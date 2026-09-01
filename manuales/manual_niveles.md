# Manual del formato de niveles — Mad Mix Game (ZX Spectrum 48K)

*[Read this in English](manual_niveles.en.md)*

*Ingeniería inversa, análisis y documentación: Rafael Eduardo Martín Candial (raemca@hotmail.com)*

> Fuente: `src/madmix_body.asm` (`CARGAR_NIVEL`, `TABLA_NIVELES`, los 15
> cuerpos + 3 cabeceras de nivel, `INICIALIZAR_ITEMS_NIVEL`,
> `VERIFICAR_FIN_NIVEL`, `INICIAR_DEMO`). Para la crónica de cómo se
> descubrió cada pieza, ver `FINDINGS.md`; este documento asume que ya
> está todo identificado y explica el resultado final de forma ordenada.

## 1. Qué es esto y qué NO es

Este manual explica cómo están construidos los 15 niveles del juego —
el formato de la rejilla de losetas, cómo se cargan en memoria, y cómo
se detecta que un nivel está completo — y cómo editarlos con
`mmlvl_tool.py`.

**No es** un sistema de niveles con metadatos ricos ni un editor visual
en el propio juego: cada nivel es, literalmente, una rejilla de bytes
(un byte = una loseta) más un registro fijo de 20 bytes con un puñado
de parámetros (posición inicial, cuántos enemigos, objetivo de
bolitas...). No hay capas, no hay entidades con posición propia fuera
de las tablas de ítem ya documentadas en `manual_motor_colision_ia.md`
— los enemigos "aparecen" siempre en el mismo punto de referencia del
nivel, nunca en coordenadas propias por nivel.

**El formato coincide, campo a campo, con el del proyecto hermano de
MSX** — mismo registro de 20 bytes, misma cifra de 15 niveles reales
con un registro 0 muerto/duplicado, mismo comodín de loseta. No es
casualidad: esta versión de Spectrum es la **original**; MSX es un
*port*, y el formato de datos de nivel es una de las piezas que se
copió sin cambios entre plataformas (ver §9 para un caso concreto y
verificable de esta herencia).

## 2. Arquitectura general

```
$6007 ─── REGISTRO_NIVEL_CUERPO_PTR (20 bytes)  -- copia de trabajo del registro del nivel actual (§3)
$883B ─┬─ CARGAR_NIVEL                          -- cargador (§6), llamado desde REINICIAR_PARTIDA/VERIFICAR_FIN_NIVEL
       └─ CALL INICIALIZAR_ITEMS_NIVEL ($87BC)  -- 2º paso, coloca enemigos/items (§7)
$88E0 ─── TABLA_NIVELES (320 bytes = 16 registros x 20 bytes)  -- catalogo de niveles (§4)
$677F.. ─── CUERPO_L01..CUERPO_L15 + CABECERA_7F1F/_7F7F/_8000 -- los datos reales (§4.1)
$9D8B ─── VERIFICAR_FIN_NIVEL -- detecta objetivo cumplido, avanza de nivel (§8)
$8EB3 ─── INICIAR_DEMO -- modo "DEMO" del menu: reproduce 4 niveles de muestra (§10)
```

## 3. El registro de nivel (20 bytes)

Cada nivel se describe con un registro de 20 bytes. Al cargar, se
copia entero a una zona de trabajo fija (`REGISTRO_NIVEL_CUERPO_PTR`,
`$6007`) — los valores que hay "de fábrica" en esa zona en el `.BIN`
compilado son solo la instantánea del último nivel procesado en tiempo
de compilación, sin significado propio (la partida real siempre los
sobrescribe al cargar el primer nivel).

