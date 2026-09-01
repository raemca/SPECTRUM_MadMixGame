# Level format manual — Mad Mix Game (ZX Spectrum 48K)

*[Leer esto en español](manual_niveles.md)*

*Reverse engineering, analysis and documentation: Rafael Eduardo Martín Candial (raemca@hotmail.com)*

> Source: `src/madmix_body.asm` (`CARGAR_NIVEL`, `TABLA_NIVELES`, the 15
> bodies + 3 level headers, `INICIALIZAR_ITEMS_NIVEL`,
> `VERIFICAR_FIN_NIVEL`, `INICIAR_DEMO`). For the chronicle of how each
> piece was discovered, see `FINDINGS.md`; this document assumes
> everything is already identified and explains the final result in an
> orderly way.

## 1. What this is and what it is NOT

This manual explains how the game's 15 levels are built — the tile
grid format, how they're loaded into memory, and how the game detects
that a level is complete — and how to edit them with `mmlvl_tool.py`.

**It is not** a level system with rich metadata or an in-game visual
editor: each level is, literally, a grid of bytes (one byte = one
tile) plus a fixed 20-byte record with a handful of parameters
(starting position, how many enemies, pellet target...). There are no
layers, no entities with their own per-level position outside the item
tables already documented in `manual_motor_colision_ia.md` — enemies
always "appear" at the same reference point in the level, never at
their own per-level coordinates.

**The format matches, field by field, the one in the sister MSX
project** — same 20-byte record, same figure of 15 real levels with a
dead/duplicate record 0, same tile wildcard. This isn't a coincidence:
this Spectrum version is the **original**; MSX is a *port*, and the
level-data format is one of the pieces that got copied unchanged
between platforms (see §9 for a concrete, verifiable case of this
inheritance).

## 2. General architecture

```
$6007 ─── REGISTRO_NIVEL_CUERPO_PTR (20 bytes)  -- working copy of the current level's record (§3)
$883B ─┬─ CARGAR_NIVEL                          -- loader (§6), called from REINICIAR_PARTIDA/VERIFICAR_FIN_NIVEL
       └─ CALL INICIALIZAR_ITEMS_NIVEL ($87BC)  -- 2nd step, places enemies/items (§7)
$88E0 ─── TABLA_NIVELES (320 bytes = 16 records x 20 bytes)  -- level catalogue (§4)
$677F.. ─── CUERPO_L01..CUERPO_L15 + CABECERA_7F1F/_7F7F/_8000 -- the real data (§4.1)
$9D8B ─── VERIFICAR_FIN_NIVEL -- detects target reached, advances level (§8)
$8EB3 ─── INICIAR_DEMO -- the menu's "DEMO" mode: plays back 4 sample levels (§10)
```

## 3. The level record (20 bytes)

Each level is described by a 20-byte record. When loaded, it is copied
whole into a fixed working area (`REGISTRO_NIVEL_CUERPO_PTR`, `$6007`)
— whatever values are "factory-set" there in the compiled `.BIN` are
just a snapshot of the last level processed at compile time, with no
meaning of their own (the real game always overwrites them when
loading the first level).

