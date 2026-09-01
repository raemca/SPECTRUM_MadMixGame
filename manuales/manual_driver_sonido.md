# Manual del driver de sonido — Mad Mix Game (ZX Spectrum 48K, altavoz por `$FE`)

*[Read this in English](manual_driver_sonido.en.md)*

*Ingeniería inversa, análisis y documentación: Rafael Eduardo Martín Candial (raemca@hotmail.com)*

> Fuente: `src/madmix_body.asm`, región `$DBE0`-`$EFB5` (motor de música,
> subpatrones, tabla de efectos, guiones de demo) más
> `DESPACHAR_EFECTO_SONIDO` (`$8F55`) y `REPRODUCIR_SONIDO` (`$E1F9`).
> Para la crónica de cómo se descubrió cada pieza, ver `FINDINGS.md`;
> este documento asume que ya está todo identificado y explica el
> resultado final de forma ordenada.

## 1. Qué es esto y qué NO es

Este manual explica cómo genera sonido el juego en un ZX Spectrum 48K
real de cinta: **no hay ningún chip de sonido dedicado** — todo pasa
por un único bit del puerto `$FE`, el mismo puerto que comparten
teclado y cinta. A partir de esa única señal binaria, el juego
construye 2 "canales" de música por multiplexación de software, un
sistema de efectos cortos independiente, y un lenguaje de bytecode
propio de 6 comandos para las canciones.

**Diferencia de fondo con el proyecto hermano de MSX**: el MSX1 tiene
un chip de sonido dedicado, el PSG AY-3-8910 (3 canales de tono +
ruido por hardware, ver `manual_driver_sonido.md` de MSX). El ZX
Spectrum 48K **no tiene ningún chip de sonido** — confirmado por
ausencia total de acceso a puertos de AY (`$FFFD`/`$BFFD`) en todo
`madmix_body.asm`, y por presencia exclusiva de `OUT ($FE),A` (21
apariciones) como único mecanismo de audio. Esta es la versión de
**cinta de 48K** — no hay indicios de paginación de memoria ni de
soporte de 128K en ningún punto del código. Todo el "sonido" real que
se oye jugando es una única señal cuadrada (o una superposición de
varias, conmutadas muy rápido) sobre el mismo bit de altavoz.

**No es** un único reproductor: son en realidad **tres subsistemas
independientes** con arquitecturas distintas (§2), y conviene no
confundirlos entre sí, ni con un cuarto formato de datos que comparte
"aspecto" con ellos pero no es sonido en absoluto (§2.4).

## 2. Los tres (más uno) subsistemas de audio

### 2.1 El motor de música — bloqueante, 2 canales multiplexados

Reproduce las 3 canciones/jingles del juego (presentación, inicio de
nivel, fin de modo especial). **Ocupa la CPU por completo mientras
suena** — es un bucle activo de primer plano
(`BUCLE_TONO_CANAL_A`, dentro de `REPRODUCIR_SONIDO`, `$E1F9`) que no
devuelve el control hasta que la canción termina o el jugador pulsa
una tecla. Mientras tanto, **ni el juego ni el redibujado de pantalla
avanzan** — la interrupción normal del motor (`ENTRADA_INTERRUPCION_VBLANK`,
que llama a `TICK_REDIBUJADO_VBLANK` y `DESPACHAR_EFECTO_SONIDO`) está
**sustituida** por la propia rutina de servicio del reproductor de
música (`ISR_SONIDO`) mientras dura la canción — así que efectos de
sonido y redibujado quedan también suspendidos, no solo el bucle
principal.

Dos "canales" simulados por software sobre el mismo bit de altavoz:

- **Canal A** (registro `IX`): tono/melodía. El tono real (la onda
  cuadrada) lo genera el propio bucle de primer plano, no la
  interrupción — con dos contadores automodificables (periodo completo
  y medio periodo) que conmutan el bit de altavoz.
- **Canal B** (registro `IY`): percusión. Sus eventos son cortos y se
  generan **directamente dentro de la interrupción** (`ISR_SONIDO`),
  sin pasar por el bucle de primer plano.

Como solo hay un bit físico de altavoz, ambos canales se superponen
sobre la misma señal: el canal A domina el tiempo de CPU (bucle activo
en primer plano) y el canal B se cuela brevemente cada vez que la
interrupción lo dispara — multiplexación por software con temporización
dirigida por interrupción, el patrón clásico de los reproductores de
altavoz de Spectrum 48K.

### 2.2 Los efectos de sonido cortos — no bloqueantes