| Offset | Campo | Contenido |
|---|---|---|
| 0-1 | `REGISTRO_NIVEL_CUERPO_PTR` | puntero al CUERPO del nivel (la rejilla de losetas, filas variables) |
| 2-3 | `REGISTRO_NIVEL_CABECERA_PTR` | puntero a la CABECERA fija (3 filas, compartida entre varios niveles) |
| 4-5 | `REGISTRO_NIVEL_PIE_PTR` | duplicado del anterior — la cabecera se copia TAMBIÉN debajo del cuerpo, de "pie" |
| 6 | `REGISTRO_NIVEL_FILAS` | número de filas VARIABLES del cuerpo (15-23); el total de filas jugables es 3 + este valor (las 3 filas fijas las pone la cabecera arriba/abajo) |
| 7 | (`$600E`, sin etiqueta confirmada) | hipótesis fuerte, sin confirmar del todo: flag de aviso "EN LA PRÓXIMA... EXTRA" — `COMPROBAR_AVISO_ULTIMA_VIDA` lee esta misma dirección para decidir si dibuja el aviso |
| 8 | `REGISTRO_NIVEL_CONTADOR_PELMAZOIDES` | nº de "Pelmazoides" (fantasmas) activos este nivel, máx. 8 — confirmado vía `HNDLR_PELMAZOIDE` (ver `manual_motor_colision_ia.md`) |
| 9 | (`$6010`, candidato `CONTADOR_MARICOCOS`) | nº de "Maricocos" activos, máx. 2 — candidato sin etiqueta real todavía |
| 10 | (`$6011`, candidato `CONTADOR_REPUGNANTOSOS`) | nº de "Repugnantosos" activos, máx. 8 — candidato sin etiqueta real todavía |
| 11 | `REGISTRO_NIVEL_DURACION_PARPADEO` | duración en fotogramas del modo especial (bola de poder/hipopótamo) |
| 12 | `REGISTRO_NIVEL_LOSETA_COMODIN` | loseta real que sustituye al comodín `$3C` del cuerpo (§5) |
| 13-14 | `REGISTRO_NIVEL_FILA_COLUMNA` | fila/columna de referencia inicial (posición de "aparición" del comecocos y de los ítems), en unidades de subpíxel |
| 15-16 | (`$6016`-`$6017`, sin identificar) | múltiplo exacto de 4 en los 16 registros — misma unidad de subpíxel que fila/columna de referencia; candidato sin confirmar a una segunda coordenada |
| 17 | `REGISTRO_NIVEL_ICONO_HUD` | código de carácter/icono del HUD para este nivel |
| 18-19 | (`$6019`, candidato `OBJETIVO_BOLAS`) | objetivo de "bolitas a comer" para completar el nivel (§8) — función plenamente confirmada pese a no tener etiqueta propia todavía |

## 4. `TABLA_NIVELES` — el catálogo de 15 niveles

**320 bytes = 16 registros de 20 bytes** (`$88E0`-`$8A20`). El primero
(índice 0) es un **registro muerto**, duplicado exacto byte a byte del
nivel 1 (mismo `CUERPO_L01`, misma cabecera, mismos 17 campos
restantes) — nunca se alcanza en juego normal: `NIVEL_ACTUAL` arranca
en 1 (`REINICIAR_PARTIDA`) y `VERIFICAR_FIN_NIVEL` (§8) lo resetea a 1
al pasar de 15, sin pasar nunca por 0. Confirmado también de forma
independiente por `src/data/niveles/`: no existe ningún
`body_l00.bin`, solo `body_l01.bin` a `body_l15.bin`. Los índices 1-15
son los 15 niveles reales — no hay ningún nivel "extra" u "oculto"
adicional en esta versión.

Reescrita como tabla de datos nativa en el propio ensamblador (punteros
de cuerpo/cabecera como etiquetas reales, resueltas por el propio
ensamblador) en vez de un `INCBIN` de tabla binaria.

Verificación cruzada exhaustiva (`tools/mmlvl_tool.py check-bolitas`):
para los 16 registros, el recuento real de losetas-con-bola de cada
cuerpo coincide EXACTO con el objetivo de bolitas declarado — valida
tabla, punteros y catálogo de tipos de loseta a la vez.

### 4.1 Los ficheros de datos: 15 cuerpos + 3 cabeceras compartidas

`src/data/niveles/*.bin` — un fichero por bloque único de datos:

