# Manual del subsistema gráfico — Mad Mix Game (ZX Spectrum 48K, ULA)

*[Read this in English](manual_subsistema_grafico.en.md)*

*Ingeniería inversa, análisis y documentación: Rafael Eduardo Martín Candial (raemca@hotmail.com)*

> Fuente: `src/madmix_body.asm` (motor de actores, sistema de losetas del
> laberinto, scroll, volcado a pantalla real, color/atributos). Para la
> crónica de cómo se descubrió cada pieza, ver `FINDINGS.md`; este
> documento asume que ya está todo identificado y explica el resultado
> final de forma ordenada.

## 1. Qué es esto y qué NO es

Este manual explica cómo el juego pone gráficos en pantalla en un ZX
Spectrum 48K: cómo está organizada la memoria de vídeo de la ULA, cómo
se dibuja el laberinto con su scroll, cómo se compone cada personaje, y
— la pieza más elaborada del subsistema — cómo un **lienzo de trabajo
en RAM normal** (no la pantalla real) se vuelca a memoria de vídeo cada
fotograma con un truco de bajo nivel muy particular.

**Punto de partida distinto al del proyecto hermano de MSX**: el MSX1
tiene un VDP con sprites hardware que el juego decide no usar; el ZX
Spectrum, en cambio, **no tiene ningún hardware de sprites que se
pudiera usar** — la ULA solo ofrece un bitmap de 256×192 más una tabla
de atributos de color, sin ningún concepto de "objeto gráfico" aparte.
El resultado práctico es el mismo en ambas versiones (blitting manual
con máscara + patrón), pero aquí no es una elección de diseño: es la
única forma de dibujar un personaje que existe en la máquina. Es la
explicación técnica real de por qué la versión de MSX "se comporta como
un Spectrum" (ver `manual_subsistema_grafico.md` de MSX, §1) — ambas
implementan, por motivos distintos, exactamente el mismo algoritmo.

**No es** un motor con hardware de scroll ni de atributos por sprite:
como en MSX, el scroll de 4px de la cámara (§5) es software puro sobre
un buffer en RAM, volcado a la pantalla real una vez por fotograma.

## 2. El hardware: la ULA en modo de pantalla estándar

Dos zonas de memoria mapeadas directamente en el espacio de
direcciones del Z80 (sin puertos de E/S — a diferencia del VDP del
MSX, la CPU escribe los píxeles y el color como si fueran RAM normal):

| Zona | Dirección | Tamaño | Contenido |
|---|---|---|---|
| Bitmap | `$4000`-`$57FF` | 6144 bytes | 1 bit por píxel (256×192), con el direccionamiento **entrelazado** clásico del Spectrum (ver §6) — no es lineal fila a fila |
| Atributos | `$5800`-`$5AFF` | 768 bytes | 1 byte por celda de carácter (32×24): tinta/papel (3 bits cada uno), brillo, parpadeo |

El único puerto de E/S relacionado con vídeo es `$FE` (compartido con
teclado y cinta), usado solo para el color del borde — no para dibujar
nada dentro de la pantalla. Todo lo demás es escritura directa a `HL`/
`DE` sobre las dos zonas de arriba.

## 3. El motor de actores en dos pasadas: `MOTOR_ACTORES` + `DIBUJAR_ACTORES_PENDIENTES`

El corazón del subsistema — llamado para preparar cada personaje
(comecocos, fantasmas, mariquita, "repugnantoso", pistas de tanque/
avión, marcador...) que haga falta redibujar ese fotograma. Igual que
en MSX, el trabajo se divide en **dos pasadas separadas**, pero aquí
ambas viven en el mismo fichero fuente y están completamente resueltas:

### 3.1 Primera pasada — `MOTOR_ACTORES` (`$91D0`)

1. **Filtrado**: descarta el actor si ya hay 10 activos (`$91C9`,
   contador de actores de este fotograma, contra `10`), si el índice
   de sprite no es válido (`B` contra `64`), o si su columna cae fuera
   de la ventana visible (`E` contra `4` y `116`). **Nota de fidelidad**:
   el límite de `64` parece heredado sin ajustar de MSX — la tabla real
   de punteros de sprite (`PTR_TABLA_SPRITES`, `$9E8E`) solo tiene sitio
   para **28 entradas** (112 bytes) antes de topar, sin hueco, con la
   tabla de fuente de texto (`$9EFE`); no se ha observado ningún caso
   real que use índices por encima de 27.
