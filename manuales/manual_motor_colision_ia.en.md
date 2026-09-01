# Collision/AI engine manual — Mad Mix Game (ZX Spectrum 48K)

*[Leer esto en español](manual_motor_colision_ia.md)*

*Reverse engineering, analysis and documentation: Rafael Eduardo Martín Candial (raemca@hotmail.com)*

> Source: `src/madmix_body.asm` — `LEER_ENTRADA` (`$9AC6`),
> `MOTOR_MOVIMIENTO_COLISION` (`$60CD`), `TABLA_MANEJADORES_LOSETA`
> (`$6266`), `MOTOR_MOVIMIENTO_ITEM` (`$81BC`) and the 3 moving-item
> handlers. For the chronicle of how each piece was discovered, see
> `FINDINGS.md`; this document assumes everything is already
> identified and explains the final result in an orderly way — except
> one point (§7) explicitly flagged as this session's reasoned
> synthesis, not yet a fact closed by the project, since it hasn't been
> verified by actually playing the rebuilt `.tzx` in an emulator.

## 1. What this is and what it is NOT

This manual explains the movement/collision engine: how player input
is read (keyboard, Kempston, Sinclair), how the engine decides what to
do on reaching each tile type, how the player and the 3 types of
moving enemy/item move through the maze, and what happens when a
special item is eaten or an enemy is touched.

**It is not** a physics engine nor real pathfinding (BFS/A\*): the 3
moving-item types decide direction with a very simple tabulated
heuristic — bias towards keeping the previous direction, choosing
among the free directions when that isn't possible, with a random
component — the same simplified design as classic Pac-Man, identical
to the sister MSX project's.

## 2. Reading player input: `LEER_ENTRADA` (`$9AC6`)

Three selectable control schemes from the menu
(`PROCESAR_MENU_CONTROLES`, `$8A20`), set in `MODO_ENTRADA` (`$91B9`):

- **`MODO_ENTRADA=0` — QAOP keyboard**: Topo Soft's classic scheme —
  Q=up, A=down, O=left, P=right (`TABLA_TECLAS_MODO_0`, `$9B45`,
  redefinable from the "4 REDEFINE KEYS" menu).
- **`MODO_ENTRADA=1` — Sinclair joystick (emulated via keyboard)**:
  scans keys 1-5 (right port) and 0,9,8,7,6 (left port) of the
  Interface 2, merged with `OR` — either Sinclair port triggers the
  same 4 directions.
- **`MODO_ENTRADA=2` — real Kempston joystick**: direct hardware read,
  `IN A,($1F)`, bypassing the keyboard scan entirely. Kempston's bit
  layout (bit0=right, bit1=left, bit2=down, bit3=up) matches the QAOP
  order exactly, so the port byte is used without reordering.
- **`MODO_ENTRADA≥3`**: an alternate key scheme
  (`TABLA_TECLAS_MODO_3`) with no confirmed purpose — candidate for a
  redefinable variant or leftover development test (§10).

