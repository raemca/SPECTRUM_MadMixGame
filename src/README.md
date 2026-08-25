# Mad Mix Game — proyecto de reconstrucción (ZX Spectrum)

*Ingeniería inversa, análisis y documentación: Rafael Eduardo Martín Candial (raemca@hotmail.com)*

Reconstrucción por ingeniería inversa de la versión de cinta (`.tzx`)
de *Mad Mix Game* (Topo Soft, 1988). Ver `../FINDINGS.md` para el
diario de descubrimientos completo, sesión a sesión.

## Estado

Los **5 binarios de la cadena de arranque completa** (cinta → portada
→ loader → motor) están reconstruidos y **verificados byte a byte
contra el original**:

- **`load_cas/madmix_bas.bas`** / **`load_cas/madmix2_bas.bas`** — los
  dos programas BASIC del `.tzx`, detokenizados a texto editable con
  `tools/zxbasic_tool.py`. `madmix_bas.bas` (línea 10-30) es solo la
  PARTE BASIC real de `MAD-MIX.bas` — el fichero de cinta completo
  (4317 bytes) trae pegado detrás, sin cabecera propia, el stub +
  payload de portada (ver abajo). `madmix2_bas.bas` es el que hace
  `LOAD "LOADER" CODE` + `RANDOMIZE USR 61366`.
- **`load_cas/portada_stub_body.asm`** → 14 bytes en `$5D1C`, destino
  de `RANDOMIZE USR 23836` (línea 20 de `madmix_bas.bas`). Copia con
  `LDIR` el payload de portada a su dirección real de ejecución.
  **Análisis semántico completo** (no solo mecánico).
- **`portada_body.asm`** → 4222 bytes, reconstruidos en su dirección
  REAL de ejecución (`$EA60`, no `$5D2A` donde viaja en la cinta —
  ver `FINDINGS.md` para la verificación de esta reubicación). Es el
  logo animado de Topo Soft (SOFT×7 + T-O-P-O + estrella×4) —
  **FICHERO CERRADO, análisis semántico completo** (sesiones 4-20):
  las 15 formas gráficas identificadas y en ficheros propios
  (`data/img/logo/`), todas las tablas de control y variables de
  trabajo con nombre, y las 6 secuencias de animación + la rutina de
  dibujo de bajo nivel + la secuencia maestra, todas analizadas y
  **con el mismo nombre que su rutina equivalente ya resuelta en
  `logotopo_cm_body.asm` de MSX** (ver "Convenciones" más abajo). No
  queda ningún tramo de bytes sin identificar; todo dato en
  hexadecimal restante es o bien una dirección de memoria (código o
  ROM) o una máscara/opcode de bits, y toda cantidad se expresa en
  decimal con comentario. Los 2 últimos huecos genuinos —
  `PORTADA_ECDA` (resuelto: es `PAUSE-1` de la ROM) y el cálculo de
  `RESTAURAR_FRANJA_FONDO` indexado por `$EABE`/`LDI_EXTRA_HUERFANOS`
  (resuelto: confirmado código muerto) — se cerraron en sesiones
  14 y 17. Quedan solo 2 detalles menores, de baja prioridad, ya
  documentados como tales: 1 byte suelto sin explicar en
  `TABLA_ANIMACION_SOFT` (`$ED28`, relleno/alineación) y qué son
  realmente los bytes de cada forma más allá de los primeros 81 que
  `DIBUJAR_FORMA_ANIMADA` llega a leer.
- **`load_cas/loader_body.asm`** → `LOADER.bin`, 196 bytes en `$EFB6`.
  El cargador de cinta real: copia relocada de `LD-BYTES` (ROM de
  48K), carga la pantalla en `$4000` y el motor en `$6000`, y salta
  ahí. **Análisis semántico completo.**
- **`load_cas/screen_body.asm`** → `SCREEN.scr`, 6912 bytes en `$4000`.
  Confirmado que NO es código (bitmap de pantalla estándar) —
  tratado como recurso de datos (`INCBIN` de `data/img/pantalla_carga.img`),
  no como desensamblado falso.
- **`madmix_body.asm`** → `CODE.bin`, 36790 bytes en `$6000`. El motor
  completo del juego. **Reconstrucción mecánica de primera pasada**
  (`tools/dasm2asm.py`), análisis semántico **recién empezado**
  (sesión 22): resuelta la cadena de arranque inicial (`MOTOR_INICIO`
  → `INICIO`, activación de interrupciones en modo 2,
  `ENTRADA_INTERRUPCION_VBLANK`), comparando con `madmix1_body.asm`/
  `madmix_scr_body.asm` de MSX igual que se hizo con la portada. Queda
  pendiente casi todo el resto: identificar qué tramos son datos, el
  bucle principal, el driver de sonido, las tablas de nivel, los
  sprites, la pantalla de créditos.

