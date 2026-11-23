# Low-poly Squad Kit 1.0

A rigged low-poly soldier with 53 animations, ten weapons, seventeen props and a
1 m modular room kit. 59 assets, 13,548 triangles in total. Every file is
original, generated from scripts. Nothing was downloaded or traced.

**Licence: CC0 1.0** (public domain dedication, see `LICENSE.txt`). Use it in
anything, commercial or not, change it, and you don't have to credit anyone.
Credit is appreciated but not required.

## What's in the folder

```
fbx/            for Unity (and most engines)
glb/            for glTF pipelines, three.js, Godot, Blender
manifest.json   every asset: id, group, triangles, bytes, size, sockets, clips
sheets/         contact sheets of everything
thumbs/         one picture per asset
```

| Group | Count | Triangles |
|---|---|---|
| Figure (1.80 m, 22 bones, 4 sockets) | 1 | 3,368 |
| Weapons | 10 | 132–372 each |
| Props | 17 | 76–960 each |
| Modular layout + one assembled room | 11 | 24–1,980 |
| Animations: 13 base clips, 7 grip sets | 53 actions | n/a |

Everything is flat-coloured from a palette. No textures and no UVs, except on
the figure. No LODs and no colliders.

## Using it in Unity

1. Copy `fbx/` into your `Assets/` folder.
2. Select `figure.fbx`. In the Rig tab, set Animation Type to **Generic** and
   Avatar Definition to **Create From This Model**.
3. The actions are named `clip` or `clip_gripset`, for example `walk`,
   `walk_rifle`, `aim_polearm`. If a grip set doesn't override a clip, the base
   clip is the one to play.

**Facing.** The kit is exported so that a model's front is Unity **+Z**
(`transform.forward`). Nothing needs a correcting rotation.

**Weapons go in sockets.** The figure has four empty child objects:
`Socket_Hand_R`, `Socket_Hand_L`, `Socket_Back` and `Socket_Head`. Parent a weapon
to `Socket_Hand_R` with position 0, rotation 0 and scale 1, and it is held
correctly. Every weapon is modelled with its handle on the origin, the muzzle
down +X and the sights up +Y. Blades and spears run up +Y instead.

**Grip sets.** Each weapon belongs to a grip set, which decides how the arms
hold it while the legs keep playing the base clip:

| Grip set | Weapons | Hands |
|---|---|---|
| unarmed | none | 0 |
| sidearm | pistol | 1 |
| blade | sword, axe | 1 |
| rifle | SMG, rifle, shotgun, sniper | 2 |
| polearm | spear | 2 |
| bow | bow | 2 |
| heavy | rocket launcher | 2 |

**Team colour without extra materials.** Material slot 0 on the figure is
`TeamColour`: helmet, shoulders, torso, hips, thighs. Tint it per unit with a
property block, which keeps batching intact:

```csharp
var block = new MaterialPropertyBlock();
block.SetColor("_BaseColor", teamColour);   // "_Color" on the Built-in pipeline
renderer.SetPropertyBlock(block, 0);
```

**Modular grid.** One cell is 1 m and the walking surface is y = 0. Walls stand
on a cell's south edge, 2.5 m tall. Rotate a wall 90°, 180° or 270° to move it
to another edge. Pieces overlap by 30 mm on purpose so no two faces are
coplanar, which stops flickering.

## Known limits

- No textures, so there is nothing to paint wear or grime onto.
- Props have no colliders. Add box or convex mesh colliders yourself.
- A weapon with detail on one side reads mirrored in the left hand. Only the
  rocket launcher has side detail, and its grip set holds it in the right hand.
