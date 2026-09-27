# Kai: first recorded animation pass

Kai now has **11 playable actions**, including four directional commands:

| Input (relative to the opponent) | Move | Use |
| --- | --- | --- |
| Down + Light | Coalbreaker | Close body hook; confirm extender |
| Forward + Light | Furnace Knee | Knee with low pushback; launcher setup |
| Forward + Heavy | Helios Breaker | Spinning kick; committed combo finish |
| Back + Heavy | Searing Lance | Long side kick; approach check |

Neutral Light/Heavy and existing specials keep their buttons. Directions resolve
at the button edge, before input buffering, and follow facing. They use the
existing remappable Light/Heavy actions. Ground variants do not replace airborne
inputs. Fighter Command and Training display the modifier and current binding.

Practice **Jab → Coalbreaker → Furnace Knee → Rising Phoenix** from close range.
This route is verified through actual collision and hit-confirm cancels. Whiffed
attacks cannot use those cancels. Flare Cross can also cash out into Helios Breaker.
The CPU can select the new moves within its normal range and recovery rules.

Training resolves super damage immediately. Use Vs Computer or Local Versus to
review Solar Requiem's full cutscene.

The library contains **17 retargeted source clips and one composed cinematic**.
All eleven Kai actions now use recorded sources, including the dodge, advancing
special, and super opening strike. His idle, forward/backward steps, hit reaction,
and knockout are also replaced. `kai_getup` remains reserved because the current
simulation has no nonfatal wakeup state. Guard/crouch/jump, showcase and victory
still use the authored library; the other fighters retain their own content.

Solar Requiem uses a body hook, knee, rising strike, and spinning back kick with
contact beats at frames **42, 70, 108, 160** of its 210-frame sequence. Three-frame
impact holds, a single launch/fall, paired spacing, camera cuts, layered impacts,
and tapered embers follow those contacts. The simulation and round clock remain
frozen; damage resolves once when the sequence completes. Its guardable opening
strike is now 22 startup / 5 active / 36 recovery with a shorter contact range.

## Rebuild

From the repository root, with the downloaded collection present:

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path desktop \
  --script tools/retarget_mixamo.gd --log-file /tmp/rift-retarget.log
```

An alternate absolute collection directory can be passed after `--`. The tool
checks each input against its download manifest before conversion. It saves the
library only after all clips have been baked. No sign-in or internet is needed.
The 60 original FBXs and source reference rig remain outside the Godot project.
Only the retargeted library is needed to play.

`SPECS` in `retarget_mixamo.gd` maps source roles to game clips. The generated
`assets/animations/kai_mixamo_report.json` records trim points, contact times,
durations, and mapped bone counts. Each animation records its source description
and SHA-256. Changes to Kai's frame data require rebuilding so contact remains
aligned. Timing edits in the workbench still preview the selected clip stretched
to the edited total; contact landmarks are baked for the canonical catalog data.

## Conversion and game timing

- Godot reads FBX directly at 60 Hz through `FBXDocument` / `FBXState`; no Blender,
  FBX SDK, uploaded VRoid model, or third-party importer executable is required.
- 52 humanoid bones are mapped, including fingers. Global rotation changes from
  the source rest pose are converted into the target skeleton's local rotations.
  Target bone lengths remain intact; only the hips receive translation.
- Horizontal source traversal is removed. Small weight shifts and vertical
  movement remain; simulation position and lunges continue to own gameplay travel.
- Standing clips are grounded using the target ankles/toes. This is a floor-height
  correction, not full foot-lock IK; stride-speed matching and planted-foot locking
  remain further locomotion polish.
- Attacks are cropped around recorded hand/foot extension. Their anticipation,
  contact, and recovery are baked to Kai's existing startup/active/recovery frames.
  Offline two-bone corrections put the striking limb inside the collision window.
  The launcher adds an upward contact arc. Jab/heavy lower-body motion is reduced
  to keep the short startup from inheriting a large captured stepping lunge.
- Attacks enter and leave through the same recorded idle pose. Loops have a blended
  seam. Bone tracks remain deterministic and use the existing manual AnimationPlayer
  blending, hitstop, and exact frame preview.
- A fighter metadata tag prevents Kai's library loading on another fighter. The
  loader uses ResourceLoader directory discovery so resource remapping on export
  does not hide the library. No new exported build was produced in this pass.

Godot API references: [FBXDocument](https://docs.godotengine.org/en/stable/classes/class_fbxdocument.html)
and [ResourceLoader](https://docs.godotengine.org/en/stable/classes/class_resourceloader.html).

## Verification and review

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path desktop \
  --script tests/test_mixamo_animation.gd --log-file /tmp/rift-mixamo-test.log
```

`tests/test_kai_commands.gd` verifies both facings, airborne fallback, buffered
commands, and the actual advertised combo route. The acceptance test checks real runtime overrides, source provenance, safe bone
tracks, loop seams, every active contact frame in both facings, return to neutral,
forward/backward selection, hitstop, floor clearance, and isolation from Neon.
The existing animation and full roster animation suites cover scrubbing, all
bones, and other fighters. Rendered contact/recovery review sheets are available
locally under `work/animation-review/`.

To feel the changes, relaunch the game, choose Kai in Training, then compare LIGHT,
HEAVY, LOW, SPECIAL I, and forward/backward movement. Move Preview can step through
the attacks with collision boxes visible.

This establishes the import and timing workflow for the remaining library. It
is not a completed animation pass for the roster: other techniques need source
selection, pose adjustment, and visual review per fighter. Remaining work includes bespoke choreography for the other nine fighters,
replacement audio recordings, stride-speed/foot-lock polish, and wakeup gameplay.