Ver `../FINDINGS.md` (sesiones 2 y 3) para la cadena de arranque
completa reconstruida paso a paso y el detalle técnico de cada
verificación.

**`main.asm` ya existe** (sesión 3) — único punto de entrada de
compilación, une los 5 fragmentos en una sola pasada de SjASMPlus (un
solo espacio de símbolos). Y el `.tzx` completo ya se reconstruye
desde cero y compila **byte a byte idéntico** al original (ver
"Compilar" más abajo).

Todavía no existen (se irán creando según avance el análisis semántico
de `madmix_body.asm`/`portada_body.asm`, mismo patrón que el proyecto
hermano de MSX):

- `data/tiles/`, `data/sprites/`, `data/sound/`, `data/niveles/` —
  recursos individuales, una vez identificados dentro de `madmix_body.asm`
  (de momento solo existe `data/img/pantalla_carga.img`, la pantalla
  de carga completa sin recortar en tiles).

## Convenciones

**IMPORTANTE — dirección del port**: esta versión de Spectrum es la
**ORIGINAL**; la versión de MSX (`MSX/proyectos/madmixgame`) es un
**port hecho a partir de ésta**, no al revés. Confirmado por el
usuario (sesión 29 de `FINDINGS.md`). Esto importa para cómo se
redactan las comparaciones: cuando un mecanismo difiere entre
versiones, se describe la versión MSX como la que tuvo que ADAPTARSE
a su hardware (VDP en vez de la ULA, PSG en vez del altavoz, modo de
interrupción 1 en vez de modo 2...), no la versión Spectrum como la
que "se aparta" de MSX. Encaja además con un hallazgo ya documentado:
`CARGAR_NIVEL` (Spectrum) usa la dirección `$FC60`, la MISMA que la
v1.0 ORIGINAL del port a MSX antes de su parche v2.0 -- coherente con
que esa v1.0 fuese un port temprano y fiel de este original que
conservó la dirección tal cual.

**Nombres compartidos con el proyecto MSX, cuando hay una rutina
equivalente ya resuelta allí.** *Mad Mix Game* se publicó tanto en
MSX como en Spectrum, y buena parte del contenido (al menos el logo
animado de Topo Soft, verificado sesión 11) es la MISMA secuencia de
alto nivel en ambas versiones, aunque el código Z80 concreto sea
distinto (arquitecturas de vídeo distintas: VRAM de VDP en MSX,
memoria de pantalla mapeada en Spectrum). La metodología de reutilizar
los nombres YA RESUELTOS en el proyecto MSX sigue siendo el camino más
eficiente (ese proyecto llegó primero y ya tiene cientos de rutinas
identificadas) — solo cambia cómo se explica QUIÉN se adaptó a quién,
no la práctica de compartir nombres. Cuando se identifica una
rutina Spectrum como equivalente de una ya resuelta en
`MSX/proyectos/madmixgame/src/load_cas/logotopo_cm_body.asm` (o, más
adelante, en `madmix1_body.asm`/`madmix_scr_body.asm`), se le pone
**el mismo nombre exacto**, no solo uno parecido — así una búsqueda
del mismo identificador en los dos proyectos encuentra las dos
rutinas directamente, y el propio nombre compartido deja constancia
de la equivalencia sin tener que leer el comentario. Ejemplo completo
(portada, sesión 11):

| MSX (`logotopo_cm_body.asm`) | Spectrum (`portada_body.asm`) |
|---|---|
| `DIBUJAR_LOGO_TOPOSOFT` | `DIBUJAR_LOGO_TOPOSOFT` |
| `DIBUJAR_FORMA_ANIMADA` | `DIBUJAR_FORMA_ANIMADA` |
| `LIMPIAR_TABLA_COLOR_VRAM` | `LIMPIAR_TABLA_COLOR_VRAM` |
| `DIBUJAR_T_TOPO` | `DIBUJAR_T_TOPO` |
| `DIBUJAR_P_TOPO_ANIMADA` | `DIBUJAR_P_TOPO_ANIMADA` |
| `DIBUJAR_O1_TOPO` | `DIBUJAR_O1_TOPO` |
| `DIBUJAR_O2_TOPO_ANIMADA` | `DIBUJAR_O2_TOPO_ANIMADA` |
| `ANIMAR_COLOR_TOPO` | `ANIMAR_COLOR_TOPO` |
| `RELLENAR_COLOR_TOPO` | `RELLENAR_COLOR_TOPO` |
| `DIBUJAR_SOFT_ROTANDO` | `DIBUJAR_SOFT_ROTANDO` |
| `ANIMAR_PUNTO_LUZ_SOFT` | `ANIMAR_PUNTO_LUZ_SOFT` |
| `DIBUJAR_ESTRELLA_ANIMADA` | `DIBUJAR_ESTRELLA_ANIMADA` |

