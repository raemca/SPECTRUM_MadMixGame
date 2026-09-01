# Contributing Guide

*[Leer esto en español](CONTRIBUTING.md)*

Thanks for your interest in contributing to this **reverse-engineering,
disassembly and Z80 assembly reconstruction** project for *Mad Mix Game*
(Topo Soft, 1988, ZX Spectrum 48K, tape version)!

The goal of this repository is to translate the game's original binary
(tape, `.tzx`) into real Z80 source code, identifying and documenting
functions, variables and data blocks, always keeping a **1:1 reconstruction
(byte-matching)** against the original executable. Before anything else,
take a look at `README.md` and `src/README.md` (the project's architecture
and conventions) and `FINDINGS.md` (the findings diary, Spanish-only so
far) to understand how the work has been done up to now.

---

## 📌 Core Project Principles

1. **1:1 fidelity (byte-matching):** any change to the assembly instructions
   or data tables must keep generating a binary that is identical, byte for
   byte, to the original (48485 bytes, 0 differences). As of today there is
   no documented exception — this Spectrum version is the **original** from
   1988, unlike the sister MSX project (a *port* of this one), which did
   have to fix a real bug of its own platform in its v2.0 (see
   `manuales/manual_niveles.en.md` §8).
2. **Clarity over interpretation:** no new code is added, and original
   routines are never "optimized". The goal is to translate and interpret
   exactly what the binary does, original bugs included if any exist.
3. **Step by step:** it's better to label/document one small, verified block
   than to submit a large change without checking it against the real
   binary.
4. **Descriptive names in Spanish:** the convention already established
   throughout the project (hundreds of renaming rounds documented in
   `FINDINGS.md`) is to use descriptive names **in Spanish**, not English or
   cryptic abbreviations — for example `MOTOR_ACTORES`,
   `CONSULTAR_TIPO_LOSETA`, `REGISTRO_NIVEL_POSICION_COMECOCOS`, not
   `ACTOR_ENGINE` or `lbl_8200`. Purely internal labels within a routine
   (jump marks with no identity of their own) use SjASMPlus's local-label
   mechanism with a leading dot (`.BUCLE_SEGMENTO`).
5. **Names shared with the MSX project when an equivalent routine is
   already resolved there:** a good part of the content (at least the
   animated Topo Soft logo, verified in session 11) is the same high-level
   sequence in both versions, even though the actual Z80 code differs
   (memory-mapped ULA on Spectrum, VDP VRAM on MSX). When a Spectrum routine
   is identified as equivalent to one already resolved in the MSX project,
   it gets **the exact same name** — see "Convenciones" in `src/README.md`
   for the full detail and the cases where the name is deliberately NOT
   shared because the real mechanism differs.

---

## 🛠️ Working Environment and Tools

- **Assembler:** [SjASMPlus](https://github.com/z00m128/sjasmplus) on your
  PATH — the only assembler this project uses (not `pasmo`, not `z80asm`).
- **Python 3** (`py` on Windows) — for the `tools/` utilities (full build,
  `.tzx` generation, sound, levels, tokenized BASIC). No external
  dependencies, standard library only.
- **A ZX Spectrum emulator with a 48K ROM** (e.g.
  [ZEsarUX](https://github.com/chernandezba/zesarux)), optional but
  recommended, to test the result and cross-check findings against the
  real ROM.
- **A legally obtained copy of the original game** (tape `.tzx`) if you
  want to verify the byte-for-byte comparison yourself — this repository
  **does not include** the original dump, see `AVISO-LEGAL.md`. Without one
  you can still contribute (renaming, comments, documentation), but you
  won't be able to check the byte-match yourself.

---

## 🚀 Contribution Workflow

### 1. Set Up the Repository

1. **Fork** this repository on GitHub.
2. Clone it locally:

   ```bash
   git clone https://github.com/YOUR_USERNAME/SPECTRUM_MadMixGame.git
   cd SPECTRUM_MadMixGame
   ```

3. Create a descriptive branch:

   ```bash
   git checkout -b label-collision-engine
   # or: git checkout -b fix-scroll-comment
   ```

### 2. Build and Verify

```bash
# Builds the ENTIRE project in one go (engine, title screen, tape loader)
py tools/build_all.py

# Generates the final deliverable (.tzx) from scratch and automatically
# verifies it byte for byte against FISICO/Mad Mix Game.tzx
py tools/gen_tzx_file.py
```

This leaves the binaries in `src/build/` and the rebuilt `.tzx` in
`build/madmix_reconstruido.tzx`. The `gen_tzx_file.py` script itself prints
the byte-for-byte comparison result — it must say **"0 diferencias, 48485
bytes idénticos"** (0 differences, 48485 identical bytes).

If your change is only renaming/comments, the result must be **exactly the
same** as before your change (0 differences). If your change introduces a
real divergence, it isn't a valid change for this project — the
reconstruction must stay byte-for-byte faithful to the original.

### 3. Document the Finding

If you identify or fix something (a label, a data block, a behavior), add an
entry to `FINDINGS.md` following the style already used — a `##`/`###`
heading describing what was believed before, what was discovered, and how it
was verified. It's the project's chronological diary; history isn't
rewritten, it's added on top of.

---

## 📬 Submitting Pull Requests

1. Commit your changes with descriptive messages:

   ```bash
   git commit -m "Rename MOTOR_MOVIMIENTO_ITEM and document the finding in FINDINGS.md"
   ```

2. Push your branch:

   ```bash
   git push origin label-collision-engine
   ```
3. Open a **Pull Request** against this repository's `main` branch.
4. In the PR description, note the memory ranges/labels changed, the result
   of the byte-for-byte verification (§2), and the affected files.

---

## 🐛 Reporting Bugs and Inconsistencies

If you find a misinterpreted section, data disassembled as code, or a label
that no longer describes what its routine does, but you're not going to fix
it yourself:

1. Check there isn't already an open Issue about it.
2. Open a new Issue describing the problem.
3. Include the real memory address and the technical justification — if you
   can verify it live with an emulator or by comparing against the original
   binary, even better.

---

Thanks for helping preserve and reverse-engineer this piece of Spanish
software history!
