# Manual del motor de colisión/IA — Mad Mix Game (ZX Spectrum 48K)

*[Read this in English](manual_motor_colision_ia.en.md)*

*Ingeniería inversa, análisis y documentación: Rafael Eduardo Martín Candial (raemca@hotmail.com)*

> Fuente: `src/madmix_body.asm` — `LEER_ENTRADA` ($9AC6),
> `MOTOR_MOVIMIENTO_COLISION` ($60CD), `TABLA_MANEJADORES_LOSETA`
> ($6266), `MOTOR_MOVIMIENTO_ITEM` ($81BC) y los 3 manejadores de
> ítem móvil. Para la crónica de cómo se descubrió cada pieza, ver
> `FINDINGS.md`; este documento asume que ya está todo identificado y
> explica el resultado final de forma ordenada — salvo un punto (§7)
> que se señala explícitamente como síntesis razonada de esta sesión,
> no como hecho ya cerrado por el proyecto, porque no se ha verificado
> todavía jugando el `.tzx` reconstruido en un emulador.

## 1. Qué es esto y qué NO es

Este manual explica el motor de movimiento/colisión: cómo se lee la
entrada del jugador (teclado, Kempston, Sinclair), cómo decide el
motor qué hacer al llegar a cada tipo de loseta, cómo se mueven el
jugador y los 3 tipos de enemigo/ítem móvil por el laberinto, y qué
pasa al comer un ítem especial o al tocar a un enemigo.

**No es** un motor de físicas ni de pathfinding real (BFS/A\*): los 3
tipos de ítem móvil deciden dirección con una heurística tabulada muy
simple — sesgo a mantener la dirección anterior, elegir entre las
direcciones libres si no se puede, con un componente aleatorio — el
mismo diseño simplificado del Pac-Man clásico, idéntico al del
proyecto hermano de MSX.

## 2. Lectura de entrada del jugador: `LEER_ENTRADA` (`$9AC6`)

Tres esquemas de control seleccionables desde el menú
(`PROCESAR_MENU_CONTROLES`, `$8A20`), fijados en `MODO_ENTRADA`
(`$91B9`):

- **`MODO_ENTRADA=0` — teclado QAOP**: esquema clásico de Topo Soft —
  Q=arriba, A=abajo, O=izquierda, P=derecha (`TABLA_TECLAS_MODO_0`,
  `$9B45`, redefinible desde el menú "4 REDEFINE TECLAS").
- **`MODO_ENTRADA=1` — joystick Sinclair (emulado por teclado)**:
  escanea las teclas 1-5 (puerto derecho) y 0,9,8,7,6 (puerto
  izquierdo) del Interface 2, fundidas con `OR` — cualquiera de los dos
  puertos Sinclair activa las mismas 4 direcciones.
- **`MODO_ENTRADA=2` — joystick Kempston real**: lectura directa de
  hardware, `IN A,($1F)`, sin pasar por el escaneo de teclado. El
  formato de bits de Kempston (bit0=derecha, bit1=izquierda,
  bit2=abajo, bit3=arriba) coincide exactamente con el orden QAOP, así
  que el byte del puerto se usa sin reordenar.
- **`MODO_ENTRADA≥3`**: un esquema de teclas alternativo
  (`TABLA_TECLAS_MODO_3`) sin propósito confirmado — candidato a
  variante redefinible o resto de pruebas de desarrollo (§10).

Los 3 modos basados en teclado comparten el mismo motor de escaneo
(`ESCANEAR_TABLA_TECLAS`, 5 lecturas de `IN A,($FE)` sobre el puerto de
la ULA), y todos pasan por una comprobación común de pausa
(`TABLA_TECLA_PAUSA`) y un mecanismo **anti-jitter** poco habitual:
`RESOLVER_CONFLICTO_VERTICAL`/`RESOLVER_CONFLICTO_HORIZONTAL` detectan
si se están pulsando dos direcciones opuestas a la vez (arriba+abajo o
izquierda+derecha) y, en ese caso, sustituyen el par contradictorio por
los bits del fotograma anterior — evita que un rebote de teclado
produzca una dirección espuria.

