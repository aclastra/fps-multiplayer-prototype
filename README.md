# FPS Multiplayer Prototype

A small **Godot 4.7** first-person shooter built to learn authoritative
client/server networking. Two or more players connect over ENet, move around a
box arena, and shoot each other. The server owns all gameplay decisions;
clients send input and render interpolated state.

## Running it

Godot 4.7 must be on your `PATH` (verified: `/usr/bin/godot`, 4.7.2).

From this folder:

```bash
# 1) Play mode — host/join menu in a window
godot --path .

# 2) Host directly, skipping the menu (you play as the host)
godot --path . -- --host

# 3) Dedicated server (no local player)
godot --headless --path . -- --server

# 4) Join directly, skipping the menu
godot --path . -- --join 127.0.0.1

# Inspect your own armored model with a pulled-back third-person camera
godot --path . -- --host --show-body
```

`--show-body` is just a debugging/inspection flag; without it, local players use
the normal first-person viewmodel.

To test on one machine: run command 2 in one terminal, then command 1 in two
more terminals and click **Join**. Use `--join <lan-ip>` for a friend on your
network. Port **7777** is UDP and must be reachable.

## Controls

Click into a game window once to capture the mouse before playing.

| Action | Input |
| --- | --- |
| Move | W A S D |
| Look | Mouse |
| Fire | Left mouse button |
| Sprint | Shift |
| Jump | Space |
| Reload | R |
| Switch weapons | 1 / 2 / 3 |
| Throw grenade | G |
| Release mouse | Esc (click to recapture) |

## Architecture

```
main.tscn
├── Main      (main.gd)     session manager, spawning, snapshots, state broadcast
├── Arena     (arena.gd)    static geometry + spawn points
├── Players   (Node3D)      player instances live here
├── HUD       (hud.gd)      health, ammo, crosshair, kill feed
└── Menu      (menu.gd)     host / join UI

scenes/player.tscn           CharacterBody3D + camera, weapon, name label
scripts/player.gd            movement, shooting, health, all RPCs
scripts/input_setup.gd       autoload that defines input actions
```

### Authority rule

Every `Player` node keeps Godot's default multiplayer authority: **the server
(peer 1)**. That gives one simple rule for all RPCs:

- **Client → server:** `@rpc("any_peer", ...)` + `rpc_id(1, ...)`, with the
  server checking `multiplayer.get_remote_sender_id()` against the player's id.
  Input, reload requests, and name changes work this way. They are unreliable
  where losing a packet for 16 ms doesn't matter.
- **Server → clients:** `@rpc("authority", ...)`. The server broadcasts a
  transform/health/ammo snapshot at 20 Hz (`receive_state`), plus one-shot
  events like shots and kills. Receivers return early when
  `multiplayer.is_server()` so the server never overwrites its own truth.

### What the server decides

- Movement: the client sends its input vector, aim angles, and button states;
  the server runs the same `CharacterBody3D` movement for every player.
- Shooting: the client only says "I'm holding fire". The server raycasts from
  the player's **authoritative** position and aim, applies damage, and tells
  everyone about the muzzle flash.
- Ammo, reload timing, death, and respawn are server-side too.

### What the client does

- The local player predicts its own movement immediately (no reconciliation
  yet), so input feels instant.
- Remote players are interpolated toward the latest server snapshot with an
  exponential smoothing factor.
- Late joiners get a reliable full snapshot so they see players who joined
  earlier; disconnects are broadcast with a reliable RPC.

## Player model

Players are realistic CC0 infantry soldiers from **Grab3D** (digital camo,
helmet, plate carrier, pouches, knee pads), holding a rifle. The model ships
only walk/run clips, so idle/fire/reload/hit/death are posed procedurally.
Jumping uses real CC0 clips from Quaternius's Universal Animation Library —
take-off, in-air loop and landing — retargeted onto the soldier's skeleton at
runtime. A subtle blue/red team tint is applied to the uniform texture.

The local player hides the body and keeps only the first-person weapon
viewmodel; remote players show the full soldier. Choose **Team: Steel Blue** or
**Team: Rust Red** in the menu — the tint is replicated to all clients.

Full details, license, and asset paths are in `docs/PLAYER_MODEL_PLAN.md`.

## Weapons

Three CC0 realistic weapons from the Mega Weapon Pack (see
`docs/ROADMAP.md` / `assets/models/weapons/LICENSE.txt`):

| Slot | Weapon | Damage | Fire rate | Magazine |
| --- | --- | --- | --- | --- |
| 1 | Rifle | 25 | 0.14 s | 30 |
| 2 | SMG | 15 | 0.075 s | 35 |
| 3 | Shotgun | 12 × 8 pellets | 0.75 s | 8 |

Stats live in `resources/weapons/*.tres`; the server owns ammo, reload and
fire rate, and weapon switching is a server-validated RPC. HUD shows the
current weapon and ammo.

## Combat feedback

Confirmed hits show a hit marker and floating damage number; taking damage
shows a directional arrow and a hurt sound. Every shot spawns a brief tracer
line to its impact point, reloads/pickups/deaths have sounds, and the camera
tilts on death before respawn. All effects are driven by server RPCs, so
clients cannot fake hits. Sounds are small locally generated WAVs in
`assets/audio/` and play through the `Sound` autoload.

## Pickups & grenades

Four server-authoritative pickups sit in the arena: two health packs (+30 HP,
15 s respawn) and two ammo crates (refill all weapons, 15 s respawn). They hide
and reappear on every client via reliable RPCs.

Each player starts with 2 grenades. **G** throws one with an arc, bounce and
2 s fuse; the server resolves a 5 m radius explosion with linear damage
falloff and replicates the grenade position/explosion to clients.

## Match flow

Hosting starts a team-deathmatch-style round automatically: a 3 s countdown,
then play until 20 kills or 5 minutes. Team scores and the timer are shown at
the top center; hold **Tab** for the full scoreboard. The match-end screen shows
the winner and a new round starts after 5 s. All scoring is server-authoritative
in `scripts/match.gd`.

## Next steps

The development plan is in `docs/ROADMAP.md`. Milestones 1 (match flow/scoring)
through 4 (match flow, weapons, pickups/grenades, combat feedback) are done;
next are netcode hardening and delivery.

## Known limitations

This is a learning prototype, not shippable netcode:

- No lag compensation, reconciliation, or client-side hit prediction.
- No interpolation buffer or tick-rate simulation (uses `_physics_process`).
- No authentication, input sanity validation, or NAT punchthrough.
- Single arena, one weapon, one life system.

See `docs/ROADMAP.md` for the planned work.