The 3 keyboard-based modes share the same scanning engine
(`ESCANEAR_TABLA_TECLAS`, 5 reads of `IN A,($FE)` on the ULA's port),
and all go through a shared pause check
(`TABLA_TECLA_PAUSA`) and an unusual **anti-jitter** mechanism:
`RESOLVER_CONFLICTO_VERTICAL`/`RESOLVER_CONFLICTO_HORIZONTAL` detect
whether two opposite directions are being pressed at once (up+down or
left+right) and, if so, replace the contradictory pair with the
previous frame's bits — preventing a keyboard bounce from producing a
spurious direction.

An accumulator (`ACUMULADOR_ENTRADA`, `$9B81`) gathers the scan result
before merging it with the pause bit. When demo mode is active
(`INDICE_CICLO_NIVELES`, `$8F43`), the direction doesn't come from this
routine at all: it comes from a prerecorded script (see
`manual_niveles.md` §9).

## 3. Player movement: `MOTOR_MOVIMIENTO_COLISION` (`$60CD`)

Called every frame from `BUCLE_PRINCIPAL_JUEGO` and from
`BUSCAR_COLUMNA_HUD`. Steps, in order:

1. Reads the direction (`LEER_ENTRADA` or the demo script) and stores
   it in `DIRECCION_SIN_PROCESAR` (`$6029`).
2. **Direction buffering**: `FLAG_DIRECCION_NUEVA`/
   `COPIA_FLAG_DIRECCION_NUEVA` remember whether a new direction
   arrived this frame, so it can be applied as soon as the player is
   grid-aligned instead of being discarded if pressed "too early" — the
   classic pattern in Pac-Man clones.
3. If `DIRECCION_FORZADA` (`$602D`, set by an "auto-hero" arrow) is
   active, it overrides the player-chosen direction.
4. **Grid alignment**: checks position modulo 4 (4×4 sub-pixel cells)
   to decide whether the player can turn now or must wait to reach the
   centre of the current cell.
5. Checks the tile one step ahead in the chosen direction
   (`CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION`); if it's
   impassable, it retries with the previous direction — allowing the
   player to "keep going straight" if the desired turn isn't possible
   yet.
6. Resolves the destination tile's handler (§4) and the player
   sprite's animation (`PUNTEROS_SUBTABLA_DIRECCION`, 4 per-direction
   animation subtables) — the result is stored in
   `SELECTOR_SPRITE_COMECOCOS` (`$6025`, whose bit 7 is the horizontal
   flip flag).

Key variables for this step: `DIRECCION_DE_MOVIMIENTO` (`$6024`),
`POSICION_ACTUAL_CAMARA` (`$602A`, initial value `$1018`),
`PUNTO_REFERENCIA_CAMARA` (`$6032`, the player position the 3 moving
item types use to chase/flee, §5).

## 4. Tile-type dispatcher: `TABLA_MANEJADORES_LOSETA` (`$6266`, 20 entries)

Reached by resolving the destination tile's type index
(`CALCULAR_INDICE_TIPO_LOSETA` + `TABLA_TIPOS_LOSETA`, `$9B85`, 91
bytes — one type byte per each of the 91 tiles in the catalogue).

| Index | Handler | What it does |
|---|---|---|
| 0 | `HNDLR_SUELO_NORMAL` | Normal wall/floor, no gameplay effect |
| 1 | `HNDLR_BOLITA_NORMAL` | Eats a pellet: replaces the tile with the wildcard, +1 point, +1 pellet eaten |
| 2 | `HNDLR_BOLITA_CLAVADA` | Pinned/locked pellet — needs the "tool" item before it can be eaten |
| 3-6 | `HNDLR_AUTOCOCO_ARRIBA`/`ABAJO`/`IZQUIERDA`/`DERECHA` | Forced-direction arrow: sets `DIRECCION_FORZADA`, +2 points, +1 pellet eaten (counts as a pellet for level completion) |
| 7 | `HNDLR_PISTA_COCOTANQUE` | Entry into a tank track — turns the player into the tank |
| 8, 9 | = `HNDLR_SUELO_NORMAL` (duplicate) | |
| 10 | `HNDLR_PISTA_COCONAVE` | Plane track — turns the player into the plane |
| 11 | `HNDLR_ITEM_SUELO` | Floor item (exact function not fully confirmed, §10) |
| 12 | `HNDLR_BOLA_PODER` | Special item: activates "enemies flee" mode (§6) |
| 13 | `HNDLR_HIPODOSO` | Special item: you trample enemies, can't eat pellets while it lasts (§6) |
| 14 | `HNDLR_EXCAVATOFONO` | Special "tool" item: lets you unpin locked pellets (§6) |
| 15, 16 | `HNDLR_SUELO_SIN_BOLA` | Resets the special mode tied to that tile |
| 17, 18 | `HNDLR_TRAMPILLA_ABIERTA_DERECHA`/`IZQUIERDA` | Trapdoor opening |
| 19 | `HNDLR_TRAMPILLA_CERRADA` | Trapdoor closing |

**Important rule**: if `MODO_ESPECIAL_ACTIVO` (`$6023`, §7) is active,
the type index is forced to 0 and the whole dispatch is diverted to
`TICK_MODO_ESPECIAL` instead of the real handler — while that short
countdown is running, **every tile effect is disabled**.

## 5. AI of the 3 moving-item types

