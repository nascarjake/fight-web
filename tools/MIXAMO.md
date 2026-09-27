# Mixamo collection for RIFT//RIOT

This is a standard-library Python adaptation of the export protocol in
[Juanjo Martínez's Mixamo downloader](https://github.com/juanjo4martinez/mixamo-downloader).
No Qt, Windows executable, browser clicking, or third-party Python dependencies
are required. Upstream attribution is in `licenses/mixamo-downloader.txt`.

## Run once, then resume whenever needed

1. Sign into Mixamo and keep the same source character selected. The first browser
   samples used **CH02_NONPBR**. No VRoid upload is necessary for this collection.
2. Double-click **Download Mixamo Animations.command** in the project root.
3. On the signed-in Mixamo page, open Developer Tools → Console and run:

   ```javascript
   copy(localStorage.getItem('access_token'))
   ```

4. Paste into the terminal's **hidden token prompt** and press Return. No characters
   appearing while pasting is normal. Do not paste the token into chat.

The prompt accepts long tokens without macOS Terminal's normal line-length limit.
If an older, already-open launcher beeps when pasting, close that window and
reopen the launcher to load the fix. Backspace and Ctrl+C still work; terminal
settings are restored when the prompt exits.

This reads the session token from Mixamo's own browser storage. The collector uses
it only for authenticated requests to `https://www.mixamo.com/api/v1`. It is held
in process memory, never printed or saved, and never forwarded to download/CDN
hosts. A missing or expired token stops the batch; repeat the handoff to resume.
An optional `--token-file` accepts a private local file, but the collector does
not create or retain one. Keep any such file outside version control.

The script uses the website's internal API, as the upstream project does. An
authenticated run on September 13, 2026 successfully collected all 60 animations
and the CH02_NONPBR reference rig (88,623,888 bytes total). All 61 files passed
FBX-header, size, and SHA-256 verification, with no duplicate file contents or
failed jobs. Future website API changes may require collector updates; this is
not a supported Adobe public batch API.

## Collection and output

`mixamo_plan.json` contains **60 source candidates**, selected by descriptions
and stable IDs from the upstream index, including the **10-clip Kai pilot**.
The index is a starting shortlist; source availability and metadata are fetched
from Mixamo at export time. These are not yet reviewed, retargeted game clips.

The launcher requests all 60 plus the source character in T-pose. To download
only the pilot, run from the project root:

```sh
python3 desktop/tools/mixamo_download.py --batch pilot
```

To review the list without signing in:

```sh
python3 desktop/tools/mixamo_download.py --batch all --list
```

Files go to `work/mixamo/<source-character>_<id>/`, which is ignored by Git and
outside Godot's imported assets. Each file has a role and animation ID in its
name, preventing Mixamo's repeated display names from overwriting one another.

- Animation exports: binary FBX, **60 FPS**, without skin, no keyframe reduction.
- Reference: binary FBX with the source rig/skin in T-pose.
- Source parameters/trim are retained in the manifest. Root translation is
  preserved for local retargeting and deliberate in-place conversion.
- The manifest includes hashes, byte counts, rig identity, source descriptions,
  and actual export parameters. Signed download URLs and credentials are omitted.
- Exports are sequential because Mixamo monitors one job per source character.
  Avoid manually exporting from the same character while the batch runs.
- Ctrl+C stops safely. Rerunning verifies checksums and skips complete files.
- Partial/invalid FBX transfers are not marked complete. API reads retry transient
  failures; uncertain export submissions stop rather than submitting twice.
- Failed jobs, expired sessions, unexpected metadata, or export timeouts stop
  with resumable progress. No infinite polling or silent success.

To expand the shortlist using the live catalog (fixed pagination):

```sh
python3 desktop/tools/mixamo_download.py --search 'boxing'
```

That saves `work/mixamo/search_results.json`; it does not export anything. Add
selected IDs, descriptions, unique roles, and batch labels to the plan. It is
also possible to pass a separate collection via `--plan`.

## After collection

Seventeen source clips are now retargeted to Kai, alongside a composed Solar Requiem cinematic, in
`assets/animations/kai_mixamo.tres`. See [RETARGETING.md](RETARGETING.md) for the
bake command, runtime coverage, contact corrections, and remaining content work.
Original source files stay intact so different fighter variants can be made
without downloading every clip again.

## Offline checks

```sh
python3 -m unittest discover -s desktop/tools/tests -p 'test_mixamo*.py' -v
```

Checks cover long hidden token pastes and terminal restoration, pagination,
parameter conversion, stale export results, failure timeouts, credential
separation, invalid downloads, and checksum-based resume.