| Offset | Field | Content |
|---|---|---|
| 0-1 | `REGISTRO_NIVEL_CUERPO_PTR` | pointer to the level's BODY (the tile grid, variable rows) |
| 2-3 | `REGISTRO_NIVEL_CABECERA_PTR` | pointer to the fixed HEADER (3 rows, shared across several levels) |
| 4-5 | `REGISTRO_NIVEL_PIE_PTR` | duplicate of the above — the header is ALSO copied below the body, as a "footer" |
| 6 | `REGISTRO_NIVEL_FILAS` | number of VARIABLE rows in the body (15-23); total playable rows = 3 + this value (the 3 fixed rows come from the top/bottom header) |
| 7 | (`$600E`, no confirmed label) | strong hypothesis, not fully confirmed: "next life extra" warning flag — `COMPROBAR_AVISO_ULTIMA_VIDA` reads this same address to decide whether to draw the warning |
| 8 | `REGISTRO_NIVEL_CONTADOR_PELMAZOIDES` | number of active "Pelmazoides" (ghosts) this level, max 8 — confirmed via `HNDLR_PELMAZOIDE` (see `manual_motor_colision_ia.md`) |
| 9 | (`$6010`, candidate `CONTADOR_MARICOCOS`) | number of active "Maricocos", max 2 — candidate, no real label yet |
| 10 | (`$6011`, candidate `CONTADOR_REPUGNANTOSOS`) | number of active "Repugnantosos", max 8 — candidate, no real label yet |
| 11 | `REGISTRO_NIVEL_DURACION_PARPADEO` | duration in frames of a special mode (power ball/hippo) |
| 12 | `REGISTRO_NIVEL_LOSETA_COMODIN` | real tile that replaces the body's `$3C` wildcard (§5) |
| 13-14 | `REGISTRO_NIVEL_FILA_COLUMNA` | starting reference row/column (spawn position of the hero and of the items), in sub-pixel units |
| 15-16 | (`$6016`-`$6017`, unidentified) | an exact multiple of 4 across all 16 records — same sub-pixel unit as the reference row/column; unconfirmed candidate for a second coordinate |
| 17 | `REGISTRO_NIVEL_ICONO_HUD` | HUD character/icon code for this level |
| 18-19 | (`$6019`, candidate `OBJETIVO_BOLAS`) | "pellets to eat" target to complete the level (§8) — function fully confirmed despite lacking its own label |

## 4. `TABLA_NIVELES` — the 15-level catalogue

**320 bytes = 16 records of 20 bytes** (`$88E0`-`$8A20`). The first one
(index 0) is a **dead record**, an exact byte-for-byte duplicate of
level 1 (same `CUERPO_L01`, same header, same remaining 17 fields) —
never reached in normal play: `NIVEL_ACTUAL` starts at 1
(`REINICIAR_PARTIDA`) and `VERIFICAR_FIN_NIVEL` (§8) resets it to 1
after 15, never passing through 0. Also confirmed independently by
`src/data/niveles/`: there is no `body_l00.bin`, only `body_l01.bin`
through `body_l15.bin`. Indices 1-15 are the 15 real levels — there is
no "extra" or "hidden" level in this version.

Rewritten as native assembler data (body/header pointers as real
labels, resolved by the assembler itself) instead of a binary
`INCBIN` table.

Exhaustive cross-check (`tools/mmlvl_tool.py check-bolitas`): for all
16 records, the real count of ball-carrying tiles in each body matches
EXACTLY the declared pellet target — validating table, pointers and
tile-type catalogue all at once.

### 4.1 The data files: 15 bodies + 3 shared headers

`src/data/niveles/*.bin` — one file per unique block of data:

- **15 bodies** (`body_l01.bin` through `body_l15.bin`): each level's
  variable grid, 15-23 rows × 32 columns. Their position in memory does
  NOT follow numeric level order (e.g. `CUERPO_L09` sits physically
  before `CUERPO_L05`) — a vestige of the original 1988 composition
  order, with no functional meaning.
- **3 shared headers** (`header_7f1f.bin`, `header_7f7f.bin`,
  `header_8000.bin`, 96 bytes each = 3 rows × 32), reused across
  several levels at once — memory economy: they are the maze's
  top/bottom borders, and several levels share exactly the same border:
  - `CABECERA_8000`: levels 0, 1, 2, 3, 6, 9, 10, 11, 14, 15 (10 uses)
  - `CABECERA_7F1F`: levels 4, 5, 7, 12, 13 (5 uses)
  - `CABECERA_7F7F`: level 8 (1 use)

  Named after their own Spectrum address (different from MSX's names,
  which use its own addresses like `CABECERA_50BC`) — same spirit of
  reuse, different addresses per platform.

Each byte in the grid is a **tile index** (bits 0-6, see
`src/data/img/tiles/*.til`, catalogue 00-90) with **bit 7**'s meaning
unconfirmed at runtime (`CARGAR_NIVEL` always clears it when copying
to the active buffer) but genuinely PRESENT in the original binaries —
which is why `mmlvl_tool.py`'s text format preserves it byte for byte
instead of discarding it.