Reproduce los 12 efectos de jugabilidad (comer bolita, activar ítem
especial, etc. — tabla completa en §4). A diferencia del motor de
música, **no bloquea el juego**: `DESPACHAR_EFECTO_SONIDO` (`$8F55`) se
llama una vez por interrupción (50 Hz) desde la propia ISR normal del
juego, avanzando un paso (un par duración/periodo) por interrupción —
el juego entero sigue corriendo, el efecto se reparte en varios
fotogramas. Solo tiene **1 "canal"**, sin comandos de guion ni
subpatrones — el sistema más simple de los tres.

### 2.3 Los guiones de demo — NO son sonido

Aviso importante para no confundir formatos: hay un tercer tipo de
dato con "aspecto de guion de sonido" (pares de bytes pequeños
terminados en un valor especial) que **no tiene nada que ver con el
audio** — son guiones de entrada pregrabada para el modo demo/atracción
(`INICIAR_DEMO`), formato pares `(umbral_frames, dirección)` terminados
en `$FF,$FF`, que alimentan `MOTOR_MOVIMIENTO_COLISION`, no el
altavoz. Se mencionan aquí solo porque una hipótesis intermedia de la
investigación (ver §11) los confundió en un primer momento con datos
de música — la permisividad del formato de bytecode del motor de
música (casi cualquier byte tiene alguna lectura válida como nota o
comando) hace que "decodifica sin fallos" no sea, por sí sola, prueba
de que algo es realmente un guion de música.

## 3. El lenguaje de bytecode del motor de música: 6 comandos

Formato de las 3 canciones y sus 43 subpatrones compartidos
(`$DD18`-`$E023`), un byte de comando por paso:

| Byte / rango | Mnemónico | Significado |
|---|---|---|
| `$00`-`$F9` | `NOTE 0xNN` | **Canal A**: bits 0-5 = índice en `TABLA_TONOS_CANAL_A` (tono); bits 6-7 = índice en `TABLA_DURACIONES` (duración). **Canal B**: bits 0-2 = índice 0-7 en `TABLA_PERCUSION` |
| `$FF` | `END` | Fin de guion. En canal A pone `FLAG_ESTADO_SONIDO=2` ("terminado"), lo que dispara `DETENER_SONIDO`; en canal B solo retorna de la interrupción sin detener el motor |
| `$FE` | `RESET` | Reinicia la duración al valor por defecto (`TABLA_DURACIONES`, índice 0) sin tocar el tono activo |
| `$FD nn nn` | `CALL 0xNNNN` | Llama a un subpatrón por dirección absoluta de 16 bits, empujando la dirección de retorno a una **pila privada del canal** |
| `$FC` | `RETURN` | Retorna del subpatrón actual (pop de la pila privada) |
| `$FB` | `PATCH1` | Código automodificable: sobrescribe 8 bytes ejecutables de `TONO_PATRON_BASE` (`$E24D`-`$E254`) con la variante `PATRON_TONO_1` (solo canal A) |
| `$FA` | `PATCH2` | Igual que `PATCH1` pero con `PATRON_TONO_2` (restaura el orden original, solo canal A) |

Notas de diseño: las llamadas usan direcciones absolutas de 16 bits, no
índices de tabla — formato más simple que el de MSX (que necesita un
mapa de direcciones externo); el marcador de fin va dentro del propio
guion (`$FF`), no en una tabla aparte. `$FB`/`$FA` son casos genuinos
de comandos que reescriben instrucciones ejecutables en vez de cargar
un simple parámetro — su efecto mecánico (qué bytes sobrescriben) está
identificado, aunque su efecto musical audible exacto no se ha
caracterizado a oído.

Cada canal tiene su propia pila privada (`PILA_CANAL_A`/`PILA_CANAL_B`,
apuntando a 50/18 bytes de espacio real en `PILA_CANAL_A_MEM`/
`PILA_CANAL_B_MEM`) para que `CALL`/`RETURN` funcionen de forma
independiente entre canales.

## 4. Los efectos de sonido cortos: sin comandos, solo pares de datos

Formato: pares `(duración, periodo)` en decimal, terminados en `$FF` —
el mismo formato de "nota" que usan `TABLA_TONOS_CANAL_A`/
`TABLA_DURACIONES` del motor de música, pero **sin ningún comando de
guion** (nada de `$FE`/`$FD`/`$FC`/`$FB`/`$FA`). Ejemplo real
(`EFECTO_SONIDO_02`, uno de los 12 datos en `$8FF5`-`$9049`, 117 bytes
en total): `DB 4,130, 8,6, 10,10, $FF`.

## 5. El disparo de efectos desde el juego: `EVENTO_SONIDO_PENDIENTE`

