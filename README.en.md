# MadMixGame (ZX Spectrum) — Reverse Engineering Project

*[Leer esto en español](README.md)*

*Reverse engineering, analysis and documentation: Rafael Eduardo Martín Candial (raemca@hotmail.com)*

Summary
-------
Sister project of [`MSX/proyectos/madmixgame`](../../../MSX/proyectos/madmixgame),
now applied to the **ZX Spectrum** (tape, `.tzx`) version of the same
game: *Mad Mix Game* (Topo Soft, 1988). Same goal and same
methodology — byte-for-byte disassembly, reconstruction as readable,
verifiable assembly source, extraction and documentation of resources
(graphics, sound, levels), and purpose-built tools to recompile the
result and regenerate the original `.tzx`.

Scope
-----
Technical work: disassembly, resource extraction, conversion tools and
documentation. It does not include or redistribute the original tape
dump (`.tzx`) nor copyrighted material without proper authorization.
See `AVISO-LEGAL.md` for the full detail.

Current status
---------------
The **7 binaries of the tape version are reconstructed and verified
byte for byte** — the full boot chain, from tape to game engine, is
100% reproducible:

| Source file | Address | Bytes | Verified |
|---|---|---|---|
| `src/load_cas/madmix_bas.bas` (editable BASIC) | — | 81 | 0 differences |
| `src/load_cas/portada_stub_body.asm` | `$5D1C` | 14 | 0 differences |
| `src/portada_body.asm` (title screen) | `$EA60` | 4222 | 0 differences |
| `src/load_cas/madmix2_bas.bas` (editable BASIC) | — | 71 | 0 differences |
| `src/load_cas/loader_body.asm` | `$EFB6` | 196 | 0 differences |
| `src/load_cas/screen_body.asm` (data, not code) | `$4000` | 6912 | 0 differences |
| `src/madmix_body.asm` (engine) | `$6000` | 36790 | 0 differences |

