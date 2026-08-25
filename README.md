# MadMixGame (ZX Spectrum) — Proyecto de Ingeniería Inversa

*Ingeniería inversa, análisis y documentación: Rafael Eduardo Martín Candial (raemca@hotmail.com)*

Resumen
-------
Proyecto hermano de [`MSX/proyectos/madmixgame`](../../../MSX/proyectos/madmixgame),
aplicado ahora a la versión de **ZX Spectrum** (cinta, `.tzx`) del mismo
juego: *Mad Mix Game* (Topo Soft, 1988). Mismo objetivo y misma
metodología — desensamblado byte a byte, reconstrucción como fuente
ensamblador legible y verificable, extracción y documentación de
recursos (gráficos, sonido, niveles), y herramientas propias para
recompilar el resultado y regenerar el `.tzx` original.

Alcance
-------
Trabajo técnico: desensamblado, extracción de recursos, herramientas
de conversión y documentación. No incluye ni redistribuye el volcado
original de la cinta (`.tzx`) ni materiales con copyright sin la
debida autorización. Ver `AVISO-LEGAL.md` para el detalle completo.

Estado actual
-------------
Todavía muy inicial en cuanto a COMPRENSIÓN del código (nada
comparable aún al análisis semántico del proyecto MSX), pero los
**5 binarios de la versión de cinta ya están reconstruidos y
verificados byte a byte** — la cadena de arranque completa, de la
cinta al motor de juego, es reproducible al 100%:

| Fichero fuente | Dirección | Bytes | Verificado |
|---|---|---|---|
| `src/load_cas/madmix_bas.bas` (BASIC editable) | — | 81 | 0 diferencias |
| `src/load_cas/portada_stub_body.asm` | `$5D1C` | 14 | 0 diferencias |
| `src/portada_body.asm` (portada, 1ª pasada mecánica) | `$EA60` | 4222 | 0 diferencias |
| `src/load_cas/madmix2_bas.bas` (BASIC editable) | — | 71 | 0 diferencias |
| `src/load_cas/loader_body.asm` | `$EFB6` | 196 | 0 diferencias |
| `src/load_cas/screen_body.asm` (dato, no código) | `$4000` | 6912 | 0 diferencias |
| `src/madmix_body.asm` (motor, 1ª pasada mecánica) | `$6000` | 36790 | 0 diferencias |

`loader_body.asm` y `portada_stub_body.asm` tienen análisis semántico
real (etiquetas con significado, comparados contra la ROM). `madmix_body.asm`
y `portada_body.asm` son reconstrucciones MECÁNICAS de primera pasada
(desensamblado lineal con `tools/dasm2asm.py`, etiquetas solo por
dirección) — recompilan idénticas al original pero todavía no
distinguen qué tramos son datos (sprites, niveles, sonido) frente a
código real; eso es el trabajo de las próximas sesiones.

Ver `FINDINGS.md` para el diario de descubrimientos con el detalle
técnico completo de cada hallazgo (incluida la cadena de arranque
completa BASIC → portada → loader → motor), y `AVISO-LEGAL.md` para de
quién es cada cosa.

**El `.tzx` completo ya se reconstruye desde cero y compila
byte a byte idéntico al original** (48485/48485 bytes, 0 diferencias
— ver "Compilar" más abajo).

Compilar
--------
```
py tools/build_all.py
py tools/gen_tzx_file.py
```
(o, en VSCode, `Ctrl+Shift+B` — tarea por defecto "Compilar todo +
generar tzx", ver `.vscode/tasks.json`).

El primer script compila `src/main.asm` con SjASMPlus (los 5
fragmentos reconstruidos, cada uno a su dirección real) y deja los
binarios en `src/build/`. El segundo tokeniza los 2 listados BASIC
editables (`src/load_cas/*.bas`), reconstruye `MAD-MIX.bas` completo
(BASIC + stub + portada, tal como viaja de verdad en la cinta — ver
`FINDINGS.md`), empaqueta todo en un `.tzx` real (mismas pausas y
bloque de información de archivo que el original) en
`build/madmix_reconstruido.tzx`, y **verifica automáticamente el
resultado byte a byte contra `FISICO/Mad Mix Game.tzx`**.

Estructura del repositorio
--------------------------
- `FISICO/` — el `.tzx` original y los ficheros extraídos de él
  (cabeceras, bloques de datos, log de extracción, disassembly crudo).
- `src/` — fuente ensamblador reconstruido y `main.asm` (punto de
  entrada único de compilación) — ver `src/README.md`/`FINDINGS.md`.
- `src/build/` — binarios compilados (`py tools/build_all.py`).
- `build/` — entregable final, `madmix_reconstruido.tzx`
  (`py tools/gen_tzx_file.py`).
- `tools/` — `zxbasic_tool.py` (detokenizador BASIC), `dasm2asm.py`
  (conversor Z80Dasm → SjASMPlus), `build_all.py`, `gen_tzx_file.py`.
- `manuales/` — manuales técnicos de referencia (aún por crear).
- `recursos/` — visores HTML autocontenidos: `mapa_memoria.html`
  (distribución de la RAM 0x0000-0xFFFF), `mapa_memoria_logotopo.html`
  (zoom al rango `$EA60-$FADD` donde se dibuja el logo animado, misma
  memoria que luego reutiliza el motor), `flujo_programa.html`
  (diagrama de arranque + inventario buscable de las etiquetas de
  todos los ficheros fuente, regenerado con `tools/gen_inventory.py`)
  y `logotopo_formas.html` (las 15 formas del logo de Topo Soft ya
  identificadas — SOFT×7, T-O-P-O, estrella×4 — con controles
  ajustables en vivo). Documentos vivos, se amplían sesión a sesión.
- `dump/` — volcados de memoria/pantalla de un emulador real, usados
  como evidencia al verificar hallazgos (aún por crear).

Dependencias y entorno
----------------------
- [SjASMPlus](https://github.com/z00m128/sjasmplus) — ensamblador Z80
  usado para recompilar la fuente reconstruida.
- `Z80Dasm.exe` (Marcel de Kogel) — desensamblador usado como primer
  paso sobre cada binario nuevo, igual que en el proyecto MSX.
- Python 3 (`py` en Windows) — para las herramientas de `tools/`
  cuando se vayan creando.
- Un emulador de ZX Spectrum (p. ej. [ZEsarUX](https://github.com/chernandezba/zesarux))
  para probar y para contrastar contra la ROM real.

Aspectos legales y éticos
-------------------------
Ver `AVISO-LEGAL.md`. Resumen: el juego original no es nuestro y no se
redistribuye; sí se documenta y se publica el análisis, las
herramientas y la fuente reconstruida, bajo `LICENSE`.

Contacto
--------
Para preguntas o propuestas de colaboración, mensaje a
raemca@hotmail.com.