Mismo nombre de variable, mismo mecanismo de fondo que su análogo de
MSX: `EVENTO_SONIDO_PENDIENTE` (`$8FD6`, 1 byte, `$FF` = "sin evento
pendiente").

- **Escritor**: 24 puntos distintos del motor (sobre todo
  `TABLA_MANEJADORES_LOSETA` y `ACTIVAR_EFECTO_ITEM`) marcan un efecto
  pendiente con `LD A,<índice>` / `LD (EVENTO_SONIDO_PENDIENTE),A`.
- **Consumidor**: `DESPACHAR_EFECTO_SONIDO`, llamado una vez por
  interrupción desde `ENTRADA_INTERRUPCION_VBLANK`. Si el índice es
  `$FF` no hay evento nuevo, pero igualmente se avanza un paso el
  efecto que ya estuviera sonando.
- Índice válido: 0-11, resuelto por `TABLA_RECURSOS_SONIDO_EVENTO`
  (`$8FDD`, 12 punteros a los guiones de efecto).

### Mapa de eventos de juego → efecto

| Índice | Evento de juego que lo dispara |
|---|---|
| 0 | Comer bolita/punto normal |
| 1 | Comer bolita clavada/especial |
| 2 | El "autococo" cambia de dirección |
| 3 | Activar/recoger ítem especial de loseta (bola de poder, hipopótamo, excavatófono, pista de tanque/avión, ítem de suelo) |
| 4 | Se registra una pista de tanque/avión nueva |
| 5 | Regeneración del "Maricoco" |
| 6 | Regeneración del "Repugnantoso" |
| 7 | Aviso de proximidad de pista tanque/avión; puntos sumados durante un modo especial |
| 8 | Arranca un modo especial (bola de poder / hipopótamo) |
| 9 | Se abre una trampilla |
| 10, 11 | Sin disparador conocido en el código (nunca escritos); además comparten guion con silencio inmediato (`$FF` sin pares), así que sonarían mudos aunque se dispararan |

Hay además un dato con el mismo formato de efecto
(`EFECTO_SONIDO_HUERFANO`, `$9003`) que ninguna entrada de la tabla
referencia — candidato a efecto retirado, sin confirmar.

## 6. Arquitectura de `REPRODUCIR_SONIDO` (`$E1F9`)

Punto de entrada externo real del motor de música, llamado desde 4
sitios (`ESPERAR_TECLA_INICIO`, el bucle de espera de partida nueva,
`BUSCAR_COLUMNA_HUD` y `BUCLE_PRINCIPAL_JUEGO`):

1. Limpia los flags de estado/duración de ambos canales.
2. `DI`; guarda el vector IM2 normal del juego (`$6061`) en
   `ISR_VECTOR_GUARDADO`, e instala `ISR_SONIDO` como nuevo vector — el
   reloj de 50 Hz pasa a alimentar el reproductor de música en vez del
   motor de juego.
3. Carga los punteros de canal (`IX`/`IY`), ya escritos por quien
   llamó, en los operandos automodificables `LD IX,nn`/`LD IY,nn`
   (`$E212`/`$E216`) — el guion de qué canción suena lo decide el
   llamador antes del `CALL`, no `REPRODUCIR_SONIDO`.
4. Inicializa las pilas privadas de cada canal.
5. `EI`; entra en `BUCLE_TONO_CANAL_A`, el bucle activo bloqueante:
   lee el teclado cada vuelta (para poder abortar con cualquier tecla
   salvo las de mapa fijo), comprueba si el canal A ha terminado
   (`FLAG_ESTADO_SONIDO=2`), y si hay una nota activa genera el tono
   real conmutando el bit de altavoz con dos contadores automodificables
   (periodo completo y medio periodo).
6. Cada interrupción, ahora servida por `ISR_SONIDO`, decrementa los
   contadores de duración de cada canal; al llegar a 0, lee y despacha
   el siguiente byte de guion (los 6 comandos de §3).
7. `DETENER_SONIDO`: `DI`, restaura el vector IM2 original, `RET`.

**Código automodificable, 4 puntos distintos** (uno de ellos, el
periodo de tono activo dentro del propio bucle de tono, se pasó por
alto en un primer análisis manual y solo se confirmó simulando el
código real — ver §11): los contadores de duración de cada canal, los
punteros de guion de canal, los parches `$FB`/`$FA` sobre
`TONO_PATRON_BASE`, y el periodo de tono activo dentro de
`BUCLE_TONO_CANAL_A`.

## 7. Arquitectura de `DESPACHAR_EFECTO_SONIDO` (`$8F55`)

1. `DI`; lee `EVENTO_SONIDO_PENDIENTE`.
2. Si es `$FF`, salta directo al avance del efecto en curso.
3. Si hay índice nuevo, lo resuelve en `TABLA_RECURSOS_SONIDO_EVENTO`,
   instala el puntero como guion activo, y limpia
   `EVENTO_SONIDO_PENDIENTE` a `$FF` (consumido).
4. Lee el siguiente par `(duración, periodo)` del guion activo. `$FF`
   = fin (no hace nada más este tick); duración 0 = silencio este paso
   pero el puntero avanza igual.
5. Con duración > 0, genera el tono con el mismo truco de contadores
   duales automodificables que el motor de música, pero con un
   **tercer contador de duración** en vez de delegarla a un flag de
   interrupción — no hay canales que multiplexar aquí. Mismo bit de
   altavoz que el motor de música.

Al ejecutarse dentro de la propia interrupción normal del juego, el
tono de un paso de efecto se genera de un tirón, íntegro, en esa
interrupción — no repartido entre varias.

## 8. Tablas de datos

| Tabla/variable | Dirección | Tamaño | Contenido |
|---|---|---|---|
| `TABLA_TONOS_CANAL_A` | `$E2B8` | 64 palabras | Periodos de tono, escala cromática descendente; solo 41 entradas en uso real, verificado por simulación contra frecuencias musicales reales |
| `TABLA_DURACIONES` | `$E2AE` | 4 bytes | `5, 11, 17, 23` fotogramas, indexada por bits 6-7 de la nota |
| `TABLA_PERCUSION` | `$E29A` | 8 punteros | Solo 4 rutinas de ruido reales, cada una duplicada para llenar las 8 entradas indexables |
| `FLAG_ESTADO_SONIDO` | `$E2AA` | 1 byte | 0=silencio, 1=sonando, 2=terminado |
| `ISR_VECTOR_GUARDADO` | `$E2AB` | 2 bytes | Vector IM2 original del juego, guardado/restaurado por `REPRODUCIR_SONIDO`/`DETENER_SONIDO` |
| `PILA_CANAL_A`/`PILA_CANAL_B` | `$E2B4`/`$E2B6` | 2+2 bytes | Punteros de pila privada de cada canal |
| `TABLA_RECURSOS_SONIDO_EVENTO` | `$8FDD` | 12 punteros | Direcciones de los 12 guiones de efecto corto |
| `EVENTO_SONIDO_PENDIENTE` | `$8FD6` | 1 byte | Mecanismo de disparo desde el motor de juego (§5) |

Las 3 canciones reales, con sus guiones de canal A/B:

| Canción | Tamaño | Disparador | Momento |
|---|---|---|---|
| `CANCION_PRESENTACION` | 80 bytes | `ESPERAR_TECLA_INICIO` / espera de partida nueva | Pantalla de título / arranque de partida nueva |
| `CANCION_INICIO_NIVEL` | 14 bytes | `BUSCAR_COLUMNA_HUD` | Cada vez que arranca a jugarse un nivel |
| `CANCION_FIN_MODO_ESPECIAL` | 14 bytes | `BUCLE_PRINCIPAL_JUEGO`, cuando el modo especial termina | Fin de bola de poder/hipopótamo |

## 9. Herramientas: `mmsnd_tool.py` y `mmsnd_render.py`

```
py tools/mmsnd_tool.py disasm fichero.snd fichero.txt     # binario -> texto editable
py tools/mmsnd_tool.py asm fichero.txt fichero.snd        # texto -> binario
py tools/mmsnd_tool.py roundtrip fichero.snd              # verifica disasm+asm = mismo binario
py tools/mmsnd_tool.py roundtrip-all carpeta/              # lo mismo para toda una carpeta
```

Formato de texto: una instrucción por línea, con los mnemónicos de §3
(`NOTE 0xNN`, `END`, `RESET`, `CALL 0xNNNN`, `RETURN`, `PATCH1`,
`PATCH2`) — mapeo directo de los 6 comandos del bytecode.

```
py tools/mmsnd_render.py render fichero.snd salida.wav [--channel A|B]
py tools/mmsnd_render.py render-pair canalA.snd canalB.snd salida.wav
py tools/mmsnd_render.py render-all carpeta/ salida_carpeta/
```

Opciones: `--rate` (44100 Hz por defecto), `--tickhz` (50 Hz), `--max-ticks`
(200), `--clock` (3.5 MHz). A diferencia de la herramienta homónima de
MSX (que reimplementa la lógica del reproductor a mano en Python),
esta **ejecuta el código Z80 original de verdad**: un simulador mínimo
corre sobre una copia real del binario, con interrupciones a 50 Hz
simuladas, registrando cada `OUT ($FE),A` para reconstruir la onda
cuadrada — elegido a propósito porque el análisis manual del bucle de
tono llevó a una conclusión incorrecta la primera vez (§11); ejecutar
el código real evita ese tipo de error.

> ⚠️ **Límite real de edición** (mismo patrón que niveles, ver
> `manual_niveles.md` §8): cada `.snd`/`.spt` se compila con `INCBIN` a
> tamaño fijo. Puedes cambiar el VALOR de una nota o el destino de un
> `CALL` sin problema. **NO añadas ni quites líneas**: el tamaño es
> FIJO — el motor lee estos bytes directamente desde RAM en las
> direcciones originales (`IX`/`IY` apuntan a direcciones absolutas, no
> relativas); si el tamaño cambia, todo lo que va detrás en el binario
> reconstruido se desplaza de dirección. Nota adicional: un guion
> "vacío" en canal A no puede ser un simple `END` (`$FF`) si se quiere
> silenciar solo ese canal sin detener el motor entero — `$FF` en canal
> A dispara siempre `DETENER_SONIDO`; hay que usar una tirada de
> `RESET` (`$FE`) en su lugar.

## 10. Confianza y pendientes

El bloque completo de datos del motor de sonido (`$DBE0`-`$EFB5`) está
cerrado por completo — no queda ni un byte sin identificar. Puntos
genuinamente abiertos:

- `PERCUSION_3`/`PERCUSION_4` leen una tabla de 2 valores por
  iteración desde `$0280` (zona de sistema en RAM baja, reutilizada
  como área de trabajo) en vez de calcular la percusión por fórmula
  como `PERCUSION_1`/`PERCUSION_2` — qué rellena esa dirección y por
  qué se eligió esa zona en concreto no está confirmado.
- 6 guiones de demo (`GUION_DEMO_SINREF_1`-`6`, incluidos 2 que en
  algún momento se confundieron con datos de sonido, ver §11) tienen
  formato válido pero ningún índice de la tabla de perfiles de demo los
  referencia — candidatos a tomas descartadas o una versión antigua del
  ciclo de demo.
- `EFECTO_SONIDO_HUERFANO` (`$9003`, §5): mismo formato que los 12
  efectos activos, sin ninguna entrada de tabla que lo referencie.
- Los índices 10/11 de `TABLA_RECURSOS_SONIDO_EVENTO` no se disparan
  nunca en el código transcrito, y aunque se dispararan sonarían mudos.
- El efecto musical/audible exacto de los comandos `PATCH1`/`PATCH2`
  (qué diferencia se oye, más allá de qué bytes reescriben) no se ha
  caracterizado a oído.

## 11. Nota metodológica: una lección sobre "decodifica sin fallos"

Vale la pena documentar un tropiezo real de la investigación, porque es
instructivo más allá de este proyecto concreto: en un momento dado se
llegó a caracterizar un tramo de 189 fragmentos (`$E3D8`-`$EF9E`) como
"189 guiones de música huérfanos", partiendo de que el desensamblador
de bytecode los recorría sin ningún error. Esto resultó ser **falso**
— ese tramo es en realidad el bitmap comprimido del marco decorativo de
carga (ver `manual_subsistema_grafico.md` §8) más su tabla de
atributos, sin relación alguna con el sonido. El motivo: el formato de
bytecode del motor de música es tan permisivo (casi cualquier byte de
0-255 tiene alguna lectura válida como nota o comando) que recorrerlo
sin errores es una prueba mucho más débil de lo que parece a primera
vista. La lección aplicada desde entonces: para confirmar que un tramo
de datos es realmente un guion de sonido no basta con que el
desensamblador lo "trague" limpio — hace falta ejecutar o simular el
código real y comparar tamaños/direcciones contra lo que se sabe con
certeza (en este caso, el tamaño exacto de una pantalla del Spectrum).

## 12. Para seguir profundizando

- `FINDINGS.md` — todas las secciones relacionadas con sonido, en
  orden cronológico, incluida la corrección de §11.
- `recursos/flujo_programa.html` §4 — dónde encaja
  `DESPACHAR_EFECTO_SONIDO` en el flujo de una interrupción completa.
- `manual_motor_colision_ia.md` — qué evento de juego dispara cada
  índice de `EVENTO_SONIDO_PENDIENTE` (este manual documenta solo el
  CÓMO suena, no el QUÉ lo dispara en detalle).
- `src/data/sound/` — los ficheros `.snd`/`.spt`/`.dem` ya extraídos,
  listos para `mmsnd_tool.py`/`mmsnd_render.py`.