- **15 cuerpos** (`body_l01.bin` a `body_l15.bin`): la rejilla variable
  de cada nivel, 15-23 filas × 32 columnas. Su posición en memoria NO
  sigue el orden numérico de nivel (p. ej. `CUERPO_L09` va físicamente
  antes que `CUERPO_L05`) — vestigio del orden de composición del
  original de 1988, sin significado funcional.
- **3 cabeceras compartidas** (`header_7f1f.bin`, `header_7f7f.bin`,
  `header_8000.bin`, 96 bytes cada una = 3 filas × 32), reutilizadas
  por varios niveles a la vez — economía de memoria: son los bordes
  superior/inferior del laberinto, y varios niveles comparten
  exactamente el mismo borde:
  - `CABECERA_8000`: niveles 0, 1, 2, 3, 6, 9, 10, 11, 14, 15 (10 usos)
  - `CABECERA_7F1F`: niveles 4, 5, 7, 12, 13 (5 usos)
  - `CABECERA_7F7F`: nivel 8 (1 uso)

  Nombradas por su propia dirección de Spectrum (distinta de los
  nombres de MSX, que usa direcciones propias como `CABECERA_50BC`) —
  mismo espíritu de reutilización, direcciones distintas por platforma.

Cada byte de la rejilla es un **índice de loseta** (bits 0-6, ver
`src/data/img/tiles/*.til`, catálogo 00-90) con el **bit 7** de
significado no confirmado en tiempo de ejecución (`CARGAR_NIVEL` lo
borra siempre al copiar al buffer activo) pero SÍ presente en los
binarios originales — por eso el formato de texto de `mmlvl_tool.py` lo
conserva byte a byte en vez de descartarlo.

### 4.2 El comodín `$3C` y la alternancia por "vueltas"

Al copiar el cuerpo, `CARGAR_NIVEL` sustituye cada loseta con valor
`$3C` (60, el "comodín", mismo valor literal que MSX) por el valor real
fijado en `REGISTRO_NIVEL_LOSETA_COMODIN` (offset 12) — así un mismo
patrón de cuerpo puede lucir distinto según el nivel sin duplicar
datos. La sustitución **no es incondicional**: si es la primera vuelta
completa al ciclo de 16 registros (`CONTADOR_VUELTAS_NIVELES=0`), los
comodines se copian tal cual, SIN sustituir. En vueltas posteriores, se
sustituyen según la **paridad** del recuento de comodines encontrados
hasta ese punto en el cuerpo, comparada con el número de vuelta — en la
práctica, en la vuelta 1 la mitad de las apariciones de `$3C` (las de
índice par) pasan a ser la loseta comodín del nivel y la otra mitad se
queda en `$3C`; desde la vuelta 2 en adelante, todas las apariciones se
sustituyen. Variedad visual en partidas largas que dan más de una
vuelta completa al ciclo de niveles. El comodín solo se aplica al
CUERPO — las cabeceras se copian siempre tal cual, sin comprobación de
`$3C`.

## 5. Cargando un nivel: `CARGAR_NIVEL` (`$883B`, 165 bytes) paso a paso

Llamado desde `REINICIAR_PARTIDA`/`VERIFICAR_FIN_NIVEL` cada vez que
hace falta un nivel nuevo:

1. Localiza el registro de `NIVEL_ACTUAL` en `TABLA_NIVELES` (20 bytes
   × número de nivel) y lo copia entero a la zona de trabajo (§3).
2. Copia la cabecera (96 bytes) al **buffer de nivel activo, dirección
   fija `$FC60`**, **arriba** del cuerpo (ver §9 sobre esta dirección).
3. Copia el cuerpo (`REGISTRO_NIVEL_FILAS` × 32 bytes, calculado con 5
   `ADD HL,HL` = ×32), limpiando el bit 7 ("comido") de cada loseta y
   aplicando la sustitución de comodín (§4.2).
4. Copia la MISMA cabecera otra vez, **debajo** del cuerpo (de "pie") —
   el laberinto queda simétrico arriba/abajo con el mismo borde.
