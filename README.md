# RIFT//RIOT — Godot Web Edition

This repository deploys the current Godot game—not the earlier browser prototype—to GitHub Pages. It targets WebGL 2 with Godot's Compatibility renderer and has a larger initial download (about 350 MB) than a conventional website. Use a current Chromium-based browser or Firefox with WebGL 2 enabled.

## Web publishing

The Web export preset is in `export_presets.cfg`. GitHub Actions installs Godot 4.7.2, imports the project, produces `build/web/index.html`, and deploys that generated artifact whenever `main` changes. Browser build output and Godot's local import cache are intentionally excluded from Git.

## Playable roster and modes

The main menu and selection screens render the selected skeletal avatar inside a live 3D arena. Ten local avatars are playable, each with its own movement profile, techniques, stance, victory pose and super choreography. Player 2 receives an alternate tint only in mirror matches.

| Fighter | Local sample | Combat style | Super |
| --- | --- | --- | --- |
| KAI | AvatarSample_C | Flame rushdown and advancing strikes | Solar Requiem |
| NEON | AvatarSample_K | Sonic projectiles and range control | Final Frequency |
| YUKI | AvatarSample_M | Frost waves and movement slows | Absolute Zero |
| IVY | AvatarSample_N | Long thorn lashes and ground snares | Eden's End |
| ROOK | AvatarSample_R | Close grabs and armored pressure | Iron Sentence |
| ATLAS | AvatarSample_T | Heavy armor and seismic attacks | World Breaker |
| ZERO | AvatarSample_V | Precise pokes and counter stance | Checkmate Protocol |
| VEX | AvatarSample_X | Evasive cross-through movement | Event Horizon |
| SORA | AvatarSample_Y | Higher jumps and aerial juggles | Heaven's Fall |
| RAIJIN | AvatarSample_Z | Fast entries and repeated lightning hits | Thunder God |

- **Versus CPU:** select both fighters and an arena; four difficulty settings.
- **Local Versus:** two players on one keyboard, two controllers, or keyboard/controller combinations. Connected controllers are assigned in device order: first to P1, second to P2.
- **Arcade:** fight the other nine roster members, with increasing difficulty and changing arenas. A loss offers a retry; defeating the ninth opponent completes the circuit.
- **Training:** choose a fighter and dummy, practice against standing, blocking or attacking behavior, view input history, combo/frame data and exact collision volumes, then reset, swap sides or step one 60 Hz frame at a time.
- **Matches:** first to two round wins, 99-second timer, knockout/time-out decisions, draw replay, victory presentation, rematch and main-menu actions.
- **Three arenas:** Neon Overpass, Cinder Works and Hallowed Dawn. Downloaded Poly Haven meshes, PBR surfaces and HDR skies are combined with authored architecture, lighting and moving scenery. See [ASSET_CREDITS.md](ASSET_CREDITS.md).
- **Audio:** an original 164 BPM stereo synth-metal loop, plus 26 new combat sounds: light/heavy punches, swings, cloth impacts, guards, landings, synthetic grunts, elemental accents and super cues. Hit sounds layer and vary by attack and fighter. Music has a persistent toggle. Offline authoring sources: `tools/render_soundtrack.py` and `tools/render_combat_sfx.py`.

## Controls and meter

| Action | Player 1 | Player 2 | Controller |
| --- | --- | --- | --- |
| Move / jump / crouch | A/D, W, S | Left/right, up, down | Left stick or D-pad |
| Jab / cross / low kick | J / K / L | 1 / 2 / 3 | South / east / west |
| Special I / character technique | U | 5 | North |
| Hold guard | I | 0 | LB |
| Dodge | Shift | 4 | RB |
| Special II / signature technique | O | 6 | RT |
| Overdrive | H | 7 | LT |
| Super finisher | P | 8 | Right-stick click |
| Pause | Escape | Escape | Start |

F11 toggles fullscreen. F3 displays hitboxes, projectile boxes, hurtboxes, invulnerability regions and frame/stun counters while fighting. Menus support mouse, keyboard and controller navigation. Every combat binding can be remapped independently for P1 and P2 from **Settings → Control Settings**, including keyboard enablement and controller assignment.

