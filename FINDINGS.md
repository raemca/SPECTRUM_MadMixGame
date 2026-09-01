# FINDINGS — diario de descubrimientos (ZX Spectrum)

*Ingeniería inversa, análisis y documentación: Rafael Eduardo Martín Candial (raemca@hotmail.com)*

Diario cronológico, en el mismo espíritu que `FINDINGS.md` del
proyecto hermano de MSX (`MSX/proyectos/madmixgame`): aquí se
documenta CÓMO se descubrió cada cosa, sesión a sesión.

## Sesión 1 — 2026-08-08: extracción del `.tzx` y primer binario reconstruido

### Extracción del `.tzx`

`FISICO/Mad Mix Game.tzx` (48485 bytes) se parseó bloque a bloque
(parser propio en PowerShell, sin Python/Node disponibles en el
sistema en ese momento) siguiendo la especificación TZX 1.20. El
parseo consumió los 48485 bytes exactos sin desincronizarse — ninguna
zona del fichero quedó sin interpretar. Bloques encontrados, en orden:

1. `0x32` Archive info — título "MAD MIX GAME", editor "TOPO / ERBE",
   comentario "D.L. M-19452-1988. TZXed by johnny farragut".
2. `0x10` Standard Speed Data, cabecera estándar de cinta (flag `$00`,
   19 bytes): programa BASIC `"MAD-MIX"`, longitud `$10DD`=4317.
3. `0x10` datos del bloque anterior → `MAD-MIX.bas` (4317 bytes,
   BASIC tokenizado válido — arranca con línea 10, `$00 $0A`).
4. `0x10` cabecera: programa BASIC `"MAD-MIX"` otra vez (incluso
   mismo nombre), longitud 71.
5. `0x10` datos → `MAD-MIX_2.bas` (71 bytes). Contiene en claro, entre
   los tokens, las cadenas `"LOADER"` y `"61366"` — es el loader real
   que hace `LOAD "LOADER" CODE` + `RANDOMIZE USR 61366` (61366 =
   `$EFB6`, confirmado como la dirección de carga real de `LOADER.bin`
   en el siguiente bloque).
6. `0x10` cabecera: bloque `CODE` `"LOADER"`, longitud 196, dirección
   de carga (param1) **61366** ($EFB6).
7. `0x10` datos → `LOADER.bin` (196 bytes).
8. `0x10` bloque de datos SIN cabecera propia (flag `$FF` directo,
   6914 bytes con flag+checksum) — 6912 bytes de payload, exactamente
   el tamaño de una pantalla de Spectrum → `SCREEN.scr`.
9. `0x10` último bloque, también sin cabecera propia, 36792 bytes con
   flag+checksum (36790 de payload) → `CODE.bin`. Este bloque llega
   justo hasta el byte final del `.tzx` (offset 11688 + 5 + 36792 =
   48485 = tamaño exacto del fichero).

Los bloques 8 y 9 no tienen cabecera estándar propia porque el
cargador real (`LOADER.bin`) no la necesita: pide la dirección de
destino como parámetro fijo en su propio código (ver más abajo), en
vez de depender de la cabecera de 19 bytes que interpreta la ROM.
Mismo patrón que `LOAD.BIN` en la versión de MSX (ver
`MSX/proyectos/madmixgame/src/FINDINGS.md`).

Herramientas usadas: parser TZX propio (PowerShell, sin dependencias
externas — no había Python ni Node instalados en el sistema en el
momento de la extracción).

### `LOADER.bin` — reconstruido y verificado byte a byte

Desensamblado con `Z80Dasm.exe -offset EFB6 LOADER.bin` (mismo
desensamblador que usa el proyecto MSX) →
`FISICO/LOADER.bin.dasm.txt`.

Estructura, de arriba a abajo:

```
$EFB6  LD IX,$4000 / LD DE,6912  / LD A,$FF / SCF / CALL $EFD3
$EFC3  LD IX,$6000 / LD DE,36790 / LD A,$FF / SCF / CALL $EFD3
$EFD0  JP $6000
$EFD3  ... rutina de lectura de cinta (166 bytes) ...
```

Los dos tamaños de bloque (6912 y 36790) coinciden EXACTOS con
`SCREEN.scr` y `CODE.bin` respectivamente — confirma que el loader
carga la pantalla en `$4000` (la dirección de pantalla estándar del
Spectrum) y el resto del juego en `$6000`, y salta ahí para arrancar
el motor.

La rutina de `$EFD3` (166 bytes) se comparó, instrucción a
instrucción, contra la rutina `LD-BYTES` de la ROM de 48K (`48.rom`
de ZEsarUX, desensamblada con el mismo `Z80Dasm.exe` en el rango
`$0556`-`$06A6` para la comparación). Resultado: **es una copia
byte-a-byte relocada de `LD-BYTES`**, mismo algoritmo (detección de
flancos en el bit 5 del puerto `$FE`, tono piloto, dos pulsos de
sincronismo, lectura de bits por byte con paridad acumulada) y mismas
constantes de temporización (`$9C`, `$C6`, `$C9`, `$D4`, `$CB`, `$B0`,
`$B2`, `$16`), con solo 2 diferencias en el preámbulo:

- ROM: `LD A,$0F` / `OUT ($FE),A` (borde blanco al empezar) + `LD
  HL,$053F` / `PUSH HL` (empuja una dirección de retorno usada por el
  mecanismo de error de la ROM, `RST $08`). Copia: `XOR A` / `OUT
  ($FE),A` (borde negro) y sin el `PUSH HL` — no depende de la pila
  de errores de la ROM.
- ROM: tras leer el puerto, `AND $20` / `OR $02` / `LD C,A`, y más
  adelante `XOR $03` antes de otro `LD C,A` al pasar de tono piloto a
  lectura de bits. Copia: ninguna de las dos — solo `AND $20` / `LD
  C,A` al principio, y un `LD A,C` / `LD C,A` (NOP funcional) en el
  punto equivalente al `XOR $03`. Efecto neto exacto sobre el flag de
  paridad inicial **no verificado al 100%** — pendiente de confirmar
  cargando de verdad `SCREEN.scr`/`CODE.bin` con este loader en un
  emulador.

Reconstrucción con etiquetas y comentarios:
`src/load_cas/loader_body.asm`.

**Verificación**: recompilado de forma aislada con SjASMPlus
(`DEVICE ZXSPECTRUM48` / `ORG $EFB6` / `INCLUDE` del cuerpo /
`SAVEBIN`) y comparado byte a byte contra el `LOADER.bin` extraído
del `.tzx` — **0 diferencias**, 196/196 bytes idénticos.

### Pendiente para la próxima sesión (estado al cierre de la sesión 1)

- Desensamblar `SCREEN.scr` (6912 bytes, sin comprimir — bitmap 6144
  + atributos 768, formato estándar de pantalla de Spectrum, debería
  poder visualizarse directo con cualquier visor de `.scr`).
- Empezar `CODE.bin` (36790 bytes) — el motor completo. Punto de
  entrada conocido: `$6000` (destino del `JP` final de `LOADER.bin`).
- Detokenizar `MAD-MIX.bas`/`MAD-MIX_2.bas` a texto editable (hace
  falta una tabla de tokens de Spectrum BASIC en `tools/`, aún no
  existe en este proyecto).

## Sesión 2 — 2026-08-08: los cinco binarios reconstruidos y verificados

Petición: "desensambla todos los ficheros y coloca los .asm en el
directorio que corresponda". Resultado: los 5 tramos de código/datos
que forman el arranque completo por cinta están ahora reconstruidos
y **verificados byte a byte contra el original** (0 diferencias en
todos), más el mapa de arranque completo (BASIC → portada → loader →
motor) reconstruido y confirmado por consistencia interna.

### Herramienta: `tools/zxbasic_tool.py` (detokenizador de BASIC)

No existía tabla de tokens de Spectrum BASIC en el proyecto — se
escribió una desde cero (tokens `$A5`-`$FF`, más los códigos de
control `$10`-`$17` de INK/PAPER/FLASH/BRIGHT/INVERSE/OVER/AT/TAB
embebidos en cadenas, y el formato de número oculto — dígitos ASCII +
`$0E` + 5 bytes de forma binaria). Verificada empíricamente con
`MAD-MIX_2.bas` (ver abajo): decodifica a una línea BASIC perfectamente
idiomática y con un número (`61366`) que coincide exacto con la
dirección de carga real de `LOADER.bin` — confirma la tabla de tokens.
Cualquier byte no cubierto se conserva exacto con escape `{$XX}`, igual
que hace `msxbasic_tool.py` en el proyecto hermano de MSX. Comandos:
`detok`/`tok`/`roundtrip`.

### `MAD-MIX_2.bas` (71 bytes) — detokenizado y verificado

```
10 BORDER 0: INK 7: PAPER 0: CLEAR 24575: LOAD "LOADER" CODE: CLS: RANDOMIZE USR 61366
```

Confirma la cadena de arranque: carga `LOADER.bin` como bloque `CODE`
y salta a él con `USR 61366` ($EFB6 — la misma dirección real de carga
que ya conocíamos por la cabecera de cinta). Roundtrip (`detok`+`tok`)
idéntico byte a byte al original.

### `MAD-MIX.bas` (4317 bytes) — NO es solo BASIC

Al intentar detokenizar el fichero completo, el parser se rompía en
seco justo después de la línea 30 con bytes que no encajaban como
cabecera de línea (`$21 $2A $5D $11...`) — esos mismos bytes,
interpretados como código Z80, son `LD HL,$5D2A` / `LD DE,$EA60` /
`LD BC,$107E` / `LDIR` / `JP $EBD8`: una rutina real, no texto BASIC.

Investigado a fondo: **el fichero son 81 bytes de BASIC real seguidos,
dentro del MISMO bloque de cinta "Program" (sin cabecera `CODE`
aparte), de 4236 bytes de código máquina** — técnica clásica de la
época (el bloque completo se carga de un tirón a la zona de
programa/variables de BASIC; el código máquina "viaja de polizón"
justo detrás de las líneas reales). Confirmado por la propia cabecera
de cinta: `Param2` (offset a variables) = `DataLength` = 4317, es
decir, el cargador de la ROM no distingue "programa" de "cola de
código" — para la ROM es todo una sola cosa.

Las 3 líneas BASIC reales (verificadas con roundtrip, 0 diferencias):

```
10 PAPER 0: BORDER 0: CLEAR 50000
20 PAUSE 40: RANDOMIZE USR 23836: PAUSE 40
30 LOAD ""
```

Los 4236 bytes de cola se dividen en:

- **Stub de reubicación** (14 bytes, `$5D1C`-`$5D29`): destino directo
  de `RANDOMIZE USR 23836` (23836 = `$5D1C`, coincide exacto). Copia
  con `LDIR` los 4222 bytes siguientes desde `$5D2A` (donde aterrizan,
  pegados al stub, al cargar el bloque BASIC) hasta `$EA60`, y salta a
  `$EBD8` — **un punto 408 bytes dentro del bloque recién copiado**,
  no su primer byte.
- **Payload de portada** (4222 bytes): escrito en el `.bas`/cinta en
  una dirección de tránsito (`$5D2A`) pero pensado para ejecutarse en
  otra bien distinta (`$EA60`) — mismo truco de reubicación que
  `PHASE`/`DEPHASE` en `madmix_scr_body.asm` del proyecto MSX.
  **Verificado**: desensamblado tomando `$EA60` como base (no `$5D2A`),
  el `JP $EBD8` del stub aterriza exacto en un inicio de instrucción
  real (`LD A,$00`) — con la hipótesis de dirección equivocada
  quedaría a mitad de otra instrucción. Y la aritmética cuadra sola:
  stub (14) + payload (4222) = 4236 = cola completa; `$EA60` +
  `$107E` (4222, la cuenta del `LDIR`) = `$FABE`, y `$EBD8` cae dentro
  de ese rango, a 408 bytes del inicio — consistente con que los
  primeros ~408 bytes copiados sean una tabla de datos (no código) que
  el `JP` deliberadamente se salta.

**Esta portada ocupa temporalmente ($EA60 en adelante) memoria que
más tarde pertenecerá a `CODE.bin` ($6000-$EFB5)** — se sobrescribe
sin conflicto porque para cuando `LOADER.bin` carga el motor real ahí
encima, la portada ya ha terminado su trabajo (dibujar la
presentación) y ha devuelto el control a la línea 20 de BASIC (de ahí
el `PAUSE 40` que viene DESPUÉS del `RANDOMIZE USR` en el listado).

### Cadena de arranque completa reconstruida (cinta → juego)

```
1. LOAD "" carga MAD-MIX.bas (4317B: 81B BASIC + 14B stub + 4222B portada)
2. RUN automatico (línea 10): PAPER 0: BORDER 0: CLEAR 50000
3. Línea 20: RANDOMIZE USR 23836 ($5D1C)
     -> stub: LDIR $5D2A->$EA60 (4222B), JP $EBD8
     -> rutina de portada (dibuja presentacion, vuelve a BASIC)
   PAUSE 40
4. Línea 30: LOAD "" carga MAD-MIX_2.bas (71B)
5. RUN automatico: BORDER 0: INK 7: PAPER 0: CLEAR 24575
     LOAD "LOADER" CODE   (carga LOADER.bin, 196B, en $EFB6)
     CLS
     RANDOMIZE USR 61366  ($EFB6)
6. LOADER.bin: lee de cinta SCREEN.scr -> $4000 (6912B)
               lee de cinta CODE.bin   -> $6000 (36790B, sobrescribe
                                           la portada que había ahí)
               JP $6000 -- arranca el motor real del juego
```

Los 3 últimos binarios de cinta son CONTIGUOS en memoria, sin hueco:
`CODE.bin` ocupa exacto `$6000-$EFB5` y `LOADER.bin` empieza en
`$EFB6` — confirmado por la propia longitud de `CODE.bin` (36790 =
`$8FB6`, y `$6000+$8FB6=$EFB6`).

### `SCREEN.scr` — confirmado que NO es código

Se pasó por `Z80Dasm.exe` solo para comprobarlo (`FISICO/SCREEN.scr.dasm.txt`):
el resultado son páginas de `NOP` (zonas en negro del bitmap) seguidas
de instrucciones sin ningún sentido de flujo — confirma que es un
bitmap de pantalla estándar sin comprimir (patrón 6144B + atributos
768B), no ejecutable. Se trata como recurso de datos
(`src/data/img/pantalla_carga.img`, cargado con `INCBIN` desde
`src/load_cas/screen_body.asm`), no como desensamblado.

### `tools/dasm2asm.py` — conversor mecánico de Z80Dasm a SjASMPlus

Para `CODE.bin` (36790 bytes) y el payload de portada (4222 bytes) no
era razonable transcribir a mano — se escribió un conversor: traduce
cada línea de `Z80Dasm.exe` a sintaxis SjASMPlus 1:1, y pone etiqueta
(`CODE_XXXX`/`PORTADA_XXXX`) solo en las direcciones que son a la vez
destino real de `CALL`/`JP`/`JR`/`DJNZ` DENTRO del propio fichero e
inicio real de una instrucción decodificada — el resto de operandos
con dirección absoluta se dejan en hex literal. Como el desensamblado
de `Z80Dasm.exe` es **lineal** (recorre todos los bytes del principio
al fin sin seguir el flujo real de ejecución), el resultado recompila
BYTE A BYTE IDÉNTICO al original **por construcción**, sin falta
entender todavía qué tramos son código real y cuáles son datos
malinterpretados como instrucciones — exactamente la misma situación
de partida que tuvo el proyecto MSX con sus binarios grandes, antes de
identificar sus huecos de datos uno a uno a lo largo de muchas
sesiones.

3 instrucciones de `CODE.bin` (`$C6E4`, `$C7A4`, `$DFA7`, bytes
`$FD $64`/`$FD $64`/`$FD $6C`) tuvieron que volcarse como `DB` en vez
de mnemónico: son la forma no documentada "medio-registro IX/IY
combinado con el H/L simple" (p. ej. `LD IYH,H`) que el Z80 real
ejecuta pero SjASMPlus no acepta como texto (los rechaza como
"Illegal instruction"). Su sola presencia, rodeada de varios
`RST 18H` seguidos, es indicio fuerte de que esa zona concreta es
tabla de datos, no código real — pendiente de confirmar en una sesión
de análisis semántico.

**Verificación de los 3 ficheros generados** (recompilados con
SjASMPlus, `DEVICE ZXSPECTRUM48` + `ORG` real + `INCLUDE` + `SAVEBIN`,
comparados byte a byte contra el binario extraído):

| Fichero fuente | Dirección | Bytes | Resultado |
|---|---|---|---|
| `src/load_cas/portada_stub_body.asm` | `$5D1C` | 14 | 0 diferencias |
| `src/portada_body.asm` | `$EA60` | 4222 | 0 diferencias |
| `src/madmix_body.asm` | `$6000` | 36790 | 0 diferencias |
| `src/load_cas/screen_body.asm` (INCBIN) | `$4000` | 6912 | 0 diferencias (por construcción) |
| `src/load_cas/loader_body.asm` (sesión 1) | `$EFB6` | 196 | 0 diferencias |

**Los 5 binarios de la versión de cinta están, por primera vez,
100% reconstruidos y verificados byte a byte** — aunque `madmix_body.asm`
y `portada_body.asm` son todavía reconstrucciones MECÁNICAS de primera
pasada (etiquetas por dirección, sin nombres con significado), no un
análisis semántico como `loader_body.asm`/`portada_stub_body.asm`.

### Pendiente para próximas sesiones (estado al cierre de la sesión 2)

- Análisis semántico real de `madmix_body.asm` (36790 bytes) y
  `portada_body.asm` (4222 bytes): identificar qué tramos son datos
  (sprites, tiles, niveles, sonido, texto) y reemplazar su
  desensamblado mecánico por `DB`/tablas con nombre; encontrar el
  bucle principal, el driver de sonido, la pantalla de créditos.
- Confirmar en vivo (emulador) que el arranque completo reconstruido
  funciona de principio a fin.
- Añadir soporte de números no enteros/grandes a `zxbasic_tool.py` si
  aparecen en análisis futuros (de momento solo cubre enteros
  0-65535, suficiente para los 4 números reales encontrados hasta
  ahora).

## Sesión 3 — 2026-08-09: compilación unificada y `.tzx` reconstruido al 100%

Petición: preparar la compilación completa (tarea de VSCode) para que
`build/` genere los binarios y, finalmente, el `.tzx` reconstruido
desde los fuentes, verificado byte a byte contra el original.

### `src/main.asm` — punto de entrada único

Une los 5 fragmentos de la sesión 2 en una sola pasada de SjASMPlus
(un solo `DEVICE ZXSPECTRUM48`, múltiples `ORG`/`INCLUDE`/`SAVEBIN`,
un único espacio de símbolos — sin colisiones, cada fragmento ya tenía
prefijos de etiqueta distintos). Requiere invocarse con el directorio
de trabajo en `src/` porque **SjASMPlus resuelve `INCLUDE`/`INCBIN`/
`SAVEBIN` relativos al directorio de trabajo del proceso, no a la
ubicación de cada fichero** — el mismo comportamiento ya documentado
en el `build_all.py` del proyecto MSX. Esto obligó a corregir la ruta
del `INCBIN` de `load_cas/screen_body.asm` (era `../data/img/...`,
válida solo al compilar ese fichero suelto desde `load_cas/`; pasó a
`data/img/...`, relativa a `src/`, la que usa de verdad `main.asm`).

### `tools/build_all.py` + `tools/gen_tzx_file.py`

Primero compila (`sjasmplus src/main.asm`, cwd=`src/`) los 5 binarios
a `src/build/`. Después, `gen_tzx_file.py`:

1. Tokeniza `load_cas/madmix_bas.bas` y `load_cas/madmix2_bas.bas`
   con `zxbasic_tool.py` (importado como módulo).
2. Reconstruye `MAD-MIX.bas` completo (4317 bytes) concatenando el
   BASIC tokenizado + `PORTADA_STUB.bin` + `PORTADA_PAYLOAD.bin` —
   exactamente como viaja de verdad en la cinta (ver sesión 2).
3. Arma el `.tzx` entero desde cero: cabecera `ZXTape!`, bloque de
   información de archivo (mismas 4 cadenas del original: título,
   editor, tipo, comentario "TZXed by johnny farragut"), y los 8
   bloques de datos estándar con las MISMAS pausas registradas en la
   sesión 1 (941/8415/944/7098/1/1/1/0 ms) y checksum XOR calculado
   (no copiado).
4. Compara el resultado byte a byte contra `FISICO/Mad Mix Game.tzx`.

**Resultado: reconstrucción desde cero (`rm -rf src/build build` +
`py tools/build_all.py` + `py tools/gen_tzx_file.py`) → `build/madmix_reconstruido.tzx`,
48485 bytes, 0 DIFERENCIAS contra el `.tzx` original de 1988.**
Primera vez que el proyecto reproduce un entregable completo al 100%
byte a byte, igual que el hito equivalente en el proyecto MSX con su
`.dsk`/`.cas`.

### `.vscode/tasks.json`

Actualizado (venía copiado tal cual del proyecto MSX, con una tarea
"Generar disco y cinta" que no aplica a Spectrum): ahora "Compilar
todo" (`build_all.py`), "Generar tzx" (`gen_tzx_file.py`), y "Compilar
todo + generar tzx" como tarea de compilación por defecto
(`Ctrl+Shift+B`), que encadena las dos anteriores.

### Pendiente para próximas sesiones (estado al cierre de la sesión 3)

- Análisis semántico real de `madmix_body.asm`/`portada_body.asm`
  (sin cambios respecto a la sesión 2 — sigue siendo el trabajo grande
  pendiente).
- Confirmar en vivo (emulador) que el `.tzx` reconstruido carga y
  arranca igual que el original.

## Sesión 4 — 2026-08-09: visores HTML (mapa de memoria + flujo/inventario)

Petición: crear `recursos/mapa_memoria.html` y
`recursos/flujo_programa.html`, igual que los del proyecto hermano de
MSX, para irlos rellenando sesión a sesión.

### `recursos/mapa_memoria.html`

Mismo diseño y CSS que el de MSX (barra de memoria a escala 0x0000-
0xFFFF con tooltip, tabla de detalle sin solapes, sección de ficheros
con flechas de reubicación). Contenido honesto al estado actual: la
categoría `mecanico` (nueva, no existe en el mapa de MSX) marca los
grandes tramos de `madmix_body.asm`/`portada_body.asm` como
"reconstruidos y verificados pero sin analizar todavía", en vez de
inventar categorías más finas (código/datos/nivel...) que en MSX
vinieron de sesiones reales de análisis que aquí aún no han pasado. La
sección de ficheros reutiliza el mismo mecanismo de "posición temporal
+ flecha de reubicación" para el caso de la portada ($5D2A tránsito →
$EA60 real, con nota de que `CODE.bin` sobrescribe después esa misma
zona) — arquitectura idéntica a `MADMIX.SCR` en MSX.

### `recursos/flujo_programa.html` + `tools/gen_inventory.py`

El diagrama de flujo (§1) cubre por ahora solo la cadena de arranque
completa (idéntica a la de `FINDINGS.md` sesión 2), con dos cajas
"pend" marcando donde empieza lo desconocido (entrada a
`portada_body.asm` y a `madmix_body.asm`).

`tools/gen_inventory.py` se adaptó del homónimo de MSX (parsea
`src/build/main.lst`, clasifica cada etiqueta por uso textual
heurístico, reescribe el array `INVENTORY` embebido en el HTML). Tuvo
que corregirse su regex de parseo de línea (`LST_LINE_RE`): el
listado de SjASMPlus de este proyecto pega la dirección sin espacio
justo detrás del `+` en líneas continuadas dentro de un `INCLUDE`
(`"52+6000"`), mientras que el de MSX aparentemente no lo hacía así (o
nunca se dio el caso con una etiqueta en una línea continuada) — la
regex original de MSX exigía un espacio ahí y no encontraba ninguna
etiqueta (0 de 1149). Corregida con una alternativa de dos grupos de
dirección según haya o no `+` pegado. Resultado tras la corrección:
**1149 etiquetas** (81 función, 1067 interna, 1 dato, 0 sin ref.) — la
inmensa mayoría son las etiquetas mecánicas `CODE_XXXX`/`PORTADA_XXXX`
de la sesión 2/3, sin nombre con significado todavía; es exactamente
el trabajo que irán rellenando las próximas sesiones de análisis
semántico.

### Primer vistazo semántico a `portada_body.asm` — confirmado visualmente por el usuario

Las primeras ~40 bytes de `portada_body.asm` ($EA60 en adelante) se
analizaron a mano: un bucle temporizado con `HALT`/`HALT` (~40 ms por
vuelta) que escribe atributos de color (`$42`=tinta roja brillante,
`$47`=tinta blanca brillante, ambos sobre papel negro) en la tabla de
atributos ($5800+), en 2 filas contiguas (fila 15-16 de 24) y 8
columnas (15-22), avanzando una columna por vuelta — un efecto de
"encendido" progresivo de color en una franja pequeña y centrada de
la pantalla.

**El usuario (jugador original) confirmó de memoria la secuencia
visual completa** al arrancar el juego: 1) logo animado de Topo Soft,
2) desaparece, 3) la portada se dibuja línea a línea en 3 zonas (arriba,
centro, abajo), cada una en líneas alternas, 4) carga el resto del
juego, 5) entrega el control. Contrastado contra lo ya reconstruido:

- El **logo animado** encaja con el bucle de color de arriba (y,
  case seguro, con más código de animación en el resto de los 4222
  bytes de `portada_body.asm`, sin analizar todavía).
- El **"desaparece"** es el `CLS` de `madmix2_bas.bas`, justo antes de
  `RANDOMIZE USR 61366`.
- La **portada línea a línea en 3 zonas, en líneas alternas** —
  verificado con aritmética real de direcciones de pantalla del
  Spectrum, NO es un efecto programado a propósito: es la consecuencia
  mecánica inevitable de escribir bytes en orden secuencial de
  dirección dentro de la memoria de pantalla ($4000-$57FF, 3 tercios
  de 2048 bytes). Dentro de un tercio, direcciones consecutivas
  recorren las filas de píxel en el orden 0,8,16,24,32,40,48,56,
  1,9,17,25... (verificado por cálculo) — exactamente "líneas
  alternas, cada vez más densas" — y esto se repite una vez por cada
  uno de los 3 tercios (arriba/centro/abajo), en ese orden, porque son
  3 bloques de memoria consecutivos. Es justo lo que hace `LOADER.bin`
  (ya verificado en la sesión 1) al leer `SCREEN.scr` byte a byte
  hacia `$4000` con `IX` incrementando.
- **Carga del resto + entrega de control**: `LOADER.bin` cargando
  `CODE.bin` en `$6000` (sin efecto visual, no es memoria de pantalla)
  y el `JP $6000` final.

Confirma con una fuente independiente (memoria visual del jugador, no
solo análisis estático) que la reconstrucción de la cadena de arranque
de las sesiones 1-3 es correcta de principio a fin, y que
`portada_body.asm` es, con alta confianza, el dibujado/animación del
logo de Topo Soft (pendiente de análisis semántico completo).

### Pendiente para próximas sesiones (estado al cierre de esta ronda)

- Seguir el análisis semántico de `portada_body.asm` (4222 bytes, solo
  ~40 analizados) con la hipótesis ahora bien apoyada de que es la
  animación del logo de Topo Soft -- y de `madmix_body.asm` (36790
  bytes, motor completo) -- sigue siendo el trabajo grande pendiente;
  cada hallazgo debería reflejarse tanto en `FINDINGS.md` como
  renombrando la etiqueta correspondiente (así el inventario y el mapa
  de memoria se actualizan solos al re-ejecutar `tools/build_all.py` +
  `tools/gen_inventory.py`).
- Confirmar en vivo (emulador) que el `.tzx` reconstruido carga y
  arranca igual que el original, y que se ve la secuencia visual
  descrita arriba.

## Sesión 5 — 2026-08-09: `DIBUJAR_FORMA_LOGO` — mecanismo del logo animado

Petición: analizar `PORTADA_EA82` a partir de la hipótesis del
usuario ("el logo TOPO son 4 letras, cada una se mueve hasta su
posición final; puede que las 4 llamadas sean 4 letras moviéndose").

### Mecanismo confirmado con datos reales del binario

`PORTADA_EA82` usa **3 parámetros autoemodificados** (no solo
código estático):

- **`$EA8E`** (operando bajo de `LD HL,$000E`) → índice·2 en la tabla
  `$ECF1` → puntero a 81 bytes de forma (27 filas × 3 bytes) en
  `$EF1C+`. Se fija **una sola vez** por secuencia de animación
  (`EB6D` fija `$EA8E=8`, `EB53` fija `9`, `EB95` fija `$0A`) → decide
  **QUÉ** forma se dibuja.
- **`$EA83`** (operando bajo de `LD HL,$006E`) → índice en la tabla
  `$ED9C`. **Volcada y verificada byte a byte**: es la tabla clásica
  de conversión fila-de-píxel→dirección de pantalla del Spectrum
  (entrada 0 = `$4000`, entrada 8 = `$4020`, entrada 64 = `$4800`
  exacto inicio del tercio central, etc. — confirmado con aritmética
  real, no solo lectura de mnemónicos). El código lee 27 entradas
  CONSECUTIVAS a partir de este índice (via `SP`/`POP`, un truco
  clásico de copia rápida) → decide **DÓNDE** (fila superior de las
  27) se dibuja. Cambia en cada llamada dentro de un bucle.
- **`$EAB6`** (operando bajo de `LD HL,$0016`, dentro del bucle de
  copia) → desplazamiento de columna, también autoemodificado.

Dos motores de movimiento ya localizados, con comportamiento bien
distinto (extraído de las tablas reales, no inferido):

- **`PORTADA_EB6D`**: fila $06→$3E en pasos aritméticos fijos de 8 —
  deslizamiento recto (¿caída vertical de una letra?).
- **`PORTADA_EB95`**: guion tabulado en `$ED29`, filas
  62→54→46→42→38→30→26→22→26→30→38→42→46→54→62 (baja y vuelve a
  subir) con la columna (`$EAB6`) subiendo despacio a la vez —
  movimiento curvo/rebote, distinto del anterior.

**Hallazgo adicional**: `PORTADA_ECE0` (llamado en bucle por
`PORTADA_EB44`/`PORTADA_EB53`, que parecían usar "otra" rutina de
dibujo) resultó ser trivial: `EI / HALT / JP DIBUJAR_FORMA_LOGO` — un
simple "espera 1 frame y dibuja la forma actual". Confirma que esas
dos secuencias TAMBIÉN son animaciones de `DIBUJAR_FORMA_LOGO`, no
mecanismos aparte. En total hay **5** puntos de llamada/salto a la
rutina (no 4 como parecía a primera vista por el texto del código),
repartidos en al menos 5-7 secuencias candidatas (`EC29`, `EB38`,
`EB44`, `EB53`, `EB6D`, `EB95`, `EBB9`), todas invocadas en orden
desde el punto de entrada real `$EBD8` (el destino final del `JP` del
stub de portada, ver sesión 2).

### Pendiente / sin confirmar

Se intentó renderizar los 81 bytes de forma (`$EA8E`=8/9/$0A) como
bitmap 27×3 directo — el resultado **no es un glifo limpio
reconocible**: las 3 formas salen parecidas entre sí (compatible con
ser variantes/fotogramas relacionados) pero con demasiado "ruido"
para leerse como letra a simple vista. Posibles explicaciones sin
confirmar: el formato real podría ser máscara+tinta en dos planos
(técnica común de sprites Spectrum) en vez de bitmap directo de un
solo plano, o el layout de 27 filas lineales no sea correcto. **No se
ha confirmado todavía qué valor de `$EA8E` corresponde a qué letra**
(T/O/P/O) ni si son exactamente 4 formas distintas o alguna más
(candidatas a "Soft" o una estrella, por analogía con el logo
animado — ya identificado y confirmado visualmente — de la versión
MSX, `LOGOTOPO.CM`).

### Cambios aplicados

- `src/portada_body.asm`: `PORTADA_EA82` → **`DIBUJAR_FORMA_LOGO`**
  (con comentario extenso documentando los 3 parámetros
  autoemodificados y las 2 secuencias de movimiento ya entendidas).
  **Verificado**: recompilado, sigue dando 0 diferencias contra el
  `.tzx` original.
- `tools/gen_inventory.py` re-ejecutado — `DIBUJAR_FORMA_LOGO` ya
  aparece como `función` en el inventario.

### La tabla `$ECF1` tiene exactamente 15 entradas — mismo recuento que MSX

Recorriendo la tabla de punteros `$ECF1` (la que indexa `$EA8E`) más
allá de los 3 índices vistos hasta ahora: las entradas 0-14 dan
direcciones crecientes y coherentes dentro de `portada_body.asm`
(15 entradas en total); a partir del índice 15 los valores dejan de
tener sentido (caen fuera de rango / se solapan con entradas
anteriores) — la tabla real son **15 formas**, ni una más ni una
menos. Coincide EXACTO con el recuento ya resuelto de
`LOGOTOPO.CM` en el proyecto MSX (7 fotogramas de "Soft" + 4 letras
T-O-P-O + 4 fotogramas de estrella = 15).

Además confirma la hipótesis de agrupación: `PORTADA_EBB9` (tabla
`$ED48`) cicla `$EA8E` DIRECTAMENTE por los índices `$0B,$0C,$0D,$0C,
$0B,$0C,$0D,$0E` (manteniendo posición fija, `$EAB6`/`$EA83` fijos)
— un ciclo de 4 formas (índices 11-14) sin mover nada de sitio,
exactamente el patrón esperado de un "parpadeo" de estrella (mismos 4
índices que en MSX). Junto con el ciclo 0→6→0 de `PORTADA_EB28` (7
formas, "Soft" rotando) ya documentado arriba, quedan acotados los 3
grupos: **0-6 = Soft (7), 7-10 = letras T-O-P-O (4), 11-14 = estrella
(4)** — misma estructura que MSX, aunque el contenido visual de cada
forma sigue sin confirmarse (ver más abajo).

### `recursos/logotopo_formas.html` — explorador interactivo

Creado (a petición del usuario, "hasta que demos con ellos") como el
equivalente exploratorio del `logotopo_formas.html` de MSX — con una
diferencia importante: el de MSX renderiza un formato YA RESUELTO
(tiles 8x8 fijos); este renderiza con **controles ajustables en vivo**
(bytes/fila, bytes a saltar, total de bytes) porque el formato real
todavía no se conoce. Contiene los 15 candidatos con una ventana
generosa de bytes cada uno (hasta 776 bytes, acotada por la siguiente
forma o el final de `portada_body.asm`). Con la hipótesis inicial
(3 bytes/fila, sin saltar cabecera) ninguna forma sale legible
todavía — herramienta lista para seguir probando en próximas sesiones
o a mano por el usuario.

### Pendiente para próximas sesiones (superado por la sesión 6)

- ~~Usar `recursos/logotopo_formas.html` para probar otros anchos/
  offsets y encontrar el formato real de las formas~~ — **HECHO, ver
  sesión 6**.
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente.
- Confirmar en vivo (emulador) el arranque completo reconstruido.

## Sesión 6 — 2026-08-09: las 15 formas del logo, IDENTIFICADAS

El usuario jugó a mano con los controles de
`recursos/logotopo_formas.html` (bytes/fila, bytes a saltar, total de
bytes) y encontró los parámetros reales de las 15 formas — **las 4
letras T-O-P-O y los 7 fotogramas de "SOFT" ya se leen limpias**.
Verificado de forma independiente renderizando con los mismos
parámetros exactos (script Python aparte, ASCII-art) — confirmado
visualmente por mí también antes de fijarlo en el código: la forma 0
se lee "SOFT" sin ambigüedad, y la forma 7 muestra con claridad la
barra horizontal + el trazo vertical de una "T".

### Parámetros confirmados (formato: bytes/fila, bytes de cabecera, bytes de dibujo tras la cabecera)

| idx | Nombre | bytes/fila | cabecera | bytes dibujo | filas | bytes "muertos" extra |
|---|---|---|---|---|---|---|
| 0-6 | SOFT, fotogramas 1-7/7 | 8 | 2 | 128 | 16 | hasta 130 sin cambio visual (2 de más) |
| 7 | T de TOPO | 9 | 3 | 765 | 85 | hasta 776 sin cambio visual (11 de más) |
| 8 | O (1ª) de TOPO | 5 | 2 | 230 | 46 | hasta 232 sin cambio visual (2 de más) |
| 9 | P de TOPO | 6 | 2 | 438 | 73 | hasta 440 sin cambio visual (2 de más) |
| 10 | O (2ª) de TOPO | 6 | 2 | 318 | 53 | hasta 320 sin cambio visual (2 de más) |
| 11-14 | estrella, fotogramas 1-4/4 | 3 | 2 | 81 | 27 | hasta 83 sin cambio visual (2 de más) |

Los "bytes muertos" de más en cada grupo son casi con toda seguridad
relleno/alineación al final de cada bloque de datos (o el margen de
seguridad de la ventana que se dumpeó al generar el HTML, acotada por
la dirección de la SIGUIENTE forma) — no forman parte del dibujo.

**Hallazgo clave**: el grupo de la estrella (idx 11-14: `3 bytes/fila,
2 de cabecera, 81 de dibujo = 27 filas`) coincide EXACTO con las
constantes que `DIBUJAR_FORMA_LOGO` (`PORTADA_EA82`) tiene
HARDCODEADAS en su propio código (`LD C,$1B`=27, `LD B,$03`=3) y con
el header de 2 bytes que lee antes de copiar (`$EABE`/`$EAB3`) — esto
**confirma que `DIBUJAR_FORMA_LOGO` es la rutina que dibuja
específicamente la estrella**, no una rutina genérica para las 15
formas como se pensaba en la sesión 5. "SOFT" (8 bytes/fila) y las
letras T/O/P/O (9/5/6/6 bytes/fila, anchos DISTINTOS entre sí — la T
es más ancha) deben dibujarse con otra rutina de ancho variable,
todavía sin localizar — candidatas: `PORTADA_EC29`/`PORTADA_EB38`
(las primeras llamadas desde el punto de entrada real `$EBD8`, antes
de que se llegue a `EB53`/`EB6D`/`EB95`/`EBB9`, que sí usan
`DIBUJAR_FORMA_LOGO`/estrella).

### Cambios aplicados

- `recursos/logotopo_formas.html`: cada tarjeta ahora arranca con los
  parámetros confirmados (antes: genérico 3/0/81 para las 15) y
  muestra el nombre real en el título. Nota superior actualizada de
  "sin confirmar" a "confirmado visualmente por el usuario".

### Pendiente para próximas sesiones (parcialmente resuelto en sesión 7)

- Localizar la rutina que dibuja "SOFT" y las letras T/O/P/O (ancho
  variable, cabecera de 2-3 bytes) — probablemente `PORTADA_EC29`
  y/o `PORTADA_EB38`, las dos primeras llamadas desde `$EBD8` sin
  trazar todavía.
- Una vez localizada, renombrarla y documentar cómo decide el ancho
  por forma (¿otro byte de cabecera? ¿tabla aparte?).
- Confirmar el orden real de aparición en pantalla (Soft primero,
  luego T-O-P-O, ¿estrella junto a la T como en MSX?) trazando
  `PORTADA_EC29`/`EB38`/`EB44`/`EB53`/`EB6D`/`EB95`/`EBB9` en el orden
  real en que las llama `$EBD8`.
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente.
- Confirmar en vivo (emulador) el arranque completo reconstruido.

## Sesión 7 — 2026-08-09: las 15 formas a fichero + mapa de memoria de la portada

Petición: extraer las 15 formas del logo a ficheros independientes en
`data/`, cargarlos con `INCBIN` y ponerles etiquetas reales
(`LOGO_SOFT_1`...`LOGO_ESTRELLA_4`); y crear
`mapa_memoria_logotopo.html` (igual que el de MSX para
`LOGOTOPO.CM`) para desglosar la memoria de esta fase, ya que aquí
también el logo reutiliza memoria que luego ocupa el motor.

### Las 15 formas, extraídas a `src/data/img/logo/*.img`

Localizado el punto de corte exacto: el rango `$EF1C-$FADD` (3010
bytes, el resto del payload de portada tras `PORTADA_EF13`) es
**puramente datos de las 15 formas, sin ningún código intercalado** —
verificado sumando los 15 tamaños reales (calculados como la
distancia entre cada entrada de `TABLA_PUNTEROS_FORMAS_LOGOTIPO` y la
siguiente, o hasta el final del payload para la última) y comprobando
que suman exacto los 3010 bytes disponibles, sin huecos ni solapes.
Cada bloque se extrajo tal cual (cabecera de 2-3 bytes incluida, no
solo los píxeles) a su propio fichero:

`src/portada_body.asm` reemplaza ahora ese tramo mecánico (2671
líneas de pseudo-instrucciones sin sentido) por 15 etiquetas +
`INCBIN`, ordenadas igual que `TABLA_PUNTEROS_FORMAS_LOGOTIPO`:
`LOGO_SOFT_1`..`LOGO_SOFT_7`, `LOGO_T`, `LOGO_O1`, `LOGO_P`,
`LOGO_O2`, `LOGO_ESTRELLA_1`..`LOGO_ESTRELLA_4`. **Verificado**:
recompilado, `build/madmix_reconstruido.tzx` sigue dando 0
diferencias contra el original.

### Las 4 tablas de control, identificadas (aunque todavía sin extraer a fichero)

Al determinar los límites exactos de las 15 formas se identificaron
también, con precisión de byte, las 4 tablas de control que hasta
ahora solo se conocían por su contenido volcado a mano:

| Tabla | Rango | Tamaño | Contenido |
|---|---|---|---|
| `TABLA_PUNTEROS_FORMAS_LOGOTIPO` | `$ECF1-$ED0E` | 30 B (15×2) | punteros a cada una de las 15 formas, indexados por `$EA8E` |
| `TABLA_CICLO_SOFT` | `$ED0F-$ED28` | 26 B | secuencia 0..6..0 + `$FF`, consumida por `PORTADA_EB28` |
| `GUION_MOVIMIENTO_REBOTE` | `$ED29-$ED47` | 31 B | 15 pares (col,fila) + `$FF`, consumido por `PORTADA_EB95` |
| `GUION_CICLO_ESTRELLA` | `$ED48-$ED50` | 9 B | 8 índices + `$FF`, consumido por `PORTADA_EBB9` |
| `TABLA_FILAS_PANTALLA` | `$ED9C-$EF1B` | 384 B (192×2) | tabla completa fila-de-píxel→dirección de pantalla (las 192 filas, no solo las usadas) — termina justo 1 byte antes de `LOGO_SOFT_1`, confirmando que no hay hueco |

Entre `GUION_CICLO_ESTRELLA` y `TABLA_FILAS_PANTALLA` quedan 75 bytes
(`$ED51-$ED9B`) mayoritariamente rellenos con el patrón repetido
`$ED,$A0` (29 veces) — probable relleno/alineación, no una tabla
activa; sin confirmar del todo.

### `recursos/mapa_memoria_logotopo.html`

Mapa de memoria con escala propia acotada a `$EA60-$FADD` (el payload
de portada completo, 4222 bytes), misma plantilla visual que
`mapa_memoria.html`. Cubre, sin huecos ni solapes (verificado
programáticamente), los 26 tramos ya identificados: `ANIMAR_DESTELLO_LOGO`,
`DIBUJAR_FORMA_LOGO`, las secuencias de movimiento (con su estado real
de análisis: completo/parcial/pendiente), las 4 tablas de control, el
tramo de relleno sin identificar, y las 15 formas gráficas.

### Pendiente para próximas sesiones

- ~~Extraer `TABLA_PUNTEROS_FORMAS_LOGOTIPO` a `DW` nativo con nombre~~ —
  **HECHO, ver sesión 8**.
- Extraer las 3 tablas de control restantes (`TABLA_CICLO_SOFT`,
  `GUION_MOVIMIENTO_REBOTE`, `GUION_CICLO_ESTRELLA`) y
  `TABLA_FILAS_PANTALLA` a `DW`/`DB` nativos con nombre — hoy siguen
  siendo pseudo-código mecánico sin sentido en `portada_body.asm`.
- Resolver los 75 bytes de relleno sin identificar (`$ED51-$ED9B`).
- Localizar la rutina que dibuja "SOFT"/T-O-P-O (sigue pendiente,
  ver sesión 6).
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente.
- Confirmar en vivo (emulador) el arranque completo reconstruido.

## Sesión 8 — 2026-08-09: `TABLA_PUNTEROS_FORMAS_LOGOTIPO` con etiquetas reales

Petición: las 15 formas ya tienen etiqueta propia, pero sus
direcciones seguían usándose "a mano" en dos sitios — localizarlos y
sustituirlos por las etiquetas nuevas.

Localizados con `grep` los 2 únicos puntos reales (el resto de
tablas/índices no referencian estas 15 direcciones, solo índices 0-14
o direcciones de fila de pantalla, sin relación):

1. **`DIBUJAR_FORMA_LOGO`** (`$EAD3`-ish): `LD HL,$EF1C` — la base a
   la que se suma el desplazamiento leído de la tabla. Cambiado a
   `LD HL,LOGO_SOFT_1` (misma dirección, `$EF1C`, ahora simbólica).
2. **`TABLA_PUNTEROS_FORMAS_LOGOTIPO`** (`$ECF1-$ED0E`, 30 bytes): hasta ahora
   pseudo-código mecánico sin sentido; son 15 punteros de 2 bytes,
   cada uno un DESPLAZAMIENTO desde `LOGO_SOFT_1` hasta el inicio real
   de cada forma. Reescrita como tabla `DW` nativa con aritmética de
   etiquetas (`DW LOGO_SOFT_2-LOGO_SOFT_1`, etc.) en vez de los 15
   valores hex sueltos — el propio ensamblador calcula el
   desplazamiento correcto; si algún día cambia el tamaño de una
   forma, la tabla se recalcula sola.

**Verificado**: recompilado, `build/madmix_reconstruido.tzx` sigue
dando 0 diferencias — confirma además, de forma independiente, que el
desplazamiento de cada forma es exactamente
`direccion_forma - LOGO_SOFT_1` (la hipótesis de la sesión 6/7 era
correcta al 100%).

### Pendiente para próximas sesiones

- ~~Extraer las 3 tablas de control restantes y `TABLA_FILAS_PANTALLA`
  a `DW`/`DB` nativos con nombre~~ — **HECHO, ver continuación de la
  sesión 8 más abajo.**
- Resolver los 75 bytes de relleno sin identificar (`$ED51-$ED9B`).
- Localizar la rutina que dibuja "SOFT"/T-O-P-O (sigue pendiente,
  ver sesión 6).
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente.
- Confirmar en vivo (emulador) el arranque completo reconstruido.

### Continuación sesión 8: las 4 tablas de control restantes, extraídas

Mismo tratamiento que `TABLA_PUNTEROS_FORMAS_LOGOTIPO`: las 3 tablas de guion/
ciclo (pequeñas, se quedan como `DB` inline con comentario, no
merece la pena un fichero aparte) y `TABLA_FILAS_PANTALLA` (384
bytes, sí a fichero propio vía `INCBIN`, igual que las 15 formas)
sustituyen ahora el pseudo-código mecánico que tenían antes:

- `TABLA_CICLO_SOFT` ($ED0F, 26 B) — `DB` inline.
- `GUION_MOVIMIENTO_REBOTE` ($ED29, 31 B) — `DB` inline.
- `GUION_CICLO_ESTRELLA` ($ED48, 9 B) — `DB` inline.
- `TABLA_FILAS_PANTALLA` ($ED9C, 384 B) — `src/data/img/logo/tabla_filas_pantalla.img`, `INCBIN`.

**Hallazgo al hacerlo**: la primera compilación falló con `Label not
found: PORTADA_ED85` — un `CALL PORTADA_ED85` real, dentro de
`PORTADA_EAFC`, apuntaba a una dirección que la sesión 7 había
etiquetado como parte del "relleno sin identificar" ($ED51-$ED9B).
**Esto corrige esa sesión**: $ED85 no es relleno — hay al menos un
llamador real ahí, así que es una rutina genuina sin analizar
todavía (los bytes en ese punto, leídos linealmente, dan el mismo
patrón `$ED,$A0` que el resto del relleno, pero eso no prueba nada:
un `CALL` real aterrizando ahí exige desensamblar desde ese byte
exacto, no fiarse de la lectura lineal previa — mismo tipo de aviso
que ya se dio para el resto de `madmix_body.asm`/`portada_body.asm`).
Se restauró la etiqueta (como marca de posición dentro del `DB`, sin
tocar ni un byte) y se dividió el segmento "relleno" en dos en
`mapa_memoria_logotopo.html`: `$ED51-$ED84` (relleno, sin llamador
conocido) y `$ED85-$ED9B` (`PORTADA_ED85`, con llamador real,
pendiente de análisis).

**Verificado**: recompilado, `build/madmix_reconstruido.tzx` sigue
dando 0 diferencias.

### Pendiente para próximas sesiones (parte cubierta en sesión 9)

- Analizar `PORTADA_ED85` (23 bytes, con llamador real confirmado) —
  desensamblar desde ese byte exacto, no asumir el patrón lineal.
- Resolver los 52 bytes de relleno restantes sin identificar
  (`$ED51-$ED84`).
- Localizar la rutina que dibuja "SOFT"/T-O-P-O (sigue pendiente,
  ver sesión 6).
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente.
- Confirmar en vivo (emulador) el arranque completo reconstruido.

## Sesión 9 — 2026-08-09: pulido de nombres y convención decimal/hex

Varios repasos pequeños sobre lo ya analizado, todos verificados
recompilando (0 diferencias cada vez):

- **`TABLA_PUNTEROS_FORMA` → `TABLA_PUNTEROS_FORMAS_LOGOTIPO`** — a
  petición del usuario, más explícito (son punteros a las formas del
  logotipo, no "formas" en general, que en `madmix_body.asm` podría
  confundirse con otra cosa). Renombrado en `portada_body.asm`,
  `FINDINGS.md` y `mapa_memoria_logotopo.html`.
- **`PORTADA_EAB4` → `.BUCLE_FILAS_FORMA`, `PORTADA_EABF` →
  `.BUCLE_BYTES_FILA`** — los dos bucles (exterior/interior) de copia
  de `DIBUJAR_FORMA_LOGO`: por cada una de las 27 filas de la forma,
  saca la dirección real de esa fila de `TABLA_FILAS_PANTALLA` (vía
  `POP`, usando `SP` como puntero de lectura rápido en vez de pila de
  verdad), le suma la columna, y copia ahí los 3 bytes siguientes de
  la forma. Etiquetas locales (con `.`) porque solo se referencian a
  sí mismas, igual que `.BUCLE_DESTELLO_LOGO`.
- **Convención decimal/hex, aplicada retroactivamente** (petición del
  usuario: "ir convirtiendo en decimal los datos en los que proceda
  hacerlo"). Regla adoptada: las **direcciones de memoria** se quedan
  en hex (convención universal en ensamblador); las **cantidades**
  (tamaños, contadores de bucle, índices, coordenadas fila/columna)
  pasan a decimal cuando eso ayuda a leerlas, salvo los bytes
  centinela tipo `$FF` (se quedan en hex, es su forma habitual).
  Aplicado a:
  - `load_cas/portada_stub_body.asm`: `LD BC,$107E` → `LD BC,4222`.
  - `portada_body.asm`, `ANIMAR_DESTELLO_LOGO`: `LD BC,$0020` → `LD BC,32`.
  - `portada_body.asm`, `DIBUJAR_FORMA_LOGO`: los 5 operandos
    autoemodificados (`$EA83`=fila, `$EA8E`=índice de forma,
    `$EAB6`=columna) y las 2 constantes de bucle (`C`=filas,
    `B`=bytes/fila) — ahora en decimal, con nota de qué forma real
    corresponde al valor compilado por defecto de `$EA8E` (14 =
    `LOGO_ESTRELLA_4`).
  - Las 3 tablas de guion/ciclo (`TABLA_CICLO_SOFT`,
    `GUION_MOVIMIENTO_REBOTE`, `GUION_CICLO_ESTRELLA`) — sus valores
    son índices de forma (0-14) y coordenadas fila/columna, ahora en
    decimal (coincide directamente con las cifras ya citadas en sus
    comentarios, p.ej. "fila baja de 62 a 22").
  - `PORTADA_RELLENO_ED51`/`PORTADA_ED85` se dejan en hex a propósito
    — son bytes sin identificar, convertirlos a decimal no aportaría
    ningún significado todavía.

### 6 referencias literales más, sustituidas por etiquetas

Repaso pedido por el usuario ("revisa las etiquetas de las tablas y
dónde deben utilizarse en lugar de las direcciones en hexadecimal"):
`grep` de las 6 direcciones de tabla (`$ED0F`, `$ED29`, `$ED48`,
`$ED9C`, `$ECF1`, `$ED51`) encontró **6 sitios reales** que seguían
usando el número en vez de la etiqueta:

| Sitio | Antes | Después |
|---|---|---|
| `DIBUJAR_FORMA_LOGO` | `LD DE,$ED9C` | `LD DE,TABLA_FILAS_PANTALLA` |
| `DIBUJAR_FORMA_LOGO` | `LD DE,$ECF1` | `LD DE,TABLA_PUNTEROS_FORMAS_LOGOTIPO` |
| `PORTADA_EAD3` | `LD DE,$ED9C` | `LD DE,TABLA_FILAS_PANTALLA` |
| `PORTADA_EAD3` | `LD DE,$ED51` | `LD DE,PORTADA_RELLENO_ED51` |
| `PORTADA_EB28` (setup) | `LD HL,$ED0F` | `LD HL,TABLA_CICLO_SOFT` |
| `PORTADA_EB95` (setup) | `LD HL,$ED29` | `LD HL,GUION_MOVIMIENTO_REBOTE` |
| `PORTADA_EBB9` (setup) | `LD HL,$ED48` | `LD HL,GUION_CICLO_ESTRELLA` |

(7 filas porque `$ED9C` aparecía dos veces, en dos rutinas distintas.)

**Hallazgo al revisar `PORTADA_EAD3`** (la rutina llamada justo
después de cada `DIBUJAR_FORMA_LOGO` en las secuencias de
movimiento, aún sin analizar del todo): calcula
`HL = (32 - $EABE)*2 + PORTADA_RELLENO_ED51` y guarda el resultado
como puntero — una aritmética de INDEXACIÓN real, no un uso
incidental de esa dirección. Esto es indicio de que
`PORTADA_RELLENO_ED51` (los 52 bytes que la sesión 7 marcó como
"relleno sin identificar") podría ser en realidad **una tabla activa
indexada**, no relleno — anotado en el propio código y pendiente de
confirmar.

**Verificado**: recompilado, 0 diferencias. Con esto,
`portada_body.asm` ya no tiene ninguna referencia literal a las
direcciones de las tablas identificadas — todas usan su etiqueta.

### Pendiente para próximas sesiones

- Confirmar si `PORTADA_RELLENO_ED51` es una tabla real (indexada
  por `(32-$EABE)*2` desde `PORTADA_EAD3`) en vez de relleno —
  revisar qué son sus 52 bytes con esa hipótesis en mente.
- Analizar `PORTADA_ED85` (23 bytes, con llamador real confirmado) —
  desensamblar desde ese byte exacto, no asumir el patrón lineal.
- Localizar la rutina que dibuja "SOFT"/T-O-P-O (sigue pendiente,
  ver sesión 6).
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente.
- Confirmar en vivo (emulador) el arranque completo reconstruido.

## Sesión 10 — 2026-08-09: la secuencia maestra del logo, resuelta por completo

Analizando `PORTADA_EAB4`/`PORTADA_EB92`/`PORTADA_EB6D` a petición del
usuario apareció, por fin completa, la llamada maestra en `$EBD8`
(antes solo se conocía el principio) — con eso se resolvieron de
golpe casi todas las piezas sueltas de `portada_body.asm`.

### El misterio de `$8738`, resuelto

`RESTAURAR_FRANJA_FONDO` (antes `PORTADA_EAD3`) calculaba
`dirección_pantalla + $8738` como origen de una copia — sesiones
anteriores lo dejaron como "no encaja, copia de memoria sin
inicializar". Al aparecer `GUARDAR_PANTALLA_LOGO` (antes
`PORTADA_ECE5`: `LD HL,$4000/DE,$C738/BC,$1B00/LDIR` — copia la
pantalla ENTERA, 6912 bytes, a un búfer en `$C738`) se resolvió solo:
`$C738 - $4000 = $8738`. La rutina no lee basura — traduce una
dirección de pantalla a la MISMA celda dentro del búfer guardado, y
copia 6 bytes de vuelta a la pantalla real vía `RESTAURAR_FRANJA_FILA`
(antes `PORTADA_ED85`, redesensamblada desde su dirección real: 6
`LDI` + `RET`). Es la técnica clásica "guarda el fondo antes de mover
el sprite, restáuralo cada fotograma para borrar el rastro" — nada de
bug ni acceso a memoria sin inicializar.

### La secuencia maestra completa (`SECUENCIA_LOGO_TOPO_SOFT`, `$EBD8`)

Es el destino real del `JP` del stub de portada (antes literal
`$EBD8`, ahora con etiqueta — también corregido en
`load_cas/portada_stub_body.asm`). Orquesta, en este orden exacto:

1. `LIMPIAR_PANTALLA_LOGO` (antes `PORTADA_EC29`) — borra la pantalla
   entera: atributos a `$47` (tinta blanca/papel negro), bitmap a 0.
2. `ANIMAR_LOGO_T` (antes `PORTADA_EB38`) — la **T** (forma 7), fila
   fija 50, se asienta con un ajuste de 3 columnas.
3. `ANIMAR_LOGO_P` (antes `PORTADA_EB53`) — la **P** (forma 9), fila
   fija 62, entra deslizando columna 26→10.
4. `GUARDAR_PANTALLA_LOGO` — snapshot de pantalla.
5. `ANIMAR_LOGO_O1` (antes `PORTADA_EB6D`) — la **primera O** (forma
   8, no la letra "SOFT" como se creía en sesión 5), cae en línea
   recta filas 6→62.
6. `GUARDAR_PANTALLA_LOGO` otra vez.
7. `ANIMAR_LOGO_O2` (antes `PORTADA_EB95`) — la **segunda O** (forma
   10, no 8 como se creía antes), guion de rebote filas 62→22→62.
8. `PORTADA_EC66` — decoración (llama a `RELLENAR_BLOQUE_COLOR` dos
   veces por vuelta, 9 vueltas, colores/posiciones cambiantes) — sin
   confirmar el efecto visual exacto todavía.
9. `RELLENAR_BLOQUE_COLOR` (antes `PORTADA_EC4D`) — rutina genérica
   parametrizada "rellena N filas de 8 celdas con un color" — aquí
   prepara el bloque rojo antes del destello.
10. `ANIMAR_LOGO_SOFT` (antes `PORTADA_EB17`) ×3 — "SOFT" rotando en
    su sitio (fila 120, columna 15), 3 vueltas completas.
11. `ANIMAR_DESTELLO_LOGO` — el destello de color de la sesión 4/5.
12. `ANIMAR_ESTRELLA` (antes `PORTADA_EBB9`) — la estrella parpadea
    en su sitio fijo (fila 110, columna 22 — los mismos valores por
    defecto compilados en `DIBUJAR_FORMA_LOGO`, tiene sentido: es la
    única forma que nunca se mueve).
13. `RET` — fin de la portada, vuelve a BASIC (línea 20 continúa con
    `PAUSE 40`).

Esto **corrige** una idea de la sesión 5: `PORTADA_EB6D`/`EB95` no
eran "dos letras cualesquiera" — son las dos **O** de TOPO (formas 8 y
10), y las formas 7 (T) y 9 (P) las anima un mecanismo más simple
(`ANIMAR_LOGO_T`/`ANIMAR_LOGO_P`, sin `RESTAURAR_FRANJA_FONDO`, solo
ajustes pequeños de posición) que no se había localizado hasta ahora.

### `RELLENAR_BLOQUE_COLOR` (antes `PORTADA_EC4D`)

Rutina genérica reutilizable: rellena `($EC4E)` filas de 8 celdas de
atributo con el color `($EC5A)`, empezando en `($EC50)`, bajando 32
(una fila) cada vez — los 3 parámetros son autoemodificados. La usan
tanto la secuencia maestra (antes de `ANIMAR_DESTELLO_LOGO`) como
`PORTADA_EC66`.

### Cambios aplicados (todos verificados, 0 diferencias cada vez)

| Antes | Después |
|---|---|
| `PORTADA_EC29` | `LIMPIAR_PANTALLA_LOGO` |
| `PORTADA_ECE5` | `GUARDAR_PANTALLA_LOGO` |
| `PORTADA_EAD3` | `RESTAURAR_FRANJA_FONDO` |
| `PORTADA_EAFC` | `.BUCLE_RESTAURAR_FRANJA` (local) |
| `PORTADA_ED85` | `RESTAURAR_FRANJA_FILA` (global -- no podía ser local, está físicamente lejos de quien la llama) |
| `PORTADA_ECE0` | `DIBUJAR_FORMA_TEMPORIZADA` |
| `PORTADA_EB17` / `EB28` | `ANIMAR_LOGO_SOFT` / `.BUCLE_LOGO_SOFT` |
| `PORTADA_EB38` / `EB44` | `ANIMAR_LOGO_T` / `.BUCLE_LOGO_T` |
| `PORTADA_EB53` / `EB5F` | `ANIMAR_LOGO_P` / `.BUCLE_LOGO_P` |
| `PORTADA_EB6D` / `EB7E` / `EB92` | `ANIMAR_LOGO_O1` / `.BUCLE_LOGO_O1` / `.FIN_LOGO_O1` |
| `PORTADA_EB95` / `EB9D` / `EBB6` | `ANIMAR_LOGO_O2` / `.BUCLE_LOGO_O2` / `.FIN_LOGO_O2` |
| `PORTADA_EBB9` / `EBBC` | `ANIMAR_ESTRELLA` / `.BUCLE_ESTRELLA` |
| `PORTADA_EC4D` / `EC52` | `RELLENAR_BLOQUE_COLOR` / `.BUCLE_RELLENAR_BLOQUE` |
| (sin etiqueta, `$EBD8`) | `SECUENCIA_LOGO_TOPO_SOFT` (nueva etiqueta; corregida también la referencia en `load_cas/portada_stub_body.asm`) |

También se limpió el comentario largo y ya desactualizado sobre
`DIBUJAR_FORMA_LOGO` (databa de la sesión 5, cuando aún no sabíamos
nada de esto) y se actualizó `recursos/mapa_memoria_logotopo.html`
con el desglose fino de todos estos tramos (verificado sin huecos ni
solapes, sigue sumando los 4222 bytes exactos).

### Pendiente para próximas sesiones

- `PORTADA_EC66` (decoración, llama a `RELLENAR_BLOQUE_COLOR` dos
  veces por vuelta) — sin confirmar el efecto visual exacto.
- Un tramo dentro de `PORTADA_EC66` que parece código INALCANZABLE
  (usa el registro `R` como aleatorio + `OUT ($FE),A`) — confirmar si
  de verdad no tiene llamador o si se nos escapa alguno.
- `PORTADA_ECDA` (`JP $1F3D`, dentro de la ROM) — confirmar qué hace
  esa dirección de la ROM de 48K.
- El cálculo indexado por `$EABE` contra `PORTADA_RELLENO_ED51` dentro
  de `RESTAURAR_FRANJA_FONDO` (guardado en `$EB10`) — se calcula pero
  no se usa en ningún sitio visible; confirmar si `PORTADA_RELLENO_ED51`
  es de verdad una tabla activa (sospecha desde sesión 9).
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente.
- Confirmar en vivo (emulador) el arranque completo reconstruido.

## Sesión 11 — 2026-08-09: usando el LOGOTOPO.CM de MSX como referencia

Petición del usuario: la animación de Topo Soft es visualmente la
misma en MSX y Spectrum — usar `MSX/proyectos/madmixgame/src/load_cas/logotopo_cm_body.asm`
(ya resuelto al 100% y confirmado visualmente allí) como apoyo para
esta reconstrucción.

Se leyó el fichero completo. Aunque el código Z80 es distinto byte a
byte (arquitecturas de vídeo distintas: VRAM del VDP en MSX, memoria
de pantalla mapeada en Spectrum), **la secuencia de alto nivel es
literalmente la misma, pieza por pieza y en el mismo orden**:

| MSX (`DIBUJAR_LOGO_TOPOSOFT`) | Spectrum (`SECUENCIA_LOGO_TOPO_SOFT`) |
|---|---|
| `LIMPIAR_TABLA_COLOR_VRAM` | `LIMPIAR_PANTALLA_LOGO` |
| `DIBUJAR_T_TOPO` | `ANIMAR_LOGO_T` |
| `DIBUJAR_P_TOPO_ANIMADA` | `ANIMAR_LOGO_P` |
| `DIBUJAR_O1_TOPO` | `ANIMAR_LOGO_O1` |
| `DIBUJAR_O2_TOPO_ANIMADA` | `ANIMAR_LOGO_O2` |
| `ANIMAR_COLOR_TOPO` | `PORTADA_EC66` → renombrada `ANIMAR_COLOR_TOPO` |
| `RELLENAR_COLOR_TOPO` | `RELLENAR_BLOQUE_COLOR` |
| `DIBUJAR_SOFT_ROTANDO` ×3 | `ANIMAR_LOGO_SOFT` ×3 |
| `ANIMAR_PUNTO_LUZ_SOFT` | `ANIMAR_DESTELLO_LOGO` |
| `DIBUJAR_ESTRELLA_ANIMADA` | `ANIMAR_ESTRELLA` |

Dos correspondencias con apoyo fuerte (posición Y orden coincidentes,
no solo intuición):

- **`ANIMAR_DESTELLO_LOGO` ≈ `ANIMAR_PUNTO_LUZ_SOFT`**: en MSX,
  confirmado visualmente como "un punto de luz que recorre 'Soft' por
  su línea superior tras terminar de rotar, acabando junto a la
  estrella". La posición fija de `ANIMAR_DESTELLO_LOGO` (fila de
  atributo 15, columna 15) coincide EXACTA con donde `ANIMAR_LOGO_SOFT`
  dibuja "SOFT" (fila de píxel 120 = fila de atributo 15, misma
  columna), y su posición en la secuencia (justo tras las 3
  rotaciones de SOFT, justo antes de la estrella) es idéntica en
  ambas versiones. Reinterpreta lo que en sesión 4/5 se llamó
  "destello genérico" como, muy probablemente, el mismo efecto de
  punto de luz recorriendo el texto.
- **`PORTADA_EC66` → `ANIMAR_COLOR_TOPO`**: en MSX, confirmado
  visualmente como "el color de TOPO expandiéndose desde el centro
  hacia los lados, justo después de dibujar las 4 letras". Coincide
  en posición exacta dentro de la secuencia (justo después de
  `ANIMAR_LOGO_O2`). El mecanismo Z80 difiere (Spectrum: 2 bloques de
  atributos, cian de 5 filas y verde de 7, deslizando cada uno 9
  columnas a la izquierda; MSX: 2 "cajas" VRAM separándose desde un
  centro), pero es el mismo efecto en el mismo punto de la secuencia
  — la semántica visual exacta en Spectrum sigue sin confirmarse en
  emulador, pero ya no es una decoración sin identificar.

`RELLENAR_COLOR_TOPO` de MSX confirma también que `RELLENAR_BLOQUE_COLOR`
está bien entendida: en ambas versiones rellena la MISMA zona que
luego usará el efecto de punto de luz, justo antes de llamarlo — no
es casualidad que `RELLENAR_BLOQUE_COLOR` en Spectrum use la misma
celda (`$59EF`) que `ANIMAR_DESTELLO_LOGO`.

**Nota metodológica para próximas sesiones**: el proyecto MSX
(`madmix1_body.asm`/`madmix_scr_body.asm`) puede servir de referencia
también para `madmix_body.asm` (el motor, sin analizar todavía) —
mismo juego, mismo publisher, estructuras de datos/rutinas
probablemente análogas (tablas de nivel, sprites, sonido, HUD),
aunque el motor en sí es mucho más grande y las plataformas difieren
más (VDP vs. memoria mapeada) que en el caso del logo.

### Cambios aplicados

- `src/portada_body.asm`: `PORTADA_EC66`/`EC79` → `ANIMAR_COLOR_TOPO`/
  `.BUCLE_COLOR_TOPO`. Comentarios ampliados en `ANIMAR_DESTELLO_LOGO`
  y `ANIMAR_COLOR_TOPO` con la comparación MSX.
- `recursos/mapa_memoria_logotopo.html` actualizado con las mismas
  referencias cruzadas.
- **Verificado**: recompilado, 0 diferencias.

### Pendiente para próximas sesiones

- Confirmar en emulador que `ANIMAR_DESTELLO_LOGO`/`ANIMAR_COLOR_TOPO`
  se ven de verdad como sus equivalentes MSX (hipótesis fuerte, no
  demostrada al 100%).
- `PORTADA_ECDA` (`JP $1F3D`, dentro de la ROM) — MSX no tiene
  equivalente directo (usa `HALT` con contador en vez de saltar a la
  ROM), así que aquí no ayuda de referencia.
- El cálculo indexado por `$EABE` contra `PORTADA_RELLENO_ED51` en
  `RESTAURAR_FRANJA_FONDO`, sin uso confirmado.
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente; considerar
  usar `madmix1_body.asm`/`madmix_scr_body.asm` de MSX como apoyo,
  igual que aquí.
- Confirmar en vivo (emulador) el arranque completo reconstruido.

## Sesión 12 — 2026-08-09: nombres exactos compartidos con MSX (política del proyecto)

Petición del usuario: en vez de nombres "parecidos" a los de MSX
(sesión 11), usar los nombres EXACTOS de la rutina equivalente ya
resuelta en MSX, y mantener esta estrategia durante todo el proyecto
para poder comparar ambas versiones con facilidad.

### Renombrados a nombre exacto de MSX

| Antes (sesión 9-11) | Ahora (= nombre MSX) |
|---|---|
| `SECUENCIA_LOGO_TOPO_SOFT` | `DIBUJAR_LOGO_TOPOSOFT` |
| `DIBUJAR_FORMA_LOGO` | `DIBUJAR_FORMA_ANIMADA` |
| `LIMPIAR_PANTALLA_LOGO` | `LIMPIAR_TABLA_COLOR_VRAM` |
| `ANIMAR_LOGO_T` | `DIBUJAR_T_TOPO` |
| `ANIMAR_LOGO_P` | `DIBUJAR_P_TOPO_ANIMADA` |
| `ANIMAR_LOGO_O1` | `DIBUJAR_O1_TOPO` |
| `ANIMAR_LOGO_O2` | `DIBUJAR_O2_TOPO_ANIMADA` |
| `RELLENAR_BLOQUE_COLOR` | `RELLENAR_COLOR_TOPO` |
| `ANIMAR_LOGO_SOFT` | `DIBUJAR_SOFT_ROTANDO` |
| `ANIMAR_DESTELLO_LOGO` | `ANIMAR_PUNTO_LUZ_SOFT` |
| `ANIMAR_ESTRELLA` | `DIBUJAR_ESTRELLA_ANIMADA` |

Más las etiquetas locales correspondientes (`.BUCLE_LOGO_T`→
`.BUCLE_POSICION`, `.BUCLE_LOGO_O1`→`.BUCLE_SEGMENTO`, `.FIN_LOGO_O1`→
`.ULTIMO_SEGMENTO`, `.BUCLE_LOGO_O2`→`.BUCLE_TRAZO`, `.FIN_LOGO_O2`→
`.ULTIMO_TRAZO`, `.BUCLE_LOGO_SOFT`/`.BUCLE_ESTRELLA`→
`.BUCLE_FOTOGRAMA`, `.BUCLE_FILAS_FORMA`→`.BUCLE_SEGMENTO`,
`.BUCLE_BYTES_FILA`→`.BUCLE_BYTE`, `.BUCLE_DESTELLO_LOGO`→
`.BUCLE_AVANZAR_PUNTO`, `.BUCLE_COLOR_TOPO`→`.BUCLE_EXPANSION`,
`.BUCLE_RELLENAR_BLOQUE`→`.BUCLE_FILA`), todas copiadas de los
nombres locales reales de `logotopo_cm_body.asm`. También corregida
la referencia en `load_cas/portada_stub_body.asm`
(`JP DIBUJAR_LOGO_TOPOSOFT`).

Lo que NO se renombró a la fuerza: `GUARDAR_PANTALLA_LOGO`,
`RESTAURAR_FRANJA_FONDO`, `RESTAURAR_FRANJA_FILA`, `PORTADA_ECDA` y
`DIBUJAR_FORMA_TEMPORIZADA` no tienen equivalente real en MSX (usan
una estrategia distinta — guardar/restaurar fondo en vez de borrar la
tabla de patrones — o no existen allí en absoluto) — se quedan con
nombre propio en español, documentado el porqué.

**Verificado**: recompilado, 0 diferencias.

### Política adoptada para el resto del proyecto

Documentada en `src/README.md`, sección "Convenciones": cuando una
rutina Spectrum resulte equivalente a una ya resuelta en el proyecto
MSX (`logotopo_cm_body.asm` por ahora; `madmix1_body.asm`/
`madmix_scr_body.asm` más adelante, para el motor), se le pone el
MISMO nombre exacto, no uno parecido — para que un simple `grep` del
mismo identificador encuentre la rutina en los dos proyectos. Cuando
el mecanismo Spectrum no tenga equivalente real en MSX, se mantiene
un nombre propio en español, sin forzar la correspondencia.

### Pendiente para próximas sesiones

- `PORTADA_ECDA` (`JP $1F3D`, dentro de la ROM) — sin equivalente MSX
  que ayude aquí.
- El cálculo indexado por `$EABE` contra `PORTADA_RELLENO_ED51` en
  `RESTAURAR_FRANJA_FONDO`, sin uso confirmado.
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente; aplicar la
  misma política de nombres compartidos usando
  `madmix1_body.asm`/`madmix_scr_body.asm` de MSX como referencia.
- Confirmar en vivo (emulador) el arranque completo reconstruido.

## Sesión 13 — 2026-08-09: la política de nombres exactos con MSX se extiende a las tablas de datos

Petición del usuario: la sesión 12 solo renombró rutinas; pedido
explícito de revisar si las TABLAS de datos usadas por esas rutinas
también tienen equivalente ya resuelto en MSX y, si es así, ponerles
el mismo nombre exacto — al menos las que encajen.

### Comparación con `logotopo_cm_body.asm` (MSX)

Cotejadas las 5 tablas de `portada_body.asm` contra las tablas de
MSX. Cuatro encajan exactamente en función (misma tabla, mismo papel
en la misma secuencia de dibujo):

| Antes (sesión 8-9) | Ahora (= nombre MSX) |
|---|---|
| `TABLA_PUNTEROS_FORMAS_LOGOTIPO` | `TABLA_PUNTEROS_FORMAS` |
| `TABLA_CICLO_SOFT` | `TABLA_ANIMACION_SOFT` |
| `GUION_MOVIMIENTO_REBOTE` | `TABLA_TRAZO_O2_TOPO` |
| `GUION_CICLO_ESTRELLA` | `TABLA_ANIMACION_ESTRELLA` |

Además, MSX tiene una etiqueta `TABLA_FORMAS` que marca el inicio del
bloque completo de las 15 formas (desde la cual se calculan todos los
desplazamientos de `TABLA_PUNTEROS_FORMAS`). En Spectrum ese mismo
byte ya tenía nombre (`LOGO_SOFT_1`, la primera forma) — en vez de
elegir entre los dos, se añadió `TABLA_FORMAS` como etiqueta ALIAS en
la misma dirección (`$EF1C`), y se cambiaron los 15 `DW` de
`TABLA_PUNTEROS_FORMAS` (antes `DW LOGO_X-LOGO_SOFT_1`) y el
`LD HL,LOGO_SOFT_1` de `DIBUJAR_FORMA_ANIMADA` para usar
`TABLA_FORMAS` como base, igual que en MSX. `LOGO_SOFT_1` se conserva
como nombre de la forma 1/7 en sí (con su propio significado, ya
confirmado visualmente en sesión 6) — ambas etiquetas conviven en la
misma dirección sin conflicto.

**No renombrada a propósito**: `TABLA_FILAS_PANTALLA` (384 bytes,
tabla de 192 direcciones absolutas de pantalla) cumple un papel
análogo a `TABLA_DELTA_POSICION` de MSX (traducir fila lógica a
dirección de pantalla), pero la estructura de datos es distinta: MSX
guarda 24 deltas RELATIVOS enmascarados, Spectrum guarda 192
direcciones ABSOLUTAS reales — forzar el mismo nombre sería engañoso.
Se dejó un comentario explícito en `portada_body.asm` explicando por
qué se mantiene el nombre propio.

**Verificado**: recompilado con `tools/build_all.py` (0 errores) y
reempaquetado con `tools/gen_tzx_file.py` — **0 diferencias, 48485
bytes idénticos al `.tzx` original**. Inventario regenerado
(`tools/gen_inventory.py`): 1074 etiquetas (función=81, interna=970,
dato=23, sinref=0).

### Documentación actualizada

- `src/README.md`, sección "Convenciones": añadida la tabla de
  equivalencias de tablas de datos (además de la de rutinas de sesión
  12), con la nota sobre por qué `TABLA_FILAS_PANTALLA` no se
  renombró.
- `recursos/mapa_memoria_logotopo.html`: los 4 segmentos de tabla y el
  segmento de `LOGO_SOFT_1`/`TABLA_FORMAS` actualizados con los nuevos
  nombres y una nota de la sesión.

### Pendiente para próximas sesiones

- `PORTADA_ECDA` (`JP $1F3D`, dentro de la ROM) — sin equivalente MSX
  que ayude aquí.
- El cálculo indexado por `$EABE` contra `PORTADA_RELLENO_ED51` en
  `RESTAURAR_FRANJA_FONDO`, sin uso confirmado.
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente; aplicar la
  misma política de nombres compartidos (rutinas Y tablas) usando
  `madmix1_body.asm`/`madmix_scr_body.asm` de MSX como referencia.
- Confirmar en vivo (emulador) el arranque completo reconstruido.

## Sesión 14 — 2026-08-09: resuelto `PORTADA_ECDA` (salto a la ROM)

Petición del usuario: analizar qué hace `PORTADA_ECDA` (`LD BC,$0005`
/ `JP $1F3D`) y ponerle nombre — quedaba pendiente desde la sesión 12
como el único salto a la ROM de 48K sin resolver en toda la portada.

### Qué es `$1F3D`

Consultada la documentación pública de la ROM de 48K (disassembly
completo de Ian Logan/Frank O'Hara, vía skoolkid.github.io/rom):
`$1F3A` es el punto de entrada del comando BASIC **`PAUSE`**; `$1F3D`
es su segunda instrucción, la etiqueta interna **PAUSE-1**, el bucle
`HALT` / `DEC BC` / comprobar cero o tecla pulsada. `PORTADA_ECDA`
salta DIRECTAMENTE a `$1F3D` con `BC` ya cargado a mano (`LD BC,5`),
saltándose la primera instrucción de `$1F3A` (`CALL FIND-INT2`, que
en el comando BASIC real lee el parámetro numérico de la expresión
`PAUSE n`) — un truco habitual para reutilizar código de ROM sin
pasar por el parser de BASIC.

Efecto: pausa de 5 interrupciones (~0.1 s a 50 Hz), pero
**interrumpible**: la ROM comprueba el bit 5 de `FLAGS` (`$5C3B`,
"tecla pulsada desde la última vez") en cada `HALT` y sale antes de
las 5 si el jugador pulsa algo — el clásico "pulsa una tecla para
saltar la animación" del Spectrum.

### Uso confirmado

Llamada exactamente 4 veces, todas desde `DIBUJAR_LOGO_TOPOSOFT`,
siempre justo después de dibujar una letra de "TOPO" (`DIBUJAR_T_TOPO`,
`DIBUJAR_P_TOPO_ANIMADA`, `DIBUJAR_O1_TOPO`, `DIBUJAR_O2_TOPO_ANIMADA`)
— una pausa breve entre letra y letra, saltable con una tecla.

### Renombrada

`PORTADA_ECDA` → **`PAUSA_ENTRE_LETRAS`**. Sin equivalente directo en
MSX: allí cada rutina de letra trae su propio bucle local inline
(`.BUCLE_ESPERA_N_FRAMES` con `HALT`/`DJNZ`, ver
`logotopo_cm_body.asm`) en vez de una rutina compartida que salta a
la ROM — se mantiene nombre propio en español, con el comentario
explicando el mecanismo de la ROM. De paso, `LD BC,$0005` → `LD BC,5`
(convención de decimales del proyecto).

**Verificado**: recompilado y reempaquetado — **0 diferencias, 48485
bytes idénticos al `.tzx` original**. Inventario regenerado: 1074
etiquetas (función=81, interna=970, dato=23, sinref=0).

### Pendiente para próximas sesiones

- El cálculo indexado por `$EABE` contra `PORTADA_RELLENO_ED51` en
  `RESTAURAR_FRANJA_FONDO`, sin uso confirmado.
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente.
- Confirmar en vivo (emulador) el arranque completo reconstruido.

## Sesión 15 — 2026-08-09: analizado (y confirmado huérfano) el fragmento `PORTADA_ECBF`/`ECC2`/`ECCF`

Petición del usuario: analizar el tramo de código sin llamador
conocido que queda justo entre `ANIMAR_COLOR_TOPO` y
`PAUSA_ENTRE_LETRAS` (`$ECB7-$ECDA`, 35 bytes), señalado como
pendiente desde la sesión 12.

### Comprobación de alcanzabilidad

Buscado en los 5 fuentes (`portada_body.asm`, `load_cas/*.asm`, y los
dos `.bas`) cualquier `CALL`/`JP`/`JR` — directo o vía `RANDOMIZE
USR`— que apunte a `$ECB7` o a cualquiera de las 3 etiquetas internas:
**ninguno**. El `RET` incondicional al final de `ANIMAR_COLOR_TOPO`
(justo antes) corta el único flujo normal posible. Confirmado
**inalcanzable** con la evidencia disponible — igual de "huérfano" en
espíritu que `DATOS_HUERFANOS_9EEA` dentro de `TABLA_FORMAS` en MSX
(mismo término ya usado en el proyecto hermano para "bytes reales
verificados, sin referencia conocida").

### Qué hace (análisis, sin observación en emulador — nunca se ejecuta)

Genera hasta 50 pulsos por el altavoz (bit 4 del puerto `$FE`,
ON/OFF alternando), pero cada pulso usa el registro `R` (refresco de
DRAM, con jitter real por las interrupciones de 50Hz) como contador
**y** como condición de salida: `RET M` puede devolver el control de
golpe en cualquier comprobación si el bit 7 de `R` está a 1 (~50% de
probabilidad cada vez) — así que en la práctica el número real de
pulsos es aleatorio y casi siempre mucho menor que 50. Efecto sonoro
de tipo "chisporroteo/estática" de duración variable. Al terminar cae
sin `RET` propio directamente en `PAUSA_ENTRE_LETRAS` (que si se
llegara a ejecutar, terminaría devolviendo el control vía el `RET` de
la rutina `PAUSE` de la ROM). `HL` se carga a 280 y se incrementa una
vez (`INC HL`) pero no se usa para nada más — puede ser un resto de
una versión anterior de la rutina.

Hipótesis (no confirmable solo con análisis estático): una llamada a
este efecto se retiró durante el desarrollo original de 1988 y el
código se dejó en su sitio sin borrar, para no tener que desplazar
todas las direcciones siguientes (un problema real en ensamblado a
mano de la época).

### Renombrado

Añadida etiqueta global nueva `RUIDO_ALTAVOZ_HUERFANO` en `$ECB7`
(antes sin etiqueta propia, solo código suelto tras el `RET` de
`ANIMAR_COLOR_TOPO`). `PORTADA_ECBF`/`PORTADA_ECC2`/`PORTADA_ECCF` →
etiquetas locales `.BUCLE_PULSO_ON`/`.BUCLE_ESPERA_ON`/
`.BUCLE_ESPERA_OFF` (todo el bloque cabe en un único ámbito global, a
diferencia del caso de `RESTAURAR_FRANJA_FILA` en sesión 9). De paso,
convertidos a decimal `LD E,$32`→`LD E,50` y `LD HL,$0118`→
`LD HL,280` (convención de decimales del proyecto); `$10` se mantiene
en hexadecimal por ser una máscara de bits de puerto, no una
cantidad.

**Verificado**: recompilado y reempaquetado — **0 diferencias, 48485
bytes idénticos al `.tzx` original**. Inventario regenerado: 1072
etiquetas (función=81, interna=967, dato=23, **sinref=1** — la propia
`RUIDO_ALTAVOZ_HUERFANO`, que el generador de inventario confirma de
forma independiente como sin referencias, coincidiendo con el
análisis manual).

### Pendiente para próximas sesiones

- El cálculo indexado por `$EABE` contra `PORTADA_RELLENO_ED51` en
  `RESTAURAR_FRANJA_FONDO`, sin uso confirmado.
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente.
- Confirmar en vivo (emulador) el arranque completo reconstruido.

## Sesión 16 — 2026-08-09: `RESTAURAR_FRANJA_FILA` a mnemónicos reales + resueltas 5 variables de trabajo

Petición del usuario: analizar `RESTAURAR_FRANJA_FILA` (`$ED85`), ya
identificada como rutina real desde la sesión 8-10 pero todavía
expresada como bytes en bruto (`DB`) en el fuente, con un comentario
antiguo en tono de hipótesis ("si es de verdad código...").

### `RESTAURAR_FRANJA_FILA`: confirmada y convertida a mnemónicos

Llamada real desde `.BUCLE_RESTAURAR_FRANJA` dentro de
`RESTAURAR_FRANJA_FONDO` (`CALL RESTAURAR_FRANJA_FILA`, una vez por fila).
Analizado el contexto completo: al llegar, `HL` = dirección origen
(el buffer de fondo guardado por `GUARDAR_PANTALLA_LOGO`, vía la
traducción `+$8738` ya confirmada en sesión previa) y `DE` = dirección
destino (la pantalla real, `$4000-$57FF`) — restaura una franja de 6
bytes de fondo sobre la pantalla, deshaciendo lo que
`DIBUJAR_FORMA_ANIMADA` dibujó encima. Los 13 bytes (`$ED,$A0`×6 +
`$C9`) son exactamente 6 `LDI` desenrollados + `RET` — confirmado
byte a byte, convertidos de `DB` a mnemónicos reales (`LDI`×6/`RET`).

### Los 10 bytes siguientes: no son tabla ni código, son variables de trabajo

Entre el `RET` de `RESTAURAR_FRANJA_FILA` (`$ED92`) y `TABLA_FILAS_PANTALLA`
(`$ED9C`) hay 10 bytes que el `Z80Dasm` original desensambló como
basura de código sin sentido (direcciones absurdas tipo `JP
$6258`/`JP M,$EE78`). Rastreadas todas las referencias a
`$ED92`/`$ED94`/`$ED96`/`$ED98`/`$ED9A` en `DIBUJAR_FORMA_ANIMADA`,
`RESTAURAR_FRANJA_FONDO` y `ANIMAR_COLOR_TOPO`: son 5 variables de
16 bits, cada una escrita antes de leerse — RAM de trabajo que
reutiliza este hueco de la zona de datos estática (patrón ya
documentado en MSX):

- `$ED92` → **`SP_GUARDADO_PORTADA`**: guarda/restaura el SP real en
  `DIBUJAR_FORMA_ANIMADA` (truco `POP` para leer
  `TABLA_FILAS_PANTALLA` rápido). Sin equivalente en MSX.
- `$ED94`-`$ED97` → **`VARIABLES_TRABAJO_FORMA`** (4 bytes = 2
  punteros): puntero a datos de forma + puntero a fila de pantalla,
  compartido con `RESTAURAR_FRANJA_FONDO`. **Mismo nombre exacto** que
  en MSX (`logotopo_cm_body.asm`), donde agrupa los mismos 2 punteros
  de trabajo de `DIBUJAR_FORMA_ANIMADA` (aunque allí, en la ROM
  limpia de cartucho, están a 0 en reposo).
- `$ED98`-`$ED9B` → **`VARIABLES_TRABAJO_COLOR_TOPO`** (4 bytes = 2
  punteros): los 2 bloques (cian/verde) que desliza `ANIMAR_COLOR_TOPO`.
  Sin equivalente en MSX (allí usa 2 "cajas" VRAM, no punteros RAM).

**Verificado**: recompilado y reempaquetado — **0 diferencias, 48485
bytes idénticos al `.tzx` original**. Inventario regenerado: 1075
etiquetas (función=81, interna=967, dato=26, sinref=1).

### CURIOSIDAD CONFIRMADA: el `.tzx` maestro se generó volcando RAM en vivo, no desde un ensamblado limpio

Los valores COMPILADOS de las 5 variables de trabajo de arriba, tal
como viajan en el `.tzx` real, no son cero ni "de fábrica" como cabría
esperar de un binario recién salido del ensamblador — son **restos de
una ejecución real**, y esto se puede demostrar con aritmética exacta,
no solo intuirse:

1. **`VARIABLES_TRABAJO_FORMA`** (puntero a los bytes de la forma que
   se está copiando) vale `$FADE` en el `.tzx`. `$FADE` es
   exactamente **1 byte pasado el último byte de todo el payload de
   portada** (`$FADD`, el final de `LOGO_ESTRELLA_4`, la última de
   las 15 formas — ver sesión 6). Ese es precisamente el valor que
   quedaría en ese puntero justo después de que
   `DIBUJAR_FORMA_ANIMADA` terminase de copiar los 81 bytes de la
   ÚLTIMA forma del logo (la estrella, fotograma 4).
2. Los 2 punteros de **`VARIABLES_TRABAJO_COLOR_TOPO`** valen `$58C2`
   y `$5962` en el `.tzx` — **exactamente 9 menos** que los valores
   iniciales que `ANIMAR_COLOR_TOPO` carga en ellos al arrancar
   (`$58CB`/`$596B`). `ANIMAR_COLOR_TOPO` decrementa ambos punteros
   una vez por vuelta en un bucle de **9 vueltas exactas**
   (`LD B,$09` / `DJNZ .BUCLE_EXPANSION`) — ese es precisamente el
   valor que quedaría justo cuando el bucle completa sus 9 vueltas y
   termina.

Dos coincidencias numéricas exactas, independientes entre sí (una
sobre el final de `DIBUJAR_FORMA_ANIMADA`, otra sobre el final de
`ANIMAR_COLOR_TOPO`, dos rutinas distintas), apuntando ambas a la
misma conclusión: **la cinta maestra de 1988 no se creó ensamblando
el código y guardándolo tal cual** — se creó **ejecutando la portada
(al menos una vez, hasta terminarla) y volcando después la RAM** a
la cinta/disco maestro. Por eso las variables de trabajo, que en un
ensamblado limpio empezarían a cero (como pasa en la ROM de cartucho
de MSX, ver `VARIABLES_TRABAJO_FORMA` allí — sesión 13), aquí llevan
"puestos" los valores que tenían en el instante exacto del volcado.

De regalo, explica un misterio previo (sesión 7-8): por qué
`Z80Dasm.exe`, al desensamblar mecánicamente este tramo por primera
vez, sacó instrucciones sin sentido (`JP $6258`, `JP M,$EE78`,
direcciones absurdas) — no era código roto ni un bug del
desensamblador, eran bytes de DATOS (contenido de variables en un
instante de ejecución) que por pura coincidencia de bits se parecen a
opcodes válidos de Z80.

### Pendiente para próximas sesiones

- Con este hallazgo, revisar si `PORTADA_RELLENO_ED51` (el patrón
  `$ED,$A0` justo antes de `RESTAURAR_FRANJA_FILA`, sesión 7, todavía "sin
  identificar") es también resto de una ejecución real en vez de
  relleno puro — la hipótesis de esta sesión da un motivo nuevo para
  reabrirlo.
- El cálculo indexado por `$EABE` contra `PORTADA_RELLENO_ED51` en
  `RESTAURAR_FRANJA_FONDO`, sin uso confirmado.
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente.
- Confirmar en vivo (emulador) el arranque completo reconstruido.

## Sesión 17 — 2026-08-09: `PORTADA_RELLENO_ED51` resuelto — 26 `LDI` huérfanos, y el cálculo `$EB10` era código muerto

Petición del usuario: analizar `PORTADA_RELLENO_ED51` (`$ED51`, 52
bytes), el último tramo "sin identificar del todo" que quedaba en la
portada, señalado como pendiente desde la sesión 7 y otra vez al
cierre de la sesión 16.

### El cálculo indexado en `RESTAURAR_FRANJA_FONDO` es código muerto

Punto de partida: al principio de `RESTAURAR_FRANJA_FONDO` había dos
cálculos cuyo destino nunca se había verificado si se leía después:

- `LD A,($EAB6) / LD ($EB07),A` — guarda la columna autoemodificada.
- Un cálculo `(32 - cabecera $EABE) * 2 + PORTADA_RELLENO_ED51`,
  guardado en `$EB10`.

Rastreadas TODAS las referencias a `$EB07` y `$EB10` en los 5
binarios reconstruidos: **ninguna de las dos se lee jamás** — solo se
escriben aquí y no se vuelven a tocar. Confirmado con búsqueda
exhaustiva (`grep` sobre todo `src/`), no por inspección parcial.

### `PORTADA_RELLENO_ED51`: inalcanzable, y son literalmente 26 `LDI`

Comprobado también que ningún `CALL`/`JP` de los 5 binarios apunta a
`$ED51` — igual de inalcanzable que `RUIDO_ALTAVOZ_HUERFANO` (sesión
15). Sí se referencia su DIRECCIÓN (en el cálculo muerto de `$EB10`
de arriba), pero eso es distinto de ser alcanzable por control de
flujo: nada salta ni entra en ejecución aquí.

Los 52 bytes, releídos como código: `$ED,$A0` × 26, exactamente el
opcode de `LDI` repetido 26 veces, sin ningún `RET` — si se
ejecutaran, caerían directo en `RESTAURAR_FRANJA_FILA` (6 `LDI` + `RET`,
justo a continuación), sumando 32 `LDI` + `RET` desde aquí. Convertido
de `DB` en bruto a 26 mnemónicos `LDI` reales.

### Hipótesis (no demostrada): una versión anterior y más ancha de `RESTAURAR_FRANJA_FILA`

Tres piezas encajan en la misma explicación:

1. `$ED,$A0` repetido de forma perfectamente uniforme 26 veces es un
   patrón raro para relleno/alineación intencional (lo habitual sería
   `$00`/NOP o el carácter de relleno por defecto del ensamblador) —
   pero es EXACTAMENTE lo que quedaría si aquí hubiera habido más
   copias de la misma instrucción `LDI` que ya usa la rutina vecina.
2. El cálculo muerto de `$EB10` apunta, con la fórmula `(32-cabecera)*2
   + base`, precisamente DENTRO de este bloque de 52 bytes (26
   entradas de 2 bytes) — coherente con un antiguo mecanismo "calcular
   cuántos `LDI` ejecutar según el tamaño de la forma" que dejó de
   usarse.
3. `RESTAURAR_FRANJA_FILA` restaura una franja de ANCHURA FIJA (6
   bytes = 48 píxeles) sin importar la forma — pero las 15 formas del
   logo tienen anchuras muy distintas (de 2 a 9 bytes/fila, ver sesión
   6). Una versión más general, con ancho VARIABLE calculado a partir
   de la cabecera de la forma, es una explicación natural de por qué
   existían estos cálculos en primer lugar.

Conclusión propuesta (hipótesis, no verificable solo con análisis
estático): en algún punto del desarrollo original, `RESTAURAR_FRANJA_FONDO`
restauraba una franja de ancho variable según la forma en curso (hasta
32 `LDI` = 32 bytes), y se simplificó a un ancho fijo de 6 bytes
(suficiente para todas las formas reales que se usan en la práctica),
dejando sin borrar tanto el código de más (estos 26 `LDI`) como los 2
cálculos que ya no alimentan a nadie (`$EB07`, `$EB10`).

### Renombrado

`PORTADA_RELLENO_ED51` → **`LDI_EXTRA_HUERFANOS`** (mismo sufijo
"huérfano" que `RUIDO_ALTAVOZ_HUERFANO`, sesión 15, y
`DATOS_HUERFANOS_9EEA` en MSX — término ya establecido en el proyecto
para "bytes reales verificados, sin referencia de control de flujo
conocida"). Añadidos comentarios en `RESTAURAR_FRANJA_FONDO` marcando
explícitamente `$EB07`/`$EB10` como cálculos muertos.

**Verificado**: recompilado y reempaquetado — **0 diferencias, 48485
bytes idénticos al `.tzx` original**. Inventario regenerado: 1075
etiquetas (función=81, interna=968, dato=25, sinref=1 — el conteo de
"sin referencia" no sube a 2 porque `LDI_EXTRA_HUERFANOS` SÍ tiene una
referencia técnica, la del cálculo muerto de `$EB10`; sigue siendo
inalcanzable por control de flujo, que es la comprobación relevante
aquí).

Con esto, toda la portada (`$EA60-$FADD`, 4222 bytes) queda con cada
tramo identificado como código analizado, tabla con nombre, gráfico
confirmado, o huérfano documentado — no queda ningún tramo "sin
identificar del todo".

### Pendiente para próximas sesiones

- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente; aplicar la
  misma metodología (comparación con MSX, política de nombres
  compartidos, búsqueda exhaustiva de referencias antes de dar por
  "sin uso" cualquier cálculo) usando `madmix1_body.asm`/
  `madmix_scr_body.asm` como referencia.
- Confirmar en vivo (emulador) el arranque completo reconstruido.

## Sesión 18 — 2026-08-09: `$EAC0` resuelto — es el interruptor "copiar vs. mezclar con OR (HL)", igual que `$94F3` en MSX

Petición del usuario: revisar qué queda por analizar en
`portada_body.asm`. Repasando el fichero completo buscando variables
escritas pero nunca leídas (con `grep` exhaustivo, no solo lectura
superficial), apareció `$EAC0` — escrita 3 veces (`$00` en
`DIBUJAR_LOGO_TOPOSOFT`, `$00` en `DIBUJAR_SOFT_ROTANDO`, `$B6` en
`DIBUJAR_O1_TOPO`) pero sin ningún comentario ni mención previa en
este diario. El usuario pidió analizarla.

### `$EAC0` no es una variable "de datos" — es un opcode autoemodificado

Buscando dónde caía exactamente esa dirección en el listado compilado
(`src/build/main.lst`), resultó ser la dirección EXACTA de la
instrucción `NOP` que sigue a `LD A,(DE)` dentro de
`.BUCLE_BYTE` (el bucle de copia byte a byte de `DIBUJAR_FORMA_ANIMADA`,
`$EABF-$EAC4`) — no una celda de datos aparte, sino el propio opcode
de esa instrucción. Al buscar `$EAC0` como texto plano antes, las 3
escrituras aparecían pero esta "lectura" (ejecución) no, porque no
hay ningún texto `$EAC0` en la línea del `NOP` en sí — solo su
posición en memoria lo delata.

### Confirmado con el equivalente MSX: es el mismo mecanismo, con los mismos valores

Comparado con `logotopo_cm_body.asm`: MSX tiene la dirección `$94F3`,
descrita allí explícitamente como "el OPCODE de OR (HL) en
`.BUCLE_BYTE` (interruptor combinar-con-VRAM-sí/no)". Y se escribe en
las MISMAS 3 rutinas, con los MISMOS valores:

- `DIBUJAR_LOGO_TOPOSOFT` (inicio): `$00` (NOP).
- `DIBUJAR_SOFT_ROTANDO` (inicio): `$00` (NOP).
- `DIBUJAR_O1_TOPO` (inicio): `$B6` (opcode real de `OR (HL)`).

Coincidencia exacta de posición Y de valor en dos implementaciones
independientes (Z80 real en ambas, pero VRAM de VDP en MSX vs.
memoria de pantalla mapeada en Spectrum) — confirma sin ambigüedad
que `$EAC0` es el mismo interruptor: normalmente la copia de un byte
de forma es directa (`NOP` = no-op, y el byte se sobreescribe tal
cual con `LD (HL),A`), pero cuando `DIBUJAR_O1_TOPO` lo activa a `$B6`,
la instrucción se convierte en `OR (HL)` — el byte que llega de la
forma se **combina** (OR a nivel de bit) con lo que ya hay en esa
posición de pantalla, en vez de sobreescribirlo. Solo O1 (la primera
"O" de "TOPO") usa este modo de mezcla, en ambas versiones del juego.

### Documentado, sin etiqueta propia

Se documentó con comentarios extensos en las 4 posiciones relevantes
(la propia instrucción `NOP` y las 3 escrituras), pero **sin** crear
una etiqueta SjASMPlus nueva para `$EAC0`: es el operando/opcode de
una instrucción normal, exactamente igual que `$EA83`/`$EA8E`/`$EAB6`
(que tampoco tienen etiqueta propia en este fichero, solo se
documentan con comentarios) — mantiene la convención ya establecida
para parámetros autoemodificados. (Se probó primero con una etiqueta
global real ahí — `OPCODE_COMBINAR_VRAM:` — pero rompía el ámbito de
las etiquetas locales de `.BUCLE_BYTE`, el mismo problema de scoping
de SjASMPlus visto en sesión 9 con `COPIAR_6_BYTES`; se revirtió a
comentario puro.)

**Verificado**: recompilado y reempaquetado — **0 diferencias, 48485
bytes idénticos al `.tzx` original**. Inventario regenerado: 1075
etiquetas (función=81, interna=968, dato=25, sinref=1).

Con esto, `DIBUJAR_FORMA_ANIMADA` queda con sus 4 parámetros
autoemodificados completamente documentados (forma, fila, columna, y
ahora el modo de combinado) — no queda ninguna variable "muda"
(escrita sin explicación) en todo `portada_body.asm`.

### Pendiente para próximas sesiones

- La relación exacta entre las cabeceras de forma (`$EABE`/`$EAB3`,
  ancho/alto REAL de cada forma según su fichero) y la ventana fija
  de dibujo de `DIBUJAR_FORMA_ANIMADA` (27×3, el tamaño real solo de
  la estrella) sigue sin resolver del todo: `$EAB3` sí es una
  variable viva (cuenta las filas del bucle de `RESTAURAR_FRANJA_FONDO`,
  usado solo para O1/O2, con los valores reales 46/53), pero
  `DIBUJAR_FORMA_ANIMADA` ignora la cabecera para el DIBUJO en sí.
  **Ampliado y confirmado mecánicamente en sesión 19** — ver esa
  sesión; sigue pendiente la confirmación visual en emulador.
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente.
- Confirmar en vivo (emulador) el arranque completo reconstruido.

## Sesión 19 — 2026-08-09: el ancho/alto real de cada forma NO lo usa `DIBUJAR_FORMA_ANIMADA` para dibujar — confirmado con renders de bits, pendiente de emulador

Petición del usuario: seguir tirando del hilo dejado abierto en la
sesión 18 — la relación entre las cabeceras de forma (`$EABE`/`$EAB3`)
y la ventana de dibujo fija (27×3) de `DIBUJAR_FORMA_ANIMADA`.

### El problema, en concreto

`DIBUJAR_FORMA_ANIMADA` siempre copia exactamente 27 filas × 3 bytes
(81 bytes), leídos LINEALMENTE y sin ningún salto, desde el inicio de
los datos de la forma — literales `LD C,27`/`LD B,3`, no valores
leídos de la cabecera. Pero la cabecera real de cada forma (el primer
byte = ancho en bytes/fila, el segundo = alto en filas — confirmado
por aritmética exacta: ancho×alto = tamaño real del fichero para las
6 formas no-estrella) declara dimensiones MUY distintas:

| Forma | Ancho×alto real (cabecera) | Bytes reales | Ventana fija de DIBUJAR_FORMA_ANIMADA |
|---|---|---|---|
| SOFT | 8×16 | 128 | 3×27 = 81 |
| T | 9×86 | 774 | 3×27 = 81 |
| O1 | 5×46 | 230 | 3×27 = 81 |
| P | 6×73 | 438 | 3×27 = 81 |
| O2 | 6×53 | 318 | 3×27 = 81 |
| estrella | 3×27 | 81 | 3×27 = 81 (**coincide exacto**) |

Solo la estrella coincide. Para las otras 5 formas, la rutina de
dibujo real:

1. Nunca recorre más de 81 bytes (siempre los PRIMEROS 81 de cada
   forma, porque el puntero de origen se reinicia al principio de la
   forma en cada llamada) — nunca llega a ver el resto de los datos
   declarados (hasta 774 bytes para la T).
2. Los interpreta con un ancho de fila de 3 bytes, cuando el ancho
   real declarado es mayor (5 a 9 según la forma) — un desajuste de
   "stride" que, aplicado a datos organizados por filas reales más
   anchas, corta las filas en la posición equivocada.

### Confirmado visualmente (renderizado a mano, no en emulador)

Escrito un script Python de un uso para volcar los bits crudos de
cada fichero `.img` como ASCII-art, con dos interpretaciones:

- **Con el ancho real de la cabecera** (p. ej. O1 a 5 bytes/fila): las
  primeras ~26 filas muestran un contorno de "O" limpio y reconocible
  (arcos concéntricos claramente circulares). SOFT a 8 bytes/fila
  muestra formas con curvas y trazos reconocibles como letras. T a 9
  bytes/fila muestra un marco/rectángulo superior limpio seguido de
  una zona de sombreado triangular (compatible con un efecto de
  relieve/sombra bajo una letra gruesa, un estilo típico de logos de
  la época).
- **Con la ventana fija de `DIBUJAR_FORMA_ANIMADA`** (3 bytes/fila,
  lectura lineal sin respetar el ancho real): el MISMO O1 sale con
  las curvas cortadas en diagonal, irreconocible como letra —
  confirma que el desajuste de stride realmente destroza la imagen
  si se lee así.

Como control de calidad del propio experimento: la estrella,
renderizada con SUS dimensiones reales (3×27, que coinciden con la
ventana fija), sale limpia y coherente en ambas interpretaciones (son
la misma) — confirma que el método de renderizado en sí es correcto,
no es un artefacto del script.

### Conclusión (mecánica, NO visual)

Dado que el `.tzx` reconstruido está verificado byte a byte contra el
original, este comportamiento — dibujar solo un fragmento de 81 bytes
con un ancho de fila que no coincide con el real, para 5 de las 6
formas no-estrella — es EXACTAMENTE lo que hace el juego real de
1988, no un artefacto de esta reconstrucción. Lo que NO se puede
confirmar solo con análisis estático es si esto se VE mal en la
pantalla real (curvas cortadas, apariencia de "glitch") o si, por
alguna razón no localizada en el código (o por ser tan breve y rápido
—toda la animación dura fracciones de segundo, con HALT de 1-2 frames
entre pasos— que resulta imperceptible), el resultado visual final es
aceptable. Ninguna hipótesis alternativa (relectura de
`TABLA_FILAS_PANTALLA`, otra rutina de dibujo con las dimensiones
reales) ha aparecido en el código — se buscó explícitamente y no
existe otro llamador de forma que use dimensiones distintas de 27×3.

Documentado con comentarios extensos en `DIBUJAR_FORMA_ANIMADA` y en
los 2 puntos donde se guardan `$EABE`/`$EAB3`, marcado explícitamente
como "PUZLE ABIERTO... sin confirmar todavía en emulador" — no se ha
forzado ninguna conclusión ni renombrado nada, siguiendo la norma del
proyecto de no sobre-afirmar.

**Verificado**: recompilado y reempaquetado tras los cambios de
comentarios — **0 diferencias, 48485 bytes idénticos al `.tzx`
original** (cambio de solo comentarios, sin efecto en el binario).

### CORRECCIÓN (misma sesión): el usuario descarta el glitch — el hallazgo de arriba queda cerrado, no confirmado

Preguntado directamente ("¿recuerdas si SOFT o las O se veían con
parpadeo/distorsión al entrar?"), el usuario — testigo directo del
juego original — respondió que **no hay parpadeo**: las letras
"aparecen una a una con un movimiento T-O-P-O", después "se rellena
el color", luego sale "SOFT rotando horizontalmente", y termina con
"el punto de luz por encima de SOFT hasta concluir con los frames de
la estrella sobre el extremo de la T" — una secuencia limpia, sin
mención de ningún artefacto visual, y que además encaja exactamente
con la secuencia maestra ya resuelta en sesión 10
(`DIBUJAR_LOGO_TOPOSOFT`).

Esto **descarta la hipótesis de un glitch visible** planteada arriba.
Conclusión revisada: la ventana fija de 27×3 (24×27 píxeles) de
`DIBUJAR_FORMA_ANIMADA` no es un desajuste que produzca un problema
visual — es sencillamente el tamaño REAL y CORRECTO con el que se
dibuja cada letra (una letra gruesa compacta, tamaño razonable para
un logo de este estilo). La coincidencia aritmética "ancho×alto de
cabecera = tamaño del fichero" sigue siendo un hecho real y
verificado, pero NO describe el ancho usado para dibujar en pantalla
— es coherente con lo ya sabido: `$EABE` es código muerto (sesión 17)
y `$EAB3` solo alimenta el contador de filas de
`RESTAURAR_FRANJA_FONDO` (usado nada más que para el borrado de fondo
de O1/O2), nunca el propio dibujo. Qué son exactamente los bytes de
cada forma más allá de los primeros 81 (hasta 774 en el caso de la T)
queda sin resolver — pero ya no hay ninguna sospecha de un problema
visual asociado. Comentarios en `portada_body.asm` y
`mapa_memoria_logotopo.html` actualizados para reflejar esta
corrección (ya no hablan de un "puzle abierto"/posible glitch, sino
de una investigación cerrada con el resultado: sin problema visual).

**Verificado**: recompilado tras el ajuste de comentarios — **0
diferencias, 48485 bytes**.

### Pendiente para próximas sesiones

- Qué son realmente los bytes de cada forma más allá de los primeros
  81 (p. ej. los ~693 bytes finales de `LOGO_T`) — nunca los lee
  `DIBUJAR_FORMA_ANIMADA`; podría ser metadata heredada de otra
  herramienta de la época, u otro dato sin relación con el dibujo.
  Prioridad baja: ya no hay sospecha de problema visual detrás.
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente.

## Sesión 20 — 2026-08-09: revisión completa de datos, decimales y comentarios de `portada_body.asm`

Petición del usuario: cerrar este bloque con un repaso íntegro del
fichero — revisar todos los datos, convertir a decimal los que
proceda, comentar todo lo que faltara, y comprobar si las
direcciones/datos en hexadecimal que quedan tienen etiqueta
equivalente y si deberían tenerla.

### Constante nueva: `ATRIBUTO_INICIO_SOFT`

`$59EF` (celda de atributo fila 15, columna 15 — donde
`DIBUJAR_SOFT_ROTANDO` dibuja "SOFT") aparecía repetido 3 veces como
literal suelto: en `ANIMAR_PUNTO_LUZ_SOFT`, en el valor por defecto
compilado del parámetro `$EC50` dentro de `RELLENAR_COLOR_TOPO`, y en
`DIBUJAR_LOGO_TOPOSOFT` (que fija `$EC50` a ese mismo valor). Las 3
son la MISMA celda conceptual — se añadió `ATRIBUTO_INICIO_SOFT EQU
$59EF` (constante, sin ocupar bytes) al principio del fichero y se
sustituyeron los 3 usos, incluyendo `ATRIBUTO_INICIO_SOFT+8` para la
celda de parada de `ANIMAR_PUNTO_LUZ_SOFT` (antes `$59F7` suelto).
Verificado que un `EQU` no rompe el ámbito de las etiquetas locales
(a diferencia de una etiqueta global normal, ver sesión 18) — compila
limpio.

El resto de direcciones autoemodificadas (`$EA83`, `$EA8E`, `$EAB6`,
`$EAC0`, `$EABE`, `$EAB3`, `$EB07`, `$EB10`, `$EC4E`, `$EC50`,
`$EC57`, `$EC5A`) se revisaron una a una y se dejaron SIN etiqueta
propia a propósito, consistente con la convención ya establecida:
son operandos de instrucciones concretas, no celdas de datos
independientes, y ponerles una etiqueta global rompería el ámbito de
las etiquetas locales de la rutina que las rodea (mismo problema visto
con `COPIAR_6_BYTES` en sesión 9 y con el intento de etiquetar
`$EAC0` en sesión 18).

### `RELLENAR_COLOR_TOPO`, completamente descifrada

No tenía ningún comentario de cabecera. Verificados sus 4 operandos
autoemodificados contra el listado compilado, dirección por
dirección: `$EC4E` = filas, `$EC50` = celda inicial, `$EC57` = ancho
de franja menos 1 (justificado: el primer byte se escribe a mano y
`LDIR` copia ese mismo byte `BC` veces más), `$EC5A` = color. Añadido
un bloque de cabecera explicando los 4, y comentado cada sitio donde
`DIBUJAR_LOGO_TOPOSOFT`/`ANIMAR_COLOR_TOPO` los fijan.

### Decimalizados y comentados: cantidades en todas las rutinas de dibujo

Todas las filas/columnas/índices de forma que quedaban en hexadecimal
sin comentar en `DIBUJAR_SOFT_ROTANDO`, `DIBUJAR_T_TOPO`,
`DIBUJAR_P_TOPO_ANIMADA`, `DIBUJAR_O1_TOPO`, `DIBUJAR_O2_TOPO_ANIMADA`,
`DIBUJAR_ESTRELLA_ANIMADA`, `DIBUJAR_LOGO_TOPOSOFT`,
`LIMPIAR_TABLA_COLOR_VRAM`, `RESTAURAR_FRANJA_FONDO` y
`ANIMAR_COLOR_TOPO` se convirtieron a decimal con un comentario que
explica qué representan (fila/columna fija, índice de forma, límite
de bucle, paso de incremento, etc.) — antes muchas de estas líneas no
tenían ningún comentario. Los sentinelas `$FF` y las máscaras de bits
de puerto (`$10` en `RUIDO_ALTAVOZ_HUERFANO`) se dejaron en
hexadecimal a propósito, según la convención ya establecida del
proyecto.

### Identificada `BORDCR` ($5C48)

`LIMPIAR_TABLA_COLOR_VRAM` escribía en `$5C48` sin ningún comentario.
Confirmado (documentación pública de la ROM): es `BORDCR`, la
variable de sistema estándar de la ROM de 48K (color de borde × 8,
más los atributos de la mitad inferior de pantalla). Añadido el
comentario; también documentados por primera vez `DIBUJAR_FORMA_TEMPORIZADA`
y `GUARDAR_PANTALLA_LOGO`, que no tenían cabecera propia.

### 3 erratas reales encontradas y corregidas

- Cabecera del fichero: `$EA60-$FABD` → **`$EA60-$FADD`** (letras
  transpuestas — `$FADD` es la dirección real confirmada desde
  sesión 16/17).
- `LOGO_T`: el comentario decía "cabecera 3 bytes, 765 de dibujo (85
  filas), 776 total (8 muertos)" — cifras aproximadas de la sintonía
  visual manual de sesiones muy tempranas. Corregido con las cifras
  exactas confirmadas en sesión 19: cabecera 2 bytes (igual que las
  demás formas), 774 de dibujo, 86 filas, 776 total, **0 muertos**.
  Mismo error de aritmética en `LOGO_SOFT_1` ("130 total, 2 muertos"
  cuando 2+128=130 exacto → 0 muertos) y en `mapa_memoria_logotopo.html`
  (mismas cifras de `LOGO_T` desactualizadas).
- Un comentario todavía citaba la variable con su nombre antiguo
  `PUNTERO_DATOS_FORMA` en vez de `VARIABLES_TRABAJO_FORMA` (renombrada
  en sesión 16); y otro citaba `(LD B,$09)`/`(C=$1B,B=$03)` en
  hexadecimal después de que el código ya se hubiera convertido a
  decimal en sesiones previas — corregidos ambos.

**Verificado**: recompilado y reempaquetado — **0 diferencias, 48485
bytes idénticos al `.tzx` original**. Inventario regenerado: 1075
etiquetas (función=81, interna=968, dato=25, sinref=1) — el conteo no
sube con la nueva constante `ATRIBUTO_INICIO_SOFT` porque
`gen_inventory.py` no contabiliza símbolos `EQU` como etiquetas
propias (limitación menor de la herramienta, no afecta al binario).

Con esta sesión, `portada_body.asm` queda con todos sus datos en
decimal donde corresponde, cada valor comentado, y sin ninguna
dirección/dato sin evaluar para ver si necesitaba etiqueta —
cerrando el bloque de la portada/logo tal como se pidió.

### Pendiente para próximas sesiones

- Qué son realmente los bytes de cada forma más allá de los primeros
  81 (p. ej. los 693 bytes finales de `LOGO_T`) — nunca los lee
  `DIBUJAR_FORMA_ANIMADA`; podría ser metadata heredada de otra
  herramienta de la época, u otro dato sin relación con el dibujo.
  Prioridad baja: ya no hay sospecha de problema visual detrás.
- `gen_inventory.py` podría extenderse para reconocer símbolos `EQU`
  como constantes con nombre propio (mejora menor de herramienta).
- Seguir con el resto de `madmix_body.asm` (36790 bytes, motor
  completo) — sigue siendo el trabajo grande pendiente.

## Sesión 21 — 2026-08-09: `portada_body.asm` — bloque cerrado

Petición del usuario: dar por finalizado `portada_body.asm`.

Balance del bloque (sesiones 1-20): los 4222 bytes de `$EA60-$FADD`
quedan con **análisis semántico completo** — ninguna dirección o dato
sin clasificar. Resumen de lo resuelto:

- Las 15 formas gráficas del logo (SOFT×7, T, O1, P, O2, estrella×4)
  identificadas, extraídas a ficheros propios y confirmadas
  visualmente.
- Las 6 secuencias de animación, la rutina de dibujo de bajo nivel
  (`DIBUJAR_FORMA_ANIMADA`, con sus 4 parámetros autoemodificados) y
  la secuencia maestra (`DIBUJAR_LOGO_TOPOSOFT`), todas con el mismo
  nombre que su equivalente ya resuelto en MSX donde existe
  equivalente real.
- Todas las tablas de datos y variables de trabajo, nombradas
  (compartiendo nombre con MSX cuando aplica) y comentadas.
- Los 2 fragmentos de código sin llamador conocido
  (`RUIDO_ALTAVOZ_HUERFANO`, `LDI_EXTRA_HUERFANOS`) analizados,
  documentados como huérfanos e integrados en el mapa de memoria.
- El salto a ROM (`PAUSA_ENTRE_LETRAS`/`$1F3D`) y el mecanismo de
  mezcla `OR (HL)` (`$EAC0`, comparado con MSX) resueltos.
- Una pista real sobre cómo Topo Soft generó la cinta maestra de 1988
  (volcado de RAM tras ejecución, no ensamblado limpio).
- Todos los datos en decimal donde corresponde, cada valor comentado,
  y 3 erratas reales corregidas en el propio fichero.

Quedan solo 2 detalles menores, de baja prioridad, explícitamente
documentados como sin resolver (no silenciados): 1 byte suelto sin
explicar en `TABLA_ANIMACION_SOFT` (`$ED28`) y el propósito real de
los bytes de cada forma más allá de los primeros 81 que se llegan a
dibujar. Ninguno de los dos compromete la verificación byte a byte
del binario ni sugiere ya ningún problema visual.

Actualizados `src/README.md` (estado de `portada_body.asm` marcado
como **fichero cerrado**) y `recursos/mapa_memoria_logotopo.html`
(pie de página, ya no habla de tramos pendientes).

**Verificado**: sin cambios de código en esta sesión (solo
documentación) — el build sigue en **0 diferencias, 48485 bytes**.

### Pendiente para próximas sesiones

- El trabajo grande que queda en todo el proyecto:
  `madmix_body.asm` (36790 bytes, el motor completo del juego),
  todavía en reconstrucción mecánica de primera pasada, sin analizar
  semánticamente. Aplicar la misma metodología usada aquí
  (comparación con MSX, política de nombres compartidos, búsqueda
  exhaustiva de referencias antes de dar nada por "sin uso",
  documentación exhaustiva sesión a sesión) usando
  `madmix1_body.asm`/`madmix_scr_body.asm` de MSX como referencia.
- Confirmar en vivo (emulador real, ROM de 48K) el arranque completo
  reconstruido — nunca se ha ejecutado, todo el análisis de este
  bloque es estático (mas el testimonio directo del usuario como
  jugador original, usado como ground truth en varias sesiones).

## Sesión 22 — 2026-08-09: primera sesión de análisis de `madmix_body.asm` — la cadena de arranque del motor

Petición del usuario: empezar a analizar las llamadas desde
`MOTOR_INICIO` (el punto de entrada de `CODE.bin`, $6000), apoyándose
en `madmix1_body.asm` y `madmix_scr_body.asm` de MSX como referencia
estructural — con la expectativa de que las diferencias reales estén
sobre todo en la gestión de gráficos/sonido y en particularidades
propias del Spectrum.

### Punto de partida

`madmix_body.asm` (36790 bytes, `$6000-$EFB5`) sigue siendo
**reconstrucción mecánica de primera pasada** (`dasm2asm.py`): cada
dirección solo tiene etiqueta `CODE_XXXX` si es a la vez destino real
de `CALL`/`JP`/`JR`/`DJNZ` DENTRO del fichero e inicio real de una
instrucción decodificada — el desensamblado es lineal (no sigue el
flujo real), así que buena parte del fichero son casi seguro datos
mal interpretados como código (exactamente el mismo punto de partida
que tuvo `LOAD.BIN` en MSX antes de identificarse sus huecos uno a
uno).

`MOTOR_INICIO` ($6000, destino de `JP $6000` desde `load_cas/loader_body.asm`)
hace un único `JP INICIO` ($9BE2) — el resto de bytes hasta ahí
(`$6003` en adelante) son casi con toda seguridad **variables de
trabajo del motor** (varios `LD BC,$0102`/`NOP` sin sentido como
código, en medio de las cuales aparece `JP ENTRADA_INTERRUPCION_VBLANK`
en `$6060`, ver abajo) — mismo patrón que `MODO_ENTRADA`/`FRAME_FLAG`
al principio de `START` en MSX.

### `INICIO` ($9BE2, antes `CODE_9BE2`) — RENOMBRADA, mismo nombre que MSX

Comparado con `INICIO` en `madmix1_body.asm` ($8F24). Coincidencias
estructurales claras:

- Fija el SP y hace `DI` antes de nada (MSX: `LD SP,$0FFF`; aquí:
  `LD SP,$5FFF`).
- Llama a la activación de interrupciones nada más empezar.
- Espera pulsación de tecla antes de continuar (MSX:
  `COMPROBAR_PULSACION` en bucle; aquí: bucle `CODE_9BEA` leyendo el
  puerto `$FE`).
- Justo después, inicializa el estado de partida: **4 variables
  consecutivas que coinciden EXACTAS en cantidad, orden y valor** con
  las que fija `REINICIAR_PARTIDA` en MSX (`VIDAS_RESTANTES=3`,
  `PUNTUACION=0`, `NIVEL_ACTUAL=1`, `CONTADOR_VUELTAS_NIVELES=0`) —
  coincidencia demasiado exacta para ser casual, ver más abajo.
- Un patrón `SCF`/`AND A` antes de una reentrada compartida
  (`CODE_9C22`) que recuerda a los 2 puntos de entrada de MSX
  (`REINICIAR_PARTIDA`/`PANTALLA_PRESENTACION_NIVEL`).

Diferencia real notable: MSX llama a `DIBUJAR_PORTADA` (redibuja el
logo) justo tras activar interrupciones — aquí no hay ninguna llamada
equivalente visible. Tiene sentido: en Spectrum la portada vivía en
la MISMA memoria que ahora ocupa el motor (confirmado en el bloque de
la portada, `$EA60-$FADD` cae dentro de `$6000-$EFB5`) — para cuando
`CODE.bin` salta aquí, el código de la portada ya no existe en RAM
(se sobreescribió), así que no podría volver a llamarse.

### `ACTIVAR_INTERRUPCION_MODO_2` ($94FC, antes `CODE_94FC`) — RESUELTA

Rellena la página `$F600-$F6FF` con el byte `$60` (truco "diamante"
de interrupciones en modo 2 del Z80: como todos los bytes son
iguales, el vector leído siempre resuelve a la palabra en `$6060`),
fija `I=$F6`, `IM 2`. **Confirmado**: en `$6060` hay literalmente
`JP ENTRADA_INTERRUPCION_VBLANK` (dentro de la zona de "datos
disfrazados de código" que sigue a `MOTOR_INICIO`) — verificación
exacta del mecanismo, no solo hipótesis.

Mismo ROL que `ACTIVAR_INTERRUPCION_MODO_1` en MSX (activar la
interrupción periódica del motor), pero mecanismo real distinto — MSX
usa el modo 1 del Z80 con el VDP como disparador; aquí, sin VDP, se
usa el modo 2 con la tabla diamante, la técnica estándar en juegos de
Spectrum para una interrupción fiable de 50Hz. Nombre propio
reflejando la diferencia real de hardware (mismo patrón de nombre que
`ACTIVAR_INTERRUPCION_MODO_1`, siguiendo la convención del proyecto).

### `ENTRADA_INTERRUPCION_VBLANK` ($950F, antes `CODE_950F`) — RENOMBRADA, mismo nombre que MSX

La rutina de servicio de interrupción real, destino del vector IM2.
**Mismo nombre exacto** que en MSX (`madmix1_body.asm`, `$882A`) — es
el manejador de la interrupción periódica de 50Hz del motor en ambas
versiones (disparada por VBLANK del VDP en MSX, por el temporizador
de la ULA aquí — en la práctica, "una vez por fotograma" en los dos
casos). Guarda TODOS los registros (incluido el juego alterno
`EXX`/`EX AF,AF'` e `IX`/`IY`) antes de llamar a `CODE_9534`/`CODE_8F55`
y termina con `EI`/`RETI` — esas 2 llamadas todavía sin analizar
(candidatas a lectura de teclado/temporizador de música, sin
confirmar).

### Hipótesis fuertes para próximas sesiones (documentadas, sin renombrar todavía)

- **Las 4 variables de estado de partida** (`$603A`, `CODE_603C`,
  `$601B`, `$603F` — hipótesis: `VIDAS_RESTANTES`, `PUNTUACION`,
  `NIVEL_ACTUAL`, `CONTADOR_VUELTAS_NIVELES`): coincidencia exacta de
  cantidad/orden/valor con MSX, documentada con una tabla comparativa
  en el propio código. No renombradas todavía porque requiere primero
  reconvertir la zona de "datos disfrazados de código" en
  `$6003-$60xx` a `DB`/`DS` reales (mismo trabajo que hubo que hacer
  con `MODO_ENTRADA`/`FRAME_FLAG` en MSX) — tarea para una sesión
  dedicada, no algo que forzar de paso.
- **Una tabla de 11 `JP` consecutivos sin llamador textual encontrado
  todavía**, justo después de `CODE_918D` (~`$91D3`): candidata fuerte
  a ser el equivalente Spectrum de la "API pública" `JT_*` de MSX (12
  entradas al principio de `START`) — uno de los 11 destinos es
  precisamente `ACTIVAR_INTERRUPCION_MODO_2`, que en MSX también es
  una entrada de esa tabla (`JT_ACTIVAR_INTERRUPCION`). Falta
  encontrar quién indexa/llama a esta tabla (probable `JP (HL)` con
  índice calculado en otro punto del fichero) y mapear los otros 10
  destinos.
- **`CODE_915A`/`CODE_9174`/`CODE_918D`**: rellenan pantalla/atributos
  con datos comprimidos tipo RLE (par valor+repeticiones) leídos de
  tablas fijas (`$904A`) — candidatos a equivalente de
  `APLICAR_COLOR_PANTALLA`/`APLICAR_COLOR_CICLO_NIVELES` en MSX
  (aplicar un esquema de color por nivel), sin confirmar.
- **`CODE_E1F9`**: instala temporalmente un manejador de interrupción
  distinto (guarda/restaura el vector real en `$6061-$6062`) y genera
  un tono por el altavoz (`OUT ($FE)` alternando en un bucle de
  temporización) durante la espera de tecla al arrancar — candidato a
  la sustitución Spectrum (altavoz, sin chip de sonido dedicado) de
  la gestión de canales de sonido del PSG en MSX
  (`VACIAR_CANALES_SONIDO`/`INSTALAR_RECURSO_SONIDO`), coherente con
  la expectativa del usuario de que las diferencias reales estarían
  en la gestión de sonido/gráficos. Sin analizar a fondo todavía.
- **`CODE_8A3F`/`CODE_883B`**: llamadas justo antes/después del bloque
  de las 4 variables de estado, en las mismas posiciones relativas
  donde MSX llama a `VACIAR_CANALES_SONIDO` — candidatos, sin
  confirmar (no se ha mirado su contenido todavía).

**Verificado**: recompilado y reempaquetado tras los 3 renombrados —
**0 diferencias, 48485 bytes idénticos al `.tzx` original**.
Inventario regenerado (el total no cambia con renombrados puros,
1075 etiquetas).

### Pendiente para próximas sesiones

- Confirmar/descartar las hipótesis de esta sesión (4 variables de
  estado, tabla de 11 `JP`, rutinas RLE de color, generador de tono,
  candidatos a `VACIAR_CANALES_SONIDO`) antes de seguir avanzando por
  el flujo de `INICIO`.
- Encontrar el llamador real de la tabla de 11 `JP` — probable clave
  para mapear de golpe varias rutinas más del motor, igual que la
  tabla `JT_*` fue la puerta de entrada al análisis completo de MSX.
- Reconvertir `$6003-$60xx` (zona de variables disfrazada de código
  tras `MOTOR_INICIO`) a `DB`/`DS` reales antes de renombrar las 4
  variables de estado con confianza.
- Seguir el resto del flujo de `INICIO` más allá de `CODE_9C22`
  (queda sin examinar) — es la continuación real hacia lo que en MSX
  es `PANTALLA_PRESENTACION_NIVEL`/el bucle principal.

## Sesión 23 — 2026-08-09: `DIBUJAR_TEXTO_VRAM` y la secuencia de HUD de inicio de nivel

Petición del usuario: continuar la sesión anterior, siguiendo el
flujo desde `INICIO`.

### Investigada la tabla de 11 `JP` (sesión 22) — sin resolver todavía

Localizada con exactitud: `$9198-$91B8` (11 instrucciones `JP`, 3
bytes cada una), seguida de 23 bytes que el desensamblado mecánico
lee como `NOP` pero que en realidad son **variables reales**: `$91C2`
(dentro de ese rango) se lee/escribe desde el helper de
`ENTRADA_INTERRUPCION_VBLANK` (`CODE_9534`) — mismo patrón que el
área de trabajo `MODO_ENTRADA`/`FRAME_FLAG` justo después de la tabla
`JT_*` en MSX (tabla de despacho + variables de interrupción justo
detrás). Buscado en todo el fichero cualquier referencia literal a
`$9198` (el inicio de la tabla): **ninguna** — y `CODE_91D0` (su
primer destino) se llama además directamente desde 8 sitios distintos
como subrutina normal, así que no es "solo" el primer salto de la
tabla. Sigue sin encontrarse el llamador real (candidato: algún `JP
(HL)`/`JP (IX)`/`JP (IY)` con dirección calculada, hay 23 en todo el
fichero sin revisar todavía uno a uno). Pendiente.

### `DIBUJAR_TEXTO_VRAM`, `ESCRIBIR_PATRON_VRAM`, `ESPERAR_TECLA_PULSADA`/`ESPERAR_TECLA_SOLTADA` — RESUELTAS, mismos nombres que MSX

Investigando `CODE_8BEE` (llamada desde `CODE_9C22`, ver sesión 22):
comparado instrucción a instrucción contra `DIBUJAR_TEXTO_VRAM` de
MSX (`madmix_scr_body.asm`, `$5CD1`) — **mecanismo prácticamente
idéntico**: `DE` apunta a un registro `[C=número de caracteres,
color/atributo, C bytes]`; cada byte ≥`$20` dibuja un carácter
(avanzando `HL`), cada byte <`$20` es un contador de columnas en
blanco a saltar. Renombrada con el mismo nombre exacto. Llamada **32
veces** en todo el motor — es la rutina de texto/HUD más usada del
juego.

Su subrutina de dibujo de un carácter (`CODE_8BCB`) hace exactamente
lo que `ESCRIBIR_PATRON_VRAM` de MSX (`$5CAF`): copia el patrón de 8
filas del carácter (indexado ×8 en una tabla de fuente, aquí `$9EFE`)
y fija el color de esa celda — incluye una conversión dirección de
pantalla→atributo (`RRCA`×3 + `AND 3` + `OR $58`), la fórmula estándar
de Spectrum, confirmando que de verdad escribe tanto forma como color
en una sola pasada (en MSX son 2 mitades de VRAM separadas, aquí es
la misma memoria lineal). Renombrada igual.

`CODE_8C0D`/`CODE_8C16` (el par "espera tecla pulsada"/"espera tecla
soltada", ya vistos en sesión 22 dentro de `INICIO`) resultaron ser
genéricos y reutilizados — renombrados con los mismos nombres exactos
que `ESPERAR_TECLA_PULSADA`/`ESPERAR_TECLA_SOLTADA` de MSX
(`madmix_scr_body.asm`, `$5CFE`/`$5D04`), mismo rol, mecanismo
Spectrum propio (puerto `$FE` directo, sin escaneo de matriz tipo
`COMPROBAR_PULSACION`).

### La secuencia de HUD de `CODE_9C22`, descifrada en buena parte

Con `DIBUJAR_TEXTO_VRAM` confirmada, sus 3 llamadas dentro de
`CODE_9C22` encajan letra por letra con la descripción de MSX ("Dibuja
3 líneas de texto de HUD/pantalla según el nivel actual y dos flags
del registro de nivel"):

1. Copia 2 bytes de una tabla indexada por nivel (`$9E1E` +
   nivel×2) a `$9E1C` (candidato "registro de nivel") y dibuja el
   texto de `$484C`.
2. Si viene de "partida nueva" (flag de acarreo puesto en
   `CODE_9C07`/`CODE_9C21`), espera 50 frames (~1s) y repite la
   llamada a `CODE_E1F9` (candidato sonido/tono, sesión 22).
3. Si un flag en `$603E` está activo, lo suma a `$603A` (candidato
   `VIDAS_RESTANTES`, tope 5) y dibuja el texto de `$48CE` —
   probable mensaje de "vida extra".
4. Si `$600E`=1 y las vidas son <4, dibuja el texto de `$5045` — otro
   aviso condicional.

Termina esperando 80 frames (~1.6s) — tiempo de lectura del HUD.
Encaja con `PREPARAR_INICIO_NIVEL` de MSX (la secuencia de
transición "nivel cargado → HUD → esperar", no el bucle de cada
frame). `CODE_9C93` justo después (llama a `CODE_9904` dos veces
separadas por `CODE_9174`, el relleno RLE de atributos de sesión 22)
es candidato a ser la continuación de esa misma secuencia — sin
analizar todavía.

**Verificado**: recompilado y reempaquetado tras los 4 renombrados —
**0 diferencias, 48485 bytes idénticos al `.tzx` original**.

### Nota sobre herramientas

`tools/gen_inventory.py` sigue reportando el mismo total (1075
etiquetas) antes y después de renombrar/documentar `madmix_body.asm`
— comprobado que SÍ incluye contenido de ese fichero (aparece
`DIBUJAR_TEXTO_VRAM` en el HTML generado), pero el número tan estable
sugiere que no está contando la mayoría de las ~1023 etiquetas
mecánicas `CODE_XXXX` del fichero — probablemente una limitación de
su heurística de clasificación con ficheros grandes, sin investigar
todavía. No afecta a la verificación del binario (que sigue en 0
diferencias); es una tarea de herramienta pendiente, de baja
prioridad.

### Pendiente para próximas sesiones

- Encontrar el llamador real de la tabla de 11 `JP` en `$9198`
  (revisar los 23 `JP (HL)`/`JP (IX)`/`JP (IY)` del fichero uno a
  uno) — sigue siendo la pista más prometedora para mapear de golpe
  varias rutinas más del motor.
- Analizar `CODE_883B`/`CODE_8A3F` (candidatos `VACIAR_CANALES_SONIDO`)
  y `CODE_E1F9` (candidato generador de tono) a fondo.
- Seguir `CODE_9C93` en adelante — la continuación de la secuencia de
  HUD de inicio de nivel.
- Reconvertir `$6003-$60xx` y la zona `$91B9-$91CF` (variables
  disfrazadas de código) a `DB`/`DS` reales antes de renombrar las 4
  variables de estado de partida con confianza.
- Investigar por qué `gen_inventory.py` no parece contabilizar la
  mayoría de las etiquetas de `madmix_body.asm` (mejora de
  herramienta, baja prioridad).

## Sesión 24 — 2026-08-09: `CARGAR_NIVEL` — coincidencia casi perfecta con MSX, y ~18 variables de motor confirmadas de golpe

Petición del usuario: continuar la sesión anterior.

### `CODE_883B` no era "vaciar sonido" — es `CARGAR_NIVEL`

Investigando `CODE_883B` (uno de los 2 candidatos a
`VACIAR_CANALES_SONIDO` de la sesión 22) resultó ser, en realidad,
**prácticamente idéntica instrucción a instrucción** a `CARGAR_NIVEL`
en `madmix_scr_body.asm` de MSX: mismos registros, misma secuencia,
**los mismos valores constantes literales** (20 bytes/registro de
nivel, 96 bytes de cabecera, `$3C` como tile comodín) — y, el detalle
más revelador, **la misma dirección exacta `$FC60`** que usaba la
**v1.0 original** de MSX antes de que la v2.0 la moviera a `$FC50`
para arreglar el bug del contador de bolitas del nivel 13 (ver
`FINDINGS.md` de MSX). Esto no es solo "mismo algoritmo" — es
evidencia de que esta cinta Spectrum comparte linaje de desarrollo
directo con el MSX v1.0 sin parchear.

Renombrada `CODE_883B` → **`CARGAR_NIVEL`** (mismo nombre exacto).

### ~18 variables del motor confirmadas de golpe

La correspondencia exacta con `CARGAR_NIVEL` permitió identificar,
por primera vez con confianza alta, un bloque grande de la zona de
variables de trabajo del motor (`$600x-$602x`, dentro de la misma
zona de "datos disfrazados de código" que sigue a `MOTOR_INICIO`):

| Spectrum | MSX (mismo campo) |
|---|---|
| `$601B` | `NIVEL_ACTUAL` (confirma la hipótesis de sesión 22) |
| `$88E0` | `TABLA_NIVELES` |
| `$6007` | `REGISTRO_NIVEL_CUERPO_PTR` |
| `$6009` | `REGISTRO_NIVEL_CABECERA_PTR` |
| `$600B` | `REGISTRO_NIVEL_PIE_PTR` |
| `$600D` | `REGISTRO_NIVEL_FILAS` |
| `$6013` | `REGISTRO_NIVEL_LOSETA_COMODIN` |
| `$6014` | `REGISTRO_NIVEL_FILA_COLUMNA` |
| `$603F` | `CONTADOR_VUELTAS_NIVELES` (confirma sesión 22) |
| `$601C` | `CONTADOR_BOLAS_COMIDAS` |
| `$601E` | `POSICION_PARPADEO_BOLA` |
| `$6023` | `MODO_ESPECIAL_ACTIVO` |
| `$6040` | `MODO_ESPECIAL` |
| `$6025` | `SELECTOR_SPRITE_COMECOCOS` |
| `$6022` | `MODO_ESPECIAL_CUENTA_ATRAS` |
| `$6021` | `MODO_ESPECIAL_FLAG` |
| `$6037` | `COLOR_ACTUAL` |
| `$602C` | `COLOR_GUARDADO` |

Todas documentadas con comentarios inline en `CARGAR_NIVEL`, pero
**sin renombrar todavía como etiquetas reales** — siguen dentro de la
zona `$6003` en adelante que el desensamblado mecánico representa
como pseudo-instrucciones en vez de `DB`/`DS`. Reconvertir esa zona
(ya con 18 nombres confirmados de una vez, en vez de uno a uno) es
ahora una tarea mucho más rentable que antes — candidata clara para
la próxima sesión.

`$9E12`/`$9E13` (tocados al final de `CARGAR_NIVEL`) no tienen
equivalente identificado en MSX todavía. `CODE_83A3` (candidato
`MAPEAR_COORDENADA_A_DIRECCION`) y `CODE_87BC` quedan sin analizar.

### Corregidos comentarios obsoletos

El comentario de `CODE_9C22` decía "HIPÓTESIS: `VACIAR_CANALES_SONIDO`
otra vez" sobre la llamada a lo que ahora sabemos es `CARGAR_NIVEL` —
corregido. También actualizado el comentario de `CODE_9C07` para
marcar `$601B`/`$603F` como confirmadas (ya no hipótesis) y aclarar
que `CODE_883B` (el otro candidato a `VACIAR_CANALES_SONIDO` barajado
en sesión 22) resultó ser algo completamente distinto — `CODE_8A3F`
sigue siendo el único candidato pendiente de analizar para ese rol.

### Tabla de 11 `JP` (sesión 22-23) — sigue sin resolver

No se ha vuelto a investigar esta sesión; sigue pendiente revisar los
23 `JP (HL)`/`JP (IX)`/`JP (IY)` del fichero uno a uno para encontrar
un posible llamador computado.

**Verificado**: recompilado y reempaquetado tras el renombrado y la
documentación — **0 diferencias, 48485 bytes idénticos al `.tzx`
original**.

### Pendiente para próximas sesiones

- **Reconvertir `$6003-$60xx`** (zona de variables tras `MOTOR_INICIO`)
  a `DB`/`DS` con las 18 etiquetas ya confirmadas en esta sesión —
  ahora es la tarea de mayor rendimiento disponible.
- Analizar `CODE_8A3F` (único candidato restante a
  `VACIAR_CANALES_SONIDO`) y `CODE_E1F9` (candidato generador de tono).
- Analizar `CODE_83A3` (candidato `MAPEAR_COORDENADA_A_DIRECCION`) y
  `CODE_87BC`.
- Encontrar el llamador real de la tabla de 11 `JP` en `$9198`.
- Seguir `CODE_9C93` en adelante (continuación de la secuencia de HUD
  de inicio de nivel).

## Sesión 25 — 2026-08-09: reconvertida la zona de variables tras `MOTOR_INICIO` a `DB`/`DW` reales

Petición del usuario: continuar con la tarea identificada como más
rentable al cierre de la sesión anterior — reconvertir `$6003-$605F`
(la zona que el desensamblado mecánico mostraba como
pseudo-instrucciones sin sentido, nunca ejecutada de verdad) a
`DB`/`DW` reales, usando las 18 variables confirmadas en sesión 24.

### Extracción exacta de los 93 bytes

Antes de tocar nada, se extrajeron del listado compilado
(`src/build/main.lst`) los 93 bytes exactos de `$6003` a `$605F`,
byte a byte, para garantizar que la reconversión a `DB`/`DW`
reproduce EXACTAMENTE los mismos bytes que el desensamblado mecánico
(y por tanto que el original de 1988) — nada se "adivinó".

### Reconvertida la zona completa

Sustituidas las ~85 líneas de pseudo-instrucciones (`NOP`, `LD
BC,$0102`, `DJNZ`, etc.) por `DB`/`DW` con etiquetas reales en las 18
direcciones confirmadas en sesión 24 (`REGISTRO_NIVEL_CUERPO_PTR`,
`REGISTRO_NIVEL_CABECERA_PTR`, `REGISTRO_NIVEL_PIE_PTR`,
`REGISTRO_NIVEL_FILAS`, `REGISTRO_NIVEL_LOSETA_COMODIN`,
`REGISTRO_NIVEL_FILA_COLUMNA`, `NIVEL_ACTUAL`,
`CONTADOR_VUELTAS_NIVELES`, `CONTADOR_BOLAS_COMIDAS`,
`POSICION_PARPADEO_BOLA`, `MODO_ESPECIAL`/`_ACTIVO`/`_CUENTA_ATRAS`/
`_FLAG`, `SELECTOR_SPRITE_COMECOCOS`, `COLOR_ACTUAL`,
`COLOR_GUARDADO`), más `VIDAS_RESTANTES`/`PUNTUACION` (hipótesis
fuerte desde sesión 22) y `CODE_603C` → **`PUNTUACION`**. Todas las
~90 referencias a estas 18 direcciones a lo largo de TODO el fichero
(no solo en `CARGAR_NIVEL`) se actualizaron para usar los nombres
reales — algunas se usan más de 20 veces en todo el motor
(`COLOR_ACTUAL` 26 veces, `MODO_ESPECIAL` 17, `MODO_ESPECIAL_ACTIVO`
13), confirmando que son variables centrales del juego, no detalles
menores.

Los bytes SIN identificar se dejaron como `DB` sueltos, sin inventar
nombre — pero cuando resultaron ser variables REALES (referenciadas
desde código ejecutado en otras partes del fichero, no solo relleno),
se anotó explícitamente en el comentario para que quede constancia
para la próxima sesión: `$600E`, `$6018`, `$6027`, `$602A-$602B`
(usada además de forma repetida, en 5 sitios distintos) y `$603E`.
`CODE_6026` se mantiene con su nombre mecánico (es una variable real,
usada en 3 sitios) al no tener correspondencia MSX identificada
todavía.

### Curiosidad: varios bytes NO son cero en el `.tzx`, pese a que deberían serlo

Igual que en la portada (sesión 16), algunas de estas variables
"deberían" empezar a 0 en un ensamblado limpio (`CARGAR_NIVEL` y
`CODE_9C07` las sobrescriben siempre antes de leerlas), pero el
`.tzx` real trae valores concretos no nulos: `REGISTRO_NIVEL_FILAS`=18,
`REGISTRO_NIVEL_LOSETA_COMODIN`=192 (`$C0`), `VIDAS_RESTANTES`=3
(coincide con el valor inicial real, aunque podría ser casualidad).
Posible eco del mismo fenómeno encontrado en la portada (cinta
generada volcando RAM tras una ejecución real, no desde un ensamblado
limpio) — anotado en el código, sin investigar a fondo todavía
(prioridad baja).

### Limpieza de comentarios redundantes

Tras el renombrado masivo (vía `sed` sobre todo el fichero), varios
comentarios que citaban la dirección en hexadecimal quedaron
duplicando el nombre real (p. ej. `LD A,(NIVEL_ACTUAL) ; NIVEL_ACTUAL`)
— revisados y limpiados en `CARGAR_NIVEL`, la cabecera de la zona de
variables, y los bloques `CODE_9C07`/`CODE_9C22`.

### Resuelta la duda sobre `gen_inventory.py` (sesión 23)

El total de etiquetas subió de 1075 a **1093** (+18) tras esta
sesión, confirmando que la herramienta SÍ cuenta las etiquetas de
`madmix_body.asm` correctamente — el total se había quedado "atascado"
en sesiones anteriores simplemente porque **renombrar una etiqueta ya
existente no cambia el número total de etiquetas** (es lo esperable,
no un fallo de la herramienta). Duda cerrada, sin necesidad de tocar
la herramienta.

**Verificado**: recompilado y reempaquetado tras la reconversión
completa — **0 diferencias, 48485 bytes idénticos al `.tzx`
original**. Inventario regenerado: 1093 etiquetas (función=81,
interna=979, dato=32, sinref=1).

### Pendiente para próximas sesiones

- Analizar `CODE_8A3F` (único candidato restante a
  `VACIAR_CANALES_SONIDO`) y `CODE_E1F9` (candidato generador de tono).
- Analizar `CODE_83A3` (candidato `MAPEAR_COORDENADA_A_DIRECCION`) y
  `CODE_87BC`.
- Encontrar el llamador real de la tabla de 11 `JP` en `$9198`.
- Seguir `CODE_9C93` en adelante (continuación de la secuencia de HUD
  de inicio de nivel).
- Investigar `$600E`/`$6018`/`$6027`/`$602A`/`$603E`/`CODE_6026` —
  variables reales sin correspondencia MSX identificada todavía.

## Sesión 26 — 2026-08-09: `WAIT_VBLANK`, `LEER_ENTRADA` y el resto del lector de teclado — y confirmación fuerte de la tabla de 11 `JP`

Petición del usuario: continuar el flujo lineal desde `CODE_9C93`
(punto 1 de las opciones planteadas al cierre de la sesión anterior).

### `WAIT_VBLANK` — RESUELTA, mismo nombre que MSX

`CODE_9675` resultó ser trivial y perfecta: pone a 1 la bandera
`$91C2` (la misma que ya sabíamos que lee `ENTRADA_INTERRUPCION_VBLANK`
vía su ayudante `CODE_9534`, sesión 22) y hace `EI`/`HALT` — espera
literalmente a la siguiente interrupción de 50Hz. Mismo nombre exacto
que `JT_WAIT_VBLANK` en MSX. Llamada 10 veces en todo el motor.

### `LEER_ENTRADA` y el lector de teclado completo — RESUELTOS, mismos nombres que MSX

`CODE_9AC6` resultó casi idéntica instrucción a instrucción a
`LEER_ENTRADA` de MSX (`madmix1_body.asm`, `$8E3C`): misma puerta de
bloqueo (bandera de 1 bit), mismo convenio de acumulador
limpiar/acumular según el parámetro `A`, mismo despacho según un modo
de entrada, mismo bucle de 5 lecturas construyendo un bitmask en `E`
con `RL E`, y una 6ª prueba compartida (`SET 5,E` — **mismo número de
bit** que en MSX) para una tecla especial (candidata a pausa).
Renombrada con el mismo nombre exacto, junto con sus 3 subrutinas de
apoyo: `ESCANEAR_FILAS_TECLADO`, `COMPROBAR_PAUSA` y `COMPROBAR_TECLA`
(equivalente de `COMPROBAR_TECLA_MSX`, aquí leyendo el puerto ULA
`$FE` con el truco clásico `LD A,(fila)/IN A,($FE)` en vez de la
matriz del PSG de MSX).

### Confirmación fuerte de la tabla de 11 `JP` (sesión 22-23)

`WAIT_VBLANK`, `ACTIVAR_INTERRUPCION_MODO_2` y `LEER_ENTRADA` — las 3
rutinas identificadas con nombre exacto de MSX hasta ahora — resultan
ser **3 entradas consecutivas** de la tabla sin llamador conocido de
`$9198` (posiciones 3, 4 y 5). En MSX, `JT_WAIT_VBLANK`,
`JT_ACTIVAR_INTERRUPCION` y `JT_LEER_ENTRADA` son TAMBIÉN 3 entradas
consecutivas de `JT_*`, en el MISMO orden relativo (posiciones 4, 5 y
6). Esta coincidencia de orden, no solo de contenido, es una prueba
mucho más fuerte que antes de que la tabla de `$9198` es de verdad el
equivalente Spectrum de la "API pública" `JT_*` — aunque su llamador
real (probablemente un `JP (HL)`/`JP (IX)`/`JP (IY)` con índice
calculado) sigue sin encontrarse.

### Contexto: `CODE_60CD` despacha entrada real vs. guion de demo

De paso, `CODE_60CD` (que llama a `LEER_ENTRADA`) resultó tener el
mismo patrón que el modo demo de MSX: si una bandera (`$8F43`) está
activa, usa un valor de `D` en vez de leer el teclado — igual que
`PUNTERO_GUION_DEMO` en MSX (sesión 24, visto en el ejemplo de
`CARGAR_NIVEL` en modo demo). `CODE_9D25` (llama a `CODE_60CD` y
`WAIT_VBLANK` justo al principio) es candidato a bucle principal de
juego, sin confirmar todavía que reentra cíclicamente.

**Verificado**: recompilado y reempaquetado tras los 5 renombrados —
**0 diferencias, 48485 bytes idénticos al `.tzx` original**.
Inventario regenerado: 1093 etiquetas (sin cambio en el total, son
todo renombrados de etiquetas ya existentes).

### Pendiente para próximas sesiones

- Encontrar el llamador real de la tabla de 11 `JP` en `$9198` — con
  3 de 11 entradas ya confirmadas y en el mismo orden relativo que
  MSX, sigue siendo la pista más prometedora del fichero.
- Confirmar si `CODE_9D25` es de verdad el bucle principal (buscar su
  reentrada cíclica).
- Analizar `CODE_8A3F` (único candidato restante a
  `VACIAR_CANALES_SONIDO`) y `CODE_E1F9` (candidato generador de tono).
- Analizar `CODE_83A3` (candidato `MAPEAR_COORDENADA_A_DIRECCION`) y
  `CODE_87BC`.
- Investigar `$600E`/`$6018`/`$6027`/`$602A`/`$603E`/`CODE_6026`/`$9B83`
  — variables reales sin correspondencia MSX identificada todavía.

## Sesión 27 — 2026-08-09: `CODE_6063` escondía 3 tablas reales de animación del sprite del jugador

Petición del usuario: analizar `CODE_6063` (el "`JR CODE_60CD`" de 2
bytes justo antes del dispatcher de entrada visto en sesión 26).

### No es un simple stub — esconde 104 bytes de datos reales

El `JR CODE_60CD` salta por encima de 104 bytes (`$6065-$60CC`) que
el desensamblado mecánico mostraba como instrucciones sin sentido
(`NOP`, `LD BC,$0102`, etc. — igual que la zona de variables tras
`MOTOR_INICIO`, sesión 25, o las tablas de la portada). Comprobado con
`grep` en todo el fichero: **hay referencias reales** a estas
direcciones exactas desde rutinas muy alejadas — no es relleno ni
código muerto, es una tabla incrustada entre código, con un salto
alrededor para no ejecutarla por accidente.

### El mecanismo completo, reconstruido cruzando todos sus lectores

1. **`TABLA_RESOLVER_DIRECCION`** (16 bytes, `$6065`): indexada por una
   máscara de 4 bits (salida de `LEER_ENTRADA` con varias teclas
   pulsadas a la vez), resuelve a un único estado 0-4 (0=sin
   dirección, 1-4=cuatro direcciones). **Compartida** por al menos 2
   rutinas distintas del fichero — una en el dispatcher de entrada
   visto en sesión 26, otra mucho más adelante con acceso a una
   estructura vía `IX+2..+5` (candidata a lógica de otro
   actor/fantasma) — por eso el nombre NO lleva sufijo `_COMECOCOS`.

2. **`TABLA_PUNTEROS_ANIMACION_COMECOCOS`** (4 punteros, `$6075`):
   elegida según el estado especial del jugador, apunta a 1 de 4
   bloques de animación alternativos. **Direcciones ABSOLUTAS**, no
   desplazamientos (a diferencia de `TABLA_PUNTEROS_FORMAS` en la
   portada) — el código las usa tal cual, sin sumarles ninguna base
   después. Detectado y corregido un error propio: al escribirla la
   primera vez la codifiqué como relativa por costumbre (por el patrón
   de la portada) — la verificación byte a byte la habría delatado,
   pero se revisó el código consumidor ANTES de compilar y se corrigió
   sin necesidad de descubrirlo por un fallo de compilación.

3. **4 bloques `ANIMACION_COMECOCOS_0..3`** (20 bytes cada uno): 5
   grupos de 4 bytes = 5 estados de dirección (0-4) × 4 fotogramas
   rotatorios. Cada byte es un índice de sprite real o un centinela:
   `$FF`="reintenta con el siguiente fotograma", `$FE`="mantiene el
   sprite actual" (el grupo 0, "sin dirección pulsada", es SIEMPRE
   `$FE,$FE,$FE,$FE` — el personaje no anima si está quieto, coherente
   con el comportamiento clásico de Pac-Man). El resultado se guarda
   en `SELECTOR_SPRITE_COMECOCOS` (ya confirmada, sesión 24), cuyo bit
   7 se usa después como flag de volteo horizontal — **mismo convenio
   de bit ya documentado para esa variable en MSX**. Dentro de cada
   bloque, 2 de los 5 grupos suelen compartir la misma secuencia de
   fotogramas con el bit 7 puesto — reutilizar el mismo ciclo de
   caminar para direcciones opuestas, volteando en vez de dibujar
   fotogramas nuevos.

### Pista falsa descartada

Un `LD SP,$6094` que aparece mucho más adelante en el fichero (cerca
de `$C4E7`) parecía a primera vista un lector rápido tipo `POP` de
esta misma tabla — comprobado el contexto real: es pura coincidencia
de bytes dentro de una zona de datos sin relación, no un lector
genuino. Descartada explícitamente en el comentario del código para
que no se reabra por error en el futuro.

**Verificado**: recompilado y reempaquetado — **0 diferencias, 48485
bytes idénticos al `.tzx` original**. Inventario regenerado: 1098
etiquetas (función=81, interna=978, dato=38, sinref=1).

### Aclaración: las 3 tablas son índices, no gráficos

Pregunta directa del usuario: ¿`ANIMACION_COMECOCOS_0` etc. contienen
gráficos? **No** — son tablas de índices/selectores, no de píxeles.
Confirmado mirando qué hace el código justo después de leer
`SELECTOR_SPRITE_COMECOCOS` (`CODE_61E6`): el valor (con el bit 7 ya
separado como flag de volteo) pasa a `B` como **índice**, y justo
después `LD E,$40` fija **E=64** — el mismo número exacto que en MSX
limita `PTR_TABLA_SPRITES` ("64 = entradas de la tabla de sprites").
Confirma que `B` indexa una **tabla de gráficos de sprites aparte**
(equivalente a `PTR_TABLA_SPRITES` de MSX), todavía sin localizar en
este fichero — buen candidato concreto para una próxima sesión.
Añadida esta aclaración al comentario del código.

### Pendiente para próximas sesiones

- **Localizar la tabla real de gráficos de sprites** (candidata a
  `PTR_TABLA_SPRITES`, ~64 entradas) que `B` indexa tras
  `SELECTOR_SPRITE_COMECOCOS` — ahora que sabemos que existe y
  aproximadamente su tamaño, debería ser localizable.
- Confirmar con qué exactamente se corresponden los 4 estados de
  `TABLA_PUNTEROS_ANIMACION_COMECOCOS` (candidatos:
  normal/vulnerable/parpadeando/otro) — necesitaría comparación más
  fina con MSX o un emulador.
- Identificar la rutina que usa `TABLA_RESOLVER_DIRECCION` con acceso
  `IX+2..+5` (candidata a IA de fantasma/actor).
- Encontrar el llamador real de la tabla de 11 `JP` en `$9198`.
- Confirmar si `CODE_9D25` es de verdad el bucle principal.
- Analizar `CODE_8A3F` (único candidato restante a
  `VACIAR_CANALES_SONIDO`) y `CODE_E1F9` (candidato generador de tono).
- Analizar `CODE_83A3` (candidato `MAPEAR_COORDENADA_A_DIRECCION`) y
  `CODE_87BC`.
- Investigar `$600E`/`$6018`/`$6027`/`$602A`/`$603E`/`CODE_6026`/`$9B83`
  — variables reales sin correspondencia MSX identificada todavía.

## Sesión 28 — 2026-08-09: `MOTOR_ACTORES` y `PTR_TABLA_SPRITES` localizados

Petición del usuario: continuar con la tarea recomendada al cierre de
la sesión anterior — localizar la tabla real de gráficos de sprites
que indexa `B` tras `SELECTOR_SPRITE_COMECOCOS`.

### `CODE_91D0` = `MOTOR_ACTORES` — confirmación muy fuerte

Trazando qué pasa con `B` (el índice de sprite) después de
`SELECTOR_SPRITE_COMECOCOS`, la pista llevó a `CODE_91D0` — que
resultó ser el motor de render de actores/personajes, con **las
mismas 4 constantes de guarda de entrada, en el mismo orden, que
`MOTOR_ACTORES` en MSX**: `$91C9` (candidato al contador de actores
activos, equivalente al `$8437` de MSX) contra **10** (máximo de
actores simultáneos), `B` contra **64** (límite de índice de sprite),
`E` contra **4** y **116** (filtro de coordenadas). Cuatro números
exactos coincidiendo en el mismo orden — la misma clase de evidencia
que ya confirmó `CARGAR_NIVEL` en sesión 24. Renombrada con el mismo
nombre exacto que MSX.

Un poco más abajo, `MOTOR_ACTORES` calcula `IX = $9F9A +
$91C9×10` — el mismo patrón "base + contador×tamaño_de_registro" que
usa MSX para su array de actores activos (allí ×12, aquí ×10 —
registro más pequeño). `$9F9A` es candidato a `TABLA_ACTORES_ACTIVOS`.

### `PTR_TABLA_SPRITES` localizada en `$9E8E`

Y ahí mismo aparece la tabla que se buscaba: `HL = $9E8E + B×4`, leída
como `[puntero de 2 bytes, parámetro, parámetro]` — el puntero de 2
bytes es, casi con toda seguridad, la dirección real de los gráficos
del sprite `B`. Mismo nombre candidato que en MSX: `PTR_TABLA_SPRITES`.

Detalle curioso que en un primer momento pareció una contradicción:
el guarda de entrada permite `B` hasta 63 (64 entradas × 4 bytes = 256
bytes), pero la tabla real solo tiene sitio para **28 entradas** (112
bytes) antes de toparse EXACTO con la tabla de fuente de texto
(`$9EFE`, `ESCRIBIR_PATRON_VRAM`, sesión 23) — sin ningún hueco de por
medio (`$9E8E + 112 = $9EFE` exacto). Conclusión: el límite de 64 del
guarda parece heredado sin ajustar del original MSX (que sí tiene 64
sprites reales); esta versión Spectrum solo llena 28 entradas, y
nunca se ha visto ningún caso que use un índice mayor — no es un bug
observable en la práctica, solo una asimetría entre el guarda y el
contenido real.

No se ha reconvertido todavía la tabla de 112 bytes a `DB` con
etiquetas — el desensamblado mecánico de esa zona genera una maraña
de referencias `JR` autoreferenciadas (típico de datos malinterpretados
como código, ver sesión 25/27) que conviene verificar con calma en su
propia sesión, en vez de apresurarlo.

**Verificado**: recompilado y reempaquetado tras el renombrado —
**0 diferencias, 48485 bytes idénticos al `.tzx` original**.
Inventario regenerado: 1098 etiquetas (sin cambio en el total, es un
renombrado puro).

### Pendiente para próximas sesiones

- **Reconvertir `PTR_TABLA_SPRITES`** (`$9E8E`, 112 bytes = 28
  entradas × 4 bytes) a `DB`/`DW` con etiquetas reales, con cuidado
  por la maraña de `JR` autoreferenciados del desensamblado mecánico.
- Confirmar `$91C9` (`CONTADOR_ACTORES_ACTIVOS`) y `$9F9A`
  (`TABLA_ACTORES_ACTIVOS`) con más detalle.
- Confirmar con qué exactamente se corresponden los 4 estados de
  `TABLA_PUNTEROS_ANIMACION_COMECOCOS`.
- Identificar la rutina que usa `TABLA_RESOLVER_DIRECCION` con acceso
  `IX+2..+5` (candidata a IA de fantasma/actor).
- Encontrar el llamador real de la tabla de 11 `JP` en `$9198`.
- Confirmar si `CODE_9D25` es de verdad el bucle principal.
- Analizar `CODE_8A3F` (único candidato restante a
  `VACIAR_CANALES_SONIDO`) y `CODE_E1F9` (candidato generador de tono).
- Analizar `CODE_83A3` (candidato `MAPEAR_COORDENADA_A_DIRECCION`) y
  `CODE_87BC`.
- Investigar `$600E`/`$6018`/`$6027`/`$602A`/`$603E`/`CODE_6026`/`$9B83`
  — variables reales sin correspondencia MSX identificada todavía.

## Sesión 29 — 2026-08-09: aclaración metodológica — Spectrum es el ORIGINAL, MSX es el port

Aclaración importante del usuario, a tener en cuenta en todas las
comparaciones y deducciones futuras: **esta versión de Spectrum es la
ORIGINAL** de *Mad Mix Game*; **la versión de MSX es un port hecho a
partir de esta**, no al revés.

Esto no cambia ningún hallazgo técnico ya confirmado (las
correspondencias byte a byte, nombres compartidos, etc. siguen siendo
válidas exactamente igual), pero sí cambia **cómo se debe redactar**
la comparación cuando dos mecanismos difieren: hay que describir la
versión MSX como la que tuvo que ADAPTARSE al hardware MSX (VDP en
vez de la ULA, PSG en vez del altavoz, modo de interrupción 1 en vez
de modo 2...), no la versión Spectrum como la que "se aparta" de MSX.

Encaja además de forma muy limpia con un hallazgo ya documentado en
sesión 24: `CARGAR_NIVEL` (Spectrum) usa la dirección `$FC60`, la
MISMA que la **v1.0 original** del port a MSX antes de su parche v2.0
(que la movió a `$FC50` para arreglar el bug del contador de bolitas
del nivel 13). Con esta aclaración, ese hallazgo cobra más sentido
todavía: la v1.0 de MSX fue un port temprano y fiel de este original
de Spectrum, que conservó la dirección tal cual.

**Cambios realizados**: añadida una nota explícita en
`src/README.md` (sección "Convenciones") estableciendo la dirección
del port para futuras sesiones. Corregidos los comentarios más
directamente mal orientados en `madmix_body.asm` (cabecera de
`INICIO`) y `portada_body.asm` (cabecera de `ANIMAR_COLOR_TOPO`), que
describían a MSX como el mecanismo "de referencia" del que Spectrum
se apartaba. **No se ha hecho un barrido exhaustivo** de las 28
sesiones anteriores — sus hallazgos técnicos siguen siendo válidos,
solo pueden tener alguna frase con la direccionalidad narrativa
invertida; se irán corrigiendo de paso si se vuelve a tocar esa zona
del código. Guardada también como memoria persistente del proyecto
para que futuras sesiones (incluso en conversaciones nuevas) partan
ya con este contexto correcto.

**Verificado**: recompilado tras los cambios de comentarios —
**0 diferencias, 48485 bytes idénticos al `.tzx` original** (cambio
de solo comentarios, sin efecto en el binario).

### Pendiente para próximas sesiones

- Seguir la lista de la sesión 28 (tabla de sprites, `MOTOR_ACTORES`,
  tabla de 11 `JP`, `CODE_9D25`, `CODE_8A3F`/`CODE_E1F9`, etc.).
- De paso, revisar y corregir la direccionalidad narrativa
  (MSX-como-adaptación, no Spectrum-como-desviación) en comentarios
  antiguos que se vuelvan a tocar.

## Sesión 30 — 2026-08-09: `PTR_TABLA_SPRITES` reconvertida, gráficos extraídos, visor HTML

Petición del usuario: continuar indagando sobre `PTR_TABLA_SPRITES`
para localizar la zona real de los sprites, extraer los ficheros y
generar el HTML de sprites, igual que en MSX.

### Extracción de los 28 sprites (144 bytes cada uno)

Localizado el bloque de gráficos: 28 punteros exactamente múltiplos
de 144 bytes, sin ningún hueco entre ellos, desde `$A1DE` hasta
`$B19D` (la 28ª entrada). Extraídos directamente de `src/build/CODE.bin`
con un script Python a `src/data/img/sprites/sprite_00.img` .. `sprite_27.img`
(144 bytes cada uno).

**Formato de píxel confirmado visualmente**: renderizando varias
entradas (0, 7, 13, 20, 27) como ASCII-art se probaron los dos formatos
candidatos — 3 bytes/fila × 48 filas (el de MSX) dio un patrón de rayas
rotas sin sentido; **6 bytes/fila × 24 filas (48×24 px)** dio siluetas
limpias y reconocibles (personajes tipo fantasma/comecocos). Confirmado:
el formato de píxel de Spectrum es distinto al de MSX (48×24 frente a
24×48) pese a compartir los mismos 144 bytes/sprite — mismo total de
1152 bits, reagrupados con ancho/alto distintos (dos filas de 24 px de
MSX equivalen a una fila de 48 px de Spectrum).

### Hallazgo cruzado: los bytes son IDÉNTICOS a los de MSX

Comprobación programática (no a ojo): los 4032 bytes de las 28
entradas de Spectrum son **exactamente iguales, byte a byte**, a los
primeros 4032 bytes de la tabla de 64 sprites de MSX
(`MSX/proyectos/madmixgame/recursos/ptrtable_sprites.html`). Esto
encaja perfectamente con [[madmix-spectrum-is-original]]: MSX
reutilizó literalmente estos gráficos originales de Spectrum sin tocar
un bit, solo reinterpretando el ancho/alto para su VDP, y añadió 36
entradas propias más (hasta llegar a 64) que no existen aquí. Gracias
a esta coincidencia, se han usado como candidatos muy sólidos (pendiente
de confirmación visual final por el usuario sobre la propia página) los
mismos 28 primeros nombres que el jugador original identificó a simple
vista en el proyecto MSX (comecocos vulnerable/invencible/avión/obra/
hipopótamo/tanque, fantasma, una entrada sin identificar).

### Reconversión a `DW`/`INCBIN` y error propio corregido en la misma sesión

Sustituidas ~4134 líneas de desensamblado mecánico (`$9E8E`-`$B19D`)
por `PTR_TABLA_SPRITES:` (28 entradas `DW SPRITE_XX` / `DB p1,p2`) +
28 bloques `SPRITE_XX: INCBIN "data/img/sprites/sprite_XX.img"`.

Al hacerlo se cometió y se detectó un error propio: se asumió que
`$9E8E`→`$B19D` era un bloque contiguo, cuando en realidad hay un
hueco real de 736 bytes (`$9EFE`-`$A1DE`) que contiene `TABLA_FUENTE`
(la fuente de texto de `ESCRIBIR_PATRON_VRAM`, ya conocida desde la
sesión 23) más datos aún sin identificar. La primera compilación dio
decenas de errores `[JR] Target out of range` — diagnóstico correcto:
desajuste de bytes por el hueco borrado por error. Corregido extrayendo
esos 736 bytes del `FISICO/CODE.bin` verificado (no del `src/build/CODE.bin`,
que estaba en estado roto) a `src/data/img/texto/tabla_fuente.img`, e
insertando `TABLA_FUENTE: INCBIN "..."` en su sitio correcto, con
comentario explícito documentando el error y la corrección.

Tras el arreglo del hueco desaparecieron los errores `[JR]`, pero
aparecieron 15 errores nuevos `Label not found` — etiquetas `CODE_XXXX`
que existían como artefacto del desensamblado mecánico dentro de las
zonas ahora convertidas a `INCBIN`, pero referenciadas por nombre desde
otro código mecánico sin analizar en otras partes del fichero (mismo
fenómeno que `RUIDO_ALTAVOZ_HUERFANO`/`LDI_EXTRA_HUERFANOS` de sesiones
anteriores). Resueltas con constantes `EQU` (no ocupan bytes, no
afectan al binario) usando la dirección codificada en el propio nombre
de cada etiqueta: `CODE_9E90`, `CODE_9E9B`, `CODE_9E9D`, `CODE_9E9F`,
`CODE_9EA1`, `CODE_9ED0` (dentro del hueco de `TABLA_FUENTE`) y
`CODE_A101`, `CODE_AAAA`, `CODE_ACBC`, `CODE_ACBE`, `CODE_ADBF`,
`CODE_ADEA`, `CODE_AE34`, `CODE_AF03`, `CODE_AF5E` (dentro de la zona
de sprites).

### Visor HTML

Creado `recursos/sprites.html`, modelado sobre el `ptrtable_sprites.html`
de MSX pero adaptado al formato real de Spectrum (`SPRITE_W=48`,
`SPRITE_H=24`, reagrupando 6 bytes/fila) y a las 28 entradas: vista en
tira, rejilla con nombres candidatos, y selector individual con zoom.
Incluye nota explicando el hallazgo cruzado con MSX y el hueco de
`TABLA_FUENTE`.

**Verificado**: recompilado tras todos los cambios —
**0 diferencias, 48485 bytes idénticos al `.tzx` original**. Inventario
regenerado: 941 etiquetas (función=81, interna=778, dato=68, sinref=14).

### Pendiente para próximas sesiones

- Confirmar a simple vista con el usuario los nombres candidatos de
  las 28 entradas en `recursos/sprites.html` (heredados de MSX por
  coincidencia byte a byte).
- Identificar el resto de `TABLA_FUENTE` (736 bytes es más de lo que
  ocuparía solo la fuente de texto — hay datos sin identificar a
  continuación de la fuente, sin dividir todavía).
- Seguir la lista de la sesión 28 (tabla de 11 `JP` en `$9198`,
  `CODE_9D25`, `CODE_8A3F`/`CODE_E1F9`, `CODE_83A3`/`CODE_87BC`,
  `TABLA_RESOLVER_DIRECCION`, variables sin identificar
  `$600E`/`$6018`/`$6027`/`$602A`/`$603E`/`CODE_6026`/`$9B83`).

## Sesión 31 — 2026-08-10: corrección importante de la sesión 30 — 64 sprites, no 28, y formato de píxel real (AND-mask + OR-pattern)

Petición del usuario: al mirar `recursos/sprites.html`, observó dos
cosas raras: (1) cada sprite se veía como dos imágenes iguales pero
con los colores invertidos, y (2) en Spectrum solo se habían
identificado 27-28 entradas frente a las 62-64 de MSX — preguntó si
sería posible que, siguiendo la lectura, se llegara también a 62-64
en Spectrum. **Las dos cosas eran síntoma del mismo error de la
sesión 30**, confirmado y corregido en esta sesión.

### Hallazgo 1: el formato de píxel no era 48×24 — son dos planos de 24×24 (AND-mask + OR-pattern)

Renderizando en PNG de verdad (no solo ASCII-art como en sesión 30) se
veía con total claridad lo que el usuario describió: cada sprite
"duplicado" con colores invertidos. Se comprobó programáticamente
sobre los 28 sprites de la sesión 30 clasificando cada par de bits
(mitad izquierda, mitad derecha) en sus 4 combinaciones posibles: la
combinación (izq=0, der=1) prácticamente no aparece nunca (0-1 bit de
576 por sprite), exactamente lo que exige la técnica clásica de
**sprite enmascarado por AND/OR** en Z80: un plano AND-mask (bit=1
preserva el fondo, transparente) y un plano OR-pattern (bit=1 fuerza
tinta), donde la combinación "borra Y dibuja a la vez" no tiene
sentido y por eso casi no aparece. Los dos planos van **entrelazados
fila a fila** (cada fila de 6 bytes = 3 bytes AND + 3 bytes OR), no
como dos mitades separadas de 72 bytes — este detalle se corrigió dos
veces en esta misma sesión (primer intento de recomposición asumió
bloques contiguos de 72+72 y salió una imagen a rayas rota; el
renderizado fila a fila dio la cara limpia). Cada sprite real mide
**24×24 píxeles**, no 48×24 como se pensó en sesión 30 — el total de
144 bytes por sprite no cambia, solo la interpretación correcta.

### Hallazgo 2: la tabla tiene 64 entradas, no 28 — el mismo número que MSX

La sesión 30 asumió que `PTR_TABLA_SPRITES` terminaba en la entrada 27
porque justo ahí (`$9EFE`) empezaba, supuestamente, `TABLA_FUENTE`
(la tabla de fuente de texto identificada en sesión 23). Leyendo los
bytes crudos de `FISICO/CODE.bin` más allá de la entrada 27 sin ese
supuesto de por medio, las siguientes 36 entradas (28-63) tienen
**exactamente el mismo patrón estructural** que las primeras 28:
puntero que avanza +144 bytes exactos cada vez, byte 4 siempre 24 —
hasta la entrada 63 inclusive, donde el patrón termina con un
centinela de 12 bytes `$FF` que enlaza, sin ningún hueco, con
`TABLA_ACTORES_ACTIVOS` (`$9F9A`, ya candidata desde sesión 28: 100
bytes a cero en el volcado de reposo, 10 actores × 10 bytes,
terminando exacto en `$9FFE`). Treinta y seis saltos consecutivos de
+144 exactos no pueden ser casualidad — es la confirmación de que la
tabla tiene **64 entradas reales**, el mismo número que predecía el
guarda de `MOTOR_ACTORES` desde sesión 28 (`E` contra `$40`) y el
mismo número que MSX.

### Por qué `TABLA_FUENTE` parecía empezar en `$9EFE`: no era mentira, pero tampoco era el sitio correcto

`ESCRIBIR_PATRON_VRAM` (sesión 23) sí hace, de verdad, `LD DE,$9EFE`
seguido de `+A*8` (confirmado con los bytes crudos del `.lst`, no una
suposición). Pero `$9EFE` es solo la **base aritmética** de esa
fórmula, no el punto donde empiezan los glifos reales. `DIBUJAR_TEXTO_VRAM`
solo trata como carácter los bytes `>=$20`, así que los primeros 32
"caracteres" (códigos 0-31, que caerían en offsets `$9EFE`-`$9FFD`)
nunca se leen en la práctica — y ese es precisamente el rango que
ocupan las 36 entradas nuevas de `PTR_TABLA_SPRITES` más
`TABLA_ACTORES_ACTIVOS`. La fuente real (los bytes que el juego sí
lee) empieza en `$9FFE` y ocupa 480 bytes (60 caracteres × 8 bytes),
terminando justo en `$A1DD`, un byte antes del primer sprite.
Confirmado visualmente: renderizados como bitmaps de 8×8, se ven con
claridad símbolos de puntuación, los dígitos 0-9 y letras A-F en fila.
Añadida la constante `TABLA_FUENTE_BASE EQU TABLA_FUENTE - $100` para
que `ESCRIBIR_PATRON_VRAM` siga generando el mismo operando literal
original (`$9EFE`) sin renombrar la etiqueta real de la fuente.

### Reconstrucción completa

Extraídos de nuevo desde `FISICO/CODE.bin` (fuente de verdad, no el
`src/build/CODE.bin` de la sesión 30 que arrastraba el error): las 64
entradas de `PTR_TABLA_SPRITES`, el centinela de 12 bytes `$FF`,
`TABLA_ACTORES_ACTIVOS` (100 bytes cero) y `TABLA_FUENTE` (480 bytes,
reemplazando el bloque de 736 bytes equivocado de la sesión 30) y los
64 sprites completos (antes solo 28). Sustituido el bloque completo de
`madmix_body.asm` desde `PTR_TABLA_SPRITES` hasta el final del sprite
63 (antes solo llegaba hasta el sprite 27 y el resto seguía siendo
desensamblado mecánico sin analizar) por la estructura corregida.
Resueltas con `EQU` 4 etiquetas huérfanas adicionales (`CODE_B630`,
`CODE_BD8A`, `CODE_BDA7`, `CODE_BF01`) referenciadas desde fuera del
bloque, mismo mecanismo que las 15 de sesión 30.

Recompilado `recursos/sprites.html` con las 64 entradas y el
renderizado correcto (combinando AND-mask + OR-pattern; blanco=tinta,
gris=transparente, negro=papel forzado), con opción de ver cada plano
por separado. Las primeras 28 entradas conservan los nombres
candidatos heredados de MSX (sesión 30); las 36 nuevas (28-63)
aparecen sin identificar todavía — no se han comparado byte a byte con
la tabla de MSX en esta sesión.

**Verificado**: recompilado tras la reconstrucción completa —
**0 diferencias, 48485 bytes idénticos al `.tzx` original**. Inventario
regenerado: 852 etiquetas (función=81, interna=644, dato=105,
sinref=22 — bajan las internas y suben los datos porque gran parte de
lo que antes eran cientos de líneas de código mecánico falso ahora son
bloques `DB`/`DW`/`INCBIN` de datos reales).

### Pendiente para próximas sesiones

- Averiguar el significado exacto del centinela de 12 bytes `$FF`
  entre `PTR_TABLA_SPRITES` y `TABLA_ACTORES_ACTIVOS`.
- Seguir la lista de la sesión 28 (tabla de 11 `JP` en `$9198`,
  `CODE_9D25`, `CODE_8A3F`/`CODE_E1F9`, `CODE_83A3`/`CODE_87BC`,
  `TABLA_RESOLVER_DIRECCION`, variables sin identificar
  `$600E`/`$6018`/`$6027`/`$602A`/`$603E`/`CODE_6026`/`$9B83`).

## Sesión 32 — 2026-08-10: las 64 entradas confirmadas por el usuario, mismo nombre y fichero que MSX

Petición del usuario: confirmó que las 36 entradas nuevas (28-63)
descubiertas en sesión 31 están **en el mismo orden** que la tabla de
64 sprites de MSX, y pidió renombrar los ficheros de sprite como en
MSX — misma extensión y mismo nombre.

### Renombrado completo a la convención de MSX

Con las 64 entradas ya confirmadas (28 por coincidencia byte a byte,
sesión 30/31; las 36 restantes por identificación visual directa del
usuario, jugador original del juego), se adoptó integramente la
convención de nombres de MSX (`src/madmix1_body.asm`,
`src/data/sprites/*.spr`):

- Ficheros: `src/data/img/sprites/sprite_NN.img` →
  `src/data/img/sprites/NN_nombre.spr` (64 renombrados, mismo
  directorio del proyecto Spectrum — `data/img/` — pero extensión y
  nombre exactos de MSX).
- Etiquetas: `SPRITE_NN` → `SPRNN_NOMBRE` (p. ej. `SPRITE_00` →
  `SPR00_PM_VULN_DER_CERRADA`), con el comentario de dirección +
  descripción tomado literalmente de MSX.
- `PTR_TABLA_SPRITES` y todos los `INCBIN` actualizados a los nuevos
  nombres.

Actualizado también `recursos/sprites.html`: las 64 entradas muestran
ya su nombre real (antes las 36 nuevas aparecían "sin identificar").

**Verificado**: recompilado tras el renombrado completo —
**0 diferencias, 48485 bytes idénticos al `.tzx` original** (cambio
puramente de nombres, sin efecto en el binario). Inventario sin
cambios de contenido (852 etiquetas, mismos renombrados que sesión 31).

### Pendiente para próximas sesiones

- Averiguar el significado exacto del centinela de 12 bytes `$FF`
  entre `PTR_TABLA_SPRITES` y `TABLA_ACTORES_ACTIVOS`.
- Seguir la lista de la sesión 28 (tabla de 11 `JP` en `$9198`,
  `CODE_9D25`, `CODE_8A3F`/`CODE_E1F9`, `CODE_83A3`/`CODE_87BC`,
  `TABLA_RESOLVER_DIRECCION`, variables sin identificar
  `$600E`/`$6018`/`$6027`/`$602A`/`$603E`/`CODE_6026`/`$9B83`).

## Sesión 33 — 2026-08-10: `recursos/mapa_memoria.html` puesto al día

Petición del usuario: actualizar `mapa_memoria.html` con todo lo
averiguado en las sesiones 22-32, y mantenerlo al día en adelante
cuando proceda.

Sustituido el único bloque `0x6000-0xEFB6: CODE.bin (mecánico)` por
17 sub-segmentos, usando las direcciones reales verificadas en
`src/build/main.lst`: `MOTOR_INICIO`, zona de variables de partida,
tablas de animación del comecocos (nueva categoría **datos**, para
tablas estáticas de índices/punteros que no son ni código ni píxeles
ni variables mutables), `CARGAR_NIVEL`, motor de texto/HUD,
`MOTOR_ACTORES`, interrupción modo 2 + ISR, `LEER_ENTRADA`, `INICIO`,
`PTR_TABLA_SPRITES` + centinela, `TABLA_ACTORES_ACTIVOS`,
`TABLA_FUENTE` y los 64 sprites — dejando 3 tramos grandes (22263
bytes en total) todavía como mecánico sin analizar. Verificados por
script que los 17 sub-segmentos son exactamente contiguos y suman los
36790 bytes de `CODE.bin`, sin huecos ni solapes. Actualizada también
la nota introductoria del documento (ya no dice "recién empezado").

No requiere recompilación (documento HTML puramente informativo, sin
efecto en el binario).

### Pendiente para próximas sesiones

- Mantener `mapa_memoria.html` al día en cada sesión que identifique
  o corrija una zona de memoria (petición explícita del usuario).
- Seguir la lista de la sesión 28 (tabla de 11 `JP` en `$9198`,
  `CODE_9D25`, `CODE_8A3F`/`CODE_E1F9`, `CODE_83A3`/`CODE_87BC`,
  `TABLA_RESOLVER_DIRECCION`, variables sin identificar
  `$600E`/`$6018`/`$6027`/`$602A`/`$603E`/`CODE_6026`/`$9B83`).

## Sesión 34 — 2026-08-10: `TABLA_SALTOS_MOTOR` ($9198) resuelta y `BUCLE_PRINCIPAL_JUEGO` confirmado

Petición del usuario: continuar con "confirmar si `CODE_9D25` es de
verdad el bucle principal" + "encontrar el llamador real de la tabla
de 11 `JP` en `$9198`" (pendientes de sesión 28).

### `CODE_9D25` = `BUCLE_PRINCIPAL_JUEGO` — confirmado

Ya existía en el propio código un `JP CODE_9D25` (auto-reentrada
cíclica) que la sesión 26 había dejado como "falta verificar". Leyendo
el cuerpo completo se confirma una estructura prácticamente idéntica,
instrucción a instrucción, a `BUCLE_PRINCIPAL_JUEGO` de MSX (`$9078`):
lee entrada + espera VBLANK, gestiona el temporizador de
`MODO_ESPECIAL_ACTIVO` (mismo patrón `AND A`/`JR Z` + `DEC`/`JR NZ`),
alinea la posición del comecocos a múltiplo de 4 (`AND $FC`), resta
una vida y game-over si no quedan. Diferencia interesante: Spectrum
resta la vida con `ADD A,(HL)` usando un delta variable en `$6003` en
vez del `SUB $01` de operando fijo que usa MSX — logra el mismo
resultado (con el acarreo invertido: `ADD` desborda cuando SI quedan
vidas) y es candidato a ser el mecanismo Spectrum equivalente al
truco de "vidas infinitas" parcheable que ya se documentó en MSX
(alli parcheando el operando de `SUB`; aquí bastaría con poner `$6003`
a 0). Dentro del bucle se identifican y renombran también
`VERIFICAR_FIN_NIVEL` (antes `CODE_9D8B`: compara `CONTADOR_BOLAS_COMIDAS`
contra el objetivo en `$6019`, tope `CP $10`=16 igual que MSX) y
`VERIFICAR_ENTRADA` (antes `CODE_9DB8`: sondea `BIT 5,A`, mismo bit de
pausa que MSX) — mismos nombres EXACTOS que MSX en los tres casos.

### `TABLA_SALTOS_MOTOR` ($9198, 11 entradas) — resuelta por completo

Localizada la tabla en el código actual (`JP MOTOR_ACTORES` en
`$9198` seguido de 10 `JP` más). Búsqueda exhaustiva de la dirección
`$9198` y de cada una de sus 11 direcciones de entrada en todo el
proyecto: **cero referencias** fuera de la tabla misma. Respuesta a
la pregunta pendiente: **no tiene llamador real** — es el antepasado
directo de la tabla `JT_*` de MSX (`$8400`-`$8430`, 12 entradas:
`JT_INICIO` + estas mismas 11 en el MISMO orden). MSX ya había
confirmado en su día, por búsqueda igual de exhaustiva, que solo
`JT_INICIO` tiene llamadores reales externos (los cargadores de
disco) y que las otras 11 entradas nunca las usa nadie porque cada
sitio del motor llama a la etiqueta real directamente — aquí pasa
exactamente lo mismo, y aquí NI SIQUIERA hace falta la entrada
`JT_INICIO` porque `INICIO` ya tiene su propio punto de entrada
directo en `MOTOR_INICIO` ($6000). Consistente con
[[madmix-spectrum-is-original]]: MSX conservó integra esta tabla
vestigial al portar el motor, aunque nunca la necesitara tampoco.

Verificadas 8 de las 11 rutinas destino instrucción a instrucción
contra su equivalente MSX (varias con tamaño EXACTO idéntico, p. ej.
`GESTIONAR_SCROLL` 647 bytes en ambas versiones,
`MAPEAR_LOSETA_RELATIVA_A_ABSOLUTA` 36 bytes en ambas) y renombradas
con el mismo nombre EXACTO que MSX: `RESET_CONTADOR_ACTORES` (`XOR A`/
`LD ($91C9),A`/`RET` -- confirma `$91C9` como `CONTADOR_ACTORES_ACTIVOS`),
`DIBUJAR_MARCADOR_PUNTOS`, `GESTIONAR_SCROLL`,
`REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM`, `REDIBUJAR_LOSETA_BUFFER_VRAM`,
`MAPEAR_LOSETA_RELATIVA_A_ABSOLUTA`, `CONSULTAR_TIPO_LOSETA` (usa
`$9B85`, candidato `TABLA_TIPOS_LOSETA`). De paso confirma `$6016`
como candidato a `REGISTRO_NIVEL_POSICION_COMECOCOS` (posición de
cámara/comecocos), leído por varias de estas rutinas igual que en MSX.
Añadidas las 11 etiquetas `JT_*` (mismos nombres que MSX) sobre cada
`JP` de la tabla.

**Verificado**: recompilado tras todos los renombrados —
**0 diferencias, 48485 bytes idénticos al `.tzx` original** (cambio
puramente de nombres/comentarios, sin efecto en el binario).
Inventario regenerado: 863 etiquetas (función=81, interna=644,
dato=105, sinref=33). Actualizado también `mapa_memoria.html`:
subdivididos los segmentos que contenían estas rutinas (el tramo
mecánico total baja de 22263 a 22207 bytes).

### Pendiente para próximas sesiones

- Analizar `CODE_8A3F` (único candidato restante a
  `VACIAR_CANALES_SONIDO`) y `CODE_E1F9` (candidato generador de
  tono/`DESTELLO_ICONO_COLOR_HUD`, llamado desde `BUCLE_PRINCIPAL_JUEGO`).
- Nombrar los helpers sin etiqueta propia todavía dentro de
  `BUCLE_PRINCIPAL_JUEGO` (`CODE_9DD1`, `CODE_9DE1`) y `CODE_9C07`/
  `CODE_9C21`/`CODE_9C93` (puntos de reentrada de `INICIO`).
- Averiguar el significado exacto del centinela de 12 bytes `$FF`
  entre `PTR_TABLA_SPRITES` y `TABLA_ACTORES_ACTIVOS`.
- Investigar `TABLA_RESOLVER_DIRECCION` con acceso `IX+2..+5`
  (candidata IA de fantasma/actor) y `CODE_83A3`/`CODE_87BC`.
- Variables sin identificar todavía:
  `$600E`/`$6018`/`$6027`/`$602A`/`$603E`/`CODE_6026`/`$9B83`.

## Sesión 35 — 2026-08-10: `TABLA_RESOLVER_DIRECCION` resuelta — IA de fantasmas (`HNDLR_PELMAZOIDE`)

Petición del usuario: continuar con la investigación de
`TABLA_RESOLVER_DIRECCION`, concretamente el segundo consumidor
pendiente desde sesión 27 (acceso vía `IX+2..+5`, candidato a IA de
fantasma/actor).

### `HNDLR_PELMAZOIDE` y `RESOLVER_DIRECCION_FANTASMA` — resueltos

Localizados los otros dos usos de `TABLA_RESOLVER_DIRECCION` (además
del ya conocido en `CODE_60CD`) dentro de una rutina completa de IA
de fantasma en `$81BC`, que a su vez se llama desde un gestor por
fotograma en `$8142`. Trazando ambos hacia atrás:

- **`HNDLR_PELMAZOIDE`** (antes `CODE_8142`, mismo nombre EXACTO que
  MSX): calcula primero la posición real del comecocos (`$6032` =
  `$6016`+16,+24, envuelta a módulo 128) y la guarda para que los
  fantasmas la persigan. Lee el contador de fantasmas activos en
  `$600F` (candidato a `REGISTRO_NIVEL_CONTADOR_PELMAZOIDES` de MSX) y
  recorre un array de registros de **7 bytes** en `$8060` — el MISMO
  tamaño de registro que `TABLA_ITEMS_PELMAZOIDE` en MSX — llamando a
  `RESOLVER_DIRECCION_FANTASMA` por cada fantasma y después a
  `MOTOR_ACTORES` para dibujarlo (bit 7 del índice de sprite como
  volteo horizontal, mismo convenio que el resto del motor).
  Confirmados **3 llamadores reales**: `CALL Z,HNDLR_PELMAZOIDE` justo
  después de `GESTIONAR_SCROLL` (comprobando antes `$9B84`/
  `FLAG_ENTRADA_BLOQUEADA`), seguido de otras dos llamadas candidatas a
  `HNDLR_MARICOCO` (`$83ED`) y `HNDLR_REGPUNANTOSO` (`$8504`) — el
  mismo patrón "scroll + 3 manejadores de item" que MSX.

- **`RESOLVER_DIRECCION_FANTASMA`** (antes `CODE_81BC`, nombre propio
  de Spectrum — MSX resuelve esta lógica inline sin subrutina
  separada): registro de actor en `IX` (7 bytes): `(IX+0)/(IX+1)` =
  posición, `(IX+2)` = flags/modo, `(IX+3)` = dirección resuelta
  (salida), `(IX+4)/(IX+5)` = sub-posición. Compara la posición del
  fantasma contra `$6032` — si `MODO_ESPECIAL_ACTIVO` está activo
  invierte el delta (`NEG`/`NEG`), es decir **el fantasma HUYE en vez
  de perseguir** durante el modo especial (bola de poder). Calcula una
  máscara de 4 bits de direcciones válidas/preferidas (usando un
  helper pequeño, `CODE_8358`, llamado 4 veces) y la resuelve a UNA
  dirección final 1-4 vía `TABLA_RESOLVER_DIRECCION` (dos accesos: uno
  para filtrar direcciones ya intentadas sin éxito, otro para elegir
  la definitiva) — **esto confirma por completo el segundo consumidor
  pendiente desde sesión 27**. Sin `RET` intermedio, continúa
  calculando la posición visible en pantalla del fantasma (candidato a
  la misma función que `CALCULAR_POSICION_VRAM_ITEM` de MSX, "comprueba
  visibilidad y calcula posición VRAM", compartida allí por fantasma/
  mariquita/repugnante) — termina con `SCF`/`RET` (fantasma fuera del
  área visible, el bucle llamador lo salta sin dibujar) o `AND A`/`RET`
  (visible, con la posición calculada).

Actualizado el comentario de cabecera de `TABLA_RESOLVER_DIRECCION`
para reflejar el hallazgo completo.

**Verificado**: recompilado tras los renombrados —
**0 diferencias, 48485 bytes idénticos al `.tzx` original**. Inventario
sin cambios de contenido (863 etiquetas, mismos renombrados).
Actualizado `mapa_memoria.html`: subdividido el mayor tramo mecánico
sin analizar para dar hueco a `HNDLR_PELMAZOIDE`/
`RESOLVER_DIRECCION_FANTASMA` (el total mecánico baja de 22207 a
21673 bytes).

### Pendiente para próximas sesiones

- Identificar `HNDLR_MARICOCO` (candidato `$83ED`) y
  `HNDLR_REGPUNANTOSO` (candidato `$8504`), llamados justo después de
  `HNDLR_PELMAZOIDE` en el mismo patrón que MSX.
- Nombrar `CODE_8358` (helper de comprobación de bits de dirección,
  llamado 4 veces desde `RESOLVER_DIRECCION_FANTASMA`) y confirmar si
  `CODE_8355`/el tramo final de `RESOLVER_DIRECCION_FANTASMA` es en
  efecto `CALCULAR_POSICION_VRAM_ITEM`.
- Analizar `CODE_8A3F` (único candidato restante a
  `VACIAR_CANALES_SONIDO`) y `CODE_E1F9` (candidato generador de
  tono/`DESTELLO_ICONO_COLOR_HUD`, llamado desde `BUCLE_PRINCIPAL_JUEGO`).
- Nombrar los helpers sin etiqueta propia todavía dentro de
  `BUCLE_PRINCIPAL_JUEGO` (`CODE_9DD1`, `CODE_9DE1`) y `CODE_9C07`/
  `CODE_9C21`/`CODE_9C93` (puntos de reentrada de `INICIO`).
- Averiguar el significado exacto del centinela de 12 bytes `$FF`
  entre `PTR_TABLA_SPRITES` y `TABLA_ACTORES_ACTIVOS`.
- Variables sin identificar todavía:
  `$600E`/`$6018`/`$6027`/`$602A`/`$603E`/`CODE_6026`/`$9B83`.

## Sesión 36 — 2026-08-10: `TABLA_CLASE_ALINEAMIENTO` — adopción de nombres exactos de MSX tras confirmar coincidencia byte a byte

Petición del usuario: pregunta si `ANIMACION_COMECOCOS_n` tiene
analogía en MSX, y a raíz de la respuesta, instrucción explícita de
convención: **cuando una etiqueta de Spectrum coincida con una de
MSX, hay que llamarla igual que en MSX**, porque la ingeniería inversa
de MSX se completó primero (ya documentado en `src/README.md`
"Convenciones", pero reafirmado aquí como recordatorio de aplicación
activa).

### Coincidencia byte a byte confirmada

Comparando las 3 tablas del bloque `CODE_6063` con
`madmix_scr_body.asm` de MSX (0x2C38-0x2C9C): **los 96 bytes son
idénticos**, tabla por tabla:

- `TABLA_RESOLVER_DIRECCION` (16 B) = `TABLA_CLASE_ALINEAMIENTO` de
  MSX — bytes `0,1,2,1,3,1,2,3,4,1,2,1,3,1,2,1`, exactos.
- `TABLA_PUNTEROS_ANIMACION_COMECOCOS` (4 punteros) =
  `PUNTEROS_SUBTABLA_DIRECCION` de MSX — misma estructura y orden.
- `ANIMACION_COMECOCOS_0..3` (20 B cada una) =
  `SUBTABLA_DIRECCION_A..D` de MSX — las 4 idénticas byte a byte.

Mismo fenómeno que ya se vio con los gráficos de sprites en sesión 30:
MSX copió estos datos tal cual del original Spectrum.

### Renombrados a los nombres exactos de MSX

- `TABLA_RESOLVER_DIRECCION` → `TABLA_CLASE_ALINEAMIENTO`
- `TABLA_PUNTEROS_ANIMACION_COMECOCOS` → `PUNTEROS_SUBTABLA_DIRECCION`
- `ANIMACION_COMECOCOS_0..3` → `SUBTABLA_DIRECCION_A..D`

Revisando el consumidor de la tabla de punteros se encontró además
**otra coincidencia instrucción a instrucción completa**: el bucle en
`CODE_61C6` (índice rotativo en `$6028`, recorre la subtabla de 20
bytes, centinelas `$FF`/`$FE`) es idéntico, instrucción a instrucción,
a `BUCLE_SUBTABLA_DIRECCION` de MSX. Renombrados también:

- `CODE_61C6` → `BUCLE_SUBTABLA_DIRECCION`
- `CODE_61E3` → `GUARDAR_SELECTOR_SPRITE_COMECOCOS`
- `$6028` → `INDICE_SUBTABLA_DIRECCION` (nueva etiqueta, 1 byte;
  `$6029` queda sin identificar por separado)

### Corrección de una descripción incompleta (sesión 22)

Aprovechando el cruce con MSX, se revisó cómo se calcula `E` (el
índice que elige uno de los 4 bloques `SUBTABLA_DIRECCION_A..D`). La
sesión 22 documentó que salía "de `MODO_ESPECIAL_CUENTA_ATRAS`", pero
trazando el código real eso solo es cierto en la rama de modo especial
activo (`CODE_6164`, `E = MODO_ESPECIAL AND $07`). En el caso normal
(sin modo especial), `E` llega vía un salto indexado por **dirección**
(`JP (IX)`, con `IX` cargado de una tabla de 5 punteros en `$6266`,
todavía sin identificar) — mecanismo equivalente en espíritu a como
MSX calcula su propio `E` ("dirección final") en
`OBTENER_SUBTABLA_DIRECCION`. Corregido el comentario de cabecera para
reflejar ambas ramas correctamente.

**Verificado**: recompilado tras todos los renombrados —
**0 diferencias, 48485 bytes idénticos al `.tzx` original**. Inventario
regenerado: 864 etiquetas (función=81, interna=645, dato=105,
sinref=33). Actualizado `mapa_memoria.html` con los nuevos nombres.

### Pendiente para próximas sesiones (superseded, ver sesión 37)

## Sesión 37 — 2026-08-10: `MOTOR_MOVIMIENTO_COLISION` — coincidencia casi total con MSX, ~14 variables/rutinas confirmadas de golpe

Petición del usuario: continuar analizando `CODE_60CD` y comparar con
el proyecto de MSX, señalando que "el 80% es casi idéntico".

### Coincidencia confirmada

Comparando `CODE_60CD` con `MOTOR_MOVIMIENTO_COLISION` de MSX
(`madmix_scr_body.asm`) instrucción a instrucción: el preámbulo entero
es **prácticamente idéntico**, incluidos los saltos internos en el
mismo orden. Renombrado `CODE_60CD` → `MOTOR_MOVIMIENTO_COLISION`
(mismo nombre EXACTO que MSX), junto con todos sus bloques internos:
`SALTAR_A_LEER_ENTRADA`, `PROCESAR_DIRECCION`, `LIMPIAR_FLAG_DIRECCION`,
`COPIAR_FLAG_DIRECCION`, `CALCULAR_MASCARA_ALINEAMIENTO`,
`COMPROBAR_ALINEAMIENTO_Y`, `APLICAR_MASCARA_ALINEAMIENTO`,
`FIJAR_DIRECCION_FINAL`, `CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION`
(antes `CODE_628E`, también verificada instrucción a instrucción),
`CALCULAR_INDICE_TIPO_LOSETA`, `OBTENER_MANEJADOR_LOSETA`.

### ~14 variables confirmadas de golpe

El cruce confirmó, con el mismo nombre EXACTO que MSX:

- `DIRECCION_DE_MOVIMIENTO` (`$6024`)
- `INDICE_CICLO_NIVELES` (`$8F43` — cae dentro de la zona mecánica
  todavía sin reconstruir, resuelta con `EQU`)
- `DIRECCION_SIN_PROCESAR` (`$6029`)
- `POSICION_ACTUAL_CAMARA` (`$602A`, word) — **valor inicial `$1018`
  IDÉNTICO** al de MSX, otra confirmación byte a byte como las de
  sprites/tablas de animación
- `DIRECCION_FORZADA` (`$602D`)
- `TEMPORIZADOR_DIRECCION_FORZADA` (`$602E`) — patrón de cuenta atrás
  confirmado en código real (`CODE_665D`)
- `FLAG_DIRECCION_NUEVA` (`$602F`)
- `COPIA_FLAG_DIRECCION_NUEVA` (`$6030`)
- `LADO_APERTURA_TRAMPILLA` (`$6031`) — confirmado por el patrón real:
  se fija junto con `DIRECCION_FORZADA` al mismo valor (1 o 2) en
  varios sitios de `CODE_665D`
- `PUNTO_REFERENCIA_CAMARA` (`$6032`, word) — ya candidata desde
  sesión 35 (HNDLR_PELMAZOIDE), ahora con nombre MSX confirmado
- `CACHE_TIPO_LOSETA` (antes `CODE_6026`) y `CACHE_COLUMNA_LOSETA`
  (antes `$6027`) — confirmadas dentro de
  `CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION`, resolviendo dos de los
  bytes "sin correspondencia MSX" que quedaban pendientes desde
  sesión 25

### Corrección de una hipótesis propia (sesión 36)

La sesión 36 había etiquetado `$6266` como "candidata a tabla de 5
punteros para seleccionar `E` por dirección". Con el cruce completo se
confirma que es en realidad **`TABLA_MANEJADORES_LOSETA`** (mismo
nombre EXACTO que MSX): el despachador por TIPO DE LOSETA de
`MOTOR_MOVIMIENTO_COLISION` (20 entradas en MSX; en Spectrum sin
extraer/etiquetar todavía). El valor de `E` para
`PUNTEROS_SUBTABLA_DIRECCION` no sale de esa tabla directamente, sino
del manejador de loseta al que salta (`JP (IX)`) — corregido el
comentario correspondiente.

**Verificado**: recompilado tras todos los renombrados — hubo que
añadir una constante `EQU INDICE_CICLO_NIVELES = $8F43` (la dirección
cae dentro de la zona mecánica sin reconstruir) y corregir un error de
conteo de bytes propio (`DB` con 4 bytes para un hueco de 3) detectado
antes de compilar. **0 diferencias, 48485 bytes idénticos al `.tzx`
original**. Inventario regenerado: 874 etiquetas (función=81,
interna=653, dato=107, sinref=33). Actualizado `mapa_memoria.html`:
nuevo segmento para el preámbulo de `MOTOR_MOVIMIENTO_COLISION` (508
bytes), el total mecánico baja de 21673 a 21165 bytes.

### Pendiente para próximas sesiones

- Analizar el resto de `MOTOR_MOVIMIENTO_COLISION`: los manejadores
  individuales por tipo de loseta (`TABLA_MANEJADORES_LOSETA`, `$6266`,
  candidata a 20 entradas) — el mayor tramo mecánico que queda
  (7801 bytes, `$62C9`-`$8142`).
- Identificar `HNDLR_MARICOCO` (candidato `$83ED`) y
  `HNDLR_REGPUNANTOSO` (candidato `$8504`).
- Nombrar `CODE_8358` (helper de comprobación de bits de dirección,
  llamado 4 veces desde `RESOLVER_DIRECCION_FANTASMA`) y confirmar si
  `CODE_8355`/el tramo final de `RESOLVER_DIRECCION_FANTASMA` es en
  efecto `CALCULAR_POSICION_VRAM_ITEM`.
- Analizar `CODE_8A3F` (único candidato restante a
  `VACIAR_CANALES_SONIDO`) y `CODE_E1F9` (candidato generador de
  tono/`DESTELLO_ICONO_COLOR_HUD`, llamado desde `BUCLE_PRINCIPAL_JUEGO`).
- Nombrar los helpers sin etiqueta propia todavía dentro de
  `BUCLE_PRINCIPAL_JUEGO` (`CODE_9DD1`, `CODE_9DE1`) y `CODE_9C07`/
  `CODE_9C21`/`CODE_9C93` (puntos de reentrada de `INICIO`).
- Averiguar el significado exacto del centinela de 12 bytes `$FF`
  entre `PTR_TABLA_SPRITES` y `TABLA_ACTORES_ACTIVOS`.
- Variables sin identificar todavía:
  `$600E`/`$6018`/`$603E`/`$9B83`.

## Sesión 38 — 2026-08-10: `TABLA_MANEJADORES_LOSETA` resuelta — 17 manejadores de tipo de loseta localizados y nombrados

Petición del usuario: seguir con `MOTOR_MOVIMIENTO_COLISION`, en
concreto el mayor tramo mecánico que quedaba (los manejadores por tipo
de loseta despachados por `TABLA_MANEJADORES_LOSETA`, `$6266`).

### Extracción y coincidencia estructural completa

Extraídos los punteros crudos de `FISICO/CODE.bin` en `$6266`: 20
entradas válidas consecutivas, terminando EXACTO donde empieza
`CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION` (`$628E`), sin ningún
hueco — confirma sin ambigüedad que la tabla tiene 20 entradas, igual
que en MSX. Comparando el ORDEN exacto con la tabla de MSX
(`madmix_scr_body.asm`): **coincide entrada a entrada, incluido el
patrón de duplicados** (las entradas 8 y 9 repiten la 0; la 16 repite
la 15) — un patrón tan específico que es virtualmente imposible que
sea casualidad.

Verificadas además **instrucción a instrucción** las dos primeras
rutinas destino:

- `HNDLR_SUELO_NORMAL` (antes en `$62E1`): `CP $02 / JR NZ,.../LD C,$00
  / ... / CP $09 / JP Z,... / JP ...` — idéntica a MSX byte a byte en
  su estructura, incluidos los valores de comparación.
- `HNDLR_BOLA_PODER` (antes en `$6543`): arranca igual
  (`PUSH AF`/lógica de activación de modo especial).

Con esa doble confirmación (orden exacto + patrón de duplicados +
verificación instrucción a instrucción de 2 de las 20), se renombraron
las **17 rutinas destino únicas** con los mismos nombres EXACTOS que
MSX: `HNDLR_SUELO_NORMAL`, `HNDLR_BOLITA_NORMAL`,
`HNDLR_BOLITA_CLAVADA`, `HNDLR_AUTOCOCO_ARRIBA/ABAJO/IZQUIERDA/DERECHA`,
`HNDLR_PISTA_COCOTANQUE`, `HNDLR_PISTA_COCONAVE`, `HNDLR_ITEM_SUELO`,
`HNDLR_BOLA_PODER`, `HNDLR_HIPODOSO`, `HNDLR_EXCAVATOFONO`,
`HNDLR_SUELO_SIN_BOLA`, `HNDLR_TRAMPILLA_ABIERTA_DERECHA/IZQUIERDA`,
`HNDLR_TRAMPILLA_CERRADA`. De paso, siguiendo el rastro de
`HNDLR_SUELO_NORMAL`, se confirmaron también `CODE_6164` →
`TICK_MODO_ESPECIAL` y `CODE_64FE` → `MODO_ESPECIAL_EXIT_TAIL` (ambos
con el mismo nombre EXACTO que MSX).

### Reconstrucción de la tabla

Sustituidas las 37 líneas de desensamblado mecánico de
`TABLA_MANEJADORES_LOSETA` (los 40 bytes se leían como instrucciones
sin sentido) por un bloque real `DW` de 20 entradas con las etiquetas
nuevas. Insertadas las 17 etiquetas de entrada en su dirección exacta
dentro del código todavía mecánico (sin tocar ni reordenar ningún
byte). El cuerpo interno de cada manejador sigue siendo, por dentro,
reconstrucción mecánica de primera pasada sin analizar línea a línea
— solo se ha confirmado y nombrado el punto de entrada de cada uno.

**Verificado**: recompiló a la primera sin errores —
**0 diferencias, 48485 bytes idénticos al `.tzx` original**. Inventario
regenerado: 891 etiquetas (función=81, interna=670, dato=108,
sinref=32). Actualizado `mapa_memoria.html`: nuevo segmento para los 17
manejadores (7777 bytes), el total mecánico baja de 21165 a 13388
bytes.

### Pendiente para próximas sesiones

- Analizar línea a línea el cuerpo interno de los 17 manejadores
  (superado, ver sesión 39).

## Sesión 39 — 2026-08-10: los 17 manejadores de `TABLA_MANEJADORES_LOSETA` resueltos por completo

Petición del usuario: seguir con `MOTOR_MOVIMIENTO_COLISION` — el
cuerpo interno de los 17 manejadores localizados en sesión 38.

### Coincidencia casi total, manejador a manejador

Comparando cada uno de los 17 manejadores con su equivalente MSX
(`madmix_scr_body.asm`) instrucción a instrucción: **todos coinciden**,
con la misma estructura `PUSH AF / comprobación de modo especial /
comprobación de fase de movimiento / efecto / JP TICK_MODO_ESPECIAL`.
Renombradas con los mismos nombres EXACTOS que MSX ~30 etiquetas
internas (puntos de salida `_EXIT`, sub-bloques como
`HNDLR_PISTA_COCOTANQUE_ACTIVATE`/`_MODE_CHECK`/`_TAIL`,
`HNDLR_PISTA_COCONAVE_ACTIVATE`/`_LOOP`,
`HNDLR_SUELO_SIN_BOLA_PLANE_CHECK`/`_LOOP`,
`HNDLR_TRAMPILLA_CERRADA_B`) y varias subrutinas/tablas compartidas
que aparecían citadas desde dentro de los manejadores:

- `DIBUJAR_CAMBIO_LOSETA` (antes `CODE_62C9`) — sustituye el gráfico
  de una loseta, llamada por casi todos los manejadores.
- `REGISTRAR_PISTA_TANQUE_AVION` (antes `CODE_646C`, con
  `BUSCAR_HUECO_PISTA`/`FIJAR_PISTA`/`GUARDAR_PISTA` internos) —
  itera `TABLA_PISTA_TANQUE_AVION` (ya conocida desde sesión 22/23).
- `TEMPORIZADOR_DIRECCION_FORZADA_TICK` (antes `CODE_665D`, con
  `LIMPIAR_DIRECCION_FORZADA`/`FIN_TICK_DIRECCION_FORZADA`) — cola
  común de limpieza de `DIRECCION_FORZADA`/`LADO_APERTURA_TRAMPILLA`.
- `PREPARAR_SCROLL`/`PREPARAR_LLAMADA_SCROLL` (antes `CODE_61E6`/
  `CODE_61F0`) — dos puntos de reentrada al bucle de scroll+items
  compartido, ya visto parcialmente en sesión 36.
- `ACTUALIZAR_DESTELLO_ITEMS` (antes `CODE_86C6`) e
  `INICIALIZAR_PARCIAL_ITEMS_NIVEL` (antes `CODE_882F`, verificada
  instrucción a instrucción idéntica, incluidos los mismos valores
  `LD B,$03` / `LD HL,TABLA_PISTA_TANQUE_AVION`).

### Variables confirmadas de golpe

- `EVENTO_SONIDO_PENDIENTE` (`$8FD6`) — índice de efecto de sonido a
  disparar, escrito por casi todos los manejadores.
- `FLAG_ENTRADA_BLOQUEADA` (`$9B84`) — ya candidata desde sesión 26,
  confirmada y con etiqueta real (sustituye un `NOP` mecánico por un
  `DB $00`, mismo byte).
- `REGISTRO_NIVEL_ICONO_HUD` (`$6018`) y
  `REGISTRO_NIVEL_DURACION_PARPADEO` (`$6012`) — dos de las variables
  "sin correspondencia MSX" que quedaban pendientes desde sesión 22,
  resueltas dentro de la zona de variables ya convertida.
- `REGISTRO_NIVEL_POSICION_COMECOCOS` (`$6016`) — de propina: llevaba
  usándose como candidato desde sesión 34 pero nunca se le había
  puesto etiqueta real en la zona de variables; corregido ahora.
- `HNDLR_MARICOCO` (`$83ED`) y `HNDLR_REGPUNANTOSO` (`$8504`) —
  confirmadas (ya no candidatas) al aparecer citadas explícitamente en
  el código real de `HNDLR_PISTA_COCONAVE`/
  `HNDLR_SUELO_SIN_BOLA_PLANE_LOOP` de MSX. Caen dentro de zonas
  mecánicas todavía sin convertir, resueltas con `EQU`; sus propios
  cuerpos quedan pendientes de una sesión futura.

**Verificado**: recompiló a la primera tras todos los renombrados —
**0 diferencias, 48485 bytes idénticos al `.tzx` original**. Inventario
regenerado: 895 etiquetas (función=81, interna=673, dato=109,
sinref=32). Actualizado `mapa_memoria.html` con el detalle enriquecido
del tramo de manejadores (los límites de byte no cambian, ya estaban
bien puestos desde sesión 38).

### Pendiente para próximas sesiones

- Analizar los cuerpos de `HNDLR_MARICOCO`/`HNDLR_REGPUNANTOSO`
  (superado, ver sesión 40).

## Sesión 40 — 2026-08-10: `HNDLR_MARICOCO`/`HNDLR_REGPUNANTOSO` resueltos por completo — desensamblado manual byte a byte

Petición del usuario: continuar con `HNDLR_MARICOCO`/`HNDLR_REGPUNANTOSO`,
las dos últimas piezas grandes del subsistema de items móviles.

### Por qué hizo falta desensamblado manual

A diferencia de los 17 manejadores de `TABLA_MANEJADORES_LOSETA`
(sesión 39, cuyo cuerpo YA estaba parcialmente desensamblado
mecánicamente y solo hacía falta renombrar), `$83ED` y `$8504` caían
en mitad de instrucciones falsas del desensamblado mecánico original
(confirmado con `main.lst`: ninguna de las dos direcciones coincidía
con el arranque de una instrucción mecánica). Se extrajeron los bytes
crudos directamente de `FISICO/CODE.bin` y se desensamblaron a mano,
instrucción a instrucción, cruzando cada una con
`HNDLR_MARICOCO`/`HNDLR_REGPUNANTOSO` de MSX (`madmix_scr_body.asm`)
en tiempo real. Verificación de consistencia: **todos los saltos
internos convergen exactos en las mismas 2 direcciones de cola**
(`SIGUIENTE_MARICOCO`/`SIGUIENTE_REGPUNANTOSO`) — si el desalineamiento
de bytes hubiera sido incorrecto en algún punto, los cálculos de
destino de salto no habrían cuadrado. Reconstruido el bloque completo
`$83CB`-`$85AD` (482 bytes) como código y datos reales, con los mismos
nombres EXACTOS que MSX en todo: `TABLA_ANIMACION_MARICOCO`,
`TABLA_ITEMS_MARICOCO`, `HNDLR_MARICOCO`, `ESTADO_REGENERACION_MARICOCO`,
`VRAM_REGENERACION_MARICOCO`, `MAPEAR_COORDENADA_A_DIRECCION_LOCAL`,
`TABLA_ANIMACION_REGPUNANTOSO`, `TABLA_ITEMS_REGPUNANTOSO`,
`HNDLR_REGPUNANTOSO`, `ESTADO_PLANTADO_REGPUNANTOSO`,
`VRAM_PLANTADO_REGPUNANTOSO`.

### Corrección importante: `RESOLVER_DIRECCION_FANTASMA` → `MOTOR_MOVIMIENTO_ITEM`

Al decodificar `HNDLR_MARICOCO` apareció `CALL $81BC` — la MISMA
dirección que la sesión 35 había nombrado `RESOLVER_DIRECCION_FANTASMA`
asumiendo que era lógica propia del fantasma. MSX confirma que es
`MOTOR_MOVIMIENTO_ITEM`, una subrutina genérica compartida por los 3
manejadores de item (`HNDLR_PELMAZOIDE`, `HNDLR_MARICOCO`,
`HNDLR_REGPUNANTOSO`) — la sesión 35 solo había visto el primer
llamador y no comprobó los otros dos. Renombrado con el nombre EXACTO
de MSX y corregidos los comentarios de cabecera que asumían que era
"nombre propio de Spectrum".

### `MAPEAR_COORDENADA_A_DIRECCION_LOCAL` usa `$FC60`

Otra coincidencia con el patrón ya visto en `CARGAR_NIVEL` (sesión 24):
esta copia independiente de la fórmula de mapeo de coordenadas usa
`$FC60`, la MISMA dirección que la v1.0 original de MSX antes de su
parche v2.0 (que la movió a `$FC50` para el bug del contador de
bolitas del nivel 13) — más evidencia de que el original Spectrum es
la fuente de la que MSX v1.0 portó fielmente estas direcciones.

### Diferencia real con MSX: sin cola diferida de redibujado

Ambos manejadores llaman **directamente** a `REDIBUJAR_LOSETA_BUFFER_VRAM`
para redibujar la loseta regenerada/plantada, mientras que MSX usa
`APILAR_PETICION_REDIBUJADO` (una cola diferida) en este punto
concreto. Consistente con
[[madmix-spectrum-is-original]]: MSX añadió esa cola como adaptación
propia (probablemente por restricciones de temporización de su VDP);
el original Spectrum, con pantalla mapeada en memoria normal, no la
necesita y dibuja de inmediato.

### Otras variables/rutinas confirmadas de paso

- `$6010` = candidato `REGISTRO_NIVEL_CONTADOR_MARICOCOS`, `$6011` =
  candidato `REGISTRO_NIVEL_CONTADOR_REPUGNANTOSOS`.
- `ACTIVAR_EFECTO_ITEM` (`$871C`, candidata) y `CODE_84E0` (referencia
  huérfana desde otra parte del fichero hacia un byte dentro de
  `TABLA_ITEMS_REGPUNANTOSO`) — ambas caen en zona mecánica todavía
  sin reconstruir, resueltas con `EQU`.

**Verificado**: recompiló tras añadir 2 constantes `EQU` que faltaban
(`ACTIVAR_EFECTO_ITEM`, `CODE_84E0`) — **0 diferencias, 48485 bytes
idénticos al `.tzx` original**, confirmando que el desensamblado
manual fue exacto byte a byte. Inventario regenerado: 903 etiquetas
(función=81, interna=675, dato=115, sinref=32). Actualizado
`mapa_memoria.html`: nuevo segmento para el subsistema completo (482
bytes), el total mecánico baja de 13388 a 12906 bytes.

### Pendiente para próximas sesiones

- Nombrar `CODE_8358` (helper de comprobación de bits de dirección,
  llamado 4 veces desde `MOTOR_MOVIMIENTO_ITEM`) y confirmar si
  `CODE_8355`/el tramo final de `MOTOR_MOVIMIENTO_ITEM` es en
  efecto `CALCULAR_POSICION_VRAM_ITEM`.
- Analizar el cuerpo de `ACTIVAR_EFECTO_ITEM` (`$871C`).
- Analizar `CODE_8A3F` (único candidato restante a
  `VACIAR_CANALES_SONIDO`) y `CODE_E1F9` (candidato generador de
  tono/`DESTELLO_ICONO_COLOR_HUD`, llamado desde `BUCLE_PRINCIPAL_JUEGO`).
- Nombrar los helpers sin etiqueta propia todavía dentro de
  `BUCLE_PRINCIPAL_JUEGO` (`CODE_9DD1`, `CODE_9DE1`) y `CODE_9C07`/
  `CODE_9C21`/`CODE_9C93` (puntos de reentrada de `INICIO`).
- Averiguar el significado exacto del centinela de 12 bytes `$FF`
  entre `PTR_TABLA_SPRITES` y `TABLA_ACTORES_ACTIVOS`.
- Variables sin identificar todavía: `$600E`/`$603E`/`$9B83`.

## Sesión 41 — 2026-08-13: localizados los gráficos de las losetas del laberinto (`GRAFICOS_LOSETAS`, $C600)

Pregunta del usuario: "¿tenemos el/los punteros a las losetas?" —
`CARGAR_NIVEL` (sesión 24) y `CONSULTAR_TIPO_LOSETA` (sesión 34) ya
daban los ÍNDICES de loseta de cada celda del mapa y su tipo/colisión,
pero el banco de gráficos real (los píxeles de cada loseta) seguía sin
localizar — `graficos.html` lo tenía marcado como pendiente.

### Localización

`REDIBUJAR_LOSETA_BUFFER_VRAM` (`$99BD`, confirmada en sesión 34)
termina con la secuencia `AND $7F` / `LD L,$00` / tres rotaciones
`RRA`+`RR L` (equivalen a `x32`) / `LD H,A` / `LD BC,$C600` / `ADD
HL,BC`, seguida de un bucle `LD B,$10` con `LDI`/`LDI` por iteración
(16 filas x 2 bytes). Es decir: dirección = `$C600 +
índice_loseta*32`, volcando 32 bytes (16x16 px monocromo, 2
bytes/fila) al buffer de pantalla — mismo formato exacto que
`GRAFICOS_LOSETAS` de MSX. Renombrado el literal `$C600` a
`GRAFICOS_LOSETAS` en el único punto donde se usaba.

### Confirmación: idéntico byte a byte a MSX

Comparación directa (script Python) entre
`FISICO/CODE.bin[$C600:$C600+91*32]` y el array `GRAFICOS_LOSETAS` de
MSX extraído de `recursos/graficos.html` del proyecto hermano: **91
losetas, 2912 bytes, coincidencia exacta al 100%**. Confirmado también
visualmente (render a PNG): muros de hierro/cemento/ladrillo, suelo
con/sin bola, flechas direccionales, pistas de tanque/avión,
trampillas, items y decoración, todo reconocible y coincidente con el
catálogo de losetas ya identificado en MSX. Mismo fenómeno que
sprites (sesión 30), fuente y tablas de animación (sesión 36): MSX
reutilizó estos gráficos del Spectrum original sin tocar un bit —
consistente con [[madmix-spectrum-is-original]].

### Error propio durante la integración (autocorregido)

Al insertar el bloque `GRAFICOS_LOSETAS` en `madmix_body.asm` se usó
por error un límite final de reemplazo equivocado (`$D0A0` en vez de
`$D160`, la dirección real donde terminan los 2912 bytes), lo que
provocó una inserción neta de +192 bytes de más y rompió la
compilación (`[JR] Target out of range` en varios puntos del tramo
`$D160+`). Un primer intento de corrección (borrar 332 líneas
calculadas a ojo) también resultó incorrecto — quitó 408 bytes en vez
de 192, dejando el fichero 216 bytes corto. La corrección definitiva
abandonó el conteo manual de líneas: se volcó directamente desde
`FISICO/CODE.bin` el tramo completo `$D160`-`$EFB5` (7766 bytes, todo
lo que queda entre el final de `GRAFICOS_LOSETAS` y `MOTOR_FIN`) como
`DB` crudo, sustituyendo cualquier resto del desensamblado mecánico
de primera pasada que hubiera quedado desalineado por el error
anterior. Se comprobó antes (script de huérfanos) que solo había una
referencia externa a una etiqueta dentro de ese tramo —
`CODE_E1F9` (candidato generador de tono, ver sesión 40) — resuelta
con `EQU CODE_E1F9 $E1F9`, mismo patrón ya usado en sesiones previas.

**Verificado**: recompiló sin errores y **0 diferencias, 48485 bytes
idénticos al `.tzx` original**, restaurando la invariante tras el
error de empalme. Inventario regenerado: 746 etiquetas (función=79,
interna=516, dato=116, sinref=35) — baja respecto a las 903 de la
sesión 40 porque el volcado crudo de `$D160`-`$EFB5` ya no conserva
las etiquetas `CODE_XXXX` auto-generadas del desensamblado mecánico
de primera pasada (mismo efecto que tuvo el propio bloque
`GRAFICOS_LOSETAS`).

### Documentación actualizada

- `mapa_memoria.html`: el tramo `$C5DE`-`$EFB6` ("sin analizar, 10712
  B") se parte en tres: 34 B sin analizar (hueco previo), el nuevo
  segmento `GRAFICOS_LOSETAS` (`$C600`-`$D160`, categoría gráficos,
  2912 B) y 7766 B sin analizar restantes. Total mecánico baja de
  12906 a 9994 bytes, repartidos ahora en siete tramos.
- `graficos.html`: sustituida la sección "Losetas del laberinto —
  pendiente" por la galería real de las 91 losetas (canvas 16x16 por
  loseta), reutilizando el objeto `TILE_LABELS` de MSX tal cual (mismo
  orden, mismos nombres) ya que los datos son idénticos.

### Pendiente para próximas sesiones

- Localizar en este proyecto la tabla de tipo/colisión de loseta
  equivalente a `TILE_TYPES` de MSX (candidata: la tabla en `$9B85`
  que consulta `CONSULTAR_TIPO_LOSETA`, sesión 34) para poder anotar
  el "tipo" en `graficos.html` como hace el proyecto MSX.
- El resto de la lista de pendientes de la sesión 40 sigue abierta
  (`CODE_8358`, `ACTIVAR_EFECTO_ITEM`, `CODE_8A3F`/`CODE_E1F9`,
  `CODE_9DD1`/`CODE_9DE1`, centinela `$FF` de 12 bytes,
  `$600E`/`$603E`/`$9B83`), todos siguen dentro del tramo mecánico sin
  convertir (ahora `$D160`-`$EFB5`).

## Sesión 42 — 2026-08-13: `GRAFICOS_LOSETAS` extraída a 91 ficheros individuales (`data/img/tiles/*.til`)

Petición del usuario: sacar los gráficos de las losetas a ficheros
individuales, igual que se hizo en el proyecto MSX (`data/tiles/*.til`),
en vez de dejarlos embebidos como `DB` inline dentro de
`madmix_body.asm` (como quedaron en la sesión 41).

### Extracción

Los 91 gráficos (32 bytes cada uno) se extrajeron directamente de
`FISICO/CODE.bin` (`$C600`-`$D15F`) a `src/data/img/tiles/`, uno por
loseta, reutilizando **exactamente los mismos nombres de fichero** que
el proyecto MSX (`data/tiles/*.til` allí) — legítimo porque los 2912
bytes ya se habían confirmado idénticos byte a byte en la sesión 41,
así que el catálogo, el orden y las descripciones son el mismo. Mismo
patrón de directorio que ya usa este proyecto para los sprites
(`data/img/sprites/*.spr`) y la fuente (`data/img/texto/*.img`).

En `madmix_body.asm`, el bloque de 91 líneas `DB` bajo
`GRAFICOS_LOSETAS:` se sustituyó por 91 líneas `INCBIN
"data/img/tiles/NN_descripcion.til"  ; tile N`, mismo estilo que ya se
usaba para los 64 sprites.

**Verificado**: recompiló sin errores (log de compilación confirma los
91 `include data:` de 32 bytes cada uno) y **0 diferencias, 48485
bytes idénticos al `.tzx` original** — la extracción a fichero no
altera ni un bit del binario resultante, solo cambia dónde vive el
dato fuente. Inventario sin cambios (746 etiquetas), ya que
`GRAFICOS_LOSETAS` sigue siendo la misma etiqueta, solo cambió el
origen de sus bytes.

### Documentación actualizada

- `graficos.html`: nota y pie de página actualizados para señalar
  `data/img/tiles/*.til` como origen de los datos en vez de `CODE.bin`
  directamente.
- `mapa_memoria.html`: detalle del segmento `GRAFICOS_LOSETAS`
  actualizado para mencionar los ficheros individuales y el `INCBIN`.

### Pendiente para próximas sesiones

Sin cambios respecto a la sesión 41 — sigue pendiente la tabla de
tipo/colisión de loseta (candidata `$9B85`) y el resto de la lista
heredada de la sesión 40.

## Sesión 43 — 2026-08-13: 6 etiquetas internas de `TICK_MODO_ESPECIAL` renombradas con nombres EXACTOS de MSX

El usuario señaló `CODE_617F` (dentro del preámbulo de
`MOTOR_MOVIMIENTO_COLISION`, ya resuelto en sesión 37) preguntando por
dónde continuar. `TICK_MODO_ESPECIAL` ya tenía nombre propio, pero sus
6 etiquetas internas (destino de `JR`) seguían como `CODE_XXXX`
mecánicos: `CODE_617F`, `CODE_6184`, `CODE_618B`, `CODE_61A3`,
`CODE_61AB`, `CODE_61B8`.

Comparación instrucción a instrucción con el equivalente de MSX
(`madmix_scr_body.asm:530-589`, mismo bloque tras
`MOTOR_MOVIMIENTO_COLISION`) confirma coincidencia exacta y da los
nombres reales:

- `CODE_617F` → `PARPADEO_COLOR_BOLA_PODER`
- `CODE_6184` → `FIN_MODO_BOLA_PODER`
- `CODE_618B` → `TICK_MODO_HIPOPOTAMO`
- `CODE_61A3` → `PARPADEO_ICONO_HIPOPOTAMO`
- `CODE_61AB` → `FIN_MODO_HIPOPOTAMO`
- `CODE_61B8` → `OBTENER_SUBTABLA_DIRECCION` (cae directo en
  `BUCLE_SUBTABLA_DIRECCION`, ya nombrada en sesión 36)

### Diferencia real con MSX

`FIN_MODO_BOLA_PODER` en MSX hace `CALL VACIAR_CANALES_SONIDO` (vacía
el gestor de recursos de sonido) justo antes de apagar
`MODO_ESPECIAL_FLAG`/`MODO_ESPECIAL`. La versión Spectrum, en el mismo
punto, no tiene esa llamada — pasa directo al `XOR A`. Queda como pista
para cuando se analice el subsistema de sonido (`CODE_8A3F`, candidato
a `VACIAR_CANALES_SONIDO`, pendiente desde sesión 40): o bien Spectrum
gestiona el silencio de otra forma (p. ej. dentro del propio
manejador de interrupción), o bien esta llamada nunca existió en el
original y MSX la añadió al adaptar su propio gestor de canales PSG.

**Verificado**: recompiló sin errores y **0 diferencias, 48485 bytes
idénticos al `.tzx` original**. Inventario sin cambios (746 etiquetas
— renombrar no cambia el total). Actualizado `mapa_memoria.html`
(detalle del segmento `MOTOR_MOVIMIENTO_COLISION`).

### Pendiente para próximas sesiones

Sin cambios de fondo respecto a sesión 41/42. Se añade una pista nueva:
confirmar si `CODE_8A3F` se llama desde algún punto equivalente a
`FIN_MODO_BOLA_PODER` una vez se analice esa zona.

**Nota del usuario sobre la diferencia de sonido**: confirmado que es
normal — Spectrum (altavoz/beeper) y MSX (PSG AY-3-8910) usan chips de
sonido distintos, así que sus drivers de sonido son necesariamente
distintos. Las diferencias en esa área no son señal de error de
transcripción, son adaptación de hardware esperada.

## Sesión 44 — 2026-08-13: `TABLA_TIPOS_LOSETA` resuelta por completo ($9B85)

Continuación pedida por el usuario tras la sesión 43: resolver
`$9B85`, la tabla de tipo/colisión de loseta que `CONSULTAR_TIPO_LOSETA`
(sesión 34) ya usaba como candidata pero sin confirmar ni convertir a
datos reales.

### Localización y confirmación

`CONSULTAR_TIPO_LOSETA` calcula `HL = $9B85 + (índice_loseta AND
$7F)` y devuelve `(HL) AND $1F`. Extraídos los 91 bytes reales
(`FISICO/CODE.bin[$9B85:$9BE0]`) más 2 bytes de relleno final
(`$9BE0-$9BE1`, ambos `$00`) — el rango termina justo en `INICIO`
(`$9BE2`), sin holgura, igual que ya pasó con `GRAFICOS_LOSETAS`.

Comparación directa con el equivalente MSX (`TABLA_TIPOS_LOSETA`,
`madmix1_body.asm:2380-2404`, dentro de un "bloque reservado"
`$8EC4-$8F23` de 96 bytes): **coincidencia byte a byte exacta**, tanto
en los 91 valores de tipo como en los 2 bytes de relleno final. MSX
usa **el mismo nombre exacto**, `TABLA_TIPOS_LOSETA` — adoptado tal
cual. Confirma también la nota ya conocida de MSX: el "tipo" no
distingue muro de suelo (las 45 losetas de muro, índices 0-44, y las
3 primeras de "suelo con bola", 45-47, comparten tipo 0).

### El bloque reservado de 4 bytes antes de la tabla

El propio código MSX documenta que su tabla de 96 bytes tiene un
prefijo de 3 bytes reutilizado como variables de `LEER_ENTRADA`
(`ACUMULADOR_ENTRADA` + 1 byte de relleno + `FLAG_ENTRADA_BLOQUEADA`)
antes de que empiece la tabla real. Spectrum tiene el mismo patrón,
con una variación: `$9B81`=`ACUMULADOR_ENTRADA` (candidata, ya
identificada), `$9B82`=relleno sin referencias (igual que el relleno
de MSX), `$9B83`=un byte EXTRA propio de Spectrum sin equivalente MSX
(guarda "el valor anterior" del acumulador antes de limpiarlo, usado
por `COMPROBAR_PAUSA` para resolver direcciones opuestas pulsadas a la
vez — ya documentado en sesión 26, ahora con contexto de por qué no
tiene equivalente MSX: MSX solo reservó 1 byte de relleno, no 2), y
`$9B84`=`FLAG_ENTRADA_BLOQUEADA` (confirmada sesión 39). Confirma una
vez más que MSX copió literalmente la técnica de "bloque reservado
reutilizado" de este original Spectrum.

### Segunda referencia sin resolver, dentro de `GESTIONAR_SCROLL`

Además del uso ya conocido en `CONSULTAR_TIPO_LOSETA`, hay una SEGUNDA
`LD HL,$9B85` dentro del tramo de `GESTIONAR_SCROLL` (código ya
marcado "confirmado instrucción a instrucción idéntico a MSX" en
sesión 34) que indexa la tabla con una máscara de 6 bits (`AND $3F`,
no 7 como `CONSULTAR_TIPO_LOSETA`) y hace un toggle de bit condicional
(lee, compara, `XOR (HL)` / `LD (HL),A`) — es decir, esta zona
**escribe** en `TABLA_TIPOS_LOSETA`, no solo la lee. No se ha
analizado a fondo todavía: no está claro si de verdad opera sobre la
tabla de tipos (reutilizando bits altos como flag transitorio, algo
consistente con que `CONSULTAR_TIPO_LOSETA` enmascare con `AND $1F`
antes de usar el valor) o si solo comparte la dirección base por
coincidencia con un descuadre de desensamblado en esa zona. Se
renombró el literal a `TABLA_TIPOS_LOSETA` de todas formas (la
dirección es correcta con certeza) y se dejó un comentario señalando
la duda.

**Verificado**: recompiló sin errores y **0 diferencias, 48485 bytes
idénticos al `.tzx` original**. Inventario: 746 etiquetas (dato=117,
+1 por `TABLA_TIPOS_LOSETA`; interna=515, -1). Actualizado
`mapa_memoria.html`: el segmento "LEER_ENTRADA y subrutinas de
teclado" se parte en dos (191 B código + 93 B `TABLA_TIPOS_LOSETA`,
categoría datos).

### Error propio durante la edición (autocorregido)

Al sustituir el tramo mecánico por el bloque `TABLA_TIPOS_LOSETA`, el
límite final del reemplazo se calculó buscando la primera línea
`INICIO:` — pero el límite real de los datos está varias líneas antes,
justo donde empieza el comentario de cabecera de `INICIO` (~46 líneas
de análisis histórico de sesiones 1/29). El primer intento de reemplazo
se comió ese comentario completo por error. Se restauró literalmente
(se tenía el texto exacto capturado en la propia sesión, de una
consulta anterior al listado de compilación) y se verificó que el
rebuild siguiera dando 0 diferencias tras la restauración.

### Pendiente para próximas sesiones

- Analizar a fondo el tramo `$9B45-$9B80` (tablas de puerto/máscara
  para `COMPROBAR_TECLA` según modo de entrada) — sigue sin convertir
  a datos reales. **[RESUELTO en sesión 45, ver abajo]**
- Entender la segunda referencia de `GESTIONAR_SCROLL` a
  `TABLA_TIPOS_LOSETA` (máscara de 6 bits, escritura condicional).
- Resto de la lista heredada de sesiones 40-43 sin cambios.

## Sesión 45 — 2026-08-13: orden de bits de `DECIDIR_DIRECCION_SCROLL` verificado — no es un error, es QAOP

Un desarrollador externo (que ha hecho su propia ingeniería inversa de
la versión Spectrum) avisó de que el orden de bits de dirección en
`GESTIONAR_SCROLL` de MSX (`ARRIBA/ABAJO/DERECHA/IZQUIERDA`) le
pareció "distinto" al que él veía en su propio desensamblado de
Spectrum, preguntando si eso significaba que uno de los dos proyectos
lo tenía mal. Adjuntó capturas de su propio desensamblado de Spectrum
(dirección `$9692`, saltos a `$97A9`/`$9760`/`$96BE`, fallthrough en
`$96A0`) frente al de MSX.

### Verificación

Primero, comparación directa: el desensamblado externo de Spectrum
coincide EXACTAMENTE, instrucción a instrucción y dirección a
dirección, con lo que ya teníamos en `madmix_body.asm` en ese punto
(`CODE_9692`/`CODE_97A9`/`CODE_9760`/`CODE_96BE`, ahora renombrados)
— confirmación cruzada independiente de que nuestra transcripción es
correcta a nivel de bytes.

Segundo, y más importante: el orden de bits en sí. `DECIDIR_DIRECCION_SCROLL`
(Spectrum) prueba los bits en orden **DERECHA, IZQUIERDA, ABAJO,
ARRIBA(fallthrough)**. `DECIDIR_DIRECCION_SCROLL`-equivalente de MSX
(`GESTIONAR_SCROLL`, `madmix1_body.asm:1265`) prueba **ARRIBA, ABAJO,
DERECHA, IZQUIERDA(fallthrough)** — órdenes distintos, confirmado.

**Esto NO es un error.** Cada versión lee su propio teclado/joystick
con su propia rutina, y el byte de dirección que le llega a
`GESTIONAR_SCROLL` ya viene con SU PROPIO orden de bits desde ESA
lectura — lo único que tiene que ser cierto es que cada versión sea
consistente CONSIGO MISMA (que sus propias teclas activen sus propios
bits en el orden que su propio código de scroll espera), no que las
dos versiones coincidan entre sí.

Para confirmarlo con evidencia dura, se descifró `TABLA_TECLAS_MODO_0`
(`$9B45`, la tabla de puerto ULA/máscara de bit que
`ESCANEAR_FILAS_TECLADO` usa por defecto, hasta ahora sin convertir —
pendiente heredada de sesión 44): extraídos los 5 pares `(puerto,
máscara)` directamente de `FISICO/CODE.bin` y decodificados contra el
mapa de teclado estándar del ZX Spectrum (fila `$FBFE`=Q/W/E/R/T,
`$FDFE`=A/S/D/F/G, `$DFFE`=P/O/I/U/Y, `$7FFE`=SPACE/SYM/M/N/B):

```
entry0: $7F,$01 -> SPACE (bit4 final, sin uso en las 4 direcciones)
entry1: $FB,$01 -> Q
entry2: $FD,$01 -> A
entry3: $DF,$02 -> O
entry4: $DF,$01 -> P
```

Como `ESCANEAR_FILAS_TECLADO` acumula en `E` con `RL E` en cada
iteración, el ÚLTIMO bit probado (`entry4`) acaba en el bit MENOS
significativo. Resultado: **bit0=P, bit1=O, bit2=A, bit3=Q** — el
esquema **QAOP** (Q=arriba, A=abajo, O=izquierda, P=derecha), el
control clásico de facto de Topo Soft en la época de este juego.
Cruzando con `DECIDIR_DIRECCION_SCROLL`: bit0(P)→`SCROLL_DERECHA`,
bit1(O)→`SCROLL_IZQUIERDA`, bit2(A)→`SCROLL_ABAJO`,
bit3(Q)→`SCROLL_ARRIBA` — **P=derecha, O=izquierda, A=abajo, Q=arriba,
exactamente como cabía esperar del esquema QAOP**. El orden de bits
"raro" no es un bug: es sencillamente el orden en que
`ESCANEAR_FILAS_TECLADO` prueba las teclas Q/A/O/P en su bucle de 5
pasadas, y el propio dispatch de scroll está escrito para encajar con
ESE orden.

### Bonus: modos de entrada 1-3 también descifrados

De paso se resolvieron las otras 3 tablas de la zona (`$9B4F`-`$9B7B`),
completando la pregunta pendiente de la sesión 44:

- `TABLA_TECLA_PAUSA` (`$9B4F`): tecla **H**, la 6ª prueba compartida
  por todos los modos (`COMPROBAR_PAUSA`, bit 5).
- `TABLA_TECLAS_MODO_1A`/`TABLA_TECLAS_MODO_1B` (`$9B5E`/`$9B68`,
  `MODO_ENTRADA=1`): emulación de **joystick Sinclair Interface 2** vía
  teclado — fila numérica `1,2,3,4,5` (puerto derecho) Y `0,9,8,7,6`
  (puerto izquierdo), fundidas con `OR` en `COMPROBAR_PAUSA` (ambos
  puertos Sinclair mapean a las mismas 4 direcciones). Es el esquema
  de teclas estándar de la época para emulación Sinclair, más
  evidencia de que la decodificación es correcta.
- Modo 2 (`CP $02` → `JP Z,CODE_9B7C`): **no usa tabla** — hace
  `IN A,($1F)` directo, el puerto estándar de **joystick Kempston**.
- `TABLA_TECLAS_MODO_3` (`$9B72`, `MODO_ENTRADA>=3`): esquema con
  teclas `0,7,6,5,8`, propósito exacto sin confirmar (candidato:
  variante redefinible o resto de pruebas de desarrollo) — pendiente.

O sea: Spectrum soporta **4 esquemas de entrada** (teclado QAOP,
Sinclair, Kempston, y un cuarto sin identificar del todo), frente al
control único de MSX (teclado, vía su propio escaneo). Todos los
esquemas de teclado decodificados son mutuamente consistentes con el
mismo orden bit0=DERECHA/bit1=IZQUIERDA/bit2=ABAJO/bit3=ARRIBA.

### Cambios en el código

- `DECIDIR_DIRECCION_SCROLL` (antes `CODE_9692`), `SCROLL_DERECHA`
  (antes `CODE_97A9`), `SCROLL_IZQUIERDA` (antes `CODE_9760`),
  `SCROLL_ABAJO` (antes `CODE_96BE`) y `SCROLL_ARRIBA` (fallthrough,
  antes sin etiqueta) — nombres nuevos, sin equivalente MSX directo
  por el orden de bits distinto pero conceptualmente análogos a
  `SCROLL_ARRIBA`/`SCROLL_ABAJO`/`SCROLL_IZQUIERDA`/`SCROLL_DERECHA`
  de MSX.
- `TABLA_TECLAS_MODO_0`, `TABLA_TECLA_PAUSA`, `TABLA_TECLAS_MODO_1A`,
  `TABLA_TECLAS_MODO_1B`, `TABLA_TECLAS_MODO_3` — 5 tablas nuevas,
  reemplazando el desensamblado mecánico (que producía instrucciones
  basura sin sentido en esa zona, señal clara de que era dato, no
  código).

**Verificado**: recompiló sin errores y **0 diferencias, 48485 bytes
idénticos al `.tzx` original** — los valores decodificados a mano
(puerto/máscara, esquema QAOP/Sinclair/Kempston) son exactos.
Inventario: 752 etiquetas (antes 746). Actualizado `mapa_memoria.html`.

### Respuesta para el desarrollador externo

El orden de bits SÍ es distinto entre Spectrum y MSX, y eso es
exactamente lo que se esperaría: cada plataforma lee su propio
teclado/joystick con su propio código, y ese código determina en qué
bit cae cada tecla. Spectrum usa QAOP (Q/A/O/P → arriba/abajo/
izquierda/derecha) por su propia rutina de escaneo de teclado;
MSX usa otra convención por la suya. Ninguno de los dos está mal —
un orden de bits igual en ambas versiones habría sido la casualidad
rara, no lo esperable. Verificado con evidencia dura (descifrado
byte a byte de la tabla de teclas de Spectrum, 0 diferencias contra
el binario original) y con la propia captura del desarrollador
(coincide con nuestro desensamblado dirección a dirección).

### Pendiente para próximas sesiones

- `TABLA_TECLAS_MODO_3` (`$9B72`): confirmar propósito exacto (por
  qué existe un 4º esquema de entrada). **[RESUELTO en sesión 46, ver
  abajo]**
- Entender la segunda referencia de `GESTIONAR_SCROLL` a
  `TABLA_TIPOS_LOSETA` (máscara de 6 bits, escritura condicional) —
  sigue pendiente, sin relación con lo de esta sesión. **[RESUELTO en
  sesión 46, ver abajo]**
- Resto de la lista heredada de sesiones 40-44 sin cambios.

## Sesión 46 — 2026-08-13: `MAPEAR_LOSETA_A_GRAFICO` resuelta y menú de controles descubierto (confirma `TABLA_TECLAS_MODO_3`)

Continuación pedida por el usuario de los 2 pendientes dejados en la
sesión 45.

### `MAPEAR_LOSETA_A_GRAFICO` (antes `CODE_9899`), RESUELTA POR COMPLETO

La segunda referencia a `TABLA_TIPOS_LOSETA` dentro de
`GESTIONAR_SCROLL` (máscara de 6 bits, escritura condicional,
señalada como sin analizar en sesión 44) resultó ser una rutina
completa: `MAPEAR_LOSETA_A_GRAFICO`. El proyecto MSX **ya la tiene
resuelta y documentada en profundidad** (`madmix1_body.asm:1667`), y
la comparación instrucción a instrucción es un calco exacto, incluidos
sus dos "vestigios" ya identificados por MSX:

- Un `AND $3F` (6 bits, no 7 como `CONSULTAR_TIPO_LOSETA`) — igual en
  ambas versiones, no es un fallo de Spectrum.
- Un `AND $00` que anula por completo una lectura de `(HL)` justo
  antes de un `XOR` — MSX lo documenta como "vestigio probable de una
  comprobación más compleja simplificada en algún momento" del
  desarrollo original. Efecto real: si el bit 7 del byte crudo de la
  celda del nivel está activo (candidato a flag de "loseta ya
  visitada/comida"), alterna el bit 7 de `TABLA_TIPOS_LOSETA[índice]`
  — pero como `CONSULTAR_TIPO_LOSETA` enmascara con `AND $1F` (bits
  0-4), ese toggle **no tiene efecto observable en el juego**, ni en
  Spectrum ni en MSX.

Función real de la rutina: calcula la dirección gráfica real de una
loseta dentro de `GRAFICOS_LOSETAS` (`=$C600+índice*32`, guardada en
`$91C5`, candidata a equivalente de `$8433` de MSX — tampoco tiene
nombre confirmado allí) para que el bucle `LDI` del llamador
(`CODE_972A`, usado tanto en el redibujado incremental de scroll como
en `REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM`) copie los píxeles
correctos. `$91C7` (candidata a `$8435` de MSX, tampoco confirmada
allí) siempre recibe `$02`, propósito exacto sin confirmar en ninguna
de las 2 versiones.

Renombrados también `LD DE,$C600` → `LD DE,GRAFICOS_LOSETAS` (literal
que aún quedaba sin sustituir) y el epílogo `CODE_98FF` →
`RESTAURAR_Y_SALIR_MAPEAR_LOSETA`.

### Descubierto: menú de opciones de control, con texto ASCII legible

Buscando el propósito de `TABLA_TECLAS_MODO_3` (el esquema de teclas
"raro", `0,7,6,5,8`, sin equivalente QAOP/Sinclair claro), se buscó
directamente en `FISICO/CODE.bin` cualquier cadena de texto legible
relacionada con teclado/joystick/modo. Apareció un bloque de texto
ASCII sin analizar en `~$8AA0-$8B40` — **dentro del rango de
direcciones que sesión 24 había marcado como `CARGAR_NIVEL`,
"prácticamente instrucción a instrucción idéntica a MSX"**:

```
$8AE8: "1 TECLADO  "
$8AF5: "2 KEMPSTON  "
$8B03: "3 SINCLAIR-SJS "
$8B14: "4 REDEFINE TECLAS"
       "5 DEMO"
       "0 JUGAR  "
```

Cada cadena va precedida de 2 bytes (longitud + atributo de color) y
el bloque completo está enmarcado por una secuencia repetida `LD
HL,<dirección>` / `CALL $8BEE` (candidata a rutina de impresión de
texto) antes del texto, y termina justo en un `CALL $8C1F` real. Es,
casi con toda seguridad, el menú de selección de controles del juego
— muy similar en espíritu al menú "1 TECLADO/2 JOYSTICK/3 REDEFINE
TECLAS" que MSX ya tiene confirmado y documentado a fondo
(`madmix1_body.asm`, sesión propia de MSX), pero con dos opciones más
(Kempston y Sinclair-SJS se solapan y expanden en Spectrum lo que en
MSX es solo "2 JOYSTICK") y un "0 JUGAR"/"5 DEMO" adicionales.

**Esto confirma con evidencia dura el propósito de
`TABLA_TECLAS_MODO_3`**: es la tabla de teclas para la opción **"4
REDEFINE TECLAS"** — sus valores actuales (`0,7,6,5,8`) son
simplemente el estado por defecto grabado en la ROM antes de que el
jugador redefina sus propias teclas desde ese menú (la lógica que
ESCRIBE esta tabla en tiempo real, si existe, vive en la parte del
menú todavía sin transcribir). De paso, encaja también con
`TABLA_TECLAS_MODO_0` = "1 TECLADO" (QAOP) y
`TABLA_TECLAS_MODO_1A`/`1B` = "3 SINCLAIR-SJS", y el modo 2
(`IN A,($1F)`, Kempston) = "2 KEMPSTON" — los 4 modos de
`MODO_ENTRADA` mapean exactamente a las primeras 4 opciones del menú.

**No se ha tocado el código todavía** — este hallazgo excede el
alcance de esta sesión (implica revisar y probablemente recortar el
límite real de `CARGAR_NIVEL`, transcribir la lógica de impresión de
menú y las 6 opciones completas, y localizar dónde se
lee/escribe la selección del jugador). Queda documentado aquí y en
`mapa_memoria.html` como aviso explícito para una sesión dedicada.

**Verificado**: recompiló sin errores tras los cambios de
`MAPEAR_LOSETA_A_GRAFICO` — **0 diferencias, 48485 bytes idénticos al
`.tzx` original**. El hallazgo del menú es solo lectura/documentación,
no toca el código fuente todavía.

### Pendiente para próximas sesiones

- **Nueva, importante**: transcribir correctamente la zona
  `~$8AA0-$8B40` (menú de opciones de control) y revisar el límite
  real de `CARGAR_NIVEL` en consecuencia — puede que la sesión 24
  necesite una correción de alcance. **[RESUELTO en sesión 47, ver
  abajo]**
- `TABLA_TECLAS_MODO_3`: localizar la lógica que la ESCRIBE cuando el
  jugador redefine teclas (vive presumiblemente en el propio menú, no
  transcrita todavía).
- Resto de la lista heredada de sesiones 40-45 sin cambios.

## Sesión 47 — 2026-08-13: límite real de `CARGAR_NIVEL` corregido — `TABLA_NIVELES` resuelta, menú de controles delimitado

Continuación pedida por el usuario ("sigue por CARGAR_NIVEL") del
aviso dejado en sesión 46.

### El error de alcance de la sesión 24

`CARGAR_NIVEL` (sesión 24) se había descrito como "912 bytes,
prácticamente instrucción a instrucción idéntica a MSX" —
`0x883B-0x8BCB`. Pero el código REAL de la rutina termina mucho antes:
justo en el `RET` que sigue a `CALL CODE_87BC`, en `$88DF` — son
**165 bytes**, no 912. La sesión 24 solo verificó que el ARRANQUE de
ese rango coincidía con MSX; el resto del rango nunca se comprobó
instrucción a instrucción, y el desensamblado mecánico de primera
pasada seguía produciendo texto superficialmente plausible más allá
del `RET` real (el mismo tipo de falso positivo ya visto otras veces
este proyecto con datos que caen en medio de "código" sin analizar).

### `TABLA_NIVELES` ($88E0, 320 bytes), RESUELTA POR COMPLETO

Justo después del `RET` de `CARGAR_NIVEL` empieza `TABLA_NIVELES`
(ya referenciada por su propio código: `LD HL,$88E0`) — 16 registros
de 20 bytes, **mismo nombre y mismo formato de registro EXACTO** que
`TABLA_NIVELES` de MSX (`madmix_scr_body.asm:3250`): puntero a
cuerpo, puntero a cabecera-arriba, puntero a cabecera-abajo, filas
variables, campo7, nº de items tipo 3/1/2, duración de parpadeo, tile
comodín, fila/columna de referencia, 2 bytes sin identificar, icono
HUD, objetivo de bolitas.

Comparación registro a registro contra el nivel 0 de MSX: **todos los
campos NO-puntero son IDÉNTICOS BYTE A BYTE** (filas=22, items=5/0/0,
parpadeo=250, comodín=`$3F`, fila/columna=`$30/$34`, bytes
sin identificar=`$18/$2C`, icono=`$70`, objetivo=114) — mismo
fenómeno de siempre, MSX copió esta tabla del original Spectrum sin
tocar los datos, solo adaptó los 3 punteros (apuntan a las copias
Spectrum de cuerpo/cabecera de cada nivel, que viven en algún punto
del propio fichero todavía sin localizar — quedan en hex crudo por
ahora, sin resolver a etiquetas).

### Menú de opciones de control ($8A20-$8BCA, 427 bytes), delimitado con precisión

El resto del rango que sesión 24 atribuyó a `CARGAR_NIVEL` es en
realidad el menú descubierto en sesión 46. Delimitado con exactitud:
la tabla de texto (formato longitud+atributo+texto) empieza en
`$8AE7` y termina en `$8B39` (justo antes de un `CALL $8C1F` real),
con las 6 opciones en estas direcciones exactas:

```
$8AE9 "1 TECLADO"          (candidato: TABLA_TECLAS_MODO_0, QAOP)
$8AF6 "2 KEMPSTON"         (candidato: modo 2, IN A,($1F))
$8B04 "3 SINCLAIR-SJS"     (candidato: TABLA_TECLAS_MODO_1A/1B)
$8B15 "4 REDEFINE TECLAS"  (candidato: TABLA_TECLAS_MODO_3)
$8B28 "5 DEMO"
$8B30 "0 JUGAR"
```

Detalle curioso: hay un byte suelto (`$20`, espacio) entre la entrada
3 y la 4 que no encaja en el patrón longitud+atributo+texto de las
demás entradas — sin explicación confirmada todavía (candidato: error
de un byte en los datos originales de 1988, o un separador de
formato que no se ha entendido del todo). El resto del bloque (antes
y después de la tabla de texto: `$8A20-$8AE6` y `$8B39-$8BCA`) es
código real (opcodes plausibles y densos, muy distinto del patrón de
datos-mal-decodificados visto en otras zonas) — casi con toda
seguridad la lógica de dibujado/navegación del menú, pero no se ha
desensamblado en detalle todavía. Se volcó como `DB` crudo con la
tabla de texto claramente señalada en un comentario de cabecera.

Esto **confirma con evidencia dura** el mapeo de sesión 45/46:
`TABLA_TECLAS_MODO_0`="1 TECLADO", modo 2 (`IN A,($1F)`)="2 KEMPSTON",
`TABLA_TECLAS_MODO_1A/1B`="3 SINCLAIR-SJS", `TABLA_TECLAS_MODO_3`="4
REDEFINE TECLAS".

### Referencias huérfanas resueltas con `EQU`

Dos etiquetas referenciadas desde fuera de este rango
(`CODE_8A3F`, candidato a `VACIAR_CANALES_SONIDO` desde
`BUCLE_PRINCIPAL_JUEGO`, ya conocido desde sesión 40; y `CODE_8A6C`,
nueva) caían dentro del menú -- resueltas con el patrón `EQU` habitual
del proyecto.

**Verificado**: recompiló sin errores tras añadir las 2 constantes
`EQU` que faltaban — **0 diferencias, 48485 bytes idénticos al `.tzx`
original**. Inventario: 718 etiquetas (baja de 752 porque el
desensamblado mecánico de esta zona generaba muchas etiquetas
`CODE_XXXX` automáticas en direcciones que nunca fueron alcanzables de
verdad — mismo efecto ya visto con `GRAFICOS_LOSETAS`/el tramo final
en sesiones 41/44). `mapa_memoria.html`: `CARGAR_NIVEL` baja de 912 a
165 bytes; nuevos segmentos `TABLA_NIVELES` (320 B, datos) y "menú de
opciones de control" (427 B, mecánico) — total mecánico sube de 9994
a 10421 bytes, ahora en ocho tramos.

### Error propio durante la edición (autocorregido)

Al calcular el límite final del reemplazo (buscando la etiqueta
`ESCRIBIR_PATRON_VRAM:`), se borró por error su comentario de cabecera
completo (14 líneas, sesión 23) porque el límite usado fue la propia
etiqueta en vez de justo antes de su comentario — mismo tipo de fallo
que ya pasó en sesión 44 con `INICIO`. Detectado de inmediato
comparando con `src/build/main.lst` (que todavía conservaba el
listado de la compilación anterior con el comentario intacto) y
restaurado el texto exacto. Lección repetida: al delimitar un
reemplazo por "primera etiqueta real encontrada", verificar SIEMPRE
si esa etiqueta tiene un comentario de cabecera pegado justo encima
que también haya que preservar.

### Pendiente para próximas sesiones

- Desensamblar en detalle el menú de opciones de control
  (`$8A20-$8AE6` y `$8B39-$8BCA`, código real) y localizar la lógica
  que escribe `TABLA_TECLAS_MODO_3` cuando el jugador redefine teclas.
- Explicar el byte suelto entre las entradas 3 y 4 de la tabla de
  texto del menú.
- Localizar los punteros de cuerpo/cabecera de cada nivel (los 3
  punteros por registro de `TABLA_NIVELES`) dentro del propio fichero.
- Resto de la lista heredada de sesiones 40-46 sin cambios.

## Sesión 48 — 2026-08-13: 5 etiquetas internas de `CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION` resueltas

El usuario señaló `CODE_629C` (dentro de
`CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION`, ya resuelta como rutina
en sesión 37) pidiendo analizar y nombrar esa etiqueta y las
siguientes. MSX tiene esta misma rutina completa y ya nombrada
(`madmix_scr_body.asm:771`), coincidencia instrucción a instrucción
total:

- `CODE_629C` → `COMPROBAR_LOSETA_IZQUIERDA`
- `CODE_62A2` → `COMPROBAR_LOSETA_ABAJO`
- `CODE_62AB` → `COMPROBAR_LOSETA_ARRIBA`
- `CODE_62AF` → `IDENTIFICAR_PROXIMA_LOSETA`
- `CODE_62C5` → `ENMASCARAR_TIPO_LOSETA`

Curiosidad de paso: esta rutina usa el orden de bits
bit0=DERECHA/bit1=IZQUIERDA/bit2=ABAJO/bit3=ARRIBA, **igual en
Spectrum y en MSX** — a diferencia de `GESTIONAR_SCROLL`
(`DECIDIR_DIRECCION_SCROLL`, sesión 45), donde MSX usa un orden
distinto al de Spectrum. Es decir, **el propio MSX usa 2 órdenes de
bits distintos en 2 rutinas distintas de su propio motor** — confirma
con más fuerza todavía la conclusión de sesión 45: el orden de bits de
dirección es una decisión local de cada rutina/subsistema (depende de
cómo esa rutina en concreto fue escrita/portada), no una convención
global de la plataforma.

**Verificado**: recompiló sin errores y **0 diferencias, 48485 bytes
idénticos al `.tzx` original**. Inventario sin cambios de fondo (718
etiquetas, renombrar no cambia el total).

### Pendiente para próximas sesiones

Sin cambios respecto a sesión 47.

## Sesión 49 — 2026-08-13: `DIBUJAR_CAMBIO_LOSETA` resuelta; corrección grande de alcance en la sesión 39 (6595 bytes)

Continuación pedida por el usuario ("continua por CODE_62D6 y
sucesivas").

### `DIBUJAR_CAMBIO_LOSETA` (2 etiquetas internas), RESUELTA POR COMPLETO

`CODE_62D6`/`CODE_62DB`, dentro de `DIBUJAR_CAMBIO_LOSETA` (ya nombrada
desde sesión 39), coinciden instrucción a instrucción con MSX
(`madmix_scr_body.asm:813`) — mismos nombres EXACTOS adoptados:

- `CODE_62D6` → `DIBUJAR_CAMBIO_LOSETA_CHECK_COL`
- `CODE_62DB` → `DIBUJAR_CAMBIO_LOSETA_REDRAW`

De paso, `CODE_6480` (dentro de `FIJAR_PISTA`, en
`REGISTRAR_PISTA_TANQUE_AVION`) resultó ser una etiqueta huérfana sin
ninguna referencia real en todo el fichero y sin equivalente en MSX
(que no tiene ninguna etiqueta en ese punto) — vestigio del
desensamblado mecánico de primera pasada. Eliminada.

### Hallazgo grande: la sesión 39 sobreestimó su propio alcance en 6595 bytes

Al pedir el usuario seguir con `CODE_67A6` y sucesivas, resultó que
ese no era un caso aislado más: **`HNDLR_TRAMPILLA_CERRADA_B`**
(termina en `$677E`) es el ÚLTIMO de los 17 manejadores reales — pero
**desde ahí hasta `HNDLR_PELMAZOIDE` ($8142) hay 6595 bytes** que
nunca se convirtieron de verdad, pese a que la sesión 39 declaró
"RESUELTOS POR COMPLETO" los 7777 bytes completos de
`$62E1-$8142` (`TABLA_MANEJADORES_LOSETA` + los 17 manejadores). En
realidad solo los primeros 1182 bytes (los 17 manejadores en sí)
se convirtieron línea a línea; el resto se quedó con desensamblado
mecánico de primera pasada (instrucciones falsas superficialmente
plausibles) sin que nadie lo comprobara — mismo tipo de error de
alcance ya visto y corregido con `CARGAR_NIVEL` en la sesión 47, pero
esta vez bastante más grande (6595 B frente a 747 B).

Verificado con el usuario antes de proceder (dado el tamaño):
volcado como `DB` crudo, honesto sobre que sigue sin analizar —
mismo criterio que el menú de controles de la sesión 47, sin intentar
entender su contenido todavía. Única referencia externa detectada
dentro del tramo: `CODE_8005`, resuelta con `EQU`.

**Verificado**: recompiló sin errores y **0 diferencias, 48485 bytes
idénticos al `.tzx` original**. `mapa_memoria.html`: el segmento
"manejadores de TABLA_MANEJADORES_LOSETA" baja de 7777 a 1182 bytes;
nuevo segmento "sin analizar" de 6595 bytes — total mecánico sube de
10421 a 17016 bytes, ahora en nueve tramos.

### Bug de herramienta descubierto y corregido: `gen_inventory.py`

Al reducir `madmix_body.asm` de ~13000 a ~9200 líneas con el volcado
anterior, `py tools/gen_inventory.py` empezó a devolver **0
etiquetas** (en vez de un error, silenciosamente). Causa: el listado
de SjASMPlus separa el número de línea de la dirección con `+` en
líneas de un `INCLUDE`, y el ancho de esa columna es de anchura
VARIABLE según el total de líneas del fichero en ese momento —
a veces hay un espacio de relleno entre el `+` y la dirección
(`874+ EF1C`) y a veces no (`11743+9BA0`, cuando el número de línea
necesita más dígitos). La expresión regular de `gen_inventory.py`
solo contemplaba el caso sin espacio (documentado explícitamente así
en un comentario, sesión propia de creación de la herramienta) —
nunca se había dado el caso de una reducción de tamaño así de grande
en este proyecto para exponerlo. Corregido: `\+` ahora acepta `\s*`
opcional antes de la dirección.

**Verificado**: `gen_inventory.py` vuelve a funcionar — 592 etiquetas
(baja de 718 porque el volcado de 6595 bytes elimina ~125 etiquetas
`CODE_XXXX` automáticas que nunca fueron alcanzables de verdad, mismo
efecto que en sesiones 41/44/47).

### `HNDLR_PELMAZOIDE` (5 etiquetas internas), RESUELTA POR COMPLETO

Continuando por `CODE_81BB`/`CODE_8160`/`CODE_81B1`/`CODE_818C`/
`CODE_8186` (pedido por el usuario): están dentro de `HNDLR_PELMAZOIDE`
(ya nombrada desde sesión 35, "gestor por fotograma de los
fantasmas"). MSX tiene esta rutina completa y ya resuelta
(`madmix_scr_body.asm:1848`), coincidencia instrucción a instrucción
total — mismos nombres EXACTOS adoptados:

- `CODE_8160` → `BUCLE_PELMAZOIDE`
- `CODE_8186` → `AJUSTAR_SPRITE_MODO_ESPECIAL`
- `CODE_818C` → `DIBUJAR_PELMAZOIDE`
- `CODE_81B1` → `SIGUIENTE_PELMAZOIDE`
- `CODE_81BB` → `FIN_PELMAZOIDE`

De paso, esta comparación confirmó varias piezas sueltas de sesiones
anteriores:

- `$600F` = `REGISTRO_NIVEL_CONTADOR_PELMAZOIDES` (antes candidata) —
  etiqueta real añadida.
- `$8060` = `TABLA_ITEMS_PELMAZOIDE` y `$8098` =
  `TABLA_ANIMACION_PELMAZOIDE` (mismos nombres EXACTOS que MSX) —
  ambas caen dentro del tramo de 6595 bytes recién descubierto sin
  analizar (ver arriba); se les puso etiqueta ahí mismo sin tocar el
  resto del tramo.
- `CODE_871C` = `ACTIVAR_EFECTO_ITEM` — ya era candidata desde sesión
  40 (resuelta entonces solo con `EQU` sobre zona mecánica); ahora
  CONFIRMADA y con etiqueta real en su verdadera dirección de código
  (la llamada de `HNDLR_PELMAZOIDE` a `ACTIVAR_EFECTO_ITEM` coincide
  exacta con la de MSX en el mismo punto). El `EQU` antiguo se
  eliminó al quedar redundante.

**Verificado**: recompiló sin errores tras resolver un conflicto de
`Duplicate label` (el `EQU` antiguo de `ACTIVAR_EFECTO_ITEM` chocaba
con la etiqueta real nueva) — **0 diferencias, 48485 bytes idénticos
al `.tzx` original**. Inventario: 595 etiquetas (sube de 592).
Actualizado `mapa_memoria.html` (detalle de `HNDLR_PELMAZOIDE`, del
tramo de 6595 bytes con las 2 tablas ahora identificadas dentro, y de
`ACTIVAR_EFECTO_ITEM`).

### `MOTOR_MOVIMIENTO_ITEM` (28 etiquetas internas), RESUELTA POR COMPLETO

Continuando por `CODE_81BB` (pedido por el usuario): resulta ser la
rutina compartida por los 3 manejadores de item (`HNDLR_PELMAZOIDE`,
`HNDLR_MARICOCO`, `HNDLR_REGPUNANTOSO`), ya nombrada desde sesión
35/40 pero con TODAS sus 28 etiquetas internas todavía sin resolver.
MSX tiene esta rutina completa y en profundidad (`madmix_scr_body.asm:1936`),
coincidencia instrucción a instrucción total — mismos nombres EXACTOS
adoptados para las 28:

`COMPROBAR_ESTADO_ITEM`, `CALCULAR_DIRECCION_ACERCAMIENTO`,
`COMPROBAR_FILA`, `COMPROBAR_ALINEAMIENTO_LOSETA`,
`ELEGIR_ENTRE_LIBRES`, `ELEGIR_DIRECCION_ALEATORIA`,
`CONTINUAR_INDICE_DIRECCION_PREVIA`, `FIJAR_DIRECCION_Y_PASO`,
`CONTINUAR_TRAS_ELEGIR_PASO`, `CONTINUAR_TRAS_MODO_INVERTIDO`,
`COMPROBAR_CODIGO_IZQUIERDA`, `COMPROBAR_CODIGO_ABAJO`,
`COMPROBAR_CODIGO_ARRIBA`, `GUARDAR_POSICION_Y`,
`CALCULAR_POSICION_VRAM_ITEM`, `CONTINUAR_AJUSTE_COLUMNA`,
`CONTINUAR_AJUSTE_FILA`, `SALIR_FUERA_DE_RANGO`,
`CONSULTAR_LOSETA_LIBRE_DIRECCION`, `COMPROBAR_IZQUIERDA`,
`COMPROBAR_ABAJO`, `COMPROBAR_ARRIBA`, `CONSULTAR_LOSETA_DESPLAZADA`,
`LOSETA_BLOQUEADA`, `LOSETA_LIBRE`, `FIN_CONSULTA_LOSETA`,
`MAPEAR_COORDENADA_A_DIRECCION`, `GENERAR_ALEATORIO`.

Esto resuelve de golpe varias preguntas pendientes de sesiones muy
anteriores:

- **`CALCULAR_POSICION_VRAM_ITEM`**: ya era "candidato" desde sesión
  35/40 ("candidato a la misma función que ... de MSX"). CONFIRMADO:
  es literalmente el **segundo punto de entrada** de
  `MOTOR_MOVIMIENTO_ITEM` (MSX lo documenta como `$53A2`, llamado
  directo desde `ACTUALIZAR_DESTELLO_ITEMS` sin pasar por las
  comprobaciones de "detrás de cámara").
- **`CODE_83A3` → `MAPEAR_COORDENADA_A_DIRECCION`**: pendiente desde
  sesión 24/25 ("candidato MAPEAR_COORDENADA_A_DIRECCION, sin
  confirmar", mencionado en la cabecera de `CARGAR_NIVEL`). CONFIRMADO.
- **`CODE_8358` → `CONSULTAR_LOSETA_LIBRE_DIRECCION`**: pendiente
  desde sesión 40 ("helper de comprobación de bits de dirección,
  llamado 4 veces desde MOTOR_MOVIMIENTO_ITEM"). CONFIRMADO.
- **`CODE_83BC` → `GENERAR_ALEATORIO`**: generador pseudoaleatorio
  basado en el registro `R` del Z80 (refresco de memoria) — mismo
  mecanismo que MSX. Usa una nueva variable `SEMILLA_ALEATORIA`
  (`$6035`, mismo nombre EXACTO que MSX) — antes 3 bytes sin
  identificar, ahora separados en 1 byte suelto + la semilla real.

De paso se completó **`TABLA_ELECCION_DIRECCION`** (`$80C2`, dentro
del tramo mecánico de 6595 bytes de más arriba): 128 bytes = 16
bloques de 8, mismo nombre y contenido EXACTOS que MSX, tabla de
"elige dirección según bitmask de libres + dirección previa + bit
aleatorio" con sesgo de continuidad de movimiento. Termina EXACTO en
`HNDLR_PELMAZOIDE`/`$8142`, sin holgura — confirmación de boundary
por aritmética, mismo patrón que otras tablas de esta sesión.

**Verificado**: recompiló sin errores y **0 diferencias, 48485 bytes
idénticos al `.tzx` original**. Inventario: 597 etiquetas (sube de
595). Actualizado `mapa_memoria.html` (`MOTOR_MOVIMIENTO_ITEM` y el
tramo de 6595 bytes, ahora con 3 tablas identificadas dentro en vez
de 2).

### Segmento completo `$85AD-$883B` (654 bytes) RESUELTO POR COMPLETO

Continuando por `CODE_67A6`/líneas 2632-3150 (pedido por el usuario):
resultó ser el tramo que sesión 40 había dejado marcado "sin
analizar" salvo por la entrada de `ACTIVAR_EFECTO_ITEM` (resuelta
solo como `EQU`). MSX tiene toda esta cadena de rutinas completa y
documentada en profundidad; coincidencia instrucción a instrucción
en todo el tramo. Resueltas de golpe, mismos nombres EXACTOS que MSX:

- **`AVISAR_PROXIMIDAD_PISTA`** (antes `CODE_85AE`, 6 etiquetas
  internas: `BUCLE_PISTA`, `FORMATO_B`, `FORMATO_B_POS`, `FILA_FIJA`,
  `COMPROBAR_MARGEN_PISTA`, `SIGUIENTE_PISTA`) — avisa cuando el
  comecocos se acerca a la pista de tanque/avión.
- **`ARMAR_AVISO_DESTELLO`** (antes `CODE_860E`, 2 etiquetas:
  `BUCLE_RANURA_AVISO`, `SIGUIENTE_RANURA_AVISO`) — arma una entrada
  de aviso/flash en `TABLA_RANURAS_AVISO`.
- **`ITEM_TABLE_EFECTOS_DESTELLO`** (`$8639`, 126 bytes) y
  **`TABLA_RANURAS_AVISO`** (`$86B7`, 15 bytes) — ambas confirmadas
  IDÉNTICAS byte a byte a MSX. Se había volcado primero por error
  como "126 bytes sin identificar, propio de Spectrum" (ver más
  abajo, autocorregido en la misma sesión al descubrir la
  coincidencia).
- **`ACTUALIZAR_DESTELLO_ITEMS`** (4 etiquetas internas:
  `BUCLE_DESTELLO`, `CALCULAR_POSICION_DESTELLO`,
  `DIBUJAR_FRAME_DESTELLO`, `SIGUIENTE_DESTELLO`) — dibuja el flash
  cada fotograma. Un quinto label (`CODE_86D0`) resultó huérfano (sin
  equivalente MSX ni referencias reales) y se eliminó.
- **`ACTIVAR_EFECTO_ITEM`** (8 etiquetas internas:
  `ACTIVAR_NUEVO_MODO_ESPECIAL`, `INICIAR_MODO_ESPECIAL`,
  `MODO_BOLA_PODER_ACTIVO`, `SUMAR_PUNTOS_MODO1`,
  `MODO_HIPOPOTAMO_ACTIVO`, `SUMAR_PUNTOS_MODO2`,
  `MODO_HERRAMIENTA_ACTIVO`, `DELEGAR_AVISO_PISTA`) — comprueba
  colisión del comecocos con un item.
- **`INICIALIZAR_ITEMS_NIVEL`**/**`INICIALIZAR_PARCIAL_ITEMS_NIVEL`**
  (antes `CODE_87BC`, 5 etiquetas internas:
  `BUCLE_RESET_PELMAZOIDE`, `BUCLE_RESET_MARICOCO`,
  `BUCLE_RESET_REGPUNANTOSO`, `LOOP_LIMPIEZA_DESTELLO`,
  `CONTINUAR_RESET_EXCAVATOFONO`, `LOOP_LIMPIEZA_PISTA`) —
  reinicializa todo el estado de items interactivos al cargar nivel.
  Confirma `TEMPORIZADOR_PARPADEO_BOLA` (`$6020`).

### 2 diferencias reales confirmadas en `ACTIVAR_EFECTO_ITEM`

Coherentes con [[madmix_sound_chip_differences_expected]] y con que
Spectrum sea el original:

- **Duración de modo especial**: MSX usa 40/45 fotogramas; aquí son
  **42/47** (`$2A`/`$2F`) — 2 fotogramas más en ambos casos.
- **Sin espera activa de evento de sonido**: `INICIAR_MODO_ESPECIAL`
  aquí termina con `RET` inmediato tras marcar
  `EVENTO_SONIDO_PENDIENTE=8`; MSX espera activamente (bucle
  `.ESPERAR_EVENTO`) a que se consuma antes de marcar el evento final
  13 — adaptación propia de MSX a la temporización de su gestor de
  sonido PSG, innecesaria aquí.

### Error propio autocorregido: `ITEM_TABLE_EFECTOS_DESTELLO` volcada mal la primera vez

Al llegar al hueco de 126 bytes entre `SIGUIENTE_RANURA_AVISO` y
`TABLA_RANURAS_AVISO`, se asumió (sin comprobar contra MSX primero)
que era contenido genuinamente propio de Spectrum sin equivalente, y
se volcó como `DB` crudo sin etiquetas. Al continuar con
`ACTUALIZAR_DESTELLO_ITEMS` inmediatamente después apareció la
referencia real (`LD HL, ITEM_TABLE_EFECTOS_DESTELLO`) que reveló el
error: MSX SÍ tiene esta tabla, documentada en detalle
(`madmix_scr_body.asm:2846`), y los 126 bytes son IDÉNTICOS byte a
byte. Se corrigió sustituyendo el volcado crudo por la estructura
completa con las 7 subsecuencias nombradas
(`EFECTOS_DESTELLO_SEQ_A/A_TAIL/B_ENTRY/B_MAIN/B_TAIL/C/C_TAIL`).
Lección: antes de dar algo por "sin correspondencia MSX conocida",
comprobar primero si alguna rutina cercana ya resuelta lo referencia
por nombre.

**Verificado**: recompiló sin errores en cada paso — **0 diferencias,
48485 bytes idénticos al `.tzx` original** en todo momento tras cada
lote de cambios. Inventario: 603 etiquetas (sube de 597).
`mapa_memoria.html`: el segmento "sin analizar (654 B)" pasa a
categoría `codigo`, totalmente resuelto y renombrado — total mecánico
baja de 17016 a 16362 bytes, ahora en siete tramos.

### Pendiente para próximas sesiones

- **[RESUELTO en sesión 50, ver abajo]**
- Resto de la lista heredada de sesiones 40-48 sin cambios.

## Sesión 50 — 2026-08-13: los 6369 bytes restantes eran datos de nivel (`CUERPO_Lxx`/`CABECERA`), no código

Continuación pedida por el usuario ("sigue por ahí") del último
pendiente grande.

### El hallazgo: no es código, son mapas de laberinto

Al examinar los primeros bytes del tramo de 6595 bytes ($677F+) el
patrón no tenía pinta de código real (valores repetidos en bloques
pequeños, típico de datos de rejilla). Cruzando los 3 punteros de
cada uno de los 16 registros de `TABLA_NIVELES` (sesión 47) contra
este rango, la hipótesis se confirmó de inmediato: **son los propios
datos de laberinto** (`CUERPO_Lxx`/`CABECERA`) que esos punteros
referencian — session 47 ya había extraído los punteros pero nunca
llegó a cruzarlos contra el contenido de esta zona.

### Verificación por aritmética de punteros (mismo patrón de toda la sesión)

Usando el campo `filas_variable` de cada registro de `TABLA_NIVELES`
(tamaño real de cada cuerpo = `filas_variable × 32` bytes; las
cabeceras son siempre 96 bytes = 3 filas × 32), se comprobó que los
12 bloques distintos encajan EXACTOS y sin hueco entre sí — cada uno
arranca justo donde termina el anterior — y el último termina EXACTO
en `TABLA_ITEMS_PELMAZOIDE` (`$8060`, ya resuelta en sesión 49), sin
holgura de ningún tipo:

```
$677F CUERPO_L01 (704 B, niveles 0 y 1 -- registro 0 es un duplicado muerto del 1)
$6A3F CUERPO_L02 (480 B)
$6C1F CUERPO_L03 (512 B)
$6E1F CUERPO_L09 (576 B)
$705F CUERPO_L05 (512 B)
$725F CUERPO_L06 (576 B)
$749F CUERPO_L04 (480 B)
$767F CUERPO_L08 (480 B)
$785F CUERPO_L07 (608 B)
$7ABF CUERPO_L10 (544 B)
$7CDF CUERPO_L15 (576 B)
$7F1F CABECERA_7F1F (96 B, niveles 4/5/7/12/13)
$7F7F CABECERA_7F7F (96 B, nivel 8)
$7FDF relleno a cero (33 B, sin consumidor conocido)
$8000 CABECERA_8000 (96 B, niveles 0/1/2/3/6/9/10/11/14/15)
$8060 TABLA_ITEMS_PELMAZOIDE (sesión 49)
```

Total: 6369 bytes, ni uno de más ni de menos. `TABLA_NIVELES`
actualizada para usar estas etiquetas en vez de direcciones hex
sueltas (15 de sus 16 registros usan bloques de este rango; los 3
punteros de cada uno de los otros 4 registros restantes, niveles
11-14, apuntan a `$D160`/`$D400`/`$D660`/`$D900` — dentro del tramo
mecánico de sesión 44, fuera de este rango, todavía sin relabeling).

Nombres `CUERPO_Lxx`/`CABECERA_xxxx` en el mismo espíritu que MSX
(que nombra sus cabeceras compartidas por dirección, ej.
`CABECERA_50BC`) — el índice de nivel usado (`Lxx`) sigue la misma
convención que MSX: índice 0 de `TABLA_NIVELES` es un registro
muerto duplicado del nivel 1 (confirmado: sus 20 bytes son
IDÉNTICOS a los del índice 1).

**Nota**: el contenido de laberinto en sí (qué tile va en cada celda)
no se ha decodificado tile a tile todavía — solo se ha delimitado y
etiquetado el bloque completo por bytes.

**Verificado**: recompiló sin errores y **0 diferencias, 48485 bytes
idénticos al `.tzx` original**. Inventario: 618 etiquetas (sube de
603). `mapa_memoria.html`: el tramo de 6595 bytes pasa de "sin
analizar"/mecánico a `datos`, resuelto por completo — total mecánico
baja de 16362 a 9767 bytes, ahora en seis tramos.

### Pendiente para próximas sesiones

- Relabeling de los cuerpos de los niveles 11-14 (`$D160`/`$D400`/
  `$D660`/`$D900`), dentro del tramo mecánico de sesión 44
  (`$D160-$EFB5`) — mismo patrón que esta sesión, ya con los
  punteros conocidos de antemano. **[RESUELTO en sesión 51, ver
  abajo]**
- Decodificar tile a tile el contenido de los laberintos ya
  delimitados.
- Resto de la lista heredada de sesiones 40-48 sin cambios.

## Sesión 51 — 2026-08-13: `CUERPO_L11-L14` resueltos — los 16 niveles ya tienen su cuerpo localizado

Continuación pedida por el usuario ("sigue") del último pendiente de
la sesión 50: los 4 niveles (11-14) cuyo cuerpo caía fuera del rango
`$677F-$8060`, dentro del tramo mecánico de sesión 44
(`$D160-$EFB5`).

Mismo patrón exacto que sesión 50: usando `filas_variable×32` de
cada registro de `TABLA_NIVELES` para los niveles 11-14 (21, 19, 21,
23 filas → 672/608/672/736 bytes), los 4 bloques encajan EXACTOS y
sin hueco entre sí, empezando justo en `$D160` (el arranque mismo del
tramo mecánico de sesión 44):

```
$D160 CUERPO_L11 (672 B)
$D400 CUERPO_L12 (608 B)
$D660 CUERPO_L13 (672 B)
$D900 CUERPO_L14 (736 B) -- termina en $DBE0
```

`TABLA_NIVELES` actualizada para usar estas 4 etiquetas nuevas en sus
últimos 4 registros (11-14) — con esto, **los 16 registros de
`TABLA_NIVELES` usan ya nombres reales para sus 3 punteros**, ningún
`DW` con dirección hex suelta. De paso se limpió el comentario de
cabecera del bloque `$D160-$EFB5` (sesión 41), que enumeraba varios
candidatos (`TABLA_TIPOS_LOSETA`, `ACTIVAR_EFECTO_ITEM`,
`CONSULTAR_LOSETA_LIBRE_DIRECCION`...) ya resueltos en otras
direcciones desde entonces — quedaba desactualizado y podía confundir
sobre qué falta realmente en el resto del tramo (`$DBE0-$EFB5`,
5078 bytes, sigue sin analizar).

**Verificado**: recompiló sin errores y **0 diferencias, 48485 bytes
idénticos al `.tzx` original**. Inventario: 622 etiquetas (sube de
618). `mapa_memoria.html`: nuevo segmento `datos` de 2688 bytes
(`$D160-$DBE0`) resuelto; total mecánico baja de 9767 a 7079 bytes.

### Pendiente para próximas sesiones

- Decodificar tile a tile el contenido de los 16 laberintos ya
  delimitados (`CUERPO_Lxx`/`CABECERA_xxxx`). **[Herramienta lista,
  ver sesión 52 — decodificación en sí sigue pendiente]**
- Analizar el resto del tramo `$DBE0-$EFB5` (5078 bytes) — candidato
  a contener el subsistema de sonido (`CODE_8A3F`/`CODE_E1F9`) y el
  payload de portada compartido (`$EA60-$EFB5`).
- Resto de la lista heredada de sesiones 40-48 sin cambios.

## Sesión 52 — 2026-08-13: niveles extraídos a `data/niveles/*.bin` + `mmlvl_tool.py` (adaptada de MSX)

El usuario recordó que el proyecto MSX ya pasó por este mismo punto:
sacó los datos de nivel a ficheros binarios individuales, con una
herramienta Python (`mmlvl_tool.py`) para convertir entre binario y
un formato de texto legible (rejilla hex) y viceversa, con
verificación de ida y vuelta (roundtrip). Pidió comprobar si los
datos de nivel son idénticos entre plataformas y, si es así,
organizar este proyecto igual, reutilizando/adaptando esas
herramientas.

### Confirmado: los 18 ficheros son IDÉNTICOS byte a byte a MSX

Comparación directa de los 15 cuerpos + 3 cabeceras (extraídos de
`FISICO/CODE.bin` en las direcciones ya localizadas en sesiones
50/51) contra los ficheros correspondientes de
`MSX/proyectos/madmixgame/src/data/niveles/`: **coincidencia exacta
en los 18**, ni un bit de diferencia. Confirma una vez más
[[madmix_spectrum_is_original]] — MSX no solo reutilizó gráficos,
tablas de animación y tablas de teclado del Spectrum original: los
**laberintos completos de los 16 niveles** son la misma copia
literal.

### `data/niveles/` + `mmlvl_tool.py`

Extraídos los 18 ficheros (`body_l01.bin`...`body_l15.bin`,
`header_7f1f.bin`/`header_7f7f.bin`/`header_8000.bin` — nombres de
cabecera por dirección PROPIA de Spectrum, ya que las de MSX
—`header_4afc.bin` etc.— no significan nada aquí) a
`src/data/niveles/`. Adaptada `mmlvl_tool.py` de MSX: mismo formato
de fichero de texto (rejilla hex de 32 columnas, cabecera con
`; filas=N columnas=N`, verificación de tamaño fijo), mismos 5
comandos (`disasm`/`asm`/`roundtrip`/`roundtrip-all`/
`check-bolitas`) — solo cambian las rutas (`madmix_scr_body.asm` →
`madmix_body.asm`, `data/tiles/` → `data/img/tiles/`) y el nombre de
la tabla a parsear (`LEVEL_TABLE` → `TABLA_NIVELES`).

**Verificación cruzada exhaustiva**: los 18 ficheros pasan
`roundtrip-all` sin fallos, y `check-bolitas` confirma, para los 16
niveles (incluido el índice 0, registro muerto), que el recuento real
de losetas "con bola" coincide EXACTO con el objetivo declarado en
`TABLA_NIVELES` — validación cruzada de la tabla (sesión 47), los
punteros de nivel (sesiones 50/51) y el catálogo de tipos de loseta
(`TABLA_TIPOS_LOSETA`, sesión 44) todo a la vez, sin ningún desajuste.

`madmix_body.asm` actualizado: los 18 bloques `DB` de datos de nivel
sustituidos por `INCBIN "data/niveles/NOMBRE.bin"`, mismo patrón que
sprites/losetas (sesiones 41/42).

**Verificado**: recompiló sin errores (el log de compilación confirma
los 18 `include data:` con el tamaño exacto de cada uno) y **0
diferencias, 48485 bytes idénticos al `.tzx` original**. Inventario
sin cambios de fondo (622 etiquetas — mover de `DB` a `INCBIN` no
altera el total). Actualizado `mapa_memoria.html`.

### Pendiente para próximas sesiones

- Decodificar tile a tile el contenido de los 16 laberintos (la
  herramienta ya está lista — `mmlvl_tool.py disasm` da la rejilla
  legible de cada nivel).
- Resto de la lista heredada de sesiones 40-51 sin cambios.

## Sesión 53 — 2026-08-13: `$DBE0-$EFB5` delimitado con precisión (sin desensamblar) — candidato a subsistema de sonido

Continuación pedida por el usuario ("sigue") del último tramo grande
sin analizar. A diferencia de todo lo resuelto en sesiones 39-52,
este tramo **no tiene equivalente MSX que cruzar** (chips de sonido
distintos en cada plataforma, ver
[[madmix_sound_chip_differences_expected]]) — un desensamblado manual
completo llevaría bastante más esfuerzo por byte, sin la red de
seguridad de comparar contra MSX. Se preguntó al usuario cómo seguir;
eligió **delimitar y documentar con precisión, sin desensamblar en
detalle todavía**.

### Lo que se confirmó (por bytes, no a ojo)

- **`$DBE0-$E037` (1112 bytes)**: estructura de datos claramente NO
  aleatoria — bloques pequeños que se repiten casi idénticos (ej.
  `$DC60-$DC8D` reaparece prácticamente igual en `$DCD0-$DCFB`),
  varios centinelas `$FFFF`, y un sub-bloque muy regular de 3 en 3
  bytes con prefijo `$FD` (candidato a tabla de punteros indexada por
  `IY`). Candidato razonable a datos/guión del generador de sonido,
  en el mismo espíritu que `GUION_MELODIA_CANAL_0/1/2` de MSX (guiones
  de sonido por canal) — pero sin tabla equivalente que comparar byte
  a byte, al ser chips distintos.
- **`$E038-$EFB5` (3966 bytes)**: es código Z80 real, confirmado por
  búsqueda exacta de bytes (no por vistazo): la secuencia
  `DI/PUSH AF/PUSH BC/PUSH DE/PUSH HL/LD A,0/OR A` empieza exactamente
  en `$E038`, justo al terminar el bloque de datos anterior sin
  hueco. Cerca de `CODE_E1F9` (el candidato a generador de tono ya
  señalado en sesiones previas) hay una instrucción `OUT ($FE),A` —
  el puerto del altavoz/border del Spectrum — que encaja con esa
  hipótesis.

Ambos límites están verificados por aritmética/búsqueda de bytes
exacta, no por impresión visual — mismo nivel de rigor que el resto
de la sesión, aunque el CONTENIDO semántico de ambos tramos sigue sin
resolver.

**Verificado**: no hubo cambios de código fuente más allá de un
comentario — recompiló sin errores y **0 diferencias, 48485 bytes
idénticos al `.tzx` original** (invariante, ya que no se tocó ningún
byte de datos). `mapa_memoria.html`: el segmento único de 5078 bytes
se parte en dos (1112 B datos + 3966 B código), ambos categoría
mecánico, con el límite exacto documentado.

### Pendiente para próximas sesiones

- Desensamblado manual completo de `$E038-$EFB5` (subsistema de
  sonido) — candidato a sesión dedicada, sin equivalente MSX,
  siguiendo la misma técnica manual usada en sesiones 40-41 para
  `HNDLR_MARICOCO`/`HNDLR_REGPUNANTOSO` (verificación por convergencia
  de saltos en vez de comparación cruzada).
- Interpretar la estructura de datos de `$DBE0-$E037`.
- Resto de la lista heredada de sesiones 40-52 sin cambios.

## Sesión 54 — 2026-08-13: `PROCESAR_MENU_CONTROLES` (427 B) resuelto por completo — desensamblado manual, y `MODO_ENTRADA` descubierta

Pedido explícito del usuario: "analiza TABLA_MENU_OPCIONES_CONTROL".
A diferencia del subsistema de sonido (sesión 53), este bloque **sí
se desensambló en detalle** — sin equivalente MSX que cruzar (el
menú de selección de teclado/joystick es propio de Spectrum, MSX no
tiene pantalla equivalente), pero con `FISICO/CODE.bin.dasm.txt`
disponible como base fiable de límites de instrucción para este
tramo concreto, y verificación por convergencia de todos los saltos
internos — misma técnica manual usada en sesiones 40-41 para
`HNDLR_MARICOCO`/`HNDLR_REGPUNANTOSO`.

### Estructura resuelta

`PROCESAR_MENU_CONTROLES` ($8A20) dibuja el menú de controles
(`TABLA_MENU_OPCIONES_CONTROL`, ya localizada en sesión 46/47, con
las 6 cadenas de texto "1 TECLADO"/"2 KEMPSTON"/"3 SINCLAIR-SJS"/
"4 REDEFINE TECLAS"/"5 DEMO"/"0 JUGAR"), espera tecla con un límite
de pasadas (`DJNZ`, 70 iteraciones de un retardo fijo por `LDIR`
ficticio), lee las 6 teclas de opción (`TABLA_TECLAS_MENU`, $8BAB,
mismo mecanismo que `LEER_ENTRADA`/`ESCANEAR_FILAS_TECLADO` de
sesión 26/45 pero con su propia tabla de 6 pares puerto/máscara) y
despacha a la opción elegida, resaltando el texto activo en pantalla
(atributo `$47`=resaltado, `$42`=normal) y guardando el modo en
`MODO_ENTRADA`. Si no se pulsa ninguna tecla de opción durante
`TEMPORIZADOR_DEMO_MENU` pasadas completas (arranca en 500), se
reinicia el menú entero — candidato a disparar la demo automática.

Etiquetas nuevas: `PROCESAR_MENU_CONTROLES`, `BUCLE_ESPERA_TECLA_MENU`,
`TECLA_DETECTADA_MENU`, `LEER_TECLA_MENU`, `REINICIAR_TEMPORIZADOR_DEMO`,
`GUARDAR_TEMPORIZADOR_DEMO`, `TEMPORIZADOR_DEMO_MENU`,
`LIMPIAR_PANTALLA_MENU`, `BUCLE_LIMPIAR_FRANJA_MENU`,
`DESPACHAR_OPCION_MENU`, `DIBUJAR_TEXTOS_MENU`, `SELECCIONAR_TECLADO`,
`SELECCIONAR_DEMO`, `SELECCIONAR_SINCLAIR`, `SELECCIONAR_KEMPSTON`,
`SELECCIONAR_REDEFINIR`, `LEER_TECLADO_MENU`, `TABLA_TECLAS_MENU`,
`FINALIZAR_MENU_CONTROLES`, `MODO_ENTRADA`.

Mapa bit→opción en `DESPACHAR_OPCION_MENU` (el orden de bits sigue
el orden físico de `TABLA_TECLAS_MENU`, no la numeración visual del
menú): bit0=JUGAR(0), bit1=TECLADO(1), bit2=SINCLAIR(3),
bit3=KEMPSTON(2), bit4=REDEFINE(4), bit5=DEMO(5).

### Dos hipótesis corregidas

- **`CODE_8A3F`** (candidata desde sesión 40 a "`VACIAR_CANALES_SONIDO`"
  por su posición): en realidad es `LEER_TECLA_MENU`, un segundo
  punto de entrada al mismo menú (salta directo a leer teclas sin
  repetir el parpadeo inicial). Se llama en vivo desde `CODE_9C07`
  (rutina de reinicio de partida) para volver a procesar el menú de
  controles al reiniciar — sin relación con sonido. Hipótesis
  descartada.
- **`CODE_8A6C`**: es `LIMPIAR_PANTALLA_MENU`, reutilizada fuera del
  menú de controles como limpiador de pantalla genérico en otro punto
  del código de reinicio.

### `MODO_ENTRADA` descubierta ($91B9)

Lo que la sesión 34 documentó como "23 bytes de puro relleno" tras
`TABLA_SALTOS_MOTOR` resulta ser, en su primer byte, una variable
real: `MODO_ENTRADA` (candidata desde sesión 26/45 por su uso en
`LEER_ENTRADA`), confirmada aquí porque `PROCESAR_MENU_CONTROLES` la
escribe y lee. Valores: 0=teclado (QAOP), 1=Sinclair-SJS, 2=Kempston,
cualquier otro=redefinir teclas. Compila a 0 (modo por defecto). Los
22 bytes restantes del bloque siguen sin verificar en detalle.

### Error propio detectado y corregido antes de reportar

Al convertir el primer byte del relleno en `DB $00` (variable
`MODO_ENTRADA`), escribí solo 21 `NOP` en vez de 22 para completar
los 23 bytes originales — el fichero quedó 1 byte corto (36789 en
vez de 36790) y `gen_tzx_file.py` reportó una diferencia arrancando
en `$6001` con ~20427 bytes desplazados. Diagnosticado comparando
`FISICO/CODE.bin` contra `src/build/CODE.bin` byte a byte, localizado
el byte que faltaba, añadido el `NOP` que faltaba. El desensamblado
de `PROCESAR_MENU_CONTROLES` en sí fue exacto a la primera — el error
estaba aislado en esta edición previa y no relacionada.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original**. `py tools/gen_inventory.py` → **641 etiquetas**
(subía desde 622). `mapa_memoria.html`: el segmento de 427 bytes pasa
de categoría mecánico a código con el detalle completo; el segmento
de "relleno 23 B" se parte en `MODO_ENTRADA` (1 B, código) + relleno
(22 B, sin explorar); verificada contigüidad de segmentos (sin huecos
ni solapes) y recalculado el total mecánico restante: 6652 bytes en
cinco tramos (antes 7079 en seis).

### Pendiente para próximas sesiones

- `CODE_8DE5`, `CODE_918D`, `CODE_8EB3` — referenciadas desde el menú
  pero sin resolver, caen dentro del tramo mecánico $8C1F-$9198 aún
  sin convertir.
- `CODE_8C1F`/`CODE_8D68` — llamadas desde `SELECCIONAR_TECLADO`, sin
  resolver (dibuja texto adicional en $8D1C, candidato a pantalla de
  confirmación "controles guardados").
- Desensamblado manual del subsistema de sonido (`$E038-$EFB5`) sigue
  diferido por elección explícita del usuario (sesión 53).
- Resto de la lista heredada de sesiones 40-53 sin cambios.

## Sesión 55 — 2026-08-14: `MOTOR DE SONIDO` (`$E038-$E37F`, 840 B) resuelto por completo

Pedido explícito del usuario ("vamos a por la parte de sonido"),
retomando lo delimitado-pero-no-desensamblado en sesión 53. Se
preguntó de nuevo el alcance (la sesión 53 había quedado en "solo
delimitar"); el usuario eligió **desensamblado manual completo**.

### Hallazgo principal: el alcance de sesión 53 era demasiado amplio

Sesión 53 había concluido que los 3966 bytes de `$E038-$EFB5` eran
"código real confirmado", basándose en encontrar el prólogo
`DI/PUSH AF/PUSH BC/PUSH DE/PUSH HL` exactamente en `$E038` mediante
búsqueda de bytes. Ese hallazgo solo demostraba que el tramo
**empezaba** con código real, no que los 3966 bytes completos lo
fueran. El desensamblado manual (instrucción a instrucción, usando
`FISICO/CODE.bin.dasm.txt` como apoyo donde era código real, y
lectura directa de bytes vía Python para las zonas de tabla/datos)
reveló que el motor real ocupa solo **840 bytes** (`$E038-$E37F`);
el resto (`$E380-$EFB5`, 3718 bytes) es más datos — guiones de
canción/SFX concatenados, con el mismo formato y estilo de bytes
pequeños y repetitivos que `$DBE0-$E037` (ya delimitado en sesión
53). Señal estadística que lo confirma: el byte `$01` aparece 1049
veces en los 3966 bytes originales (26.5%), un sesgo extremo típico
de datos estructurados, no de código a mano.

### Arquitectura del motor (sin equivalente MSX — usa el PSG
AY-3-8910, ver [[madmix_sound_chip_differences_expected]])

Motor de 2 "canales" dirigido por interrupción, patrón clásico de
reproductor de altavoz en Spectrum 48K:

- **`ISR_SONIDO`** ($E038) se instala como el vector de interrupción
  modo 2 real del juego (parchea `$6061-$6062`, guardando el valor
  anterior en `ISR_VECTOR_GUARDADO` para restaurarlo al terminar) —
  se reejecuta en cada interrupción (50 veces/seg) mientras el
  sonido está activo. Cada tick decrementa 2 contadores de duración
  (uno por canal); cuando un contador llega a 0, lee el siguiente
  byte de guion del canal (vía `IX`/`IY`) y lo despacha.
- **Canal A** (`IX`): generador de TONO/melodía. Bytes de guion:
  "notas" (bits0-5 = índice en `TABLA_TONOS_CANAL_A`, bits6-7 =
  índice en `TABLA_DURACIONES`) o comandos especiales `$FF` (fin),
  `$FE` (reset), `$FD`/`$FC` (llamada/retorno a subpatrón vía pila
  privada), `$FB`/`$FA` (2 parches de código automodificable para
  variantes de vibrato/tempo).
- **Canal B** (`IY`): generador de PERCUSIÓN. Bytes de guion usan
  bits0-2 como índice (0-7) en `TABLA_PERCUSION`, tabla de saltos a
  solo **4 rutinas de ruido reales** (cada una duplicada dos veces,
  ocupando las 8 entradas) que hacen `OUT ($FE),A` directamente
  durante la propia interrupción — percusión corta, no usa el bucle
  de primer plano.
- El TONO real de canal A no lo genera la interrupción, sino un
  **bucle activo en primer plano** (`BUCLE_TONO_CANAL_A`) que
  alterna el altavoz continuamente mientras no se pulse ninguna
  tecla. `REPRODUCIR_SONIDO` (el punto de entrada externo real,
  antes `CODE_E1F9`, llamado 4 veces desde `INICIO`/`CODE_9C22`/
  `BUCLE_PRINCIPAL_JUEGO`) cae directamente en él una vez configurado
  todo, y no vuelve hasta que el guion señala "terminado" o el
  jugador pulsa una tecla. La ISR preserva `AF`/`BC`/`DE`/`HL` en su
  prólogo precisamente para no romper los contadores del bucle activo
  mientras lo interrumpe — el porqué de ese `PUSH`/`POP` específico
  quedó resuelto de paso.
- `TABLA_TONOS_CANAL_A` (64 palabras, 41 en uso real): periodos de
  tono en escala cromática descendente (razón ≈1.06 entre entradas
  consecutivas — coincide con 2^(1/12), la escala temperada de 12
  semitonos).

### Truco de código automodificable (×3), ahorro típico de memoria en 8 bits

1. Los contadores de duración de cada canal son el operando
   inmediato de sendas `LD A,n` (`FLAG_DURACION_CANAL_A`/`_B` en
   `$E03E`/`$E048`) — la propia ISR los parchea directamente en vez
   de usar una variable aparte.
2. Los punteros de guion de cada canal son el operando de
   `LD IX,nn`/`LD IY,nn` en `REPRODUCIR_SONIDO` (`$E212`/`$E216`) —
   por eso quien llama (`INICIO`, `CODE_9C22`, `BUCLE_PRINCIPAL_JUEGO`)
   escribe ahí con `LD ($E212),HL` antes del `CALL`, en vez de pasar
   parámetros por registro.
3. Los comandos `$FB`/`$FA` de canal A no cargan un parámetro: **
   sobrescriben 8 bytes de código ejecutable** dentro del propio
   bucle de tono (`TONO_PATRON_BASE`, `$E24D-$E254`) con una de 2
   variantes precompiladas (`COPIAR_PATRON_TONO`/`PATRON_TONO_1`/`2`).

### Dos hipótesis corregidas/cerradas

- `CODE_E1F9` (candidato a generador de tono desde sesión 1) es
  `REPRODUCIR_SONIDO` — confirmado y completamente resuelto.
- El comentario de `INICIO` que especulaba con que MSX "añadió" una
  llamada a `DIBUJAR_PORTADA` sigue válido; se retiró solo la nota
  pendiente sobre `CODE_E1F9`, ya cerrada.

### Detalle sin confirmar (documentado como tal, no bloqueante)

`PERCUSION_3`/`PERCUSION_4` leen una tabla de 2 valores por
iteración desde `$0280` (zona de sistema en RAM baja) en vez de
calcularla por fórmula como `PERCUSION_1`/`PERCUSION_2` — no se pudo
confirmar qué la rellena ni por qué esa dirección en concreto.

### Error propio detectado y corregido antes de reportar

Al colocar la etiqueta `TONO_PATRON_BASE` la puse un `LD` antes de
donde correspondía (delante de `LD ($E25C),BC` en vez de
`LD ($E26E),DE`), desplazando su dirección 4 bytes y rompiendo la
referencia `LD DE,TONO_PATRON_BASE` de `COPIAR_PATRON_TONO`. El
primer intento de verificación reportó exactamente 2 bytes distintos
en offset `0xB030` (`$4D`→`$49`, el byte bajo de esa dirección) —
diagnóstico inmediato por la precisión del diff, corregido moviendo
la etiqueta a la instrucción correcta.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original**. `py tools/gen_inventory.py` → **690 etiquetas**
(subía desde 641). `mapa_memoria.html`: el segmento único de 3966
bytes se parte en `MOTOR DE SONIDO` (840 B, código) + guiones de
canción/SFX sin decodificar (3718 B, mecánico); contigüidad de
segmentos verificada (sin huecos ni solapes); total mecánico
restante recalculado: 5812 bytes en seis tramos (antes 6652 en
cinco).

### Pendiente para próximas sesiones

- `CODE_8DE5`, `CODE_918D`, `CODE_8EB3`, `CODE_8C1F`/`CODE_8D68` —
  heredado de sesión 54, sin cambios.
- Decodificar cancion por canción los guiones de `$DBE0-$E037` y
  `$E380-$EFB5` (4830 bytes combinados) — de valor bajo dado que no
  hay equivalente MSX que cruzar; posible candidato a un pequeño
  reproductor/analizador en Python si en algún momento interesa
  escuchar las melodías reconstruidas en vez de leerlas.
- Resto de la lista heredada de sesiones 40-54 sin cambios.

## Sesión 56 — 2026-08-14: `tools/mmsnd_tool.py` + 49 guiones extraídos, y corrección importante del motor de tono

Pedido explícito del usuario: repetir con el sonido lo mismo que se
hizo con los niveles en MSX (herramientas Python para convertir
binario↔texto). Investigación previa del proyecto MSX (`mmsnd_tool.py`/
`mmsnd_render.py`) confirmó que el formato Spectrum es **más simple**:
al tener marcador de fin explícito (`$FF`) dentro del propio guion, no
hace falta el mapa de direcciones externo que necesitaba MSX.

### `tools/mmsnd_tool.py` (nueva herramienta)

Adaptado del patrón de `mmlvl_tool.py`: `disasm`/`asm`/`roundtrip`/
`roundtrip-all`. Formato de una instrucción por línea: `NOTE 0xNN`,
`END`, `RESET`, `CALL 0xNNNN` (dirección absoluta de 16 bits a otro
guion/subpatrón), `RETURN`, `PATCH1`, `PATCH2` — mapeo directo de los
6 comandos del motor resuelto en sesión 55.

### 49 fragmentos localizados y extraídos

Trazando los 3 guiones ya conocidos por sus 3 pares de punteros
($DFB7/$DFCA, $E007/$E00E, $E015/$E01C — los únicos 4 sitios de
`LD ($E212)`/`LD ($E216)` de todo el fichero) y siguiendo
recursivamente cada comando `CALL` ($FD), aparecieron **49
fragmentos** (6 guiones reales + 43 subpatrones compartidos) que
encajan de forma EXACTA y sin ningún hueco entre `$DD18` y `$E023`
(779 bytes) — mismo patrón de "canciones + subpatrones reutilizados"
que ya usa MSX, solo que aquí las llamadas son direcciones absolutas
en vez de índices de tabla. Extraídos a `src/data/sound/snd/*.snd`
(los 6 guiones, nombrados por canción/canal) y
`src/data/sound/spt/*.spt` (los 43 subpatrones, nombrados por
dirección y canal alcanzable), con roundtrip 100% correcto en los 49.

**Pendiente sin resolver**: el bloque de datos total es de ~4830
bytes (`$DBE0-$E037` + `$E380-$EFB5`); estos 49 fragmentos solo
cubren 779. El resto (~4000 bytes) casi seguro son más guiones, mas
no se ha localizado todavía qué los dispara — los 4 sitios de llamada
conocidos son los únicos que escriben directamente en
`$E212`/`$E216`; candidato a una tabla de eventos (al estilo
`TABLA_RECURSOS_SONIDO_EVENTO` de MSX) todavía sin encontrar.

### Corrección importante: el motor SÍ usa la tabla de tonos

Al diseñar el renderizador WAV, verificando a mano el bucle de tono
(`BUCLE_TONO_CANAL_A`) no encontré ninguna lectura de `$E23E` (donde
`CANAL_A_NOTA` guarda el periodo de `TABLA_TONOS_CANAL_A`) — parecía
que el bucle usaba siempre `BC=$0000`/`DE=$FFFF` fijos, sin importar
la nota. Antes de asumir que el motor no usaba la tabla de tonos (una
conclusión rara dado que la tabla es una escala cromática clara), el
usuario pidió investigar más a fondo en vez de generar audio sobre
una suposición sin confirmar.

Escribí un **simulador Z80 mínimo** en Python (solo las ~35
instrucciones que aparecen en este bloque de 840 bytes, con memoria
mutable real cargada de `FISICO/CODE.bin` e interrupciones simuladas
a 50 Hz) para ejecutar el motor de verdad con un guion real
(`$DFB7`/`$DFCA`) y observar `BC`/`DE` en tiempo de ejecución. Resultado:
`BC` arranca en `$00FB` — exactamente el valor que `CANAL_A_NOTA`
acababa de escribir en `$E23E`, no en `$0000`.

**La explicación**: es un CUARTO caso de código automodificable (los
otros 3 ya documentados en sesión 55) que se me pasó por alto en el
análisis manual — la instrucción que yo transcribí como
`LD BC,$0000` vive exactamente en `$E23D`, así que sus propios bytes
de operando ocupan `$E23E-E23F`: la MISMA dirección donde
`CANAL_A_NOTA` escribe el periodo real. El valor `$0000` que veía en
el binario no era "el bucle ignora la tabla", era solo el valor de
compilación por defecto de un operando que se sobreescribe en tiempo
de ejecución. El mismo patrón se repite dos veces más: `$E25C`
(operando de un segundo `LD BC,$0000` dentro del propio bucle, recarga
tras cada conmutación) y `$E26E` (equivalente para `DE`, el
semiperiodo) — ambos escritos una vez al principio con el periodo
real, para que el bucle recargue con el periodo correcto en vez de
con cero cada vez que conmuta.

Verificación de frecuencia con el simulador: periodo `$00FB` (251) →
**~277 Hz** (Do#4 real = 277.18 Hz), periodo `$013C` (316) → **~209
Hz** (Sol#3 real = 207.65 Hz) — coincide con notas musicales reales y
con la proporción de la escala cromática de la tabla. El bucle usa
DOS contadores independientes (`BC`=periodo completo, `DE`=medio
periodo) conmutando el mismo bit de altavoz a tasas relacionadas, no
un cuadrado puro de un solo contador.

Corregidos los comentarios de `BUCLE_TONO_CANAL_A`/`CANAL_A_NOTA` en
`madmix_body.asm` y la cabecera de sección del motor de sonido
(pasaba de "3 casos de automodificación" a 4).

**Verificado**: los cambios de esta sesión son solo comentarios y
ficheros nuevos fuera de `madmix_body.asm` (la extracción no toca los
bytes ya presentes) — `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (invariante). `py tools/gen_inventory.py` → 690
etiquetas (sin cambio, no se añadieron etiquetas nuevas esta sesión).

### `tools/mmsnd_render.py` (construido en la misma sesión, tras la corrección)

En vez de reimplementar la lógica del reproductor a mano en Python
(como hizo la herramienta homónima de MSX), esta ejecuta el motor
ORIGINAL de verdad: el mismo simulador Z80 mínimo usado para
investigar el bug de arriba, formalizado como módulo del tool,
corriendo sobre una copia real de `FISICO/CODE.bin` con interrupciones
a 50 Hz, registrando cada `OUT ($FE),A` real (bit 4 = altavoz) para
reconstruir la onda cuadrada. Evita por diseño el tipo de error de
interpretación manual que motivó la investigación.

Comandos: `render fichero.snd salida.wav [--channel A|B]` (un canal
aislado, el otro silenciado), `render-pair canalA.snd canalB.snd
salida.wav` (ambos canales mezclados, el sonido real del juego),
`render-all carpeta/ salida/` (por lotes). Acepta tanto `.snd`/`.spt`
binarios como `.txt` ya editados (los ensambla con `mmsnd_tool.py`
antes de simular) — permite escuchar el resultado de un cambio antes
de recompilar el juego.

**Detalle importante**: silenciar canal A con un simple `$FF` (fin de
guion) dispara `DETENER_SONIDO` y apaga el motor entero antes de que
canal B llegue a sonar (mismo mecanismo de la sección "Corrección
importante" de arriba) -- el guion "vacío" de canal A tuvo que ser una
tirada larga de `$FE` (reinicio, no termina nada) en vez de `$FF`.
Detectado y corregido probando los 43 subpatrones por lotes: los de
canal B daban 0 eventos hasta aplicar este arreglo.

Verificado con los 3 guiones reales (mezclados y por canal) y los 43
subpatrones: todos producen audio real (2 niveles, cientos-miles de
transiciones, nada de silencio permanente ni saturación). Sin cambios
en `madmix_body.asm` en esta parte -- **0 diferencias** se mantiene
invariante (herramienta nueva en Python, no toca la fuente Z80).

### `DESPACHAR_EFECTO_SONIDO` ($8F55-$9049, 245 B) — tercer subsistema de sonido, resuelto por completo

Buscando el disparador de los guiones restantes (tarea de arriba),
una búsqueda por bytes de `OUT ($FE),A` en TODO el binario (no solo
en el motor ya resuelto) encontró 3 ocurrencias fuera de la zona
conocida, dentro del tramo `$8C1F-$9198` ya marcado como "sin
analizar". No resolvían la pregunta original, pero resultaron ser
algo más relevante: un **tercer subsistema de sonido**, completamente
distinto del motor de música (`ISR_SONIDO`) y del ciclador de demo
(`CODE_8EB3`) — mucho más simple (un solo "canal", sin comandos de
guion ni subpatrones) y de propósito claramente distinto: efectos de
sonido cortos de jugabilidad, no música.

**La pieza que faltaba ya estaba medio resuelta**: `EVENTO_SONIDO_PENDIENTE`
(`$8FD6`) ya era una variable conocida desde **sesión 39**, con el
mismo nombre exacto que MSX, escrita desde **24 sitios** de código ya
resuelto (sobre todo `TABLA_MANEJADORES_LOSETA` y
`ACTIVAR_EFECTO_ITEM`) — pero su CONSUMIDOR nunca se había
identificado. Resulta ser `DESPACHAR_EFECTO_SONIDO` (antes
`CODE_8F55`), ya completamente desensamblado por una sesión anterior
(con etiquetas `CODE_8F55`/`CODE_8F62`/`CODE_8F76`/etc. y hasta
referenciando `EVENTO_SONIDO_PENDIENTE` por nombre) pero sin
documentar ni renombrar — solo hacía falta conectar los dos lados y
ponerle nombre.

**Mecanismo**: `DESPACHAR_EFECTO_SONIDO` se llama **una vez por
interrupción** desde `ENTRADA_INTERRUPCION_VBLANK` (`$9510`, la ISR
normal del juego — cierra una pregunta abierta desde la sesión 1
sobre qué hacían sus 2 CALL). Si `EVENTO_SONIDO_PENDIENTE` tiene un
índice nuevo (`0-11`, distinto de `$FF`), lo busca en
`TABLA_RECURSOS_SONIDO_EVENTO` (mismo nombre exacto que la tabla
homóloga de MSX, aunque más simple: 12 punteros directos en vez de
registros de 3 bytes canal+puntero) y lo instala como "efecto
activo"; siempre avanza el efecto activo un paso, leyendo pares
`(duración,periodo)` hasta un `$FF` de fin. El generador de tono
(`INICIAR_TONO_EFECTO_SONIDO`) reutiliza el MISMO truco de contadores
duales automodificables que `BUCLE_TONO_CANAL_A` del motor de música
(periodo completo + medio periodo, recarga automodificable en vez de
a cero), con un tercer contador (`HL`) para la duración en vez de
delegarla a un flag de ISR — lógico, al no tener canales que
multiplexar. Mismo bit de altavoz (`XOR $10` = bit 4).

**Datos**: 10 guiones de efecto únicos (algunos compartidos por 2
índices de la tabla) más 1 guion "huérfano" (`$9003`) con el mismo
formato pero sin ninguna entrada de la tabla que lo referencie —
candidato a efecto retirado/sin usar, documentado como tal sin
confirmar.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original**. `py tools/gen_inventory.py` → **698 etiquetas**
(subía desde 690). `mapa_memoria.html`: el tramo de 1401 bytes
`$8C1F-$9198` se parte en tres (822 B + 245 B resueltos + 334 B);
contigüidad verificada; total mecánico restante recalculado: 5567
bytes en siete tramos (antes 5812 en seis).

### Pendiente para próximas sesiones

- Localizar el disparador de los ~4000 bytes de guiones restantes del
  motor de música (`$DBE0-$DD17`, `$E023-$E037`, `$E380-$EFB5`) —
  sigue sin resolver; la búsqueda por bytes de `OUT ($FE),A` en todo
  el binario ya está agotada (solo aparecen las ocurrencias ya
  identificadas: percusión+tono del motor de música, y el nuevo
  `DESPACHAR_EFECTO_SONIDO`).
- `CODE_9121`/`CODE_918D` siguen sin resolver, dentro del tramo `$904A-$9198`.
- `CODE_9534` (mantenimiento cada 256 interrupciones) sin resolver del todo.
- Resto de la lista heredada de sesiones 40-55 sin cambios.

## Sesión 56 (continuación) — `INICIAR_DEMO` resuelto por completo — corrige la caracterización de `$DBE0-$DD17`

Pedido explícito del usuario ("seguimos") tras cerrar
`DESPACHAR_EFECTO_SONIDO`. Investigando el mismo tramo mecánico
vecino (`$8C1F-$9198`) para entender el resto de llamadas de
`CODE_8EB3` (candidato desde sesión 40/54 a "arrancar demo/ciclador
de niveles"), resultó que ya estaba desensamblado a mano por una
sesión anterior (etiquetas `CODE_8EB3`/`CODE_8EBD`/`CODE_8EC7`/etc.,
solo sin renombrar ni documentar) — igual que pasó con
`DESPACHAR_EFECTO_SONIDO` unas horas antes.

### `INICIAR_DEMO` (antes `CODE_8EB3`, $8EB3-$8F54, 162 bytes)

Ciclador de niveles pregrabados para el modo demo/atracción (opción
"5 DEMO" del menú de controles, `SELECCIONAR_DEMO`). Recorre
`TABLA_PERFILES_DEMO` (4 entradas: niveles 1, 2, 4 y 5 — el 3 no
tiene perfil propio) cargando cada nivel con `CARGAR_NIVEL` y
reproduciendo un **guion de entrada pregrabado** en vez de leer el
teclado real — confirma de golpe la hipótesis abierta desde sesión
37/45 sobre `INDICE_CICLO_NIVELES` ("guion pregrabado si está activo,
mismo patrón que el ciclador de demo de MSX"). Formato del guion:
pares `(umbral_frames,dirección)`, ambos en decimal, terminados en
`$FF,$FF` — cada frame se incrementa un contador y se compara contra
el umbral del par activo; al alcanzarlo, se avanza al siguiente par y
la dirección se pasa a `MOTOR_MOVIMIENTO_COLISION`.

### Corrección importante: `$DBE0-$DD17` NO son datos de sonido

Los 4 punteros de `TABLA_PERFILES_DEMO` lo confirman sin ambigüedad:
3 caen dentro de `$DBE0-$DD17` (312 bytes, el tramo que las sesiones
53/55 habían caracterizado como "datos/guion del generador de
sonido" por compartir el mismo estilo de bytes pequeños y repetitivos
que la zona de sonido vecina) y el cuarto (nivel 5) apunta a
**`$E380`** — exactamente el inicio del otro tramo marcado "guiones
de canción/SFX sin decodificar". Trazando los 4 guiones por su propio
formato (parada en `$FF,$FF`) se localizaron con precisión:

- `GUION_DEMO_NIVEL_1` ($DBE0, 64 B), `GUION_DEMO_NIVEL_2` ($DC20,
  94 B), `GUION_DEMO_NIVEL_4` ($DC90, 66 B), `GUION_DEMO_NIVEL_5`
  ($E380, 88 B) — los 4 indexados por `TABLA_PERFILES_DEMO`.
- 4 guiones más con el mismo formato pero **sin índice conocido** que
  los referencie (`GUION_DEMO_EXTRA_1-4`, 18+4+24+18 bytes) — candidato
  a tomas descartadas o una versión antigua del ciclo de demo.
- `$DD00-$DD17` (24 B): relleno a cero antes del motor de música real
  (`$DD18`, ya confirmado sesión 55).

Esto **corrige** la caracterización de sesiones 53/55: `$DBE0-$DD17`
no tiene nada que ver con el motor de sonido; es un subsistema
totalmente distinto (grabación/reproducción de entrada) que
simplemente comparte el mismo "estilo de bytes pequeños" por
coincidencia de formato (ambos usan pares terminados en `$FF`). La
pregunta original de esta sesión ("qué dispara los guiones de canción
restantes") se queda sin resolver para la música en sí, pero de paso
se resolvió qué eran realmente 400 de esos bytes.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original**. `py tools/gen_inventory.py` → **706 etiquetas**
(subía desde 698). `mapa_memoria.html`: el tramo `$8C1F-$8F55` se
parte en dos (660 B sin analizar + 162 B `INICIAR_DEMO`); `$DBE0-$E038`
se parte en `GUION_DEMO` (312 B, código) + guiones de música (800 B,
mecánico); `$E380-$EFB6` se parte en `GUION_DEMO_NIVEL_5` (88 B,
código) + resto sin decodificar (3630 B); contigüidad verificada;
total mecánico restante recalculado: 5005 bytes en siete tramos
(antes 5567 en siete, con distinta repartición).

### Pendiente para próximas sesiones

- Localizar el disparador de los guiones de música restantes
  (`$E023-$E037`, la mayor parte de `$E3D8-$EFB5`) — sigue sin
  resolver, y ahora se suma la duda de si ese resto es música, más
  guiones de demo, o ambos.
- `GUION_DEMO_EXTRA_1-4` sin índice conocido — candidato a investigar
  si vale la pena, bajo valor esperado.
- `CODE_9121`/`CODE_918D`/`CODE_9534` siguen sin resolver.
- Resto de la lista heredada de sesiones 40-55 sin cambios.

## Sesión 56 (continuación 2) — `$E023-$E037` era relleno, y 189 guiones de música más confirmados por fuerza bruta

Pedido explícito del usuario ("sigue"). Cerrado el misterio de
`$DBE0-$DD17` (guiones de demo, no sonido), quedaban dos huecos sin
explicar: `$E023-$E037` (21 bytes) y la mayor parte de
`$E3D8-$EFB5` (~3630 bytes).

### `$E023-$E037`: resuelto — puro relleno

Comprobado byte a byte: los 21 bytes son `$00`. Sin misterio, cierra
ese hueco.

### `$E3D8-$EF9E`: 189 guiones de música más, confirmados por fuerza bruta

En vez de buscar más disparadores (agotado: no hay más sitios que
escriban en `$E212`/`$E216`, ni tabla de eventos equivalente
localizada), se probó **escanear la zona directamente con el propio
formato del motor** en vez de buscar quién la referencia: parar en
cada `END`/`RETURN` ($FF/$FC) y ver si el siguiente byte arranca otro
guion válido, empezando en `$E3D8` y avanzando de forma puramente
mecánica. Resultado: **189 fragmentos consecutivos, 3015 bytes,
CERO fallos** — ni un solo byte suelto, ninguna secuencia inválida,
ningún `CALL` ($FD) roto. Estadísticamente imposible que sea
casualidad — es música real en el mismo formato ya verificado y
escuchado (sesión 55), sin ninguna llamada `CALL` entre fragmentos
(a diferencia de los 49 de `$DD18-$E023`, que se llaman unos a otros
como canción+subpatrones): aquí son 189 frases sueltas.

**Nota honesta**: los primeros ~26 bytes (`$E3D8-$E3F1`) son
ambiguos — también decodifican limpio como 2 guiones de demo cortos
(mismo formato que `GUION_DEMO_EXTRA_1-4`). Se optó por tratar toda
la zona como música (single `$FF`/`$FC`, no pares `$FF,$FF`) porque
esa interpretación es la que se sostiene sin fallos durante los 3015
bytes completos; la alternativa demo se habría atascado enseguida.

**SIN disparador conocido**: a diferencia de los 49 fragmentos de
`$DD18-$E023` (alcanzables desde los 3 guiones ya conocidos) o los 5
guiones de demo (alcanzables desde `TABLA_PERFILES_DEMO`), no hay
ningún sitio del código que instale una dirección de este rango como
guion activo. Candidato: contenido de composición nunca conectado
(sobrante de desarrollo), o un disparador que vive en una parte del
código todavía sin convertir (`$8C1F-$8EB3`, `$904A-$9198`) — no
descartado, pero la búsqueda por bytes ya cubrió toda la superficie
razonable.

Extraídos con `tools/mmsnd_tool.py` a `data/sound/huerfano/*.spt`
(189 ficheros, roundtrip 189/189 OK) y renderizados a WAV con
`tools/mmsnd_render.py` para poder escucharlos.

**Quedan 23 bytes** (`$EF9F-$EFB5`) que no encajan limpio como guion
de música ni de demo — 4 bytes no nulos seguidos de relleno a cero.

**Verificado**: sin cambios en `madmix_body.asm` (extracción pura a
ficheros nuevos) — `py tools/build_all.py`/`gen_tzx_file.py` siguen
en **0 diferencias** (invariante). `mapa_memoria.html`: segmento
`$DD18-$E038` partido en guiones de música (779 B) + relleno resuelto
(21 B); `$E3D8-$EFB6` partido en 189 fragmentos huérfanos (3015 B) +
23 B sin decodificar; contigüidad verificada; total mecánico
recalculado: 4984 bytes en ocho tramos (antes 5005 en siete).

### Pendiente para próximas sesiones

- `$EF9F-$EFB5` (23 B): 4 bytes no nulos sin identificar + relleno.
- Los 189 guiones huérfanos y los 4 guiones de demo huérfanos siguen
  sin disparador conocido — de valor bajo seguir buscando salvo que
  aparezca una pista nueva.
- `CODE_9121`/`CODE_918D`/`CODE_9534` siguen sin resolver, dentro de
  los tramos `$8C1F-$8EB3` y `$904A-$9198`.
- Resto de la lista heredada de sesiones 40-55 sin cambios.

## Sesión 56 (continuación 3) — todos los datos de sonido pasados a `INCBIN`

El usuario señaló que en MSX los datos de sonido extraídos SÍ se
referencian con `INCBIN` desde el fuente (`madmix1_body.asm`), no se
duplican como bytes sueltos además de los ficheros extraídos. En
Spectrum se habían dejado como `DB` inline (con copias aparte solo
para las herramientas), una inconsistencia frente al patrón ya usado
con niveles (`data/niveles/*.bin`) y tiles (`data/img/tiles/*.til`).

Corregido: los 8 guiones de demo (extraídos ahora a
`data/sound/demo/*.bin`, no existían como ficheros hasta ahora), los
49 fragmentos de música de `$DD18-$E023` y los 189 huérfanos de
`$E3D8-$EF9E` pasan todos a `INCBIN`, en el mismo orden exacto en que
aparecen en memoria (sin huecos, verificado). El fuente ya no
duplica esos bytes.

**Verificado**: `py tools/build_all.py` sin errores (246 directivas
`INCBIN` nuevas), `py tools/gen_tzx_file.py` → **0 diferencias, 48485
bytes idénticos al `.tzx` original**. `py tools/gen_inventory.py` →
706 etiquetas (sin cambio, `INCBIN` no añade etiquetas nuevas).

## Sesión 56 (continuación 4) — CORRECCIÓN: los "189 guiones de música huérfanos" eran una imagen

Pedido explícito del usuario ("CODE_918D/CODE_9121"). Investigando
`CODE_9121` (candidato sin resolver desde sesión 54, referenciado
desde el menú de controles junto a `CODE_918D`) para confirmar si era
código real, apareció una llamada real a `CODE_915A` desde `INICIO`
(`CALL CODE_915A`, ya documentada como hipótesis desde sesión 1) que
limpia atributos y descomprime **2992 bytes desde `$E3F2`** hacia
`$4000` (el bitmap de pantalla) mediante un esquema RLE
(valor,repeticiones) — el mismo mecanismo ya visto en `CODE_9174`/
`CODE_918D`, que leen la misma tabla vecina (`$904A`) como atributos
de color.

**`$E3F2` es exactamente la dirección donde empezaban los "189
guiones de música huérfanos"** extraídos hace un rato en esta misma
sesión (`data/sound/huerfano/*.spt`, INCBIN ya insertado en
`madmix_body.asm`). Decodificando esos bytes como RLE de pantalla en
vez de como guion de música: **6140 de los 6144 bytes exactos** de
una pantalla completa del Spectrum, y la tabla de atributos vecina da
**764 de los 768 bytes exactos** de la tabla de atributos — ambas
cifras casi perfectas, la confirmación estadística mucho más fuerte
que la que había antes (la "prueba" de que era música — "3015 bytes,
cero fallos" — no probaba mucho: el formato del reproductor de
música es tan permisivo, todo byte 0x00-0xFF tiene alguna lectura
válida como nota o comando, que casi cualquier dato lo atraviesa sin
errores). Renderizada, la imagen es un marco decorativo de rayas
diagonales rojo/blanco con adornos en las esquinas — ver
`data/img/marco_decorativo/preview.png`.

**Lección para el proyecto**: cuando un formato es tan permisivo que
"decodifica sin fallos" ya no es evidencia fuerte, hace falta otra
prueba — aquí la decisiva fue ejecutar/trazar el código real
(confirmar la llamada de verdad desde `INICIO`) y comprobar que el
tamaño descomprimido cuadra con una pantalla completa, no solo que el
parseo no rompe.

### Corregido

- `$904A-$9159` (272 B): **no** son las etiquetas mecánicas sin
  llamador `CODE_9121`/`CODE_914D`/`CODE_9158` (búsqueda exhaustiva:
  cero referencias externas a ninguna de las 3) — son
  `TABLA_ATRIBUTOS_MARCO_DECORATIVO`, datos RLE de color.
- `CODE_915A`/`CODE_9174`/`CODE_917D`/`CODE_9182`/`CODE_918D`
  renombrados a `CARGAR_MARCO_DECORATIVO`/`APLICAR_ATRIBUTOS_MARCO_COMPLETO`/
  `DESCOMPRIMIR_RLE_ATRIBUTOS`/`DESCOMPRIMIR_RLE_ATRIBUTOS_REPETIR`/
  `APLICAR_ATRIBUTOS_MARCO_PARCIAL` — resuelve la pregunta original
  del usuario: `CODE_918D` es real (descompresor parcial, llamado
  desde el menú), `CODE_9121` **no era código real**, era una
  etiqueta mecánica mal colocada dentro de la tabla de atributos.
- `$E3D8-$EF9E` (189 ficheros `.spt` falsos, borrados) → sustituido
  por `BITMAP_MARCO_DECORATIVO` (`$E3F2-$EFA1`, 2992 B, imagen real) +
  26 bytes en `$E3D8-$E3F1` que siguen sin explicar (candidato:
  todavía podrían ser 2 guiones de demo más, formato compatible, sin
  confirmar) + `$EFA2-$EFB5` (20 B) relleno a cero.

**Ficheros nuevos**: `data/img/marco_decorativo/atributos_904a.bin`,
`bitmap_e3f2.bin` (fuente comprimida real, INCBIN), `preview.png`
(vista previa descomprimida y coloreada, solo documentación).
**Ficheros borrados**: `data/sound/huerfano/` completo (379 ficheros)
y `build/sound_preview/huerfano/` (189 WAV).

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (el cambio es puramente de interpretación/etiquetas,
los bytes ya eran correctos). `py tools/gen_inventory.py` → 705
etiquetas (bajaba desde 706: se retiraron 3 etiquetas mecánicas
falsas y se añadieron menos nuevas). `mapa_memoria.html`: el tramo
`$904A-$9198` (334 B, "sin analizar") y el tramo `$E3D8-$EFB6` (3038
B, "guiones de música") pasan a código/datos resueltos; contigüidad
verificada; total mecánico recalculado: **1612 bytes en cinco
tramos** (antes 4984 en ocho).

### Pendiente para próximas sesiones

- `$E3D8-$E3F1` (26 B): sigue sin confirmar si son 2 guiones de demo
  más o algo distinto.
- `CODE_9534` sin resolver.
- Resto de la lista heredada de sesiones 40-55 sin cambios.

## Sesión 56 (continuación 5) — `REDEFINIR_TECLAS` y `DIBUJAR_CREDITOS_MENU` resueltos ($8C1F-$8EB3)

Pedido explícito del usuario para continuar con `$8C1F-$8EB3` (660
bytes, el tramo "sin analizar" contiguo a `INICIAR_DEMO`). Igual que
`DESPACHAR_EFECTO_SONIDO` e `INICIAR_DEMO`, ya estaba desensamblado a
mano por una sesión anterior con etiquetas `CODE_*` — solo faltaba
nombrarlo y documentarlo.

### `REDEFINIR_TECLAS` (antes `CODE_8C1F`, llamada solo desde `SELECCIONAR_TECLADO`)

Es la pantalla interactiva de la opción **"4 REDEFINE TECLAS"** del
menú de controles. Dibuja 6 líneas (`FUEGO`, `ARRIBA`, `ABAJO`,
`IZQUIERDA`, `DERECHA`, `PAUSA` — los mismos 6 nombres que las 6
entradas de `TABLA_TECLAS_MODO_0`) y, para cada una,
`ESPERAR_TECLA_REDEFINIDA` escanea el **teclado completo** (las 8
filas del puerto ULA, no solo las 5 teclas de juego habituales) hasta
detectar una pulsación, calcula su par real (puerto,máscara de bit) y
lo escribe **directamente en `TABLA_TECLAS_MODO_0`** (`$9B45`). Un
array de 40 bytes (`$8DBA`, uno por tecla física del Spectrum) evita
asignar la misma tecla a dos acciones.

Esto **explica** un detalle que sesión 54 dejó como nota sin resolver:
`SELECCIONAR_REDEFINIR` fija `MODO_ENTRADA=0` (el mismo modo que
"1 TECLADO") — no es un descuido de pulido, es correcto: la
redefinición no crea una tabla nueva, **sobreescribe la tabla QAOP
por defecto en memoria**, así que "modo 0" pasa a ser lo que el
jugador acaba de configurar.

`ETIQUETA_TECLA_ESPECIAL` sustituye la etiqueta de una sola letra por
un nombre completo (`ESPACIO`/`S.SHIFT`/`C.SHIFT`/`ENTER`) cuando la
tecla detectada no tiene un carácter imprimible razonable.

### `DIBUJAR_CREDITOS_MENU` (antes `CODE_8DE5`)

Llamada real desde el principio de `PROCESAR_MENU_CONTROLES` —
**corrige** la hipótesis de sesión 40 ("candidata a parpadear
borde/color mientras espera tecla"). En realidad dibuja los créditos
reales del juego, parte de la pantalla del menú de controles:

```
MAD$MIX GAME
POGRAMADO BY:
RAPHAEL GOMEZZZ
GRAPHICOS BY
ROBERTO P.ACEBES
MUSIC-A BY:
COMILONAS
TOPOSHOW -1988-
```

("POGRAMADO"/"GRAPHICOS" así, tal cual en el original — no son
erratas de la transcripción). Detalle de codificación curioso: el
último byte del registro de texto de "ROBERTO P.ACEBES" hace doble
uso — es su propio byte de control final Y, a la vez, el byte de
longitud del siguiente registro ("MUSIC-A BY:", longitud 11 = `$0B`)
— ambos son llamadas independientes con direcciones fijas, así que no
es un error, ahorra 1 byte del original.

### Error propio detectado y corregido antes de reportar

Al transcribir los 8 textos de créditos como `DB longitud,atributo,
"texto"` independientes (en vez de como bytes crudos), la
verificación reportó 8 bytes menos de los esperados. Causa: el mismo
truco de "byte compartido" de arriba — escribir cada registro por
separado duplicaba/perdía ese byte compartido. Corregido volcando ese
tramo en hexadecimal crudo (con comentarios indicando el texto
legible), que representa exactamente los bytes reales sin asumir
límites de registro que no existen como tales en memoria.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original**. `py tools/gen_inventory.py` → **718 etiquetas**
(subía desde 705). `mapa_memoria.html`: el tramo `$8C1F-$8EB3` (660
B, "sin analizar") pasa a código resuelto; contigüidad verificada;
total mecánico restante recalculado: **952 bytes en cuatro tramos**
(antes 1612 en cinco).

### Pendiente para próximas sesiones

- `$E3D8-$E3F1` (26 B) y `CODE_9534` siguen sin resolver.
- Solo quedan 4 tramos mecánicos sueltos sin sesión asignada
  (`$62C9-$62E1`, `$8358-$83CB`, `$C5DE-$C600`, más los 49 fragmentos
  de música ya extraídos pero no decodificados canción por canción).
- Resto de la lista heredada de sesiones 40-55 sin cambios.

## Sesión 56 (continuación 6) — `CODE_9534` resuelto: `TICK_REDIBUJADO_VBLANK` + `DIBUJAR_ACTORES_PENDIENTES` ($945A-$94FB)

Tirando del hilo de `CODE_9534` (petición explícita del usuario:
"tira del hilo CODE_9534") se resuelven dos rutinas completas y se
corrige una hipótesis previa.

### `TICK_REDIBUJADO_VBLANK` (antes `CODE_9534`, $9534)

Se llama en **todas** las interrupciones desde
`ENTRADA_INTERRUPCION_VBLANK`, pero solo hace trabajo real cuando
`$91C2` valía exactamente 1 al entrar. **Corrige** la hipótesis de
sesión 54 ("rutina de mantenimiento que se ejecuta 1 de cada 256
interrupciones, vía un contador en `$91C2`"): en realidad `$91C2` es
una **bandera de un solo uso**, puesta a 1 por `WAIT_VBLANK` justo
antes de su `EI`/`HALT` — el trabajo extra solo corre cuando la
interrupción que despierta a `WAIT_VBLANK` es esa misma, no cada 256.
Los `OUT ($FF)` alrededor de la llamada no van a ningún puerto real
decodificado en un Spectrum de 48K (`$FF` es impar, solo importa el
bit 0 de la dirección para la ULA) — son relleno de temporización
puro (11 T-estados fijos cada uno), candidato a acotar la ventana de
ejecución de `DIBUJAR_ACTORES_PENDIENTES` a un número predecible de
T-estados.

### `DIBUJAR_ACTORES_PENDIENTES` (antes `CODE_945A`, $945A-$94FB, 162 B)

Motor de dibujado de sprites **alternativo** a `MOTOR_ACTORES` (ya
resuelto sesión 28) — consume la **misma**
`TABLA_ACTORES_ACTIVOS`/`CONTADOR_ACTORES_ACTIVOS` ($9F9A, 10 B por
actor) que `MOTOR_ACTORES` rellena, pero en vez de dibujar en el
momento en que `MOTOR_ACTORES` decide la posición, los **encola** y
esta rutina dibuja todos los pendientes de una vez, sincronizada con
`WAIT_VBLANK` vía `TICK_REDIBUJADO_VBLANK` — candidato a evitar
parpadeo/desgarro dibujando todos los sprites en el mismo instante
del barrido, en vez de repartido a lo largo del frame.

Usa el truco clásico Z80 de leer datos de sprite con `POP` en vez de
`LD`/`INC` (máxima velocidad): `SP` se redirige a apuntar al buffer
de datos del sprite vía `LD SP,HL`, y `$91CC` guarda el `SP` real
mientras tanto. Por cada actor pendiente (registro de 10 bytes):
offset 2-3 = dirección destino, offset 4 = número de filas, offset
5-6 = puntero a los datos del sprite (máscara+patrón intercalados,
consumidos vía `POP`), offset **7-9 = tres bytes que se escriben,
automodificando, en 6 posiciones** de `BLIT_ACTOR_PENDIENTE` (cada
offset se copia a 2 posiciones gemelas). Normalmente esas 6
posiciones son la instrucción `LD (HL),A` que guarda el píxel
compuesto; sustituirla por otro byte (candidato: `$00`=NOP) permite
"apagar" celdas concretas de la rejilla 2×3 del sprite — soporte para
formas irregulares sin necesitar una rutina de blit distinta por
forma. Termina restaurando `SP` y poniendo `CONTADOR_ACTORES_ACTIVOS`
a 0 (vacía la cola para el siguiente frame).

### Error propio detectado y corregido antes de reportar

El comentario de cabecera escrito inicialmente decía `$945A-$9506,
173 B`. El listado de compilación (`src/build/main.lst`) muestra que
la rutina termina exactamente donde empieza
`ACTIVAR_INTERRUPCION_MODO_2` (`$94FC`), es decir **162 bytes**, no
173. Corregido antes de tocar `mapa_memoria.html` (que sí exige el
tamaño exacto para mantener la contigüidad de tramos).

### Zona nueva descubierta, sin resolver — pendiente de decidir alcance

Justo después del `RET` de `TICK_REDIBUJADO_VBLANK` aparece una
rutina sin etiquetar (`CODE_954E`, ~93 B) que construye una tabla en
`$E400` (usa `CALL CODE_9656`, otra rutina aún sin nombrar, con pinta
de cálculo de dirección de pantalla/atributos fila↔dirección). Y la
segunda mitad de `REFRESCAR_ESQUEMA_COLOR_NIVEL` ($95B0, llamada
desde `TICK_REDIBUJADO_VBLANK` — su primera mitad, rellenar el
esquema de color del HUD/nivel vía `REGISTRO_NIVEL_ICONO_HUD`, sí
está entendida) continúa en `CODE_95FB` con una secuencia larga y
todavía no descifrada de intercambios de `SP` contra `IX=$E400` (deja
de tener sentido como el truco de `POP` de sprites ya visto — parece
un mecanismo distinto). Esto excede el alcance concreto que el
usuario aprobó ("`CODE_9534` lleva a un motor de sprites alternativo,
`CODE_945A`, ~186 líneas") — no se ha continuado sin confirmación.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (comprobado dos veces: tras los renombrados +
comentarios, y de nuevo tras corregir el error de tamaño de arriba).
`mapa_memoria.html`: el tramo `MOTOR_ACTORES` (0x91D0-0x94FC, 812 B,
ya "código") se divide en `MOTOR_ACTORES` (650 B) +
`DIBUJAR_ACTORES_PENDIENTES` (162 B) sin cambiar el total mecánico
(ambos ya contaban como resueltos); contigüidad exacta verificada
(0x91D0-0x945A + 0x945A-0x94FC = 0x91D0-0x94FC, sin huecos).

### Pendiente para próximas sesiones

- `$E3D8-$E3F1` (26 B) sigue sin resolver.
- Solo quedan 4 tramos mecánicos sueltos sin sesión asignada
  (`$62C9-$62E1`, `$8358-$83CB`, `$C5DE-$C600`, más los 49 fragmentos
  de música ya extraídos pero no decodificados canción por canción).
- Resto de la lista heredada de sesiones 40-55 sin cambios.

## Sesión 56 (continuación 7) — `CALCULAR_DIRECCION_PANTALLA` + `PREPARAR_TABLA_ESQUEMA_COLOR`/`BUCLE_MEZCLA_ESQUEMA_COLOR`, con verificación por simulador Z80 nuevo (`tools/mmesquema_sim.py`)

Continuación directa de la anterior: dentro de `REFRESCAR_ESQUEMA_COLOR_NIVEL`
apareció una segunda mitad (`CODE_95FB`, intercambio de registros vía
`SP`/`PUSH`/`POP`/`EXX`) mucho más grande de lo esperado. El usuario,
al ver el tamaño real de la tarea, eligió explícitamente construir un
simulador Z80 de verdad para resolverla con certeza en vez de seguir
razonándola a mano.

### `CALCULAR_DIRECCION_PANTALLA` (antes `CODE_9656`)

Resuelta con certeza total mediante **derivación algebraica bit a
bit** de las 10 instrucciones (sin necesidad de ejecutarla): es la
fórmula **estándar** de cálculo de dirección de pantalla del
Spectrum. Entrada B=Y (línea de píxel, 0-191), C=columna desplazada 3
bits a la izquierda (columna 0-31 en los 5 bits altos de C). Salida
HL = dirección de pantalla completa, repartiendo Y en los tres campos
entrelazados clásicos de la memoria de pantalla del 48K. Confirmada
además por **5 llamadores distintos** en todo el fichero (no es
exclusiva de esta zona) y por la simulación posterior (los valores
que calcula coinciden exactamente con la fórmula derivada a mano).

### `PREPARAR_TABLA_ESQUEMA_COLOR` (antes `CODE_954E`, $954E-$95AA)

Llamada **una sola vez** desde `INICIO`, justo después de
`CARGAR_MARCO_DECORATIVO` — y ese orden es la clave del hallazgo:
en cuanto el marco decorativo ya está dibujado en pantalla, su
bitmap/atributos fuente (`BITMAP_MARCO_DECORATIVO`, $E3F2-$EFA1, ya
resuelto en la corrección de sesión 56 anterior) dejan de hacer
falta, y esta rutina **recicla exactamente esa misma memoria** como
área de trabajo. Siembra, con paso fijo de 31 bytes por fila (144
filas, líneas de píxel 16 a 159), solo 3 de los 31 bytes de cada
fila: `+0/+1` = dirección de pantalla (columna 16), `+2/+3` = un
puntero de encadenado (tabla paralela con paso 32, desalineada a
propósito de la anterior), `+28/+29` = dirección de pantalla (columna
28). El resto de cada fila conserva los bytes que dejó el bitmap del
marco decorativo.

### `BUCLE_MEZCLA_ESQUEMA_COLOR` (antes `CODE_95FB`) — verificado por simulación

Con `IX` apuntando a un "nodo" de 10 bytes, usa `LD SP,IX` para
leer/escribir 8 palabras consecutivas vía `POP`/`PUSH` (máxima
velocidad, sin `LD`/`INC`), alternando entre el banco de registros
normal y el alterno (`EXX`) — y repite la misma danza una segunda vez
usando como puntero el valor de `HL` leído en la primera mitad, en
vez de `IX`. Esto entrelaza dos cadenas (la de `IX` y la de `HL`) en
cada pasada: el nuevo `IX` de la siguiente iteración sale de la
cadena de `HL`, no de su propia cadena. Repite hasta que el byte alto
de `IX` llega a 0.

Razonar esto a mano llevaba a hipótesis contradictorias (¿lista
enlazada real? ¿qué direcciones toca? ¿termina?). Se construyó
**`tools/mmesquema_sim.py`**, un simulador Z80 nuevo (misma filosofía
que `mmsnd_render.py`: ejecutar el código real sobre una copia real
de `FISICO/CODE.bin`, no reimplementar la lógica a mano), que
ejecuta `PREPARAR_TABLA_ESQUEMA_COLOR` seguido de varios fotogramas
sucesivos de `REFRESCAR_ESQUEMA_COLOR_NIVEL` y traza qué direcciones
toca. Resultado **verificado por ejecución real**:

- El proceso es **idempotente**: desde el primer fotograma alcanza un
  punto fijo estable — mismo número de iteraciones (72) y misma
  secuencia de valores de `IX` en cada fotograma sucesivo, sin
  reconstruir la tabla.
- Toca de verdad un pequeño conjunto **fijo** de bytes reales del
  bitmap de pantalla (`$4044-$405B`), además de recorrer la propia
  zona de trabajo reciclada de `PREPARAR_TABLA_ESQUEMA_COLOR` —
  confirma que el mecanismo interactúa con pantalla real, no solo
  consigo mismo.
- **No confirmado con la misma certeza**: el efecto visual/de juego
  exacto que produce (candidato: variación o parpadeo puntual de 1-2
  celdas del HUD). Precisarlo del todo exigiría comparar contra el
  juego corriendo de verdad (emulador con vídeo), fuera del alcance
  de esta sesión — documentado explícitamente como límite honesto en
  vez de forzar una interpretación no verificada.

### Corrección adicional

El bloque `LD HL,$0000/LD D,H/LD E,L/LD BC,$0160/LDIR` dentro de
`REFRESCAR_ESQUEMA_COLOR_NIVEL`, documentado provisionalmente como
"limpia 352 bytes en `$0000`", en realidad **no mueve ningún dato**:
con `HL=DE=$0000` la `LDIR` copia cada byte sobre sí mismo — es
relleno de temporización puro (352×21 T-estados), el mismo truco ya
documentado en `LIMPIAR_PANTALLA_MENU`/`BUCLE_ESPERA_TECLA_MENU`
(confirmado por precedente exacto ya presente en el propio fichero,
no solo por analogía).

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (comprobado tras cada tanda de renombrados).
`py tools/gen_inventory.py` → 718 etiquetas (sin cambio, solo
renombrados). `mapa_memoria.html`: el tramo "interrupción modo 2 +
ISR" (0x94FC-0x9670, 372 B, ya "código") se divide en tres tramos más
precisos sin cambiar el total mecánico; contigüidad exacta
verificada. `tools/mmesquema_sim.py` añadido como herramienta
permanente del proyecto.

### Pendiente para próximas sesiones

- Confirmar contra vídeo real de una partida qué efecto visual
  produce `BUCLE_MEZCLA_ESQUEMA_COLOR` en las celdas de pantalla
  `$4044-$405B` (o desestimarlo como vestigio sin efecto perceptible,
  a determinar).
- Solo quedan 3 tramos mecánicos sueltos sin sesión asignada
  (`$62C9-$62E1`, `$8358-$83CB`, `$C5DE-$C600`, más los 49 fragmentos
  de música ya extraídos pero no decodificados canción por canción).
- Resto de la lista heredada de sesiones 40-55 sin cambios.

## Sesión 56 (continuación 8) — `$E3D8-$E3F1` etiquetado como `GUION_DEMO_EXTRA_5`/`GUION_DEMO_EXTRA_6`

Último tramo pendiente cerca del marco decorativo. La extracción de
`GUION_DEMO_NIVEL_5` (88 bytes, `$E380-$E3D7`, resuelta en la
continuación 6) termina en un par (umbral,dirección) `$01,$00,$FF,$FF`
— un terminador genuino del formato ya confirmado por el consumidor
real (`INICIAR_DEMO`/`BUCLE_FRAME_DEMO`), no un corte arbitrario de
extracción. Esto confirma que el límite en `$E3D8` es real, y que los
26 bytes siguientes son una zona aparte.

Esos 26 bytes decodifican, con el mismo formato exacto, como 2
guiones cortos más, cada uno con su propio terminador limpio
(`$FF,$FF` / dirección=`$FF`):

```
GUION_DEMO_EXTRA_5 ($E3D8, 6 B):  01 1D 01 04 FF FF
GUION_DEMO_EXTRA_6 ($E3DE, 20 B): 01 11 01 01 01 11 01 01 01 11 08 01
                                   01 11 0C 01 05 00 FF FF
```

Igual que `GUION_DEMO_EXTRA_1-4` (`$DBE0-$DD17`, ya resueltos):
ningún índice de `TABLA_PERFILES_DEMO` apunta aquí (sus 4 entradas —
niveles 1/2/4/5 — ya están localizadas por completo), así que **no
hay ejecución real confirmada** que los lea. Se etiquetan con el
mismo criterio ya aplicado a sus 4 hermanos (formato + terminador
limpio como evidencia estructural, sin llamador confirmado) en vez de
dejarlos como bytes sueltos.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original**. `py tools/gen_inventory.py` → **720 etiquetas**
(subía desde 718 — 2 etiquetas nuevas de verdad, no renombrados).
`mapa_memoria.html`: el tramo `$E3D8-$E3F1` pasa de `sinexplorar` a
`codigo`; contigüidad verificada (67 tramos, sin huecos ni
solapes). El total de "952 bytes en cuatro tramos mecánicos" de la
nota introductoria no cambia — esos 26 bytes estaban en la categoría
`sinexplorar` (junto al relleno NOP de `$91BA`), no en `mecanico`.

### Pendiente para próximas sesiones

- Confirmar contra vídeo real de una partida qué efecto visual
  produce `BUCLE_MEZCLA_ESQUEMA_COLOR` en las celdas de pantalla
  `$4044-$405B` (o desestimarlo como vestigio sin efecto perceptible,
  a determinar).
- Solo quedan 3 tramos mecánicos sueltos sin sesión asignada
  (`$62C9-$62E1`, `$8358-$83CB`, `$C5DE-$C600`, más los 49 fragmentos
  de música ya extraídos pero no decodificados canción por canción).
- Resto de la lista heredada de sesiones 40-55 sin cambios.

## Sesión 56 (continuación 9) — `CODE_884B` (dentro de `CARGAR_NIVEL`): limpieza de comentario obsoleto, sin código nuevo

Petición del usuario: "tira del hilo `CODE_884B`" (etiqueta interna
de `CARGAR_NIVEL`, ya resuelta por completo desde sesión 24/47).
`CODE_884B` resultó ser solo el punto de aterrizaje del salto rápido
cuando `NIVEL_ACTUAL=0` (se salta el bucle que suma registros de
`TABLA_NIVELES`) — no llevaba a ningún código sin analizar.

Tirar del hilo sí encontró algo útil: la cabecera de `CARGAR_NIVEL`
(escrita en sesión 47) todavía marcaba `MAPEAR_COORDENADA_A_DIRECCION`
como "candidato, sin confirmar" e `INICIALIZAR_ITEMS_NIVEL` como "sin
analizar" — ambas quedaron **confirmadas por completo** en sesiones
posteriores (`MAPEAR_COORDENADA_A_DIRECCION` en sesión 40, al resolver
`MOTOR_MOVIMIENTO_ITEM` completo por coincidencia instrucción a
instrucción con MSX; `INICIALIZAR_ITEMS_NIVEL` también resuelta con
nombre real) pero el comentario nunca se actualizó. Corregido, y de
paso se nombraron las 6 etiquetas internas del bloque (antes
`CODE_8847/8876/8880/8898/889C/88AE`) ahora que toda la rutina está
entendida: `BUCLE_LOCALIZAR_REGISTRO_NIVEL`, `COPIAR_REGISTRO_NIVEL`,
`BUCLE_COPIAR_CUERPO_NIVEL_SIMPLE`, `BUCLE_COPIAR_CUERPO_NIVEL_COMODIN`,
`CONTINUAR_COPIA_CUERPO_COMODIN`, `COPIAR_PIE_NIVEL`,
`INICIALIZAR_ESTADO_NIVEL`.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original**. `py tools/gen_inventory.py` → 720 etiquetas (sin
cambio, solo renombrados). Sin cambios en `mapa_memoria.html` (la
zona ya era `codigo`, límites sin cambios).

### Pendiente para próximas sesiones

- Confirmar contra vídeo real de una partida qué efecto visual
  produce `BUCLE_MEZCLA_ESQUEMA_COLOR` en las celdas de pantalla
  `$4044-$405B` (o desestimarlo como vestigio sin efecto perceptible,
  a determinar).
- Solo quedan 3 tramos mecánicos sueltos sin sesión asignada
  (`$62C9-$62E1`, `$8358-$83CB`, `$C5DE-$C600`, más los 49 fragmentos
  de música ya extraídos pero no decodificados canción por canción).
- Resto de la lista heredada de sesiones 40-55 sin cambios.

## Sesión 56 (continuación 10) — `TABLA_PISTAS_TANQUE_AVION`/`BUCLE_DIBUJAR_PISTA` (tirando del hilo de `CODE_61FB`)

Petición del usuario: "tira del hilo `CODE_61FB`" (etiqueta interna
dentro de `MOTOR_MOVIMIENTO_COLISION`, en la preparación de la
llamada a `GESTIONAR_SCROLL`). `CODE_61FB` en sí es trivial —solo el
punto de aterrizaje de un salto condicional que decide si forzar
`H=0` antes de `CALL GESTIONAR_SCROLL`, renombrado
`CONTINUAR_LLAMADA_SCROLL`— pero justo debajo, dentro del bucle
principal de juego, había un tramo de 6 etiquetas mecánicas sin
analizar (`CODE_6224/623B/624B/6256/6259/6260`) que resultó ser una
pieza que faltaba de un sistema ya parcialmente conocido.

### El hilo conecta 4 consumidores de una tabla de 6 bytes

`$6041` ya tenía 3 consumidores identificados en sesiones anteriores,
pero **sin conectar entre sí** en los comentarios (cada uno lo trataba
como una zona de trabajo aparte, sin nombre): `LOOP_LIMPIEZA_PISTA`
(la vacía al cargar nivel), `REGISTRAR_PISTA_TANQUE_AVION` (escribe
una ranura nueva cuando se activa una loseta "cocotanque"/"coconave"),
y `AVISAR_PROXIMIDAD_PISTA` (dispara un flash de aviso cuando el
jugador se acerca al punto registrado). El bloque sin analizar de
`CODE_6224` resultó ser el **cuarto consumidor**: la rutina que
DIBUJA el icono de aviso cada fotograma, con exactamente la misma
estructura de decodificación de formato que `AVISAR_PROXIMIDAD_PISTA`
(mismo `BIT 0,D` para elegir eje, mismo `BIT 7` para elegir sentido)
— la coincidencia estructural con una rutina ya confirmada fue la
pista de que pertenecían al mismo subsistema.

Se le dio nombre a la tabla (`TABLA_PISTAS_TANQUE_AVION`, $6041, 6
bytes = 3 ranuras x 2 bytes) y se sustituyeron sus 4 referencias en
crudo (`LD HL,$6041`) por el símbolo.

### Hallazgo por lectura de registros: la "posición" se mueve sola

Trazando con cuidado qué registro contiene qué valor en cada punto del
bucle (en vez de asumir), se confirmó que `BUCLE_DIBUJAR_PISTA` **no
solo lee** la posición de cada ranura — la **reescribe** cada
fotograma con el valor ya desplazado (±8 en el eje horizontal, −16 en
el vertical) antes de dibujar. Esto convierte lo que parecía una
posición fija registrada una vez en una posición **en vivo** que
avanza fotograma a fotograma, hasta salir del rango válido
(`$08-$70` horizontal), momento en el que la ranura se autolimpia. Es,
mecánicamente, un icono deslizándose por el borde de la pantalla — el
comentario ya existente sobre `EFECTOS_DESTELLO_SEQ_A` ("flecha
derecha x22") encaja con esta lectura.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original**. `py tools/gen_inventory.py` → **721 etiquetas**
(subía desde 720 — 1 etiqueta nueva de verdad, `TABLA_PISTAS_TANQUE_AVION`).
`mapa_memoria.html`: sin cambio de límites (la zona ya era `codigo`
dentro del preámbulo de `MOTOR_MOVIMIENTO_COLISION`), detalle
actualizado.

### Pendiente para próximas sesiones

- Confirmar contra vídeo real de una partida qué efecto visual
  produce `BUCLE_MEZCLA_ESQUEMA_COLOR` en las celdas de pantalla
  `$4044-$405B` (o desestimarlo como vestigio sin efecto perceptible,
  a determinar).
- `$6047-$604A` (4 bytes, dentro/junto a `TABLA_PISTAS_TANQUE_AVION`) y
  `$604B-$605F` (26 bytes) siguen sin identificar.
- ~~Solo quedan 3 tramos mecánicos sueltos sin sesión asignada
  (`$62C9-$62E1`, `$8358-$83CB`, `$C5DE-$C600`, más los 49 fragmentos
  de música ya extraídos pero no decodificados canción por canción).~~
  **[Los 3 tramos y los 49 fragmentos ya estaban RESUELTOS antes de
  esta nota, sin que se actualizara aquí — verificado en sesión 56
  (continuaciones 26 y 29): `$62C9-$62E1` es `DIBUJAR_CAMBIO_LOSETA`,
  `$8358-$83CB` es la cola de `MOTOR_MOVIMIENTO_ITEM`
  (`CONSULTAR_LOSETA_LIBRE_DIRECCION`+`MAPEAR_COORDENADA_A_DIRECCION`+
  `GENERAR_ALEATORIO`), `$C5DE-$C5FF` es relleno a cero antes de
  `GRAFICOS_LOSETAS`, y los 49 fragmentos de música/SFX (más el resto
  de `$DBE0-$EFB5`, incluido el bitmap del marco decorativo) están
  extraídos y sin ningún byte pendiente de identificar.]**
- Resto de la lista heredada de sesiones 40-55 sin cambios.

## Sesión 56 (continuación 11) — `CODE_9A30` renombrada a `DIBUJAR_TEXTO_MARCADOR`

Petición del usuario: identificar y nombrar `CODE_9A30`, dentro de
`DIBUJAR_MARCADOR_PUNTOS`. Es la **cola común de las 3 ramas** que
deciden qué etiqueta pintar en el marcador de puntuación: dígitos de
puntuación formateados en `BUFFER_TEXTO_PUNTUACION` (caso normal),
`ETIQUETA_PUNTUACION_MAXIMA` ("BESTIA", si se alcanza el límite de
10000) o `ETIQUETA_PUNTUACION_DEMO` (" DEMO ", mientras el ciclador de
demo está activo). Las 3 ramas dejan el puntero elegido en `IX` y
saltan (o caen) aquí, donde se fija la posición fija de pantalla del
marcador (`B=$B0`=Y176, `C=$B0`→columna 22, según la fórmula ya
documentada de `CALCULAR_DIRECCION_PANTALLA`) y se llama a `CODE_9A90`
(rutina de dibujo de cadena en VRAM, hermana de `ESCRIBIR_PATRON_VRAM`
pero para una cadena completa terminada en `$FF`, no un solo
carácter).

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (renombrado puro, sin cambio de bytes).

## Sesión 56 (continuación 12) — `CODE_9A3E`/`CODE_9A49`/`CODE_9A54`/`CODE_9A69`/`CODE_9A90` renombradas

Petición del usuario: identificar y nombrar el resto del subsistema de
dibujado del marcador de puntuación, ya iniciado con
`DIBUJAR_TEXTO_MARCADOR` (continuación 11). Dos piezas:

**Conversión binario→decimal ASCII** (llamada una vez por
`DIBUJAR_MARCADOR_PUNTOS` con `HL`=puntuación, `DE`=dirección de
`BUFFER_TEXTO_PUNTUACION`), por división mediante resta repetida contra
`TABLA_VALORES_DECIMAL_PUNTUACION` (1000,100,10):
- `CODE_9A3E` → **`CONVERTIR_PUNTUACION_A_TEXTO`**: orquestador —
  guarda la dirección del buffer en el par `DE` sombra (`EXX`) como
  puntero fijo de escritura, deja el `DE` primario como contador de
  posición, y arranca el bucle.
- `CODE_9A49` → **`BUCLE_CONVERTIR_PUNTUACION`**: nombre que el propio
  comentario de `TABLA_VALORES_DECIMAL_PUNTUACION` (sesión 56,
  continuación anterior) ya anticipaba. Por cada divisor de la tabla,
  lo carga en `BC` y resetea el contador de dígito; se detiene al leer
  el divisor 10 (centinela de fin de tabla).
- `CODE_9A54` → **`BUCLE_RESTAR_DIVISOR`**: bucle interno de resta
  repetida que calcula el dígito decimal para el divisor actual.
- `CODE_9A69` → **`ESCRIBIR_DIGITO_PUNTUACION`**: convierte el dígito
  binario a ASCII (`+$30`) y lo escribe en la posición actual del
  buffer (dirección en `DE` sombra + offset en `DE` primario),
  avanzando el offset.

**Dibujado de cadena en VRAM**:
- `CODE_9A90` → **`DIBUJAR_CADENA_VRAM`**: hermana de
  `ESCRIBIR_PATRON_VRAM` pero para una cadena completa de índices de
  patrón terminada en `$FF` (dígitos ya convertidos, o las etiquetas
  fijas "BESTIA"/" DEMO "), en vez de un solo carácter.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (renombrado puro, sin cambio de bytes).

## Sesión 56 (continuación 13) — `DIBUJAR_CADENA_VRAM`: bucle interno renombrado, 3 etiquetas mecánicas eliminadas

Petición del usuario: identificar y nombrar `CODE_9A94`, `CODE_9AAA`,
`CODE_9AAD`, `CODE_9AAF`, `CODE_9AB1` y `CODE_9AC0`, el bucle interno
de `DIBUJAR_CADENA_VRAM` (continuación 12) que copia el patrón de cada
carácter de la cadena a pantalla.

Antes de nombrar, se comprobó (grep de cada etiqueta en todo el
fichero) cuáles son destino real de algún salto. Solo 3 de las 6 lo
son:
- `CODE_9A94` → **`BUCLE_DIBUJAR_CARACTER`** (destino de `JR` al final
  del bucle): por cada carácter de la cadena, lee su índice de `IX`,
  detecta el `$FF` de fin, y calcula la dirección del patrón de fuente
  (misma fórmula base que `ESCRIBIR_PATRON_VRAM`).
- `CODE_9AAA` → **`BUCLE_COPIAR_FILA_DOBLE`** (destino de `DJNZ`): por
  cada una de las 8 filas del patrón, copia el byte de fuente y lo
  escribe **dos veces seguidas** — el carácter se dibuja a doble altura
  (16 líneas de píxel en vez de 8), acorde con que el marcador de
  puntuación se ve más grande que el HUD normal.
- `CODE_9AC0` → **`CONTINUAR_FILA_DOBLE`** (destino de 2 saltos
  condicionales): punto de convergencia tras el chequeo de cruce de
  tercio de pantalla, antes de repetir el bucle de fila.

Las otras 3 (`CODE_9AAD`, `CODE_9AAF`, `CODE_9AB1`) **no las referencia
ningún salto en todo el fichero** — son puntos de corte mecánicos del
desensamblado lineal de primera pasada (`dasm2asm.py`), simple caída
desde la instrucción anterior, sin ser objetivo de control de flujo
real. Siguiendo el mismo criterio ya aplicado en la limpieza de
`CODE_884B` (continuación 9), se eliminaron como etiqueta y su
contenido quedó documentado con comentarios en línea dentro de
`BUCLE_COPIAR_FILA_DOBLE` (duplicar fila / avanzar puntero de fuente /
chequeo de cruce de tercio de pantalla).

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (renombrado + eliminación de etiquetas muertas, sin
cambio de bytes).

## Sesión 56 (continuación 14) — `LEER_ENTRADA`/`COMPROBAR_PAUSA`: 7 etiquetas renombradas, `CODE_9ACF` eliminada

Petición del usuario: identificar y nombrar `CODE_9ACF`, `CODE_9AD8`,
`CODE_9AED`, `CODE_9B00`, `CODE_9B03`, `CODE_9B14`, `CODE_9B26` y
`CODE_9B38`, repartidas entre `LEER_ENTRADA`, `ESCANEAR_FILAS_TECLADO`
y `COMPROBAR_PAUSA` (ya documentadas en conjunto desde sesión 26, ver
el bit layout QAOP: bit0=DERECHA, bit1=IZQUIERDA, bit2=ABAJO,
bit3=ARRIBA, bit4=SPACE, bit5=PAUSA).

Mismo criterio que en continuaciones 9 y 13: se comprobó primero cuáles
tienen salto entrante real. Solo `CODE_9ACF` no lo tiene (nadie salta
ahí, caída directa tras `LD HL,$9B81`) — se eliminó como etiqueta,
documentando su rol en comentario (decide si limpiar
`ACUMULADOR_ENTRADA` o dejarlo acumular, según el parámetro `A` de
`LEER_ENTRADA`).

Las 7 restantes, todas con salto entrante real:
- `CODE_9AD8` → **`DESPACHAR_MODO_ENTRADA`**: lee `MODO_ENTRADA`
  ($91B9) y despacha a la tabla de teclas o rutina correspondiente
  según su valor (0-3).
- `CODE_9AED` → **`CARGAR_TABLA_MODO_0`**: carga `TABLA_TECLAS_MODO_0`
  (esquema QAOP por defecto) antes del escaneo compartido.
- `CODE_9B00` → **`TECLA_NO_PULSADA`**: dentro de
  `ESCANEAR_FILAS_TECLADO`, camino "tecla no pulsada" (mete un bit 0
  en `E`).
- `CODE_9B03` → **`CONTINUAR_ESCANEO_TECLADO`**: cola común del bucle
  de escaneo (avanza tabla, `DJNZ`).
- `CODE_9B14` → **`RESOLVER_CONFLICTO_VERTICAL`**: dentro de
  `COMPROBAR_PAUSA`, resuelve ABAJO+ARRIBA pulsados a la vez
  (anti-jitter, sustituye por el acumulador anterior).
- `CODE_9B26` → **`RESOLVER_CONFLICTO_HORIZONTAL`**: mismo mecanismo
  para DERECHA+IZQUIERDA.
- `CODE_9B38` → **`FUNDIR_ACUMULADOR_ENTRADA`**: paso final, funde
  (`OR`) el resultado con `ACUMULADOR_ENTRADA` y lo guarda.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (renombrado + eliminación de 1 etiqueta muerta, sin
cambio de bytes).

## Sesión 56 (continuación 15) — `LEER_ENTRADA`: confirmado soporte de joystick Sinclair y Kempston (`CODE_9B51`/`CODE_9B7C`/`CODE_9AF1` renombradas)

Petición del usuario: identificar y nombrar `CODE_9B51`, `CODE_9B7C` y
`CODE_9AF1`, que completan el despacho de `DESPACHAR_MODO_ENTRADA`
(continuación 14). Resuelve una duda que llevaba abierta desde sesión
26 ("posible indicio de soporte para mas de un tipo de joystick").

- `CODE_9AF1` → **`ESCANEAR_TABLA_TECLAS`**: motor de escaneo
  compartido por los 3 modos basados en teclado (0, 1 y 3) — resetea
  `E`/`B` y entra al bucle de fila, que cae en `COMPROBAR_PAUSA` como
  epílogo común.
- `CODE_9B51` → **`LEER_JOYSTICK_SINCLAIR`**: modo 1, emulación de
  joystick **Sinclair Interface 2** vía teclado — escanea
  `TABLA_TECLAS_MODO_1A` (fila numérica 1-5) y `TABLA_TECLAS_MODO_1B`
  (0,9,8,7,6), fundiendo ambas lecturas en `COMPROBAR_PAUSA`.
- `CODE_9B7C` → **`LEER_JOYSTICK_KEMPSTON`**: modo 2, **joystick
  Kempston real por hardware** — `IN A,($1F)`, el puerto ESTÁNDAR
  Kempston, sin pasar por `ESCANEAR_TABLA_TECLAS` en absoluto. El
  formato de bits Kempston (bit0=derecha, bit1=izquierda, bit2=abajo,
  bit3=arriba) coincide exactamente con el layout QAOP ya establecido
  para `E`, por lo que el byte del puerto se usa tal cual.

Con esto queda confirmado el mapa completo de `MODO_ENTRADA`: 0=teclado
QAOP, 1=Sinclair Interface 2 emulado, 2=Kempston real, 3=esquema
alternativo sin propósito confirmado (pendiente). Se actualizó también
el comentario de cabecera de `LEER_ENTRADA` (sesión 26) que ya
anticipaba la duda, para reflejar la confirmación.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (renombrado puro, sin cambio de bytes).

## Sesión 56 (continuación 16) — `CODE_9B58` renombrada a `LEER_JOYSTICK_SINCLAIR_PUERTO_IZQUIERDO`

Petición del usuario: identificar y nombrar `CODE_9B58`, la segunda
mitad de `LEER_JOYSTICK_SINCLAIR` (continuación 15). A diferencia de
las etiquetas mecánicas eliminadas en continuaciones 13 y 14 (simple
caída entre instrucciones, sin ningún salto ni retorno de por medio),
esta sí marca un punto de control de flujo real: es la **dirección de
retorno** del `CALL ESCANEAR_TABLA_TECLAS` justo encima (tras escanear
el puerto DERECHO Sinclair — `TABLA_TECLAS_MODO_1A`, teclas 1-5 — y
volver aquí). Escanea entonces `TABLA_TECLAS_MODO_1B` (puerto
IZQUIERDO, teclas 0,9,8,7,6) con `JR` definitivo esta vez.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (renombrado puro, sin cambio de bytes).

## Sesión 56 (continuación 17) — Secuencia de arranque `INICIO`: 12 etiquetas de código renombradas (4 con nombre exacto de MSX) + 3 etiquetas de datos reclasificadas

Petición del usuario: identificar y nombrar `CODE_9BEA`, `CODE_9C07`,
`CODE_9C22`, `CODE_9C21`, `CODE_9C5B`, `CODE_9C49`, `CODE_9C76`,
`CODE_9C8D`, `CODE_9C90`, `CODE_9C93`, `CODE_9CA6`, `CODE_9CCB`,
`CODE_9E5E`, `CODE_9E5D` y `CODE_9E69` — toda la secuencia de arranque
de partida/nivel de `INICIO`, ya con comentarios de hipótesis extensos
de sesiones anteriores (paralelismo fuerte con MSX: 4 variables
coinciden en cantidad/orden/valor con `REINICIAR_PARTIDA`, estructura
que encaja con `PREPARAR_INICIO_NIVEL`/`BUSCAR_COLUMNA_HUD`).

### 12 etiquetas de código (todas destino real de salto)

Dado el paralelismo ya confirmado en comentarios previos, 4 usan el
**mismo nombre exacto que MSX**:
- `CODE_9C07` → **`REINICIAR_PARTIDA`**: reentrada "partida nueva"
  (resetea vidas/puntuación/nivel).
- `CODE_9C21` → **`PANTALLA_PRESENTACION_NIVEL`**: reentrada "nivel
  siguiente" (sin resetear vidas/puntuación).
- `CODE_9C22` → **`PREPARAR_INICIO_NIVEL`**: cuerpo compartido — carga
  nivel, dibuja HUD, música si es partida nueva.
- `CODE_9CCB` → **`BUSCAR_COLUMNA_HUD`**: bucle de "búsqueda de
  columna del HUD", MSX describe esta misma fase con las mismas
  palabras ("animación de búsqueda del HUD").

El resto, nombres descriptivos nuevos (sin equivalente MSX directo
identificado):
- `CODE_9BEA` → `ESPERAR_TECLA_INICIO`
- `CODE_9C49` → `BUCLE_ESPERA_PARTIDA_NUEVA`
- `CODE_9C5B` → `COMPROBAR_VIDA_EXTRA`
- `CODE_9C76` → `COMPROBAR_AVISO_ULTIMA_VIDA`
- `CODE_9C8D` → `CONTINUAR_TRAS_AVISOS_HUD`
- `CODE_9C90` → `BUCLE_ESPERA_LECTURA_HUD`
- `CODE_9C93` → `REINICIAR_ESTADO_NIVEL`
- `CODE_9CA6` → `GUARDAR_SELECTOR_SPRITE_INICIAL`

### 3 etiquetas que en realidad son DATOS ($9E01-$9E8D)

Mismo fenómeno "datos disfrazados de código" ya documentado en
`$9A75-$9A8F` (sesión 56, continuación 11): el desensamblado mecánico
decodifica esta zona como instrucciones sin sentido, pero es DATA.
Cruzando qué escribe el código justo antes (`BUSCAR_COLUMNA_HUD`
calcula un byte de atributo/color) con qué consume `DIBUJAR_TEXTO_VRAM`
justo después, se identificaron 3 registros de texto (formato
`[longitud, atributo, caracteres]`) para las 3 líneas de HUD dibujadas
antes de `BUCLE_PRINCIPAL_JUEGO` (candidato al "READY?" de MSX):
- `CODE_9E5D` → **`REGISTRO_TEXTO_HUD_1`** (longitud, registro 1,
  dibujado en `$488C`).
- `CODE_9E5E` → **`ATRIBUTO_TEXTO_HUD_1`** (byte de atributo del
  registro 1, escrito dinámicamente).
- `CODE_9E69` → **`REGISTRO_TEXTO_HUD_2`** (longitud, registro 2,
  dibujado en `$48AC`).

Solo estas 3 (las referenciadas directamente desde el código) — el
resto del tramo, incluido el 3er registro en `$9E75` (ya referenciado
como hex crudo sin etiqueta `CODE_`) y el resto de bytes sin
referencia directa, queda pendiente de convertir a datos reales en una
sesión futura.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (renombrado puro, sin cambio de bytes).

## Sesión 56 (continuación 18) — corregido el nombrado del trío HUD: es `TEXTO_VACIO_1`/`TEXTO_READY`/`TEXTO_VACIO_2`, no genérico

Petición del usuario: comprobar si el nombrado genérico dado en la
continuación 17 (`REGISTRO_TEXTO_HUD_1`/`ATRIBUTO_TEXTO_HUD_1`/
`REGISTRO_TEXTO_HUD_2`) debía ser tan específico como en MSX, donde la
etiqueta `TEXTO_READY` ya identifica el contenido exacto.

**Verificación por volcado de bytes reales** (`FISICO/CODE.bin`,
`$9E01-$9E90`, no solo por analogía): confirma que la ronda anterior
acertó el mecanismo pero **no el contenido exacto** — `$9E5D` (que
llamé `REGISTRO_TEXTO_HUD_1`) NO es el texto "READY", es la línea en
blanco de ANTES; el "READY?" real está en `$9E69`:

```
$9E5D: 0A 00 20 20 20 20 20 20 20 20 20 20  -> "          " (blanco)
$9E69: 0A 00 20 20 52 45 41 44 59 3F 20 20  -> "  READY?  "
$9E75: 0A 00 20 20 20 20 20 20 20 20 20 20  -> "          " (blanco)
```

Exactamente el mismo trío, mismo contenido, mismo orden, que
`TEXTO_VACIO_1`/`TEXTO_READY`/`TEXTO_VACIO_2` de MSX (dibujado en
`MOSTRAR_READY_Y_ARRANCAR_NIVEL`). Renombrado con los mismos nombres
exactos:

- `REGISTRO_TEXTO_HUD_1` ($9E5D) → **`TEXTO_VACIO_1`**
- `ATRIBUTO_TEXTO_HUD_1` ($9E5E) → **eliminada**, sustituida por
  `TEXTO_VACIO_1+1` (aritmética de etiqueta, mismo idioma EXACTO que
  usa MSX para su atributo — `TEXTO_VACIO_1+1`/`TEXTO_READY+1`/
  `TEXTO_VACIO_2+1` — en vez de un símbolo separado).
- `REGISTRO_TEXTO_HUD_2` ($9E69) → **`TEXTO_READY`**
- `$9E75` (hex crudo) → nueva etiqueta **`TEXTO_VACIO_2`**, completando
  el trío.

**Bonus descubierto en el mismo volcado** (fuera de alcance de esta
petición, pendiente para una sesión futura si se quiere): 5 direcciones
más de la misma familia que MSX también nombra con precisión:
`$9E14`→`TEXTO_FASE`, `$9E1E`→`TABLA_NUMEROS_NIVEL`,
`$9E3E`→`TEXTO_VIDA_EXTRA` (contenido real "EN LA PROXIMA... EXTRA" —
el comentario actual de `COMPROBAR_AVISO_ULTIMA_VIDA` que dice
"candidato aviso ultima vida" es incorrecto, no es un aviso de última
vida), `$9E56`→`TEXTO_EXTRA`, y `CODE_9E81`→`TEXTO_GAME_OVER`
(contenido real "ESTAS FRITO").

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (renombrado puro, sin cambio de bytes).

## Sesión 56 (continuación 19) — `BUCLE_PRINCIPAL_JUEGO`/`VERIFICAR_FIN_NIVEL`/`VERIFICAR_ENTRADA`: 10 etiquetas renombradas + 13 movidas a EQU (patrón ya establecido)

Petición del usuario: identificar y nombrar 23 etiquetas más de la
misma zona (`CODE_9D3E`, `CODE_9DE1`, `CODE_9E81`, `CODE_9D85`,
`CODE_9DD1`, `CODE_9DAC`, `CODE_9DCE`, `CODE_9DC3`, `CODE_9DC6`,
`CODE_9DEA`, y 13 más entre `$9E3F` y `$9E90`).

### 10 etiquetas reales (código genuino + 1 dato con referencia real)

- `CODE_9D3E` → **`COMPROBAR_TEMPORIZADOR_MODO_ESPECIAL`**: convergencia
  tras el intercambio opcional de color (solo si
  `MODO_ESPECIAL_ACTIVO==2`), antes de decrementar el temporizador.
- `CODE_9DE1` → **`REPINTAR_ICONOS_HUD`**: guarda `COLOR_ACTUAL` en
  `$9E13` y arranca el repintado animado de iconos del HUD (recorrido
  hacia atrás desde `$9E10`, guardado por `BUSCAR_COLUMNA_HUD`).
- `CODE_9DEA` → **`BUCLE_REPINTAR_ICONOS_HUD`**: bucle interno de ese
  repintado.
- `CODE_9E81` → **`TEXTO_GAME_OVER`** (mismo nombre que MSX) —
  confirmado por volcado de bytes: contenido real "ESTAS FRITO",
  idéntico al `TEXTO_GAME_OVER` de MSX.
- `CODE_9D85` → **`BUCLE_ESPERA_GAME_OVER`**: espera ~150 frames tras
  dibujar el GAME OVER.
- `CODE_9DD1` → **`ACTUALIZAR_PARPADEO_BOLA`**: actualiza temporizador
  y posición del parpadeo de la bola.
- `CODE_9DAC` → **`PREPARAR_TRANSICION_NIVEL`**: tras comprobar el
  ciclo de 16 niveles, llama a `REPINTAR_ICONOS_HUD` y transfiere el
  flag `$600E`→`$603E` para el siguiente nivel.
- `CODE_9DCE` → **`CONTINUAR_BUCLE_PRINCIPAL`**: convergencia antes de
  reentrar en `BUCLE_PRINCIPAL_JUEGO`.
- `CODE_9DC3` → **`BUCLE_ESPERA_PAUSA`**: espera 50 frames tras
  detectar pausa.
- `CODE_9DC6` → **`ESPERAR_TECLA_REANUDAR`**: espera tecla para
  reanudar tras pausa.

### 13 etiquetas de ruido dentro de datos ya identificados

`CODE_9E3F`, `CODE_9E41`, `CODE_9E4D`, `CODE_9E51`, `CODE_9E55`,
`CODE_9E59`, `CODE_9E5C`, `CODE_9E5F`, `CODE_9E65`, `CODE_9E6B`,
`CODE_9E73`, `CODE_9E7D`, `CODE_9E87` caían dentro de las cadenas de
texto ya identificadas por volcado de bytes (`TEXTO_VIDA_EXTRA`,
`TEXTO_EXTRA`, `TEXTO_READY`/`TEXTO_VACIO_2`/`TEXTO_GAME_OVER`), y
comprobado que **todas sus referencias vienen de otras instrucciones
igual de falsas del mismo tramo, nunca de código real**. Se aplicó el
mismo patrón que el fichero ya usa para `CODE_9E9B`/`CODE_9E9D`/
`CODE_9E9F`/`CODE_9EA1`/`CODE_9ED0` (sesión 30/31): eliminadas como
etiqueta inline y movidas al bloque de constantes `EQU` existente
(mismo nombre, valor numérico exacto, sin inventar nombre de
subrutina). `CODE_9E90` ya estaba en ese bloque desde antes, sin
cambios.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (renombrado + reubicación a EQU, sin cambio de
bytes).

## Sesión 56 (continuación 20) — cierre del tramo `$9E01-$9E8D`: `CODE_9E83`/`CODE_9E85`/`CODE_9E8D` a EQU, `CODE_9E79` eliminada

Petición del usuario: continuar con el resto de etiquetas del mismo
lote (la mayoría ya resueltas en continuación 19 o desde sesión
30/31). Solo 4 seguían pendientes, todas dentro de `TEXTO_GAME_OVER`
(los caracteres de "ESTAS FRITO") o justo al final del tramo:

- `CODE_9E83`, `CODE_9E85`, `CODE_9E8D`: caen dentro de los caracteres
  de `TEXTO_GAME_OVER`, referenciadas solo por otras instrucciones
  falsas del mismo tramo (nunca código real) — movidas a `EQU`, mismo
  patrón que continuación 19.
- `CODE_9E79`: sin salto entrante en todo el fichero (ni siquiera uno
  falso) — eliminada, mismo criterio que `CODE_9AAD`/`CODE_9ACF` de
  rondas anteriores.

Con esto queda completo el saneamiento del tramo `$9E01-$9E8D`
("datos disfrazados de código" del HUD/READY/GAME OVER): de las
etiquetas mecánicas originales de esa zona, todas están ya resueltas
como dato real, movidas a `EQU`, o eliminadas por no representar
ningún flujo de control genuino.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (reubicación a EQU + eliminación de 1 etiqueta
muerta, sin cambio de bytes).

## Sesión 56 (continuación 21) — 14 constantes `EQU` huérfanas eliminadas (`CODE_9E51` + 13 entre `$A101` y `$BF01`)

Petición del usuario: analizar el bloque completo de constantes `EQU`
(35 en total, incluidas las 22 de continuaciones 19-20) tras notar que
podían corresponder a elementos de un array.

**Comprobación de referencias**: de las 35, **14 no las referenciaba
nada en absoluto en todo el fichero** (ni código real ni otra
instrucción falsa) — resto muerto:
- `CODE_9E51`: se me pasó en la continuación 19/20 — debería haberse
  eliminado como `CODE_9E79`, no convertido a `EQU`.
- 13 más, mucho más lejanas (`CODE_A101` … `CODE_BF01`), heredadas de
  sesión 30/31, probablemente huérfanas desde que el código mecánico
  que las usaba se sustituyó por `INCBIN`/`DB` sin limpiar también
  estas constantes.

**Comprobación de la hipótesis "elementos de array"**: se localizó
dónde cae cada una de las 13 lejanas contra `PTR_TABLA_SPRITES` (64
sprites × 144 bytes) y `TABLA_FUENTE`. 12 de las 13 caen en bytes
sueltos dentro de un sprite o de la fuente de texto, sin ser límite de
nada (`CODE_A101`→dentro de `TABLA_FUENTE`; `CODE_AAAA`→dentro de
`SPR15`; `CODE_ACBC`/`CODE_ACBE`→`SPR19`; `CODE_ADBF`/`CODE_ADEA`/
`CODE_AE34`→`SPR21`; `CODE_AF03`→`SPR23`; `CODE_B630`→`SPR36`;
`CODE_BD8A`/`CODE_BDA7`→`SPR49`; `CODE_BF01`→`SPR51`). Solo
**`CODE_AF5E` coincidía EXACTO con el inicio real de un elemento del
array** — `SPR24_PM_HIPO_ABAJO_3` — pero por tener ya su propio nombre,
la constante duplicada tampoco aportaba nada.

Eliminadas las 14. Ampliado el comentario de cabecera del bloque `EQU`
documentando la depuración.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (eliminación de constantes muertas, sin cambio de
bytes).

## Sesión 56 (continuación 22) — `REPINTAR_ICONOS_HUD` era `DESTELLO_ICONO_COLOR_HUD` (mismo nombre EXACTO que MSX) + `TABLA_POSICIONES_HUD` identificada

Pregunta del usuario: "¿`BUCLE_REPINTAR_ICONOS_HUD` tiene analogía en
MSX?". Sí, y muy fuerte: MSX tiene `DESTELLO_ICONO_COLOR_HUD`
(`madmix1_body.asm:2816`), **idéntica instrucción a instrucción**
(mismas variables `REGISTRO_NIVEL_ICONO_HUD`/`COLOR_ACTUAL`/
`WAIT_VBLANK`, misma estructura de bucle). El comentario de MSX además
corrige una hipótesis previa: no es un "repintado" ni una "máquina de
escribir" que revela texto — es un **parpadeo/destello rápido** de
icono+color mientras recorre hacia atrás la tabla desde donde la dejó
la búsqueda.

**Correlación de direcciones, confirmada por aritmética exacta**:
`TABLA_POSICIONES_HUD` de MSX (`$9136`) tiene sus mismos offsets +15
(puntero de búsqueda, word) y +18 (color guardado) reutilizados en
Spectrum — y `$9E12` (offset +17, columna/icono objetivo) también
coincide exactamente con MSX (`$9147`/`TABLA_POSICIONES_HUD+17`, usado
en `BUSCAR_COLUMNA_HUD` de MSX). Esto resuelve varios comentarios
"pendiente"/"sin equivalente MSX" que llevaban abiertos desde sesiones
anteriores (línea de `CARGAR_NIVEL`, y el efecto de parpadeo del icono
en modo hipopótamo).

**Cambios**:
- `REPINTAR_ICONOS_HUD` → **`DESTELLO_ICONO_COLOR_HUD`** (mismo nombre
  que MSX).
- `BUCLE_REPINTAR_ICONOS_HUD` → **`BUCLE_DESTELLO_ICONO_COLOR_HUD`**.
- `$9E01` → nueva etiqueta **`TABLA_POSICIONES_HUD`** (mismo nombre
  que MSX, contenido byte a byte ya verificado idéntico en rondas
  anteriores), colocada en su posición real de bytes dentro del tramo
  "datos disfrazados de código" (verificada contra `src/build/main.lst`
  para no desplazar ni un byte).
- `$9E10`/`$9E12`/`$9E13` (4 sitios distintos del fichero, no solo
  dentro de `DESTELLO_ICONO_COLOR_HUD`/`BUSCAR_COLUMNA_HUD`, también en
  `CARGAR_NIVEL` y en el efecto de parpadeo del modo hipopótamo) →
  aritmética `TABLA_POSICIONES_HUD+15`/`+17`/`+18`, mismo idioma que
  MSX.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (renombrado + nueva etiqueta en posición verificada,
sin cambio de bytes).

## Sesión 56 (continuación 23) — `TABLA_POSICIONES_HUD`-`TEXTO_GAME_OVER`: convertido POR COMPLETO de "datos disfrazados de código" a datos reales

Petición del usuario: revisando MSX, lo que hay bajo `TABLA_POSICIONES_
HUD` en Spectrum no son instrucciones sino datos que hay que
estructurar con sus etiquetas correspondientes, igual que MSX. Correcto
— hasta ahora esta zona (`$9E01-$9E8D`, ~140 bytes) seguía como
desensamblado mecánico de primera pasada (instrucciones Z80 sin
sentido real), con solo 4 etiquetas puntuales colocadas encima
(`TABLA_POSICIONES_HUD`, `TEXTO_VACIO_1`, `TEXTO_READY`,
`TEXTO_VACIO_2`, `TEXTO_GAME_OVER`) y el resto de constantes `EQU`
resolviendo autorreferencias falsas.

**Reconstrucción completa** contrastando byte a byte contra
`FISICO/CODE.bin` y contra la estructura de datos de MSX
(`madmix1_body.asm`, bloque `0x9136-0x92E3`): todo el tramo son en
realidad **9 elementos de datos consecutivos**, mismo formato y mismos
nombres EXACTOS que MSX:

```
TABLA_POSICIONES_HUD  ($9E01, 19 bytes)  -- ya nombrada continuacion 22
TEXTO_FASE             ($9E14, 10 bytes)  -- " FASE 00"
TABLA_NUMEROS_NIVEL     ($9E1E, 32 bytes)  -- " 0 1 2...9101112131415"
TEXTO_VIDA_EXTRA        ($9E3E, 24 bytes)  -- "EN LA PROXIMA... EXTRA"
TEXTO_EXTRA             ($9E56,  7 bytes)  -- "EXTRA"
TEXTO_VACIO_1           ($9E5D, 12 bytes)  -- linea en blanco
TEXTO_READY             ($9E69, 12 bytes)  -- "  READY?  "
TEXTO_VACIO_2           ($9E75, 12 bytes)  -- linea en blanco
TEXTO_GAME_OVER         ($9E81, 13 bytes)  -- "ESTAS FRITO"
PTR_TABLA_SPRITES       ($9E8E)            -- ya identificada, sin cambios
```

Sustituidas TODAS las instrucciones mecánicas de esta zona por
directivas `DB` reales (formato `[longitud, atributo, texto]`, igual
que MSX), con etiquetas nuevas para `TEXTO_FASE` y
`TABLA_NUMEROS_NIVEL` (no existían todavía) y datos reales para las 5
ya nombradas en rondas anteriores (hasta ahora solo tenían la etiqueta
de inicio, el resto seguía siendo instrucciones falsas).

**Limpieza consecuente**: las 21 constantes `EQU` que resolvían
autorreferencias falsas dentro de este tramo (`CODE_9E3F`...`CODE_9ED0`,
`CODE_9E83`/`85`/`8D`/`90`/`9B`/`9D`/`9F`/`A1`) quedaron huérfanas al
desaparecer las instrucciones mecánicas que las referenciaban —
eliminadas, comprobando antes que ninguna tenía ya ninguna referencia.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** — confirma que la reconstrucción byte a byte de las 9
tablas/textos es exacta (longitud, atributo y contenido de cada una
coinciden con el binario original).

## Sesión 56 (continuación 24) — sustituidas las 5 direcciones en hex crudo que quedaban de la conversión anterior

Pregunta del usuario: las etiquetas nuevas de la continuación 23
(`TEXTO_FASE`, `TABLA_NUMEROS_NIVEL`, etc.) deberían usarse también
donde el código las referenciaba por dirección explícita — ¿es
correcto? Sí. Comprobado sistemáticamente (grep de cada una de las 9
direcciones contra todo el fichero): 4 ya estaban bien (`TEXTO_VACIO_1`/
`TEXTO_READY`/`TEXTO_VACIO_2`/`TEXTO_GAME_OVER`, etiquetadas en rondas
anteriores), pero **5 seguían en hex crudo** en `PREPARAR_INICIO_NIVEL`/
`COMPROBAR_VIDA_EXTRA`/`COMPROBAR_AVISO_ULTIMA_VIDA`:

- `$9E1E` → `TABLA_NUMEROS_NIVEL`
- `$9E1C` → `TEXTO_FASE+8` (el "00" final de " FASE 00", donde se
  copian los 2 dígitos del nivel)
- `$9E14` → `TEXTO_FASE`
- `$9E56` → `TEXTO_EXTRA`
- `$9E3E` → `TEXTO_VIDA_EXTRA`

De paso, comentarios actualizados: `PREPARAR_INICIO_NIVEL` pasa de
"RESUELTA EN BUENA PARTE" a "RESUELTA POR COMPLETO" (los 3 textos que
dibuja ya tienen contenido confirmado, no solo candidatos), y se repite
en los 2 sitios relevantes la corrección de continuación 18 (el texto
que dibuja `COMPROBAR_AVISO_ULTIMA_VIDA` anuncia la PRÓXIMA vida extra,
pese al nombre histórico de la rutina).

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (sustitución de hex por etiquetas, sin cambio de
bytes).

## Sesión 56 (continuación 25) — `recursos/mapa_memoria.html` puesto al día: pasada completa de las 28 referencias `CODE_XXXX` obsoletas

Pregunta del usuario: ¿se había actualizado la documentación HTML de
`recursos/` en todas las sesiones de hoy? Respuesta honesta: no —
`recursos/flujo_programa.html` sí (se regenera solo con
`tools/gen_inventory.py` en cada ronda), pero `mapa_memoria.html`
(mantenido a mano, sin herramienta de regeneración) llevaba sin
tocarse desde el 14 de agosto, bastante antes de que empezara esta
sesión larga.

**Pasada completa** sobre las 28 referencias `CODE_XXXX` encontradas:

- **Corrección de categoría real** (no solo de nombre): el segmento
  `0x9DB8-0x9E8E` estaba marcado entero `category: "codigo"`, pero
  desde la continuación 23 la mitad (`0x9E01-0x9E8D`) ya es DATO
  (`TABLA_POSICIONES_HUD` + 8 textos). Dividido en 2 segmentos:
  `0x9DB8-0x9E01` (código: `VERIFICAR_ENTRADA`/`ACTUALIZAR_PARPADEO_BOLA`/
  `DESTELLO_ICONO_COLOR_HUD`) y `0x9E01-0x9E8E` (datos, nuevo segmento).
- **Segundo error de categoría, de sesiones anteriores a hoy**: el
  segmento `0x8358-0x83CB` decía `"sin analizar"`/`category: "mecanico"`,
  pero verificado contra `src/build/main.lst` resultó ser código
  totalmente resuelto (`CONSULTAR_LOSETA_LIBRE_DIRECCION` arranca
  exactamente en `$8358`, y el tramo completo hasta `$83CA` es la cola
  de `MOTOR_MOVIMIENTO_ITEM`, ya descrita en el segmento anterior).
  Fusionado con `MOTOR_MOVIMIENTO_ITEM` (ahora `0x81BC-0x83CB`).
- **26 referencias `CODE_XXXX` sustituidas** por su nombre actual,
  mapeadas contra `src/build/main.lst` cuando no bastaba con buscar el
  texto "antes CODE_XXXX" ya presente en `madmix_body.asm` (la mayoría
  ya tenían esa anotación; unas pocas —`CODE_87BC`, `CODE_9C07`,
  `CODE_9534`, `CODE_915A`/`9174`/`917D`/`9182`/`918D`— aparecían en
  crudo sin ella).
- Corregida una afirmación obsoleta que decía "`CODE_8DE5`,
  `CODE_918D`, `CODE_8EB3` siguen sin resolver" — los 3 quedaron
  resueltos en esta misma sesión (`DIBUJAR_CREDITOS_MENU`,
  `APLICAR_ATRIBUTOS_MARCO_PARCIAL`, `INICIAR_DEMO`).

**Verificado**: solo cambios de documentación (comentarios/etiquetas
JS dentro del HTML, sin lógica ni estructura de datos alterada) —
balance de llaves/corchetes comprobado, 67 segmentos de memoria
listados (mismo total que antes: se fusionaron 2 en 1 y se añadió 1
nuevo). No afecta a la compilación del binario.

## Sesión 56 (continuación 26) — falsa alarma: los punteros de `TABLA_NIVELES` ya estaban resueltos, comentario de cabecera desactualizado desde sesión 47

Petición del usuario: resolver el punto 2 de la lista de pendientes
("los 3 punteros por registro de `TABLA_NIVELES` siguen en hex crudo,
sin resolver a `CUERPO_Lxx`/`CABECERA_xxxx`"). Al comprobar el código
real (no solo el comentario que lo señalaba como pendiente): **ya
estaba resuelto**. Las 16 entradas de la tabla ya usan
`CUERPO_L01`...`CUERPO_L15` y `CABECERA_7F1F`/`CABECERA_7F7F`/
`CABECERA_8000` simbólicos en sus 3 punteros — la resolución de esos
datos de nivel en **sesión 50** ya los había sustituido, pero el
comentario de cabecera de `TABLA_NIVELES` (escrito en **sesión 47**,
antes de que esas etiquetas existieran) nunca se actualizó y seguía
diciendo "quedan en hex crudo por ahora". Mismo patrón de comentario
obsoleto ya detectado 2 veces esta sesión (en `mapa_memoria.html` y en
`PREPARAR_INICIO_NIVEL`) — un hallazgo cerrado en una sesión posterior
no siempre se refleja hacia atrás en el comentario que lo señalaba
como pendiente. Corregido el comentario para reflejar el estado real.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (cambio de comentario puro, sin cambio de bytes).

## Sesión 56 (continuación 27) — `TABLA_NIVELES` reescrita en decimal donde el programador original lo habría hecho así

Petición del usuario: revisar en general y escribir los valores como
estarían en el fuente original, ya que datos que originalmente se
habrían escrito en decimal deben notarse en decimal para que el
fuente sea legible como lo pensó el programador (continuación directa
del análisis de la continuación anterior sobre si los números de
`TABLA_NIVELES` tenían sentido en decimal).

Reescritos los 16 registros de la tabla, campo a campo:

- **`duracion_parpadeo`** → decimal puro: son segundos redondos a 50Hz
  en 15 de los 16 niveles (50/80/150/200/250 fotogramas = 1/1.6/3/4/5s);
  el único atípico, `$FF`=255, se anota como probable centinela de
  "máximo" en vez de duración literal.
- **`filas_variable`, `campo7`, `items_tipo3/1/2`, `tile_comodin`** →
  decimal (cantidades pequeñas, sin ambigüedad).
- **`fila_ref`/`columna_ref` y el par "sin identificar"** → decimal:
  confirmado que los 64 valores (16 niveles × 4 campos) son múltiplos
  EXACTOS de 4 sin ninguna excepción — misma unidad de subpíxel que
  `REGISTRO_NIVEL_POSICION_COMECOCOS`. No identifica qué representa el
  segundo par, pero confirma que es la misma familia de dato
  (posición), no un valor arbitrario.
- **`objetivo_bolitas`** → decimal (ya tenía el valor traducido en
  comentario; ahora el literal mismo es decimal).
- **`icono_hud`** → se dejó EN HEXADECIMAL a propósito: no es una
  cantidad, es una de las entradas crudas de `TABLA_POSICIONES_HUD`
  (también en hex) — mantener la misma notación facilita comparar
  ambas tablas a simple vista.
- Los 3 punteros de cada registro (`DW CUERPO_Lxx,CABECERA_xxxx,...`)
  se dejaron como estaban: ya eran simbólicos, no hex crudo (ver
  continuación 26).

Cambio puramente de notación (mismos bytes, distinta base numérica en
el fuente) — regenerado con un script Python que parseó los 16
registros y reescribió cada campo según la regla de arriba, para
evitar errores de transcripción manual en 160 líneas.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original**.

## Sesión 56 (continuación 28) — barrido de todo `madmix_body.asm`: notación hex/decimal según intención del programador original

Petición del usuario: extender el criterio de la continuación 27
(¿decimal o hex según lo habría escrito el programador de 1987?) a
**todo el fichero**, no solo `TABLA_NIVELES`.

**Metodología**: script de triaje automático que localizó los 106
bloques de datos con literales `$hex` (excluyendo `INCBIN` -- bitmap
puro, no aplica -- y código real). Cada uno se clasificó por tipo de
contenido:

- **Ya en decimal** (la mayoría): `TABLA_CLASE_ALINEAMIENTO`,
  `TABLA_DURACIONES`, `TABLA_TONOS_CANAL_A`, `EFECTO_SONIDO_*`,
  `ETIQUETA_TECLA_*`/`TABLA_MENU_OPCIONES_CONTROL` (longitud de texto),
  `PTR_TABLA_SPRITES` (parámetros por sprite), y casi toda la "ZONA DE
  VARIABLES DEL MOTOR" (`REGISTRO_NIVEL_FILAS`, `_LOSETA_COMODIN`,
  `VIDAS_RESTANTES`, `NIVEL_ACTUAL`, etc.) -- alguien ya había aplicado
  este mismo criterio en sesiones anteriores.
- **Correctamente en hexadecimal, sin tocar** (mayoría del resto):
  punteros/direcciones (`PUNTERO_EFECTO_SONIDO_ACTUAL`,
  `ISR_VECTOR_GUARDADO`, posiciones empaquetadas tipo
  `POSICION_ACTUAL_CAMARA`/`REGISTRO_NIVEL_POSICION_COMECOCOS`),
  bytes de atributo/color ULA (`COLOR_ACTUAL`/`COLOR_GUARDADO`, $78),
  opcodes de parche de código automodificable (`PATRON_TONO_1/2`),
  sentinelas (`$FE`/`$FF`), índices de sprite/loseta con bit 7 de
  volteo (`SUBTABLA_DIRECCION_A-D`, `TABLA_ANIMACION_PELMAZOIDE/
  MARICOCO/REGPUNANTOSO`, `EFECTOS_DESTELLO_SEQ_*`), y valores que
  coinciden con entradas crudas de otra tabla ya en hex (`icono_hud`
  frente a `TABLA_POSICIONES_HUD`). Confirmado además por el patrón ya
  visto en `SUBTABLA_DIRECCION_A` (`$00,$01,$02,$01` junto a
  `$80,$81,$82,$81` -- mismo índice con bit7 de volteo) que estas
  tablas son código/bitmask, no cantidades.
- **Genuinamente pendientes de corregir** (4 bytes, todos en la ZONA DE
  VARIABLES DEL MOTOR, todos réplicas en tiempo de ejecución de campos
  de `TABLA_NIVELES` ya decimalizados en la continuación 27):
  `REGISTRO_NIVEL_CONTADOR_PELMAZOIDES` ($02→2) y sus 2 vecinos sin
  etiqueta propia ($6010/$6011, candidatos MARICOCO/REPUGNANTOSO,
  $01→1 cada uno) -- misma familia que `items_tipo3/1/2`;
  `REGISTRO_NIVEL_DURACION_PARPADEO` ($C8→200) -- misma familia que
  `duracion_parpadeo`.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (cambio de notación puro).

## Sesión 56 (continuación 29) — cerrado el pendiente de "49 fragmentos de música sin decodificar": ya no queda ningún byte sin identificar en `$D160-$EFB5`

Petición del usuario: retomar el pendiente de sonido/música de la
lista maestra ("49 fragmentos de música ya extraídos pero no
decodificados canción por canción"). Al revisar el estado real del
rango completo `$D160-$EFB5` (no solo los 49 fragmentos), resultó que
**el pendiente ya estaba cerrado** — el trabajo de la sesión sobre el
`MARCO DECORATIVO` (`CARGAR_MARCO_DECORATIVO`, `$904A`) y sobre los
guiones de demo (`INICIAR_DEMO`) había resuelto, por otro camino sin
conectarlo explícitamente, el resto del rango que la nota de
"pendiente" seguía señalando como abierto:

```
$DBE0-$DD17 (312 B)  guiones de demo                    -- resuelto
$DD18-$E022          43 subpatrones + 6 guiones cancion  -- resuelto (los "49 fragmentos")
$E023-$E037 (21 B)   relleno a cero                      -- confirmado
$E038-$E37F (840 B)  motor de sonido (codigo)            -- resuelto (sesion 55)
$E380-$E3D7 (88 B)   guion de demo (nivel 5)              -- resuelto
$E3D8-$E3F1 (26 B)   2 guiones de demo mas                -- resuelto
$E3F2-$EFA1 (2992 B) bitmap del marco decorativo (RLE)    -- resuelto
$EFA2-$EFB5 (20 B)   relleno a cero                       -- confirmado
```

Ni un byte sin identificar en todo el bloque. Corregidas 4 cabeceras
de comentario que seguían diciendo "sigue sin disparador conocido"/
"sigue como datos sin desensamblar" sobre este rango ya cerrado
(mismo patrón de comentario desfasado de continuaciones 25-27).

Lo que sí sigue siendo trabajo real (no bytes sin identificar, sino
análisis musical/de contenido, de valor bajo/opcional): entender qué
`.snd`/`.spt` corresponde a qué momento del juego (¿qué canción suena
en qué nivel?) más allá de que ya están todos extraídos, con `.txt`
legible y `.wav` renderizado en `build/sound_preview/`.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (cambio de comentario puro, sin cambio de bytes).

## Sesión 56 (continuación 30) — 23 etiquetas más alineadas con MSX (nomenclatura compartida para facilitar la comparación humana)

Petición del usuario: revisar sistemáticamente qué funciones/etiquetas/
variables Spectrum tienen equivalente MSX real pero nombre distinto, y
trasladar la nomenclatura de MSX para facilitar la comparación entre
ambas versiones.

**Metodología**: comparación automática de las 659 etiquetas de
`madmix_body.asm` contra las 568 de MSX (`madmix1_body.asm` +
`madmix_scr_body.asm`) — 296 ya coincidían exactas. Para las 363
restantes, `difflib.get_close_matches` encontró 116 candidatas por
similitud de nombre; cada una se verificó leyendo el código real de
ambos lados (no solo el nombre) antes de renombrar.

### 14 confirmadas por estructura idéntica

`ENLACE_MOTOR_MOVIMIENTO_COLISION` (antes `ENTRADA_...`, ambas `JR
MOTOR_MOVIMIENTO_COLISION`), `SALIR_MOTOR_ACTORES` (antes
`FIN_MOTOR_ACTORES`, mismo epílogo `POP BC/DE/HL/AF`+`RET`),
`BUCLE_PISTA_TANQUE_AVION` + sus 4 etiquetas internas
(`PISTA_FORMATO_B`/`PISTA_FORMATO_B_POS`/`PISTA_FILA_FIJA`/
`DIBUJAR_PISTA`, antes `DIBUJO_FORMATO_B`/`DIBUJO_FORMATO_B_POS`/
`DIBUJO_FILA_FIJA`/`DIBUJAR_SPRITE_PISTA` — rutina completa
comparada instrucción a instrucción), `DESPACHAR_ACCION_MENU` +
`SELECCIONAR_OPCION_TECLADO`/`_DEMO`/`_REDEFINIR_TECLAS`, y
`ESPERAR_TECLA_NUEVA`.

### 10 confirmadas por MSX tener el mismo fenómeno exacto

`GUION_DEMO_NIVEL1/2/4/5` (antes `GUION_DEMO_NIVEL_1/2/4/5`, con guión
bajo) y `GUION_DEMO_SINREF_1-6` (antes `GUION_DEMO_EXTRA_1-6`) — MSX
tiene el mismo patrón exacto (guiones de demo con índice conocido +
6 "huérfanos sin referencia", mismos nombres, `madmix1_body.asm`
~línea 4544).

### 2 errores propios detectados y corregidos antes de compilar

Dos de los renombrados iniciales chocaron con etiquetas que **ya
existían con ese nombre exacto**, de resoluciones de sesiones
anteriores que no se comprobaron antes de renombrar (`sjasmplus`
lo detectó de inmediato: "Duplicate label", más 12 errores en cascada
de rangos `JR` fuera de alcance):

- `GUARDAR_SELECTOR_SPRITE_INICIAL` se había renombrado a
  `GUARDAR_SELECTOR_SPRITE_COMECOCOS` por una coincidencia superficial
  (ambas escriben en `SELECTOR_SPRITE_COMECOCOS`), pero ese nombre
  EXACTO ya lo tenía, con más razón, una convergencia bit7/centinela
  en `ENLACE_MOTOR_MOVIMIENTO_COLISION` que coincide carácter a
  carácter con el `GUARDAR_SELECTOR_SPRITE_COMECOCOS` real de MSX.
  Revertido a su nombre original.
- `DIBUJO_SIGUIENTE_PISTA` (dentro de `BUCLE_PISTA_TANQUE_AVION`) se
  renombró a `SIGUIENTE_PISTA`, pero ese nombre global ya lo tenía
  (correctamente) el cierre de `AVISAR_PROXIMIDAD_PISTA` -- MSX
  resuelve esta misma colisión con una etiqueta LOCAL
  (`.SIGUIENTE_PISTA`) en ese segundo sitio, convención que este
  fichero no usa todavía. Renombrado en su lugar a
  `SIGUIENTE_PISTA_TANQUE_AVION` para desambiguar sin introducir
  etiquetas locales de forma aislada.

Quedan ~90 candidatas más de la búsqueda por similitud sin verificar
individualmente (menor confianza) para una ronda futura si se quiere
continuar.

**Verificado**: `py tools/build_all.py` sin errores (tras corregir los
2 choques), `py tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes
idénticos al `.tzx` original** (renombrado puro, sin cambio de bytes).

## Sesión 56 (continuación 31) — 13 etiquetas más alineadas con MSX; resto de los ~90 candidatos revisados y descartados con motivo

Petición del usuario: continuar con todos los candidatos restantes de
la búsqueda por similitud (continuación 30 dejó ~90 sin verificar
individualmente).

### 13 confirmadas por contenido/estructura idéntica

- `BUFFER_DIGITOS_PUNTUACION` (antes `BUFFER_TEXTO_PUNTUACION`),
  `TEXTO_BESTIA` (antes `ETIQUETA_PUNTUACION_MAXIMA`), `TEXTO_DEMO`
  (antes `ETIQUETA_PUNTUACION_DEMO`) — MSX tiene el MISMO contenido
  byte a byte con esos nombres exactos (`madmix1_body.asm:2188-2193`).
- Las 8 etiquetas de créditos (`TEXTO_CREDITOS_PROGRAMADO_POR`/
  `_NOMBRE_PROGRAMADOR`/`_GRAFICOS_POR`/`_NOMBRE_GRAFICOS`/
  `_MUSICA_POR`/`_NOMBRE_MUSICA`/`_TOPOSHOW`/`_TITULO`, antes
  `ETIQUETA_CREDITOS_*`) — contenido byte a byte idéntico a MSX
  (`madmix_scr_body.asm:4221-4245`).
- `DIBUJAR_CREDITOS` (antes `DIBUJAR_CREDITOS_MENU`) — misma secuencia
  exacta de `DE/HL/CALL DIBUJAR_TEXTO_VRAM` por línea, mismo orden.
- `BUCLE_PAUSA` (antes `BUCLE_ESPERA_PAUSA`) — ambas `HALT`/`DJNZ`,
  pausa fija de 50 fotogramas.

### Candidatos revisados y descartados (con motivo verificado, no solo por nombre)

- `COMPROBAR_ABAJO`/`ARRIBA`/`IZQUIERDA` (línea ~2031): mecanismo
  IDÉNTICO a `COMPROBAR_LOSETA_ABAJO`/`ARRIBA`/`IZQUIERDA` de MSX
  (misma cadena `RRA`+`JR NC`) -- **pero ese nombre exacto YA lo tiene**
  una tercera ocurrencia pre-existente en Spectrum (línea 840, dentro
  de `MOTOR_MOVIMIENTO_COLISION`, también ya alineada con MSX de una
  sesión anterior). Como MSX solo tiene una copia de esta cadena y
  Spectrum tiene dos (una para el comecocos, otra para
  `MOTOR_MOVIMIENTO_ITEM`), no hay 2 nombres MSX distintos que
  repartir -- se dejaron sin tocar para no chocar (aprendida la
  lección de la continuación 30).
- `BUCLE_RESET_MARICOCO`/`PELMAZOIDE`/`REGPUNANTOSO`: pese al nombre
  parecido a `BUCLE_MARICOCO`/`PELMAZOIDE`/`REGPUNANTOSO` de MSX, son
  rutinas DISTINTAS -- las de Spectrum inicializan campos a cero
  (`LD (IX+n),0`), las de MSX llaman a `MOTOR_MOVIMIENTO_ITEM` cada
  fotograma. Ningún parecido real más allá del nombre.
- `APLICAR_DESPLAZAMIENTO_FILA` vs `APLICAR_DESPLAZAMIENTO_LATERAL`:
  la de Spectrum vive dentro de `MOTOR_ACTORES` (campos de sprite), la
  de MSX es scroll de pantalla (140 filas) -- subsistemas distintos.
- `CONTINUAR_LLAMADA_SCROLL` vs `PREPARAR_LLAMADA_SCROLL`: la de
  Spectrum es mucho más amplia (guarda registros, llama a
  `GESTIONAR_SCROLL` Y a los 3 manejadores de ítems), no un simple
  paso de preparación como en MSX.
- `FIJAR_DIRECCION_Y_PASO` vs `FIJAR_DIRECCION_FINAL`: la de Spectrum
  escribe en un campo de actor (`IX+3`), la de MSX en la variable
  global `DIRECCION_DE_MOVIMIENTO` -- contextos distintos
  (`MOTOR_MOVIMIENTO_ITEM` vs movimiento del comecocos).
- `ACTIVAR_NUEVO_MODO_ESPECIAL` vs `AJUSTAR_SPRITE_MODO_ESPECIAL`:
  mecanismos sin relación al leer el código real.
- `TABLA_TECLAS_MENU` vs `TABLA_TECLAS_MENU_PRINCIPAL`/`TABLA_TECLAS_MSX`:
  Spectrum ya documentó que todo `PROCESAR_MENU_CONTROLES` no tiene
  equivalente MSX (menú propio de Spectrum) -- coincidencia de nombre
  sin relación real.
- Restantes de coincidencia puramente textual sin relación de
  contenido: `ACTIVAR_INTERRUPCION_MODO_2` (modos de interrupción
  genuinamente distintos), `COMPROBAR_TECLA`/`LEER_JOYSTICK_KEMPSTON`/
  `_SINCLAIR` (ya diferenciados a propósito, MSX tiene menos esquemas),
  `COPIAR_REGISTRO_NIVEL`, `COMPROBAR_VIDA_EXTRA`,
  `FUNDIR_ACUMULADOR_ENTRADA`, `DESPACHAR_EFECTO_SONIDO_OFFSET`/
  `AVANZAR_EFECTO_SONIDO` (subsistema de efectos sin equivalente MSX),
  `CALCULAR_POSICION_DESTELLO`, `INICIALIZAR_ESTADO_NIVEL`,
  `LEER_TECLADO_MENU` (menú propio de Spectrum), `MOTOR_INICIO`.

Quedan ~50 candidatos de la cola de menor probabilidad (coincidencias
de 1-2 palabras sueltas como "SIGUIENTE"/"BUCLE"/"CALCULAR") sin
verificar uno a uno -- rendimiento decreciente claro en esta ronda
(la mayoría de los últimos candidatos comprobados resultaron ser
coincidencias textuales sin relación real), así que se deja aquí salvo
que se pida seguir explícitamente.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (renombrado puro, sin cambio de bytes).

## Sesión 56 (continuación 32) — cierre de la alineación de nomenclatura con MSX: 3 renombrados más + confirmación de que la mayoría de "candidatos" ya estaban bien desde antes

Petición del usuario: continuar con el resto de los ~90 candidatos de
similitud sin verificar.

### Hallazgo metodológico importante

Al comprobar candidatos como `CALCULAR_DIRECCION_ACERCAMIENTO`,
`COMPROBAR_ABAJO`/`ARRIBA`/`IZQUIERDA`, `FIJAR_DIRECCION_Y_PASO`,
`FIN_CONSULTA_LOSETA`, `LOSETA_BLOQUEADA`, `BUCLE_RESET_MARICOCO`/
`PELMAZOIDE`/`REGPUNANTOSO`, `MODO_BOLA_PODER_ACTIVO`,
`MODO_HIPOPOTAMO_ACTIVO` uno a uno, resultó que **ya tenían el nombre
correcto** -- la comparación automática de las continuaciones 30-31
solo cotejaba contra etiquetas GLOBALES de MSX, sin contar sus
etiquetas LOCALES (con punto, p. ej. `.BUCLE_CARACTER`), que sesiones
Spectrum anteriores a esta ya habían igualado (sin el punto, ya que
este fichero no usa etiquetas locales). Un script comparando contra
las locales de MSX (punto retirado) encontró **52 etiquetas Spectrum**
que ya coincidían exactas por este camino y que mi búsqueda por
similitud de las rondas 30-31 había etiquetado por error como
"candidatos sin verificar" o incluso "descartados" -- estaban bien
desde el principio.

### 3 renombrados nuevos genuinos

`BUCLE_CARACTER`/`CONTINUAR_CARACTER`/`SALTAR_COLUMNAS` (antes
`BUCLE_DIBUJAR_TEXTO_VRAM`/`CONTINUAR_DIBUJAR_TEXTO_VRAM`/
`SALTAR_COLUMNAS_BLANCO`) -- coinciden exactos con las etiquetas
locales `.BUCLE_CARACTER`/`.CONTINUAR_CARACTER`/`.SALTAR_COLUMNAS` del
`DIBUJAR_TEXTO_VRAM` de MSX (`madmix_scr_body.asm:3810-3838`),
estructura idéntica instrucción a instrucción.

### Balance final de esta serie de continuaciones (30-32)

- **331 coincidencias EXACTAS con nombre global de MSX** (296 antes de
  empezar esta serie + 35 renombradas en las continuaciones 30-32).
- **52 coincidencias EXACTAS con nombre LOCAL de MSX** (sin punto),
  todas ya correctas de sesiones anteriores a esta.
- Total: **383 de 659 etiquetas** (58%) con nombre alineado a MSX de
  una forma u otra. El resto son mayormente conceptos genuinamente
  propios de Spectrum sin equivalente MSX (subsistema de efectos de
  sonido, menú de selección de controles, redefinición de teclas,
  soporte de Kempston/Sinclair, datos de sprites/tiles/niveles/sonido
  con nombre propio) -- **rendimiento decreciente confirmado, se da
  por cerrada esta tarea** salvo que aparezca un candidato concreto
  que valga la pena revisar más adelante.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (renombrado puro, sin cambio de bytes).

## Sesión 56 (continuación 33) — mapeadas las 3 canciones a su momento real del juego, etiquetadas simbólicamente

Petición del usuario: averiguar qué canción suena en qué momento del
juego (último punto "opcional" de la lista de pendientes).

**Rastreados los 4 únicos sitios de todo el fichero** que escriben
`$E212`/`$E216` (punteros de canal) antes de `CALL REPRODUCIR_SONIDO`
— son los únicos disparadores posibles de música completa, así que el
mapeo queda cerrado con certeza:

| Canción | Disparador | Momento |
|---|---|---|
| `CANCION_PRESENTACION` ($DFB7/$DFCA, 80 B) | `ESPERAR_TECLA_INICIO` | Pantalla de título |
| `CANCION_PRESENTACION` (otra vez) | `BUCLE_ESPERA_PARTIDA_NUEVA` | Solo al arrancar partida NUEVA |
| `CANCION_INICIO_NIVEL` ($E007/$E00E, 14 B) | Cola de `BUSCAR_COLUMNA_HUD` | Cada vez que arranca a jugarse un nivel (nueva partida, siguiente nivel, o tras perder vida) |
| `CANCION_FIN_MODO_ESPECIAL` ($E015/$E01C, 14 B) | `BUCLE_PRINCIPAL_JUEGO`, cuando `MODO_ESPECIAL_ACTIVO` llega a 0 | Se acaba el efecto de bola de poder/hipopótamo |

El tamaño confirma la lectura: `CANCION_PRESENTACION` (80 B) es una
melodía real; `CANCION_INICIO_NIVEL`/`CANCION_FIN_MODO_ESPECIAL` (14 B
cada una) son jingles cortos, no canciones completas.

Etiquetadas simbólicamente las 6 direcciones (`GUION_CANCION_
PRESENTACION_CANAL_A/B`, `GUION_CANCION_INICIO_NIVEL_CANAL_A/B`,
`GUION_CANCION_FIN_MODO_ESPECIAL_CANAL_A/B`, antes hex crudo `$DFB7`
etc.) y sustituidas las 8 referencias en los 4 sitios disparadores.

Con esto se cierra el último punto "opcional" de la lista de
pendientes de la continuación 29 — no queda ninguna cuestión abierta
sobre qué contenido de sonido/música corresponde a qué.

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original**.

## Sesión 56 (continuación 34) — `recursos/` puesto al día y pulido a "release candidate"

Petición del usuario: revisar los documentos de `recursos/`, ponerlos
al día (varios describían el motor como "sin analizar" pese a que la
ingeniería inversa está cerrada desde la continuación 32) y pulirlos
a una versión definitiva, simplificando contenido y eliminando texto
de pasos intermedios.

**`flujo_programa.html`**: la nota introductoria y el diagrama de
arranque (§1) se detenían justo en `MOTOR_INICIO`, marcado "sin
analizar todavía" — desactualizado desde antes de esta sesión.
Extendido el diagrama con la secuencia real de arranque del motor
(`INICIO` → `ACTIVAR_INTERRUPCION_MODO_2` → `ESPERAR_TECLA_INICIO` →
`REINICIAR_PARTIDA`/`PANTALLA_PRESENTACION_NIVEL` →
`PREPARAR_INICIO_NIVEL` → `BUSCAR_COLUMNA_HUD` →
`BUCLE_PRINCIPAL_JUEGO`) y la caja de `portada_body.asm` pasada de
"pendiente" a "resuelta". Añadidas 3 secciones nuevas: §2 tabla de
despacho `TABLA_SALTOS_MOTOR` (11 entradas, ninguna con llamador real
— a diferencia de MSX, donde el slot 0 sí tiene llamadores), §3
despachador `TABLA_MANEJADORES_LOSETA` (20 entradas) y §4 variables
de estado compartido clave. §5 "Pendientes menores" reescrita a los 2
puntos genuinos que quedan. Inventario renumerado a §6 (sin cambios
de contenido, sigue generado por `gen_inventory.py`).

**`mapa_memoria.html`**: 3 segmentos seguían marcados
"sin analizar"/"mecánico" pese a estar ya resueltos semanas atrás
(`$62C9-$62E1` es `DIBUJAR_CAMBIO_LOSETA`, `$C5DE-$C5FF` es relleno a
cero, los 49 fragmentos de música) — la propia nota de "Pendiente"
de la continuación 29 ya lo señalaba sin que se hubiera corregido el
documento. Corregido `DIBUJAR_CREDITOS_MENU` → `DIBUJAR_CREDITOS`
(renombrada en algún momento posterior a cuando se escribió ese
segmento, sin propagar el cambio). Corregida la nota de
`MAD-MIX.bas (portada)` en la tabla de ficheros, que aún decía
"4188 bytes sin analizar todavía" pese a que la portada es fichero
cerrado desde las sesiones 4-20. Comprimida la nota introductoria
(~70 líneas enumerando cada subsistema resuelto sesión a sesión) a un
párrafo corto y preciso. Eliminada la categoría "mecánico" de la
leyenda (0 segmentos la usan ya).

**`mapa_memoria_logotopo.html`** / **`graficos.html`** /
**`logotopo_formas.html`**: correcciones menores — leyenda con una
categoría sin uso, nota que anunciaba secciones "por venir" que ya
existían, y una afirmación obsoleta sobre que "SOFT" y las letras de
"TOPO" usarían una rutina de dibujo distinta a la de la estrella
(`DIBUJAR_FORMA_LOGO`) — en realidad todas comparten
`DIBUJAR_FORMA_ANIMADA`, la única rutina de bajo nivel del logo.

`portada.html` y `sprites.html` revisados, sin cambios — ya estaban
al día.

**Corrección adicional** (detectada al construir `flujo_secuencial.html`,
ver continuación siguiente): el flow-note de sonido de
`flujo_programa.html` decía que `ISR_SONIDO` "corre dentro de esa
misma interrupción" que `ENTRADA_INTERRUPCION_VBLANK` — INCORRECTO.
`REPRODUCIR_SONIDO` en realidad **sustituye** el vector IM2
($6061-$6062) por `ISR_SONIDO` mientras suena, y bloquea el resto del
juego en un bucle de sondeo de teclado en primer plano
(`BUCLE_TONO_CANAL_A`) hasta que la canción termina o se pulsa una
tecla. Corregido.

No aplica verificación de `.tzx` (cambios solo en `recursos/`, ningún
fichero fuente de `src/` tocado).

## Sesión 56 (continuación 35) — creados `flujo_detallado.html` y `flujo_secuencial.html`, análogos a los del proyecto MSX

Petición del usuario: MSX tiene 2 documentos de flujo más
(`flujo_detallado.html`, grafo de llamadas real; `flujo_secuencial.html`,
diagrama del orden de ejecución) que Spectrum no tenía — crear los
equivalentes.

**`tools/gen_flow_diagram.py`** (nuevo, adaptado del homónimo de
MSX): genera `flujo_detallado.html` a partir del grafo de llamadas
`CALL` real entre las 82 etiquetas "función" de `gen_inventory.py`
(mismo criterio de alcance que MSX: sin manejadores de tabla de
salto, sin aristas atribuidas a un origen no fiable). `CATEGORY`
propia con las 82 funciones clasificadas a mano en 7 subsistemas
(arranque/portada 18, motor 14, ítems 10, HUD 12, menú 10, sonido 4,
gráficos 14) — ninguna cae en "sin clasificar". Ejecutado:
82 nodos, 28 aristas, 206 CALL descartados por no tener un nodo
origen fiable (misma proporción que MSX).

**`recursos/flujo_secuencial.html`** (nuevo, curado a mano —
mismo criterio que el de MSX, no autogenerado): diagrama Mermaid del
ORDEN REAL de ejecución, trazado línea a línea contra
`src/madmix_body.asm`: cadena de arranque → interrupción IM2 en
paralelo (con el hallazgo de que `REPRODUCIR_SONIDO` sustituye ese
vector y bloquea el juego mientras suena, ver continuación anterior)
→ pantalla de título (`ESPERAR_TECLA_INICIO`) → doble reentrada
`REINICIAR_PARTIDA`/`PANTALLA_PRESENTACION_NIVEL` → menú de
controles (`PROCESAR_MENU_CONTROLES`, con el detalle real de que
`SELECCIONAR_SINCLAIR`/`SELECCIONAR_KEMPSTON` retornan directamente
sin limpiar la pantalla del menú, a diferencia de las otras 3
opciones) → modo demo (`INICIAR_DEMO`, ciclador de 4 niveles
pregrabados) → presentación de nivel (`PREPARAR_INICIO_NIVEL`,
`BUSCAR_COLUMNA_HUD`) → bucle de cada frame
(`BUCLE_PRINCIPAL_JUEGO`/`MOTOR_MOVIMIENTO_COLISION`, con el
despacho completo a los 17 manejadores de `TABLA_MANEJADORES_LOSETA`
y las 3 franjas SIEMPRE/CONDICIONAL/EVENTO). Mismo motor visual que
el de MSX (Mermaid.js, zoom/tooltip/leyenda por checkbox), reescrito
para reflejar la estructura real de Spectrum en vez de copiar la de
MSX.

**Hallazgo real durante la construcción** (no solo redacción): la
lógica de "resta 1 vida" en `BUCLE_PRINCIPAL_JUEGO` está anidada
DENTRO de la comprobación de cuenta atrás de `MODO_ESPECIAL_ACTIVO`
— la resta (`VIDAS_RESTANTES += ($6003)`) solo se ejecuta cuando esa
cuenta atrás llega a 0, no en un sitio separado. El código ya lo
documentaba así (comentario de cabecera de sesiones previas); esta
continuación solo lo verificó instrucción a instrucción para
representarlo correctamente en el diagrama.

No aplica verificación de `.tzx` (documentación + herramienta nueva,
ningún fichero fuente de `src/` tocado).

## Sesión 56 (continuación 36) — confirmado por simulación: Spectrum SÍ tiene un lienzo de laberinto en RAM (como MSX), pero NO necesita buffer de actores

Petición del usuario: comparando `mapa_memoria.html` de MSX (que
documenta un "buffer de render de actores" en `$0500-$1000` y un
"lienzo de bitmap en RAM" en `$DE04`) contra el de Spectrum, preguntó
si Spectrum tiene equivalentes — y pidió investigarlo a fondo con
evidencia real, no solo razonamiento a mano.

**Herramienta nueva**: `tools/mmcanvas_sim.py`, un simulador Z80 mucho
más completo que `mmesquema_sim.py` (cobertura razonable de los
juegos de opcodes sin prefijo, CB, ED, DD/FD — IX principalmente, que
es el único que usan estas rutinas), construido específicamente para
esta pregunta siguiendo la misma filosofía del proyecto: ejecutar el
código real sobre una copia real de `FISICO/CODE.bin` y observar
dónde escribe de verdad, en vez de deducirlo a mano (código
automodificable y memoria reciclada hacían el razonamiento manual
poco fiable).

### Confirmado: SÍ hay un lienzo de laberinto en RAM, más grande de lo documentado hasta ahora

`GESTIONAR_SCROLL`, `REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM` y
`REDIBUJAR_LOSETA_BUFFER_VRAM` (y por tanto `DIBUJAR_CAMBIO_LOSETA`,
que llama a esta última cada vez que una loseta cambia en vivo — p.
ej. al comerse una bolita) **no escriben en la pantalla real**
(`$4000-$57FF`): escriben en una zona de trabajo en RAM que arranca
en `$E404` y que la simulación confirma que llega hasta al menos
`$F88C` — mucho más allá de lo que `mapa_memoria.html` documentaba
como límite de `BITMAP_MARCO_DECORATIVO` (`$EFA1`). Es la misma
memoria que ocupaba el bitmap RLE comprimido del marco decorativo,
reciclada una vez `CARGAR_MARCO_DECORATIVO` ya la consumió — el
equivalente real y directo del "lienzo de bitmap en RAM" que MSX
mantiene en `$DE04` (mismos 3 últimos dígitos de dirección, `xE04`,
coincidencia nada casual dado que MSX es un port de este código).

**Corrección importante**: esto significa que la nota anterior sobre
`LOADER.bin` ("ya se ejecutó... pero sigue residente en RAM, nada lo
sobrescribe después") era una suposición sin verificar — SÍ se
sobrescribe, en tiempo de ejecución, por este mismo lienzo (su rango,
`$EFB6-$F07A`, cae dentro de la zona de escritura confirmada). Sin
consecuencia real: para cuando el lienzo lo usa, `LOADER.bin` ya
cumplió su única función.

Solo el HUD (marcador de puntos, iconos de vida) se dibuja aparte,
directo a pantalla real, vía `CALCULAR_DIRECCION_PANTALLA` — confirmado
revisando sus 5 únicos llamadores en todo el fichero, ninguno
relacionado con el lienzo del laberinto.

### Confirmado: NO hace falta un buffer de actores separado (a diferencia de MSX)

`MOTOR_ACTORES` calcula la dirección de pantalla REAL del actor con
`CALCULAR_DIRECCION_PANTALLA` y la guarda directamente en el registro
del actor (`TABLA_ACTORES_ACTIVOS`, offset+2/+3) — confirmado leyendo
el código fuente directamente (sin ambigüedad ni automodificación
posible en este punto). `DIBUJAR_ACTORES_PENDIENTES` compone el
sprite (máscara AND + patrón OR) DIRECTAMENTE sobre esa dirección
real, sin ningún paso intermedio. Tiene sentido arquitectónico: el
Spectrum tiene la pantalla mapeada en memoria normal, así que el CPU
ya puede escribir en ella sin restricción — el paso extra que MSX
necesita (su VDP solo es accesible por puertos, más lento) no hace
falta aquí.

### Pendiente: el mecanismo de volcado del lienzo a pantalla real no se ha localizado

Búsqueda exhaustiva sin éxito: los 5 llamadores de
`CALCULAR_DIRECCION_PANTALLA` (los mismos de arriba, todos HUD/texto),
el cuerpo completo de `WAIT_VBLANK` (solo `EI`/`HALT`, nada más) y de
`TICK_REDIBUJADO_VBLANK` (solo `REFRESCAR_ESQUEMA_COLOR_NIVEL` +
`DIBUJAR_ACTORES_PENDIENTES`), y confirmado que el operando `$E404`
de estas instrucciones no se automodifica en ningún sitio del
fichero. El juego es jugable y el laberinto se ve correctamente en
pantalla real, así que el volcado tiene que existir en algún punto —
candidato razonable para una sesión futura con más herramientas (un
emulador con salida de vídeo real permitiría observar el efecto en
vivo en vez de deducirlo del código estático).

**Documentación actualizada**: `recursos/mapa_memoria.html` — el
segmento `BITMAP_MARCO_DECORATIVO` ampliado con esta nota; nuevo
segmento `$EFA2-$F88C` (antes repartido entre "relleno a cero" y
`LOADER.bin`, ahora unificado como "lienzo de trabajo del laberinto
en RAM"); ajustado el límite del segmento "sistema/BASIC" siguiente
(antes empezaba en `$F07A`, ahora en `$F88C`); segmento
`MOTOR_ACTORES` ampliado con el hallazgo sobre actores. Total de
segmentos: 66 (antes 67, al fusionar 2 en 1).

No aplica verificación de `.tzx` (investigación + documentación +
herramienta nueva, ningún fichero fuente de `src/` tocado).

## Sesión 56 (continuación 37) — CORRECCIÓN: sí hay un buffer de render de actores (la continuación 36 se equivocó)

Petición del usuario: seguir buscando el mecanismo de volcado del
lienzo del laberinto, con la pista de que "debe haber una rutina que
explícitamente empieza a escribir en $4000 con origen el lienzo".

Repasando `MOTOR_ACTORES` de arriba abajo (la mitad central,
`$91FD-$9467`, no se había leído línea a línea en la continuación
36) apareció un mecanismo que la continuación 36 pasó por alto:
además de calcular la dirección de pantalla real con
`CALCULAR_DIRECCION_PANTALLA` (registro del actor, offset+2/+3, esto
sí estaba bien), `MOTOR_ACTORES` **compone el sprite ya volteado y
desplazado a nivel de sub-píxel (0-7) en un buffer de trabajo en
RAM**, vía `BUCLE_FILA_ACTOR`/`ESCRIBIR_FILA_ACTOR`/
`ENTRADA_DESPLAZAR_DERECHA`/`IZQUIERDA`/`COMPONER_CELDA_DERECHA`/
`IZQUIERDA` — un bump-allocator: `$91CA` guarda el puntero de
escritura actual, reiniciado a `$F701` cada frame (cuando el
contador de actores `$91C9` está a 0) y avanzando según cuántas
filas tenga el sprite. Ese puntero se guarda en el registro del
actor (offset+5/+6) — y `DIBUJAR_ACTORES_PENDIENTES` (ya lo había
leído bien en la continuación 36) lee DESDE ahí, no desde
`PTR_TABLA_SPRITES` directamente, y compone AND/OR sobre la
dirección real (offset+2/+3).

**CONFIRMADO por simulación** (`tools/mmcanvas_sim.py`, ampliado con
`LD A,R`/`LD R,A`): llamando a `RESET_CONTADOR_ACTORES` +
`MOTOR_ACTORES` para un actor de prueba, escribió 144 direcciones
distintas en `$F701-$F790` — ni una sola en pantalla real.

Es decir: SÍ hay un equivalente real al "buffer de render de
actores" que MSX tiene en `$0500-$1000` — la conclusión de la
continuación 36 ("Spectrum NO necesita buffer de actores") era
**incorrecta**, específicamente por no haber leído esa sección
central de `MOTOR_ACTORES`. La diferencia real con MSX no es "con
buffer vs. sin buffer", sino "rango fijo separado (MSX) vs.
bump-allocator dinámico dentro de la misma zona reciclada que el
lienzo del laberinto (Spectrum, `$F701` cae dentro de
`$EFA2-$F88C`)".

**Sigue sin resolverse** (esta era la pregunta original): el volcado
del LIENZO DEL LABERINTO a pantalla real. Se comprobaron además en
esta continuación: las 17 instrucciones `LDIR`/`LDI`/`LDDR` de todo
el fichero (ninguna copia desde el lienzo a pantalla real), el
cuerpo completo de `ISR_SONIDO` (solo sonido, sin escritura de
vídeo), y una simulación con un **nivel real cargado** (`CARGAR_NIVEL`
ejecutado de verdad, no datos sueltos) seguido de
`REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM`: la pantalla real
($4000-$57FF) permanece en cero fuera de los 288 bytes del HUD/iconos,
mientras que el lienzo (`$E404+`) sí contiene datos estructurados
reales (patrones de bits reconocibles como gráficos de loseta reales,
no basura). El descubrimiento del buffer de actores demuestra que el
patrón "componer en RAM ahora, volcar más tarde desde otra rutina" sí
existe en este motor — pero la única consumidora de ese patrón en la
interrupción (`DIBUJAR_ACTORES_PENDIENTES`, vía `TICK_REDIBUJADO_VBLANK`)
solo lee del registro de actores, no de ningún puntero global al
lienzo, así que no es ella. Queda como pendiente concreto para una
sesión con más herramientas (emulador con vídeo real).

**Documentación corregida**: `recursos/mapa_memoria.html` (segmento
`MOTOR_ACTORES`) y `tools/mmcanvas_sim.py` (docstring).

No aplica verificación de `.tzx` (investigación + documentación,
ningún fichero fuente de `src/` tocado).

## Sesión 56 (continuación 38) — RESUELTO: `BUCLE_MEZCLA_ESQUEMA_COLOR` es el volcado del lienzo a pantalla real

Petición del usuario: seguir buscando, con la pista de que "debe haber
una rutina que explícitamente empieza a escribir en `0x4000` con
origen el lienzo".

Repasando `MOTOR_ACTORES` completo se descartó que el buffer de
actores (continuación 37) tuviera relación con el laberinto, y una
revisión de los 17 manejadores de tipo de loseta (incluidas las 3
trampillas, que no se habían leído) confirmó que TODOS pasan por
`REDIBUJAR_LOSETA_BUFFER_VRAM` (el lienzo), sin excepción.

**El hallazgo real vino de reconsiderar `REFRESCAR_ESQUEMA_COLOR_NIVEL`/
`BUCLE_MEZCLA_ESQUEMA_COLOR`** ($95FB): una sesión anterior a esta
(no la continuación 36) ya la había caracterizado por simulación como
*"IDEMPOTENTE, toca un pequeño conjunto fijo de bytes de pantalla
real -- candidato a parpadeo puntual de 1-2 celdas del HUD"* — pero
esa prueba se hizo con el lienzo **vacío**, sin datos de nivel reales.
`PREPARAR_TABLA_ESQUEMA_COLOR` construye su tabla en la MISMA zona de
memoria que `GESTIONAR_SCROLL`/`REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM`
usan como lienzo ($E400 vs. $E404) — con el lienzo sucio de contenido
real, el comportamiento de la rutina cambia radicalmente.

**Prueba decisiva** (`tools/mmcanvas_sim.py`, test 5): `PREPARAR_TABLA_ESQUEMA_COLOR`
→ `CARGAR_NIVEL` real → `REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM` (para
poblar el lienzo con el nivel 1 de verdad) → `REFRESCAR_ESQUEMA_COLOR_NIVEL`.
Resultado: **3456 direcciones distintas de pantalla real escritas**
(144 de las 192 líneas de píxel, `$4044-$577B` — exactamente el área
jugable, sin el marco decorativo), estable fotograma a fotograma
(mismas direcciones en 4 llamadas sucesivas), y **el contenido
resultante en pantalla real coincide byte a byte con el contenido del
lienzo** en ese instante (`fd 60 fd 60 80 00 80 00...` en ambos
sitios). Sin ambigüedad: esta es la rutina que traduce el lienzo
LINEAL en RAM a la pantalla REAL entrelazada, y se llama cada VBLANK
relevante vía `TICK_REDIBUJADO_VBLANK` — exactamente la pieza que
faltaba.

El algoritmo EXACTO (cómo cada nodo de 10 bytes de la cadena resuelve
el direccionamiento entrelazado) no se ha derivado instrucción a
instrucción — la rutina hace una danza muy densa de `PUSH`/`POP` con
`SP` redirigido, alternando banco de registros (`EXX`), recorriendo
una estructura tipo cadena enlazada; confirmado solo por su efecto
observado, no por lectura completa del mecanismo interno. Queda como
posible refinamiento futuro, de baja prioridad (ya no es un misterio
funcional, solo falta la explicación instrucción a instrucción).

**Corregido**: el comentario de cabecera de `BUCLE_MEZCLA_ESQUEMA_COLOR`
en `src/madmix_body.asm` (solo el comentario — recompilado y verificado
`0 diferencias, 48485 bytes idénticos`), `recursos/mapa_memoria.html`
(segmento `BITMAP_MARCO_DECORATIVO`) y `tools/mmcanvas_sim.py`
(docstring + test 5 nuevo, reproduce el hallazgo en cada ejecución).

**Verificado**: `py tools/build_all.py` sin errores, `py
tools/gen_tzx_file.py` → **0 diferencias, 48485 bytes idénticos al
`.tzx` original** (cambio de comentario únicamente).