5. Resetea `CONTADOR_BOLAS_COMIDAS` a 0, calcula la dirección de
   pantalla del punto de referencia inicial (posición de parpadeo de
   la bola), limpia todos los flags de modo especial, restaura el
   color de HUD por defecto (`COLOR_ACTUAL`/`COLOR_GUARDADO = $78`),
   escribe el icono de HUD del nivel, fija la posición de cámara
   (`POSICION_ACTUAL_CAMARA = $1018`), y llama a
   `INICIALIZAR_ITEMS_NIVEL` (§6).

## 6. `INICIALIZAR_ITEMS_NIVEL` (`$87BC`) — reaparición de enemigos e ítems

Llamada tanto desde `CARGAR_NIVEL` (carga completa de nivel) como al
reentrar tras perder una vida (sin recargar el laberinto):

- Coloca las 8 entradas de `TABLA_ITEMS_PELMAZOIDE`, las 2 de
  `TABLA_ITEMS_MARICOCO` y las 8 de `TABLA_ITEMS_REGPUNANTOSO` en el
  punto de referencia (`REGISTRO_NIVEL_FILA_COLUMNA`), limpiando su
  sub-posición — "vuelven a aparecer" todas en el mismo sitio de
  salida. El número de instancias realmente **activas** ese nivel no lo
  decide esta rutina (siempre reinicia el máximo de cada tabla) sino
  los contadores del registro de nivel (offsets 8-10, §3), que los
  manejadores de cada tipo de ítem usan para limitar cuántas procesan y
  dibujan de verdad cada fotograma.
- También limpia la cola de avisos/parpadeo (`TABLA_RANURAS_AVISO`, 4
  ranuras) y resetea dirección/temporizadores de movimiento — salvo con
  el modo "herramienta" (excavatófono) activo, que arranca con un valor
  especial (`$0E`).
- Segundo punto de entrada, `INICIALIZAR_PARCIAL_ITEMS_NIVEL`, solo
  limpia `TABLA_PISTAS_TANQUE_AVION` (3 ranuras) — usado cuando no hace
  falta repetir todo el reseteo anterior.

## 7. Cómo se detecta el fin de nivel: `VERIFICAR_FIN_NIVEL` (`$9D8B`)

Comprobado cada frame dentro del bucle principal:

```
VERIFICAR_FIN_NIVEL:
    CALL ACTUALIZAR_PARPADEO_BOLA
    LD HL,(CONTADOR_BOLAS_COMIDAS)
    LD DE,(OBJETIVO_BOLAS)      ; $6019, offset 18-19 del registro de nivel
    AND A
    SBC HL,DE
    JR NZ,VERIFICAR_ENTRADA     ; nivel aun en curso
    ...
```

1. Compara `CONTADOR_BOLAS_COMIDAS` contra el objetivo del registro de
   nivel activo. Si no coincide, el nivel sigue en curso.
2. Si coincide: incrementa `NIVEL_ACTUAL`. Si llega a 16 (`$10`, es
   decir, se acaba de completar el nivel 15), lo resetea a 1 e
   incrementa `CONTADOR_VUELTAS_NIVELES` (§4.2) — el ciclo de 15
   niveles vuelve a empezar. Si no, simplemente continúa con el
   siguiente registro.
3. Dispara el destello de icono/color del HUD y salta a
   `PANTALLA_PRESENTACION_NIVEL` (recarga el HUD para el nuevo nivel,
   que a su vez desemboca en `CARGAR_NIVEL`).

**Qué cuenta como "bolita"**: no solo las bolitas normales
(`HNDLR_BOLITA_NORMAL`) — los 4 manejadores de flecha "autococo"
(`HNDLR_AUTOCOCO_ARRIBA`/`_ABAJO`/`_IZQUIERDA`/`_DERECHA`, que además
fuerzan una dirección de movimiento al comecocos) TAMBIÉN incrementan
`CONTADOR_BOLAS_COMIDAS` al pisarlas, así que el objetivo real de un
nivel mezcla ambos tipos de loseta — exactamente el mismo criterio que
usa `check-bolitas` en `mmlvl_tool.py` (`BALL_TILES`, 3 índices de
gráfico para la bola normal + 4 para las flechas).