Un acumulador (`ACUMULADOR_ENTRADA`, `$9B81`) reúne el resultado del
escaneo antes de fundirlo con el bit de pausa. Cuando el modo demo
está activo (`INDICE_CICLO_NIVELES`, `$8F43`), la dirección no sale de
esta rutina en absoluto: viene de un guion pregrabado (ver
`manual_niveles.md` §9).

## 3. Movimiento del jugador: `MOTOR_MOVIMIENTO_COLISION` (`$60CD`)

Llamado cada fotograma desde `BUCLE_PRINCIPAL_JUEGO` y desde
`BUSCAR_COLUMNA_HUD`. Pasos, en orden:

1. Lee la dirección (`LEER_ENTRADA` o el guion de demo) y la guarda en
   `DIRECCION_SIN_PROCESAR` (`$6029`).
2. **Buffering de dirección**: `FLAG_DIRECCION_NUEVA`/
   `COPIA_FLAG_DIRECCION_NUEVA` recuerdan si llegó una dirección nueva
   este fotograma, para poder aplicarla en cuanto el jugador esté
   alineado a rejilla en vez de descartarla si se pulsó "demasiado
   pronto" — el patrón clásico de los clones de Pac-Man.
3. Si `DIRECCION_FORZADA` (`$602D`, activada por una flecha "auto-coco")
   está activa, sustituye a la dirección elegida por el jugador.
4. **Alineación a rejilla**: comprueba la posición módulo 4 (celdas de
   4×4 subpíxeles) para decidir si el jugador puede girar ya o debe
   esperar a llegar al centro de la celda actual.
5. Consulta la loseta un paso por delante en la dirección elegida
   (`CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION`); si es intransitable,
   reintenta con la dirección anterior — permite "seguir recto" si el
   giro deseado todavía no es posible.
6. Resuelve el manejador de la loseta de destino (§4) y la animación
   del sprite del jugador (`PUNTEROS_SUBTABLA_DIRECCION`, 4 subtablas
   de animación por dirección) — el resultado se guarda en
   `SELECTOR_SPRITE_COMECOCOS` (`$6025`, cuyo bit 7 es el flag de
   volteo horizontal).

Variables clave de este paso: `DIRECCION_DE_MOVIMIENTO` (`$6024`),
`POSICION_ACTUAL_CAMARA` (`$602A`, valor inicial `$1018`),
`PUNTO_REFERENCIA_CAMARA` (`$6032`, la posición del jugador que usan
los 3 tipos de ítem móvil para perseguir/huir, §5).

## 4. Despachador de tipo de loseta: `TABLA_MANEJADORES_LOSETA` (`$6266`, 20 entradas)

Se llega a ella resolviendo el índice de tipo de la loseta de destino
(`CALCULAR_INDICE_TIPO_LOSETA` + `TABLA_TIPOS_LOSETA`, `$9B85`, 91
bytes — un byte de tipo por cada una de las 91 losetas del catálogo).

| Índice | Manejador | Qué hace |
|---|---|---|
| 0 | `HNDLR_SUELO_NORMAL` | Pared/suelo normal, sin efecto de juego |
| 1 | `HNDLR_BOLITA_NORMAL` | Come bolita: sustituye la loseta por el comodín, +1 punto, +1 bola comida |
| 2 | `HNDLR_BOLITA_CLAVADA` | Bola fija/clavada — necesita el ítem "herramienta" antes de poder comerse |
| 3-6 | `HNDLR_AUTOCOCO_ARRIBA`/`ABAJO`/`IZQUIERDA`/`DERECHA` | Flecha de dirección forzada: fija `DIRECCION_FORZADA`, +2 puntos, +1 bola comida (cuenta como bolita a efectos de fin de nivel) |
| 7 | `HNDLR_PISTA_COCOTANQUE` | Entrada a pista de tanque — convierte al jugador en tanque |
| 8, 9 | = `HNDLR_SUELO_NORMAL` (duplicado) | |
| 10 | `HNDLR_PISTA_COCONAVE` | Pista de avión — convierte al jugador en avión |
| 11 | `HNDLR_ITEM_SUELO` | Ítem de suelo (función exacta sin confirmar del todo, §10) |
| 12 | `HNDLR_BOLA_PODER` | Ítem especial: activa el modo "fantasmas huyen" (§6) |
| 13 | `HNDLR_HIPODOSO` | Ítem especial: pisas enemigos, no puedes comer bolitas mientras dura (§6) |
| 14 | `HNDLR_EXCAVATOFONO` | Ítem especial "herramienta": permite desclavar bolas clavadas (§6) |
| 15, 16 | `HNDLR_SUELO_SIN_BOLA` | Resetea el modo especial ligado a esa loseta |
| 17, 18 | `HNDLR_TRAMPILLA_ABIERTA_DERECHA`/`IZQUIERDA` | Trampilla abriéndose |
| 19 | `HNDLR_TRAMPILLA_CERRADA` | Trampilla cerrándose |

