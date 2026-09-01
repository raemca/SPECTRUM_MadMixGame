# Graphics subsystem manual — Mad Mix Game (ZX Spectrum 48K, ULA)

*[Leer esto en español](manual_subsistema_grafico.md)*

*Reverse engineering, analysis and documentation: Rafael Eduardo Martín Candial (raemca@hotmail.com)*

> Source: `src/madmix_body.asm` (actor engine, maze tile system, scroll,
> flush to real screen, colour/attributes). For the chronicle of how
> each piece was discovered, see `FINDINGS.md`; this document assumes
> everything is already identified and explains the final result in an
> orderly way.

## 1. What this is and what it is NOT

This manual explains how the game puts graphics on screen on a ZX
Spectrum 48K: how the ULA's video memory is laid out, how the maze is
drawn with its scrolling, how each character is composed, and — the
most elaborate part of the subsystem — how a **plain RAM working
canvas** (not the real screen) is flushed to video memory every frame
with a very particular low-level trick.

**A different starting point from the sister MSX project**: the MSX1
has a VDP with hardware sprites that the game chooses not to use; the
ZX Spectrum, on the other hand, **has no sprite hardware to use at
all** — the ULA only offers a 256×192 bitmap plus a colour-attribute
table, with no concept of a separate "graphic object". The practical
result is the same in both versions (manual blitting with mask +
pattern), but here it isn't a design choice: it's the only way to draw
a character that exists on the machine. This is the real technical
reason the MSX version "behaves like a Spectrum" (see MSX's
`manual_subsistema_grafico.md`, §1) — both versions implement, for
different reasons, exactly the same algorithm.

**It is not** an engine with hardware scroll or per-sprite attributes:
just like on MSX, the 4px camera scroll (§5) is pure software over a
RAM buffer, flushed to the real screen once per frame.

## 2. The hardware: the ULA in its standard display mode

Two memory zones mapped directly into the Z80's address space (no I/O
ports involved — unlike the MSX's VDP, the CPU writes pixels and
colour as if they were plain RAM):

| Zone | Address | Size | Content |
|---|---|---|---|
| Bitmap | `$4000`-`$57FF` | 6144 bytes | 1 bit per pixel (256×192), with the Spectrum's classic **interleaved** addressing (§6) — not linear row by row |
| Attributes | `$5800`-`$5AFF` | 768 bytes | 1 byte per character cell (32×24): ink/paper (3 bits each), bright, flash |

The only video-related I/O port is `$FE` (shared with keyboard and
tape), used only for the border colour — never for drawing anything
inside the screen. Everything else is direct writes through `HL`/`DE`
over the two zones above.

## 3. The two-pass actor engine: `MOTOR_ACTORES` + `DIBUJAR_ACTORES_PENDIENTES`

The heart of the subsystem — called to prepare every character
(Pac-Man-like hero, ghosts, ladybug, "repugnantoso", tank/plane
tracks, scoreboard...) that needs redrawing that frame. Just like on
MSX, the work is split into **two separate passes**, but here both live
in the same source file and are fully resolved:

### 3.1 First pass — `MOTOR_ACTORES` (`$91D0`)