Semantic analysis has advanced well beyond the initial mechanical
reconstruction: `loader_body.asm`, `portada_stub_body.asm` and
`portada_body.asm` (the animated Topo Soft logo) are **closed, with
complete semantic analysis** — same names as their already-resolved
counterparts in the sister MSX project wherever a correspondence
exists. `madmix_body.asm` (the game's full engine) already has
hundreds of identified and named routines and tables — a 2-channel
sound engine, the input system (QAOP keyboard, emulated Sinclair
joystick and real Kempston), level loading and engine, the 64
hero/enemy sprites, the score marker and HUD, the boot sequence, the
controls menu, key redefinition, credits, demo mode... —
with `recursos/flujo_programa.html` keeping an always up-to-date,
searchable inventory (regenerated with `tools/gen_inventory.py`) of
the total labels and how many remain unresolved. Only scattered
handfuls of unidentified bytes and music scripts not yet decoded
song by song remain — see the "Pendiente para próximas sesiones" list
at the end of `FINDINGS.md`.

See `FINDINGS.md` for the discovery diary with the full technical
detail of every finding (including the full boot chain BASIC → title
screen → loader → engine), and `AVISO-LEGAL.md` for who owns what.

**The complete `.tzx` is now rebuilt from scratch and compiles
byte-for-byte identical to the original** (48485/48485 bytes, 0
differences — see "Building" below).

Building
--------
```
py tools/build_all.py
py tools/gen_tzx_file.py
```
(or, in VSCode, `Ctrl+Shift+B` — default task "Compilar todo +
generar tzx", see `.vscode/tasks.json`).

The first script compiles `src/main.asm` with SjASMPlus (the 5
reconstructed fragments, each at its real address) and leaves the
binaries in `src/build/`. The second tokenizes the 2 editable BASIC
listings (`src/load_cas/*.bas`), reconstructs the complete `MAD-MIX.bas`
(BASIC + stub + title screen, exactly as it really travels on the tape
— see `FINDINGS.md`), packages everything into a real `.tzx` (same
pauses and file-info block as the original) in
`build/madmix_reconstruido.tzx`, and **automatically verifies the
result byte for byte against `FISICO/Mad Mix Game.tzx`**.

Repository structure
---------------------
- `FISICO/` — the original `.tzx` and the files extracted from it
  (headers, data blocks, extraction log, raw disassembly).
- `src/` — reconstructed assembly source and `main.asm` (the single
  build entry point) — see `src/README.md`/`FINDINGS.md`.
- `src/build/` — compiled binaries (`py tools/build_all.py`).
- `src/data/` — resources already identified and extracted into
  individual files, included in the source via `INCBIN`:
  `img/sprites/` (64), `img/tiles/` (91 tiles), `img/logo/` (the 15
  title-screen shapes), `niveles/` (the 15 levels + headers),
  `sound/` (music/effect/subpattern scripts) — see `src/README.md`
  for the detail of each one.
- `build/` — final deliverable, `madmix_reconstruido.tzx`
  (`py tools/gen_tzx_file.py`).
- `tools/` — `zxbasic_tool.py` (BASIC detokenizer), `dasm2asm.py`
  (Z80Dasm → SjASMPlus converter), `build_all.py`, `gen_tzx_file.py`,
  `gen_inventory.py` (label inventory → `flujo_programa.html`),
  `gen_flow_diagram.py` (call graph → `flujo_detallado.html`),
  `mmlvl_tool.py` (levels), `mmsnd_tool.py`/`mmsnd_render.py`
  (extraction and `.wav` rendering of music/effects), `mmesquema_sim.py`
  (a minimal Z80 simulator used to verify the HUD colour scheme by
  real execution, not just reading) and `mmcanvas_sim.py` (a fuller
  Z80 simulator, used to locate the maze's RAM working canvas and
  confirm that actors are drawn directly to the real screen through an
  intermediate pre-render buffer).
- `manuales/` — technical reference manuals, in Spanish and English,
  with the same pedagogical approach ("how it works", not "how it was
  discovered") as the sister MSX project: sound driver, collision/AI
  engine, graphics subsystem and level format — see
  `manuales/README.md`.
- `recursos/` — self-contained HTML viewers: `mapa_memoria.html` (the
  0x0000-0xFFFF RAM layout), `mapa_memoria_logotopo.html` (a zoom into
  the `$EA60-$FADD` range where the animated logo is drawn, the same
  memory the engine later reuses), `flujo_programa.html` (a large flow
  diagram + the engine's dispatch table + the tile-type dispatcher +
  shared state variables + a searchable inventory of every source
  file's labels, regenerated with `tools/gen_inventory.py`),
  `flujo_detallado.html` (the real call graph among the engine's 82
  functions, grouped by subsystem, regenerated with
  `tools/gen_flow_diagram.py`), `flujo_secuencial.html` (a diagram of
  the real execution order, boot → title → menu → gameplay frame by
  frame, hand-curated), `logotopo_formas.html` (the 15 already
  identified Topo Soft logo shapes — SOFT×7, T-O-P-O, star×4 — with
  live-adjustable controls), `portada.html` (a viewer for the full
  animated title screen), `graficos.html` (the engine's tiles) and
  `sprites.html` (the 64 hero/enemy sprites). Living documents,
  expanded session by session.
- `dump/` — memory/screen dumps from a real emulator, used as evidence
  when verifying findings (not yet created).

Dependencies and environment
------------------------------
- [SjASMPlus](https://github.com/z00m128/sjasmplus) — the Z80
  assembler used to recompile the reconstructed source.
- `Z80Dasm.exe` (Marcel de Kogel) — the disassembler used as the first
  step on every new binary, just like in the MSX project.
- Python 3 (`py` on Windows) — for the `tools/` utilities.
- A ZX Spectrum emulator (e.g. [ZEsarUX](https://github.com/chernandezba/zesarux))
  to test and to cross-check against the real ROM.

Legal and ethical aspects
---------------------------
See `AVISO-LEGAL.md`. Summary: the original game is not ours and is
not redistributed; the analysis, tools and reconstructed source are
documented and published under `LICENSE`.

Contact
-------
For questions or collaboration proposals, message
raemca@hotmail.com.
