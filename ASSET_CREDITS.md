# Native asset credits

The three native arenas use the downloaded assets below from **Poly Haven**. All listed assets are offered by their publisher under **CC0 1.0**. Poly Haven permits commercial use, modification and redistribution. Attribution is appreciated but not required. Source: [Poly Haven asset license](https://polyhaven.com/license), [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

The game runs from local files. It makes no Poly Haven API calls at runtime. Downloads were obtained through the publisher's public API and CDN on 2026-09-12. The downloaded files' exact URLs, sizes and checked MD5 hashes are recorded in [assets/environments/manifest.json](assets/environments/manifest.json); original API file metadata is retained in `assets/environments/source_metadata/`.

## Downloaded models

| Original asset | Creator | Included data | Arena use |
| --- | --- | --- | --- |
| [Concrete Road Barrier](https://polyhaven.com/a/concrete_road_barrier) | Amal Kumar | glTF, geometry buffer, 1K PBR textures | Neon Overpass and Cinder Works perimeter barriers |
| [Modular Industrial Pipes 01](https://polyhaven.com/a/modular_industrial_pipes_01) | Jorge Camacho | glTF, geometry buffer, two 1K PBR texture sets | Actual pipe modules arranged around the industrial arenas |
| [Ceiling Fan](https://polyhaven.com/a/ceiling_fan) | Ulan Cabanilla | glTF, geometry buffer, 1K PBR textures | Cinder Works ceiling fan and furnace turbine |
| [Rock Moss Set 01](https://polyhaven.com/a/rock_moss_set_01) | Kless Gyzen | Six rock meshes, glTF/buffer, 1K textures | Hallowed Dawn perimeter rocks |
| [Gothic Statue](https://polyhaven.com/a/gothic_statue) | Benny Weimer | glTF, geometry buffer, 1K PBR textures | Hallowed Dawn monumental statue |

## Downloaded lighting and background panoramas

| Original asset | Creator | Included data | Arena |
| --- | --- | --- | --- |
| [Shanghai Bund](https://polyhaven.com/a/shanghai_bund) | Greg Zaal | 2K HDR panorama | Neon Overpass |
| [Industrial Sunset 02](https://polyhaven.com/a/industrial_sunset_02) | Sergej Majboroda | 2K HDR panorama | Cinder Works |
| [Spruit Sunrise](https://polyhaven.com/a/spruit_sunrise) | Greg Zaal | 2K HDR panorama | Hallowed Dawn |

These panoramas are distant static imagery and environment lighting, not traversable 3D cities or landscapes.

## Downloaded PBR surfaces

| Original asset | Creator | Included data |
| --- | --- | --- |
| [Hangar Concrete Floor](https://polyhaven.com/a/hangar_concrete_floor) | Dimitrios Savva | 2K diffuse, OpenGL normal and roughness maps |
| [Rusty Metal Sheet](https://polyhaven.com/a/rusty_metal_sheet) | Amal Kumar | 2K diffuse, OpenGL normal and roughness maps |
| [Medieval Blocks 02](https://polyhaven.com/a/medieval_blocks_02) | Rob Tuytel | 2K diffuse, OpenGL normal and roughness maps |

## Authored assembly and motion

Arena architecture, layouts, signs, platform trim, lights, drone geometry, particle effects and camera paths are implemented in `scripts/game_stage.gd`. Downloaded meshes have been instanced, repositioned and scaled for the scenes; source files remain intact. The downloaded glTF models contain **no animation clips**. Fan/turbine rotation, drone flight, rain, cinders, drifting motes, pulsing lights and hit effects are authored in the game, rather than attributed to the downloaded models.

`scripts/motion_library.gd` contains authored prototype poses baked into native skeletal animation tracks. It supplies character-specific combat techniques, idle/showcase/victory clips and ten 3.5-second super choreographies. `scripts/super_director.gd` supplies the camera cuts and staging. These animations are not downloaded motion capture and were not included in the source VRMs.

## Mixamo animation sources

`assets/animations/kai_mixamo.tres` contains seventeen clips derived from Adobe Mixamo animations and one composed cinematic acquired through the project owner's account, using the stock CH02_NONPBR source rig. They were retargeted, cropped, grounded, and adjusted for Kai's contact timing. Each clip embeds its source description and SHA-256; the bake report records the conversion. These downloaded motions are distinct from the authored prototype poses described above. See [the collection workflow](tools/MIXAMO.md) and [retargeting notes](tools/RETARGETING.md).

## Local characters and portraits

The playable local roster uses the user-supplied VRoid samples below. The author recorded in every file is **pixiv VRoid Project**. The source files and their copies in `assets/characters/` are byte-identical. Each portrait in `assets/ui/roster/` was extracted from that VRM's embedded thumbnail.

| Fighter | Local source | Extracted portrait |
| --- | --- | --- |
| KAI | AvatarSample_C.vrm | kai.png |
| NEON | AvatarSample_K.vrm | neon.png |
| YUKI | AvatarSample_M.vrm | yuki.png |
| IVY | AvatarSample_N.vrm | ivy.png |
| ROOK | AvatarSample_R.vrm | rook.png |
| ATLAS | AvatarSample_T.vrm | atlas.png |
| ZERO | AvatarSample_V.vrm | zero.png |
| VEX | AvatarSample_X.vrm | vex.png |
| SORA | AvatarSample_Y.vrm | sora.png |
| RAIJIN | AvatarSample_Z.vrm | raijin.png |

All ten files record `avatarPermission: onlyAuthor`, `creditNotation: required`, `allowRedistribution: false` and `modification: prohibited`. Avatar C records `commercialUsage: personalProfit`; the other nine record `personalNonProfit`. Their metadata also disallows excessively violent/sexual, political/religious and antisocial/hate usage, and references the [VRM 1.0 license specification](https://vrm.dev/licenses/1.0/).

These are metadata records, not verified permission to distribute the characters. Keep both the VRMs and extracted portraits local; do not include them in a public repository or downloadable build, or upload them to an animation service. Replace these assets or obtain appropriate permission before distribution. Poly Haven's CC0 license applies only to the listed environment assets; it does not apply to the characters or portraits.

## UI and audio

The native roster uses the ten local portraits listed above. The older web prototype's generated concept atlas has separate provenance and is not the source of these playable character portraits. Typography uses native system font fallbacks.

`assets/audio/riot_engine.wav` is an original 32-bar, 164 BPM synth-metal composition, rendered with the included `tools/render_soundtrack.py`. Guitar-like synthesis, bass, percussion and the five sound effects use no third-party recordings or sampled music. The music loops and is controlled by the in-game music setting.
