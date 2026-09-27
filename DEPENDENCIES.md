# Native dependencies

- Godot Engine 4.7.2 stable, official macOS universal distribution. Download: https://godotengine.org/download/archive/4.7.2-stable/ . The local editor is ignored under `.tools/Godot.app`.
- V-Sekai godot-vrm: https://github.com/V-Sekai/godot-vrm , pinned commit `e15199f980064028bfa4fbee5e70dddb82dd55c3`. Bundled `addons/vrm` (plugin 2.0.1) and `addons/Godot-MToon-Shader` (3.4.0), with their original LICENSE files preserved.
- Ten user-provided local VRMs: `AvatarSample_C`, `K`, `M`, `N`, `R`, `T`, `V`, `X`, `Y` and `Z`, copied without changing their bytes to `assets/characters/`. Their embedded thumbnails are the local roster portraits in `assets/ui/roster/`. The models and extracted portraits must not be redistributed; see `README.md` and `ASSET_CREDITS.md` for the recorded restrictions and pixiv VRoid Project attribution. These character assets are not supplied by the environment download or animation library.
- Poly Haven CC0 environment models, HDR panoramas and PBR textures, downloaded as local assets. Exact source URLs, creators and checksums are in `ASSET_CREDITS.md` and `assets/environments/manifest.json`.
- The local soundtrack and effects are rendered WAV files. Regeneration uses Python 3 and NumPy through `tools/render_soundtrack.py`; Python is not required to play the game.
- Character keyframes, super choreography and camera cuts are authored in the Godot scripts. No external motion-capture service or runtime network connection is required. Optional `.tres` animation libraries must be retargeted before use.