La misma política se aplica a las **tablas de datos**, no solo a las
rutinas (sesión 13): cuando una tabla Spectrum tiene la misma función
que una ya resuelta en MSX, recibe su mismo nombre exacto:

| MSX (`logotopo_cm_body.asm`) | Spectrum (`portada_body.asm`) |
|---|---|
| `TABLA_PUNTEROS_FORMAS` | `TABLA_PUNTEROS_FORMAS` |
| `TABLA_ANIMACION_SOFT` | `TABLA_ANIMACION_SOFT` |
| `TABLA_TRAZO_O2_TOPO` | `TABLA_TRAZO_O2_TOPO` |
| `TABLA_ANIMACION_ESTRELLA` | `TABLA_ANIMACION_ESTRELLA` |
| `TABLA_FORMAS` | `TABLA_FORMAS` (alias en `$EF1C`, mismo byte que `LOGO_SOFT_1`) |
| `VARIABLES_TRABAJO_FORMA` | `VARIABLES_TRABAJO_FORMA` (sesión 16, ver abajo) |

`TABLA_DELTA_POSICION` (MSX) **no** se ha renombrado en Spectrum —
sigue llamándose `TABLA_FILAS_PANTALLA` a propósito: aunque cumple un
papel análogo (traducir fila lógica a dirección de pantalla), la
estructura de datos es distinta (192 direcciones absolutas reales en
Spectrum frente a 24 deltas relativos enmascarados en MSX), así que
forzar el mismo nombre sería engañoso; se deja anotado en el
comentario de la tabla en `portada_body.asm`.

Las etiquetas locales (con `.`) siguen el mismo criterio cuando el
bucle equivalente existe en MSX (p. ej. `.BUCLE_SEGMENTO`,
`.BUCLE_FOTOGRAMA`, `.BUCLE_POSICION`). Cuando el mecanismo Spectrum
NO tiene equivalente real en MSX (p. ej. `GUARDAR_PANTALLA_LOGO`/
`RESTAURAR_FRANJA_FONDO`, que sustituyen la estrategia MSX de "borrar
la tabla de patrones entre letra y letra" por "guardar y restaurar
franjas de fondo" — dos soluciones distintas al mismo problema), se
deja un nombre propio en español, sin forzar una correspondencia que
no existe. Si el nombre compartido con MSX no encaja del todo con el
comportamiento Spectrum (p. ej. `LIMPIAR_TABLA_COLOR_VRAM` aquí
también borra el bitmap, no solo el color, porque el modelo de
pantalla del Spectrum no separa ambas tablas igual que la VRAM del
MSX), se anota la diferencia en el comentario de la rutina en vez de
inventar un nombre distinto.

## Compilar y verificar

```
py tools/build_all.py       # compila src/main.asm -> src/build/*.bin
py tools/gen_tzx_file.py    # empaqueta + tokeniza BASIC -> build/madmix_reconstruido.tzx
                             # y verifica byte a byte contra ../FISICO/Mad Mix Game.tzx
```

(o `Ctrl+Shift+B` en VSCode — ver `../.vscode/tasks.json`). Resultado
actual: **0 diferencias, 48485/48485 bytes idénticos**.

`main.asm` debe compilarse SIEMPRE con el directorio de trabajo en
`src/` (lo hace `build_all.py`) — SjASMPlus resuelve `INCLUDE`/`INCBIN`/
`SAVEBIN` relativos al `cwd` del proceso, no a la ubicación de cada
fichero fuente (por eso el `INCBIN` de `load_cas/screen_body.asm` usa
una ruta relativa a `src/`, no a `load_cas/`).

Para los `.bas` sueltos: `py tools/zxbasic_tool.py roundtrip <fichero.bas>`
verifica que detokenizar+retokenizar reproduce el binario original
exacto.

## Requisitos

- [SjASMPlus](https://github.com/z00m128/sjasmplus) en el PATH.
- `Z80Dasm.exe` (Marcel de Kogel) para el primer desensamblado de cada
  binario nuevo — copia disponible en
  `../../MSX/compiladores/Z80Dasm/Z80Dasm.exe`.
- Python 3 (`py` en Windows) — para `tools/zxbasic_tool.py` y
  `tools/dasm2asm.py`.
- Un emulador de ZX Spectrum con ROM de 48K (p. ej.
  [ZEsarUX](https://github.com/chernandezba/zesarux)) para probar y
  para contrastar hallazgos contra la ROM real.
