import io
import json
import os
from pathlib import Path
import pty
import select
import subprocess
import sys
import tempfile
import termios
import unittest
from unittest.mock import Mock
from urllib.error import HTTPError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import mixamo_download as m

FBX = b"Kaydara FBX Binary  \x00\x1a\x00" + b"\x00" * 200
DETAIL = {"description": "Leading jab", "type": "Motion", "details": {"gms_hash": {
    "params": [["Overdrive", 0, 100, 50], ["Arm space", 0, 100, 49.5]],
    "trim": ["0", "100"], "overdrive": 9, "other": "retained"}}}


class Response(io.BytesIO):
    pass


class Tests(unittest.TestCase):
    def test_long_token_paste_is_hidden_and_terminal_is_restored(self):
        master, slave = pty.openpty()
        original = termios.tcgetattr(slave)
        source = str(m.PLAN.parent)
        code = (f"import sys; sys.path.insert(0, {source!r}); "
                "import mixamo_download as m; "
                "value=m.hidden_token(); "
                "print('MATCH' if value == 'x'*8192 else 'MISMATCH')")
        process = subprocess.Popen([sys.executable, "-c", code], stdin=slave,
                                   stdout=slave, stderr=slave)
        try:
            self.assertTrue(select.select([master], [], [], 5)[0])
            output = os.read(master, 4096)
            self.assertIn(b"press Enter", output)
            self.assertFalse(termios.tcgetattr(slave)[3] & (termios.ECHO | termios.ICANON))
            os.write(master, b"x" * 8192 + b"\n")
            process.wait(timeout=5)
            while select.select([master], [], [], 0.1)[0]:
                output += os.read(master, 4096)
            self.assertIn(b"MATCH", output)
            self.assertNotIn(b"MISMATCH", output)
            self.assertNotIn(b"xxxx", output)
            restored = termios.tcgetattr(slave)
            # macOS may set the kernel-managed pending-input flag on restore.
            restored[3] &= ~termios.PENDIN
            original[3] &= ~termios.PENDIN
            self.assertEqual(restored, original)
            self.assertEqual(process.returncode, 0)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)
            os.close(slave)

    def client(self):
        return m.Client("secret-for-test", sleep=lambda _: None)

    def test_plan_has_ten_pilot_and_sixty_unique_sources(self):
        plan = json.loads(m.PLAN.read_text())
        m.validate_plan(plan)
        self.assertEqual(len(plan["animations"]), 60)
        self.assertEqual(sum(x["batch"] == "pilot" for x in plan["animations"]), 10)
        plan["animations"].append(plan["animations"][0])
        with self.assertRaises(m.DownloadError):
            m.validate_plan(plan)

    def test_payload_preserves_fractional_settings_and_source_metadata(self):
        payload = m.motion_payload("rig", DETAIL)
        self.assertEqual(payload["preferences"]["fps"], "60")
        self.assertFalse(payload["preferences"]["skin"])
        self.assertEqual(payload["gms_hash"][0]["params"], "50,49.5")
        self.assertEqual(DETAIL["details"]["gms_hash"]["overdrive"], 9)
        self.assertEqual(payload["gms_hash"][0]["other"], "retained")

    def test_search_visits_each_page_once(self):
        client = self.client()
        client.api = Mock(side_effect=[
            {"results": [{"id": "a", "description": "A"}], "pagination": {"num_pages": 2}},
            {"results": [{"id": "b", "description": "B"}], "pagination": {"num_pages": 2}}])
        self.assertEqual(client.search("boxing"), {"a": "A", "b": "B"})
        self.assertEqual([c.kwargs["params"]["page"] for c in client.api.call_args_list], [1, 2])

    def test_monitor_does_not_download_stale_previous_job(self):
        client = self.client()
        old = {"status": "completed", "job_result": "https://cdn.example/old.fbx"}
        client.api = Mock(side_effect=[old, {}, old, {"status": "processing"},
            {"status": "completed", "job_result": "https://cdn.example/new.fbx"}])
        self.assertEqual(client.export("rig", {}), "https://cdn.example/new.fbx")
        self.assertEqual(client.api.call_count, 5)

    def test_export_rejects_busy_character(self):
        client = self.client()
        client.api = Mock(return_value={"status": "processing"})
        with self.assertRaises(m.DownloadError):
            client.export("rig", {})
        self.assertEqual(client.api.call_count, 1)

    def test_failed_export_stops(self):
        client = self.client()
        client.api = Mock(side_effect=[{}, {}, {"status": "failed"}])
        with self.assertRaises(m.DownloadError):
            client.export("rig", {})

    def test_stale_monitor_is_bounded(self):
        client = m.Client("secret", timeout=2, sleep=lambda _: None, clock=Mock(side_effect=[0, 1, 3]))
        old = {"status": "completed", "job_result": "https://cdn.example/old.fbx"}
        client.api = Mock(side_effect=[old, {}, old])
        with self.assertRaises(m.DownloadError):
            client.export("rig", {})

    def test_auth_failure_is_redacted(self):
        client = self.client()
        client.api_opener.open = Mock(side_effect=HTTPError("secret-url", 401, "secret-body", {}, None))
        with self.assertRaises(m.AuthError) as error:
            client.api("/characters/primary")
        self.assertNotIn("secret", str(error.exception))
        self.assertEqual(client.api_opener.open.call_count, 1)

    def test_reads_retry_but_uncertain_posts_do_not(self):
        client = self.client()
        failure = lambda: HTTPError("url", 503, "error", {}, None)
        client.api_opener.open = Mock(side_effect=[failure(), Response(b'{"ok":true}')])
        self.assertEqual(client.api("/products"), {"ok": True})
        client.api_opener.open = Mock(side_effect=failure())
        with self.assertRaises(m.DownloadError):
            client.api("/animations/export", payload={})
        self.assertEqual(client.api_opener.open.call_count, 1)

    def test_cdn_does_not_receive_adobe_credentials(self):
        client = self.client()
        client.file_opener.open = Mock(return_value=Response(FBX))
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "jab.fbx"
            client.download("https://cdn.example/file", target)
            request = client.file_opener.open.call_args.args[0]
            self.assertFalse(request.has_header("Authorization"))
            self.assertTrue(m.valid_fbx(target))
            self.assertFalse(target.with_suffix(".fbx.part").exists())

    def test_html_download_cannot_be_marked_complete(self):
        client = self.client()
        client.file_opener.open = Mock(return_value=Response(b"<html>not an fbx</html>" * 20))
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "jab.fbx"
            with self.assertRaises(m.DownloadError):
                client.download("https://cdn.example/file", target)
            self.assertFalse(target.exists())
            self.assertFalse(target.with_suffix(".fbx.part").exists())

    def test_resume_verifies_content_not_just_filename(self):
        client = self.client()
        client.primary = Mock(return_value=("rig", "source"))
        client.api = Mock(return_value=DETAIL)
        client.export = Mock(return_value="https://cdn.example/file")
        client.download = Mock(side_effect=lambda _, path: path.write_bytes(FBX))
        item = {"id": "motion", "role": "jab", "description": "Jab"}
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            m.run_collection(client, [item], output, reference=False)
            m.run_collection(client, [item], output, reference=False)
            self.assertEqual(client.export.call_count, 1)
            ledger = json.loads((output / "source_rig/manifest.json").read_text())
            self.assertNotIn("secret", json.dumps(ledger))
            self.assertNotIn("cdn.example", json.dumps(ledger))
            target = output / "source_rig" / ledger["completed"]["motion"]["file"]
            target.write_bytes(FBX + b"tamper")
            m.run_collection(client, [item], output, reference=False)
            self.assertEqual(client.export.call_count, 2)

    def test_invalid_download_url(self):
        for url in ["http://cdn.example/file", "file:///etc/passwd", "https://user:pass@example.com/file"]:
            with self.assertRaises(m.DownloadError):
                m.validate_download_url(url)


if __name__ == "__main__":
    unittest.main()