## Phase 1 player tools

**Fighter Command** is available from the main menu and pause menu. It presents the selected fighter in a 3D preview and lists normals, specials and supers with their live bindings, purpose, coaching note, timing, cancel information and meter cost. The frame slider lets players inspect a move pose before taking it straight into Training.

**Training** uses the same remapped input profiles as matches. Its input history, live held-input display, command list, combo readout, frame/phase display, meter controls and hitbox toggle are designed for practicing a sequence without opening the developer Combat Lab. Pause, reset, side swap and one-frame stepping are available in the player-facing HUD.

The second Phase 1 pass focuses on **footsies**. CPU opponents take short steps, hold their ground, give ground after commitments, and choose attacks using each move's reach and startup. Difficulty changes observation delay (24/19/15/12 simulation frames), decision cadence, attack frequency and how reliably the CPU confirms legal cancel routes after a hit. The CPU sees delayed combat state rather than player inputs; it attempts whiff punishes only when its startup fits the estimated remaining recovery. Neon alternates projectile spacing with pokes instead of periodically rushing in with full meter.

Arcade always begins at **Rookie** and rises across its nine bouts: Rookie (1–2), Challenger (3–4), Veteran (5–6), then Expert (7–9). The CPU setting in System applies to Versus CPU; the Arcade HUD displays the current circuit tier.

In Training, choose **FOOTSIES CPU** to practice against that same policy and see its current intention, or **WHIFF PRACTICE** for a repeating heavy-attack drill. Step outside the heavy, then attack during its recovery. The HUD shows horizontal origin-to-origin distance and estimated grounded light/low tip reach against a neutral torso. These estimates exclude advancing movement, crouching, airborne opponents and exposed limbs; red/green boxes remain the exact contact geometry. The colored floor bars mark each fighter's low attack reach from their origin. Input history now records actual attack attempts, including simultaneous buttons, and missed strikes report **WHIFF**.

Kai and Neon's normal attacks now use smaller, animated collision boxes with different ranges. Startup has no attack box; active frames extend/retract it; an exposed limb remains vulnerable briefly in recovery. Their default contact poses are baked against those active frames. Effects originate from the striking hand or foot, and Kai's cross/drive advance less. Combat Lab exposes the entry/exit offsets, edge scales and limb-recovery settings alongside its existing frame editor.

A new match starts at **zero energy**. Landing attacks, receiving hits and blocked contacts earn meter; standing idle does not refill it. Meter carries between rounds of the same match and resets for a new match or rematch. The six regular techniques have no meter cost in the default fighter profiles.

**Overdrive and supers spend the same meter.** Overdrive costs **50**, adding 25% damage for 360 unfrozen simulation frames. A super costs **100** on activation, including when it misses or is blocked. Its startup is vulnerable and guardable. Only a clean confirmed contact starts the **3.5-second cinematic**: a character-specific sequence of strikes with camera cuts, effects and a finishing attack. The simulation and round timer pause during the sequence; its confirmed damage resolves once before normal combat resumes. Blocking, countering or interrupting the initial attack prevents that cinematic.

Blocking consumes guard and takes chip damage; depleted guard causes a guard crush. Ordinary hitstop freezes combat timing and skeletal playback together, and also stops the round clock.

## Phase 2 combat presentation

Every one of the 70 regular techniques and ten supers now has a unique authored presentation cue in its fighter data. The move list, Training reference, active-frame scheduler, effect system, sound system and contact camera response read that same cue, so a move cannot silently fall back to an unrelated generic effect.

The eight fighters added after Kai and Neon have their own readable effect families: Yuki forms frost shards and ground ice, Ivy sends thorn lashes and snares, Rook creates close-range lock rings, Atlas throws debris and shockwaves, Zero marks precise lanes, Vex folds void halos, Sora draws rising wind spirals, and Raijin chains electric bolts. Attack starts show the character's telegraph; contact supplies the impact burst, authored hit weight and sound layering. This keeps the screen legible while differentiating each kit.