2. **Reserva de registro**: calcula `IX = $9F9A + $91C9*10` — un
   registro de 10 bytes dentro de `TABLA_ACTORES_ACTIVOS` (`$9F9A`, 100
   bytes = 10 actores × 10 bytes), y calcula la posición real en
   pantalla con `CALCULAR_DIRECCION_PANTALLA` (§6), descartando el
   actor si su fila cae fuera de la franja de cámara visible.
3. **Volteo**: si el sprite necesita espejo horizontal o vertical (2
   bits del byte de control), lo aplica ANTES de componer, sobre una
   copia temporal — `VOLTEAR_PATRON_HORIZONTAL` (inversión bit a bit
   clásica, `RLC`/`RRA` ×8 por byte) o el trío
   `CALCULAR_LIMITE_INTERCAMBIO`/`COMPROBAR_INTERCAMBIO_NECESARIO`/
   `BUCLE_INTERCAMBIAR_DATOS` (intercambia dos regiones de datos de
   sprite para el volteo vertical).
4. **Desplazamiento sub-pixel + escritura en el buffer de pre-render**:
   con la ULA solo se puede escribir un byte (8 píxeles) a la vez —
   igual que el motor de MSX, este implementa desplazamiento de **0 a 7
   bits** rotando máscara+patrón bit a bit entre registros
   (`BUCLE_DESPLAZAR_DERECHA`/`_IZQUIERDA`, alternando bancos con `EXX`
   para procesar 2 filas a la vez, vía `BUCLE_FILA_ACTOR`/
   `ESCRIBIR_FILA_ACTOR`), pero en vez de mezclar directamente contra
   la pantalla real, **escribe el resultado en un buffer de pre-render
   dinámico** que arranca en `$F701` — un asignador tipo "bump
   allocator": cada actor añade sus filas a partir del puntero rodante
   `$91CA` (que queda listo para el siguiente actor), y `$91C9` (el
   mismo contador de actores del filtrado) se resetea cada fotograma
   con `RESET_CONTADOR_ACTORES`. El registro de 10 bytes en
   `TABLA_ACTORES_ACTIVOS` guarda tanto la dirección real de pantalla
   (offset+2/+3) como el puntero a este buffer de pre-render
   (offset+5/+6).

### 3.2 Segunda pasada — `DIBUJAR_ACTORES_PENDIENTES` (`$945A`)

No dibuja en el momento en que `MOTOR_ACTORES` decide la posición de
cada actor: los **encola**, y esta rutina, llamada desde
`TICK_REDIBUJADO_VBLANK` (justo después de sincronizar con
`WAIT_VBLANK`, ver §7), dibuja TODOS los actores pendientes de una vez
— candidato claro a evitar parpadeo/desgarro dibujando todo en el mismo
instante del barrido en vez de repartido a lo largo del fotograma.

Usa el mismo truco Z80 de leer datos con `POP` en vez de `LD`/`INC`:
redirige `SP` al buffer de pre-render (`LD SP,HL`, guardando el `SP`
real en `$91CC`) y, por cada actor, hace **código automodificable**:
los 3 bytes de máscara de recorte del registro (offset 7-9) se
reescriben en caliente en 6 posiciones gemelas de `BLIT_ACTOR_PENDIENTE`
— normalmente esas 6 posiciones son la secuencia `AND E`/`OR D`/`LD
(HL),A` que compone el píxel sobre la pantalla real, celda a celda de
una rejilla de 2×3. `BC`/`IX` recorren `TABLA_ACTORES_ACTIVOS` hasta
agotar el contador, y al terminar restaura `SP` y pone
`CONTADOR_ACTORES_ACTIVOS` (`$91C9`) a 0 — vacía la cola para el
fotograma siguiente.

## 4. El sistema de losetas del laberinto: un lienzo en RAM, no la pantalla real