**Regla importante**: si `MODO_ESPECIAL_ACTIVO` (`$6023`, §7) está
activo, el índice de tipo se fuerza a 0 y el despacho entero se desvía
a `TICK_MODO_ESPECIAL` en vez de al manejador real — mientras esa
cuenta atrás corta está corriendo, **todos los efectos de loseta quedan
desactivados**.

## 5. IA de los 3 tipos de ítem móvil

Comparten la misma subrutina de decisión de dirección,
**`MOTOR_MOVIMIENTO_ITEM`** (`$81BC`). Registro de actor de 7 bytes:
posición (X,Y), estado/modo (offset 2, usado también por
`ACTIVAR_EFECTO_ITEM`, §6), dirección resuelta, sub-posición, fase de
animación.

Cada manejador se llama tras `GESTIONAR_SCROLL` cada fotograma, y
**solo si `FLAG_ENTRADA_BLOQUEADA` (`$9B84`) vale 0** — el mismo flag
que bloquea la lectura de entrada nueva también bloquea el movimiento/
redibujado de los 3 tipos de enemigo y del propio jugador (se activa,
por ejemplo, durante la animación de `BUSCAR_COLUMNA_HUD` al empezar
un nivel).

### 5.1 `HNDLR_PELMAZOIDE` (`$8142`) — "fantasma"

Hasta **8** activos por nivel (`REGISTRO_NIVEL_CONTADOR_PELMAZOIDES`).
Calcula `PUNTO_REFERENCIA_CAMARA` (posición del jugador, con un
desplazamiento fijo) para que la IA lo persiga; cuando
`MODO_ESPECIAL_CUENTA_ATRAS` está a punto de expirar, el sprite
parpadea (aviso visual de que el efecto de huida está por acabar).

### 5.2 `HNDLR_MARICOCO` (`$83ED`) — "mariquita, repone bolitas"

Hasta **2** activas por nivel. Cuando está alineada a rejilla, comprueba
si la loseta bajo ella es un "comodín" regenerable a bolita; si el
jugador se aleja lo suficiente, la regenera (decrementa
`CONTADOR_BOLAS_COMIDAS`, redibuja la loseta como bolita,
`EVENTO_SONIDO_PENDIENTE=5`). Fuerza su estado (offset 2 del registro)
a `1` justo antes de comprobar colisión con el jugador.

### 5.3 `HNDLR_REGPUNANTOSO` (`$8504`) — "repugnantoso, convierte bolitas en clavadas"

Hasta **8** activos por nivel. Efecto inverso al de la mariquita: si
detecta una bolita normal bajo ella y el jugador se ha alejado lo
suficiente, la "planta" como bola clavada (el efecto que luego deshace
el ítem "herramienta"). Fuerza su estado a `2`,
`EVENTO_SONIDO_PENDIENTE=6`.

### 5.4 El algoritmo de decisión de dirección (compartido)

1. **Persecución/huida**: compara la posición del ítem contra
   `PUNTO_REFERENCIA_CAMARA`. Si `MODO_ESPECIAL_FLAG` (`$6021`) está
   activo, invierte el delta — el enemigo **huye** en vez de perseguir
   (solo lo activa `HNDLR_BOLA_PODER`, §6).