They share the same direction-decision routine,
**`MOTOR_MOVIMIENTO_ITEM`** (`$81BC`). A 7-byte actor record: position
(X,Y), state/mode (offset 2, also used by `ACTIVAR_EFECTO_ITEM`, §6),
resolved direction, sub-position, animation phase.

Each handler is called after `GESTIONAR_SCROLL` every frame, and
**only if `FLAG_ENTRADA_BLOQUEADA` (`$9B84`) is 0** — the same flag
that blocks reading new input also blocks the movement/redraw of all 3
enemy types and the player itself (set, for example, during the
`BUSCAR_COLUMNA_HUD` animation at level start).

### 5.1 `HNDLR_PELMAZOIDE` (`$8142`) — "ghost"

Up to **8** active per level (`REGISTRO_NIVEL_CONTADOR_PELMAZOIDES`).
Computes `PUNTO_REFERENCIA_CAMARA` (the player's position, with a
fixed offset) for the AI to chase; when `MODO_ESPECIAL_CUENTA_ATRAS`
is about to expire, the sprite flickers (a visual warning that the
flee effect is about to end).

### 5.2 `HNDLR_MARICOCO` (`$83ED`) — "ladybug, refills pellets"

Up to **2** active per level. When grid-aligned, it checks whether the
tile underneath it is a "wildcard" that can regenerate into a pellet;
if the player has moved far enough away, it regenerates it (decrements
`CONTADOR_BOLAS_COMIDAS`, redraws the tile as a pellet,
`EVENTO_SONIDO_PENDIENTE=5`). It forces its state (record offset 2) to
`1` right before checking collision with the player.

### 5.3 `HNDLR_REGPUNANTOSO` (`$8504`) — "repugnantoso, turns pellets into locked ones"

Up to **8** active per level. The inverse effect of the ladybug: if it
detects a normal pellet underneath it and the player has moved far
enough away, it "plants" it as a locked pellet (the effect later undone
by the "tool" item). It forces its state to `2`,
`EVENTO_SONIDO_PENDIENTE=6`.

### 5.4 The shared direction-decision algorithm

1. **Chase/flee**: compares the item's position against
   `PUNTO_REFERENCIA_CAMARA`. If `MODO_ESPECIAL_FLAG` (`$6021`) is
   active, it inverts the delta — the enemy **flees** instead of
   chasing (only `HNDLR_BOLA_PODER` activates it, §6).
2. **Only at intersections** (grid-aligned cell) does it recompute the
   direction; otherwise it keeps the one already set.
3. It builds a 4-bit mask of free directions by checking
   `TABLA_TIPOS_LOSETA` in the 4 neighbouring cells.
4. If the "desired" direction is free, it's used. Otherwise,
   **`TABLA_ELECCION_DIRECCION`** (128 bytes, indexed by
   `free_bitmask` + previous direction class + a random bit) resolves
   the choice, biased towards **keeping the previous direction when
   possible**.
5. The random generator (`GENERAR_ALEATORIO`) uses the Z80's `R`
   register (memory refresh) as its entropy source.

There is no directed pathfinding: it's simple chasing by position delta
plus a tabulated continuity heuristic, with randomness — the same
simplified design as classic Pac-Man.

## 6. Special items and temporary modes

Eating each of the 3 special floor items:

- **`HNDLR_BOLA_PODER`** (tile 60): sets `MODO_ESPECIAL_FLAG=1`
  (enemies flee, §5.4), sets `MODO_ESPECIAL_CUENTA_ATRAS` to the
  level's duration (`REGISTRO_NIVEL_DURACION_PARPADEO`), changes the
  HUD colour, flags `MODO_ESPECIAL=1`.
- **`HNDLR_HIPODOSO`** (tile 61): same mechanics but without triggering
  the enemy flee, `MODO_ESPECIAL=2` — you "trample" enemies instead of
  avoiding them.
- **`HNDLR_EXCAVATOFONO`** (tile 62, "tool"): enables unpinning locked
  pellets (type 2), `MODO_ESPECIAL=3`.

**`TICK_MODO_ESPECIAL`**, called at the end of every tile handler,
decrements `MODO_ESPECIAL_CUENTA_ATRAS` every frame, picks the HUD icon
according to the active mode, and turns off the flags when it reaches
0 — this is the power-up's **visual** countdown, tied to the level's
duration.

