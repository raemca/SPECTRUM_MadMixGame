# Manuals

*[Leer esto en español](README.md)*

*Reverse engineering, analysis and documentation: Rafael Eduardo Martín Candial (raemca@hotmail.com)*

This folder is different from `FINDINGS.md` (chronological discovery
diary) and `recursos/flujo_programa.html` (execution-flow inventory).
There, we document **how each thing was discovered**, in the order it
was investigated, with all the uncertainty and dead ends along the way.

Here, instead, we document **how each already-understood subsystem
works**, in an orderly, pedagogical way — as if it were the technical
manual a programmer of the era would have left for a new colleague.
Two concrete goals:

1. **Training**: so a programmer joining the project (or any similar
   reverse-engineering effort) can learn how each piece really works
   without having to rebuild the entire investigation process.
2. **Preservation**: leaving a clear, readable record of how this piece
   of 8-bit software archaeology is built, beyond the reconstructed
   source code itself.

Each manual assumes the reader knows Z80 assembly and programming in
general, but assumes **nothing** specific to this project or to ZX
Spectrum hardware — that gets explained from scratch the first time it
matters.

These 4 manuals are the direct counterpart of the ones already in the
sister MSX project (`../../MSX/proyectos/madmixgame/manuales/`),
adapted to the real platform differences — the most notable being that
the Spectrum has neither a dedicated sound chip nor any sprite
hardware at all, so both subsystems are solved here entirely in
software, over the beeper and the ULA.

## Index

- [`manual_driver_sonido.md`](manual_driver_sonido.md) — the beeper
  sound driver (`src/madmix_body.asm`, region `$DBE0`-`$EFB5`): the
  three audio subsystems (a blocking 2-channel music engine, non-
  blocking short sound effects, and the demo scripts that are NOT
  sound despite looking like it), the 6-command bytecode language, the
  effect-trigger mechanism (`EVENTO_SONIDO_PENDIENTE`), and the tools
  for editing and listening to the sounds.
- [`manual_motor_colision_ia.md`](manual_motor_colision_ia.md) — the
  movement/collision engine (`src/madmix_body.asm`), the 20-tile-type
  dispatch table, and the AI of the moving enemies/items: how they
  decide direction, what each one does on arrival, and the special
  modes triggered by stepping on them.
- [`manual_subsistema_grafico.md`](manual_subsistema_grafico.md) — the
  ULA in its standard display mode, why the actor engine has NO sprite
  hardware to use at all (unlike the MSX's VDP, which has some but
  ignores it): it composites every character by hand with AND/OR masks
  and sub-pixel shifting. Also the maze's RAM working canvas, the
  software scroll (4px, `RLD`/`RRD`), and the mechanism — the most
  distinctive one in the whole project — that flushes that canvas to
  the real screen every frame with a redirected-`SP` `PUSH`/`POP`
  dance.
- [`manual_niveles.md`](manual_niveles.md) — the format of the 15
  levels: the 20-byte record, the 16-entry table (record 0 is a dead
  duplicate), the 15 bodies + 3 shared headers, the `$3C` wildcard, how
  level completion is detected, the menu's demo mode, the
  `mmlvl_tool.py` tool for editing them, and a concrete case of a
  shared address inherited by the MSX port.

*(More manuals will be added here as more parts of the system are
chosen to be documented this way.)*