## 8. `$FC60`: un caso concreto de herencia MSX ↔ Spectrum

No se ha detectado ningún bug propio en la reconstrucción de Spectrum
— el binario recompilado es 0 diferencias / 48485 bytes idéntico al
`.tzx` original en todo momento. Pero sí hay un dato de linaje
verificable y curioso: `CARGAR_NIVEL` usa la dirección fija **`$FC60`**
como buffer de nivel activo — la MISMA dirección exacta que usaba la
**v1.0 original** del port a MSX, antes de que su parche v2.0 la
moviera a `$FC50` para corregir un bug propio de esa plataforma (el
"bug del contador de bolitas del nivel 13", documentado en el
`FINDINGS.md` del proyecto MSX). La misma dirección `$FC60` reaparece
también en el cálculo de posición de pantalla del punto de referencia.

Esto es evidencia consistente de que **la cinta de Spectrum es el
ORIGINAL** y de que el port a MSX v1.0 heredó esta dirección
literalmente sin adaptarla, antes de tener que parchearla en su propia
v2.0 por un bug propio de esa plataforma. **Sin confirmar**: no hay
constancia de que el Spectrum sufra en la práctica un efecto adverso
análogo en el nivel 13 (o en cualquier otro) — nadie ha verificado en
emulador si `$FC60` produce aquí el mismo problema que producía en MSX
antes de su parche. Pregunta abierta razonable, no un hecho cerrado.

## 9. El modo "DEMO" del menú: `INICIAR_DEMO` (`$8EB3`, 162 bytes)

Distinto de jugar de verdad: el menú principal ofrece una opción
"5 DEMO" que reproduce, sin intervención del jugador, **4 niveles de
muestra** de una tabla propia (`TABLA_PERFILES_DEMO`, `$8F49`, 4
entradas `[nivel, puntero_a_guion]`):

```
nivel 1 -> $DBE0 (GUION_DEMO_NIVEL1, 64 B)
nivel 2 -> $DC20 (GUION_DEMO_NIVEL2, 94 B)
nivel 4 -> $DC90 (GUION_DEMO_NIVEL4, 66 B)
nivel 5 -> $E380 (GUION_DEMO_NIVEL5, 88 B)
```

El nivel 3 no tiene perfil de demo propio — solo se ciclan 1, 2, 4 y 5.
Para cada uno: fija `NIVEL_ACTUAL`, pone `VIDAS_RESTANTES=0`, carga el
nivel (mismo `CARGAR_NIVEL`/`INICIALIZAR_ITEMS_NIVEL` que en juego
real, sin ninguna variante especial para demo), y reproduce un **guion
de demo** — una secuencia de pares `[umbral de fotogramas, dirección]`
en decimal, terminada con el centinela `$FF,$FF`, que sustituye a la
lectura real de teclado/joystick pasando la dirección directamente a
`MOTOR_MOVIMIENTO_COLISION` — no es procedural, es entrada de joystick
pregrabada byte a byte. Termina el perfil al agotar el guion o al
pulsar cualquier tecla (`ABORTAR_DEMO`); tras el 4º perfil, aborta.

Hay **6 guiones de demo huérfanos** con el mismo formato pero sin
ningún índice de `TABLA_PERFILES_DEMO` que los referencie
(`GUION_DEMO_SINREF_1` a `_6`) — candidatos a tomas descartadas o una
versión antigua del ciclo de demo, sin llamador confirmado. Nota
histórica de corrección propia del proyecto: en un momento de la
investigación se caracterizó por error el rango de estos guiones como
"datos del generador de sonido" por parecido superficial de formato —
corregido después al confirmarse que alimentan el motor de movimiento,
no el altavoz (ver `manual_driver_sonido.md` §2.3 para el aviso
metodológico completo).

## 10. Herramienta: `tools/mmlvl_tool.py`

