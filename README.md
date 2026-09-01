# MadMixGame (ZX Spectrum) — Proyecto de Ingeniería Inversa

*[Read this in English](README.en.md)*

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
Los **7 binarios de la versión de cinta están reconstruidos y
verificados byte a byte** — la cadena de arranque completa, de la
cinta al motor de juego, es reproducible al 100%:

| Fichero fuente | Dirección | Bytes | Verificado |
|---|---|---|---|
| `src/load_cas/madmix_bas.bas` (BASIC editable) | — | 81 | 0 diferencias |
| `src/load_cas/portada_stub_body.asm` | `$5D1C` | 14 | 0 diferencias |
| `src/portada_body.asm` (portada) | `$EA60` | 4222 | 0 diferencias |
| `src/load_cas/madmix2_bas.bas` (BASIC editable) | — | 71 | 0 diferencias |
| `src/load_cas/loader_body.asm` | `$EFB6` | 196 | 0 diferencias |
| `src/load_cas/screen_body.asm` (dato, no código) | `$4000` | 6912 | 0 diferencias |
| `src/madmix_body.asm` (motor) | `$6000` | 36790 | 0 diferencias |

El análisis semántico ha avanzado mucho más allá de la reconstrucción
mecánica inicial: `loader_body.asm`, `portada_stub_body.asm` y
`portada_body.asm` (logo animado de Topo Soft) están **cerrados, con
análisis semántico completo** — mismos nombres que sus equivalentes ya
resueltos en el proyecto hermano de MSX cuando existe correspondencia.
`madmix_body.asm` (el motor completo del juego) tiene ya cientos de
rutinas y tablas identificadas y nombradas — motor de sonido de 2
canales, sistema de entrada (teclado QAOP, joystick Sinclair
emulado y Kempston real), carga y motor de niveles, los 64 sprites del
comecocos/enemigos, marcador de puntuación y HUD, secuencia de
arranque, menú de controles, redefinición de teclas, créditos, modo
demo... — con `recursos/flujo_programa.html` manteniendo un inventario
buscable siempre actualizado (regenerado con `tools/gen_inventory.py`)
del total de etiquetas y cuántas siguen sin resolver. Quedan solo
puñados sueltos de bytes sin identificar y los guiones de música sin
decodificar canción por canción — ver la lista "Pendiente para
próximas sesiones" al final de `FINDINGS.md`.

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
- `src/data/` — recursos ya identificados y extraídos a fichero
  individual, incluidos en la fuente vía `INCBIN`: `img/sprites/` (64),
  `img/tiles/` (91 losetas), `img/logo/` (las 15 formas de la
  portada), `niveles/` (los 15 niveles + cabeceras), `sound/` (guiones
  de música/efectos/subpatrones) — ver `src/README.md` para el detalle
  de cada uno.
- `build/` — entregable final, `madmix_reconstruido.tzx`
  (`py tools/gen_tzx_file.py`).
- `tools/` — `zxbasic_tool.py` (detokenizador BASIC), `dasm2asm.py`
  (conversor Z80Dasm → SjASMPlus), `build_all.py`, `gen_tzx_file.py`,
  `gen_inventory.py` (inventario de etiquetas → `flujo_programa.html`),
  `gen_flow_diagram.py` (grafo de llamadas → `flujo_detallado.html`),
  `mmlvl_tool.py` (niveles), `mmsnd_tool.py`/`mmsnd_render.py`
  (extracción y renderizado a `.wav` de la música/efectos) y
  `mmesquema_sim.py` (simulador Z80 mínimo usado para verificar el
  esquema de color del HUD por ejecución real, no solo lectura) y
  `mmcanvas_sim.py` (simulador Z80 más completo, usado para localizar
  el lienzo de trabajo del laberinto en RAM y confirmar que los
  actores se dibujan directo a pantalla real, sin buffer intermedio).
- `manuales/` — manuales técnicos de referencia, en español e inglés,
  con el mismo enfoque pedagógico ("cómo funciona", no "cómo se
  descubrió") que el proyecto hermano de MSX: driver de sonido, motor
  de colisión/IA, subsistema gráfico y formato de niveles — ver
  `manuales/README.md`.
- `recursos/` — visores HTML autocontenidos: `mapa_memoria.html`
  (distribución de la RAM 0x0000-0xFFFF), `mapa_memoria_logotopo.html`
  (zoom al rango `$EA60-$FADD` donde se dibuja el logo animado, misma
  memoria que luego reutiliza el motor), `flujo_programa.html`
  (diagrama de flujo grande + tabla de despacho del motor +
  despachador de tipo de loseta + variables de estado + inventario
  buscable de las etiquetas de todos los ficheros fuente, regenerado
  con `tools/gen_inventory.py`), `flujo_detallado.html` (grafo de
  llamadas real entre las 82 funciones del motor, agrupado por
  subsistema, regenerado con `tools/gen_flow_diagram.py`),
  `flujo_secuencial.html` (diagrama del orden real de ejecución,
  arranque → título → menú → partida frame a frame, curado a mano),
  `logotopo_formas.html` (las 15 formas del logo de Topo Soft ya
  identificadas — SOFT×7, T-O-P-O, estrella×4 — con controles
  ajustables en vivo), `portada.html` (visor de la portada animada
  completa), `graficos.html` (tiles/losetas del motor) y
  `sprites.html` (los 64 sprites del comecocos y enemigos). Documentos
  vivos, se amplían sesión a sesión.
- `dump/` — volcados de memoria/pantalla de un emulador real, usados
  como evidencia al verificar hallazgos (aún por crear).

Dependencias y entorno
----------------------
- [SjASMPlus](https://github.com/z00m128/sjasmplus) — ensamblador Z80
  usado para recompilar la fuente reconstruida.
- `Z80Dasm.exe` (Marcel de Kogel) — desensamblador usado como primer
  paso sobre cada binario nuevo, igual que en el proyecto MSX.
- Python 3 (`py` en Windows) — para las herramientas de `tools/`.
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