**`ACTIVAR_EFECTO_ITEM`** (`$871C`) is the player/moving-item collision
point, called after drawing each of the 3 item types:

- Does nothing if `MODO_ESPECIAL_ACTIVO` (§7) is already running
  (debounce: only one trigger per "encounter").
- Checks whether the screen position where the item was just drawn
  falls inside a fixed window — the player is always centred on
  screen, it's the maze that scrolls, so "collision" here means "did
  the enemy get drawn right where the player always is?".
- If it collides and a power-up **is** currently active
  (`MODO_ESPECIAL≠0`): awards points (4 or 6, depending on the item's
  state) and triggers a flash warning + sound — the enemy "gets eaten".
- If it collides and **no** power-up is active: it enters
  `ACTIVAR_NUEVO_MODO_ESPECIAL`, which arms `MODO_ESPECIAL_ACTIVO` for
  42 or 47 frames (depending on which item type was touched) — see §7
  for what this countdown represents.

## 7. Player-enemy collision and losing a life

> ⚠️ This section documents a mechanism whose code is verified line by
> line, but whose **gameplay interpretation** (what it actually means
> for the player) is this investigation's reasoned synthesis, not yet
> a fact confirmed by playing the rebuilt `.tzx` in an emulator. Treat
> it as a well-founded hypothesis pending that verification (see §10).

The only life-loss mechanism found anywhere in the engine sits inside
`BUCLE_PRINCIPAL_JUEGO`, nested in the very same `MODO_ESPECIAL_ACTIVO`
check that `ACTIVAR_NUEVO_MODO_ESPECIAL` arms (§6):

```
LD A,(MODO_ESPECIAL_ACTIVO)     ; $6023
AND A
JR Z,VERIFICAR_FIN_NIVEL        ; if 0, nothing to decrement
DEC (HL)
JR NZ,VERIFICAR_FIN_NIVEL       ; if still >0 after decrementing, keeps counting
; --- only reached the frame the countdown just hit 0 ---
... restores colour, plays the special-mode-end jingle ...
LD A,(VIDAS_RESTANTES)          ; $603A
ADD A,delta                     ; delta at $6003, candidate -1
LD (VIDAS_RESTANTES),A
JP C,REINICIAR_ESTADO_NIVEL     ; lives remain -> respawn
... otherwise -> "ESTAS FRITO" (game over), back to the menu
```

In other words: **the engine's only life decrement happens when
`MODO_ESPECIAL_ACTIVO` expires** — there is no independent
player/enemy position check anywhere else in the file.

Combined with §6, the most coherent reading of the full mechanism is:
touching a `HNDLR_PELMAZOIDE` or a `HNDLR_REGPUNANTOSO` while no
power-up is currently active arms `MODO_ESPECIAL_ACTIVO` for 42-47
frames (under a second at 50 Hz); while that countdown runs, every
tile effect is disabled (§4) — a "frozen instant" of warning — and,
unless the player eats a real power-up first (which would divert
`ACTIVAR_EFECTO_ITEM` toward the scoring branch instead of the arming
branch), a life is lost when the countdown expires. This is consistent
with touching the "ladybug" (`HNDLR_MARICOCO`, benign) always forcing a
state (`1`) that `ACTIVAR_NUEVO_MODO_ESPECIAL` treats as "no effect" —
the ladybug can't kill the player; only the ghost and the
"repugnantoso" can.

## 8. The scoring system: `DIBUJAR_MARCADOR_PUNTOS` (`$9A01`)

Called whenever the score changes (from tile handlers and from
`ACTIVAR_EFECTO_ITEM`), not every frame:

- In demo mode, it draws a fixed text instead of the real score.
- In normal play: adds the received points to `PUNTUACION` (`$603C`).
  If it reaches 10000, the same special text is shown instead of the
  digits (candidate for a scoreboard cap). Otherwise it converts to
  text and draws the digits at the scoreboard's fixed position.

`BUSCAR_COLUMNA_HUD` (`$9CCB`) is a different mechanism — the HUD's
"column search" animation at the start of each level, unrelated to
collision scoring; it sets `FLAG_ENTRADA_BLOQUEADA` while it lasts.