For a new fighter or move, add fighter-prefixed VFX and sound cue names alongside the frame data. `FighterCatalog.presentation_errors()` rejects duplicate or incorrectly owned cues; `MoveData.validation_errors()` checks presentation values; the stage keeps transient effects within a fixed budget; and the audio pool throttles repeat requests while reserving high priority for supers. The roster and stage tests run every cue through the real presentation paths.

## Combat Lab

The top fighter picker switches both lab avatars, their move data and training profiles. Unsaved edits remain with each fighter while switching during the session.

**Move Preview** isolates an attack. Play, pause, scrub or step one exact 60 Hz frame at a time. The timeline shows startup (gold), active (red), recovery (blue), invulnerability and cancel windows. Frames are zero-based; window endpoints are inclusive. The first active frame equals startup. Edit timing, stun, hitstop, damage, energy cost, transition blending, box offsets/dimensions, cancel windows/destinations and assigned animation. Boxes update immediately. Invalid temporary edits are reported and cannot be saved.

**Live Training** runs the simulation with the keyboard controls above. Choose a standing, blocking or attacking dummy. Space/Escape pauses; period steps one tick, R resets fighters and B toggles collision display. Click the arena or leave text fields before entering combat input. Training resets with full meter for testing. Confirmed supers resolve their damage immediately in the lab; the laboratory does not run the game's camera sequence. Move Preview remains an exact scrub of the selected move clip.

Green boxes are vulnerable hurtboxes. Red boxes are active attacks and projectiles. Blue boxes show the normally vulnerable region during invulnerability; those regions are excluded from contact tests. These displays use the simulation's exact `Rect2` geometry, mirrored by facing. A box is a gameplay volume, not a per-pixel mesh collider.

**Save Move** writes validated resources to `user://moves/<fighter_id>/<move_id>.tres`, such as `user://moves/neon/burst.tres`. Reload restores only that fighter's saved overrides. Matches load each side's qualified saves independently. On macOS, the base directory is `~/Library/Application Support/Godot/app_userdata/RIFT RIOT — Combat Lab/moves`; that data-directory name is retained for compatibility.

The lab can read old `user://moves/<move_id>.tres` files for Kai when no qualified Kai save exists. Save those again from the Kai workbench to migrate them to `moves/kai/` for matches. Other fighters never inherit these legacy files. Standalone workbench callers that omit a save namespace retain the original flat save path.

## Architecture and animation

- `combat/MoveData.gd`: editable move schema and validation.
- `combat/MoveCatalog.gd`: seven base input IDs, including `finisher`.
- `combat/FighterCatalog.gd`: ten profiles and independent move resources.
- `combat/FightSimulation.gd`: fixed 60 Hz combat, buffering, collision, projectiles, grabs, counters, armor, slows, meter and confirmed contacts.
- `combat/MatchSession.gd`: round/match/arcade progression and deterministic CPU decisions.
- `combat/FootsiesAI.gd`: shared match/Training CPU spacing, delayed observation, attack selection and recovery punish policy.
- `scripts/game.gd`: front-end flow, input and match integration.
- `scripts/game_ui.gd`: menus, fighter/stage selection, HUD and results.
- `scripts/input/control_profile.gd` / `scripts/input/combat_input_router.gd`: persisted P1/P2 bindings, keyboard/controller assignment and semantic combat input.
- `scripts/control_settings.gd`: player-facing remapping screen.
- `scripts/fighter_command.gd`: player-facing move reference and 3D move preview.
- `scripts/training_mode.gd`: player-facing practice mode, telemetry and dummy behavior.
- `scripts/game_stage.gd`: three environments and background motion.
- `scripts/super_director.gd`: cinematic clock, actor staging and camera cuts.
- `scripts/game_audio.gd`: soundtrack and sound effects.
- `scripts/avatar_actor.gd`: VRM switching, skeletal playback, blending and exact frame sampling.
- `scripts/motion_library.gd`: authored poses baked into native animation tracks.
- `editor/move_workbench.gd`: move editing, per-fighter persistence and timeline.
- `scripts/combat_lab.gd` / `scripts/lab_stage.gd`: training, preview and collision visualization.

