# Roadmap — Next Phase

Focus: **gameplay features** + **match structure**, delivered as medium
milestones. Each milestone ends with a playable build and headless tests.

Current baseline: authoritative client/server, 2–8 players, hitscan rifle,
3 s respawn, team colors, realistic soldier with real jump clips, kill feed.

---

## Milestone 1 — Match flow & scoring ✅ done

Goal: turn the endless deathmatch into an actual match with a beginning and end.

- [ ] New `scripts/match.gd` (autoload or child of Main), server-authoritative
      state machine: `LOBBY → COUNTDOWN → PLAYING → ROUND_END → MATCH_END`.
- [ ] Configurable rules: score limit (default 20 kills), time limit (5 min),
      respawn delay (3 s, already in `player.gd`).
- [ ] Team scores + per-player kills/deaths, tracked on the server only.
- [ ] Replicate scoreboard data to clients (new snapshot fields or a dedicated
      reliable RPC on state transitions).
- [ ] Scoreboard UI (hold Tab): name, team, kills, deaths; always-on compact
      score at top center during play.
- [ ] Countdown overlay before the round and a match-end screen with winner
      and a "play again" reset.
- [ ] Reset positions/health/ammo/scores on match restart.

Acceptance: two clients can play a match to 20 kills, see the winner, and
restart without desync. Headless test simulates kills and checks scores/win.

Files: `scripts/match.gd`, `scripts/main.gd`, `scripts/hud.gd`, `scripts/menu.gd`,
`scenes/main.tscn`, new `scenes/scoreboard.tscn`.

---

## Milestone 2 — Loadouts & weapons ✅ done

Goal: more than one gun, with server-side validation.

**Models found and downloaded (CC0, realistic modern style, consistent set):**
- Rifle — `assets/models/weapons/rifle.glb` ([source](https://3dassets.dev/assets/mega-weapon-pack-standard-rifle-94762172)), 38k tris, mag/charge clips
- SMG — `assets/models/weapons/smg.glb` ([source](https://3dassets.dev/assets/mega-weapon-pack-bullpup-smg-b2a1f487)), 36k tris, mag/charge clips
- Shotgun — `assets/models/weapons/shotgun.glb` ([source](https://3dassets.dev/assets/mega-weapon-pack-bullpup-shotgun-loadout-0f97efcb)), 45k tris, pump clips
- License: `assets/models/weapons/LICENSE.txt`

Note: the source GLBs used `KHR_mesh_quantization`, which Godot 4.7 cannot
import. They were converted to plain float attributes locally so they import
cleanly; geometry/textures/animations are unchanged.

- [ ] `resources/weapon_data.tres` resources: name, damage, fire interval,
      magazine, reload time, range, pellets (shotgun), viewmodel path.
- [ ] Three weapons from the CC0 Toolbench kit already downloaded:
      Rifle (current), SMG (fast/low damage), Shotgun (pellets/short range).
- [ ] Weapon switching with 1/2/3; active weapon index replicated in state
      snapshots; server validates switch timing.
- [ ] Server owns fire rate, ammo, reload, and pellet spread for every weapon.
- [ ] Hitscan returns multiple hits for shotgun; damage applied once per pellet.
- [ ] HUD shows weapon name + ammo; quick-switch animation on the viewmodel.

Acceptance: all three weapons fire, reload, and kill correctly over the
network; no client can fake ammo or fire rate. Headless test verifies each
weapon's damage/ammo behavior.

Files: `resources/weapons/`, `scripts/player.gd`, `scripts/player_body.gd`,
`scripts/hud.gd`, `assets/models/squad/weapon_*.glb`.

---

## Milestone 3 — Pickups & grenades ✅ done

Goal: arena interactivity and a second damage source.

- [ ] Server-authoritative pickups: health pack (+25 HP) and ammo crate,
      fixed spawn points, respawn timers, replicated visibility.
- [ ] Pickup detection on the server using simple distance checks.
- [ ] Grenades (key G): server-thrown projectile with gravity/bounce, fuse,
      explosion radius damage with falloff; replicated position for clients.
- [ ] Visuals: pickup meshes, grenade mesh, explosion flash + puff.
- [ ] HUD: grenade count, pickup notification.

Acceptance: pickups respawn on schedule; grenades damage only within radius;
headless test checks pickup timer and explosion damage falloff.

Files: `scripts/pickup.gd`, `scripts/grenade.gd`, `scripts/arena.gd`,
`scripts/player.gd`, `scenes/pickup.tscn`, `scenes/grenade.tscn`.

---

## Milestone 4 — Combat feedback ✅ done

Goal: make hits and deaths readable.

- [ ] Hit marker + damage number on the client when the server confirms a hit.
- [ ] Flinch already exists (`hit` clip); add directional damage indicator.
- [ ] Tracer lines from muzzle to impact, brief and cheap.
- [ ] Death camera stays with the body for 1 s, then respawn.
- [ ] Simple audio: fire, reload, hit, death, pickup (CC0 freesound or generated).

Acceptance: every confirmed hit gives visual feedback; no feedback on misses.

Files: `scripts/hud.gd`, `scripts/player.gd`, `scripts/player_body.gd`,
`assets/audio/`.

---

## Later (after this phase)

These are important but deliberately deferred until the game is fun:

1. **Netcode hardening** ✅ done — sequence numbers on client input; server
   discards stale inputs and echoes the last processed sequence in state;
   local client replays unacknowledged inputs from authoritative state;
   remote players interpolate from a 100 ms snapshot buffer; hitscan tests
   against target positions recorded at the time the shot input arrived.
2. **Maps & modes** — second arena, objective mode (capture/control point).
3. **Delivery** — export presets for dedicated server + client, CI headless
   tests, final docs pass.

---

## Working rules for each milestone

1. Implement on the server first; clients only display and send input.
2. Add a headless test before declaring a milestone done.
3. Keep all RPCs following the existing authority rule:
   client→server `any_peer` + sender check, server→client `authority`.
4. Update `README.md` when a milestone changes controls or rules.