```
py tools/mmlvl_tool.py disasm fichero.bin fichero.txt   # binario -> rejilla de texto editable
py tools/mmlvl_tool.py asm fichero.txt fichero.bin      # texto -> binario (para recompilar el juego)
py tools/mmlvl_tool.py roundtrip fichero.bin            # verifica que disasm+asm da el mismo binario
py tools/mmlvl_tool.py roundtrip-all carpeta/            # lo mismo para todos los .bin de una carpeta
py tools/mmlvl_tool.py check-bolitas fichero.txt NIVEL  # cuenta bolitas del .txt y compara contra
                                                          # el objetivo real de ese nivel en TABLA_NIVELES
```

Adaptación directa de la herramienta homónima de MSX — los 18 ficheros
de `src/data/niveles/` son idénticos byte a byte a los de MSX. El
formato de texto: rejilla hexadecimal de 32 columnas fijas, filas
variables autodetectadas por tamaño de fichero, con una cabecera
(`; filas=N columnas=N`) repitiendo el tamaño exacto. `check-bolitas`
es la comprobación más útil al editar un nivel: lee el objetivo real
directamente de `TABLA_NIVELES` en `madmix_body.asm` (sin fichero de
manifiesto aparte que se pueda desincronizar) y cuenta las losetas
"bola" (normales + flechas autococo, §7) del `.txt` — si no coinciden,
el nivel es infinal (compilaría sin error, pero nunca terminaría de
jugarse).

> ⚠️ **Límite real de edición** (mismo patrón que sonido, ver
> `manual_driver_sonido.md` §9): cada `.bin` se compila con `INCBIN` a
> una dirección FIJA. Puedes cambiar el VALOR de cualquier loseta sin
> problema. **NO añadas ni quites filas ni columnas**: el propio
> `assemble()` de la herramienta rechaza cualquier cambio de tamaño con
> un error explícito — el fichero se referencia con un `INCBIN` cuyo
> tamaño depende de la posición en el mapa de memoria; si cambia, todo
> lo que va detrás en `madmix_body.asm` se desplaza de dirección.

## 11. Confianza y pendientes

La estructura del registro de nivel, la tabla de 16 entradas, y el
mecanismo de carga/detección de fin están verificados al 100% contra
el desensamblado real y validados cruzadamente con `check-bolitas`
sobre los 16 registros. Puntos abiertos:

- El campo de offset 7 del registro (`$600E`): hipótesis fuerte de
  "flag de aviso de vida extra" (coherente con la lectura real de
  `COMPROBAR_AVISO_ULTIMA_VIDA`), sin confirmación formal adicional.
- Los contadores de offset 9/10 (Maricoco/Repugnantoso): candidatos sin
  etiqueta real todavía, a diferencia del de offset 8 (Pelmazoides),
  confirmado con más fuerza.
- El campo de offset 15-16: confirmado solo que es múltiplo de 4 en los
  16 registros (misma unidad de subpíxel que la posición de referencia)
  — sin hipótesis de significado más allá de "candidato".
- El mecanismo de paridad de la sustitución del comodín (§4.2): la
  mecánica está confirmada leyendo el código, pero el "porqué" del
  esquema par/impar no está razonado en ningún comentario del proyecto.
- Los 6 guiones de demo huérfanos (§9): sin disparador conocido, bajo
  valor esperado de seguir investigando.
- Si `$FC60` produce en el Spectrum real algún efecto adverso análogo
  al bug de nivel 13 que tuvo MSX v1.0 (§8) — sin verificar en
  emulador.

## 12. Para seguir profundizando

- `FINDINGS.md` — todas las secciones relacionadas con niveles, el
  registro de 20 bytes campo a campo, y la herencia `$FC60` con MSX, en
  orden cronológico.
- `manual_motor_colision_ia.md` — qué hacen los enemigos/ítems una vez
  que el nivel ya está cargado (este manual documenta solo cómo se
  construye y carga el nivel, no la lógica de juego dentro de él).
- `recursos/graficos.html` — catálogo de las 91 losetas del laberinto
  ya identificadas, útil como referencia mientras se edita un nivel.
