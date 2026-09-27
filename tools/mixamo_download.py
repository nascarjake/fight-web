#!/usr/bin/env python3
"""Resumable Mixamo collection, using the protocol in Juanjo Martínez's downloader.

Python standard library only. No browser automation or stored account credentials.
See MIXAMO.md and licenses/mixamo-downloader.txt for provenance and setup.
"""
from __future__ import annotations

import argparse
import copy
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import socket
import ssl
import sys
import termios
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, HTTPSHandler, Request, build_opener

API = "https://www.mixamo.com/api/v1"
ROOT = Path(__file__).resolve().parents[2]
PLAN = Path(__file__).with_name("mixamo_plan.json")
SETTINGS = {"format": "fbx7_2019", "skin": False, "fps": "60", "reducekf": "0"}
MAX_FBX = 256 * 1024 * 1024


class DownloadError(Exception):
    pass


class AuthError(DownloadError):
    pass


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # API bearer credentials must never follow a redirect to another host.
        raise DownloadError("API redirected unexpectedly; stopped without forwarding credentials.")


class HTTPSRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        validate_download_url(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def validate_download_url(url):
    parsed = urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise DownloadError("Export did not return a valid HTTPS download location.")
    return url


def atomic_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    temporary.replace(path)


def slug(value):
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")[:90] or "animation"


def file_hash(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def valid_fbx(path):
    if not path.is_file() or path.stat().st_size < 100:
        return False
    with path.open("rb") as stream:
        header = stream.read(64)
    return header.startswith(b"Kaydara FBX Binary  \x00\x1a\x00") or header.startswith(b"; FBX")


def validate_plan(plan):
    ids, roles = set(), set()
    for item in plan["animations"]:
        if not re.fullmatch(r"[a-f0-9-]{36}", item["id"]):
            raise DownloadError("Invalid animation ID in plan.")
        if item["id"] in ids or item["role"] in roles:
            raise DownloadError("Duplicate ID or role in collection plan.")
        if not item["description"] or item["batch"] not in ("pilot", "expansion"):
            raise DownloadError("Invalid collection entry.")
        ids.add(item["id"])
        roles.add(item["role"])


def motion_payload(character, detail):
    if detail.get("type") != "Motion":
        raise DownloadError("Selected product is not a single animation.")
    motion = copy.deepcopy(detail["details"]["gms_hash"])
    params = motion["params"]
    if isinstance(params, list):
        values = [float(param[-1]) for param in params]
        if not all(math.isfinite(v) for v in values):
            raise DownloadError("Animation parameters contain non-finite values.")
        motion["params"] = ",".join(format(value, "g") for value in values)
    elif not isinstance(params, str):
        raise DownloadError("Unrecognized animation parameter format.")
    motion["overdrive"] = 0
    motion["trim"] = [int(value) for value in motion["trim"]]
    return {"character_id": character, "product_name": detail["description"],
            "type": "Motion", "preferences": dict(SETTINGS), "gms_hash": [motion]}


class Client:
    def __init__(self, token, timeout=180, sleep=time.sleep, clock=time.monotonic):
        self.token = token
        self.timeout = timeout
        self.sleep = sleep
        self.clock = clock
        context = ssl.create_default_context()
        # python.org's macOS install can lack its optional certificate symlink.
        # Load Apple's shipped CA bundle while keeping certificate verification on.
        if sys.platform == "darwin" and Path("/etc/ssl/cert.pem").is_file():
            context.load_verify_locations("/etc/ssl/cert.pem")
        self.api_opener = build_opener(NoRedirect(), HTTPSHandler(context=context))
        self.file_opener = build_opener(HTTPSRedirect(), HTTPSHandler(context=context))

    def api(self, path, payload=None, params=None):
        url = API + path + (("?" + urlencode(params)) if params else "")
        headers = {"Accept": "application/json", "Content-Type": "application/json",
                   "X-Api-Key": "mixamo2", "X-Requested-With": "XMLHttpRequest",
                   "Authorization": "Bearer " + self.token}
        data = json.dumps(payload).encode() if payload is not None else None
        for attempt in range(4):
            try:
                with self.api_opener.open(Request(url, data=data, headers=headers), timeout=30) as reply:
                    raw = reply.read(8 * 1024 * 1024 + 1)
                if len(raw) > 8 * 1024 * 1024:
                    raise DownloadError("API response exceeded its size limit.")
                return json.loads(raw) if raw.strip() else {}
            except HTTPError as error:
                if error.code in (401, 403):
                    raise AuthError("Mixamo session expired or access was denied. Sign in again and rerun.") from None
                # A failed POST can still have submitted a job. Do not submit it twice.
                if payload is not None or error.code not in (429, 500, 502, 503, 504) or attempt == 3:
                    raise DownloadError(f"Mixamo API returned HTTP {error.code}; rerun to resume.") from None
                retry = error.headers.get("Retry-After", "")
                delay = min(60, max(1, int(retry))) if retry.isdigit() else 2 ** (attempt + 1)
                self.sleep(delay)
            except (URLError, TimeoutError, socket.timeout):
                if payload is not None or attempt == 3:
                    raise DownloadError("Network request failed; completed files are preserved. Rerun to resume.") from None
                self.sleep(2 ** (attempt + 1))
            except (json.JSONDecodeError, UnicodeDecodeError):
                raise DownloadError("Mixamo returned an unexpected response. Sign in again or check API compatibility.") from None

    def primary(self):
        data = self.api("/characters/primary")
        if not data.get("primary_character_id"):
            raise DownloadError("Select a character in Mixamo before downloading.")
        return str(data["primary_character_id"]), str(data.get("primary_character_name", "source"))

    def search(self, query):
        result = {}
        page = 1
        while True:
            data = self.api("/products", params={"limit": 96, "page": page, "type": "Motion", "query": query})
            for item in data["results"]:
                result[item["id"]] = item["description"]
            if page >= int(data["pagination"]["num_pages"]):
                return result
            page += 1
            if page > 200:
                raise DownloadError("Search pagination exceeded expected bounds.")

    def export(self, character, payload):
        path = "/characters/" + quote(character, safe="") + "/monitor"
        before = self.api(path)
        if before.get("status") in ("processing", "pending", "queued", "in_progress"):
            raise DownloadError("This source character already has an export running. Let it finish before retrying.")
        previous_url = before.get("job_result")
        self.api("/animations/export", payload=payload)
        deadline = self.clock() + self.timeout
        saw_processing = False
        while self.clock() < deadline:
            self.sleep(1.5)
            current = self.api(path)
            status = current.get("status")
            if status in ("failed", "error", "cancelled"):
                raise DownloadError("Mixamo could not export this animation.")
            if status in ("processing", "pending", "queued", "in_progress"):
                saw_processing = True
            if status == "completed" and current.get("job_result"):
                url = current["job_result"]
                # Monitor can briefly return the previous export. Never save that
                # file under the next motion's name. A cached identical result
                # without any observed transition times out instead of guessing.
                if saw_processing or url != previous_url:
                    return validate_download_url(url)
        raise DownloadError("Export timed out or never produced an identifiable new result; rerun to resume.")

    def download(self, url, target):
        validate_download_url(url)
        temporary = target.with_suffix(".fbx.part")
        try:
            # Separate opener and request: no Adobe token is sent to the CDN.
            with self.file_opener.open(Request(url), timeout=60) as response, temporary.open("wb") as output:
                total = 0
                while block := response.read(1024 * 1024):
                    total += len(block)
                    if total > MAX_FBX:
                        raise DownloadError("Export exceeds the 256 MB per-file limit.")
                    output.write(block)
            if not valid_fbx(temporary):
                raise DownloadError("Download was not a valid FBX file; it was not marked complete.")
            temporary.replace(target)
        except (HTTPError, URLError, TimeoutError, socket.timeout):
            raise DownloadError("Animation transfer failed; rerun to resume.") from None
        finally:
            temporary.unlink(missing_ok=True)


def hidden_token():
    """Read long JWTs without echo or macOS's canonical line-length limit."""
    fd = sys.stdin.fileno()
    original = termios.tcgetattr(fd)
    hidden = copy.deepcopy(original)
    hidden[3] &= ~(termios.ECHO | termios.ICANON)
    hidden[6][termios.VMIN] = 1
    hidden[6][termios.VTIME] = 0
    value = bytearray()
    try:
        termios.tcsetattr(fd, termios.TCSANOW, hidden)
        print("Mixamo session token (hidden; paste, then press Enter): ", end="", flush=True)
        while True:
            char = os.read(fd, 1)
            if char in (b"\r", b"\n"):
                break
            if char in (b"", b"\x04"):
                raise AuthError("Token input cancelled.")
            if char in (b"\x7f", b"\x08"):
                if value:
                    value.pop()
            else:
                value.extend(char)
            if len(value) > 32768:
                raise AuthError("Token input is unexpectedly long; please copy only the access token.")
        return value.decode("ascii").removeprefix("\x1b[200~").removesuffix("\x1b[201~")
    finally:
        termios.tcsetattr(fd, termios.TCSANOW, original)
        print(flush=True)


def read_token(args):
    if args.token_file:
        token = args.token_file.read_text().strip()
    else:
        if not sys.stdin.isatty():
            raise AuthError("Run in a terminal for the hidden token prompt, or supply --token-file with a local private file.")
        print("In the signed-in Mixamo tab, open Developer Tools → Console and run:")
        print("  copy(localStorage.getItem('access_token'))")
        print("Paste into the prompt below. It stays in memory and is never written to the manifest.")
        token = hidden_token().strip()
    if token.startswith("Bearer "):
        token = token[7:]
    token = token.strip('"')
    if token in ("", "null", "undefined") or any(c.isspace() for c in token):
        raise AuthError("No usable session token supplied. Sign into Mixamo and try again.")
    return token


def run_collection(client, items, output, reference=True):
    output.mkdir(parents=True, exist_ok=True)
    # Protect the monitor endpoint and local ledger from concurrent collectors.
    with (output / ".download.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise DownloadError("A downloader is already using this output folder.") from None
        character, name = client.primary()
        folder = output / (slug(name) + "_" + slug(character))
        folder.mkdir(exist_ok=True)
        ledger_file = folder / "manifest.json"
        ledger = json.loads(ledger_file.read_text()) if ledger_file.exists() else {
            "schema_version": 1, "character_id": character, "character_name": name,
            "settings": SETTINGS, "completed": {}, "failed": {}}
        if ledger["character_id"] != character or ledger["settings"] != SETTINGS:
            raise DownloadError("Output manifest uses a different rig or export settings. Choose a fresh output folder.")
        work = ([{"id": "reference", "description": "T-pose reference", "role": "reference"}] if reference else []) + items
        print(f"Source: {name} | {len(work)} files including verified resumable entries", flush=True)
        for number, item in enumerate(work, 1):
            identifier = item["id"]
            filename = slug(item["role"]) + "__" + slug(identifier) + ".fbx"
            target = folder / filename
            entry = ledger["completed"].get(identifier)
            if entry and entry.get("file") == filename and valid_fbx(target) and file_hash(target) == entry.get("sha256"):
                print(f"[{number}/{len(work)}] Verified, skip: {item['role']}", flush=True)
                continue
            print(f"[{number}/{len(work)}] Exporting: {item['description']}", flush=True)
            try:
                if identifier == "reference":
                    payload = {"character_id": character, "product_name": name, "type": "Character",
                               "preferences": {"format": "fbx7_2019", "mesh": "t-pose"}, "gms_hash": None}
                    detail = None
                else:
                    detail = client.api("/products/" + identifier, params={"similar": 0, "character_id": character})
                    payload = motion_payload(character, detail)
                url = client.export(character, payload)
                client.download(url, target)
                ledger["completed"][identifier] = {"file": filename, "role": item["role"],
                    "description": payload["product_name"], "sha256": file_hash(target),
                    "bytes": target.stat().st_size, "preferences": payload["preferences"],
                    "gms_hash": payload["gms_hash"], "downloaded_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
                ledger["failed"].pop(identifier, None)
                atomic_json(ledger_file, ledger)
            except (DownloadError, KeyError, ValueError, TypeError) as error:
                message = str(error) if isinstance(error, DownloadError) else "Unexpected animation metadata schema."
                ledger["failed"][identifier] = {"role": item["role"], "reason": message}
                atomic_json(ledger_file, ledger)
                # Stop rather than repeatedly hammering an expired session or
                # confusing another request with a still-running export job.
                raise DownloadError(message) from None
        print(f"Collection complete: {folder}", flush=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path, default=PLAN)
    parser.add_argument("--batch", choices=("pilot", "all"), default="pilot")
    parser.add_argument("--output", type=Path, default=ROOT / "work" / "mixamo")
    parser.add_argument("--token-file", type=Path, help="Optional private local file; never pass a token on the command line")
    parser.add_argument("--list", action="store_true", help="Print the collection without signing in or downloading")
    parser.add_argument("--search", help="Search the live catalog and write search_results.json; does not export")
    parser.add_argument("--no-reference", action="store_true")
    args = parser.parse_args(argv)
    plan = json.loads(args.plan.read_text())
    validate_plan(plan)
    items = [item for item in plan["animations"] if args.batch == "all" or item["batch"] == "pilot"]
    if args.list:
        for item in items:
            print(f"{item['role']}: {item['description']}")
        print(f"{len(items)} animation sources + one reference rig")
        return 0
    client = Client(read_token(args))
    if args.search:
        args.output.mkdir(parents=True, exist_ok=True)
        results = client.search(args.search)
        atomic_json(args.output / "search_results.json", results)
        print(f"Found {len(results)} results; saved to {args.output / 'search_results.json'}")
    else:
        run_collection(client, items, args.output, not args.no_reference)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nStopped. Completed files are preserved; rerun to resume.", file=sys.stderr)
        sys.exit(130)
    except (DownloadError, OSError, ValueError, KeyError) as error:
        # Never dump request objects, headers, signed CDN URLs or token values.
        message = str(error) if isinstance(error, DownloadError) else "Local file/configuration error; check paths and manifest JSON."
        print("Download stopped: " + message, file=sys.stderr)
        sys.exit(1)