2. **Solo en intersecciones** (celda alineada) recalcula dirección; si
   no, sigue en la ya fijada.
3. Construye un bitmask de 4 bits de direcciones libres consultando
   `TABLA_TIPOS_LOSETA` en las 4 celdas vecinas.
4. Si la dirección "deseada" está libre, se usa. Si no,
   **`TABLA_ELECCION_DIRECCION`** (128 bytes, indexada por
   `bitmask_libres` + clase de dirección previa + un bit aleatorio)
   resuelve la elección, con sesgo a **mantener la dirección anterior
   si es posible**.
5. El generador aleatorio (`GENERAR_ALEATORIO`) usa el registro `R` del
   Z80 (refresco de memoria) como fuente de entropía.

No hay pathfinding dirigido: es persecución simple por delta de
posición más una heurística de continuidad tabulada, con
aleatoriedad — mismo diseño simplificado del Pac-Man clásico.

## 6. Ítems especiales y modos temporales

Al comer cada uno de los 3 ítems especiales de suelo:

- **`HNDLR_BOLA_PODER`** (tile 60): activa `MODO_ESPECIAL_FLAG=1` (los
  enemigos huyen, §5.4), fija `MODO_ESPECIAL_CUENTA_ATRAS` a la
  duración de nivel (`REGISTRO_NIVEL_DURACION_PARPADEO`), cambia el
  color del HUD, marca `MODO_ESPECIAL=1`.
- **`HNDLR_HIPODOSO`** (tile 61): igual mecánica pero sin activar la
  huida de enemigos, `MODO_ESPECIAL=2` — "pisas" enemigos en vez de
  evitarlos.
- **`HNDLR_EXCAVATOFONO`** (tile 62, "herramienta"): habilita
  desclavar bolas clavadas (tipo 2), `MODO_ESPECIAL=3`.

**`TICK_MODO_ESPECIAL`**, llamado al final de cada manejador de
loseta, decrementa `MODO_ESPECIAL_CUENTA_ATRAS` cada fotograma,
distingue el icono de HUD según el modo activo, y al llegar a 0 apaga
los flags — esta es la cuenta atrás **visual** del power-up, ligada a
la duración de nivel.

**`ACTIVAR_EFECTO_ITEM`** (`$871C`) es el punto de colisión
jugador-ítem móvil, llamado tras dibujar cada actor de los 3 tipos:

- No hace nada si `MODO_ESPECIAL_ACTIVO` (§7) ya está corriendo
  (debounce: un solo disparo por "encuentro").
- Comprueba si la posición de pantalla donde se acaba de dibujar el
  ítem cae dentro de una ventana fija — el jugador siempre está
  centrado en pantalla, es el laberinto el que hace scroll, así que
  "colisión" aquí es "¿el enemigo se dibujó encima de donde está
  siempre el jugador?".
- Si colisiona y hay un power-up **vigente** (`MODO_ESPECIAL≠0`):
  otorga puntos (4 o 6, según el estado del ítem) y dispara un aviso de
  destello + sonido — el enemigo "se come".
- Si colisiona y **no** hay power-up vigente: entra en
  `ACTIVAR_NUEVO_MODO_ESPECIAL`, que arma `MODO_ESPECIAL_ACTIVO` a
  42 o 47 fotogramas (según el tipo de ítem tocado) — ver §7 para lo
  que representa esta cuenta atrás.

## 7. Colisión jugador-enemigo y pérdida de vida

> ⚠️ Este apartado documenta un mecanismo cuyo código está verificado
> línea a línea, pero cuya **interpretación de juego** (qué representa
> exactamente para el jugador) es una síntesis razonada de esta
> investigación, no un hecho ya confirmado jugando el `.tzx`
> reconstruido en un emulador. Márquese como hipótesis fundamentada,
> pendiente de esa verificación (ver §10).