The authored fallback library has **28 native skeletal clips** per actor: 16 legacy fallbacks, 11 clips for its own fighter and a shared cinematic victim sequence. Across the roster, this includes 70 character-specific combat techniques, ten super choreographies and individual idle/showcase/victory clips. These are authored prototype keyframe animations, not downloaded motion capture or final production animation.

Simulation ticks decide contacts and invulnerability. Animation presents those results. Locomotion and reactions advance through the native `AnimationPlayer`; exact-frame preview seeks without blending. Kai now has eleven actions: the original seven buttons plus Down+Light, Forward+Light, Forward+Heavy, and Back+Heavy command variants. His library loads 17 retargeted Mixamo clips and a composed four-contact Solar Requiem cinematic (37 total available clips including fallbacks). See [the retargeting workflow](tools/RETARGETING.md). External libraries in `assets/animations/*.tres` must already be retargeted to the intended humanoid's rest pose. Arbitrary animation files cannot safely be applied to an unrelated rig.

## Local character provenance

The ten user-supplied files `AvatarSample_C/K/M/N/R/T/V/X/Y/Z.vrm` are imported through V-Sekai's VRM importer and MToon shader. Copies under `assets/characters/` are byte-identical to the originals. Runtime visual children are normalized to 1.72 m resting height and grounded without changing actor scale or collision units. Their imported skeletons contain 137–228 total bones, including secondary bones. The source models contain no motion clips. Portraits in `assets/ui/roster/` were extracted from each source VRM's embedded thumbnail.

All ten metadata records name **pixiv VRoid Project** and specify `avatarPermission: onlyAuthor`, `creditNotation: required`, `allowRedistribution: false` and `modification: prohibited`. Avatar C reports `commercialUsage: personalProfit`; the other nine report `personalNonProfit`. These are the recorded metadata fields, not a grant of distribution rights. The metadata also disallows excessively violent/sexual, political/religious and antisocial/hate usage.

The local models and extracted portraits are not redistribution assets. Do not include them in a public repository, downloadable build or upload to an animation service. A distributable build needs replacement assets or appropriate permission from the rights holder. The environment assets' CC0 license and this project's authored animations do not change the character metadata. See [ASSET_CREDITS.md](ASSET_CREDITS.md).

## Validation

Run `../.tools/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit --log-file /tmp/rift-import.log` once to import assets and register classes. Do not run multiple editor imports concurrently.

Run the same executable with `--headless --path . --script res://<test_path>` for:

- `tests/test_combat.gd`: combat rules and contacts.
- `tests/test_match.gd`: rounds, CPU, arcade and meter.
- `tests/test_footsies.gd`: CPU approach/retreat/wait cadence, reaction delay, punish eligibility, animated hitbox boundaries and exposed-limb contacts.
- `tests/test_roster.gd`: all ten mechanics, independent move resources, meter and cinematic resolution.
- `tests/test_stage.gd`: nonoverlapping Dawn geometry, effect lifecycle and audio resources.
- `tests/test_mixamo_animation.gd`: runtime source overrides, active-frame contact, loops, floor clearance, and fighter isolation.
- `tests/test_animation.gd`: move sampling, neutral-state advancement, hitstop and exact scrubbing.
- `tests/test_roster_animation.gd`: all ten models, required clips, cinematics and bounded displacement.
- `tests/test_game.gd`: real game flow, all ten super directors, lethal supers and result cleanup.
- `tests/test_input_router.gd`: control persistence, conflicts, device assignment and semantic input.
- `tests/test_control_settings.gd`: remapping-screen behavior and reset paths.
- `tests/test_fighter_command.gd`: move-reference filtering, frame preview and Training handoff.
- `tests/test_training.gd`: player-facing Training telemetry, dummy controls and command guidance.
- `tests/test_lab.gd`: fighter switching, editing, training projectiles and immediate super resolution.
- `editor/test_workbench.gd`: UI signals and save/reload with a temporary test resource.
