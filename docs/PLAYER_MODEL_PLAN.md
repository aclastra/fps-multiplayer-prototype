# Player Model — Realistic Infantry Soldier

Status: **implemented**. The low-poly soldier was replaced with a photoreal
rigged model from Grab3D.

## Asset

| Item | Source | License | Local files |
| --- | --- | --- | --- |
| Realistic rigged soldier (camo uniform, helmet, plate carrier, pouches, knee pads) | [Grab3D Soldier](https://grab3d.com/models/characters/soldier/) | CC0 1.0 | `assets/models/realistic/soldier.glb`, `LICENSE.txt` |
| Rifle (held in hand) | [Low-poly Squad Kit by Toolbench](https://toolbenchdev.com/gamedev/cc0-game-assets/low-poly-squad-kit/) | CC0 1.0 | `assets/models/squad/weapon_rifle.glb`, `LICENSE.txt` |
| Jump animations (take-off / air / landing) | [Quaternius Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html) | CC0 1.0 | `assets/models/animations/jump_source.glb`, `LICENSE_Quaternius.txt` |

The soldier GLB is 13 MB (rigged version), 24 bones, ~400k triangles with PBR
textures. It stands 1.8 m tall with its feet at y=0.

## Animation approach

The model only ships two clips: `walk` and `run`. The remaining states are
posed procedurally on its skeleton in `scripts/player_body.gd`:

| Game state | Handling |
| --- | --- |
| Idle | animation stopped (rest/A-pose) |
| Walk / sprint | `walk` / `run` clips with speed scaling |
| Jump | real CC0 clips from Quaternius's Universal Animation Library: `jump_start` → `jump_loop` → `jump_land`, retargeted onto the soldier's bones at runtime (position tracks ignored because physics owns height) |
| Fire | right arm rotated forward briefly |
| Reload | right arm bent, small oscillating motion |
| Hit | spine tilt |
| Death | hips rotated to fall, body lowered |

All of these are real `Animation` resources derived from the model's walk
clip at startup. Every bone is anchored to a valid pose, so the AnimationPlayer
crossfades between states instead of snapping. Locomotion speed is eased with
a smoothed `speed_scale`, and `play()` is only called when the clip actually
changes (the old code restarted the crossfade every frame, which caused the
jitter).

This is deliberately simple. If richer animation matters later, the options
are retargeting the 53 clips from the Toolbench rig (BoneMap / retarget import)
or replacing the model with one that ships a full gun animation set.

Team colors are applied by duplicating the model's material and multiplying
its albedo by a subtle blue/red tint, preserving the camo texture.

## Files

- `scripts/player_body.gd` — model instance, rifle attachment, team tint,
  procedural posing. Same public API as before, so `player.gd` and all
  networking code are unchanged.
- `assets/models/realistic/` — soldier GLB + license.
- `assets/models/squad/weapon_rifle.glb` — rifle only (the low-poly figure is
  no longer used).