El único mecanismo de pérdida de vida localizado en todo el motor está
dentro de `BUCLE_PRINCIPAL_JUEGO`, anidado en la misma comprobación de
`MODO_ESPECIAL_ACTIVO` que arma `ACTIVAR_NUEVO_MODO_ESPECIAL` (§6):

```
LD A,(MODO_ESPECIAL_ACTIVO)     ; $6023
AND A
JR Z,VERIFICAR_FIN_NIVEL        ; si vale 0, no hay nada que decrementar
DEC (HL)
JR NZ,VERIFICAR_FIN_NIVEL       ; si sigue >0 tras decrementar, sigue contando
; --- solo llega aqui el fotograma en que la cuenta atras acaba de llegar a 0 ---
... restaura color, reproduce el jingle de fin de modo especial ...
LD A,(VIDAS_RESTANTES)          ; $603A
ADD A,delta                     ; delta en $6003, candidato -1
LD (VIDAS_RESTANTES),A
JP C,REINICIAR_ESTADO_NIVEL     ; quedan vidas -> respawn
... si no -> "ESTAS FRITO" (game over), vuelta al menu
```

Es decir: **la única resta de vida del motor ocurre cuando
`MODO_ESPECIAL_ACTIVO` expira**, no hay ninguna comprobación de
posición jugador-enemigo independiente en ningún otro punto del
fichero.

Combinando esto con §6, la lectura más coherente del mecanismo
completo es: tocar un `HNDLR_PELMAZOIDE` o un `HNDLR_REGPUNANTOSO`
mientras no hay ningún power-up vigente arma `MODO_ESPECIAL_ACTIVO` a
42-47 fotogramas (menos de un segundo a 50 Hz); mientras esa cuenta
atrás corre, todos los efectos de loseta quedan desactivados (§4) — un
"instante congelado" de aviso — y, salvo que el jugador coma un
power-up real antes (lo que desviaría `ACTIVAR_EFECTO_ITEM` hacia la
rama de puntuación en vez de la de armado), al expirar la cuenta atrás
se resta una vida. Esto es coherente con que tocar a la "mariquita"
(`HNDLR_MARICOCO`, benigna) fuerza siempre un estado (`1`) que
`ACTIVAR_NUEVO_MODO_ESPECIAL` trata como "sin efecto" — la mariquita no
puede matar al jugador, solo el fantasma y el "repugnantoso" pueden.

## 8. Sistema de puntuación: `DIBUJAR_MARCADOR_PUNTOS` (`$9A01`)

Llamado cada vez que hay un cambio de puntuación (desde los
manejadores de loseta y desde `ACTIVAR_EFECTO_ITEM`), no cada
fotograma:

- En modo demo, dibuja un texto fijo en vez de la puntuación real.
- En juego normal: suma los puntos recibidos a `PUNTUACION` (`$603C`).
  Si llega a 10000, muestra el mismo texto especial en vez de los
  dígitos (candidato a tope de marcador). Si no, convierte a texto y
  dibuja los dígitos en la posición fija del marcador.

`BUSCAR_COLUMNA_HUD` (`$9CCB`) es un mecanismo distinto — la animación
de "búsqueda de columna" del HUD al empezar cada nivel, no relacionada
con puntuación por colisión; bloquea `FLAG_ENTRADA_BLOQUEADA` mientras
dura.

## 9. Variables de estado compartido clave