### 4.2 The `$3C` wildcard and the "lap"-based alternation

When copying the body, `CARGAR_NIVEL` replaces every tile with value
`$3C` (60, the "wildcard", same literal value as MSX) with the real
value set in `REGISTRO_NIVEL_LOSETA_COMODIN` (offset 12) — so the same
body pattern can look different depending on the level without
duplicating data. The substitution is **not unconditional**: on the
first full lap around the cycle of 16 records
(`CONTADOR_VUELTAS_NIVELES=0`), wildcards are copied as-is, with NO
substitution. On later laps, they are substituted according to the
**parity** of the count of wildcards found so far in that body,
compared to the lap number — in practice, on lap 1 half of the `$3C`
occurrences (the even-indexed ones) become the level's wildcard tile
while the other half stay `$3C`; from lap 2 onward, every occurrence
gets substituted. Visual variety in long games that loop more than
once through the level cycle. The wildcard only applies to the BODY —
headers are always copied as-is, with no `$3C` check.

## 5. Loading a level: `CARGAR_NIVEL` (`$883B`, 165 bytes) step by step

Called from `REINICIAR_PARTIDA`/`VERIFICAR_FIN_NIVEL` whenever a new
level is needed:

1. Locates `NIVEL_ACTUAL`'s record in `TABLA_NIVELES` (20 bytes ×
   level number) and copies it whole into the working area (§3).
2. Copies the header (96 bytes) into the **active level buffer, fixed
   address `$FC60`**, **above** the body (see §9 about this address).
3. Copies the body (`REGISTRO_NIVEL_FILAS` × 32 bytes, computed with 5
   `ADD HL,HL` = ×32), clearing each tile's "eaten" bit 7 and applying
   the wildcard substitution (§4.2).
4. Copies the SAME header again, **below** the body (as a "footer") —
   the maze ends up symmetric top/bottom with the same border.
5. Resets `CONTADOR_BOLAS_COMIDAS` to 0, computes the screen address of
   the initial reference point (the pellet-flash position), clears all
   special-mode flags, restores the default HUD colour
   (`COLOR_ACTUAL`/`COLOR_GUARDADO = $78`), writes the level's HUD
   icon, sets the camera position (`POSICION_ACTUAL_CAMARA = $1018`),
   and calls `INICIALIZAR_ITEMS_NIVEL` (§6).

## 6. `INICIALIZAR_ITEMS_NIVEL` (`$87BC`) — enemy/item respawn

Called both from `CARGAR_NIVEL` (full level load) and when re-entering
after losing a life (without reloading the maze):