## 9. Key shared state variables

| Address | Name | Role |
|---|---|---|
| `$600F` | `REGISTRO_NIVEL_CONTADOR_PELMAZOIDES` | Active ghosts this level (≤8) |
| `$6012` | `REGISTRO_NIVEL_DURACION_PARPADEO` | Level's visual power-up duration |
| `$6021` | `MODO_ESPECIAL_FLAG` | 1 = enemies flee (only `HNDLR_BOLA_PODER` sets it) |
| `$6022` | `MODO_ESPECIAL_CUENTA_ATRAS` | Power-up's visual duration, decremented in `TICK_MODO_ESPECIAL` |
| `$6023` | `MODO_ESPECIAL_ACTIVO` | Short countdown (42-47 frames); its expiry loses a life (§7); while ≠0, disables tile effects |
| `$6024` | `DIRECCION_DE_MOVIMIENTO` | Player's movement direction this frame |
| `$6029` | `DIRECCION_SIN_PROCESAR` | Raw input value before processing |
| `$602A` | `POSICION_ACTUAL_CAMARA` | Camera/player position (word) |
| `$602D` | `DIRECCION_FORZADA` | Direction imposed by an "auto-hero" arrow |
| `$602F` | `FLAG_DIRECCION_NUEVA` | Buffering: a new direction is pending |
| `$6032` | `PUNTO_REFERENCIA_CAMARA` | Player position used by the 3 item types' AI |
| `$6035` | `SEMILLA_ALEATORIA` | PRNG seed based on the `R` register |
| `$603A` | `VIDAS_RESTANTES` | Lives remaining |
| `$603C` | `PUNTUACION` | Accumulated score (word) |
| `$6040` | `MODO_ESPECIAL` | Currently active power-up (0=none, 1=power ball, 2=hippo, 3=tool) |
| `$8F43` | `INDICE_CICLO_NIVELES` | Active = demo mode |
| `$91B9` | `MODO_ENTRADA` | 0=QAOP keyboard, 1=Sinclair, 2=Kempston, 3=unconfirmed alternate |
| `$9B84` | `FLAG_ENTRADA_BLOQUEADA` | Blocks new input plus movement/redraw of all actors |
| `$9B85` | `TABLA_TIPOS_LOSETA` | 91 bytes, tile index → type (0-19) |

## 10. Confidence and open items

The tile dispatcher, the player movement algorithm, and the AI of the
3 moving-item types are verified by direct code reading, with near-
total instruction-by-instruction correspondence to the sister MSX
project. Open points:

- **The §7 interpretation as "life lost on touching an enemy"** is the
  top-priority piece to verify — recommended to play the rebuilt
  `.tzx` in an emulator and observe exactly what happens when touching
  each of the 3 moving-item types under every `MODO_ESPECIAL`
  combination.
- `TABLA_TECLAS_MODO_3` (`MODO_ENTRADA≥3`): no confirmed purpose.
- Tile 59 (`HNDLR_ITEM_SUELO`): function not fully confirmed, visually
  similar to tile 60 (power ball).
- The visual catalogue's text says the hippo mode is "no points", but
  the code does award points when "eating" an enemy during that mode —
  possibly a nuance the catalogue's description doesn't capture, or
  "no points" refers to eating pellets being blocked while it lasts;
  unreconciled.
- The line-by-line detail of the tank/plane track subsystem
  (`HNDLR_PISTA_COCOTANQUE`/`HNDLR_PISTA_COCONAVE`) is out of scope for
  this manual.
- `$6047`-`$605F` (30 bytes): unidentified, no code references them.

## 11. Further reading

- `FINDINGS.md` — every input, movement, tile-type and AI-related
  section, in chronological order.
- `recursos/flujo_programa.html` §3-4 — the tile dispatch table and the
  shared state variables in the context of the full game flow.
- `manual_niveles.md` — how enemies are placed when a level loads, and
  the demo-script mechanism that replaces `LEER_ENTRADA`.
- `manual_subsistema_grafico.md` — how each actor is drawn once this
  engine has decided where it should be (this manual only documents
  the WHAT and the WHEN).
- `recursos/graficos.html` — visual catalogue of the 91 already-
  identified maze tiles.