A diferencia de los actores, el laberinto no se recalcula actor a
actor: es un **lienzo de trabajo en RAM corriente** (`$E404` en
adelante) que se va actualizando loseta a loseta y se vuelca a pantalla
real una vez por fotograma (§6). Ese rango de memoria **no es una zona
dedicada**: es la misma memoria que ocupaba `BITMAP_MARCO_DECORATIVO`
(`$E3F2`, 2992 bytes) mientras se dibujaba el marco decorativo de
carga — en cuanto `CARGAR_MARCO_DECORATIVO` termina de descomprimirlo a
pantalla, esos bytes dejan de hacer falta y `PREPARAR_TABLA_ESQUEMA_COLOR`
(§6) reutiliza la misma memoria como área de trabajo. Economía de
memoria típica de un Spectrum de 48K, no una zona reservada a propósito.

- **`MAPEAR_LOSETA_A_GRAFICO`**: dada una posición de cámara/loseta,
  calcula la dirección real del gráfico de esa loseta
  (`GRAFICOS_LOSETAS + índice×32` — cada loseta ocupa 32 bytes,
  `GRAFICOS_LOSETAS = $C600`) y lo copia al lienzo. De paso alterna el
  bit 7 de `TABLA_TIPOS_LOSETA[índice]` cuando el byte crudo de la
  celda del nivel trae su propio bit 7 activo (candidato a "loseta ya
  visitada/comida"), aunque como el despacho real de tipo de loseta
  solo mira los bits 0-4, este toggle no tiene efecto observable en el
  juego — vestigio confirmado, sin impacto.
- **`REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM`**: redibujado TOTAL del
  lienzo (recorre las 36 filas de losetas visibles llamando a
  `BUCLE_REDIBUJAR_FILA_VERTICAL`/`MAPEAR_LOSETA_A_GRAFICO`) — usado al
  arrancar o cambiar de nivel, no cada fotograma.
- **`REDIBUJAR_LOSETA_BUFFER_VRAM`** (`$99BD`): actualiza una sola
  loseta (16×16 px) en el lienzo — llamada por `DIBUJAR_CAMBIO_LOSETA`
  cada vez que una loseta cambia de estado en juego (p. ej. al comerse
  una bolita).
- **El volcado real a pantalla lo hace exclusivamente el mecanismo del
  §6** — ni el redibujado de losetas ni el scroll (§5) tocan `$4000`
  directamente en ningún momento; solo escriben en el lienzo.

## 5. El scroll por software (4px, sin hardware de scroll)

`GESTIONAR_SCROLL` (`$967D`) decide la dirección según los bits de
entrada ya leídos (`DECIDIR_DIRECCION_SCROLL`) y despacha a una de 4
rutinas:

- **`SCROLL_ARRIBA`/`SCROLL_ABAJO`**: desplazamiento vertical por
  bloques `LDI` (24 `LDI` seguidos ×2 pasadas, moviendo el lienzo
  entero una fila de carácter) más una fila nueva de losetas
  redibujada al final con `MAPEAR_LOSETA_A_GRAFICO`.
- **`SCROLL_IZQUIERDA`/`SCROLL_DERECHA`**: desplazamiento horizontal
  encadenando **`RRD`/`RLD`** (la instrucción Z80 de rotación de
  nibble a través de `(HL)` y el nibble bajo de `A`) — el mismo truco
  clásico de 8 bits que usa MSX para desplazar contenido medio-byte sin
  desplazamiento de bit a bit explícito — seguido de
  `COPIAR_COLUMNA_ALINEADA`/`_DESALINEADA` para la columna nueva que
  entra por el borde.

**Orden de bits distinto al de MSX, y no es un error**: en
`DECIDIR_DIRECCION_SCROLL` el orden es DERECHA/IZQUIERDA/ABAJO/
ARRIBA (fallthrough), mientras que MSX usa ARRIBA/ABAJO/DERECHA/
IZQUIERDA. Confirmado descifrando `TABLA_TECLAS_MODO_0` (`$9B45`,
esquema QAOP clásico de Topo Soft: Q=arriba, A=abajo, O=izquierda,
P=derecha, que produce exactamente este orden de bits) y verificado
también por un desarrollador externo con su propio desensamblado
independiente: cada versión lee su propio teclado/joystick con su
propio orden de bits, y lo único que debe coincidir es que cada versión
sea consistente consigo misma.

Las 4 rutinas escriben SOLO en el lienzo (`$E404` en adelante) — nunca
en `$4000` directamente, exactamente el mismo principio arquitectónico
que en MSX (donde `ACTUALIZAR_VRAM_FRAME` es la única función que
copia a VRAM real).

## 6. El volcado del lienzo a pantalla real: el truco de `SP` dirigido

Esta es la pieza más particular del subsistema, y la que costó más
investigación identificar (ver `FINDINGS.md`). El mecanismo completo,
en dos rutinas:

### 6.1 `PREPARAR_TABLA_ESQUEMA_COLOR` (`$954E`-`$95AA`) — una vez por nivel

`CALCULAR_DIRECCION_PANTALLA` (`$9656`) es la fórmula estándar de
direccionamiento entrelazado del Spectrum — dado `B`=línea de píxel
(0-191) y `C`=columna×8, calcula
`HL = $4000 | (Y7·Y6·Y2·Y1·Y0)<<8 | (Y5·Y4·Y3)<<5 | columna` (los tres
campos entrelazados clásicos de la memoria de pantalla del 48K) — pero
cuesta unas 10 instrucciones de rotación de bits, caro si se llamara
una vez por byte cada fotograma (3456 veces). En vez de eso, se llama
**solo 288 veces por nivel** (2 direcciones × 144 líneas de píxel
jugables) y el resultado se deja precalculado dentro de una tabla de
144 filas de 31 bytes cada una (`$E400` en adelante — justo antes del
lienzo):

- offset +0/+1: dirección de pantalla real ya resuelta para la
  **columna de carácter 16**.
- offset +2/+3: un puntero de encadenado (tabla paralela con paso 32,
  no 31 — se desalinea progresivamente de la tabla principal; si es
  deliberado o un efecto colateral del reciclado de memoria no está
  confirmado).
- offset +28/+29: dirección de pantalla real para la **columna 28**.
- El resto de cada fila (24 de los 31 bytes) no se toca — conserva lo
  que dejó el bitmap del marco decorativo, usado como relleno sin que
  su valor concreto importe para que el mecanismo funcione (verificado
  por simulación).

### 6.2 `BUCLE_MEZCLA_ESQUEMA_COLOR` (`$95FB`) — cada VBLANK relevante

Llamada desde `REFRESCAR_ESQUEMA_COLOR_NIVEL` (`$95B0`-`$965D`, a su
vez llamada desde `TICK_REDIBUJADO_VBLANK`, §7) con `IX=$E400`. El
algoritmo, derivado instrucción a instrucción con un simulador Z80
propio (`tools/mmcanvas_sim.py`, instrumentado para registrar cada
`LD SP,xx`):

1. **`LD SP,IX` / 8×`POP`**: redirige `SP` a apuntar dentro de la fila
   de la tabla — no a la tabla de direcciones, sino a los 16 bytes de
   datos del **lienzo** en esa posición. El primer `POP` (a `IX`) trae
   la dirección de pantalla YA CALCULADA para la columna 16 (la que
   `PREPARAR_TABLA_ESQUEMA_COLOR` dejó en offset+0/+1); los 7 `POP`
   siguientes (a `HL`/`AF`/`DE`/`BC`, y tras `EXX`, otra vez
   `HL`/`DE`/`BC`) leen 14 bytes más de datos reales del lienzo, en los
   dos bancos de registros.
2. **`LD SP,IX`**: con `IX` ahora apuntando a la dirección REAL de
   pantalla (columna 16 de esa línea), el código "salta" ahí
   redirigiendo `SP` una segunda vez.
3. **2 bloques de `PUSH` de 6 bytes cada uno** (banco normal y, tras
   `EXX`, banco alterno — 12 bytes en total): como `PUSH` decrementa
   `SP` ANTES de escribir, esos 12 bytes caen **hacia atrás** desde el
   ancla de columna 16, cubriendo las columnas 4-15.
4. **La misma danza se repite con el segundo ancla** (columna 28,
   también leído del mismo tramo de 16 bytes), escribiendo hacia atrás
   las columnas 16-27.
5. Entre los dos anclajes: las **24 columnas exactas** del área
   jugable de esa fila, sin huecos ni solape — el "trabajo" de mezcla
   ya lo hizo la fórmula de direccionamiento al escribir las dos
   anclas, no hay ningún `AND`/`OR` de por medio: es una copia directa.
6. El avance a la fila siguiente sale del propio `HL` leído en la misma
   pasada (el puntero de "encadenado" de paso 32 que
   `PREPARAR_TABLA_ESQUEMA_COLOR` también dejó preparado) — por eso el
   bucle entrelaza la cadena de `IX` con la de `HL` en vez de
   incrementar un puntero simple. Repite hasta que el byte alto de `IX`
   llega a 0 (fin de las 144 filas).

**Verificado por simulación con un nivel real cargado** (no con el
lienzo vacío, que fue el error de una caracterización previa de esta
rutina): escribe **3456 direcciones de pantalla real** (144 filas × 24
columnas, rango `$4044`-`$577B`) cada VBLANK relevante, de forma
estable fotograma a fotograma, y el contenido de pantalla tras el
volcado coincide byte a byte con el lienzo.

## 7. El ritmo de fotograma: `WAIT_VBLANK` / `TICK_REDIBUJADO_VBLANK`

El Spectrum no tiene VBLANK del VDP como el MSX — la interrupción
periódica de 50 Hz la genera la ULA por temporizador puro
(`ACTIVAR_INTERRUPCION_MODO_2`, modo IM2 con la tabla "diamante"
clásica de Spectrum en `$F600`-`$F6FF`, vector real en `$6060`). El
resto del mecanismo es análogo en espíritu al de MSX:

- **`WAIT_VBLANK`**: pone a 1 la bandera `$91C2` y hace `EI`/`HALT` —
  espera literalmente a la siguiente interrupción.
- **`ENTRADA_INTERRUPCION_VBLANK`**: la ISR real, guarda todos los
  registros (incluidos el banco alterno e `IX`/`IY`) y llama a
  `TICK_REDIBUJADO_VBLANK` y `DESPACHAR_EFECTO_SONIDO`.
- **`TICK_REDIBUJADO_VBLANK`**: se ejecuta en TODAS las interrupciones,
  pero solo hace trabajo real cuando `$91C2` valía exactamente 1 al
  entrar — es decir, solo cuando la interrupción que despierta es
  precisamente la que `WAIT_VBLANK` esperaba, no cualquier otra. Si
  toca trabajar, llama a `REFRESCAR_ESQUEMA_COLOR_NIVEL` (§6) y luego a
  `DIBUJAR_ACTORES_PENDIENTES` (§3.2) — en ese orden: primero el
  laberinto, luego los actores encima.

## 8. El color: atributos del HUD, y el marco decorativo comprimido

**`REFRESCAR_ESQUEMA_COLOR_NIVEL`** tiene tres partes:

1. Relleno de atributos del HUD/icono de nivel: 18 filas desde `$5844`
   con el color de `REGISTRO_NIVEL_ICONO_HUD`, más 4 celdas sueltas
   coloreadas con `COLOR_ACTUAL` (el color de parpadeo de los modos
   especiales).
2. Un bloque `LDIR` con origen y destino `$0000` (ROM) — no mueve
   ningún dato real (copia cada byte sobre sí mismo); es relleno de
   temporización puro, el mismo truco ya documentado en otras rutinas
   del menú.
3. El volcado del lienzo del §6.

**El marco decorativo** (`CARGAR_MARCO_DECORATIVO`, llamado una vez
desde `INICIO` tras la primera espera de tecla): descomprime un bitmap
comprimido por parejas `(valor, repeticiones)` sin marcador de fin —
el número de pares a leer lo fija `BC` en cada llamada
(`DESCOMPRIMIR_RLE_ATRIBUTOS`). El bitmap (`BITMAP_MARCO_DECORATIVO`,
`$E3F2`, 1496 pares = 2992 bytes fuente) descomprime a 6140 de los 6144
bytes de una pantalla completa; su tabla de atributos (136 pares = 272
bytes) da 764 de los 768 bytes de atributos — ambas cifras casi exactas
al tamaño real de pantalla. El mismo descompresor RLE lo reutilizan
`APLICAR_ATRIBUTOS_MARCO_COMPLETO` (también desde el modo demo) y
`APLICAR_ATRIBUTOS_MARCO_PARCIAL` (desde las 5 opciones del menú de
controles), leyendo un prefijo más corto (125 de los 136 pares) de la
misma tabla de atributos.

## 9. Direcciones y constantes relevantes

| Constante/rango | Dirección | Qué es |
|---|---|---|
| — (bitmap) | `$4000`-`$57FF` | pantalla real, entrelazada |
| — (atributos) | `$5800`-`$5AFF` | color por celda de carácter |
| `MOTOR_ACTORES` | `$91D0` | 1ª pasada: filtra, calcula posición, desplaza sub-pixel, escribe en el buffer de pre-render |
| `TABLA_ACTORES_ACTIVOS` | `$9F9A` | 10 actores × 10 bytes, cola de actores pendientes de dibujar |
| `PTR_TABLA_SPRITES` | `$9E8E` | punteros a gráficos de sprite (28 entradas reales, límite de guarda de 64 sin ajustar) |
| — (buffer de pre-render de actores) | `$F701` en adelante | bump allocator, filas de sprite ya desplazadas sub-pixel |
| `DIBUJAR_ACTORES_PENDIENTES` | `$945A` | 2ª pasada: compone AND/OR sobre pantalla real, sincronizada a VBLANK |
| — (lienzo del laberinto) | `$E404` en adelante | reutiliza la memoria de `BITMAP_MARCO_DECORATIVO` |
| `GRAFICOS_LOSETAS` | `$C600` | gráficos fuente de losetas, 32 bytes cada una |
| `REDIBUJAR_LOSETA_BUFFER_VRAM` | `$99BD` | redibuja 1 loseta en el lienzo |
| `GESTIONAR_SCROLL` | `$967D` | despachador de scroll, 4 direcciones |
| — (tabla de anclas de pantalla) | `$E400` en adelante | 144 filas × 31 bytes, preparada 1 vez por nivel |
| `PREPARAR_TABLA_ESQUEMA_COLOR` | `$954E` | precalcula las 288 direcciones de pantalla ancla |
| `REFRESCAR_ESQUEMA_COLOR_NIVEL` | `$95B0` | HUD + relleno de temporización + volcado del lienzo |
| `BUCLE_MEZCLA_ESQUEMA_COLOR` | `$95FB` | el volcado real, danza de `PUSH`/`POP` con `SP` dirigido |
| `CALCULAR_DIRECCION_PANTALLA` | `$9656` | fórmula de direccionamiento entrelazado del Spectrum |
| `CARGAR_MARCO_DECORATIVO` | — | descomprime el marco decorativo RLE a pantalla real |

## 10. Confianza y pendientes

La mecánica de composición de actores (dos pasadas, buffer de
pre-render, desplazamiento sub-pixel) y el mecanismo completo de
volcado del lienzo (anclas precalculadas + danza de `SP`) están
verificados al 100% mediante simulación de instrucciones con
`tools/mmcanvas_sim.py` (no solo lectura del desensamblado). Puntos
genuinamente abiertos:

- El propósito exacto de `$91C7` (recibe siempre `$02` en
  `MAPEAR_LOSETA_A_GRAFICO`, sin confirmar en ninguna de las 2
  versiones del juego).
- Si el desalineamiento de paso 32 vs. 31 de la tabla de "encadenado"
  (§6.1, offset+2/+3) es deliberado o un efecto colateral de cómo se
  reutilizó la memoria.
- El límite de guarda de `64` sprites en `MOTOR_ACTORES` frente a las
  28 entradas reales de `PTR_TABLA_SPRITES` — heredado de MSX sin
  ajustar, sin efecto observable conocido.

## 11. Para seguir profundizando

- `FINDINGS.md` — continuaciones 36-39 de la sesión 56: el
  descubrimiento del lienzo, la corrección sobre el buffer de actores,
  la localización de `BUCLE_MEZCLA_ESQUEMA_COLOR`, y la derivación
  completa de su algoritmo.
- `recursos/mapa_memoria.html` — mapa de memoria completo con el
  detalle de cada zona mencionada aquí.
- `recursos/flujo_programa.html` §1/§4 — dónde encajan estas rutinas en
  el flujo de ejecución de un fotograma completo.
- `tools/mmcanvas_sim.py` — el simulador Z80 propio usado para derivar
  el algoritmo de §6, con sus 6 pruebas documentadas.
- `manual_motor_colision_ia.md` — quién decide QUÉ loseta cambia y
  CUÁNDO se mueve cada actor (este manual documenta solo el CÓMO se
  pone en pantalla).
- `recursos/graficos.html`/`sprites.html` — catálogo visual de losetas
  y sprites ya identificados.