- Places all 8 entries of `TABLA_ITEMS_PELMAZOIDE`, the 2 of
  `TABLA_ITEMS_MARICOCO`, and the 8 of `TABLA_ITEMS_REGPUNANTOSO` at
  the reference point (`REGISTRO_NIVEL_FILA_COLUMNA`), clearing their
  sub-position — they all "respawn" at the same exit point. How many
  instances are actually **active** that level isn't decided by this
  routine (it always resets each table's maximum) but by the level
  record's counters (offsets 8-10, §3), which each item type's handler
  uses to limit how many it actually processes and draws each frame.
- Also clears the warning/flash queue (`TABLA_RANURAS_AVISO`, 4 slots)
  and resets movement direction/timers — except with the "tool" mode
  (drill-phone) active, which starts with a special value (`$0E`).
- A second entry point, `INICIALIZAR_PARCIAL_ITEMS_NIVEL`, only clears
  `TABLA_PISTAS_TANQUE_AVION` (3 slots) — used when the rest of the
  reset doesn't need repeating.

## 7. Detecting the end of a level: `VERIFICAR_FIN_NIVEL` (`$9D8B`)

Checked every frame inside the main loop:

```
VERIFICAR_FIN_NIVEL:
    CALL ACTUALIZAR_PARPADEO_BOLA
    LD HL,(CONTADOR_BOLAS_COMIDAS)
    LD DE,(OBJETIVO_BOLAS)      ; $6019, offset 18-19 of the level record
    AND A
    SBC HL,DE
    JR NZ,VERIFICAR_ENTRADA     ; level still in progress
    ...
```

1. Compares `CONTADOR_BOLAS_COMIDAS` against the active level record's
   target. If it doesn't match, the level is still ongoing.
2. If it matches: increments `NIVEL_ACTUAL`. If it reaches 16 (`$10`,
   i.e. level 15 was just completed), resets it to 1 and increments
   `CONTADOR_VUELTAS_NIVELES` (§4.2) — the cycle of 15 levels starts
   over. Otherwise, it simply continues with the next record.
3. Triggers the HUD icon/colour flash and jumps to
   `PANTALLA_PRESENTACION_NIVEL` (reloads the HUD for the new level,
   which in turn leads into `CARGAR_NIVEL`).

**What counts as a "pellet"**: not just regular pellets
(`HNDLR_BOLITA_NORMAL`) — the 4 "auto-hero" arrow handlers
(`HNDLR_AUTOCOCO_ARRIBA`/`_ABAJO`/`_IZQUIERDA`/`_DERECHA`, which also
force a movement direction onto the hero) ALSO increment
`CONTADOR_BOLAS_COMIDAS` when stepped on, so a level's real target
mixes both tile types — exactly the same criterion `check-bolitas` in
`mmlvl_tool.py` uses (`BALL_TILES`: 3 graphic indices for the regular
pellet + 4 for the arrows).

## 8. `$FC60`: a concrete case of MSX ↔ Spectrum inheritance

No bug of its own has been detected in the Spectrum reconstruction —
the recompiled binary is 0 differences / 48485 bytes identical to the
original `.tzx` at all times. But there is a verifiable, curious piece
of lineage evidence: `CARGAR_NIVEL` uses the fixed address **`$FC60`**
as the active level buffer — the EXACT SAME address the MSX port's
**original v1.0** used, before its v2.0 patch moved it to `$FC50` to
fix a bug of its own (the "level 13 pellet-counter bug", documented in
the MSX project's `FINDINGS.md`). The same `$FC60` address also
reappears in the reference point's screen-position calculation.

This is consistent evidence that **the Spectrum tape is the
ORIGINAL** and that the MSX v1.0 port inherited this address literally
without adapting it, before having to patch it in its own v2.0 because
of a bug specific to that platform. **Unconfirmed**: there is no record
of the Spectrum actually suffering a similar adverse effect on level 13
(or any other) — nobody has verified in an emulator whether `$FC60`
causes here the same problem it caused on MSX before its patch. A
reasonable open question, not a closed fact.

## 9. The menu's "DEMO" mode: `INICIAR_DEMO` (`$8EB3`, 162 bytes)

Different from actually playing: the main menu offers a "5 DEMO"
option that plays back, without player input, **4 sample levels** from
its own table (`TABLA_PERFILES_DEMO`, `$8F49`, 4 entries `[level,
script pointer]`):

```
level 1 -> $DBE0 (GUION_DEMO_NIVEL1, 64 B)
level 2 -> $DC20 (GUION_DEMO_NIVEL2, 94 B)
level 4 -> $DC90 (GUION_DEMO_NIVEL4, 66 B)
level 5 -> $E380 (GUION_DEMO_NIVEL5, 88 B)
```

Level 3 has no demo profile of its own — only 1, 2, 4 and 5 are
cycled. For each one: sets `NIVEL_ACTUAL`, sets `VIDAS_RESTANTES=0`,
loads the level (the very same `CARGAR_NIVEL`/`INICIALIZAR_ITEMS_NIVEL`
as real play, with no special demo variant), and plays back a **demo
script** — a sequence of `[frame threshold, direction]` pairs in
decimal, ended with the `$FF,$FF` sentinel, which replaces real
keyboard/joystick reading by feeding the direction directly to
`MOTOR_MOVIMIENTO_COLISION` — it isn't procedural, it's prerecorded
joystick input, byte for byte. A profile ends when its script runs out
or when any key is pressed (`ABORTAR_DEMO`); after the 4th profile, it
aborts.

There are **6 orphan demo scripts** with the same format but no
`TABLA_PERFILES_DEMO` index referencing them (`GUION_DEMO_SINREF_1`
through `_6`) — candidates for discarded takes or an older version of
the demo cycle, with no confirmed caller. Historical correction note
from the project's own investigation: at one point these scripts'
range was mischaracterised as "sound-generator data" due to superficial
format similarity — corrected afterwards once confirmed they feed the
movement engine, not the speaker (see `manual_driver_sonido.md` §2.3
for the full methodological warning).

## 10. Tool: `tools/mmlvl_tool.py`

```
py tools/mmlvl_tool.py disasm file.bin file.txt   # binary -> editable text grid
py tools/mmlvl_tool.py asm file.txt file.bin      # text -> binary (to rebuild the game)
py tools/mmlvl_tool.py roundtrip file.bin         # verifies disasm+asm yields the same binary
py tools/mmlvl_tool.py roundtrip-all folder/       # same, for every .bin in a folder
py tools/mmlvl_tool.py check-bolitas file.txt LEVEL  # counts pellets in the .txt and compares
                                                       # against that level's real target in TABLA_NIVELES
```

A direct adaptation of the equivalent MSX tool — the 18 files in
`src/data/niveles/` are byte-for-byte identical to MSX's. Text format:
a fixed 32-column hex grid, variable rows auto-detected from file
size, with a header (`; filas=N columnas=N`) repeating the exact size.
`check-bolitas` is the most useful check when editing a level: it
reads the real target directly from `TABLA_NIVELES` in
`madmix_body.asm` (no separate manifest file that could drift out of
sync) and counts the "pellet" tiles (regular + auto-hero arrows, §7)
in the `.txt` — if they don't match, the level is unfinishable (it
would compile without error, but could never be completed by playing).

> ⚠️ **Real editing limit** (same pattern as sound, see
> `manual_driver_sonido.md` §9): each `.bin` is compiled with a fixed
> `INCBIN` address. You can freely change the VALUE of any tile.
> **Do NOT add or remove rows or columns**: the tool's own
> `assemble()` explicitly rejects any size change — the file is
> referenced by an `INCBIN` whose size depends on its position in the
> memory map; if it changes, everything that follows in
> `madmix_body.asm` shifts address.

## 11. Confidence and open items

The level record's structure, the 16-entry table, and the
load/end-detection mechanism are verified 100% against the real
disassembly and cross-validated with `check-bolitas` across all 16
records. Open points:

- The record's offset-7 field (`$600E`): a strong hypothesis of "extra
  life warning flag" (consistent with the real read in
  `COMPROBAR_AVISO_ULTIMA_VIDA`), without additional formal
  confirmation.
- The offset 9/10 counters (Maricoco/Repugnantoso): candidates without
  a real label yet, unlike offset 8's (Pelmazoides), which is confirmed
  more strongly.
- The offset 15-16 field: only confirmed to be a multiple of 4 across
  all 16 records (same sub-pixel unit as the reference position) — no
  hypothesis of meaning beyond "candidate".
- The wildcard substitution's parity mechanism (§4.2): the mechanics
  are confirmed by reading the code, but the "why" of the odd/even
  scheme isn't reasoned about in any project comment.
- The 6 orphan demo scripts (§9): no known trigger, low expected value
  in investigating further.
- Whether `$FC60` causes any adverse effect on real Spectrum hardware
  analogous to MSX v1.0's level-13 bug (§8) — unverified in an
  emulator.

## 12. Further reading

- `FINDINGS.md` — every level-related section, the 20-byte record field
  by field, and the `$FC60` inheritance with MSX, in chronological
  order.
- `manual_motor_colision_ia.md` — what enemies/items do once the level
  is already loaded (this manual only documents how the level is built
  and loaded, not the gameplay logic within it).
- `recursos/graficos.html` — catalogue of the 91 already-identified
  maze tiles, useful as a reference while editing a level.