| Dirección | Nombre | Rol |
|---|---|---|
| `$600F` | `REGISTRO_NIVEL_CONTADOR_PELMAZOIDES` | Nº de fantasmas activos este nivel (≤8) |
| `$6012` | `REGISTRO_NIVEL_DURACION_PARPADEO` | Duración visual de nivel del power-up |
| `$6021` | `MODO_ESPECIAL_FLAG` | 1 = enemigos huyen (solo lo activa `HNDLR_BOLA_PODER`) |
| `$6022` | `MODO_ESPECIAL_CUENTA_ATRAS` | Duración visual del power-up, decrementada en `TICK_MODO_ESPECIAL` |
| `$6023` | `MODO_ESPECIAL_ACTIVO` | Cuenta atrás corta (42-47 fotogramas); su expiración resta una vida (§7); mientras ≠0, desactiva los efectos de loseta |
| `$6024` | `DIRECCION_DE_MOVIMIENTO` | Dirección de movimiento del jugador este fotograma |
| `$6029` | `DIRECCION_SIN_PROCESAR` | Valor crudo de entrada antes de procesar |
| `$602A` | `POSICION_ACTUAL_CAMARA` | Posición de cámara/jugador (word) |
| `$602D` | `DIRECCION_FORZADA` | Dirección impuesta por una flecha "auto-coco" |
| `$602F` | `FLAG_DIRECCION_NUEVA` | Buffering: hay una dirección nueva pendiente |
| `$6032` | `PUNTO_REFERENCIA_CAMARA` | Posición del jugador usada por la IA de los 3 tipos de ítem |
| `$6035` | `SEMILLA_ALEATORIA` | Semilla del PRNG basado en el registro `R` |
| `$603A` | `VIDAS_RESTANTES` | Vidas restantes |
| `$603C` | `PUNTUACION` | Puntuación acumulada (word) |
| `$6040` | `MODO_ESPECIAL` | Power-up vigente (0=ninguno, 1=bola de poder, 2=hipopótamo, 3=herramienta) |
| `$8F43` | `INDICE_CICLO_NIVELES` | Activo = modo demo |
| `$91B9` | `MODO_ENTRADA` | 0=teclado QAOP, 1=Sinclair, 2=Kempston, 3=alternativo sin confirmar |
| `$9B84` | `FLAG_ENTRADA_BLOQUEADA` | Bloquea entrada nueva y movimiento/redibujado de todos los actores |
| `$9B85` | `TABLA_TIPOS_LOSETA` | 91 bytes, índice de loseta → tipo (0-19) |

## 10. Confianza y pendientes

El despachador de losetas, el algoritmo de movimiento del jugador, y
la IA de los 3 tipos de ítem móvil están verificados por lectura
directa del código, con coincidencia casi total instrucción a
instrucción con el proyecto hermano de MSX. Puntos abiertos:

- **La interpretación de §7 como "vida perdida al tocar un enemigo"**
  es la pieza de mayor prioridad para verificar — recomendado jugar el
  `.tzx` reconstruido en un emulador y observar qué ocurre exactamente
  al tocar cada uno de los 3 tipos de ítem móvil en cada combinación de
  `MODO_ESPECIAL`.
- `TABLA_TECLAS_MODO_3` (`MODO_ENTRADA≥3`): sin propósito confirmado.
- Tile 59 (`HNDLR_ITEM_SUELO`): función sin confirmar del todo, parecido
  visual al tile 60 (bola de poder).
- La descripción textual del catálogo visual dice que el modo
  hipopótamo es "sin puntos", pero el código sí otorga puntos al
  "comer" un enemigo durante ese modo — posible matiz no capturado por
  el catálogo, o el "sin puntos" se refiere a que comer bolitas queda
  bloqueado mientras dura; sin reconciliar.
- El detalle línea a línea del subsistema de tanque/avión
  (`HNDLR_PISTA_COCOTANQUE`/`HNDLR_PISTA_COCONAVE`) queda fuera del
  alcance de este manual.
- `$6047`-`$605F` (30 bytes): sin identificar, sin código que los
  referencie.

## 11. Para seguir profundizando

- `FINDINGS.md` — todas las secciones relacionadas con entrada,
  movimiento, tipos de loseta e IA, en orden cronológico.
- `recursos/flujo_programa.html` §3-4 — la tabla de despacho de
  losetas y las variables de estado compartido en el contexto del flujo
  completo del juego.
- `manual_niveles.md` — cómo se colocan los enemigos al cargar un
  nivel, y el mecanismo de guiones de demo que sustituye a
  `LEER_ENTRADA`.
- `manual_subsistema_grafico.md` — cómo se dibuja cada actor una vez
  que este motor decidió dónde debe estar (este manual documenta solo
  el QUÉ y el CUÁNDO).
- `recursos/graficos.html` — catálogo visual de las 91 losetas del
  laberinto ya identificadas.