1. **Filtering**: discards the actor if there are already 10 active
   (`$91C9`, this frame's actor counter, against `10`), if the sprite
   index is invalid (`B` against `64`), or if its column falls outside
   the visible window (`E` against `4` and `116`). **Fidelity note**:
   the `64` limit looks inherited unadjusted from MSX — the real
   sprite-pointer table (`PTR_TABLA_SPRITES`, `$9E8E`) only has room
   for **28 entries** (112 bytes) before hitting, with no gap, the
   text-font table (`$9EFE`); no real case using indices above 27 has
   been observed.
2. **Record allocation**: computes `IX = $9F9A + $91C9*10` — a 10-byte
   record inside `TABLA_ACTORES_ACTIVOS` (`$9F9A`, 100 bytes = 10
   actors × 10 bytes), and computes the real screen position with
   `CALCULAR_DIRECCION_PANTALLA` (§6), discarding the actor if its row
   falls outside the visible camera band.
3. **Flipping**: if the sprite needs a horizontal or vertical mirror (2
   bits in the control byte), it is applied BEFORE compositing, on a
   temporary copy — `VOLTEAR_PATRON_HORIZONTAL` (classic bit-by-bit
   inversion, `RLC`/`RRA` ×8 per byte) or the trio
   `CALCULAR_LIMITE_INTERCAMBIO`/`COMPROBAR_INTERCAMBIO_NECESARIO`/
   `BUCLE_INTERCAMBIAR_DATOS` (swaps two sprite-data regions for the
   vertical flip).
4. **Sub-pixel shift + writing into the pre-render buffer**: the ULA
   can only write one byte (8 pixels) at a time — just like the MSX
   engine, this implements a **0-to-7-bit** shift by rotating mask +
   pattern bit by bit across registers (`BUCLE_DESPLAZAR_DERECHA`/
   `_IZQUIERDA`, alternating register banks with `EXX` to process 2
   rows at once, via `BUCLE_FILA_ACTOR`/`ESCRIBIR_FILA_ACTOR`), but
   instead of blending directly against the real screen, **it writes
   the result into a dynamic pre-render buffer** starting at `$F701` —
   a bump-allocator: each actor appends its rows starting at the
   rolling pointer `$91CA` (left ready for the next actor), and `$91C9`
   (the same actor counter from filtering) is reset every frame by
   `RESET_CONTADOR_ACTORES`. The 10-byte record in
   `TABLA_ACTORES_ACTIVOS` stores both the real screen address
   (offset+2/+3) and the pointer into this pre-render buffer
   (offset+5/+6).

### 3.2 Second pass — `DIBUJAR_ACTORES_PENDIENTES` (`$945A`)

It does not draw at the moment `MOTOR_ACTORES` decides each actor's
position: it **queues** them, and this routine, called from
`TICK_REDIBUJADO_VBLANK` (right after syncing with `WAIT_VBLANK`, see
§7), draws ALL pending actors at once — a clear candidate for avoiding
flicker/tearing by drawing everything at the same instant of the
raster instead of spread across the frame.

It uses the same Z80 trick of reading data with `POP` instead of
`LD`/`INC`: it redirects `SP` to the pre-render buffer (`LD SP,HL`,
saving the real `SP` in `$91CC`) and, per actor, does **self-modifying
code**: the 3 clip-mask bytes from the record (offset 7-9) are
rewritten on the fly into 6 twin positions of `BLIT_ACTOR_PENDIENTE` —
normally those 6 positions are the `AND E`/`OR D`/`LD (HL),A` sequence
that composites the pixel onto the real screen, cell by cell of a 2×3
grid. `BC`/`IX` walk `TABLA_ACTORES_ACTIVOS` until the counter is
exhausted, and on finishing it restores `SP` and sets
`CONTADOR_ACTORES_ACTIVOS` (`$91C9`) to 0 — emptying the queue for the
next frame.

## 4. The maze tile system: a RAM canvas, not the real screen

Unlike actors, the maze isn't recalculated actor by actor: it is a
**plain RAM working canvas** (`$E404` onward) that gets updated tile by
tile and flushed to the real screen once per frame (§6). That memory
range **is not a dedicated zone**: it is the very same memory that
`BITMAP_MARCO_DECORATIVO` (`$E3F2`, 2992 bytes) occupied while the
loading-screen decorative frame was being drawn — as soon as
`CARGAR_MARCO_DECORATIVO` finishes decompressing it to the screen,
those bytes are no longer needed and `PREPARAR_TABLA_ESQUEMA_COLOR`
(§6) reuses that same memory as scratch working area. Typical memory
economy of a 48K Spectrum, not a zone reserved on purpose.

- **`MAPEAR_LOSETA_A_GRAFICO`**: given a camera/tile position, computes
  the real address of that tile's graphic
  (`GRAFICOS_LOSETAS + index×32` — each tile takes 32 bytes,
  `GRAFICOS_LOSETAS = $C600`) and copies it into the canvas. Along the
  way it toggles bit 7 of `TABLA_TIPOS_LOSETA[index]` when the level
  cell's raw byte itself has bit 7 set (candidate for "already
  visited/eaten tile"), although since real tile-type dispatch only
  looks at bits 0-4, this toggle has no observable effect on the game
  — a confirmed, harmless vestige.
- **`REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM`**: a FULL redraw of the
  canvas (walks the 36 visible tile rows calling
  `BUCLE_REDIBUJAR_FILA_VERTICAL`/`MAPEAR_LOSETA_A_GRAFICO`) — used
  when starting or changing level, not every frame.
- **`REDIBUJAR_LOSETA_BUFFER_VRAM`** (`$99BD`): updates a single tile
  (16×16 px) in the canvas — called by `DIBUJAR_CAMBIO_LOSETA` whenever
  a tile changes state in-game (e.g. when a pellet is eaten).
- **The actual flush to the screen is done exclusively by the
  mechanism in §6** — neither the tile redraw nor the scroll (§5) ever
  touch `$4000` directly; they only write to the canvas.

## 5. Software scrolling (4px, no scroll hardware)

`GESTIONAR_SCROLL` (`$967D`) decides the direction from the input bits
already read (`DECIDIR_DIRECCION_SCROLL`) and dispatches to one of 4
routines:

- **`SCROLL_ARRIBA`/`SCROLL_ABAJO`** (up/down): vertical shift by `LDI`
  blocks (24 chained `LDI`s ×2 passes, moving the entire canvas one
  character row) plus a new tile row redrawn at the end with
  `MAPEAR_LOSETA_A_GRAFICO`.
- **`SCROLL_IZQUIERDA`/`SCROLL_DERECHA`** (left/right): horizontal shift
  chaining **`RRD`/`RLD`** (the Z80 nibble-rotation instruction through
  `(HL)` and the low nibble of `A`) — the same classic 8-bit trick MSX
  uses to shift half-byte content without an explicit bit-by-bit
  shift — followed by `COPIAR_COLUMNA_ALINEADA`/`_DESALINEADA` for the
  new column entering at the edge.

**A different bit order from MSX, and not a bug**: in
`DECIDIR_DIRECCION_SCROLL` the order is RIGHT/LEFT/DOWN/UP
(fallthrough), while MSX uses UP/DOWN/RIGHT/LEFT. Confirmed by
decoding `TABLA_TECLAS_MODO_0` (`$9B45`, Topo Soft's classic QAOP
scheme: Q=up, A=down, O=left, P=right, which produces exactly this bit
order) and also verified by an external developer with their own
independent disassembly: each version reads its own keyboard/joystick
with its own bit order, and the only thing that must hold is that each
version is internally consistent.

All 4 routines write ONLY to the canvas (`$E404` onward) — never
directly to `$4000`, the exact same architectural principle as on MSX
(where `ACTUALIZAR_VRAM_FRAME` is the sole function that copies to
real VRAM).

## 6. Flushing the canvas to the real screen: the redirected-`SP` trick

This is the most distinctive part of the subsystem, and the one that
took the most investigation to identify (see `FINDINGS.md`). The full
mechanism, in two routines:

### 6.1 `PREPARAR_TABLA_ESQUEMA_COLOR` (`$954E`-`$95AA`) — once per level

`CALCULAR_DIRECCION_PANTALLA` (`$9656`) is the Spectrum's standard
interleaved-addressing formula — given `B`=pixel line (0-191) and
`C`=column×8, it computes
`HL = $4000 | (Y7·Y6·Y2·Y1·Y0)<<8 | (Y5·Y4·Y3)<<5 | column` (the
classic three interleaved fields of 48K screen memory) — but it costs
about 10 bit-rotation instructions, expensive if called once per byte
every frame (3456 times). Instead, it is called **only 288 times per
level** (2 addresses × 144 playable pixel lines) and the result is
left pre-computed inside a table of 144 rows of 31 bytes each (`$E400`
onward — right before the canvas):

- offset +0/+1: real screen address already resolved for **character
  column 16**.
- offset +2/+3: a chaining pointer (a parallel table with stride 32,
  not 31 — it progressively drifts out of alignment with the main
  table; whether this is deliberate or a side effect of memory reuse
  is unconfirmed).
- offset +28/+29: real screen address for **column 28**.
- The rest of each row (24 of the 31 bytes) is left untouched — it
  keeps whatever the decorative-frame bitmap left there, used as
  padding without its exact value seeming to matter for the mechanism
  to work (verified by simulation).

### 6.2 `BUCLE_MEZCLA_ESQUEMA_COLOR` (`$95FB`) — every relevant VBLANK

Called from `REFRESCAR_ESQUEMA_COLOR_NIVEL` (`$95B0`-`$965D`, itself
called from `TICK_REDIBUJADO_VBLANK`, §7) with `IX=$E400`. The
algorithm, derived instruction by instruction with a purpose-built Z80
simulator (`tools/mmcanvas_sim.py`, instrumented to log every
`LD SP,xx`):

1. **`LD SP,IX` / 8×`POP`**: redirects `SP` to point inside the table
   row — not the address table, but the 16 bytes of actual **canvas**
   data at that position. The first `POP` (into `IX`) brings the
   ALREADY-COMPUTED screen address for column 16 (the one
   `PREPARAR_TABLA_ESQUEMA_COLOR` left at offset+0/+1); the next 7
   `POP`s (into `HL`/`AF`/`DE`/`BC`, and after `EXX`, `HL`/`DE`/`BC`
   again) read 14 more real bytes of canvas data, across both register
   banks.
2. **`LD SP,IX`**: with `IX` now pointing at the REAL screen address
   (column 16 of that line), the code effectively "jumps" there by
   redirecting `SP` a second time.
3. **2 blocks of 6-byte `PUSH`es each** (normal bank and, after `EXX`,
   alternate bank — 12 bytes total): since `PUSH` decrements `SP`
   BEFORE writing, those 12 bytes land **backwards** from the column-16
   anchor, covering columns 4-15.
4. **The same dance repeats with the second anchor** (column 28, also
   read from the same 16-byte stretch), writing backwards columns
   16-27.
5. Between the two anchors: the **exact 24 columns** of the playable
   area for that row, with no gaps or overlap — the "mixing" work was
   already done by the addressing formula when writing the two
   anchors; there is no `AND`/`OR` involved at all — it's a straight
   copy.
6. The advance to the next row comes from the very `HL` read in the
   same pass (the stride-32 "chain" pointer that
   `PREPARAR_TABLA_ESQUEMA_COLOR` also left ready) — which is why the
   loop interleaves the `IX` chain with the `HL` chain instead of just
   incrementing a plain pointer. It repeats until `IX`'s high byte
   reaches 0 (end of the 144 rows).

**Verified by simulation with a real level loaded** (not an empty
canvas, which was the mistake of an earlier characterisation of this
routine): it writes **3456 real screen addresses** (144 rows × 24
columns, range `$4044`-`$577B`) every relevant VBLANK, stable frame to
frame, and screen content after the flush matches the canvas byte for
byte.

## 7. The frame rhythm: `WAIT_VBLANK` / `TICK_REDIBUJADO_VBLANK`

The Spectrum has no VDP VBLANK like the MSX — the periodic 50 Hz
interrupt is generated by the ULA through a plain timer
(`ACTIVAR_INTERRUPCION_MODO_2`, IM2 mode with the classic Spectrum
"diamond" table at `$F600`-`$F6FF`, real vector at `$6060`). The rest
of the mechanism is analogous in spirit to MSX's:

- **`WAIT_VBLANK`**: sets flag `$91C2` to 1 and does `EI`/`HALT` —
  literally waits for the next interrupt.
- **`ENTRADA_INTERRUPCION_VBLANK`**: the real ISR, saves all registers
  (including the alternate bank and `IX`/`IY`) and calls
  `TICK_REDIBUJADO_VBLANK` and `DESPACHAR_EFECTO_SONIDO`.
- **`TICK_REDIBUJADO_VBLANK`**: runs on EVERY interrupt, but only does
  real work when `$91C2` was exactly 1 on entry — i.e. only when the
  interrupt waking it up is precisely the one `WAIT_VBLANK` was
  waiting for, not any other. When there is work to do, it calls
  `REFRESCAR_ESQUEMA_COLOR_NIVEL` (§6) and then
  `DIBUJAR_ACTORES_PENDIENTES` (§3.2) — in that order: maze first,
  actors drawn on top afterwards.

## 8. Colour: HUD attributes, and the compressed decorative frame

**`REFRESCAR_ESQUEMA_COLOR_NIVEL`** has three parts:

1. Filling the HUD/level-icon attributes: 18 rows from `$5844` with the
   colour from `REGISTRO_NIVEL_ICONO_HUD`, plus 4 loose cells coloured
   with `COLOR_ACTUAL` (the flashing colour of special modes).
2. An `LDIR` block with source and destination both `$0000` (ROM) —
   moves no real data at all (copies every byte onto itself); it is
   pure timing padding, the same trick already documented in other
   menu routines.
3. The canvas flush from §6.

**The decorative frame** (`CARGAR_MARCO_DECORATIVO`, called once from
`INICIO` after the first key wait): decompresses a bitmap compressed as
`(value, repeat-count)` pairs with no end marker — the number of pairs
to read is fixed by `BC` on each call
(`DESCOMPRIMIR_RLE_ATRIBUTOS`). The bitmap (`BITMAP_MARCO_DECORATIVO`,
`$E3F2`, 1496 pairs = 2992 source bytes) decompresses to 6140 of the
6144 bytes of a full screen; its attribute table (136 pairs = 272
bytes) yields 764 of the 768 attribute bytes — both figures almost
exactly the real screen size. The same RLE decompressor is reused by
`APLICAR_ATRIBUTOS_MARCO_COMPLETO` (also from the demo mode) and
`APLICAR_ATRIBUTOS_MARCO_PARCIAL` (from the 5 control-menu options),
reading a shorter prefix (125 of the 136 pairs) of the same attribute
table.

## 9. Relevant addresses and constants

| Constant/range | Address | What it is |
|---|---|---|
| — (bitmap) | `$4000`-`$57FF` | real screen, interleaved |
| — (attributes) | `$5800`-`$5AFF` | colour per character cell |
| `MOTOR_ACTORES` | `$91D0` | 1st pass: filters, computes position, sub-pixel-shifts, writes into the pre-render buffer |
| `TABLA_ACTORES_ACTIVOS` | `$9F9A` | 10 actors × 10 bytes, queue of pending actors to draw |
| `PTR_TABLA_SPRITES` | `$9E8E` | pointers to sprite graphics (28 real entries, guard limit of 64 unadjusted) |
| — (actor pre-render buffer) | `$F701` onward | bump allocator, already sub-pixel-shifted sprite rows |
| `DIBUJAR_ACTORES_PENDIENTES` | `$945A` | 2nd pass: composites AND/OR onto the real screen, synced to VBLANK |
| — (maze canvas) | `$E404` onward | reuses `BITMAP_MARCO_DECORATIVO`'s memory |
| `GRAFICOS_LOSETAS` | `$C600` | source tile graphics, 32 bytes each |
| `REDIBUJAR_LOSETA_BUFFER_VRAM` | `$99BD` | redraws 1 tile into the canvas |
| `GESTIONAR_SCROLL` | `$967D` | scroll dispatcher, 4 directions |
| — (screen-anchor table) | `$E400` onward | 144 rows × 31 bytes, prepared once per level |
| `PREPARAR_TABLA_ESQUEMA_COLOR` | `$954E` | pre-computes the 288 anchor screen addresses |
| `REFRESCAR_ESQUEMA_COLOR_NIVEL` | `$95B0` | HUD + timing padding + canvas flush |
| `BUCLE_MEZCLA_ESQUEMA_COLOR` | `$95FB` | the real flush, the redirected-`SP` `PUSH`/`POP` dance |
| `CALCULAR_DIRECCION_PANTALLA` | `$9656` | Spectrum interleaved-addressing formula |
| `CARGAR_MARCO_DECORATIVO` | — | decompresses the RLE decorative frame to the real screen |

## 10. Confidence and open items

The actor-compositing mechanics (two passes, pre-render buffer,
sub-pixel shift) and the full canvas-flush mechanism (pre-computed
anchors + `SP` dance) are verified 100% by instruction-level simulation
with `tools/mmcanvas_sim.py` (not just disassembly reading). Genuinely
open points:

- The exact purpose of `$91C7` (always receives `$02` in
  `MAPEAR_LOSETA_A_GRAFICO`, unconfirmed in either version of the
  game).
- Whether the stride-32-vs-31 misalignment of the "chain" table (§6.1,
  offset+2/+3) is deliberate or a side effect of how the memory was
  reused.
- The `64`-sprite guard limit in `MOTOR_ACTORES` versus the 28 real
  entries in `PTR_TABLA_SPRITES` — inherited from MSX unadjusted, no
  known observable effect.

## 11. Further reading

- `FINDINGS.md` — session 56 continuations 36-39: the canvas discovery,
  the correction about the actor buffer, locating
  `BUCLE_MEZCLA_ESQUEMA_COLOR`, and the full derivation of its
  algorithm.
- `recursos/mapa_memoria.html` — full memory map with the detail of
  every zone mentioned here.
- `recursos/flujo_programa.html` §1/§4 — where these routines fit in
  the execution flow of a full frame.
- `tools/mmcanvas_sim.py` — the purpose-built Z80 simulator used to
  derive the §6 algorithm, with its 6 documented tests.
- `manual_motor_colision_ia.md` — who decides WHICH tile changes and
  WHEN each actor moves (this manual only documents the HOW it ends up
  on screen).
- `recursos/graficos.html`/`sprites.html` — visual catalogue of already
  identified tiles and sprites.
