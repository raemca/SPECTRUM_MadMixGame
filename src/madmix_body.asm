; ============================================================
;  CODE.bin (version de cinta, Topo Soft 1988) - ZX Spectrum 48K
;  El motor completo del juego -- 36790 bytes, cargado por
;  LOADER.bin en $6000 (ver load_cas/loader_body.asm) y ejecutado
;  con JP $6000 justo despues de cargarlo. Ocupa EXACTAMENTE
;  $6000-$EFB5, pegado sin hueco al inicio de LOADER.bin ($EFB6) --
;  los tres binarios de cinta (portada, motor, loader) son
;  contiguos en el mapa de memoria de careteristicas $5D1C-$F079.
;
;  RECONSTRUCCION MECANICA DE PRIMERA PASADA -- NO es todavia un
;  analisis semantico como load_cas/loader_body.asm. Generada
;  automaticamente a partir de la salida de Z80Dasm.exe con un
;  conversor propio (dasm2asm.py, ver FINDINGS.md): cada linea del
;  desensamblado lineal se tradujo 1:1 a sintaxis SjASMPlus, y se
;  puso etiqueta CODE_XXXX solo en las direcciones que son a la vez
;  (a) destino real de un CALL/JP/JR/DJNZ dentro de este mismo
;  fichero y (b) inicio real de una instruccion decodificada -- el
;  resto de operandos con direccion absoluta se dejaron en hex
;  literal tal cual. Como el desensamblado es LINEAL (recorre todos
;  los bytes de principio a fin sin seguir el flujo real del
;  programa), es CASI SEGURO que partes de este fichero son en
;  realidad DATOS (tablas de sprites, niveles, sonido...)
;  malinterpretados como instrucciones -- el hecho de que
;  recompile BYTE A BYTE IDENTICO al original (ver mas abajo) lo
;  garantiza matematicamente el desensamblador lineal siempre
;  puede re-ensamblarse igual, entienda o no lo que hay en cada
;  zona, exactamente igual que ocurrio con LOAD.BIN en el proyecto
;  MSX antes de identificar sus huecos de datos uno a uno.
;
;  3 instrucciones tuvieron que volcarse como DB en vez de mnemonico
;  (mismo byte, $FD 64/$FD 64/$FD 6C -- formas "IYH,H"/"IYL,H" de
;  opcodes no documentados que el Z80 real ejecuta pero SjASMPlus no
;  acepta como texto): $C6E4, $C7A4, $DFA7. Su sola presencia (y la
;  de tantos "RST 18H" seguidos alrededor, ver FINDINGS.md) es un
;  indicio fuerte de que esa zona es tabla de datos, no codigo real.
;
;  VERIFICACION: recompilado con SjASMPlus (DEVICE ZXSPECTRUM48,
;  ORG $6000, INCLUDE de este fichero, SAVEBIN) y comparado byte a
;  byte contra CODE.bin extraido del .tzx original -- 0 diferencias,
;  36790/36790 bytes identicos.
;
;  Pendiente para proximas sesiones: identificar manualmente que
;  tramos son datos reales (y sustituir su desensamblado falso por
;  DB/tablas con nombre), encontrar el bucle principal, el driver de
;  sonido, las tablas de nivel y sprites, y la pantalla de creditos.
;
; Ingeniería inversa, herramientas y documentación de este proyecto: Rafael Eduardo Martín Candial (raemca@hotmail.com)
; ============================================================

; Generado mecanicamente a partir de Z80Dasm.exe + dasm2asm.py
; (traduccion literal, sin analisis semantico todavia -- ver FINDINGS.md)
MOTOR_INICIO:
    JP INICIO
; ==============================================================
;  ZONA DE VARIABLES DEL MOTOR ($6003-$605F, 93 bytes) -- RESUELTA
;  EN BUENA PARTE (sesion 25). Bytes reales de trabajo del motor,
;  NUNCA ejecutados como codigo (el "JP INICIO" de MOTOR_INICIO salta
;  por encima de todo esto) -- el desensamblado mecanico los leia
;  linealmente y los mostraba como pseudo-instrucciones sin sentido
;  (NOP/LD BC,xxxx/etc.), igual que paso con MODO_ENTRADA/FRAME_FLAG
;  al principio de START en MSX (mismo patron: variables de trabajo
;  justo detras del salto de entrada). Reconvertido a DB/DW reales.
;
;  18 direcciones identificadas con confianza alta en sesion 24,
;  comparando CARGAR_NIVEL byte a byte contra madmix_scr_body.asm de
;  MSX (ver esa rutina para el detalle completo de la comparacion):
;  REGISTRO_NIVEL_CUERPO_PTR/CABECERA_PTR/PIE_PTR/FILAS/
;  LOSETA_COMODIN/FILA_COLUMNA, NIVEL_ACTUAL, CONTADOR_VUELTAS_NIVELES,
;  CONTADOR_BOLAS_COMIDAS, POSICION_PARPADEO_BOLA, MODO_ESPECIAL(_ACTIVO/
;  _CUENTA_ATRAS/_FLAG), SELECTOR_SPRITE_COMECOCOS, COLOR_ACTUAL,
;  COLOR_GUARDADO. Mas VIDAS_RESTANTES/PUNTUACION (hipotesis fuerte
;  desde sesion 22, coinciden en orden/valor con REINICIAR_PARTIDA de
;  MSX pero sin una confirmacion tan directa como las 18 anteriores).
;
;  Varios bytes NO identificados todavia se dejan como DB sueltos sin
;  etiqueta (en vez de inventar un nombre): unos son relleno puro
;  (siempre $00, sin ninguna referencia externa encontrada), otros SI
;  se leen/escriben desde codigo real en otras partes del fichero
;  ($600E, $6018, $603E) pero su papel exacto aun no tiene
;  correspondencia MSX identificada -- se anota su uso conocido en el
;  comentario para la proxima sesion. CODE_6026/$6027 SI tienen ya
;  nombre MSX confirmado (sesion 37, ver CACHE_TIPO_LOSETA/
;  CACHE_COLUMNA_LOSETA mas abajo).
;
;  CURIOSO (paralelo con el hallazgo de la portada, sesion 16): varios
;  bytes de esta zona NO son cero en el .tzx compilado, pese a que
;  logicamente deberian estar a 0 "de fabrica" (son variables que el
;  propio motor sobreescribe siempre antes de leerlas) -- p.ej.
;  REGISTRO_NIVEL_FILAS=18, REGISTRO_NIVEL_LOSETA_COMODIN=192/$C0,
;  VIDAS_RESTANTES=3 (coincide con el valor inicial real, pero podria
;  ser casualidad). Posible eco del mismo fenomeno que en la portada
;  (cinta generada volcando RAM tras una ejecucion real) -- sin
;  investigar a fondo todavia, caso de baja prioridad.
; ==============================================================
    DB $FF,$E1,$FB,$C9            ; $6003-$6006, sin identificar
REGISTRO_NIVEL_CUERPO_PTR:        ; $6007, 2 bytes (word)
    DW 0
REGISTRO_NIVEL_CABECERA_PTR:      ; $6009, 2 bytes (word)
    DW 0
REGISTRO_NIVEL_PIE_PTR:           ; $600B, 2 bytes (word)
    DW 0
REGISTRO_NIVEL_FILAS:             ; $600D, 1 byte
    DB 18
    DB $01                        ; $600E, referenciada en COMPROBAR_AVISO_ULTIMA_VIDA
                                ; ("LD A,($600E) / CP 1"), sin
                                ; correspondencia MSX identificada
REGISTRO_NIVEL_CONTADOR_PELMAZOIDES:  ; $600F, 1 byte -- mismo nombre EXACTO
                                ; que MSX, CONFIRMADO sesion 49 via
                                ; HNDLR_PELMAZOIDE ("LD A,
                                ; (REGISTRO_NIVEL_CONTADOR_PELMAZOIDES)").
    DB 2                        ; RESUELTO sesion 56 continuacion 27 (antes $02) --
                                ; misma cantidad (contador de enemigos) que
                                ; items_tipo3/1/2 en TABLA_NIVELES, ya decimal
    DB 1                         ; $6010, candidato REGISTRO_NIVEL_CONTADOR_MARICOCOS (sesion 40) -- decimal (antes $01)
    DB 1                         ; $6011, candidato REGISTRO_NIVEL_CONTADOR_REPUGNANTOSOS (sesion 40) -- decimal (antes $01)
REGISTRO_NIVEL_DURACION_PARPADEO: ; REGISTRO_NIVEL_DURACION_PARPADEO, 1 byte -- mismo nombre EXACTO
                                ; que MSX, confirmado sesion 39 via
                                ; HNDLR_BOLA_PODER/HNDLR_HIPODOSO ("LD A,
                                ; (REGISTRO_NIVEL_DURACION_PARPADEO) / LD
                                ; (MODO_ESPECIAL_CUENTA_ATRAS),A").
    DB 200                        ; RESUELTO sesion 56 continuacion 27 (antes $C8) --
                                ; misma cantidad (segundos a 50Hz) que
                                ; duracion_parpadeo en TABLA_NIVELES, ya decimal
REGISTRO_NIVEL_LOSETA_COMODIN:    ; $6013, 1 byte
    DB 192
REGISTRO_NIVEL_FILA_COLUMNA:      ; $6014, 2 bytes (word) -- fila=16,
                                ; columna=16 (empaquetado en 1 word,
                                ; igual que en MSX)
    DW $1010
REGISTRO_NIVEL_POSICION_COMECOCOS: ; REGISTRO_NIVEL_POSICION_COMECOCOS, 2 bytes (word) -- mismo
                                ; nombre EXACTO que MSX, candidato desde
                                ; sesion 34 (leido por GESTIONAR_SCROLL,
                                ; MAPEAR_LOSETA_RELATIVA_A_ABSOLUTA y
                                ; varios manejadores de loseta).
    DW $0001
REGISTRO_NIVEL_ICONO_HUD:         ; REGISTRO_NIVEL_ICONO_HUD, 1 byte -- mismo nombre EXACTO
                                ; que MSX, confirmado sesion 39 via
                                ; HNDLR_PISTA_COCOTANQUE/HNDLR_PISTA_COCONAVE/
                                ; HNDLR_HIPODOSO ("LD A,
                                ; (REGISTRO_NIVEL_ICONO_HUD) / LD
                                ; (COLOR_ACTUAL),A").
    DB $38
    DB $00,$00                    ; $6019-$601A, sin identificar
NIVEL_ACTUAL:                     ; $601B, 1 byte
    DB 0
CONTADOR_BOLAS_COMIDAS:           ; $601C, 2 bytes (word)
    DW 0
POSICION_PARPADEO_BOLA:           ; $601E, 2 bytes (word)
    DW 0
TEMPORIZADOR_PARPADEO_BOLA:       ; $6020, 1 byte -- mismo nombre EXACTO
                                ; que MSX, CONFIRMADA sesion 49 via
                                ; INICIALIZAR_ITEMS_NIVEL/INICIALIZAR_PARCIAL_ITEMS_NIVEL.
    DB $00
MODO_ESPECIAL_FLAG:               ; $6021, 1 byte
    DB 0
MODO_ESPECIAL_CUENTA_ATRAS:       ; $6022, 1 byte
    DB 0
MODO_ESPECIAL_ACTIVO:             ; $6023, 1 byte
    DB 0
DIRECCION_DE_MOVIMIENTO:          ; DIRECCION_DE_MOVIMIENTO, 1 byte -- mismo nombre EXACTO
                                ; que MSX, confirmado sesion 37 via
                                ; MOTOR_MOVIMIENTO_COLISION (coincidencia
                                ; casi total instruccion a instruccion
                                ; con MSX): direccion final de este
                                ; fotograma, ya resuelta tras aplicar la
                                ; mascara de alineamiento.
    DB $00
SELECTOR_SPRITE_COMECOCOS:        ; $6025, 1 byte
    DB 0
CACHE_TIPO_LOSETA:                ; $6026, 1 byte -- mismo nombre EXACTO
                                ; que MSX, confirmado sesion 37 via
                                ; CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION
                                ; ($62AF/$62C5/$6320): cache del ultimo
                                ; tipo de loseta consultado (evita
                                ; repetir CONSULTAR_TIPO_LOSETA).
    DB $00
CACHE_COLUMNA_LOSETA:             ; CACHE_COLUMNA_LOSETA, 1 byte -- mismo nombre EXACTO
                                ; que MSX, confirmado sesion 37: cache de
                                ; la ultima columna consultada.
    DB $00
INDICE_SUBTABLA_DIRECCION:        ; $6028, 1 byte -- mismo nombre EXACTO
                                ; que MSX (indice rotativo 0-3 del
                                ; fotograma de animacion, confirmado
                                ; sesion 36 via BUCLE_SUBTABLA_DIRECCION,
                                ; instruccion a instruccion identica a
                                ; MSX). Reemplaza el anterior "indice
                                ; ciclico en $6028" sin etiqueta propia.
    DB $00
DIRECCION_SIN_PROCESAR:           ; DIRECCION_SIN_PROCESAR, 1 byte -- mismo nombre EXACTO
                                ; que MSX, confirmado sesion 37: direccion
                                ; "cruda" de este fotograma (antes de
                                ; aplicar la mascara de alineamiento),
                                ; guardada por MOTOR_MOVIMIENTO_COLISION.
    DB $00
POSICION_ACTUAL_CAMARA:           ; POSICION_ACTUAL_CAMARA, 2 bytes (word) -- mismo nombre
                                ; EXACTO que MSX, confirmado sesion 37:
                                ; valor inicial $1018 IDENTICO al de MSX
                                ; ($2C16-17, "GESTIONAR_SCROLL la lee, los
                                ; modos tanque/avion la fijan a un valor
                                ; concreto ($1018/$1C18) mientras duran").
    DW $1018
COLOR_GUARDADO:                   ; $602C, 1 byte
    DB $78
DIRECCION_FORZADA:                ; DIRECCION_FORZADA, 1 byte -- mismo nombre EXACTO
                                ; que MSX, confirmado sesion 37
                                ; (MOTOR_MOVIMIENTO_COLISION): override de
                                ; "direccion sticky" (activado por flechas/
                                ; trampillas), 0=sin forzar.
    DB $00
TEMPORIZADOR_DIRECCION_FORZADA:   ; TEMPORIZADOR_DIRECCION_FORZADA, 1 byte -- mismo nombre EXACTO
                                ; que MSX, confirmado sesion 37: cuenta
                                ; atras de cuantos frames mas dura la
                                ; direccion forzada (patron real de
                                ; cuenta atras: "LD A,(HL)/AND A/JR Z/
                                ; DEC (HL)" en TEMPORIZADOR_DIRECCION_FORZADA_TICK).
    DB $00
FLAG_DIRECCION_NUEVA:             ; FLAG_DIRECCION_NUEVA, 1 byte -- mismo nombre EXACTO
                                ; que MSX, confirmado sesion 37: flag "hay
                                ; input de direccion nuevo tras soltar",
                                ; armado/desarmado en MOTOR_MOVIMIENTO_COLISION.
    DB $00
COPIA_FLAG_DIRECCION_NUEVA:       ; COPIA_FLAG_DIRECCION_NUEVA, 1 byte -- mismo nombre EXACTO
                                ; que MSX, confirmado sesion 37: copia del
                                ; flag anterior, candidato a "flanco de
                                ; pulsacion".
    DB $00
LADO_APERTURA_TRAMPILLA:          ; LADO_APERTURA_TRAMPILLA, 1 byte -- mismo nombre EXACTO
                                ; que MSX, confirmado sesion 37: lado por
                                ; el que se abrio la trampilla en curso,
                                ; 1=izquierda/2=derecha (se fija a la vez
                                ; que DIRECCION_FORZADA con el mismo
                                ; valor, en varios sitios de TEMPORIZADOR_DIRECCION_FORZADA_TICK).
    DB $00
PUNTO_REFERENCIA_CAMARA:          ; PUNTO_REFERENCIA_CAMARA, 2 bytes (word) -- mismo nombre
                                ; EXACTO que MSX, candidato desde sesion 35
                                ; ("posicion real del comecocos", calculada
                                ; en HNDLR_PELMAZOIDE como $6016+16,+24) --
                                ; encaja con MSX: "punto de mira" (camara+
                                ; desplazamiento), usado por la logica de
                                ; movimiento de fantasmas.
    DW $0000
    DB $00                        ; $6034, sin identificar
SEMILLA_ALEATORIA:                ; $6035, 2 bytes (word) -- mismo nombre EXACTO
                                ; que MSX, CONFIRMADA sesion 49 via
                                ; GENERAR_ALEATORIO ("LD HL,(SEMILLA_ALEATORIA)").
    DW $0000
COLOR_ACTUAL:                     ; $6037, 1 byte
    DB $78
    DB $00,$00                    ; $6038-$6039, sin identificar
VIDAS_RESTANTES:                  ; $603A, 1 byte -- HIPOTESIS (sesion 22)
    DB 3
    DB $00                        ; $603B, sin identificar
PUNTUACION:                       ; $603C, 2 bytes (word) -- HIPOTESIS (sesion 22)
    DW 0
    DB $00                        ; $603E, referenciada en COMPROBAR_VIDA_EXTRA
                                ; ("LD HL,$603E / LD A,(HL)"), sin
                                ; correspondencia MSX identificada
CONTADOR_VUELTAS_NIVELES:         ; $603F, 1 byte
    DB 0
MODO_ESPECIAL:                    ; $6040, 1 byte
    DB 0
; TABLA_PISTAS_TANQUE_AVION ($6041, 6 bytes = 3 ranuras x 2 bytes) --
; RESUELTA sesion 56 tirando del hilo de "tira del hilo CODE_61FB"
; (etiqueta interna dentro de MOTOR_MOVIMIENTO_COLISION, renombrada
; CONTINUAR_LLAMADA_SCROLL -- resulto ser un punto de paso trivial, el
; verdadero hallazgo estaba justo debajo). 4 consumidores identificados
; en el fichero (antes sin conectar entre si): LOOP_LIMPIEZA_PISTA
; (vacia las 3 ranuras al cargar nivel), REGISTRAR_PISTA_TANQUE_AVION
; (escritor inicial: byte1=$68 o $40 segun bit0/bit7 de la direccion,
; byte2=direccion cruda, fija), AVISAR_PROXIMIDAD_PISTA (dispara el
; flash de avistamiento cuando el jugador se acerca al punto
; registrado) y BUCLE_PISTA_TANQUE_AVION (mas abajo, RESUELTA la misma
; sesion). Formato de cada ranura: byte2 bit0 decide el eje -- si esta
; activo, columna fija $40=64 y fila variable =byte1 (linea vertical);
; si no, fila fija $38=56 y columna variable =byte1 (linea horizontal),
; con byte2 bit7 decidiendo el sentido. CONFIRMADO por lectura de
; registros: byte1 NO es una posicion fija -- BUCLE_PISTA_TANQUE_AVION lo
; REESCRIBE cada fotograma con el valor ya desplazado (+-8 horizontal,
; -16 vertical), asi que byte1 es la posicion EN VIVO de un icono que
; se desliza por el borde de pantalla (candidato: aviso de tanque/avion
; acercandose) hasta salir de rango, momento en que la ranura se limpia
; sola -- encaja con los graficos "flecha_derecha" de
; EFECTOS_DESTELLO_SEQ_A.
TABLA_PISTAS_TANQUE_AVION:
    DB $00,$00,$00,$00,$00,$00                   ; $6041-$6046
    DB $00,$00,$00,$00                           ; $6047-$604A, sin identificar
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $604B-$6054
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; $6055-$605F, sin identificar
    JP ENTRADA_INTERRUPCION_VBLANK
; ==============================================================
;  ENLACE_MOTOR_MOVIMIENTO_COLISION: NO es solo un stub -- el "JR MOTOR_MOVIMIENTO_COLISION" salta por
;  encima de 104 bytes ($6065-$60CC) que el desensamblado mecanico
;  mostraba como instrucciones sin sentido, pero que en realidad son
;  3 TABLAS DE DATOS REALES, activamente leidas desde otras partes del
;  fichero (CONFIRMADO, sesion 27, no solo hipotesis -- hay LD HL con
;  estas direcciones exactas en varias rutinas alejadas de aqui, ver
;  detalle de cada tabla mas abajo, ademas de la propia MOTOR_MOVIMIENTO_COLISION un
;  poco mas abajo). Mismo patron que las tablas de la portada o la
;  zona de variables tras MOTOR_INICIO: un JR/JP que rodea datos
;  incrustados entre rutinas, no relleno ni codigo muerto. (Descartada
;  una pista falsa: un "LD SP,$6094" que aparece muy lejos, cerca de
;  $C4E7, es pura coincidencia de bytes dentro de una zona de datos
;  sin relacion -- no es un lector real de esta tabla via POP.)
;
;  Reconstruido el mecanismo completo cruzando todos sus lectores.
;
;  CONFIRMADO EN SESION 36: las 3 tablas (96 bytes en total) son
;  IDENTICAS BYTE A BYTE a su equivalente en MSX (madmix_scr_body.asm,
;  0x2C38-0x2C9C) -- mismo hallazgo que ya se vio con los graficos de
;  sprites en sesion 30: MSX copio estos datos tal cual del original
;  Spectrum. Renombradas con los mismos nombres EXACTOS que MSX (antes
;  TABLA_RESOLVER_DIRECCION/PUNTEROS_ANIMACION_COMECOCOS/
;  ANIMACION_COMECOCOS_0..3, nombres propios de Spectrum de sesiones
;  22-27) -- ver FINDINGS.md sesion 36 para el detalle completo.
;
;  1. TABLA_CLASE_ALINEAMIENTO (16 bytes, $6065): indexada
;     por una mascara de 4 bits (entrada de LEER_ENTRADA con varias
;     teclas posibles pulsadas a la vez, AND $0F) -- resuelve a UN
;     estado final 0-4 (0=ninguna direccion, 1-4=cuatro direcciones).
;     Nombre y contenido EXACTOS de MSX; alli clasifica la "clase de
;     alineamiento" sub-loseta (nibble bajo de la posicion), semantica
;     mas precisa que la hipotesis original de Spectrum. COMPARTIDA:
;     CONFIRMADO (sesion 35) que tambien la usa
;     MOTOR_MOVIMIENTO_ITEM ($81BC, acceso a registro de actor
;     via IX+2..+5), la logica de movimiento de HNDLR_PELMAZOIDE
;     (mismo nombre EXACTO que MSX, $8142 -- confirmado con 3
;     llamadores reales: CALL Z,HNDLR_PELMAZOIDE justo despues de
;     GESTIONAR_SCROLL, junto a otras 2 llamadas candidatas a
;     HNDLR_MARICOCO/HNDLR_REGPUNANTOSO en $83ED/$8504, igual que en
;     MSX). Compara la posicion del fantasma contra PUNTO_REFERENCIA_CAMARA
;     ($6032, mismo nombre EXACTO que MSX desde sesion 37, calculada
;     como $6016+16,+24) y
;     resuelve una mascara de 4 bits de direcciones libres/preferidas
;     de la misma forma que para el jugador -- de ahi que esta tabla
;     NO lleve "_COMECOCOS" en el nombre, a diferencia de las 2 tablas
;     siguientes que si son especificas del sprite del jugador. Ver
;     FINDINGS.md sesion 35 para el detalle completo del hallazgo.
;
;  2. PUNTEROS_SUBTABLA_DIRECCION (4 punteros, $6075): CORREGIDO en
;     sesion 36 -- la sesion 22 penso que E (0-3) salia siempre de
;     MODO_ESPECIAL_CUENTA_ATRAS, pero eso solo es cierto cuando
;     MODO_ESPECIAL_ACTIVO!=0 (rama TICK_MODO_ESPECIAL, E=MODO_ESPECIAL AND $07).
;     PRECISADO en sesion 37: en el caso normal (sin modo especial), la
;     ejecucion no fija E aqui mismo -- salta via JP (IX) a un manejador
;     de loseta (IX cargado de TABLA_MANEJADORES_LOSETA, $6266,
;     despachador POR TIPO DE LOSETA de MOTOR_MOVIMIENTO_COLISION, mismo
;     nombre EXACTO que MSX -- alli 20 entradas; en Spectrum sin
;     extraer/etiquetar todavia). Es ESE manejador (en algun punto de la
;     zona mecanica sin analizar) el que termina fijando E=direccion
;     final antes de llegar aqui -- mismo mecanismo general que en MSX,
;     donde OBTENER_SUBTABLA_DIRECCION recibe "E = direccion final" ya
;     calculada por el manejador de turno. Apunta a 1 de los 4 bloques
;     SUBTABLA_DIRECCION_A..D.
;
;  3. Los 4 bloques SUBTABLA_DIRECCION_A..D (20 bytes cada uno):
;     organizados en 5 grupos de 4 bytes = 5 (clase de alineamiento,
;     0-4) x 4 (fotograma rotatorio, indice INDICE_SUBTABLA_DIRECCION
;     en $6028 -- mismo nombre EXACTO que MSX -- dentro de
;     BUCLE_SUBTABLA_DIRECCION, tambien mismo nombre EXACTO que MSX,
;     instruccion a instruccion identica). Cada byte es o bien un
;     indice de sprite real, o un centinela: $FF="reintenta con el
;     siguiente fotograma" (bucle en BUCLE_SUBTABLA_DIRECCION),
;     $FE="mantiene el sprite actual sin cambiar" (freeze -- coherente
;     con que el grupo 0, "sin direccion pulsada", sea SIEMPRE
;     $FE,$FE,$FE,$FE: el personaje no anima si esta quieto, solo
;     cuando se mueve). El resultado final se guarda en
;     SELECTOR_SPRITE_COMECOCOS (GUARDAR_SELECTOR_SPRITE_COMECOCOS,
;     mismo nombre EXACTO que MSX), cuyo bit 7 luego se enmascara
;     aparte (PREPARAR_SCROLL, "AND $7F") como flag de volteo horizontal --
;     MISMO convenio de bit ya documentado para SELECTOR_SPRITE_COMECOCOS
;     en MSX. De hecho, dentro de cada bloque, el grupo 2 y el grupo 3
;     suelen ser la MISMA secuencia de fotogramas con el bit 7 puesto
;     (p.ej. bloque A: 00,01,02,01 vs 80,81,82,81) -- consistente con
;     reusar el mismo ciclo de caminar para dos direcciones opuestas,
;     volteando en vez de dibujar fotogramas nuevos.
;
;  IMPORTANTE: estas 3 tablas son INDICES/SELECTORES, no graficos --
;  el indice que producen (SELECTOR_SPRITE_COMECOCOS) se usa mas tarde
;  como indice B en MOTOR_ACTORES (RESUELTA sesion 28, ver mas abajo)
;  contra PTR_TABLA_SPRITES ($9E8E, candidato) -- ESA es la tabla real
;  de graficos de sprites, ya localizada.
; ==============================================================
; --- ENLACE_MOTOR_MOVIMIENTO_COLISION (antes ENTRADA_MOTOR_MOVIMIENTO_
; COLISION): mismo nombre EXACTO que MSX (sesion 56 continuacion 30) --
; ambas son literalmente "JR MOTOR_MOVIMIENTO_COLISION", nada mas. ---
ENLACE_MOTOR_MOVIMIENTO_COLISION:
    JR MOTOR_MOVIMIENTO_COLISION
TABLA_CLASE_ALINEAMIENTO:      ; $6065, 16 bytes
    DB 0,1,2,1,3,1,2,3,4,1,2,1,3,1,2,1
PUNTEROS_SUBTABLA_DIRECCION:      ; $6075, 4 punteros (8 bytes) --
                                        ; direcciones ABSOLUTAS (no
                                        ; desplazamientos: el codigo que
                                        ; las consume las usa tal cual,
                                        ; sin sumarles ninguna base
                                        ; despues -- a diferencia de
                                        ; TABLA_PUNTEROS_FORMAS en la
                                        ; portada, que si son relativas)
    DW SUBTABLA_DIRECCION_A
    DW SUBTABLA_DIRECCION_B
    DW SUBTABLA_DIRECCION_C
    DW SUBTABLA_DIRECCION_D
SUBTABLA_DIRECCION_A:                   ; $607D, 20 bytes = 5 grupos x 4 fotogramas
    DB $FE,$FE,$FE,$FE
    DB $00,$01,$02,$01
    DB $80,$81,$82,$81
    DB $03,$04,$05,$04
    DB $06,$06,$06,$06
SUBTABLA_DIRECCION_B:                   ; $6091, 20 bytes
    DB $FE,$FE,$FE,$FE
    DB $07,$08,$09,$08
    DB $87,$88,$89,$88
    DB $0A,$39,$0B,$39
    DB $06,$06,$06,$06
SUBTABLA_DIRECCION_C:                   ; $60A5, 20 bytes
    DB $FE,$FE,$FE,$FE
    DB $10,$11,$12,$11
    DB $90,$91,$92,$91
    DB $13,$18,$14,$18
    DB $15,$19,$16,$19
SUBTABLA_DIRECCION_D:                   ; $60B9, 20 bytes
    DB $FE,$FE,$FE,$FE
    DB $0D,$0D,$0D,$0D
    DB $8D,$8D,$8D,$8D
    DB $0E,$0E,$0E,$0E
    DB $0F,$0F,$0F,$0F
; --- MOTOR_MOVIMIENTO_COLISION: RESUELTA POR COMPLETO (sesion 37),
; mismo nombre EXACTO que MSX -- coincidencia CASI TOTAL, instruccion a
; instruccion, con MOTOR_MOVIMIENTO_COLISION de MSX
; (madmix_scr_body.asm): el preambulo entero (decide la direccion valida
; del fotograma -- entrada real via LEER_ENTRADA o guion pregrabado si
; INDICE_CICLO_NIVELES esta activo, mismo patron que el ciclador de demo
; de MSX --, aplica la mascara de alineamiento a loseta, consulta con
; CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION la loseta un paso por
; delante, y calcula el indice de tipo para el despacho via
; TABLA_MANEJADORES_LOSETA/OBTENER_MANEJADOR_LOSETA) es identico salvo
; diferencias de hardware. Este cruce confirmo de golpe ~10 variables y
; subrutinas mas: DIRECCION_DE_MOVIMIENTO ($6024),
; INDICE_CICLO_NIVELES ($8F43), DIRECCION_SIN_PROCESAR ($6029),
; POSICION_ACTUAL_CAMARA ($602A, valor inicial $1018 IDENTICO a MSX),
; DIRECCION_FORZADA ($602D), TEMPORIZADOR_DIRECCION_FORZADA ($602E),
; FLAG_DIRECCION_NUEVA ($602F), COPIA_FLAG_DIRECCION_NUEVA ($6030),
; LADO_APERTURA_TRAMPILLA ($6031), PUNTO_REFERENCIA_CAMARA ($6032,
; candidato ya visto en sesion 35 desde HNDLR_PELMAZOIDE),
; CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION (antes CODE_628E, tambien
; verificada instruccion a instruccion) y TABLA_MANEJADORES_LOSETA
; (candidata, $6266, despachador por tipo de loseta -- en MSX tiene 20
; entradas; en Spectrum sin extraer/etiquetar todavia, queda pendiente).
; Llamada desde BUSCAR_COLUMNA_HUD (sesion 22-23) y BUCLE_PRINCIPAL_JUEGO (el
; bucle principal, sesion 34). Los sub-bloques internos
; (SALTAR_A_LEER_ENTRADA, PROCESAR_DIRECCION, LIMPIAR_FLAG_DIRECCION,
; COPIAR_FLAG_DIRECCION, CALCULAR_MASCARA_ALINEAMIENTO,
; COMPROBAR_ALINEAMIENTO_Y, APLICAR_MASCARA_ALINEAMIENTO,
; FIJAR_DIRECCION_FINAL, CALCULAR_INDICE_TIPO_LOSETA,
; OBTENER_MANEJADOR_LOSETA) llevan tambien los mismos nombres EXACTOS
; que sus equivalentes MSX. Cae directamente en BUCLE_SUBTABLA_DIRECCION
; (sesion 36) para resolver el fotograma de animacion del comecocos --
; ver FINDINGS.md sesion 37 para el detalle completo. ---
; INDICE_CICLO_NIVELES ($8F43) cae dentro de la zona mecanica todavia
; sin reconstruir (0x8C1F-0x9198, ver mapa_memoria.html) -- resuelto
; con EQU (no ocupa bytes, no arriesga la estructura) en vez de forzar
; una etiqueta real dentro de un bloque sin convertir todavia.
INDICE_CICLO_NIVELES EQU $8F43
MOTOR_MOVIMIENTO_COLISION:
    LD A,(DIRECCION_DE_MOVIMIENTO)
    PUSH AF
    LD A,(INDICE_CICLO_NIVELES)                  ; candidato "modo demo activo"
    AND A
    JR Z,SALTAR_A_LEER_ENTRADA
    LD A,D                        ; entrada desde guion pregrabado (demo)
    JR PROCESAR_DIRECCION
SALTAR_A_LEER_ENTRADA:
    CALL LEER_ENTRADA
PROCESAR_DIRECCION:
    LD (DIRECCION_SIN_PROCESAR),A
    LD B,A
    AND $10
    LD HL,FLAG_DIRECCION_NUEVA
    LD C,$00
    JR Z,LIMPIAR_FLAG_DIRECCION
    LD A,(HL)
    AND A
    JR NZ,COPIAR_FLAG_DIRECCION
    LD C,$01
    LD (HL),C
    JR COPIAR_FLAG_DIRECCION
LIMPIAR_FLAG_DIRECCION:
    LD (HL),$00
COPIAR_FLAG_DIRECCION:
    INC HL
    LD (HL),C
    LD A,B
    LD BC,(POSICION_ACTUAL_CAMARA)
    CALL MAPEAR_LOSETA_RELATIVA_A_ABSOLUTA
    POP BC
    AND $0F
    LD C,A
    LD A,(DIRECCION_FORZADA)
    AND A
    JR Z,CALCULAR_MASCARA_ALINEAMIENTO
    LD C,A
CALCULAR_MASCARA_ALINEAMIENTO:
    PUSH DE
    LD A,E
    LD E,$0F
    AND $03
    JR Z,COMPROBAR_ALINEAMIENTO_Y
    LD E,$03
COMPROBAR_ALINEAMIENTO_Y:
    LD A,D
    AND $03
    JR Z,APLICAR_MASCARA_ALINEAMIENTO
    LD E,$0C
APLICAR_MASCARA_ALINEAMIENTO:
    LD A,C
    AND E
    JR NZ,FIJAR_DIRECCION_FINAL
    LD A,B
FIJAR_DIRECCION_FINAL:
    LD C,A
    LD (DIRECCION_DE_MOVIMIENTO),A
    CALL CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION
    JR NZ,CALCULAR_INDICE_TIPO_LOSETA
    LD A,B
    LD C,A
    LD (DIRECCION_DE_MOVIMIENTO),A
    CALL CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION
CALCULAR_INDICE_TIPO_LOSETA:
    ADD A,A
    PUSH HL
    LD L,A
    LD A,(MODO_ESPECIAL_ACTIVO)
    AND A
    JR Z,OBTENER_MANEJADOR_LOSETA
    LD L,$00
OBTENER_MANEJADOR_LOSETA:
    LD A,L
    LD HL,TABLA_MANEJADORES_LOSETA
    ADD A,L
    LD L,A
    LD A,H
    ADC A,$00
    LD H,A
    LD E,(HL)
    INC HL
    LD D,(HL)
    PUSH DE
    POP IX
    LD A,C
    AND $0F
    LD B,C
    LD HL,TABLA_CLASE_ALINEAMIENTO
    ADD A,L
    LD L,A
    LD C,(HL)
    POP HL
    POP DE
    LD A,(MODO_ESPECIAL_ACTIVO)
    AND A
    LD A,(MODO_ESPECIAL)
    JR NZ,TICK_MODO_ESPECIAL
    AND A
    JP (IX)
; TICK_MODO_ESPECIAL y sus 6 etiquetas internas: mismos nombres EXACTOS
; que MSX (madmix_scr_body.asm), coincidencia instruccion a instruccion.
; Con un modo especial en curso decrementa su temporizador de duracion
; (MODO_ESPECIAL_CUENTA_ATRAS) y, distinguiendo modo 1 (bola de poder)
; de modo 2 (hipopotamo) via el ID en E, actualiza el icono de HUD
; correspondiente; al llegar el temporizador a 0 apaga los flags de
; modo. DIFERENCIA con MSX: FIN_MODO_BOLA_PODER en MSX hace primero
; CALL VACIAR_CANALES_SONIDO (vacia el gestor de recursos de sonido) --
; aqui esa llamada no esta, cae directo al XOR A. Candidato a
; corroborar cuando se resuelva el subsistema de sonido (CODE_8A3F).
TICK_MODO_ESPECIAL:
    AND $07
    LD E,A
    CP $01
    JR NZ,TICK_MODO_HIPOPOTAMO
    LD HL,MODO_ESPECIAL_CUENTA_ATRAS
    DEC (HL)
    JR Z,FIN_MODO_BOLA_PODER
    LD A,(HL)
    CP $3C
    JR NC,TICK_MODO_HIPOPOTAMO
    AND $01
    LD A,$70
    JR Z,PARPADEO_COLOR_BOLA_PODER
    LD A,(COLOR_GUARDADO)
PARPADEO_COLOR_BOLA_PODER:
    LD (COLOR_ACTUAL),A
    JR TICK_MODO_HIPOPOTAMO
FIN_MODO_BOLA_PODER:
    XOR A
    LD (MODO_ESPECIAL_FLAG),A
    LD (MODO_ESPECIAL),A
TICK_MODO_HIPOPOTAMO:
    CP $02
    JR NZ,OBTENER_SUBTABLA_DIRECCION
    LD HL,MODO_ESPECIAL_CUENTA_ATRAS
    DEC (HL)
    JR Z,FIN_MODO_HIPOPOTAMO
    LD A,(HL)
    CP $3C
    JR NC,OBTENER_SUBTABLA_DIRECCION
    AND $01
    LD A,(TABLA_POSICIONES_HUD+17)               ; RESUELTO sesion 56: antes $9E12,
                                ; "columna objetivo"/valor de icono de TABLA_POSICIONES_HUD
                                ; (mismo offset +17 que en MSX, ver BUSCAR_COLUMNA_HUD)
    JR NZ,PARPADEO_ICONO_HIPOPOTAMO
    XOR $40
PARPADEO_ICONO_HIPOPOTAMO:
    LD (REGISTRO_NIVEL_ICONO_HUD),A
    LD (COLOR_ACTUAL),A
    JR OBTENER_SUBTABLA_DIRECCION
FIN_MODO_HIPOPOTAMO:
    LD A,(COLOR_GUARDADO)
    LD (COLOR_ACTUAL),A
    XOR A
    LD (MODO_ESPECIAL_FLAG),A
    LD (MODO_ESPECIAL),A
OBTENER_SUBTABLA_DIRECCION:
    LD A,E
    ADD A,A
    LD HL,PUNTEROS_SUBTABLA_DIRECCION
    ADD A,L
    LD L,A
    LD A,H
    ADC A,$00
    LD H,A
    LD E,(HL)
    INC HL
    LD D,(HL)
BUCLE_SUBTABLA_DIRECCION:
    LD HL,INDICE_SUBTABLA_DIRECCION
    LD A,(HL)
    INC A
    AND $03
    LD (HL),A
    LD L,A
    LD A,C
    ADD A,A
    ADD A,A
    ADD A,L
    LD L,A
    LD H,$00
    ADD HL,DE
    LD A,(HL)
    CP $FF
    JR Z,BUCLE_SUBTABLA_DIRECCION
    CP $FE
    JR NZ,GUARDAR_SELECTOR_SPRITE_COMECOCOS
    LD A,(SELECTOR_SPRITE_COMECOCOS)
GUARDAR_SELECTOR_SPRITE_COMECOCOS:
    LD (SELECTOR_SPRITE_COMECOCOS),A
PREPARAR_SCROLL:
    LD D,A
    AND $7F
    LD H,B
    LD B,A
    LD A,D
    AND $80
    LD D,$38
PREPARAR_LLAMADA_SCROLL:
    LD E,$40
    LD L,A
    LD A,(MODO_ESPECIAL_ACTIVO)
    AND A
    JR Z,CONTINUAR_LLAMADA_SCROLL
    LD H,$00
CONTINUAR_LLAMADA_SCROLL:
    LD A,L
    PUSH AF
    PUSH HL
    PUSH DE
    PUSH BC
    LD A,H
    CALL GESTIONAR_SCROLL
    LD A,(FLAG_ENTRADA_BLOQUEADA)
    AND A
    PUSH AF
    CALL Z,HNDLR_PELMAZOIDE
    POP AF
    PUSH AF
    CALL Z,HNDLR_MARICOCO
    POP AF
    CALL Z,HNDLR_REGPUNANTOSO
    CALL ACTUALIZAR_DESTELLO_ITEMS
    POP BC
    POP DE
    POP HL
    POP AF
    CALL Z,MOTOR_ACTORES
; ==============================================================
;  BUCLE_PISTA_TANQUE_AVION ($6224-$6265, antes CODE_6224 y compania) --
;  RESUELTA sesion 56 tirando del hilo de CODE_61FB (ver cabecera
;  completa junto a TABLA_PISTAS_TANQUE_AVION, $6041, mas arriba).
;  Llamada cada fotograma desde BUCLE_PRINCIPAL_JUEGO. Por cada una de
;  las 3 ranuras: si esta vacia, la salta; si no, calcula la posicion
;  de pantalla (columna fija+fila variable o fila fija+columna
;  variable, segun el formato de la ranura), la RE-ESCRIBE en la
;  propia ranura ya desplazada (efecto de deslizamiento) y llama a
;  MOTOR_ACTORES con B=$1A (sprite 26) para dibujar el icono en esa
;  posicion -- si el desplazamiento se sale del rango valido, borra la
;  ranura en vez de dibujar (icono ya fuera de pantalla).
;
;  NOMBRES ALINEADOS CON MSX (sesion 56 continuacion 30): la rutina
;  completa y sus 5 etiquetas internas coinciden instruccion a
;  instruccion con BUCLE_PISTA_TANQUE_AVION de MSX
;  (madmix_scr_body.asm:693) -- PISTA_FORMATO_B/PISTA_FORMATO_B_POS/
;  PISTA_FILA_FIJA/DIBUJAR_PISTA renombradas (antes DIBUJO_FORMATO_B/
;  DIBUJO_FORMATO_B_POS/DIBUJO_FILA_FIJA/DIBUJAR_SPRITE_PISTA) con los
;  mismos nombres EXACTOS. El cierre de bucle se llama
;  SIGUIENTE_PISTA_TANQUE_AVION (antes DIBUJO_SIGUIENTE_PISTA) en vez
;  del "SIGUIENTE_PISTA" global que usa MSX ahi, porque ese nombre ya
;  lo tiene AVISAR_PROXIMIDAD_PISTA mas abajo (MSX lo resuelve con una
;  etiqueta LOCAL ".SIGUIENTE_PISTA" ahi -- convencion que este fichero
;  no usa todavia).
; ==============================================================
    LD B,$03
    LD HL,TABLA_PISTAS_TANQUE_AVION
BUCLE_PISTA_TANQUE_AVION:
    PUSH BC
    LD A,(HL)
    AND A
    JR Z,SIGUIENTE_PISTA_TANQUE_AVION
    INC HL
    LD D,(HL)
    BIT 0,D
    JR Z,PISTA_FORMATO_B
    DEC HL
    SUB $10
    LD D,A
    LD E,$40
    JR NC,DIBUJAR_PISTA
    LD (HL),$00
    JR SIGUIENTE_PISTA_TANQUE_AVION
PISTA_FORMATO_B:
    BIT 7,(HL)
    DEC HL
    JR Z,PISTA_FORMATO_B_POS
    SUB $08
    LD E,A
    CP $08
    JR NC,PISTA_FILA_FIJA
    LD (HL),$00
    JR SIGUIENTE_PISTA_TANQUE_AVION
PISTA_FORMATO_B_POS:
    ADD A,$08
    LD E,A
    CP $70
    JR C,PISTA_FILA_FIJA
    LD (HL),$00
    JR SIGUIENTE_PISTA_TANQUE_AVION
PISTA_FILA_FIJA:
    LD E,A
    LD D,$38
DIBUJAR_PISTA:
    LD (HL),A
    LD B,$1A
    XOR A
    CALL MOTOR_ACTORES
; --- SIGUIENTE_PISTA_TANQUE_AVION (antes DIBUJO_SIGUIENTE_PISTA):
; MSX llama "SIGUIENTE_PISTA" (global) a esta misma cola de bucle, pero
; ese nombre exacto ya lo usa (con razon, MSX tiene una etiqueta LOCAL
; ".SIGUIENTE_PISTA" distinta ahi) la cola de AVISAR_PROXIMIDAD_PISTA
; mas abajo -- este fichero no usa etiquetas locales con "." todavia,
; asi que se desambigua con el sufijo _TANQUE_AVION en vez de chocar. ---
SIGUIENTE_PISTA_TANQUE_AVION:
    INC HL
    INC HL
    POP BC
    DJNZ BUCLE_PISTA_TANQUE_AVION
    RET
; ==============================================================
;  TABLA_MANEJADORES_LOSETA ($6266, 20 entradas x 2 bytes = 40
;  bytes) -- RESUELTA POR COMPLETO (sesion 38), mismo nombre
;  EXACTO que MSX. Extraida directamente de FISICO/CODE.bin: 20
;  punteros validos, terminando EXACTO donde empieza
;  CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION ($628E), sin hueco
;  de por medio -- confirma el limite sin ambiguedad. Mismo orden
;  EXACTO que MSX, incluido el patron de duplicados (entradas 8
;  y 9 repiten la 0; la 16 repite la 15) que ya tiene la tabla
;  MSX -- imposible que sea casualidad. Es el despachador por
;  TIPO DE LOSETA de MOTOR_MOVIMIENTO_COLISION (JP (IX) tras
;  OBTENER_MANEJADOR_LOSETA). Las 2 primeras entradas verificadas
;  ademas instruccion a instruccion identicas a MSX
;  (HNDLR_SUELO_NORMAL, HNDLR_BOLA_PODER) -- el resto se renombra
;  por la fuerza de esta doble confirmacion (orden exacto +
;  patron de duplicados) siguiendo la convencion del proyecto.
;  Ver FINDINGS.md sesion 38 para el detalle completo.
; ==============================================================
; EVENTO_SONIDO_PENDIENTE ($8FD6) cae dentro de zona mecanica todavia
; sin reconstruir -- resuelto con EQU (sesion 39), mismo nombre EXACTO
; que MSX (indice de efecto de sonido a disparar, escrito por casi
; todos los manejadores de TABLA_MANEJADORES_LOSETA).
EVENTO_SONIDO_PENDIENTE EQU $8FD6
TABLA_MANEJADORES_LOSETA:
    DW HNDLR_SUELO_NORMAL
    DW HNDLR_BOLITA_NORMAL
    DW HNDLR_BOLITA_CLAVADA
    DW HNDLR_AUTOCOCO_ARRIBA
    DW HNDLR_AUTOCOCO_ABAJO
    DW HNDLR_AUTOCOCO_IZQUIERDA
    DW HNDLR_AUTOCOCO_DERECHA
    DW HNDLR_PISTA_COCOTANQUE
    DW HNDLR_SUELO_NORMAL
    DW HNDLR_SUELO_NORMAL
    DW HNDLR_PISTA_COCONAVE
    DW HNDLR_ITEM_SUELO
    DW HNDLR_BOLA_PODER
    DW HNDLR_HIPODOSO
    DW HNDLR_EXCAVATOFONO
    DW HNDLR_SUELO_SIN_BOLA
    DW HNDLR_SUELO_SIN_BOLA
    DW HNDLR_TRAMPILLA_ABIERTA_DERECHA
    DW HNDLR_TRAMPILLA_ABIERTA_IZQUIERDA
    DW HNDLR_TRAMPILLA_CERRADA
; CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION: las 5 etiquetas internas
; RESUELTAS POR COMPLETO (sesion 48), mismos nombres EXACTOS que MSX
; (madmix_scr_body.asm:771) -- coincidencia instruccion a instruccion
; total, incluido el orden de bits: bit0=DERECHA (C+=4), bit1=IZQUIERDA
; (DEC C), bit2=ABAJO (B+=4), bit3=ARRIBA (DEC B). Curiosidad: este
; orden es DISTINTO al de DECIDIR_DIRECCION_SCROLL en GESTIONAR_SCROLL
; (sesion 45, alli bit0=DERECHA/bit1=IZQUIERDA/bit2=ABAJO/bit3=ARRIBA
; tambien -- pero el DE MSX en GESTIONAR_SCROLL usa
; ARRIBA/ABAJO/DERECHA/IZQUIERDA). Es decir: MSX usa 2 ordenes de bits
; distintos en 2 rutinas distintas de su propio motor, y esta rutina
; en concreto coincide EXACTO con Spectrum en las 2 versiones -- mas
; confirmacion de que el orden de bits es una decision local de cada
; rutina/subsistema, no una convencion global de la plataforma (ver
; FINDINGS.md sesion 45 y 48).
CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION:
    PUSH BC
    LD BC,(POSICION_ACTUAL_CAMARA)
    RRA
    JR NC,COMPROBAR_LOSETA_IZQUIERDA
    LD A,C
    ADD A,$04                    ; derecha: +1 columna (4 = paso de una loseta en esta unidad)
    LD C,A
    JR IDENTIFICAR_PROXIMA_LOSETA
COMPROBAR_LOSETA_IZQUIERDA:
    RRA
    JR NC,COMPROBAR_LOSETA_ABAJO
    DEC C                         ; izquierda: -1 columna
    JR IDENTIFICAR_PROXIMA_LOSETA
COMPROBAR_LOSETA_ABAJO:
    RRA
    JR NC,COMPROBAR_LOSETA_ARRIBA
    LD A,B
    ADD A,$04                    ; abajo: +1 fila
    LD B,A
    JR IDENTIFICAR_PROXIMA_LOSETA
COMPROBAR_LOSETA_ARRIBA:
    RRA
    JR NC,IDENTIFICAR_PROXIMA_LOSETA
    DEC B                         ; arriba: -1 fila
IDENTIFICAR_PROXIMA_LOSETA:
    CALL MAPEAR_LOSETA_RELATIVA_A_ABSOLUTA
    LD A,(CACHE_COLUMNA_LOSETA)
    CP L
    LD A,(CACHE_TIPO_LOSETA)
    JR Z,ENMASCARAR_TIPO_LOSETA
    LD A,L
    LD (CACHE_COLUMNA_LOSETA),A
    CALL CONSULTAR_TIPO_LOSETA
    LD (CACHE_TIPO_LOSETA),A
ENMASCARAR_TIPO_LOSETA:
    AND $1F
    POP BC
    RET
; DIBUJAR_CAMBIO_LOSETA: sus 2 etiquetas internas RESUELTAS POR
; COMPLETO (sesion 49), mismos nombres EXACTOS que MSX
; (madmix_scr_body.asm:813) -- coincidencia instruccion a instruccion
; total. Escribe A en (HL), ajusta BC segun el caso (bordes de franja:
; C original=4 -> 1 fila menos; C original=2 -> 1 columna menos) y
; llama a REDIBUJAR_LOSETA_BUFFER_VRAM.
DIBUJAR_CAMBIO_LOSETA:
    PUSH BC
    LD (HL),A
    LD B,A
    PUSH BC
    LD A,C
    LD BC,$0406                  ; BC = tamano de franja por defecto (4 filas x 6 columnas)
    CP $04
    JR NZ,DIBUJAR_CAMBIO_LOSETA_CHECK_COL
    DEC B
DIBUJAR_CAMBIO_LOSETA_CHECK_COL:
    CP $02
    JR NZ,DIBUJAR_CAMBIO_LOSETA_REDRAW
    DEC C
DIBUJAR_CAMBIO_LOSETA_REDRAW:
    POP AF
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    POP BC
    RET
HNDLR_SUELO_NORMAL:                          ; $62E1, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    CP $02
    JR NZ,HNDLR_SUELO_NORMAL_CONT
    LD C,$00
HNDLR_SUELO_NORMAL_CONT:
    LD B,$00
    CP $09
    JP Z,MODO_ESPECIAL_EXIT_TAIL
    JP TICK_MODO_ESPECIAL
HNDLR_BOLITA_NORMAL:                          ; $62F1, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    PUSH BC
    PUSH AF
    CP $02
    JR NC,HNDLR_BOLITA_NORMAL_EXIT
    LD A,D
    OR E
    AND $03
    CP $02
    JR NZ,HNDLR_BOLITA_NORMAL_EXIT
    LD A,$0F
    LD (CACHE_TIPO_LOSETA),A
    XOR A
    LD (EVENTO_SONIDO_PENDIENTE),A
    LD A,(HL)
    LD A,(REGISTRO_NIVEL_LOSETA_COMODIN)
    OR $80
    CALL DIBUJAR_CAMBIO_LOSETA
    PUSH HL
    LD HL,$0001
    CALL DIBUJAR_MARCADOR_PUNTOS
    LD HL,(CONTADOR_BOLAS_COMIDAS)
    INC HL
    LD (CONTADOR_BOLAS_COMIDAS),HL
    POP HL
HNDLR_BOLITA_NORMAL_EXIT:
    POP AF
    POP BC
    JP TICK_MODO_ESPECIAL
HNDLR_BOLITA_CLAVADA:                          ; $6325, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    CP $03
    PUSH AF
    JR NZ,HNDLR_BOLITA_CLAVADA_EXIT
    LD A,D
    OR E
    AND $03
    CP $02
    JR NZ,HNDLR_BOLITA_CLAVADA_EXIT
    LD A,$01
    LD (EVENTO_SONIDO_PENDIENTE),A
    LD A,(HL)
    SUB $03
    CALL DIBUJAR_CAMBIO_LOSETA
HNDLR_BOLITA_CLAVADA_EXIT:
    POP AF
    JP TICK_MODO_ESPECIAL
HNDLR_AUTOCOCO_ARRIBA:                          ; $6341, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    PUSH AF
    CP $02
    JR NC,HNDLR_AUTOCOCO_ARRIBA_EXIT
    LD A,D
    OR E
    AND $03
    CP $02
    JR NZ,HNDLR_AUTOCOCO_ARRIBA_EXIT
    BIT 2,B
    LD A,B
    LD B,$00
    JR NZ,HNDLR_AUTOCOCO_ARRIBA_EXIT
    LD B,A
    LD A,$02
    LD (EVENTO_SONIDO_PENDIENTE),A
    LD A,(REGISTRO_NIVEL_LOSETA_COMODIN)
    CALL DIBUJAR_CAMBIO_LOSETA
    LD A,$08
    LD (DIRECCION_FORZADA),A
    PUSH HL
    LD HL,$0002
    CALL DIBUJAR_MARCADOR_PUNTOS
    LD HL,(CONTADOR_BOLAS_COMIDAS)
    INC HL
    LD (CONTADOR_BOLAS_COMIDAS),HL
    POP HL
HNDLR_AUTOCOCO_ARRIBA_EXIT:
    POP AF
    JP TICK_MODO_ESPECIAL
HNDLR_AUTOCOCO_ABAJO:                          ; $6379, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    PUSH AF
    CP $02
    JR NC,HNDLR_AUTOCOCO_ABAJO_EXIT
    LD A,D
    OR E
    AND $03
    CP $02
    JR NZ,HNDLR_AUTOCOCO_ABAJO_EXIT
    BIT 3,B
    LD A,B
    LD B,$00
    JR NZ,HNDLR_AUTOCOCO_ABAJO_EXIT
    LD B,A
    LD A,$02
    LD (EVENTO_SONIDO_PENDIENTE),A
    LD A,(REGISTRO_NIVEL_LOSETA_COMODIN)
    CALL DIBUJAR_CAMBIO_LOSETA
    LD A,$04
    LD (DIRECCION_FORZADA),A
    PUSH HL
    LD HL,$0002
    CALL DIBUJAR_MARCADOR_PUNTOS
    LD HL,(CONTADOR_BOLAS_COMIDAS)
    INC HL
    LD (CONTADOR_BOLAS_COMIDAS),HL
    POP HL
HNDLR_AUTOCOCO_ABAJO_EXIT:
    POP AF
    JP TICK_MODO_ESPECIAL
HNDLR_AUTOCOCO_IZQUIERDA:                          ; $63B1, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    PUSH AF
    CP $02
    JR NC,HNDLR_AUTOCOCO_IZQUIERDA_EXIT
    LD A,D
    OR E
    AND $03
    CP $02
    JR NZ,HNDLR_AUTOCOCO_IZQUIERDA_EXIT
    LD A,B
    BIT 0,B
    LD B,$00
    JR NZ,HNDLR_AUTOCOCO_IZQUIERDA_EXIT
    LD B,A
    LD A,$02
    LD (EVENTO_SONIDO_PENDIENTE),A
    LD A,(REGISTRO_NIVEL_LOSETA_COMODIN)
    CALL DIBUJAR_CAMBIO_LOSETA
    LD A,$02
    LD (DIRECCION_FORZADA),A
    PUSH HL
    LD HL,$0002
    CALL DIBUJAR_MARCADOR_PUNTOS
    LD HL,(CONTADOR_BOLAS_COMIDAS)
    INC HL
    LD (CONTADOR_BOLAS_COMIDAS),HL
    POP HL
HNDLR_AUTOCOCO_IZQUIERDA_EXIT:
    POP AF
    JP TICK_MODO_ESPECIAL
HNDLR_AUTOCOCO_DERECHA:                          ; $63E9, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    PUSH AF
    CP $02
    JR NC,HNDLR_AUTOCOCO_DERECHA_EXIT
    LD A,D
    OR E
    AND $03
    CP $02
    JR NZ,HNDLR_AUTOCOCO_DERECHA_EXIT
    LD A,B
    BIT 1,B
    LD B,$00
    JR NZ,HNDLR_AUTOCOCO_DERECHA_EXIT
    LD B,A
    LD A,$02
    LD (EVENTO_SONIDO_PENDIENTE),A
    LD A,(REGISTRO_NIVEL_LOSETA_COMODIN)
    CALL DIBUJAR_CAMBIO_LOSETA
    LD A,$01
    LD (DIRECCION_FORZADA),A
    PUSH HL
    LD HL,$0002
    CALL DIBUJAR_MARCADOR_PUNTOS
    LD HL,(CONTADOR_BOLAS_COMIDAS)
    INC HL
    LD (CONTADOR_BOLAS_COMIDAS),HL
    POP HL
HNDLR_AUTOCOCO_DERECHA_EXIT:
    POP AF
    JP TICK_MODO_ESPECIAL
HNDLR_PISTA_COCOTANQUE:                          ; $6421, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    PUSH AF
    JR NZ,HNDLR_PISTA_COCOTANQUE_MODE_CHECK
    BIT 3,B
    JR Z,HNDLR_PISTA_COCOTANQUE_ACTIVATE
    RES 3,B
    POP AF
    JP TICK_MODO_ESPECIAL
HNDLR_PISTA_COCOTANQUE_MODE_CHECK:
    CP $08
    JR Z,HNDLR_PISTA_COCOTANQUE_TAIL
    POP AF
    JP TICK_MODO_ESPECIAL
HNDLR_PISTA_COCOTANQUE_ACTIVATE:
    LD A,$03
    LD (EVENTO_SONIDO_PENDIENTE),A
    LD A,(COLOR_ACTUAL)
    LD (COLOR_GUARDADO),A
    LD (TABLA_POSICIONES_HUD+18),A               ; RESUELTO sesion 56: antes $9E13,
                                ; guarda COLOR_ACTUAL para restaurar (mismo offset
                                ; +18 que MSX, ver DESTELLO_ICONO_COLOR_HUD)
    LD A,(REGISTRO_NIVEL_ICONO_HUD)
    LD (COLOR_ACTUAL),A
    LD A,$01
    LD (MODO_ESPECIAL_FLAG),A
    LD A,$08
    LD (MODO_ESPECIAL),A
HNDLR_PISTA_COCOTANQUE_TAIL:
    POP AF
    LD A,(DIRECCION_SIN_PROCESAR)
    AND $02
    RRCA
    RRCA
    LD D,A
    LD A,(COPIA_FLAG_DIRECCION_NUEVA)
    AND A
    CALL NZ,REGISTRAR_PISTA_TANQUE_AVION
    LD B,$04
    LD A,D
    OR $17
    JP PREPARAR_SCROLL
REGISTRAR_PISTA_TANQUE_AVION:
    LD B,$03
    LD HL,TABLA_PISTAS_TANQUE_AVION
BUSCAR_HUECO_PISTA:
    LD A,(HL)
    AND A
    JR Z,FIJAR_PISTA
    INC HL
    INC HL
    DJNZ BUSCAR_HUECO_PISTA
    RET
FIJAR_PISTA:
    BIT 0,D
    LD (HL),$68
    JR NZ,GUARDAR_PISTA
    BIT 7,D
    LD (HL),$40
    JR NZ,GUARDAR_PISTA
    LD (HL),$40
GUARDAR_PISTA:
    INC HL
    LD (HL),D
    LD A,$04
    LD (EVENTO_SONIDO_PENDIENTE),A
    RET
HNDLR_PISTA_COCONAVE:                          ; $6490, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    JR Z,HNDLR_PISTA_COCONAVE_ACTIVATE
    CP $09
    JR Z,MODO_ESPECIAL_EXIT_TAIL
    JP TICK_MODO_ESPECIAL
HNDLR_PISTA_COCONAVE_ACTIVATE:
    LD A,E
    AND $03
    LD A,$00
    JP NZ,TICK_MODO_ESPECIAL
    LD A,$09
    LD (MODO_ESPECIAL),A
    LD A,$01
    LD (MODO_ESPECIAL_FLAG),A
    LD A,(COLOR_ACTUAL)
    LD (COLOR_GUARDADO),A
    LD A,(REGISTRO_NIVEL_ICONO_HUD)
    LD (COLOR_ACTUAL),A
    LD BC,$1C18
    LD (POSICION_ACTUAL_CAMARA),BC
    LD B,$0C
    LD D,$38
    LD E,$40
HNDLR_PISTA_COCONAVE_LOOP:
    PUSH BC
    PUSH DE
    LD H,$08
    POP DE
    LD A,D
    ADD A,$04
    LD D,A
    LD B,$05
    XOR A
    PUSH AF
    PUSH HL
    PUSH DE
    PUSH BC
    LD A,H
    CALL GESTIONAR_SCROLL
    LD A,(FLAG_ENTRADA_BLOQUEADA)
    AND A
    PUSH AF
    CALL Z,HNDLR_PELMAZOIDE
    POP AF
    PUSH AF
    CALL Z,HNDLR_MARICOCO
    POP AF
    CALL Z,HNDLR_REGPUNANTOSO
    CALL ACTUALIZAR_DESTELLO_ITEMS
    POP BC
    POP DE
    POP HL
    POP AF
    CALL Z,MOTOR_ACTORES
    CALL WAIT_VBLANK
    POP BC
    DJNZ HNDLR_PISTA_COCONAVE_LOOP
    LD A,$03
    LD (EVENTO_SONIDO_PENDIENTE),A
MODO_ESPECIAL_EXIT_TAIL:
    LD A,B
    AND $02
    RRCA
    RRCA
    LD D,A
    LD A,(COPIA_FLAG_DIRECCION_NUEVA)
    AND A
    LD H,B
    JR Z,MODO_ESPECIAL_EXIT_REENTER
    SET 0,D
    PUSH HL
    CALL REGISTRAR_PISTA_TANQUE_AVION
    POP HL
    RES 0,D
MODO_ESPECIAL_EXIT_REENTER:
    LD A,D
    LD B,$0C
    LD D,$68
    JP PREPARAR_LLAMADA_SCROLL
HNDLR_ITEM_SUELO:                          ; $651C, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    PUSH AF
    JR Z,HNDLR_ITEM_SUELO_EXIT
    LD A,D
    OR E
    AND $03
    CP $02
    JR NZ,HNDLR_ITEM_SUELO_EXIT
    LD A,$03
    LD (EVENTO_SONIDO_PENDIENTE),A
    LD A,$78
    LD (COLOR_ACTUAL),A
    XOR A
    LD (MODO_ESPECIAL_FLAG),A
    LD (MODO_ESPECIAL),A
    POP AF
    PUSH AF
    ADD A,$3B
    CALL DIBUJAR_CAMBIO_LOSETA
HNDLR_ITEM_SUELO_EXIT:
    POP AF
    JP TICK_MODO_ESPECIAL
HNDLR_BOLA_PODER:                          ; $6543, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    PUSH AF
    JR NZ,HNDLR_BOLA_PODER_EXIT
    LD A,D
    OR E
    AND $03
    CP $02
    JR NZ,HNDLR_BOLA_PODER_EXIT
    LD A,$03
    LD (EVENTO_SONIDO_PENDIENTE),A
    LD A,$01
    LD (MODO_ESPECIAL_FLAG),A
    LD A,(REGISTRO_NIVEL_DURACION_PARPADEO)
    LD (MODO_ESPECIAL_CUENTA_ATRAS),A
    LD A,(COLOR_ACTUAL)
    LD (COLOR_GUARDADO),A
    LD A,$70
    LD (COLOR_ACTUAL),A
    LD A,$01
    LD (MODO_ESPECIAL),A
    LD A,(REGISTRO_NIVEL_LOSETA_COMODIN)
    CALL DIBUJAR_CAMBIO_LOSETA
    PUSH HL
    LD HL,$0002
    CALL DIBUJAR_MARCADOR_PUNTOS
    POP HL
HNDLR_BOLA_PODER_EXIT:
    POP AF
    JP TICK_MODO_ESPECIAL
HNDLR_HIPODOSO:                          ; $6580, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    PUSH AF
    JR NZ,HNDLR_HIPODOSO_EXIT
    LD A,D
    OR E
    AND $03
    CP $02
    JR NZ,HNDLR_HIPODOSO_EXIT
    LD A,$03
    LD (EVENTO_SONIDO_PENDIENTE),A
    LD A,(REGISTRO_NIVEL_DURACION_PARPADEO)
    LD (MODO_ESPECIAL_CUENTA_ATRAS),A
    LD A,(COLOR_ACTUAL)
    LD (COLOR_GUARDADO),A
    LD A,(REGISTRO_NIVEL_ICONO_HUD)
    LD (COLOR_ACTUAL),A
    LD A,$02
    LD (MODO_ESPECIAL),A
    LD A,(REGISTRO_NIVEL_LOSETA_COMODIN)
    CALL DIBUJAR_CAMBIO_LOSETA
HNDLR_HIPODOSO_EXIT:
    POP AF
    JP TICK_MODO_ESPECIAL
HNDLR_EXCAVATOFONO:                          ; $65B1, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    PUSH AF
    JR NZ,HNDLR_EXCAVATOFONO_EXIT
    LD A,D
    OR E
    AND $03
    CP $02
    JR NZ,HNDLR_EXCAVATOFONO_EXIT
    LD A,$03
    LD (EVENTO_SONIDO_PENDIENTE),A
    LD A,(COLOR_ACTUAL)
    LD (COLOR_GUARDADO),A
    LD A,$68
    LD (COLOR_ACTUAL),A
    LD A,$03
    LD (MODO_ESPECIAL),A
    LD A,$3B
    CALL DIBUJAR_CAMBIO_LOSETA
HNDLR_EXCAVATOFONO_EXIT:
    POP AF
    JP TICK_MODO_ESPECIAL
HNDLR_SUELO_SIN_BOLA:                          ; $65DA, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    PUSH BC
    PUSH AF
    JP Z,TEMPORIZADOR_DIRECCION_FORZADA_TICK
    CP $08
    JR NZ,HNDLR_SUELO_SIN_BOLA_PLANE_CHECK
    LD A,$03
    LD (EVENTO_SONIDO_PENDIENTE),A
    LD A,(COLOR_GUARDADO)
    LD (COLOR_ACTUAL),A
    XOR A
    LD (MODO_ESPECIAL),A
    LD (MODO_ESPECIAL_FLAG),A
    CALL INICIALIZAR_PARCIAL_ITEMS_NIVEL
    JR TEMPORIZADOR_DIRECCION_FORZADA_TICK
HNDLR_SUELO_SIN_BOLA_PLANE_CHECK:
    CP $09
    JR NZ,TEMPORIZADOR_DIRECCION_FORZADA_TICK
    LD A,E
    AND $03
    JR NZ,TEMPORIZADOR_DIRECCION_FORZADA_TICK
    XOR A
    LD (MODO_ESPECIAL_FLAG),A
    LD B,$0C
    LD D,$68
    LD E,$40
HNDLR_SUELO_SIN_BOLA_PLANE_LOOP:
    PUSH BC
    PUSH DE
    LD H,$04
    POP DE
    LD A,D
    ADD A,$FC
    LD D,A
    LD B,$06
    XOR A
    PUSH AF
    PUSH HL
    PUSH DE
    PUSH BC
    LD A,H
    CALL GESTIONAR_SCROLL
    LD A,(FLAG_ENTRADA_BLOQUEADA)
    AND A
    PUSH AF
    CALL Z,HNDLR_PELMAZOIDE
    POP AF
    PUSH AF
    CALL Z,HNDLR_MARICOCO
    POP AF
    CALL Z,HNDLR_REGPUNANTOSO
    CALL ACTUALIZAR_DESTELLO_ITEMS
    POP BC
    POP DE
    POP HL
    POP AF
    CALL Z,MOTOR_ACTORES
    CALL WAIT_VBLANK
    POP BC
    DJNZ HNDLR_SUELO_SIN_BOLA_PLANE_LOOP
    CALL INICIALIZAR_PARCIAL_ITEMS_NIVEL
    LD A,$03
    LD (EVENTO_SONIDO_PENDIENTE),A
    XOR A
    LD (MODO_ESPECIAL),A
    LD A,(COLOR_GUARDADO)
    LD (COLOR_ACTUAL),A
    LD BC,$1018
    LD (POSICION_ACTUAL_CAMARA),BC
    JR TEMPORIZADOR_DIRECCION_FORZADA_TICK
TEMPORIZADOR_DIRECCION_FORZADA_TICK:
    PUSH HL
    LD HL,TEMPORIZADOR_DIRECCION_FORZADA
    LD A,(HL)
    AND A
    JR Z,LIMPIAR_DIRECCION_FORZADA
    DEC (HL)
    JR FIN_TICK_DIRECCION_FORZADA
LIMPIAR_DIRECCION_FORZADA:
    LD (DIRECCION_FORZADA),A
    XOR A
    LD (LADO_APERTURA_TRAMPILLA),A
FIN_TICK_DIRECCION_FORZADA:
    POP HL
    POP AF
    POP BC
    JP TICK_MODO_ESPECIAL
HNDLR_TRAMPILLA_ABIERTA_DERECHA:                          ; $6675, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    PUSH AF
    LD A,$02
    LD (DIRECCION_FORZADA),A
    LD (LADO_APERTURA_TRAMPILLA),A
    LD A,E
    AND $03
    CP $02
    JR NZ,FIN_ANIMACION_TRAMPILLA
    LD A,$09
    LD (EVENTO_SONIDO_PENDIENTE),A
    PUSH HL
    PUSH BC
    LD A,$4F
    LD (HL),A
    LD BC,$0405
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    DEC HL
    LD A,$4E
    LD BC,$0404
    LD (HL),A
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    LD BC,$FFE0
    ADD HL,BC
    LD A,$4C
    LD (HL),A
    LD BC,$0304
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    INC HL
    LD A,$4D
    LD (HL),A
    LD BC,$0305
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    POP BC
    POP HL
FIN_ANIMACION_TRAMPILLA:
    POP AF
    JP TICK_MODO_ESPECIAL
HNDLR_TRAMPILLA_ABIERTA_IZQUIERDA:                          ; $66BC, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    PUSH AF
    LD A,(DIRECCION_FORZADA)
    AND A
    LD A,$01
    LD (DIRECCION_FORZADA),A
    LD (LADO_APERTURA_TRAMPILLA),A
    LD A,E
    AND $03
    CP $02
    JR NZ,FIN_ANIMACION_TRAMPILLA
    LD A,$09
    LD (EVENTO_SONIDO_PENDIENTE),A
    PUSH HL
    LD A,$4E
    LD (HL),A
    LD BC,$0406
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    INC HL
    LD A,$4F
    LD BC,$0407
    LD (HL),A
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    LD BC,$FFE0
    ADD HL,BC
    LD A,$4D
    LD (HL),A
    LD BC,$0307
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    DEC HL
    LD A,$4C
    LD (HL),A
    LD BC,$0306
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    POP HL
    LD B,$01
    JR FIN_ANIMACION_TRAMPILLA
HNDLR_TRAMPILLA_CERRADA:                          ; $6705, mismo nombre EXACTO que MSX (TABLA_MANEJADORES_LOSETA, sesion 38)
    PUSH AF
    LD A,(LADO_APERTURA_TRAMPILLA)
    LD B,A
    LD A,E
    AND $03
    CP $02
    JR NZ,FIN_ANIMACION_TRAMPILLA
    LD A,$03
    LD (TEMPORIZADOR_DIRECCION_FORZADA),A
    LD A,B
    CP $02
    JR Z,HNDLR_TRAMPILLA_CERRADA_B
    PUSH HL
    LD A,$44
    LD BC,$0406
    LD (HL),A
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    DEC HL
    LD A,$43
    LD BC,$0405
    LD (HL),A
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    LD BC,$FFE0
    ADD HL,BC
    LD A,$4A
    LD (HL),A
    LD BC,$0305
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    INC HL
    LD A,$4B
    LD (HL),A
    LD BC,$0306
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    LD B,$01
    POP HL
    POP AF
    JP TICK_MODO_ESPECIAL
HNDLR_TRAMPILLA_CERRADA_B:
    PUSH HL
    LD A,$49
    LD BC,$0405
    LD (HL),A
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    INC HL
    LD A,$45
    LD BC,$0406
    LD (HL),A
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    LD BC,$FFE0
    ADD HL,BC
    LD A,$48
    LD (HL),A
    LD BC,$0306
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    DEC HL
    LD A,$47
    LD (HL),A
    LD BC,$0305
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    POP HL
    LD B,$02
    POP AF
    JP TICK_MODO_ESPECIAL
; ==============================================================
;  $677F-$8141 (6595 bytes) -- CORRECCION DE ALCANCE (sesion 49):
;  la sesion 39 declaro "RESUELTOS POR COMPLETO" los 7777 bytes
;  de $62E1-$8142 (TABLA_MANEJADORES_LOSETA + los 17 manejadores),
;  pero en realidad solo los primeros 1182 bytes ($62E1-$677E, los
;  17 manejadores en si, terminando en HNDLR_TRAMPILLA_CERRADA_B)
;  se convirtieron linea a linea de verdad. Este tramo (6595
;  bytes) se quedo con desensamblado mecanico de primera pasada
;  (instrucciones falsas plausibles pero nunca alcanzables) sin
;  que nadie lo notara -- descubierto al pedir el usuario nombrar
;  CODE_67A6 y sucesivas. Volcado aqui como DB crudo, honesto
;  sobre que sigue sin analizar. Candidato a contener mas
;  subsistemas de items/manejadores todavia sin identificar
;  entre aqui y HNDLR_PELMAZOIDE ($8142). Unica referencia
;  externa detectada: CODE_8005, resuelta con EQU. Ver
;  FINDINGS.md sesion 49.
; ==============================================================
CODE_8005 EQU $8005
; ==============================================================
;  DATOS DE NIVEL ($677F-$805F, 6369 bytes) -- RESUELTOS POR
;  COMPLETO (sesion 50): son los CUERPO_Lxx/CABECERA que
;  TABLA_NIVELES referencia por puntero (sesion 47). Localizados
;  cruzando los 3 punteros de cada uno de los 16 registros de
;  TABLA_NIVELES contra estas direcciones: encajan EXACTOS y sin
;  hueco (arranca cada bloque justo donde termina el anterior,
;  usando filas_variable*32 bytes por cuerpo, 96 por cabecera),
;  terminando el ultimo EXACTO en TABLA_ITEMS_PELMAZOIDE
;  ($8060) -- mismo patron de verificacion por aritmetica que
;  el resto de tablas de esta sesion. Nombres CUERPO_Lxx/
;  CABECERA_xxxx en el mismo espiritu que MSX (que nombra sus
;  cabeceras compartidas por direccion, ej. CABECERA_50BC).
;  4 de los 16 niveles (11-14) usan cuerpos en $D160+, fuera de
;  este rango -- dentro del tramo mecanico de sesion 44,
;  pendiente de relabeling con nombres CUERPO_L11..L14. Datos
;  en si (contenido del laberinto) sin decodificar tile a tile
;  todavia. Ver FINDINGS.md sesion 50.
; ==============================================================
CUERPO_L01:  ; $677F, 704 bytes -- nivel 1 (y nivel 0 duplicado -- registro muerto)
    INCBIN "data/niveles/body_l01.bin"
CUERPO_L02:  ; $6A3F, 480 bytes -- nivel 2
    INCBIN "data/niveles/body_l2.bin"
CUERPO_L03:  ; $6C1F, 512 bytes -- nivel 3
    INCBIN "data/niveles/body_l3.bin"
CUERPO_L09:  ; $6E1F, 576 bytes -- nivel 9
    INCBIN "data/niveles/body_l9.bin"
CUERPO_L05:  ; $705F, 512 bytes -- nivel 5
    INCBIN "data/niveles/body_l5.bin"
CUERPO_L06:  ; $725F, 576 bytes -- nivel 6
    INCBIN "data/niveles/body_l6.bin"
CUERPO_L04:  ; $749F, 480 bytes -- nivel 4
    INCBIN "data/niveles/body_l4.bin"
CUERPO_L08:  ; $767F, 480 bytes -- nivel 8
    INCBIN "data/niveles/body_l8.bin"
CUERPO_L07:  ; $785F, 608 bytes -- nivel 7
    INCBIN "data/niveles/body_l7.bin"
CUERPO_L10:  ; $7ABF, 544 bytes -- nivel 10
    INCBIN "data/niveles/body_l10.bin"
CUERPO_L15:  ; $7CDF, 576 bytes -- nivel 15
    INCBIN "data/niveles/body_l15.bin"
CABECERA_7F1F:  ; $7F1F, 96 bytes -- compartida por niveles 4/5/7/12/13
    INCBIN "data/niveles/header_7f1f.bin"
CABECERA_7F7F:  ; $7F7F, 96 bytes -- nivel 8
    INCBIN "data/niveles/header_7f7f.bin"
; $7FDF, 33 bytes -- relleno, todo $00, sin consumidor conocido
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    DB $00
CABECERA_8000:  ; $8000, 96 bytes -- compartida por niveles 0/1/2/3/6/9/10/11/14/15
    INCBIN "data/niveles/header_8000.bin"
TABLA_ITEMS_PELMAZOIDE:  ; $8060, array de 8 registros de 7 bytes -- CONFIRMADA sesion 49 via HNDLR_PELMAZOIDE, mismo nombre EXACTO que MSX (antes candidata por tener el mismo tamano). Reformateada a 1 registro por linea en sesion 54 (identica byte a byte a MSX, madmix_scr_body.asm:1736).
    DB $20,$10,$00,$01,$00,$00,$01  ; X,Y=semilla(sobrescrita) modo=0 dir=1 subX,subY=0 fase=1
    DB $10,$10,$00,$01,$00,$00,$02  ; fase=2
    DB $10,$10,$00,$01,$00,$00,$03  ; fase=3
    DB $10,$10,$00,$01,$00,$00,$01  ; fase=1
    DB $10,$10,$00,$01,$00,$00,$02  ; fase=2
    DB $10,$10,$00,$01,$00,$00,$01  ; fase=1
    DB $10,$10,$00,$01,$00,$00,$00  ; fase=0
    DB $10,$10,$00,$01,$00,$00,$01  ; fase=1
TABLA_ANIMACION_PELMAZOIDE:  ; $8098, 42 bytes (corregido sesion 54 -- no 32: el
                                ; comentario original solo contaba la tabla de
                                ; animacion propiamente dicha, sin los 10 bytes
                                ; finales que MSX documenta aparte como cola sin
                                ; etiqueta propia). CONFIRMADA sesion 49 via
                                ; HNDLR_PELMAZOIDE, mismo nombre EXACTO que MSX,
                                ; IDENTICA byte a byte (madmix_scr_body.asm:1812).
                                ; indice = direccion(1-4)*4 + fase(0-3), offsets
                                ; 6-9/10-13/14-17/18-21 relativos (0-5 nunca se
                                ; alcanza).
    DB $9A,$80                       ; offset 0-1: puntero autorreferencial = $809A (offset 2 de aqui mismo)
    DB $1B,$1B,$1C,$1C                ; offset 2-5: NUNCA se lee (direccion nunca vale 0) -- duplica "derecha"
    DB $1B,$1B,$1C,$1C                ; offset 6-9: DERECHA (direccion=1) -- sprites $1B,$1C
    DB $9B,$9B,$9C,$9C                ; offset 10-13: IZQUIERDA (direccion=2) -- $1B,$1C con bit7 (volteo horizontal)
    DB $1D,$1D,$1E,$1E                ; offset 14-17: ABAJO (direccion=3) -- sprites $1D,$1E
    DB $1F,$1F,$20,$20                ; offset 18-21: ARRIBA (direccion=4) -- sprites $1F,$20 -- ULTIMO offset real alcanzable
    DB $21,$21,$22,$22                ; offset 22-25: cola sin usar, fuera de rango indexable
    DB $21,$21,$22,$22                ; offset 26-29: cola sin usar, repite el patron anterior
    DB $A1,$A1                        ; offset 30-31: cola sin usar ($21 con bit7)
    DB $A2,$A2,$23,$23,$24,$24,$1F,$1F,$20,$20  ; offset 32-41: candidato a sprite huerfano (dato, no codigo -- igual que MSX $5174-$517D)
; TABLA_ELECCION_DIRECCION ($80C2, 128 bytes = 16 bloques de 8) --
; RESUELTA POR COMPLETO (sesion 49), mismo nombre EXACTO que MSX
; (madmix_scr_body.asm:1823), IDENTICA byte a byte. DATO puro (solo
; se lee con LD A,(HL), ningun salto apunta aqui). Indexada por
; MOTOR_MOVIMIENTO_ITEM/ELEGIR_DIRECCION_ALEATORIA como "(bitmask
; de direcciones libres)<<3 | (clase de direccion previa, via
; TABLA_CLASE_ALINEAMIENTO)<<1 | (bit aleatorio)" -> devuelve el
; codigo de direccion final elegido (1/2/4/8). Cada bloque de 8
; bytes se agrupa en 4 pares (bit aleatorio solo desempata): sesgo
; de "mantener direccion si se puede, si no elegir otra libre".
TABLA_ELECCION_DIRECCION:
    DB $01,$01,$01,$01,$01,$01,$01,$01  ; libres=ninguna (0000) -- sin libres, siempre intenta derecha por defecto
    DB $01,$01,$01,$01,$01,$01,$01,$01  ; libres=derecha (0001)
    DB $02,$02,$02,$02,$02,$02,$02,$02  ; libres=izquierda (0010)
    DB $01,$01,$02,$02,$01,$01,$01,$01  ; libres=derecha+izquierda (0011) -- prev.derecha->derecha, prev.izquierda->izquierda, resto->derecha
    DB $04,$04,$04,$04,$04,$04,$04,$04  ; libres=abajo (0100)
    DB $01,$01,$04,$04,$04,$04,$01,$01  ; libres=derecha+abajo (0101)
    DB $04,$04,$02,$02,$04,$04,$02,$02  ; libres=izquierda+abajo (0110)
    DB $01,$04,$02,$04,$01,$02,$01,$02  ; libres=derecha+izquierda+abajo (0111)
    DB $08,$08,$08,$08,$08,$08,$08,$08  ; libres=arriba (1000)
    DB $01,$01,$08,$08,$01,$01,$08,$08  ; libres=derecha+arriba (1001)
    DB $08,$08,$02,$02,$02,$02,$08,$08  ; libres=izquierda+arriba (1010)
    DB $01,$08,$02,$08,$01,$02,$08,$08  ; libres=derecha+izquierda+arriba (1011)
    DB $08,$04,$08,$04,$04,$04,$08,$08  ; libres=abajo+arriba (1100)
    DB $01,$01,$08,$04,$04,$01,$08,$01  ; libres=derecha+abajo+arriba (1101)
    DB $08,$04,$02,$02,$04,$02,$08,$02  ; libres=izquierda+abajo+arriba (1110)
    DB $01,$01,$02,$02,$04,$04,$08,$08  ; libres=derecha+izquierda+abajo+arriba (1111) -- mantiene la direccion previa en cada caso
; HNDLR_PELMAZOIDE: sus 5 etiquetas internas RESUELTAS POR COMPLETO
; (sesion 49), mismos nombres EXACTOS que MSX (madmix_scr_body.asm:1848)
; -- coincidencia instruccion a instruccion total. De paso CONFIRMADO
; $8060=TABLA_ITEMS_PELMAZOIDE (array de 7 bytes/entrada), $8098=
; TABLA_ANIMACION_PELMAZOIDE (16 palabras) y CODE_871C=
; ACTIVAR_EFECTO_ITEM (candidata desde sesion 40, ahora confirmada por
; coincidir exactamente con la llamada real de MSX en este mismo punto).
HNDLR_PELMAZOIDE:
    LD HL,(REGISTRO_NIVEL_POSICION_COMECOCOS)
    LD A,$10
    ADD A,H
    AND $7F
    LD H,A
    LD A,$18
    ADD A,L
    AND $7F
    LD L,A
    LD (PUNTO_REFERENCIA_CAMARA),HL
    LD A,(REGISTRO_NIVEL_CONTADOR_PELMAZOIDES)
    AND A
    JP Z,FIN_PELMAZOIDE
    LD B,A
    LD IX,TABLA_ITEMS_PELMAZOIDE
BUCLE_PELMAZOIDE:
    PUSH BC
    CALL MOTOR_MOVIMIENTO_ITEM
    JR C,SIGUIENTE_PELMAZOIDE
    PUSH DE
    LD A,(IX+$02)
    AND $0F
    ADD A,A
    LD HL,TABLA_ANIMACION_PELMAZOIDE
    ADD A,L
    LD L,A
    LD E,(HL)
    INC HL
    LD D,(HL)
    LD A,(MODO_ESPECIAL_FLAG)
    AND A
    JR Z,DIBUJAR_PELMAZOIDE
    LD A,(MODO_ESPECIAL_CUENTA_ATRAS)
    CP $32
    JR NC,AJUSTAR_SPRITE_MODO_ESPECIAL
    BIT 0,A
    JR Z,DIBUJAR_PELMAZOIDE
AJUSTAR_SPRITE_MODO_ESPECIAL:
    EX DE,HL
    LD DE,$0014
    ADD HL,DE
    EX DE,HL
DIBUJAR_PELMAZOIDE:
    LD A,(IX+$06)
    INC A
    AND $03
    LD (IX+$06),A
    LD L,A
    LD A,C
    ADD A,A
    ADD A,A
    ADD A,L
    LD L,A
    LD H,$00
    ADD HL,DE
    LD A,(HL)
    LD D,A
    AND $7F
    LD B,A
    LD A,D
    AND $80
    POP DE
    PUSH IX
    CALL MOTOR_ACTORES
    POP IX
    CALL ACTIVAR_EFECTO_ITEM
SIGUIENTE_PELMAZOIDE:
    LD BC,$0007
    ADD IX,BC
    POP BC
    DEC B
    JP NZ,BUCLE_PELMAZOIDE
FIN_PELMAZOIDE:
    RET
; --- MOTOR_MOVIMIENTO_ITEM: RESUELTA Y RENOMBRADA (sesion 35 con
; nombre propio "RESOLVER_DIRECCION_FANTASMA"; CORREGIDO en sesion 40
; al nombre EXACTO de MSX -- alli SI es una subrutina separada
; (HELPER_5278/MOVER_ITEM_MOVIL), compartida por los 3 manejadores de
; item: HNDLR_PELMAZOIDE, HNDLR_MARICOCO y HNDLR_REGPUNANTOSO -- la
; sesion 35 solo habia visto el primero y asumio, sin comprobarlo
; contra los otros dos, que era logica especifica del fantasma).
; Registro de actor en IX (7 bytes): para el fantasma, TABLA_ITEMS_PELMAZOIDE
; ($8060, confirmada sesion 49); para mariquita/repugnantoso, TABLA_ITEMS_MARICOCO/TABLA_ITEMS_REGPUNANTOSO
; (2/8 entradas). (IX+0)/(IX+1) = posicion H/L, (IX+2) = flags/modo,
; (IX+3) = direccion resuelta (salida), (IX+4)/(IX+5) = sub-posicion.
; Compara la posicion del item contra PUNTO_REFERENCIA_CAMARA ($6032)
; -- si MODO_ESPECIAL_ACTIVO
; esta activo invierte el delta (NEG/NEG) -- en el fantasma esto es
; HUIR en vez de perseguir; en mariquita/repugnantoso el efecto
; practico durante el modo especial no se ha explorado a fondo todavia.
; Calcula una mascara de 4 bits de direcciones validas/preferidas y la
; resuelve a UNA direccion final 1-4 via TABLA_CLASE_ALINEAMIENTO (dos
; accesos: uno para filtrar direcciones ya intentadas sin exito, otro
; para elegir la definitiva), guardando el resultado en (IX+3) y
; actualizando (IX+0)/(IX+1)/(IX+4)/(IX+5) con el movimiento
; resultante. Sigue, sin RET intermedio, calculando la posicion
; visible en pantalla del item (candidato a la misma funcion que
; CALCULAR_POSICION_VRAM_ITEM de MSX, "comprueba visibilidad y calcula
; posicion VRAM", compartida alli por fantasma/mariquita/repugnante)
; -- termina con SCF/RET (carry SET) si el item queda fuera del area
; visible (el bucle llamador lo salta sin dibujar) o AND A/RET (carry
; CLEAR, con DE=posicion calculada)
; si es visible. ---
MOTOR_MOVIMIENTO_ITEM:
    LD D,$00
    LD C,(IX+$00)
    LD B,(IX+$01)
    LD HL,(PUNTO_REFERENCIA_CAMARA)
    LD A,(MODO_ESPECIAL_FLAG)
    AND A
    JR Z,COMPROBAR_ESTADO_ITEM
    LD A,H
    NEG
    LD H,A
    LD A,L
    NEG
    LD L,A
    JR CALCULAR_DIRECCION_ACERCAMIENTO
COMPROBAR_ESTADO_ITEM:
    LD A,(IX+$02)
    AND A
    JR NZ,COMPROBAR_ALINEAMIENTO_LOSETA
    LD A,(MODO_ESPECIAL_ACTIVO)
    AND A
    JR NZ,COMPROBAR_ALINEAMIENTO_LOSETA
CALCULAR_DIRECCION_ACERCAMIENTO:
    LD A,L
    AND $FC
    LD L,A
    LD A,C
    AND $FC
    CP L
    JR NZ,COMPROBAR_FILA
    LD A,B
    CP H
    LD D,$08
    JR NC,COMPROBAR_ALINEAMIENTO_LOSETA
    LD D,$04
    JR COMPROBAR_ALINEAMIENTO_LOSETA
COMPROBAR_FILA:
    LD A,H
    AND $FC
    LD H,A
    LD A,B
    AND $FC
    CP H
    JR NZ,COMPROBAR_ALINEAMIENTO_LOSETA
    LD A,C
    CP L
    LD D,$02
    JR NC,COMPROBAR_ALINEAMIENTO_LOSETA
    LD D,$01
COMPROBAR_ALINEAMIENTO_LOSETA:
    LD A,(IX+$00)
    OR (IX+$01)
    AND $03
    LD A,(IX+$03)
    JR NZ,FIJAR_DIRECCION_Y_PASO
    LD B,D
    LD D,$00
    LD A,$01
    CALL CONSULTAR_LOSETA_LIBRE_DIRECCION
    OR D
    LD D,A
    LD A,$02
    CALL CONSULTAR_LOSETA_LIBRE_DIRECCION
    OR D
    LD D,A
    LD A,$04
    CALL CONSULTAR_LOSETA_LIBRE_DIRECCION
    OR D
    LD D,A
    LD A,$08
    CALL CONSULTAR_LOSETA_LIBRE_DIRECCION
    OR D
    LD D,A
    AND B
    JR Z,ELEGIR_ENTRE_LIBRES
    LD A,(MODO_ESPECIAL_FLAG)
    AND A
    LD A,B
    JR NZ,FIJAR_DIRECCION_Y_PASO
    CALL GENERAR_ALEATORIO
    AND $01
    LD A,B
    JR Z,FIJAR_DIRECCION_Y_PASO
ELEGIR_ENTRE_LIBRES:
    LD A,D
    ADD A,A
    ADD A,A
    ADD A,A
    LD D,A
    LD A,(IX+$02)
    AND A
    LD A,(IX+$03)
    JR Z,ELEGIR_DIRECCION_ALEATORIA
    LD A,(IX+$04)
    OR (IX+$05)
    BIT 7,A
    LD A,(IX+$03)
    JR NZ,FIJAR_DIRECCION_Y_PASO
ELEGIR_DIRECCION_ALEATORIA:
    LD HL,TABLA_CLASE_ALINEAMIENTO
    ADD A,L
    LD L,A
    LD A,H
    ADC A,$00
    LD H,A
    LD A,(HL)
    SUB $01
    JR NC,CONTINUAR_INDICE_DIRECCION_PREVIA
    XOR A
CONTINUAR_INDICE_DIRECCION_PREVIA:
    ADD A,A
    LD E,A
    CALL GENERAR_ALEATORIO
    AND $01
    OR E
    OR D
    LD HL,TABLA_ELECCION_DIRECCION
    ADD A,L
    LD L,A
    LD A,H
    ADC A,$00
    LD H,A
    LD A,(HL)
FIJAR_DIRECCION_Y_PASO:
    LD (IX+$03),A
    LD C,A
    LD A,C
    AND $0F
    LD HL,TABLA_CLASE_ALINEAMIENTO
    ADD A,L
    LD L,A
    LD C,(HL)
    LD A,(IX+$02)
    AND A
    LD A,C
    LD H,(IX+$00)
    LD L,(IX+$04)
    LD DE,$0100
    JR Z,CONTINUAR_TRAS_ELEGIR_PASO
    LD DE,$0080
CONTINUAR_TRAS_ELEGIR_PASO:
    LD A,(MODO_ESPECIAL_FLAG)
    AND A
    JR Z,CONTINUAR_TRAS_MODO_INVERTIDO
    LD DE,$0080
CONTINUAR_TRAS_MODO_INVERTIDO:
    LD A,C
    CP $01
    JR NZ,COMPROBAR_CODIGO_IZQUIERDA
    LD (IX+$05),$00
    ADD HL,DE
COMPROBAR_CODIGO_IZQUIERDA:
    CP $02
    JR NZ,COMPROBAR_CODIGO_ABAJO
    LD (IX+$05),$00
    SBC HL,DE
COMPROBAR_CODIGO_ABAJO:
    LD (IX+$04),L
    LD (IX+$00),H
    LD H,(IX+$01)
    LD L,(IX+$05)
    CP $03
    JR NZ,COMPROBAR_CODIGO_ARRIBA
    LD (IX+$04),$00
    ADD HL,DE
COMPROBAR_CODIGO_ARRIBA:
    CP $04
    JR NZ,GUARDAR_POSICION_Y
    LD (IX+$04),$00
    SBC HL,DE
GUARDAR_POSICION_Y:
    LD (IX+$05),L
    LD (IX+$01),H
CALCULAR_POSICION_VRAM_ITEM:
    PUSH BC
    LD BC,$0000
    LD DE,(REGISTRO_NIVEL_POSICION_COMECOCOS)
    RES 7,E
    RES 7,D
    LD A,E
    SUB $08
    RES 7,A
    CP $40
    JR C,CONTINUAR_AJUSTE_COLUMNA
    LD C,$40
    SUB C
CONTINUAR_AJUSTE_COLUMNA:
    LD E,A
    LD A,D
    SUB $08
    RES 7,A
    CP $40
    JR C,CONTINUAR_AJUSTE_FILA
    LD B,$40
    SUB B
CONTINUAR_AJUSTE_FILA:
    LD D,A
    LD A,(IX+$01)
    RES 7,A
    ADD A,B
    RES 7,A
    SUB D
    RES 7,A
    JR C,SALIR_FUERA_DE_RANGO
    CP $2C
    JR NC,SALIR_FUERA_DE_RANGO
    SUB $08
    RES 7,A
    LD H,A
    LD A,(IX+$00)
    RES 7,A
    ADD A,C
    RES 7,A
    SUB E
    RES 7,A
    JR C,SALIR_FUERA_DE_RANGO
    CP $38
    JR NC,SALIR_FUERA_DE_RANGO
    SUB $08
    RES 7,A
    LD L,A
    ADD A,A
    ADD A,$0E
    LD E,A
    LD A,H
    ADD A,A
    ADD A,A
    ADD A,$F8
    LD D,A
    LD A,(IX+$04)
    RLCA
    LD A,E
    ADC A,$00
    LD E,A
    LD A,(IX+$05)
    RLCA
    LD A,D
    ADC A,$00
    LD D,A
    POP BC
    AND A
    RET
SALIR_FUERA_DE_RANGO:
    POP BC
    SCF
    RET
CONSULTAR_LOSETA_LIBRE_DIRECCION:
    PUSH BC
    PUSH DE
    LD C,(IX+$00)
    LD B,(IX+$01)
    RRA
    JR NC,COMPROBAR_IZQUIERDA
    INC C
    INC C
    INC C
    INC C
    LD A,$01
    JR CONSULTAR_LOSETA_DESPLAZADA
COMPROBAR_IZQUIERDA:
    RRA
    JR NC,COMPROBAR_ABAJO
    DEC C
    LD A,$02
    JR CONSULTAR_LOSETA_DESPLAZADA
COMPROBAR_ABAJO:
    RRA
    JR NC,COMPROBAR_ARRIBA
    INC B
    INC B
    INC B
    INC B
    LD A,$04
    JR CONSULTAR_LOSETA_DESPLAZADA
COMPROBAR_ARRIBA:
    RRA
    JR NC,CONSULTAR_LOSETA_DESPLAZADA
    DEC B
    LD A,$08
CONSULTAR_LOSETA_DESPLAZADA:
    LD D,A
    CALL MAPEAR_COORDENADA_A_DIRECCION
    CALL CONSULTAR_TIPO_LOSETA
    AND A
    JR Z,LOSETA_BLOQUEADA
    CP $08
    JR Z,LOSETA_BLOQUEADA
    CP $07
    JR Z,LOSETA_BLOQUEADA
    CP $0A
    JR NZ,LOSETA_LIBRE
LOSETA_BLOQUEADA:
    XOR A
    SCF
    JR FIN_CONSULTA_LOSETA
LOSETA_LIBRE:
    LD A,D
    AND A
FIN_CONSULTA_LOSETA:
    POP DE
    POP BC
    RET
MAPEAR_COORDENADA_A_DIRECCION:
    LD A,B
    AND $7C
    RRCA
    RRCA
    LD B,A
    LD A,C
    AND $7C
    RLCA
    RR B
    RRA
    RR B
    RRA
    RR B
    RRA
    LD C,A
    LD HL,$FC60
    ADD HL,BC
    RET
GENERAR_ALEATORIO:
    PUSH HL
    LD HL,(SEMILLA_ALEATORIA)
    LD A,R
    RRCA
    ADC A,L
    XOR (HL)
    LD L,A
    LD (SEMILLA_ALEATORIA),HL
    POP HL
    RET
; ==============================================================
;  SUBSISTEMA MARIQUITA/REPUGNANTOSO ($83CB-$85AD) -- RESUELTO
;  POR COMPLETO (sesion 40), mismos nombres EXACTOS que MSX.
;  Coincidencia CASI TOTAL instruccion a instruccion con
;  HNDLR_MARICOCO/HNDLR_REGPUNANTOSO de MSX (madmix_scr_body.asm)
;  -- extraido y verificado byte a byte desde FISICO/CODE.bin
;  (desensamblado manual, sin ambiguedad: todos los saltos
;  internos convergen exactos en las mismas 2 direcciones de
;  cola -- SIGUIENTE_MARICOCO/SIGUIENTE_REGPUNANTOSO -- lo que
;  confirma que la alineacion de bytes es correcta de principio
;  a fin). Ambos manejadores comparten MOTOR_MOVIMIENTO_ITEM
;  ($81BC, antes nombrada RESOLVER_DIRECCION_FANTASMA en sesion 35)
;  con HNDLR_PELMAZOIDE -- CORRECCION de sesion 40: no es logica
;  propia del fantasma, es una rutina generica de movimiento de
;  item compartida por los 3 (fantasma/mariquita/repugnantoso),
;  igual que en MSX. Tambien comparten MAPEAR_COORDENADA_A_DIRECCION_LOCAL
;  (usa $FC60, no $FC50 -- MISMA direccion que la v1.0 original de
;  MSX antes de su parche v2.0, coherente con sesion 29) y llaman
;  DIRECTAMENTE a REDIBUJAR_LOSETA_BUFFER_VRAM (no via cola diferida
;  APILAR_PETICION_REDIBUJADO como MSX en este punto concreto -- MSX
;  aniadio esa cola como adaptacion propia, consistente con
;  [[madmix-spectrum-is-original]]). ACTIVAR_EFECTO_ITEM ($871C, sesion
;  40 como EQU sobre zona mecanica; RESUELTA a etiqueta real en sesion
;  49, ver su propia definicion mas abajo) y CODE_84E0 (referencia
;  huerfana desde otra parte del fichero a una direccion dentro de
;  TABLA_ITEMS_REGPUNANTOSO, resuelta con EQU).
;  Ver FINDINGS.md sesion 40 para el detalle completo.
; ==============================================================
CODE_84E0 EQU $84E0
TABLA_ANIMACION_MARICOCO:              ; $83CB, 20 bytes -- comentarios de sesion 54, mismo patron confirmado que MSX (madmix_scr_body.asm:2348)
    DB $27,$27,$27,$27               ; offset 0-3: nunca se lee (direccion nunca vale 0)
    DB $27,$27,$27,$27               ; offset 4-7: DERECHA (direccion=1)
    DB $A7,$A7,$A7,$A7               ; offset 8-11: IZQUIERDA (direccion=2) -- $27 con bit7
    DB $25,$25,$25,$25               ; offset 12-15: ABAJO (direccion=3)
    DB $26,$26,$26,$26               ; offset 16-19: ARRIBA (direccion=4)
TABLA_ITEMS_MARICOCO:                  ; $83DF, 2 entradas x 7 bytes -- pasada a decimal en sesion 54 (regla del proyecto: cantidades en decimal), igual que MSX (madmix_scr_body.asm:2355)
    DB 32,16,1,1,0,0,1  ; X,Y=semilla(sobrescrita) modo/plantado=1 dir=1 subX,subY=0 fase=1
    DB 32,16,1,1,0,0,1
HNDLR_MARICOCO:
    LD A,($6010)                       ; REGISTRO_NIVEL_CONTADOR_MARICOCOS (candidato)
    AND A
    RET Z
    LD B,A
    LD IX,TABLA_ITEMS_MARICOCO
BUCLE_MARICOCO:
    PUSH BC
    LD C,(IX+$00)
    LD B,(IX+$01)
    LD HL,(REGISTRO_NIVEL_POSICION_COMECOCOS)
    LD A,B
    OR C
    OR H
    OR L
    AND $03
    JR NZ,MARICOCO_SIN_REGENERAR
    CALL MAPEAR_COORDENADA_A_DIRECCION_LOCAL
    LD A,(HL)
    BIT 7,A
    JR Z,MARICOCO_SIN_REGENERAR
    RES 7,A
    SUB $3F
    JR C,MARICOCO_SIN_REGENERAR
    CP $03
    JR NC,MARICOCO_SIN_REGENERAR
    ADD A,$2D
    JR MARICOCO_GUARDAR_ESTADO_REGENERACION
MARICOCO_SIN_REGENERAR:
    XOR A
MARICOCO_GUARDAR_ESTADO_REGENERACION:
    LD (ESTADO_REGENERACION_MARICOCO),A
    LD (VRAM_REGENERACION_MARICOCO),HL
    PUSH BC
    CALL MOTOR_MOVIMIENTO_ITEM
    POP HL
    JR C,SIGUIENTE_MARICOCO
    PUSH HL
    PUSH DE
    LD DE,TABLA_ANIMACION_MARICOCO
    LD A,(IX+$06)
    INC A
    AND $03
    LD (IX+$06),A
    LD L,A
    LD A,C
    ADD A,A
    ADD A,A
    ADD A,L
    LD L,A
    LD H,$00
    ADD HL,DE
    LD A,(HL)
    LD D,A
    AND $7F
    LD B,A
    LD A,D
    AND $80
    POP DE
    PUSH IX
    CALL MOTOR_ACTORES
    POP IX
    LD (IX+$02),$01
    CALL ACTIVAR_EFECTO_ITEM
    POP DE
    LD HL,(REGISTRO_NIVEL_POSICION_COMECOCOS)
    RES 7,H
    RES 7,L
    LD A,E
    SUB L
    AND $7C
    RRCA
    RRCA
    LD C,A
    CP $0C
    JR NC,SIGUIENTE_MARICOCO
    LD A,D
    SUB H
    AND $7C
    RRCA
    RRCA
    LD B,A
    CP $09
    JR NC,SIGUIENTE_MARICOCO
    LD A,(ESTADO_REGENERACION_MARICOCO)
    AND A
    JR Z,SIGUIENTE_MARICOCO
    LD HL,CONTADOR_BOLAS_COMIDAS
    DEC (HL)
    LD HL,(VRAM_REGENERACION_MARICOCO)
    LD (HL),A
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    LD A,$05
    LD (EVENTO_SONIDO_PENDIENTE),A
SIGUIENTE_MARICOCO:
    LD BC,$0007
    ADD IX,BC
    POP BC
    DEC B
    JP NZ,BUCLE_MARICOCO
    RET
ESTADO_REGENERACION_MARICOCO:          ; $849A, 1 byte
    DB 0
VRAM_REGENERACION_MARICOCO:            ; $849B, 2 bytes (word)
    DW 0
MAPEAR_COORDENADA_A_DIRECCION_LOCAL:   ; $849D -- mismo nombre EXACTO
                                        ; que MSX, formula identica a
                                        ; MAPEAR_LOSETA_RELATIVA_A_ABSOLUTA
                                        ; pero copia independiente. Usa
                                        ; $FC60 (no $FC50) -- MISMA
                                        ; direccion que la v1.0 original
                                        ; de MSX antes de su parche v2.0.
    PUSH BC
    LD A,B
    AND $7C
    RRCA
    RRCA
    LD B,A
    LD A,C
    AND $7C
    RLCA
    RR B
    RRA
    RR B
    RRA
    RR B
    RRA
    LD C,A
    LD HL,$FC60
    ADD HL,BC
    POP BC
    RET
TABLA_ANIMACION_REGPUNANTOSO:          ; $84B8, 20 bytes -- comentarios de sesion 54, mismo patron confirmado que MSX (madmix_scr_body.asm:2531)
    DB $2F,$2E,$2D,$2E               ; offset 0-3: nunca se lee (direccion nunca vale 0)
    DB $2F,$2E,$2D,$2E               ; offset 4-7: DERECHA (direccion=1), 4 fotogramas reales
    DB $AF,$AE,$AD,$AE               ; offset 8-11: IZQUIERDA (direccion=2) -- misma animacion con bit7
    DB $32,$31,$30,$31               ; offset 12-15: ABAJO (direccion=3)
    DB $33,$34,$35,$34               ; offset 16-19: ARRIBA (direccion=4)
TABLA_ITEMS_REGPUNANTOSO:              ; $84CC, 8 entradas x 7 bytes -- pasada a decimal en sesion 54 (regla del proyecto: cantidades en decimal), igual que MSX (madmix_scr_body.asm:2538)
    DB 32,16,2,1,0,0,1  ; X,Y=semilla(sobrescrita) modo/plantado=2 dir=1 subX,subY=0 fase=1
    DB 32,16,2,1,0,0,1
    DB 32,16,2,1,0,0,1
    DB 32,16,2,1,0,0,1
    DB 32,16,2,1,0,0,1
    DB 32,16,2,1,0,0,1
    DB 32,16,2,1,0,0,1
    DB 32,16,2,1,0,0,1
HNDLR_REGPUNANTOSO:
    LD A,($6011)                       ; REGISTRO_NIVEL_CONTADOR_REPUGNANTOSOS (candidato)
    AND A
    RET Z
    LD B,A
    LD IX,TABLA_ITEMS_REGPUNANTOSO
BUCLE_REGPUNANTOSO:
    PUSH BC
    LD (IX+$02),$02
    LD C,(IX+$00)
    LD B,(IX+$01)
    LD HL,(REGISTRO_NIVEL_POSICION_COMECOCOS)
    LD A,B
    OR C
    OR H
    OR L
    AND $03
    JR NZ,REGPUNANTOSO_SIN_PLANTAR
    CALL MAPEAR_COORDENADA_A_DIRECCION_LOCAL
    LD A,(HL)
    BIT 7,A
    JR NZ,REGPUNANTOSO_SIN_PLANTAR
    SUB $2D
    JR C,REGPUNANTOSO_SIN_PLANTAR
    CP $03
    JR NC,REGPUNANTOSO_SIN_PLANTAR
    ADD A,$30
    JR REGPUNANTOSO_GUARDAR_ESTADO_PLANTADO
REGPUNANTOSO_SIN_PLANTAR:
    XOR A
REGPUNANTOSO_GUARDAR_ESTADO_PLANTADO:
    LD (ESTADO_PLANTADO_REGPUNANTOSO),A
    LD (VRAM_PLANTADO_REGPUNANTOSO),HL
    PUSH BC
    CALL MOTOR_MOVIMIENTO_ITEM
    POP HL
    JR C,SIGUIENTE_REGPUNANTOSO
    PUSH HL
    PUSH DE
    LD DE,TABLA_ANIMACION_REGPUNANTOSO
    LD A,(IX+$06)
    INC A
    AND $03
    LD (IX+$06),A
    LD L,A
    LD A,C
    ADD A,A
    ADD A,A
    ADD A,L
    LD L,A
    LD H,$00
    ADD HL,DE
    LD A,(HL)
    LD D,A
    AND $7F
    LD B,A
    LD A,D
    AND $80
    POP DE
    PUSH IX
    CALL MOTOR_ACTORES
    POP IX
    CALL ACTIVAR_EFECTO_ITEM
    POP DE
    LD HL,(REGISTRO_NIVEL_POSICION_COMECOCOS)
    RES 7,H
    RES 7,L
    LD A,E
    SUB L
    AND $7C
    RRCA
    RRCA
    LD C,A
    CP $0C
    JR NC,SIGUIENTE_REGPUNANTOSO
    LD A,D
    SUB H
    AND $7C
    RRCA
    RRCA
    LD B,A
    CP $09
    JR NC,SIGUIENTE_REGPUNANTOSO
    LD A,(ESTADO_PLANTADO_REGPUNANTOSO)
    AND A
    JR Z,SIGUIENTE_REGPUNANTOSO
    LD HL,(VRAM_PLANTADO_REGPUNANTOSO)
    LD (HL),A
    CALL REDIBUJAR_LOSETA_BUFFER_VRAM
    LD A,$06
    LD (EVENTO_SONIDO_PENDIENTE),A
SIGUIENTE_REGPUNANTOSO:
    LD BC,$0007
    ADD IX,BC
    POP BC
    DEC B
    JP NZ,BUCLE_REGPUNANTOSO
    RET
ESTADO_PLANTADO_REGPUNANTOSO:          ; $85AB, 1 byte
    DB 0
VRAM_PLANTADO_REGPUNANTOSO:            ; $85AC, 2 bytes (word)
    DW 0
AVISAR_PROXIMIDAD_PISTA:
    PUSH IX
    PUSH DE
    EXX
    POP DE
    EXX
    LD B,$03
    LD HL,TABLA_PISTAS_TANQUE_AVION
BUCLE_PISTA:
    PUSH BC
    LD A,(HL)
    AND A
    JR Z,SIGUIENTE_PISTA
    INC HL
    LD D,(HL)
    BIT 0,D
    JR Z,FORMATO_B
    DEC HL
    SUB $10
    LD D,A
    LD E,$40
    JR NC,COMPROBAR_MARGEN_PISTA
    JR SIGUIENTE_PISTA
FORMATO_B:
    BIT 7,(HL)
    DEC HL
    JR Z,FORMATO_B_POS
    SUB $08
    LD E,A
    JR FILA_FIJA
FORMATO_B_POS:
    ADD A,$08
    LD E,A
    JR FILA_FIJA
FILA_FIJA:
    LD E,A
    LD D,$38
COMPROBAR_MARGEN_PISTA:
    EXX
    PUSH DE
    EXX
    POP BC
    LD A,C
    ADD A,$FC
    CP E
    JR NC,SIGUIENTE_PISTA
    ADD A,$0C
    CP E
    JR C,SIGUIENTE_PISTA
    LD A,B
    ADD A,$F8
    CP D
    JR NC,SIGUIENTE_PISTA
    ADD A,$14
    CP D
    JR C,SIGUIENTE_PISTA
    PUSH HL
    LD C,$4D
    CALL ARMAR_AVISO_DESTELLO
    LD A,$07
    LD (EVENTO_SONIDO_PENDIENTE),A
    POP HL
SIGUIENTE_PISTA:
    INC HL
    INC HL
    POP BC
    DJNZ BUCLE_PISTA
    POP IX
    RET
ARMAR_AVISO_DESTELLO:
    LD HL,TABLA_RANURAS_AVISO
    LD B,$04
BUCLE_RANURA_AVISO:
    LD A,(HL)
    AND A
    JR NZ,SIGUIENTE_RANURA_AVISO
    LD (HL),C
    BIT 7,C
    RET NZ
    INC HL
    LD A,(IX+$00)
    LD (HL),A
    INC HL
    LD A,(IX+$01)
    LD (HL),A
    LD HL,(REGISTRO_NIVEL_FILA_COLUMNA)
    LD (IX+$00),L
    LD (IX+$01),H
    XOR A
    LD (TEMPORIZADOR_PARPADEO_BOLA),A
    RET
SIGUIENTE_RANURA_AVISO:
    INC HL
    INC HL
    INC HL
    DJNZ BUCLE_RANURA_AVISO
    RET
; ITEM_TABLE_EFECTOS_DESTELLO ($8639, 126 bytes) -- RESUELTA POR
; COMPLETO (sesion 49), mismo nombre EXACTO que MSX
; (madmix_scr_body.asm:2846), IDENTICA byte a byte. Secuencias de
; "flash" de celebracion (dibuja iconos reales con el motor de
; sprites): ACTUALIZAR_DESTELLO_ITEMS recorre cada una byte a byte
; hasta encontrar $FF (centinela de fin). Puntos de entrada reales
; (valor de C en cada CALL ARMAR_AVISO_DESTELLO): $01=SEQ_A,
; $17=SEQ_A_TAIL, $A7=SEQ_B_ENTRY (item=hipopotamo), $AD=SEQ_B_MAIN
; (resto de items), $4D=SEQ_B_TAIL (AVISAR_PROXIMIDAD_PISTA, flash
; mas corto), $55=SEQ_C, $6D=SEQ_C_TAIL. TRUCO DE AHORRO DE MEMORIA:
; el $FF que cierra la secuencia A (offset 39) se reutiliza a
; proposito como punto de entrada valido a la secuencia B (entrada
; $A7). El tramo $0F,$8D,$0E,$0D,$0F (offset 40-44) sigue sin
; descifrar en ninguna de las 2 versiones -- no encaja con el patron
; de "loseta repetida" del resto de la tabla.
ITEM_TABLE_EFECTOS_DESTELLO:
    DB $00                                       ; offset 0: sin punto de entrada conocido
EFECTOS_DESTELLO_SEQ_A:                          ; offset 1 -- entrada real ($01)
    DB $36,$36,$36,$36,$36,$36,$36,$36,$36,$36,$36,$36,$36,$36,$36,$36,$36,$36,$36,$36,$36,$36  ; flecha_derecha x22
EFECTOS_DESTELLO_SEQ_A_TAIL:                     ; offset 23 -- entrada real ($17)
    DB $28,$28,$29,$29,$2A,$2B                   ; cierre comun (esquinas/uniones de muro de ladrillo)
    DB $38,$38,$38,$38,$38,$38,$38,$38,$38,$38   ; linea_electrica_puerta_fantasmas_a x10
EFECTOS_DESTELLO_SEQ_B_ENTRY:                    ; offset 39 -- entrada real ($A7); TAMBIEN el $FF que cierra la
                                                  ; secuencia A (ver truco de ahorro de memoria arriba)
    DB $FF
    DB $0F,$8D,$0E,$0D,$0F                       ; offset 40-44: sin descifrar
EFECTOS_DESTELLO_SEQ_B_MAIN:                     ; offset 45 -- entrada real ($AD)
    DB $03,$00,$06,$80,$03,$00,$06,$80,$03,$00,$06,$80,$03,$00,$06,$80,$03,$00,$06,$80,$03,$00,$06,$80  ; patron repetido, sin descifrar
    DB $3A,$3A,$3B,$3B,$3C,$3C,$3D,$3D           ; ciclo: pista_avion/item_suelo/bola_poder/hipopotamo
EFECTOS_DESTELLO_SEQ_B_TAIL:                     ; offset 77 -- entrada real ($4D)
    DB $28,$28,$29,$29,$2A,$2B,$2C               ; cierre comun (esquinas/uniones de muro de ladrillo)
    DB $FF                                       ; fin real de la secuencia B
EFECTOS_DESTELLO_SEQ_C:                          ; offset 85 -- entrada real ($55)
    DB $3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E  ; item_herramienta x24
EFECTOS_DESTELLO_SEQ_C_TAIL:                     ; offset 109 -- entrada real ($6D)
    DB $28,$28,$29,$29,$2A,$2B                   ; cierre comun (esquinas/uniones de muro de ladrillo)
    DB $37,$37,$37,$37,$37,$37,$37,$37,$37,$37   ; pista_tanque_vertical x10
    DB $FF                                       ; fin real de la secuencia C
; TABLA_RANURAS_AVISO ($86B7, 15 bytes = 4 entradas x 2 bytes + 7
; bytes sin consumidor confirmado) -- RESUELTA sesion 49, mismo
; nombre EXACTO que MSX, IDENTICA (15 ceros en ambas versiones).
; Zona de trabajo de ARMAR_AVISO_DESTELLO/ACTUALIZAR_DESTELLO_ITEMS
; (secuencias de aviso/flash: pista, bola de poder, puntos).
TABLA_RANURAS_AVISO:
    DB $00,$00,$00,$00,$00,$00,$00,$00
    DB $00,$00,$00,$00,$00,$00,$00
; ACTUALIZAR_DESTELLO_ITEMS: sus etiquetas internas RESUELTAS POR
; COMPLETO (sesion 49), mismos nombres EXACTOS que MSX
; (madmix_scr_body.asm:2883) -- coincidencia instruccion a instruccion
; total (incluidos los valores decimales D=56/E=64, posicion VRAM fija
; centro de pantalla). Recorre las 4 entradas de TABLA_RANURAS_AVISO
; y para cada una no vacia hace parpadear/reduce su cuenta, con
; ITEM_TABLE_EFECTOS_DESTELLO decidiendo la loseta segun MODO_ESPECIAL.
ACTUALIZAR_DESTELLO_ITEMS:
    LD B,$04
    LD IX,TABLA_RANURAS_AVISO
BUCLE_DESTELLO:
    PUSH BC
    LD A,(IX+$00)
    INC IX
    AND A
    JP Z,SIGUIENTE_DESTELLO
    INC (IX-$01)
    AND $7F
    LD C,A
    LD A,(MODO_ESPECIAL_ACTIVO)
    AND A
    JR Z,CALCULAR_POSICION_DESTELLO
    BIT 7,(IX-$01)
    LD D,$38
    LD E,$40
    JR NZ,DIBUJAR_FRAME_DESTELLO
CALCULAR_POSICION_DESTELLO:
    CALL CALCULAR_POSICION_VRAM_ITEM
    RR B
DIBUJAR_FRAME_DESTELLO:
    LD HL,ITEM_TABLE_EFECTOS_DESTELLO
    LD A,C
    ADD A,L
    LD L,A
    LD A,H
    ADC A,$00
    LD H,A
    LD A,(HL)
    AND $80
    RL B
    LD B,(HL)
    RES 7,B
    PUSH IX
    CALL NC,MOTOR_ACTORES
    POP IX
    INC HL
    LD A,(HL)
    CP $FF
    JR NZ,SIGUIENTE_DESTELLO
    LD (IX-$01),$00
SIGUIENTE_DESTELLO:
    INC IX
    INC IX
    POP BC
    DJNZ BUCLE_DESTELLO
    RET
; ACTIVAR_EFECTO_ITEM: RESUELTA POR COMPLETO (sesion 49), mismo
; nombre EXACTO que MSX (madmix_scr_body.asm:2945) para la rutina Y
; todas sus etiquetas internas (ACTIVAR_NUEVO_MODO_ESPECIAL,
; INICIAR_MODO_ESPECIAL, MODO_BOLA_PODER_ACTIVO, SUMAR_PUNTOS_MODO1,
; MODO_HIPOPOTAMO_ACTIVO, SUMAR_PUNTOS_MODO2, MODO_HERRAMIENTA_ACTIVO,
; DELEGAR_AVISO_PISTA) -- coincidencia instruccion a instruccion casi
; total. Comprueba colision del comecocos con un item (ventana de
; posicion VRAM fija) y dispara el modo especial/puntos/aviso segun
; el tipo de item y su estado.
;
; 2 diferencias reales confirmadas con MSX, ambas coherentes con
; [[madmix_sound_chip_differences_expected]] y con que Spectrum sea
; el original:
;   - Duracion del modo especial: MSX usa 40/45 fotogramas: aqui son
;     42/47 ($2A/$2F) -- 2 fotogramas mas en ambos casos.
;   - INICIAR_MODO_ESPECIAL termina con RET inmediato tras marcar
;     EVENTO_SONIDO_PENDIENTE=8; MSX en cambio espera activamente
;     (bucle .ESPERAR_EVENTO) a que se consuma antes de marcar el
;     evento final 13 -- adaptacion propia de MSX a la temporizacion
;     de su gestor de sonido PSG, que aqui no hace falta.
ACTIVAR_EFECTO_ITEM:
    LD A,(MODO_ESPECIAL_ACTIVO)
    AND A
    RET NZ
    LD A,D
    CP $32
    JP C,DELEGAR_AVISO_PISTA
    CP $3E
    JP NC,DELEGAR_AVISO_PISTA
    LD A,E
    CP $3C
    JP C,DELEGAR_AVISO_PISTA
    CP $44
    JP NC,DELEGAR_AVISO_PISTA
    LD H,(IX+$02)
    LD A,(MODO_ESPECIAL)
    LD L,A
    AND A
    JR NZ,MODO_BOLA_PODER_ACTIVO
ACTIVAR_NUEVO_MODO_ESPECIAL:
    LD A,H
    CP $01
    JR Z,DELEGAR_AVISO_PISTA
    LD A,(LADO_APERTURA_TRAMPILLA)
    AND A
    JR NZ,DELEGAR_AVISO_PISTA
    LD A,(INDICE_CICLO_NIVELES)
    AND A
    JR NZ,DELEGAR_AVISO_PISTA
    LD A,L
    CP $03
    LD A,$2A
    LD C,$AD
    JR NZ,INICIAR_MODO_ESPECIAL
    LD A,$2F
    LD C,$A7
INICIAR_MODO_ESPECIAL:
    LD (MODO_ESPECIAL_ACTIVO),A
    CALL ARMAR_AVISO_DESTELLO
    LD A,$08
    LD (EVENTO_SONIDO_PENDIENTE),A
    RET
MODO_BOLA_PODER_ACTIVO:
    CP $01
    JR NZ,MODO_HIPOPOTAMO_ACTIVO
    LD A,H
    CP $02
    JR NC,DELEGAR_AVISO_PISTA
    CP $01
    LD HL,$0004
    LD C,$6D
    JR NZ,SUMAR_PUNTOS_MODO1
    LD HL,$0006
    LD C,$17
SUMAR_PUNTOS_MODO1:
    CALL DIBUJAR_MARCADOR_PUNTOS
    CALL ARMAR_AVISO_DESTELLO
    LD A,$07
    LD (EVENTO_SONIDO_PENDIENTE),A
    RET
MODO_HIPOPOTAMO_ACTIVO:
    CP $02
    JR NZ,MODO_HERRAMIENTA_ACTIVO
    LD A,H
    CP $01
    LD HL,$0006
    LD C,$17
    JR Z,SUMAR_PUNTOS_MODO2
    LD C,$55
    LD HL,$0004
    JR C,SUMAR_PUNTOS_MODO2
    LD HL,$0006
    LD C,$01
SUMAR_PUNTOS_MODO2:
    CALL DIBUJAR_MARCADOR_PUNTOS
    CALL ARMAR_AVISO_DESTELLO
    LD A,$07
    LD (EVENTO_SONIDO_PENDIENTE),A
    RET
MODO_HERRAMIENTA_ACTIVO:
    CP $03
    JR Z,ACTIVAR_NUEVO_MODO_ESPECIAL
DELEGAR_AVISO_PISTA:
    CALL AVISAR_PROXIMIDAD_PISTA
    RET
INICIALIZAR_ITEMS_NIVEL:
    LD IX,TABLA_ITEMS_PELMAZOIDE
    LD BC,(REGISTRO_NIVEL_FILA_COLUMNA)
    LD DE,$0007
    LD A,$08
BUCLE_RESET_PELMAZOIDE:
    LD (IX+$00),C
    LD (IX+$01),B
    LD (IX+$04),$00
    LD (IX+$05),$00
    ADD IX,DE
    DEC A
    JR NZ,BUCLE_RESET_PELMAZOIDE
    LD IX,TABLA_ITEMS_MARICOCO
    LD A,$02
BUCLE_RESET_MARICOCO:
    LD (IX+$00),C
    LD (IX+$01),B
    LD (IX+$04),$00
    LD (IX+$05),$00
    ADD IX,DE
    DEC A
    JR NZ,BUCLE_RESET_MARICOCO
    LD IX,TABLA_ITEMS_REGPUNANTOSO
    LD A,$08
BUCLE_RESET_REGPUNANTOSO:
    LD (IX+$00),C
    LD (IX+$01),B
    LD (IX+$04),$00
    LD (IX+$05),$00
    ADD IX,DE
    DEC A
    JR NZ,BUCLE_RESET_REGPUNANTOSO
    LD B,$04
    LD HL,TABLA_RANURAS_AVISO
LOOP_LIMPIEZA_DESTELLO:
    LD (HL),$00
    INC HL
    INC HL
    DJNZ LOOP_LIMPIEZA_DESTELLO
    LD A,(MODO_ESPECIAL)
    CP $03
    LD A,$0E
    JR Z,CONTINUAR_RESET_EXCAVATOFONO
    XOR A
CONTINUAR_RESET_EXCAVATOFONO:
    LD (DIRECCION_DE_MOVIMIENTO),A
    LD (DIRECCION_FORZADA),A
    LD (TEMPORIZADOR_DIRECCION_FORZADA),A
    LD (TEMPORIZADOR_PARPADEO_BOLA),A
INICIALIZAR_PARCIAL_ITEMS_NIVEL:
    LD B,$03
    LD HL,TABLA_PISTAS_TANQUE_AVION
LOOP_LIMPIEZA_PISTA:
    LD (HL),$00
    INC HL
    INC HL
    DJNZ LOOP_LIMPIEZA_PISTA
    RET
; --- CARGAR_NIVEL: RESUELTA Y RENOMBRADA (sesion 24), mismo nombre
; EXACTO que en MSX (madmix_scr_body.asm, $58D9 aprox.) -- coincidencia
; INSTRUCCION A INSTRUCCION casi perfecta con la version MSX, incluidos
; los MISMOS valores constantes (20, 96, $3C=tile comodin) y, mas
; llamativo aun, la MISMA direccion $FC60 que usaba la v1.0 ORIGINAL de
; MSX antes del parche de la v2.0 que la movio a $FC50 (bug del
; contador de bolitas del nivel 13, ver FINDINGS.md de MSX) -- prueba
; de que esta cinta Spectrum comparte linaje de desarrollo directo con
; el MSX v1.0 sin parchear, no es una adaptacion independiente.
;
; Esta correspondencia exacta permitio confirmar de una vez una FAMILIA
; ENTERA de variables (antes solo hipotesis sueltas), todas dentro de
; la zona de trabajo del motor en $600x-$602x -- ver la cabecera de esa
; zona (justo detras de MOTOR_INICIO, sesion 25) para el detalle
; completo de cada una con su direccion real y su equivalente MSX.
; $88E0 = TABLA_NIVELES (20 bytes/registro, indexada por nivel, ver su
; propia cabecera mas abajo -- RESUELTA por completo en sesion 47).
;
; POSICION_PARPADEO_BOLA es el resultado de MAPEAR_COORDENADA_A_DIRECCION
; (CONFIRMADA sesion 40, ver MOTOR_MOVIMIENTO_ITEM -- coincide
; instruccion a instruccion con MSX). $9E12/$9E13 -- RESUELTO sesion
; 56: SI tienen equivalente MSX, son TABLA_POSICIONES_HUD+17/+18 (ver
; DESTELLO_ICONO_COLOR_HUD/BUSCAR_COLUMNA_HUD), aqui reinicializados a
; juego con COLOR_ACTUAL/REGISTRO_NIVEL_ICONO_HUD al cargar nivel.
; INICIALIZAR_ITEMS_NIVEL tambien RESUELTA POR COMPLETO (ver su propia
; cabecera mas abajo). Etiquetas internas de este bloque
; (COPIAR_REGISTRO_NIVEL y siguientes) nombradas sesion 56 tirando del
; hilo de CODE_884B -- no llevaba a ningun codigo nuevo, solo confirmo
; que ambas notas de arriba estaban obsoletas.
;
; CORRECCION (sesion 47): el codigo REAL de CARGAR_NIVEL termina en el
; RET justo despues de CALL INICIALIZAR_ITEMS_NIVEL ($88DF) -- son 165 bytes, NO los
; 912 que sesion 24 le habia atribuido por error (la mecanica del
; desensamblado de primera pasada seguia produciendo instrucciones
; superficialmente plausibles mas alla de ese RET, y nunca se comprobo
; que de verdad fueran alcanzables). El resto de ese rango es
; TABLA_NIVELES (320 B, ver abajo) seguida de un menu de opciones de
; control descubierto en sesion 46 (427 B, ver TABLA_MENU_OPCIONES_
; CONTROL mas abajo) -- ninguno de los dos es CARGAR_NIVEL. Ver
; FINDINGS.md sesion 47 para el detalle completo. ---
CARGAR_NIVEL:
    LD A,(NIVEL_ACTUAL)
    LD HL,$88E0                  ; TABLA_NIVELES
    LD BC,$0014                  ; 20 bytes/registro
    AND A
    JR Z,COPIAR_REGISTRO_NIVEL
BUCLE_LOCALIZAR_REGISTRO_NIVEL:
    ADD HL,BC
    DEC A
    JR NZ,BUCLE_LOCALIZAR_REGISTRO_NIVEL
COPIAR_REGISTRO_NIVEL:
    LD DE,REGISTRO_NIVEL_CUERPO_PTR
    LDIR
    LD DE,$FC60                  ; buffer de nivel activo (= direccion EXACTA
                                ; de la v1.0 original de MSX, sin el parche
                                ; que la v2.0 movio a $FC50)
    LD HL,(REGISTRO_NIVEL_CABECERA_PTR)
    LD BC,$0060                  ; 96 bytes (3 filas de 32)
    LDIR                          ; copia la cabecera ARRIBA del nivel
    LD A,(REGISTRO_NIVEL_FILAS)
    LD L,A
    LD H,$00
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL                    ; HL = filas * 32
    LD C,L
    LD B,H
    LD HL,(REGISTRO_NIVEL_CUERPO_PTR)
    LD A,(CONTADOR_VUELTAS_NIVELES)
    AND A
    EXX
    LD D,A
    LD E,$00
    EXX
    JR NZ,BUCLE_COPIAR_CUERPO_NIVEL_COMODIN
BUCLE_COPIAR_CUERPO_NIVEL_SIMPLE:
    RES 7,(HL)                   ; limpia el bit "comido" de la celda
    LDI
    LD A,B
    OR C
    JR NZ,BUCLE_COPIAR_CUERPO_NIVEL_SIMPLE
    JR COPIAR_PIE_NIVEL
BUCLE_COPIAR_CUERPO_NIVEL_COMODIN:
    RES 7,(HL)
    LD A,(HL)
    LDI
    CP $3C                       ; $3C = tile comodin
    JR NZ,CONTINUAR_COPIA_CUERPO_COMODIN
    EXX
    LD A,E
    AND $01
    INC E
    CP D
    EXX
    JR Z,CONTINUAR_COPIA_CUERPO_COMODIN
    LD A,(REGISTRO_NIVEL_LOSETA_COMODIN)
    DEC DE
    LD (DE),A
    INC DE
CONTINUAR_COPIA_CUERPO_COMODIN:
    LD A,B
    OR C
    JR NZ,BUCLE_COPIAR_CUERPO_NIVEL_COMODIN
COPIAR_PIE_NIVEL:
    LD HL,(REGISTRO_NIVEL_PIE_PTR)
    LD BC,$0060                  ; 96 bytes, misma cabecera copiada ABAJO
    LDIR
    LD HL,$0000
    LD (CONTADOR_BOLAS_COMIDAS),HL
    LD BC,(REGISTRO_NIVEL_FILA_COLUMNA)
INICIALIZAR_ESTADO_NIVEL:
    DEC B
    CALL MAPEAR_COORDENADA_A_DIRECCION
    LD (POSICION_PARPADEO_BOLA),HL
    XOR A
    LD (MODO_ESPECIAL_ACTIVO),A
    LD (MODO_ESPECIAL),A
    LD (SELECTOR_SPRITE_COMECOCOS),A
    LD (MODO_ESPECIAL_CUENTA_ATRAS),A
    LD (MODO_ESPECIAL_FLAG),A
    LD A,$78
    LD (COLOR_ACTUAL),A
    LD (COLOR_GUARDADO),A
    LD (TABLA_POSICIONES_HUD+18),A               ; RESUELTO sesion 56 (antes $9E13)
    LD A,(REGISTRO_NIVEL_ICONO_HUD)
    LD (TABLA_POSICIONES_HUD+17),A               ; RESUELTO sesion 56 (antes $9E12)
    LD HL,$1018
    LD (POSICION_ACTUAL_CAMARA),HL
    CALL INICIALIZAR_ITEMS_NIVEL
    RET
; ==============================================================
;  TABLA_NIVELES ($88E0, 16 registros x 20 bytes = 320 bytes) --
;  RESUELTA POR COMPLETO (sesion 47), mismo nombre EXACTO que MSX.
;  Formato de registro IDENTICO a TABLA_NIVELES de MSX
;  (madmix_scr_body.asm:3250): DW cuerpo_ptr,cabecera_arriba_ptr,
;  cabecera_abajo_ptr / DB filas_variable,campo7(?) / DB
;  items_tipo3,items_tipo1,items_tipo2 / DB duracion_parpadeo /
;  DB tile_comodin / DB fila_ref,columna_ref / DB byte15,byte16
;  (sin identificar) / DB icono_hud / DW objetivo_bolitas.
;  CONFIRMADO comparando registro a registro con MSX: todos los
;  campos NO-puntero son IDENTICOS BYTE A BYTE (filas, items,
;  duracion, comodin, fila/columna, icono, objetivo) -- los 3
;  punteros de cada registro son logicamente distintos porque
;  apuntan a las copias Spectrum de cuerpo/cabecera de nivel. YA
;  RESUELTOS a etiquetas (CORREGIDO sesion 56 -- este comentario decia
;  "quedan en hex crudo" desde sesion 47, pero la resolucion de
;  CUERPO_Lxx/CABECERA_7F1F/7F7F/8000 en sesion 50 ya los habia
;  sustituido en las 16 entradas de la tabla, sin que se actualizara
;  esta cabecera). Ver FINDINGS.md sesiones 47 y 50.
;
;  NOTACION decimal (sesion 56, continuacion 27): la mayoria de campos
;  numericos de esta tabla se reescribieron en decimal (antes
;  hexadecimal) al confirmar por analisis de los 16 registros que asi
;  es como los habria escrito el programador original -- son
;  cantidades pensadas en decimal, no direcciones ni mascaras de bit:
;  duracion_parpadeo son SIEMPRE segundos redondos a 50Hz (50/80/150/
;  200/250 fotogramas = 1/1.6/3/4/5s; el unico valor atipico, 255, es
;  probable centinela de "maximo" en vez de una duracion literal de
;  5.1s); fila_ref/columna_ref y el par sin identificar son, en los 16
;  niveles SIN EXCEPCION, multiplos exactos de 4 -- misma unidad de
;  subpixel que REGISTRO_NIVEL_POSICION_COMECOCOS (alineada con
;  AND $FC en otras partes del motor). icono_hud se ha dejado en
;  hexadecimal a proposito: su valor no es una cantidad, es una de las
;  entradas crudas de TABLA_POSICIONES_HUD (tambien en hex), y
;  mantener la misma notacion facilita comparar ambas tablas a simple
;  vista. Cambio de notacion puro -- verificado 0 diferencias tras
;  recompilar.
; ==============================================================
TABLA_NIVELES:
; --- nivel 0 ---
    DW CUERPO_L01,CABECERA_8000,CABECERA_8000   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 22,0                    ; filas variables (total filas=3+22=25), campo7 sin identificar
    DB 5,0,0                        ; num. items tipo 3/1/2
    DB 250                             ; duracion parpadeo bola/pista especial (fotogramas = 5.00s a 50Hz)
    DB 63                             ; tile comodin
    DB 48,52                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 12,13)
    DB 24,44                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 6,11)
    DB $70                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 114                          ; objetivo de bolitas para completar el nivel
; --- nivel 1 ---
    DW CUERPO_L01,CABECERA_8000,CABECERA_8000   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 22,0                    ; filas variables (total filas=3+22=25), campo7 sin identificar
    DB 5,0,0                        ; num. items tipo 3/1/2
    DB 250                             ; duracion parpadeo bola/pista especial (fotogramas = 5.00s a 50Hz)
    DB 63                             ; tile comodin
    DB 48,52                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 12,13)
    DB 24,44                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 6,11)
    DB $70                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 114                          ; objetivo de bolitas para completar el nivel
; --- nivel 2 ---
    DW CUERPO_L02,CABECERA_8000,CABECERA_8000   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 15,1                    ; filas variables (total filas=3+15=18), campo7 sin identificar
    DB 4,0,0                        ; num. items tipo 3/1/2
    DB 250                             ; duracion parpadeo bola/pista especial (fotogramas = 5.00s a 50Hz)
    DB 64                             ; tile comodin
    DB 64,60                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 16,15)
    DB 40,0                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 10,0)
    DB $38                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 147                          ; objetivo de bolitas para completar el nivel
; --- nivel 3 ---
    DW CUERPO_L03,CABECERA_8000,CABECERA_8000   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 16,0                    ; filas variables (total filas=3+16=19), campo7 sin identificar
    DB 4,1,0                        ; num. items tipo 3/1/2
    DB 250                             ; duracion parpadeo bola/pista especial (fotogramas = 5.00s a 50Hz)
    DB 63                             ; tile comodin
    DB 64,40                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 16,10)
    DB 40,8                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 10,2)
    DB $30                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 120                          ; objetivo de bolitas para completar el nivel
; --- nivel 4 ---
    DW CUERPO_L04,CABECERA_7F1F,CABECERA_7F1F   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 15,0                    ; filas variables (total filas=3+15=18), campo7 sin identificar
    DB 3,1,0                        ; num. items tipo 3/1/2
    DB 250                             ; duracion parpadeo bola/pista especial (fotogramas = 5.00s a 50Hz)
    DB 63                             ; tile comodin
    DB 60,60                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 15,15)
    DB 40,24                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 10,6)
    DB $70                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 79                          ; objetivo de bolitas para completar el nivel
; --- nivel 5 ---
    DW CUERPO_L05,CABECERA_7F1F,CABECERA_7F1F   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 16,1                    ; filas variables (total filas=3+16=19), campo7 sin identificar
    DB 3,0,1                        ; num. items tipo 3/1/2
    DB 250                             ; duracion parpadeo bola/pista especial (fotogramas = 5.00s a 50Hz)
    DB 63                             ; tile comodin
    DB 60,60                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 15,15)
    DB 36,8                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 9,2)
    DB $38                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 101                          ; objetivo de bolitas para completar el nivel
; --- nivel 6 ---
    DW CUERPO_L06,CABECERA_8000,CABECERA_8000   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 18,0                    ; filas variables (total filas=3+18=21), campo7 sin identificar
    DB 3,0,1                        ; num. items tipo 3/1/2
    DB 250                             ; duracion parpadeo bola/pista especial (fotogramas = 5.00s a 50Hz)
    DB 64                             ; tile comodin
    DB 64,24                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 16,6)
    DB 40,16                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 10,4)
    DB $38                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 151                          ; objetivo de bolitas para completar el nivel
; --- nivel 7 ---
    DW CUERPO_L07,CABECERA_7F1F,CABECERA_7F1F   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 19,0                    ; filas variables (total filas=3+19=22), campo7 sin identificar
    DB 3,0,1                        ; num. items tipo 3/1/2
    DB 200                             ; duracion parpadeo bola/pista especial (fotogramas = 4.00s a 50Hz)
    DB 63                             ; tile comodin
    DB 8,76                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 2,19)
    DB 240,52                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 60,13)
    DB $60                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 126                          ; objetivo de bolitas para completar el nivel
; --- nivel 8 ---
    DW CUERPO_L08,CABECERA_7F7F,CABECERA_7F7F   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 15,0                    ; filas variables (total filas=3+15=18), campo7 sin identificar
    DB 3,0,1                        ; num. items tipo 3/1/2
    DB 250                             ; duracion parpadeo bola/pista especial (fotogramas = 5.00s a 50Hz)
    DB 63                             ; tile comodin
    DB 64,64                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 16,16)
    DB 40,24                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 10,6)
    DB $70                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 90                          ; objetivo de bolitas para completar el nivel
; --- nivel 9 ---
    DW CUERPO_L09,CABECERA_8000,CABECERA_8000   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 18,0                    ; filas variables (total filas=3+18=21), campo7 sin identificar
    DB 3,2,0                        ; num. items tipo 3/1/2
    DB 250                             ; duracion parpadeo bola/pista especial (fotogramas = 5.00s a 50Hz)
    DB 64                             ; tile comodin
    DB 64,44                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 16,11)
    DB 40,36                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 10,9)
    DB $38                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 168                          ; objetivo de bolitas para completar el nivel
; --- nivel 10 ---
    DW CUERPO_L10,CABECERA_8000,CABECERA_8000   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 17,0                    ; filas variables (total filas=3+17=20), campo7 sin identificar
    DB 3,0,2                        ; num. items tipo 3/1/2
    DB 50                             ; duracion parpadeo bola/pista especial (fotogramas = 1.00s a 50Hz)
    DB 63                             ; tile comodin
    DB 64,48                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 16,12)
    DB 40,24                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 10,6)
    DB $60                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 116                          ; objetivo de bolitas para completar el nivel
; --- nivel 11 ---
    DW CUERPO_L11,CABECERA_8000,CABECERA_8000   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 21,0                    ; filas variables (total filas=3+21=24), campo7 sin identificar
    DB 3,1,0                        ; num. items tipo 3/1/2
    DB 255                             ; duracion parpadeo bola/pista especial (fotogramas = 5.10s a 50Hz, probable centinela de maximo)
    DB 64                             ; tile comodin
    DB 100,28                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 25,7)
    DB 8,40                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 2,10)
    DB $70                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 287                          ; objetivo de bolitas para completar el nivel
; --- nivel 12 ---
    DW CUERPO_L12,CABECERA_7F1F,CABECERA_7F1F   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 19,1                    ; filas variables (total filas=3+19=22), campo7 sin identificar
    DB 3,1,1                        ; num. items tipo 3/1/2
    DB 250                             ; duracion parpadeo bola/pista especial (fotogramas = 5.00s a 50Hz)
    DB 65                             ; tile comodin
    DB 68,40                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 17,10)
    DB 44,16                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 11,4)
    DB $70                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 176                          ; objetivo de bolitas para completar el nivel
; --- nivel 13 ---
    DW CUERPO_L13,CABECERA_7F1F,CABECERA_7F1F   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 21,0                    ; filas variables (total filas=3+21=24), campo7 sin identificar
    DB 2,0,3                        ; num. items tipo 3/1/2
    DB 80                             ; duracion parpadeo bola/pista especial (fotogramas = 1.60s a 50Hz)
    DB 63                             ; tile comodin
    DB 64,60                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 16,15)
    DB 40,36                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 10,9)
    DB $70                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 105                          ; objetivo de bolitas para completar el nivel
; --- nivel 14 ---
    DW CUERPO_L14,CABECERA_8000,CABECERA_8000   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 23,1                    ; filas variables (total filas=3+23=26), campo7 sin identificar
    DB 2,1,2                        ; num. items tipo 3/1/2
    DB 250                             ; duracion parpadeo bola/pista especial (fotogramas = 5.00s a 50Hz)
    DB 63                             ; tile comodin
    DB 68,96                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 17,24)
    DB 100,80                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 25,20)
    DB $70                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 267                          ; objetivo de bolitas para completar el nivel
; --- nivel 15 ---
    DW CUERPO_L15,CABECERA_8000,CABECERA_8000   ; cuerpo, cabecera(arriba), cabecera(abajo)
    DB 18,1                    ; filas variables (total filas=3+18=21), campo7 sin identificar
    DB 3,1,1                        ; num. items tipo 3/1/2
    DB 150                             ; duracion parpadeo bola/pista especial (fotogramas = 3.00s a 50Hz)
    DB 63                             ; tile comodin
    DB 96,48                    ; fila/columna de referencia inicial (subpixel, /4 = loseta: 24,12)
    DB 72,16                    ; sin identificar (multiplo exacto de 4 en los 16 niveles, misma unidad de subpixel que fila/columna: /4 = 18,4)
    DB $70                            ; icono/digito HUD -- coincide con una entrada de TABLA_POSICIONES_HUD
    DW 165                          ; objetivo de bolitas para completar el nivel
; ==============================================================
;  PROCESAR_MENU_CONTROLES / TABLA_MENU_OPCIONES_CONTROL ($8A20-$8BCA,
;  427 bytes) -- RESUELTO POR COMPLETO (sesion 54), desensamblado a
;  mano instruccion a instruccion (localizado en sesion 46 dentro de
;  lo que sesion 24 habia marcado por error como parte de
;  CARGAR_NIVEL; delimitado con precision en sesion 47). Sin
;  equivalente MSX que cruzar -- este menu de seleccion de
;  teclado/joystick es propio de Spectrum. Verificacion de
;  consistencia: todos los saltos internos convergen en las mismas
;  direcciones (mismo metodo ya usado sesiones 40-41 con
;  HNDLR_MARICOCO/HNDLR_REGPUNANTOSO).
; ==============================================================
; DIBUJAR_CREDITOS ya existe como etiqueta mecanica real mas abajo, dentro
; del tramo $8C1F-$8F55 todavia sin convertir -- referenciada aqui
; tal cual, sin EQU (candidato: "parpadear borde/color mientras
; espera tecla"). INICIAR_DEMO (antes CODE_8EB3) RESUELTA POR
; COMPLETO en sesion 56 -- ver su propia cabecera de seccion.
TEMPORIZADOR_DEMO_MENU EQU $8EB1     ; variable de 2 bytes, mismo tramo
                                      ; mecanico -- cuenta atras (arranca en
                                      ; 500) de pasadas del menu antes de
                                      ; reiniciarlo (candidato a disparar la
                                      ; demo si nadie pulsa ninguna tecla).
;
; CORRECCION: CODE_8A3F ("candidata a VACIAR_CANALES_SONIDO" desde
; sesion 40) en realidad es LEER_TECLA_MENU, un segundo punto de
; entrada a este mismo menu (salta directo a leer teclas sin repetir
; el parpadeo inicial) -- llamado en vivo desde BUCLE_PRINCIPAL_JUEGO
; para revisar el menu durante la pausa. Hipotesis de sesion 40
; descartada -- ver FINDINGS.md sesion 54.
PROCESAR_MENU_CONTROLES:
    CALL DIBUJAR_CREDITOS
    LD B,$46                      ; 70 pasadas maximo antes de continuar igualmente
BUCLE_ESPERA_TECLA_MENU:
    PUSH BC
    LD HL,$0000
    LD DE,$0000
    LD BC,$4000
    LDIR                           ; NOTA: HL=DE=0 -> LDIR no mueve datos de verdad,
                                    ; se usa solo como retardo de temporizacion fijo
    POP BC
    XOR A
    IN A,($FE)
    CPL
    AND $1F
    JR NZ,TECLA_DETECTADA_MENU
    DJNZ BUCLE_ESPERA_TECLA_MENU
TECLA_DETECTADA_MENU:
    CALL ESPERAR_TECLA_SOLTADA
LEER_TECLA_MENU:                  ; segundo punto de entrada (antes CODE_8A3F, ver cabecera)
    CALL FINALIZAR_MENU_CONTROLES
    CALL APLICAR_ATRIBUTOS_MARCO_PARCIAL
REINICIAR_TEMPORIZADOR_DEMO:
    LD BC,$01F4                   ; 500
GUARDAR_TEMPORIZADOR_DEMO:
    LD (TEMPORIZADOR_DEMO_MENU),BC
    CALL DIBUJAR_TEXTOS_MENU
    CALL LEER_TECLADO_MENU
    LD A,E
    PUSH AF
    LD HL,$8AA1                   ; direccion "falsa" apilada solo para
    PUSH HL                       ; balancear PUSH/POP mas abajo (nunca se ejecuta como codigo)
    BIT 0,A                       ; bit0 = tecla "0" (JUGAR)
    JR Z,DESPACHAR_ACCION_MENU
    POP HL
    POP AF
    CALL LIMPIAR_PANTALLA_MENU
    XOR A
    LD ($6018),A
    LD (COLOR_ACTUAL),A
    CALL WAIT_VBLANK
    RET
; LIMPIAR_PANTALLA_MENU: limpia una franja de 0x90 filas del buffer de
; pantalla ($E404+), rellenando con $FF y avanzando +$20 por fila.
LIMPIAR_PANTALLA_MENU:
    LD DE,$E404
    LD B,$90
BUCLE_LIMPIAR_FRANJA_MENU:
    PUSH BC
    PUSH DE
    LD H,D
    LD L,E
    INC DE
    LD (HL),$FF
    LD BC,$0017
    LDIR
    POP HL
    LD BC,$0020
    ADD HL,BC
    EX DE,HL
    POP BC
    DJNZ BUCLE_LIMPIAR_FRANJA_MENU
    RET
; DESPACHAR_ACCION_MENU (antes DESPACHAR_OPCION_MENU) y sus 3 destinos
; SELECCIONAR_OPCION_TECLADO/_DEMO/_REDEFINIR_TECLAS (antes
; SELECCIONAR_TECLADO/_DEMO/_REDEFINIR) -- mismos nombres EXACTOS que
; MSX (sesion 56 continuacion 30, mismo rol: despacho por bit a un
; SELECCIONAR_OPCION_* concreto). Spectrum tiene 5 ramas en vez de las
; 4 de MSX (teclado/sinclair/kempston/redefine/demo frente a
; teclado/joystick/redefine/demo) -- SELECCIONAR_SINCLAIR/KEMPSTON no
; tienen equivalente MSX directo, se quedan con nombre propio.
; bit1=TECLADO(1), bit2=SINCLAIR(3), bit3=KEMPSTON(2),
; bit4=REDEFINE(4), bit5=DEMO(5) -- el orden de bits no coincide con la
; numeracion del menu (depende del orden fisico de TABLA_TECLAS_MENU).
; Si ninguno de los 5 bits esta activo, reintenta hasta que
; TEMPORIZADOR_DEMO_MENU llegue a 0 (entonces reinicia el menu entero,
; PROCESAR_MENU_CONTROLES, candidato a arrancar la demo).
DESPACHAR_ACCION_MENU:
    BIT 5,A
    JP NZ,SELECCIONAR_OPCION_DEMO
    BIT 1,A
    JP NZ,SELECCIONAR_OPCION_TECLADO
    BIT 2,A
    JP NZ,SELECCIONAR_SINCLAIR
    BIT 3,A
    JP NZ,SELECCIONAR_KEMPSTON
    BIT 4,A
    JP NZ,SELECCIONAR_OPCION_REDEFINIR_TECLAS
    POP HL                        ; descarta la direccion "falsa" $8AA1
    POP AF
    AND A
    JR NZ,REINICIAR_TEMPORIZADOR_DEMO
    LD BC,(TEMPORIZADOR_DEMO_MENU)
    DEC BC
    LD A,B
    OR C
    JP Z,PROCESAR_MENU_CONTROLES
    JR GUARDAR_TEMPORIZADOR_DEMO
; DIBUJAR_TEXTOS_MENU: dibuja las 6 cadenas de TABLA_MENU_OPCIONES_CONTROL
; (sesion 46/47) via DIBUJAR_TEXTO_VRAM, una CALL por opcion.
DIBUJAR_TEXTOS_MENU:
    LD HL,$4089
    LD DE,TABLA_MENU_OPCIONES_CONTROL     ; "1 TECLADO"
    CALL DIBUJAR_TEXTO_VRAM
    LD HL,$40C9
    LD DE,$8AF4                   ; "2 KEMPSTON"
    CALL DIBUJAR_TEXTO_VRAM
    LD HL,$4809
    LD DE,$8B02                   ; "3 SINCLAIR-SJS"
    CALL DIBUJAR_TEXTO_VRAM
    LD HL,$4869
    LD DE,$8B13                   ; "4 REDEFINE TECLAS"
    CALL DIBUJAR_TEXTO_VRAM
    LD HL,$48A9
    LD DE,$8B26                   ; "5 DEMO"
    CALL DIBUJAR_TEXTO_VRAM
    LD HL,$5009
    LD DE,$8B2E                   ; "0 JUGAR"
    JP DIBUJAR_TEXTO_VRAM
; TABLA_MENU_OPCIONES_CONTROL ($8AE7, 82 bytes): tabla de texto
; (longitud+atributo+texto) con las 6 opciones reales del menu, en el
; formato de registro que lee DIBUJAR_TEXTO_VRAM -- reformateada a
; cadenas legibles en sesion 54 (era un volcado hex crudo), igual
; convencion que usa MSX para sus tablas de texto equivalentes
; (madmix1_body.asm/madmix_scr_body.asm: DB "..." entre comillas).
; Longitud en decimal (regla del proyecto), atributo de color en hex.
TABLA_MENU_OPCIONES_CONTROL:
    DB 11,$47, "1 TECLADO  "        ; $8AE9
    DB 12,$42, "2 KEMPSTON  "       ; $8AF6
    DB 14,$42, "3 SINCLAIR-SJS"     ; $8B04
    DB $20                          ; byte suelto sin explicar, no encaja
                                    ; en el patron longitud+atributo+texto
    DB 17,$44, "4 REDEFINE TECLAS"  ; $8B15
    DB 6,$04,  "5 DEMO"             ; $8B28
    DB 9,$46,  "0 JUGAR  "          ; $8B30
SELECCIONAR_OPCION_TECLADO:
    CALL REDEFINIR_TECLAS                ; sin resolver -- solo esta opcion lo llama
    LD A,$47
    LD ($8AE8),A                  ; resalta "1 TECLADO"
    LD A,$42
    LD ($8AF5),A                  ; atributo normal "2 KEMPSTON"
    LD ($8B03),A                  ; atributo normal "3 SINCLAIR-SJS"
    LD A,$00
    LD (MODO_ENTRADA),A           ; modo 0 = TECLADO (TABLA_TECLAS_MODO_0, QAOP)
    CALL FINALIZAR_MENU_CONTROLES
    CALL APLICAR_ATRIBUTOS_MARCO_PARCIAL
    RET
SELECCIONAR_OPCION_DEMO:
    CALL INICIAR_DEMO              ; RESUELTA sesion 56 (antes CODE_8EB3)
    CALL FINALIZAR_MENU_CONTROLES
    CALL APLICAR_ATRIBUTOS_MARCO_PARCIAL
    RET
SELECCIONAR_SINCLAIR:
    LD A,$01
    LD (MODO_ENTRADA),A           ; modo 1 = SINCLAIR-SJS (TABLA_TECLAS_MODO_1A/1B)
    LD A,$47
    LD ($8B03),A                  ; resalta "3 SINCLAIR-SJS"
    LD A,$42
    LD ($8AE8),A
    LD ($8AF5),A
    RET
SELECCIONAR_KEMPSTON:
    LD A,$02
    LD (MODO_ENTRADA),A           ; modo 2 = KEMPSTON (IN A,($1F))
    LD A,$47
    LD ($8AF5),A                  ; resalta "2 KEMPSTON"
    LD A,$42
    LD ($8AE8),A
    LD ($8B03),A
    RET
SELECCIONAR_OPCION_REDEFINIR_TECLAS:
    LD A,$00
    LD (MODO_ENTRADA),A           ; modo 0 -- mismo modo que TECLADO (la propia
                                    ; redefinicion de teclas, TABLA_TECLAS_MODO_3,
                                    ; se gestiona en otro punto sin resolver)
    LD A,$47
    LD ($8AE8),A                  ; NOTA: resalta "1 TECLADO", no "4 REDEFINE
                                    ; TECLAS" -- podria ser que la opcion 4 reutilice
                                    ; el resaltado de la 1 a proposito, o un caso sin
                                    ; terminar de pulir en el original
    LD A,$42
    LD ($8B03),A
    LD ($8AF5),A
    RET
; LEER_TECLADO_MENU: escanea las 6 teclas de TABLA_TECLAS_MENU
; (0/1/2/3/4/5) reutilizando ESCANEAR_FILAS_TECLADO (igual que
; LEER_ENTRADA, sesion 45, pero con su propia tabla y B=6 en vez de 5).
; Devuelve el bitmask de 6 bits en E.
LEER_TECLADO_MENU:
    LD IX,TABLA_TECLAS_MENU
    PUSH HL
    LD HL,$8BB7                   ; byte de relleno/alineacion tras la tabla, sin uso real
    LD (HL),$00
    LD E,$00
    LD B,$06
    CALL ESCANEAR_FILAS_TECLADO
    POP HL
    RET
; TABLA_TECLAS_MENU ($8BAB, 6 pares puerto/mascara -- fila $F7=teclas
; 1-5, EF=tecla 0): orden de escaneo -> bit0=0(JUGAR), bit1=1(TECLADO),
; bit2=3(SINCLAIR), bit3=2(KEMPSTON), bit4=4(REDEFINE), bit5=5(DEMO).
TABLA_TECLAS_MENU:
    DB $F7,$10                    ; 5 -> bit5 (DEMO)
    DB $F7,$01                    ; 1 -> bit4 (REDEFINE)
    DB $F7,$02                    ; 2 -> bit3 (KEMPSTON)
    DB $F7,$04                    ; 3 -> bit2 (SINCLAIR)
    DB $F7,$08                    ; 4 -> bit1 (TECLADO)
    DB $EF,$01                    ; 0 -> bit0 (JUGAR)
    DB $00                        ; $8BB7, relleno (LEER_TECLADO_MENU lo pone a 0 cada vez, sin consumidor real)
; FINALIZAR_MENU_CONTROLES ($8BB8): limpia pantalla otra vez, deja
; pasar 1 frame (EI/HALT) y limpia el area de atributos de color
; completa ($5800-$5AFF) a negro/attr 0 -- deja la pantalla lista
; para lo que dibuje el motor real justo despues.
FINALIZAR_MENU_CONTROLES:
    CALL LIMPIAR_PANTALLA_MENU
    EI
    HALT
    LD HL,$5800
    LD DE,$5801
    LD BC,$0300
    LD (HL),$00
    LDIR
    RET
; --- ESCRIBIR_PATRON_VRAM: RESUELTA y RENOMBRADA (sesion 23), mismo
; nombre EXACTO que en MSX (madmix_scr_body.asm, $5CAF) -- mismo rol
; casi identico pese al hardware distinto (aqui no hay VRAM de VDP,
; "pantalla" es memoria mapeada normal): dibuja el patron de 8 filas
; del caracter A (indice*8 en la tabla de fuente $9EFE) en la columna
; de pantalla apuntada por HL (avanzando 1 fila de pixel por byte via
; INC H -- el truco clasico de direccionamiento de pantalla Spectrum
; dentro del mismo caracter), y ademas fija el color de esa celda:
; convierte la direccion final a su atributo correspondiente (formula
; estandar screen->attr: RRCA x3 + AND 3 + OR $58) y escribe ahi el
; byte de color recibido en AF' (heredado de DIBUJAR_TEXTO_VRAM). En
; MSX hace lo mismo en espiritu con 2 mitades VRAM (forma+color)
; separadas via LDIRVM/FILVRM -- aqui es una unica pasada porque
; forma y atributo viven en la misma memoria lineal. ---
ESCRIBIR_PATRON_VRAM:
    PUSH HL
    LD L,A
    LD H,$00
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL
    LD DE,TABLA_FUENTE_BASE             ; base aritmetica $9EFE de la formula
                                        ; base+A*8 (sesion 31: los caracteres
                                        ; reales empiezan en $9FFE, ver TABLA_FUENTE)
    ADD HL,DE
    EX DE,HL
    POP HL
    LD B,$08
BUCLE_COPIAR_PATRON_CARACTER:
    LD A,(DE)
    LD (HL),A
    INC H
    INC DE
    DJNZ BUCLE_COPIAR_PATRON_CARACTER
    DEC H
    LD A,H
    RRCA
    RRCA
    RRCA
    AND $03
    OR $58                              ; direccion de atributo ($58xx-$5Bxx)
    LD H,A
    EX AF,AF'
    LD (HL),A
    EX AF,AF'
    RET
; --- DIBUJAR_TEXTO_VRAM: RESUELTA y RENOMBRADA (sesion 23), mismo
; nombre EXACTO que en MSX (madmix_scr_body.asm, $5CD1) -- mecanismo
; PRACTICAMENTE IDENTICO instruccion a instruccion (mismo motor de
; "descompresion"/dibujado de texto): DE apunta a un registro
; [C=numero de caracteres, color/atributo, C bytes de datos]. Cada
; byte del registro >=$20 dibuja un caracter via ESCRIBIR_PATRON_VRAM
; avanzando HL; si es <$20, NO es caracter -- es un contador de
; columnas en blanco a saltar (SALTAR_COLUMNAS hace INC HL A veces). Llamada
; 32 veces en todo el motor -- es la rutina de texto/HUD mas usada del
; juego, equivalente exacto de MSX salvo que aqui HL avanza de 1 en 1
; (columna de pantalla lineal) en vez de +8 (offset dentro de un
; bloque de patrones VRAM). ---
DIBUJAR_TEXTO_VRAM:
    LD A,(DE)
    LD C,A                              ; C = numero de caracteres del registro
    INC DE
    EX AF,AF'
    LD A,(DE)                           ; color/atributo (se guarda en AF' para
                                        ; ESCRIBIR_PATRON_VRAM)
    EX AF,AF'
    INC DE
; --- BUCLE_CARACTER/CONTINUAR_CARACTER/SALTAR_COLUMNAS (antes BUCLE_
; DIBUJAR_TEXTO_VRAM/CONTINUAR_DIBUJAR_TEXTO_VRAM/SALTAR_COLUMNAS_
; BLANCO): mismos nombres EXACTOS que las etiquetas LOCALES de MSX
; (.BUCLE_CARACTER/.CONTINUAR_CARACTER/.SALTAR_COLUMNAS dentro de su
; propio DIBUJAR_TEXTO_VRAM, madmix_scr_body.asm:3810-3838) -- sesion
; 56 continuacion 32, sin punto porque este fichero no usa etiquetas
; locales. Estructura identica instruccion a instruccion. ---
BUCLE_CARACTER:
    LD A,(DE)
    CP $20                               ; <$20 -> no es caracter, ver SALTAR_COLUMNAS
    JR C,SALTAR_COLUMNAS
    PUSH HL
    PUSH DE
    CALL ESCRIBIR_PATRON_VRAM
    POP DE
    POP HL
    INC HL                               ; siguiente columna
CONTINUAR_CARACTER:
    INC DE
    DEC C
    JR NZ,BUCLE_CARACTER
    RET
SALTAR_COLUMNAS:                               ; "saltar A columnas en blanco"
    INC HL
    DEC A
    JR NZ,SALTAR_COLUMNAS
    JR CONTINUAR_CARACTER
; --- ESPERAR_TECLA_PULSADA / ESPERAR_TECLA_SOLTADA: RESUELTAS y
; RENOMBRADAS (sesion 23), mismos nombres EXACTOS que en MSX
; (madmix_scr_body.asm, $5CFE/$5D04) -- mismo rol, mecanismo Spectrum
; propio (leen el puerto ULA $FE directamente en vez de pasar por una
; rutina de escaneo de matriz de teclado tipo COMPROBAR_PULSACION de
; MSX, que aqui no existe como tal: no hace falta, el puerto ya da
; media fila entera de una vez). ---
ESPERAR_TECLA_PULSADA:
    XOR A
    IN A,($FE)
    CPL
    AND $1F
    JR Z,ESPERAR_TECLA_PULSADA
    RET
ESPERAR_TECLA_SOLTADA:
    XOR A
    IN A,($FE)
    CPL
    AND $1F
    JR NZ,ESPERAR_TECLA_SOLTADA
    RET
; ==============================================================
;  REDEFINIR_TECLAS ($8C1F-$8D67 codigo + $8D68-$9044 logica de
;  escaneo, 660 B junto con DIBUJAR_CREDITOS) -- RESUELTO POR
;  COMPLETO sesion 56 (antes CODE_8C1F, candidato desde sesion 54,
;  llamado unicamente desde SELECCIONAR_OPCION_TECLADO). Pantalla interactiva
;  de redefinicion de teclas de la opcion "4 REDEFINE TECLAS" del menu
;  de controles.
;
;  Dibuja 6 lineas (FUEGO/ARRIBA/ABAJO/IZQUIERDA/DERECHA/PAUSA -- los
;  mismos 6 nombres que las 6 entradas de TABLA_TECLAS_MODO_0) y, para
;  cada una, ESPERA_TECLA_REDEFINIDA escanea el teclado COMPLETO (las
;  8 filas via el puerto ULA, no solo las teclas de juego) hasta
;  detectar una tecla pulsada, calcula su (puerto,mascara de bit) real
;  y lo escribe DIRECTAMENTE en TABLA_TECLAS_MODO_0 ($9B45) -- esto
;  explica por que SELECCIONAR_OPCION_REDEFINIR_TECLAS fija MODO_ENTRADA=0 (sesion
;  54, "NOTA: mismo modo que TECLADO"): la redefinicion no crea una
;  tabla nueva, SOBREESCRIBE la tabla del modo QAOP por defecto. Un
;  array de 40 bytes ($8DBA, uno por tecla fisica del Spectrum)
;  evita asignar la misma tecla a 2 acciones (INICIAR_REDEFINICION_TECLAS
;  lo limpia al principio; GUARDAR_TECLA_REDEFINIDA marca cada tecla
;  usada con el bit 7).
;
;  ETIQUETA_TECLA_ESPECIAL: cuando la tecla detectada no tiene un
;  caracter imprimible razonable (Space, Symbol Shift, Caps Shift,
;  Enter -- indices de tecla $20/$21/$22/otro), sustituye la etiqueta
;  de una sola letra por su nombre completo.
; ==============================================================
PUNTERO_ESCRITURA_REDEFINICION EQU $8DE2   ; 2 bytes -- avanza por TABLA_TECLAS_MODO_0
ULTIMA_TECLA_REDEFINIDA EQU $8DE4           ; 1 byte -- indice (0-39) de la ultima tecla detectada
TABLA_TECLAS_REDEFINIDAS_USADAS EQU $8DBA   ; 40 bytes -- bit7 = "ya asignada a otra accion"
REDEFINIR_TECLAS:
    CALL FINALIZAR_MENU_CONTROLES
    CALL INICIAR_REDEFINICION_TECLAS
    LD HL,$4089
    LD DE,ETIQUETA_TECLA_FUEGO
    CALL DIBUJAR_TEXTO_VRAM
    CALL ESPERAR_TECLA_NUEVA
    LD A,$47
    EX AF,AF'
    LD A,(ULTIMA_TECLA_REDEFINIDA)
    LD HL,$4095
    CP $24
    PUSH AF
    CALL C,ETIQUETA_TECLA_ESPECIAL
    POP AF
    JR C,REDEFINIR_TECLA_ARRIBA
    CALL ESCRIBIR_PATRON_VRAM
REDEFINIR_TECLA_ARRIBA:
    LD HL,$40C9
    LD DE,ETIQUETA_TECLA_ARRIBA
    CALL DIBUJAR_TEXTO_VRAM
    CALL ESPERAR_TECLA_NUEVA
    LD A,$47
    EX AF,AF'
    LD A,(ULTIMA_TECLA_REDEFINIDA)
    LD HL,$40D5
    CP $24
    PUSH AF
    CALL C,ETIQUETA_TECLA_ESPECIAL
    POP AF
    JR C,REDEFINIR_TECLA_ABAJO
    CALL ESCRIBIR_PATRON_VRAM
REDEFINIR_TECLA_ABAJO:
    LD HL,$4809
    LD DE,ETIQUETA_TECLA_ABAJO
    CALL DIBUJAR_TEXTO_VRAM
    CALL ESPERAR_TECLA_NUEVA
    LD A,$47
    EX AF,AF'
    LD A,(ULTIMA_TECLA_REDEFINIDA)
    LD HL,$4815
    CP $24
    PUSH AF
    CALL C,ETIQUETA_TECLA_ESPECIAL
    POP AF
    JR C,REDEFINIR_TECLA_IZQUIERDA
    CALL ESCRIBIR_PATRON_VRAM
REDEFINIR_TECLA_IZQUIERDA:
    LD HL,$4849
    LD DE,ETIQUETA_TECLA_IZQUIERDA
    CALL DIBUJAR_TEXTO_VRAM
    CALL ESPERAR_TECLA_NUEVA
    LD A,$47
    EX AF,AF'
    LD A,(ULTIMA_TECLA_REDEFINIDA)
    LD HL,$4855
    CP $24
    PUSH AF
    CALL C,ETIQUETA_TECLA_ESPECIAL
    POP AF
    JR C,REDEFINIR_TECLA_DERECHA
    CALL ESCRIBIR_PATRON_VRAM
REDEFINIR_TECLA_DERECHA:
    LD HL,$4889
    LD DE,ETIQUETA_TECLA_DERECHA
    CALL DIBUJAR_TEXTO_VRAM
    CALL ESPERAR_TECLA_NUEVA
    LD A,$47
    EX AF,AF'
    LD A,(ULTIMA_TECLA_REDEFINIDA)
    LD HL,$4895
    CP $24
    PUSH AF
    CALL C,ETIQUETA_TECLA_ESPECIAL
    POP AF
    JR C,REDEFINIR_TECLA_PAUSA
    CALL ESCRIBIR_PATRON_VRAM
REDEFINIR_TECLA_PAUSA:
    LD HL,$48C9
    LD DE,ETIQUETA_TECLA_PAUSA
    CALL DIBUJAR_TEXTO_VRAM
    CALL ESPERAR_TECLA_NUEVA
    LD A,$47
    EX AF,AF'
    LD A,(ULTIMA_TECLA_REDEFINIDA)
    LD HL,$48D5
    CP $24
    PUSH AF
    CALL C,ETIQUETA_TECLA_ESPECIAL
    POP AF
    JR C,FIN_REDEFINIR_TECLAS
    CALL ESCRIBIR_PATRON_VRAM
FIN_REDEFINIR_TECLAS:
    CALL ESPERAR_TECLA_SOLTADA
    JP ESPERAR_TECLA_PULSADA
ETIQUETA_TECLA_ESPECIAL:
    CP $20
    JR NZ,ETIQUETA_TECLA_ESPECIAL_2
    LD DE,ETIQUETA_TECLA_ESPACIO
    JP DIBUJAR_TEXTO_VRAM
ETIQUETA_TECLA_ESPECIAL_2:
    CP $21
    JR NZ,ETIQUETA_TECLA_ESPECIAL_3
    LD DE,ETIQUETA_TECLA_SSHIFT
    JP DIBUJAR_TEXTO_VRAM
ETIQUETA_TECLA_ESPECIAL_3:
    CP $22
    JR NZ,ETIQUETA_TECLA_ESPECIAL_4
    LD DE,ETIQUETA_TECLA_CSHIFT
    JP DIBUJAR_TEXTO_VRAM
ETIQUETA_TECLA_ESPECIAL_4:
    LD DE,ETIQUETA_TECLA_ENTER
    JP DIBUJAR_TEXTO_VRAM
; Etiquetas de texto de REDEFINIR_TECLAS/ETIQUETA_TECLA_ESPECIAL --
; $8D15-$8D67, un registro DIBUJAR_TEXTO_VRAM por linea
; (longitud,atributo,texto). ETIQUETA_TECLA_PAUSA se usa la ULTIMA
; (REDEFINIR_TECLA_PAUSA, 6a linea) pero cae la PRIMERA en memoria.
ETIQUETA_TECLA_PAUSA:
    DB 5,$42, "PAUSA"           ; $8D15
ETIQUETA_TECLA_FUEGO:
    DB 5,$42, "FUEGO"           ; $8D1C
ETIQUETA_TECLA_ARRIBA:
    DB 6,$44, "ARRIBA"          ; $8D23
ETIQUETA_TECLA_ABAJO:
    DB 5,$44, "ABAJO"           ; $8D2B
ETIQUETA_TECLA_IZQUIERDA:
    DB 9,$44, "IZQUIERDA"       ; $8D32
ETIQUETA_TECLA_DERECHA:
    DB 7,$44, "DERECHA"         ; $8D3D
ETIQUETA_TECLA_ESPACIO:
    DB 7,$47, "ESPACIO"         ; $8D46 -- nombre especial (ver ETIQUETA_TECLA_ESPECIAL)
ETIQUETA_TECLA_SSHIFT:
    DB 7,$47, "S.SHIFT"         ; $8D4F -- SYMBOL SHIFT
ETIQUETA_TECLA_CSHIFT:
    DB 7,$47, "C.SHIFT"         ; $8D58 -- CAPS SHIFT
ETIQUETA_TECLA_ENTER:
    DB 5,$47, "ENTER"           ; $8D61 -- tambien el caso por defecto de ETIQUETA_TECLA_ESPECIAL
INICIAR_REDEFINICION_TECLAS:
    LD HL,TABLA_TECLAS_MODO_0
    LD (PUNTERO_ESCRITURA_REDEFINICION),HL
    LD HL,TABLA_TECLAS_REDEFINIDAS_USADAS
    LD B,$28
INICIAR_REDEFINICION_TECLAS_BUCLE:
    RES 7,(HL)
    INC HL
    DJNZ INICIAR_REDEFINICION_TECLAS_BUCLE
    RET
; --- ESPERAR_TECLA_NUEVA (antes ESPERAR_TECLA_REDEFINIDA): mismo
; nombre EXACTO que MSX (sesion 56 continuacion 30) -- mismo rol,
; esperar la nueva pulsacion durante la redefinicion de teclas. ---
ESPERAR_TECLA_NUEVA:
    LD HL,(PUNTERO_ESCRITURA_REDEFINICION)
ESPERAR_TECLA_REDEFINIDA_SOLTAR:
    XOR A
    IN A,($FE)
    CPL
    AND $1F
    JR NZ,ESPERAR_TECLA_REDEFINIDA_SOLTAR
ESCANEAR_TECLA_REDEFINIDA:
    LD DE,$FE00
ESCANEAR_TECLA_REDEFINIDA_PUERTO:
    LD A,D
    IN A,($FE)
    LD B,$05
ESCANEAR_TECLA_REDEFINIDA_BIT:
    RRCA
    JR NC,ESCANEAR_TECLA_REDEFINIDA_HALLADA
    INC E
    DJNZ ESCANEAR_TECLA_REDEFINIDA_BIT
    RLC D
    JR C,ESCANEAR_TECLA_REDEFINIDA_PUERTO
    JR ESCANEAR_TECLA_REDEFINIDA
ESCANEAR_TECLA_REDEFINIDA_HALLADA:
    LD A,$20
ESCANEAR_TECLA_REDEFINIDA_MASCARA:
    RRCA
    DJNZ ESCANEAR_TECLA_REDEFINIDA_MASCARA
    LD (HL),D
    INC HL
    LD (HL),A
    INC HL
    PUSH HL
    LD D,$00
    LD HL,TABLA_TECLAS_REDEFINIDAS_USADAS
    ADD HL,DE
    LD A,(HL)
    BIT 7,A
    JR Z,GUARDAR_TECLA_REDEFINIDA
    POP HL
    JR ESPERAR_TECLA_NUEVA
GUARDAR_TECLA_REDEFINIDA:
    LD (ULTIMA_TECLA_REDEFINIDA),A
    SET 7,(HL)
    POP HL
    LD (PUNTERO_ESCRITURA_REDEFINICION),HL
    RET
    LD ($585A),HL
    LD B,E
    LD D,(HL)
    LD B,C
    LD D,E
    LD B,H
    LD B,(HL)
    LD B,A
    LD D,C
    LD D,A
    LD B,L
    LD D,D
    LD D,H
    LD SP,$3332
    INC (HL)
    DEC (HL)
    JR NC,DIBUJAR_CREDITOS_MENU_L5
    JR C,DIBUJAR_CREDITOS_MENU_L5
    LD (HL),$50
    LD C,A
    LD C,C
    LD D,L
    LD E,C
    INC HL
    LD C,H
    LD C,E
    LD C,D
    LD C,B
    JR NZ,DIBUJAR_CREDITOS_MENU_L4
    LD C,L
    LD C,(HL)
    LD B,D
    NOP
    NOP
    NOP
; --- DIBUJAR_CREDITOS (antes DIBUJAR_CREDITOS_MENU): mismo nombre
; EXACTO que MSX (sesion 56 continuacion 31) -- misma secuencia
; DE/HL/CALL DIBUJAR_TEXTO_VRAM por cada linea de creditos, mismo
; orden (TITULO/PROGRAMADO_POR/NOMBRE_PROGRAMADOR/...). ---
DIBUJAR_CREDITOS:
    CALL FINALIZAR_MENU_CONTROLES
    LD DE,TEXTO_CREDITOS_TITULO
    LD HL,$4049
    CALL DIBUJAR_TEXTO_VRAM
    LD DE,TEXTO_CREDITOS_PROGRAMADO_POR
    LD HL,$40A4
    CALL DIBUJAR_TEXTO_VRAM
    LD DE,TEXTO_CREDITOS_NOMBRE_PROGRAMADOR
    LD HL,$40EC
DIBUJAR_CREDITOS_MENU_L4:
    CALL DIBUJAR_TEXTO_VRAM
    LD DE,TEXTO_CREDITOS_GRAFICOS_POR
    LD HL,$4824
DIBUJAR_CREDITOS_MENU_L5:
    CALL DIBUJAR_TEXTO_VRAM
    LD DE,TEXTO_CREDITOS_NOMBRE_GRAFICOS
    LD HL,$486C
    CALL DIBUJAR_TEXTO_VRAM
    LD DE,TEXTO_CREDITOS_MUSICA_POR
    LD HL,$48A4
    CALL DIBUJAR_TEXTO_VRAM
    LD DE,TEXTO_CREDITOS_NOMBRE_MUSICA
    LD HL,$48EC
    CALL DIBUJAR_TEXTO_VRAM
    LD DE,TEXTO_CREDITOS_TOPOSHOW
    LD HL,$5048
    JP DIBUJAR_TEXTO_VRAM
; Creditos del juego -- $8E30-$8EB2, un registro DIBUJAR_TEXTO_VRAM
; por linea (longitud,atributo,texto). NOMBRES ALINEADOS CON MSX
; (sesion 56 continuacion 31): las 8 etiquetas (antes ETIQUETA_
; CREDITOS_PROGRAMADOR/_NOMBRE, _GRAFICOS/_NOMBRE, _MUSICA/_NOMBRE,
; _COPYRIGHT, _TITULO) contienen el MISMO contenido byte a byte que
; TEXTO_CREDITOS_PROGRAMADO_POR/_NOMBRE_PROGRAMADOR/_GRAFICOS_POR/
; _NOMBRE_GRAFICOS/_MUSICA_POR/_NOMBRE_MUSICA/_TOPOSHOW/_TITULO de MSX
; (madmix_scr_body.asm:4221-4245) -- renombradas con los mismos
; nombres EXACTOS. Volcado en hex (no como cadena)
; porque el ultimo byte de TEXTO_CREDITOS_NOMBRE_GRAFICOS hace DOBLE
; USO: es su propio byte de control final Y, a la vez, el byte de
; longitud de TEXTO_CREDITOS_MUSICA_POR (llamadas independientes,
; direcciones fijas -- no es un fallo, ahorra 1 byte). Dibujado por
; DIBUJAR_CREDITOS (linea 1=TEXTO_CREDITOS_TITULO, ultima en
; memoria pero PRIMERA en pantalla).
TEXTO_CREDITOS_PROGRAMADO_POR: ; $8E30 -- "POGRAMADO BY:  "
    DB $0F,$42,$50,$4F,$47,$52,$41,$4D,$41,$44,$4F,$20,$42,$59,$3A,$20
    DB $20,$20
TEXTO_CREDITOS_NOMBRE_PROGRAMADOR: ; $8E42 -- "RAPHAEL GOMEZZZ"
    DB $0F,$47,$52,$41,$50,$48,$41,$45,$4C,$20,$47,$4F,$4D,$45,$5A,$5A
    DB $5A,$2E,$2E,$20
TEXTO_CREDITOS_GRAFICOS_POR:  ; $8E56 -- "GRAPHICOS BY "
    DB $0D,$42,$47,$52,$41,$50,$48,$49,$43,$4F,$53,$20,$42,$59,$20,$3A
    DB $20,$20
TEXTO_CREDITOS_NOMBRE_GRAFICOS: ; $8E68 -- "ROBERTO P.ACEBES"+$0B (byte final = ATRIBUTO/LARGO de la sig. linea, reutilizado)
    DB $11,$47,$52,$4F,$42,$45,$52,$54,$4F,$20,$50,$2E,$41,$43,$45,$42
    DB $45,$53
TEXTO_CREDITOS_MUSICA_POR:    ; $8E7A -- "MUSIC-A BY:"
    DB $0B,$42,$4D,$55,$53,$49,$43,$2D,$41,$20,$42,$59,$3A
TEXTO_CREDITOS_NOMBRE_MUSICA: ; $8E87 -- "COMILONAS"
    DB $09,$47,$43,$4F,$4D,$49,$4C,$4F,$4E,$41,$53
TEXTO_CREDITOS_TOPOSHOW: ; $8E92 -- "TOPOSHOW -1988-"
    DB $0F,$04,$54,$4F,$50,$4F,$53,$48,$4F,$57,$20,$2D,$31,$39,$38,$38
    DB $2D
TEXTO_CREDITOS_TITULO:    ; $8EA3 -- "MAD$MIX GAME"
    DB $0C,$46,$4D,$41,$44,$24,$4D,$49,$58,$20,$47,$41,$4D,$45,$00,$00
; ==============================================================
;  INICIAR_DEMO (antes CODE_8EB3, $8EB3-$8F54, 162 bytes) -- RESUELTO
;  POR COMPLETO (sesion 56). Candidato de sesion 40/54 confirmado:
;  ciclador de niveles pregrabados para el modo demo/atraccion (opcion
;  "5 DEMO" del menu de controles, SELECCIONAR_OPCION_DEMO). Recorre
;  TABLA_PERFILES_DEMO (4 entradas: nivel 1, 2, 4 y 5 -- el 3 no tiene
;  perfil propio) cargando cada nivel con CARGAR_NIVEL y reproduciendo
;  un GUION DE ENTRADA PREGRABADO en vez de leer el teclado real --
;  confirma de golpe la hipotesis abierta desde sesion 37/45 sobre
;  INDICE_CICLO_NIVELES ("guion pregrabado si esta activo, mismo
;  patron que el ciclador de demo de MSX"). Sale al pulsar cualquier
;  tecla o al agotar los 4 perfiles.
;
;  FORMATO DEL GUION (verificado desensamblando el consumidor, no solo
;  intuido por el patron de bytes): pares (umbral_frames,direccion),
;  ambos en decimal, terminados en $FF,$FF. Cada frame se incrementa
;  CONTADOR_FRAME_DEMO y se compara contra el umbral del par activo;
;  al alcanzarlo, se avanza al siguiente par y la direccion (bits0-4,
;  formato identico al puerto de teclado real) se pasa a
;  MOTOR_MOVIMIENTO_COLISION via el registro D.
;
;  CORRECCION IMPORTANTE (sesion 56): esto identifica el contenido
;  real de $DBE0-$DD17 (312 bytes), que las sesiones 53/55
;  caracterizaron como "datos/guion del generador de sonido" por
;  compartir el mismo estilo de bytes pequenos y repetitivos que la
;  zona de sonido vecina -- en realidad son GUIONES DE DEMO, sin
;  ninguna relacion con el motor de musica. Los 4 punteros de
;  TABLA_PERFILES_DEMO lo confirman sin ambiguedad: 3 caen dentro de
;  $DBE0-$DD17, y el cuarto (nivel 5) apunta a $E380 -- EXACTAMENTE el
;  inicio del otro tramo marcado "guiones de cancion/SFX sin
;  decodificar" -- confirmando que al menos el principio de ESE tramo
;  (E380-E3D7, 88 bytes) es TAMBIEN guion de demo, no musica. CERRADO
;  sesion 56: el resto de ese tramo ($E3D8-$EFB5) tambien quedo
;  identificado por completo -- 2 guiones de demo mas (E3D8-E3F1),
;  el bitmap del marco decorativo (E3F2-EFA1) y relleno a cero
;  (EFA2-EFB5). Ver cabecera de BITMAP_MARCO_DECORATIVO mas abajo. No
;  queda ningun byte sin identificar entre $DBE0 y $EFB5.
; ==============================================================
PUNTERO_GUION_DEMO EQU $8F44        ; 2 bytes -- puntero al par (umbral,direccion) activo
CONTADOR_FRAME_DEMO EQU $8F46       ; 1 byte -- frames transcurridos desde el par activo
TABLA_PERFILES_DEMO EQU $8F49       ; 4 entradas x 3 bytes (nivel,puntero_guion)
INICIAR_DEMO:
    XOR A
    LD (INDICE_CICLO_NIVELES),A
    LD ($FC01),A
    LD ($FC00),A
SIGUIENTE_PERFIL_DEMO:
    LD HL,INDICE_CICLO_NIVELES
    LD A,(HL)
    INC (HL)
    CP $04
    JP Z,ABORTAR_DEMO
CALCULAR_OFFSET_PERFIL_DEMO:
    LD L,A
    ADD A,A
    ADD A,L
    LD HL,TABLA_PERFILES_DEMO
    ADD A,L
    LD L,A
    LD A,H
CALCULAR_OFFSET_PERFIL_DEMO_ALTO:
    ADC A,$00
    LD H,A
    LD A,(HL)
    LD (NIVEL_ACTUAL),A
    INC HL
    LD C,(HL)
    INC HL
    LD B,(HL)
    LD (PUNTERO_GUION_DEMO),BC
    XOR A
    LD (VIDAS_RESTANTES),A
    LD (MODO_ESPECIAL_ACTIVO),A
    CALL CARGAR_NIVEL
    CALL INICIALIZAR_ITEMS_NIVEL
    CALL REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM
    CALL APLICAR_ATRIBUTOS_MARCO_COMPLETO
    XOR A
    LD (CONTADOR_FRAME_DEMO),A
BUCLE_FRAME_DEMO:
    CALL LEER_ENTRADA
    XOR A
    LD (MODO_ESPECIAL_ACTIVO),A
    LD IX,(PUNTERO_GUION_DEMO)
    LD HL,CONTADOR_FRAME_DEMO
    INC (HL)
    LD A,(HL)
    CP (IX+$00)
    LD A,(IX+$01)
    JR C,APLICAR_DIRECCION_DEMO
    INC IX
    INC IX
    LD (HL),$00
    LD A,(IX+$01)
    LD (PUNTERO_GUION_DEMO),IX
APLICAR_DIRECCION_DEMO:
    CP $FF
    JP Z,SIGUIENTE_PERFIL_DEMO
    AND $1F
    LD D,A
    CALL ENLACE_MOTOR_MOVIMIENTO_COLISION
    CALL WAIT_VBLANK
    CALL ACTUALIZAR_PARPADEO_BOLA
    LD B,$FE
    LD C,$FE
ESPERA_TECLA_ABORTAR_DEMO:
    LD A,B
    IN A,(C)
    CPL
    AND $1F
    JR NZ,ABORTAR_DEMO
    RLC B
    JR C,ESPERA_TECLA_ABORTAR_DEMO
    JR BUCLE_FRAME_DEMO
ABORTAR_DEMO:
    XOR A
    LD (INDICE_CICLO_NIVELES),A
    RET
; $8F43 (1 byte) y $8F47-$8F48 (2 bytes) -- sin consumidor confirmado
; (candidato: relleno/alineacion, mismo patron que otras variables
; vecinas de este bloque).
    DB $00
    DW $0000                        ; PUNTERO_GUION_DEMO, compila vacio
    DB $01                          ; CONTADOR_FRAME_DEMO, compila sin uso
    DB $00,$FC                      ; sin consumidor confirmado
    ; TABLA_PERFILES_DEMO (EQU declarada arriba) empieza aqui:
    DB 1                            ; nivel 1
    DW $DBE0                        ; guion en $DBE0 (ver GUION_DEMO_NIVEL1)
    DB 2                            ; nivel 2
    DW $DC20                        ; guion en $DC20 (ver GUION_DEMO_NIVEL2)
    DB 4                            ; nivel 4
    DW $DC90                        ; guion en $DC90 (ver GUION_DEMO_NIVEL4)
    DB 5                            ; nivel 5
    DW $E380                        ; guion en $E380 (ver GUION_DEMO_NIVEL5, dentro del otro tramo de datos)
; ==============================================================
;  SUBSISTEMA DE EFECTOS DE SONIDO CORTOS -- RESUELTO POR COMPLETO
;  (sesion 56). TERCER subsistema de sonido del juego, distinto tanto
;  del motor de musica (ISR_SONIDO/REPRODUCIR_SONIDO, $E038) como del
;  ciclador de demo (CODE_8EB3) -- mas simple que el motor de musica
;  (un solo "canal", sin comandos de guion, sin subpatrones) y de
;  proposito claramente distinto: efectos de sonido cortos de
;  jugabilidad (recoger objeto, colision, etc.), NO musica.
;
;  DISPARO: cualquier parte del juego marca un efecto pendiente
;  escribiendo su indice (0-11) en EVENTO_SONIDO_PENDIENTE ($8FD6,
;  variable YA CONOCIDA desde sesion 39 con nombre EXACTO de MSX,
;  escrita desde 24 sitios distintos -- sobre todo TABLA_MANEJADORES_LOSETA
;  y ACTIVAR_EFECTO_ITEM) -- lo que faltaba resolver era el CONSUMIDOR.
;
;  CONSUMO: DESPACHAR_EFECTO_SONIDO (antes CODE_8F55) se llama UNA VEZ
;  POR INTERRUPCION desde ENTRADA_INTERRUPCION_VBLANK ($9510, "CALL
;  TICK_REDIBUJADO_VBLANK/CALL CODE_8F55" -- ver mas abajo, cierra una pregunta
;  abierta desde sesion 1). Si hay un indice nuevo (!=$FF), lo busca
;  en TABLA_RECURSOS_SONIDO_EVENTO (mismo nombre EXACTO que la tabla
;  homologa de MSX, aunque el formato interno es mas simple: 12
;  punteros directos en vez de registros de 3 bytes canal+puntero) y
;  lo instala como "efecto activo"; siempre (haya indice nuevo o no)
;  avanza el efecto activo un paso (AVANZAR_EFECTO_SONIDO), leyendo
;  pares (duracion,periodo) hasta un $FF de fin.
;
;  TONO: INICIAR_TONO_EFECTO_SONIDO usa EL MISMO truco de contadores
;  duales automodificables que BUCLE_TONO_CANAL_A del motor de musica
;  (BC=periodo, DE=periodo/2, recarga automodificable en vez de a
;  cero -- ver FINDINGS.md sesion 56) pero con un TERCER contador
;  (HL=duracion) en vez de delegar la duracion a un flag de ISR --
;  logico, al no tener "canales" que multiplexar por interrupcion.
;  Bit de altavoz: XOR $10 (identico al bit 4 usado en BUCLE_TONO_CANAL_A).
; ==============================================================
DESPACHAR_EFECTO_SONIDO:
    DI
    LD A,(EVENTO_SONIDO_PENDIENTE)
    CP $FF
    JR Z,AVANZAR_EFECTO_SONIDO
    CP $0C
    JR C,DESPACHAR_EFECTO_SONIDO_OFFSET
    XOR A
DESPACHAR_EFECTO_SONIDO_OFFSET:
    ADD A,A
    LD E,A
    LD D,$00
    LD HL,TABLA_RECURSOS_SONIDO_EVENTO
    ADD HL,DE
    LD E,(HL)
    INC HL
    LD D,(HL)
    LD (PUNTERO_EFECTO_SONIDO_ACTUAL),DE
    LD A,$FF
    LD (EVENTO_SONIDO_PENDIENTE),A
AVANZAR_EFECTO_SONIDO:
    LD HL,(PUNTERO_EFECTO_SONIDO_ACTUAL)
    LD E,(HL)
    INC HL
    LD D,$00
    LD A,E
    CP $FF
    JR Z,FIN_AVANZAR_EFECTO_SONIDO
    LD C,(HL)
    INC HL
    LD B,$00
    LD (PUNTERO_EFECTO_SONIDO_ACTUAL),HL
    EX DE,HL
    LD A,L
    AND A
    RET Z
    CALL INICIAR_TONO_EFECTO_SONIDO
FIN_AVANZAR_EFECTO_SONIDO:
    RET
INICIAR_TONO_EFECTO_SONIDO:
    XOR A
    EX AF,AF'
    LD D,B
    LD E,C
    DEC BC
    LD ($8FA8),BC
    LD ($8FB6),DE
    SRL D
    RR E
BUCLE_EFECTO_SONIDO_A:
    DEC BC
    LD A,B
    OR C
    JR NZ,BUCLE_EFECTO_SONIDO_B
    LD BC,$0000
    EX AF,AF'
    XOR $10
    OUT ($FE),A
    EX AF,AF'
BUCLE_EFECTO_SONIDO_B:
    DEC DE
    LD A,D
    OR E
    JR NZ,BUCLE_EFECTO_SONIDO_A
    LD DE,$0000
    EX AF,AF'
    XOR $10
    OUT ($FE),A
    EX AF,AF'
    DEC HL
    LD A,H
    OR L
    JR NZ,BUCLE_EFECTO_SONIDO_A
    RET
    DI
    LD HL,$0000
    LD ($9521),HL
    EI
    RET
    DI
    LD HL,DESPACHAR_EFECTO_SONIDO
    LD ($9521),HL
    EI
    RET
; EVENTO_SONIDO_PENDIENTE ($8FD6, EQU declarada sesion 39 mas arriba) --
; el propio byte de la variable, compila a $FF ("sin evento pendiente").
    DB $FF
PUNTERO_EFECTO_SONIDO_ACTUAL:          ; $8FD7-8FD8, 2 bytes -- puntero al
                                        ; efecto activo, avanzado por
                                        ; AVANZAR_EFECTO_SONIDO. Compila
                                        ; autoreferenciado ($8FD6, su propio
                                        ; vecino) como valor de relleno sin
                                        ; significado hasta el primer disparo.
    DW $8FD6
; $8FD9-$8FDC (4 bytes) -- sin consumidor confirmado (candidato: relleno/alineacion).
    DB $46,$90,$00,$00
TABLA_RECURSOS_SONIDO_EVENTO:          ; $8FDD, 12 punteros -- mismo nombre
                                        ; EXACTO que la tabla homologa de MSX
                                        ; (formato mas simple aqui: puntero
                                        ; directo, sin byte de canal). Indices
                                        ; 8/9 y 10/11 comparten efecto.
    DW EFECTO_SONIDO_00,EFECTO_SONIDO_01,EFECTO_SONIDO_02,EFECTO_SONIDO_03
    DW EFECTO_SONIDO_04,EFECTO_SONIDO_05,EFECTO_SONIDO_06,EFECTO_SONIDO_07
    DW EFECTO_SONIDO_08,EFECTO_SONIDO_08,EFECTO_SONIDO_10,EFECTO_SONIDO_10
; Datos de los 12 efectos ($8FF5-$9049, 117 bytes): pares (duracion,periodo)
; en decimal, terminados en $FF -- mismo formato de "nota" que
; TABLA_TONOS_CANAL_A/TABLA_DURACIONES del motor de musica, pero sin
; comandos de guion (no hay $FE/$FD/$FC/$FB/$FA aqui, solo notas y fin).
EFECTO_SONIDO_02:                      ; $8FF5
    DB 4,130, 8,6, 10,10, $FF
EFECTO_SONIDO_01:                      ; $8FFC
    DB 10,2, 7,90, 18,8, $FF
EFECTO_SONIDO_HUERFANO:                ; $9003 -- mismo formato, pero NINGUNA
                                        ; entrada de TABLA_RECURSOS_SONIDO_EVENTO
                                        ; lo referencia; candidato a efecto
                                        ; sin usar/retirado, sin confirmar.
    DB 18,25, 10,40, 8,48, $FF
EFECTO_SONIDO_03:                      ; $900A
    DB 5,80, 7,60, 2,2, 8,20, $FF
EFECTO_SONIDO_04:                      ; $9013
    DB 9,40, 8,58, 7,71, 6,90, $FF
EFECTO_SONIDO_05:                      ; $901C
    DB 30,22, 18,10, $FF
EFECTO_SONIDO_06:                      ; $9021
    DB 24,20, 18,28, 15,32, 12,36, $FF
EFECTO_SONIDO_07:                      ; $902A
    DB 12,10, 18,2, 12,16, 15,8, 4,7, 18,8, 20,2, $FF
EFECTO_SONIDO_08:                      ; $9039 -- indices 8 y 9 de la tabla
    DB 20,2, 15,3, 13,8, 13,12, 10,18, 8,25, $FF
EFECTO_SONIDO_10:                      ; $9046 -- indices 10 y 11 de la tabla;
                                        ; sin pares, silencio inmediato.
    DB $FF
EFECTO_SONIDO_00:                      ; $9047
    DB 10,22, $FF
; $904A -- CORREGIDO sesion 56: sesiones anteriores habian marcado
; parte de este tramo como "CODE_9121"/"CODE_914D"/"CODE_9158" (etiquetas
; mecanicas reales, pero NINGUNA con llamador externo -- busqueda
; exhaustiva de "CODE_9121"/"CODE_914D"/"CODE_9158" en todo el fichero:
; cero referencias fuera de si mismas). Investigando por que, se
; confirmo que es DATO, no codigo: la tabla de atributos de color del
; MARCO_DECORATIVO (ver TABLA_ATRIBUTOS_MARCO_DECORATIVO,  mas
; abajo, para el hallazgo completo) -- formato RLE (valor,repeticiones),
; 136 pares. APLICAR_ATRIBUTOS_MARCO_COMPLETO la consume ENTERA (136 pares = 272 bytes,
; termina EXACTO en $9159, justo donde empieza CARGAR_MARCO_DECORATIVO, codigo real
; confirmado); APLICAR_ATRIBUTOS_MARCO_PARCIAL solo lee un PREFIJO (125 pares = 250 bytes).
TABLA_ATRIBUTOS_MARCO_DECORATIVO:      ; $904A, 272 bytes
    INCBIN data/img/marco_decorativo/atributos_904a.bin
; ==============================================================
;  MARCO DECORATIVO ($904A-$9159 datos de atributos + $9174-$918C
;  codigo + $E3F2-$EFA1 datos de bitmap) -- RESUELTO POR COMPLETO
;  sesion 56, CORRIGE un hallazgo de la misma sesion: la zona
;  $E3D8-$EF9E se habia extraido antes como "189 guiones de musica
;  huerfanos" -- el formato del reproductor de musica es tan
;  permisivo (todo byte 0x00-0xFF tiene alguna lectura valida como
;  nota o comando) que casi cualquier dato lo atraviesa sin errores;
;  la prueba de "cero fallos en 3015 bytes" que parecia confirmarlo
;  era mucho mas debil de lo que parecia. Investigando CODE_918D (ver
;  mas abajo) se encontro que CARGAR_MARCO_DECORATIVO tiene una
;  llamada real desde INICIO -- no una hipotesis, un CALL de verdad --
;  y descomprime esos mismos bytes como IMAGEN, no musica.
;
;  Formato de compresion: pares (valor,repeticiones), sin marcador de
;  fin -- el numero de pares a leer lo fija BC en cada llamada
;  (DESCOMPRIMIR_RLE_ATRIBUTOS). Descomprimir el bitmap
;  ($E3F2, 1496 pares = 2992 bytes fuente) da 6140 de los 6144 bytes
;  exactos de una pantalla completa; la tabla de atributos que lo
;  acompaña ($904A, 136 pares = 272 bytes) da 764 de los 768 bytes de
;  atributos -- ambas cifras casi exactas al tamaño real de pantalla,
;  la confirmacion mas fuerte posible de que es una imagen. Renderizada:
;  un marco de rayas diagonales rojo/blanco con adornos en las esquinas
;  (ver FINDINGS.md sesion 56 y data/img/marco_decorativo/preview.png).
;
;  CARGAR_MARCO_DECORATIVO (antes CODE_915A, llamada real desde INICIO
;  justo tras la primera espera de tecla) limpia los atributos y
;  descomprime el bitmap completo a $4000. APLICAR_ATRIBUTOS_MARCO_COMPLETO
;  (antes CODE_9174, llamada tambien desde INICIAR_DEMO y desde
;  CODE_9C99 -- sin explicar del todo por que el ciclador de demo
;  necesita reaplicar los colores del marco) y APLICAR_ATRIBUTOS_MARCO_PARCIAL
;  (antes CODE_918D, llamada desde las 5 opciones del menu de
;  controles) comparten el mismo bucle descompresor
;  (DESCOMPRIMIR_RLE_ATRIBUTOS) pero leen distinta cantidad de la
;  MISMA tabla de atributos: 136 pares (completa) o 125 (un prefijo).
; ==============================================================
CARGAR_MARCO_DECORATIVO:
    EI
    HALT
    LD HL,$5800
    LD DE,$5801
    LD BC,$02FF
    LD (HL),$00
    LDIR
    LD DE,$4000
    LD HL,BITMAP_MARCO_DECORATIVO
    LD BC,$05D8
    JR DESCOMPRIMIR_RLE_ATRIBUTOS
APLICAR_ATRIBUTOS_MARCO_COMPLETO:
    LD DE,$5800
    LD HL,TABLA_ATRIBUTOS_MARCO_DECORATIVO
    LD BC,$0088
DESCOMPRIMIR_RLE_ATRIBUTOS:
    PUSH BC
    LD A,(HL)
    INC HL
    LD B,(HL)
    INC HL
DESCOMPRIMIR_RLE_ATRIBUTOS_REPETIR:
    LD (DE),A
    INC DE
    DJNZ DESCOMPRIMIR_RLE_ATRIBUTOS_REPETIR
    POP BC
    DEC BC
    LD A,B
    OR C
    JR NZ,DESCOMPRIMIR_RLE_ATRIBUTOS
    RET
APLICAR_ATRIBUTOS_MARCO_PARCIAL:
    LD DE,$5800
    LD HL,TABLA_ATRIBUTOS_MARCO_DECORATIVO
    LD BC,$007D
    JR DESCOMPRIMIR_RLE_ATRIBUTOS
; ==============================================================
;  TABLA_SALTOS_MOTOR ($9198, 11 entradas x 3 bytes = 33 bytes) --
;  RESUELTA POR COMPLETO (sesion 34). Pendiente desde sesion 22/28:
;  "encontrar el llamador real de esta tabla". RESPUESTA: no tiene
;  llamador real -- es el antepasado directo de la tabla JT_* de MSX
;  ($8400-$8430 alli), que el port a MSX conservo integra (con una
;  entrada extra, JT_INICIO, al principio -- alli SI hace falta como
;  punto de entrada para los cargadores de disco; aqui INICIO ya tiene
;  su propio punto de entrada directo en MOTOR_INICIO, $6000, asi que
;  esta tabla nunca necesito esa entrada). Busqueda exhaustiva de
;  "$9198" y cada una de las 11 direcciones de esta tabla en todo el
;  proyecto: CERO referencias fuera de esta misma tabla -- igual que
;  MSX confirmo (sesion propia de MSX) que solo JT_INICIO de su tabla
;  tiene llamadores reales externos y las otras 11 entradas no las usa
;  nadie (cada sitio del motor llama a la etiqueta real directamente).
;
;  Las 11 entradas, en el MISMO orden que MSX (JT_MOTOR_ACTORES en
;  adelante, saltandose solo JT_INICIO): 8 de las 11 rutinas
;  destino se han verificado instruccion a instruccion identicas (o
;  con diferencias minimas de hardware) a su equivalente MSX:
;  RESET_CONTADOR_ACTORES (XOR A/LD ($91C9),A/RET -- confirma $91C9
;  como CONTADOR_ACTORES_ACTIVOS), DIBUJAR_MARCADOR_PUNTOS,
;  GESTIONAR_SCROLL, MAPEAR_LOSETA_RELATIVA_A_ABSOLUTA,
;  CONSULTAR_TIPO_LOSETA (usa TABLA_TIPOS_LOSETA, $9B85, resuelta por
;  completo en sesion 44) y
;  REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM (LD B,$24=36, igual que las
;  "36 franjas de camara" de MSX). Confirma ademas que $6016 es
;  candidato a REGISTRO_NIVEL_POSICION_COMECOCOS (posicion de camara/
;  comecocos), leido por 4 de estas rutinas igual que en MSX.
; ==============================================================
JT_MOTOR_ACTORES:
    JP MOTOR_ACTORES
JT_RESET_CONTADOR_ACTORES:
    JP RESET_CONTADOR_ACTORES
JT_WAIT_VBLANK:
    JP WAIT_VBLANK
JT_ACTIVAR_INTERRUPCION:
    JP ACTIVAR_INTERRUPCION_MODO_2
JT_LEER_ENTRADA:
    JP LEER_ENTRADA
JT_DIBUJAR_MARCADOR_PUNTOS:
    JP DIBUJAR_MARCADOR_PUNTOS
JT_GESTIONAR_SCROLL:
    JP GESTIONAR_SCROLL
JT_REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM:
    JP REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM
JT_REDIBUJAR_LOSETA_BUFFER_VRAM:
    JP REDIBUJAR_LOSETA_BUFFER_VRAM
JT_MAPEAR_LOSETA_RELATIVA_A_ABSOLUTA:
    JP MAPEAR_LOSETA_RELATIVA_A_ABSOLUTA
JT_CONSULTAR_TIPO_LOSETA:
    JP CONSULTAR_TIPO_LOSETA
MODO_ENTRADA:                     ; $91B9, 1 byte -- CONFIRMADO sesion 54 via
                                ; PROCESAR_MENU_CONTROLES/LEER_ENTRADA (candidato
                                ; desde sesion 26/45): 0=teclado(QAOP), 1=Sinclair-SJS,
                                ; 2=Kempston, resto=redefinir. Cae dentro de lo que
                                ; sesion 34 documento como puro relleno tras
                                ; TABLA_SALTOS_MOTOR -- resulta ser el primer byte de
                                ; una variable real (compila a 0 = modo por defecto),
                                ; el resto del bloque (22 bytes) sigue sin verificar.
    DB $00
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
; --- MOTOR_ACTORES: RESUELTA Y RENOMBRADA (sesion 28), mismo nombre
; EXACTO que en MSX (madmix1_body.asm, JT_MOTOR_ACTORES) -- motor de
; render de actores/personajes. Confirmado por las 4 constantes de
; guarda de entrada, en el MISMO orden y con los MISMOS valores que en
; MSX ("guardas contra 10/64/4/116", ver comentario de MOTOR_ACTORES
; alli): $91C9 (candidato CONTADOR_ACTORES_ACTIVOS, equivalente al
; $8437 de MSX) contra 10 (maximo de actores simultaneos), B contra 64
; (limite de indice de sprite -- ver PTR_TABLA_SPRITES mas abajo), E
; contra 4 y 116 (filtro de coordenadas en pantalla). Si algun guarda
; falla, descarta el actor sin dibujar (RET temprano).
;
; Un poco mas abajo (PREPARAR_REGISTRO_ACTOR en adelante, sin transcribir aqui)
; calcula IX = $9F9A + $91C9*10 -- candidato a TABLA_ACTORES_ACTIVOS,
; el array de registros de actor activos (registros de 10 bytes aqui,
; MSX usa 12) -- y lee de PTR_TABLA_SPRITES (candidato, $9E8E,
; indexada por B*4: primeros 2 bytes = puntero a los graficos reales
; del sprite, ver mas abajo). CONFIRMADO (sesion 28) que $9E8E es la
; misma tabla que responde a la pregunta "donde estan los graficos que
; selecciona SELECTOR_SPRITE_COMECOCOS" (sesion 27): B llega aqui
; siendo precisamente ese indice de sprite. Nota: aunque el guarda
; permite B hasta 63 (64 entradas x 4 bytes = 256 bytes), la tabla
; real solo tiene sitio para 28 entradas (112 bytes) antes de topar
; EXACTO con la tabla de fuente de texto ($9EFE, ESCRIBIR_PATRON_VRAM,
; sesion 23) -- sin hueco de por medio. El limite de 64 del guarda
; parece heredado de MSX sin ajustar al numero real de sprites de esta
; version; no se ha observado ningun caso real que use indices >27.
; NO reconvertida todavia a DB con etiquetas (el desensamblado
; mecanico de esos 112 bytes genera una maraña de JR autoreferenciados
; que conviene verificar con calma) -- tarea para una sesion dedicada.
;
; Sesion 56: nombradas las 31 etiquetas internas (antes CODE_91E5 y
; siguientes). Estructura confirmada: guardas de entrada -> PREPARAR_
; REGISTRO_ACTOR (localiza el registro en TABLA_ACTORES_ACTIVOS) ->
; CALCULAR_POSICION_PANTALLA_ACTOR/CALCULAR_FILA_RELATIVA_CAMARA
; (posicion en pantalla, descarta si cae fuera de la franja visible)
; -> PREPARAR_DESPACHO_DESPLAZAMIENTO fija IY a uno de dos puntos de
; entrada REALES sin llamador visible por CALL/JP directo
; (ENTRADA_DESPLAZAR_DERECHA=$9343/ENTRADA_DESPLAZAR_IZQUIERDA=$938F,
; solo alcanzables via "JP (IY)" en BUCLE_FILA_ACTOR) segun el volteo
; horizontal del actor -- BUCLE_DESPLAZAR_DERECHA/IZQUIERDA rota
; mascara+patron bit a bit (desplazamiento sub-pixel de 0-7, el mismo
; truco de precision fina que MSX resuelve con hardware VDP) y
; COMPONER_CELDA_DERECHA/IZQUIERDA escribe el resultado en pantalla,
; con un segundo paso (BUCLE_DESPLAZAR_DERECHA_2/IZQUIERDA_2) cuando el
; desplazamiento hace que el sprite ocupe una celda de pantalla extra.
; VOLTEAR_PATRON_HORIZONTAL invierte bit a bit cada byte del patron
; (truco RLC/RRA x8 clasico) cuando cambia el sentido vertical; el
; trio CALCULAR_LIMITE_INTERCAMBIO/COMPROBAR_INTERCAMBIO_NECESARIO/
; BUCLE_INTERCAMBIAR_DATOS intercambia dos regiones de datos de sprite
; cuando cambia el sentido horizontal.
; ---
MOTOR_ACTORES:
    BIT 7,E
    RET NZ
    PUSH AF
    LD A,($91C9)                  ; candidato CONTADOR_ACTORES_ACTIVOS
    CP $0A                        ; 10 = maximo de actores simultaneos
    JR NC,SALIR_MOTOR_ACTORES_GUARDA
    LD A,B                        ; B = indice de sprite (candidato)
    CP $40                        ; 64 = limite nominal de PTR_TABLA_SPRITES
    JR NC,SALIR_MOTOR_ACTORES_GUARDA
    LD A,E
    CP $04
    JR NC,COMPROBAR_GUARDA_FILA
SALIR_MOTOR_ACTORES_GUARDA:
    POP AF
    RET
COMPROBAR_GUARDA_FILA:
    CP $74
    JR NC,SALIR_MOTOR_ACTORES_GUARDA
    POP AF
    PUSH AF
    PUSH HL
    PUSH DE
    PUSH BC
    PUSH AF
    PUSH BC
    BIT 5,A
    LD HL,$91CE
    LD (HL),$90
    JR Z,PREPARAR_REGISTRO_ACTOR
    LD (HL),$B0
PREPARAR_REGISTRO_ACTOR:
    SLA E
    RES 0,D
    LD ($91C3),DE
    LD A,($91C9)
    LD L,A
    LD H,$00
    ADD HL,HL
    PUSH HL
    ADD HL,HL
    ADD HL,HL
    POP BC
    ADD HL,BC
    LD BC,$9F9A
    ADD HL,BC
    PUSH HL
    POP IX
    LD A,E
    LD HL,$94DC
    AND $F8
    RRCA
    RRCA
    RRCA
    ADD A,L
    LD L,A
    LD A,(HL)
    LD (IX+$07),A
    INC HL
    LD A,(HL)
    LD (IX+$08),A
    INC HL
    LD A,(HL)
    LD (IX+$09),A
    LD HL,$91CE
    LD A,D
    CP (HL)
    JR C,CALCULAR_POSICION_PANTALLA_ACTOR
    XOR A
CALCULAR_POSICION_PANTALLA_ACTOR:
    LD C,E
    ADD A,$10
    LD B,A
    CALL CALCULAR_DIRECCION_PANTALLA
    LD (IX+$02),L
    LD (IX+$03),H
    POP BC
    LD L,B
    LD H,$00
    ADD HL,HL
    ADD HL,HL
    LD BC,PTR_TABLA_SPRITES
    ADD HL,BC
    LD C,(HL)
    INC HL
    LD B,(HL)
    LD ($91C5),BC
    INC HL
    PUSH HL
    LD A,(HL)
    AND $07
    LD ($91CF),A
    LD A,$03
    LD ($91C7),A
    INC HL
    LD A,(HL)
    LD ($91C8),A
    LD L,$00
    LD E,A
    LD A,($91C4)
    LD D,A
    ADD A,E
    JR NC,CALCULAR_FILA_RELATIVA_CAMARA
    LD H,A
    LD A,E
    SUB H
    LD L,A
    ADD A,A
    ADD A,L
    ADD A,A
    LD L,A
    LD A,H
    JR APLICAR_DESPLAZAMIENTO_FILA
CALCULAR_FILA_RELATIVA_CAMARA:
    PUSH HL
    LD HL,$91CE
    SUB (HL)
    POP HL
    LD H,A
    LD A,E
    JR C,APLICAR_DESPLAZAMIENTO_FILA
    SUB H
    JR Z,DESCARTAR_ACTOR_FUERA_RANGO
    JR NC,APLICAR_DESPLAZAMIENTO_FILA
DESCARTAR_ACTOR_FUERA_RANGO:
    POP HL
    POP AF
    JP SALIR_MOTOR_ACTORES
APLICAR_DESPLAZAMIENTO_FILA:
    LD H,$00
    ADD HL,BC
    LD (IX+$00),L
    LD (IX+$01),H
    SRL A
    JR NZ,FIJAR_CONTADOR_FILAS_ACTOR
    INC A
FIJAR_CONTADOR_FILAS_ACTOR:
    LD (IX+$04),A
    LD HL,$91C9
    LD A,(HL)
    AND A
    JR NZ,CARGAR_PUNTERO_SPRITE_PREVIO
    LD DE,$F701
    JR GUARDAR_PUNTERO_DATOS_SPRITE
CARGAR_PUNTERO_SPRITE_PREVIO:
    LD DE,($91CA)
GUARDAR_PUNTERO_DATOS_SPRITE:
    LD (IX+$05),E
    LD (IX+$06),D
    INC (HL)
    LD A,($91C8)
    ADD A,A
    LD B,A
    POP HL
    POP AF
    AND $C0
    LD D,A
    LD A,(HL)
    AND $C0
    XOR D
    LD D,A
    AND $80
    JR Z,COMPROBAR_VOLTEO_VERTICAL
    XOR (HL)
    LD (HL),A
    CALL VOLTEAR_PATRON_HORIZONTAL
COMPROBAR_VOLTEO_VERTICAL:
    LD A,D
    AND $40
    JR Z,PREPARAR_DESPACHO_DESPLAZAMIENTO
    XOR (HL)
    LD (HL),A
    CALL CALCULAR_LIMITE_INTERCAMBIO
PREPARAR_DESPACHO_DESPLAZAMIENTO:
    DI
    LD A,($91C3)
    BIT 7,(HL)
    LD IY,ENTRADA_DESPLAZAR_DERECHA
    JR Z,CALCULAR_DESPLAZAMIENTO_SUBPIXEL
    LD L,A
    LD A,($91CF)
    AND A
    LD A,L
    JR Z,CALCULAR_DESPLAZAMIENTO_SUBPIXEL
    CPL
    LD L,A
    LD IY,ENTRADA_DESPLAZAR_IZQUIERDA
    LD A,($91CF)
    ADD A,L
    INC A
CALCULAR_DESPLAZAMIENTO_SUBPIXEL:
    AND $07
    EXX
    LD C,A
    EXX
    LD ($91CC),SP
    LD A,(IX+$04)
    LD L,(IX+$00)
    LD H,(IX+$01)
    LD SP,HL
    LD L,(IX+$05)
    LD H,(IX+$06)
BUCLE_FILA_ACTOR:
    EX AF,AF'
    POP DE
    POP BC
    EXX
    POP HL
    LD A,C
    LD B,A
    AND A
    EXX
    LD A,B
    JP (IY)
ESCRIBIR_FILA_ACTOR:
    LD (HL),C
    LD B,A
    INC HL
    EXX
    LD A,H
    EXX
    LD (HL),A
    INC HL
    LD (HL),D
    INC HL
    EXX
    LD A,L
    EXX
    LD (HL),A
    INC HL
    LD (HL),E
    INC HL
    LD (HL),B
    INC HL
    EX AF,AF'
    DEC A
    JP NZ,BUCLE_FILA_ACTOR
    LD SP,($91CC)
    LD ($91CA),HL
    EI
    JP SALIR_MOTOR_ACTORES
; ENTRADA_DESPLAZAR_DERECHA ($9343) -- destino REAL de "JP (IY)" en
; BUCLE_FILA_ACTOR cuando IY=$9343 (caso normal, sin voltear), fijado
; en PREPARAR_DESPACHO_DESPLAZAMIENTO -- sin llamador visible por CALL/
; JP directo en el listado, solo alcanzable via el registro IY.
ENTRADA_DESPLAZAR_DERECHA:
    JR Z,COMPONER_CELDA_DERECHA
    EX DE,HL
    EXX
BUCLE_DESPLAZAR_DERECHA:
    AND A
    RRA
    RR L
    RR H
    EXX
    SCF
    RR L
    RR H
    RR C
    EXX
    DJNZ BUCLE_DESPLAZAR_DERECHA
    EXX
    EX DE,HL
COMPONER_CELDA_DERECHA:
    LD (HL),E
    INC HL
    LD (HL),A
    INC HL
    LD (HL),D
    INC HL
    EXX
    LD A,L
    EXX
    LD (HL),A
    INC HL
    LD (HL),C
    INC HL
    EXX
    LD A,H
    EXX
    LD (HL),A
    INC HL
    POP DE
    POP BC
    EXX
    POP HL
    LD A,C
    LD B,A
    AND A
    EXX
    LD A,B
    JR Z,FIN_FILA_DERECHA
    EX DE,HL
    EXX
BUCLE_DESPLAZAR_DERECHA_2:
    AND A
    RRA
    RR L
    RR H
    EXX
    SCF
    RR L
    RR H
    RR C
    EXX
    DJNZ BUCLE_DESPLAZAR_DERECHA_2
    EXX
    EX DE,HL
FIN_FILA_DERECHA:
    JP ESCRIBIR_FILA_ACTOR
; ENTRADA_DESPLAZAR_IZQUIERDA ($938F) -- destino REAL de "JP (IY)" en
; BUCLE_FILA_ACTOR cuando IY=$938F (caso volteado), fijado en
; PREPARAR_DESPACHO_DESPLAZAMIENTO -- sin llamador visible por CALL/JP
; directo, solo alcanzable via el registro IY.
ENTRADA_DESPLAZAR_IZQUIERDA:
    JR Z,COMPONER_CELDA_IZQUIERDA
    EX DE,HL
    EXX
BUCLE_DESPLAZAR_IZQUIERDA:
    AND A
    RL H
    RL L
    RLA
    EXX
    SCF
    RL C
    RL H
    RL L
    EXX
    DJNZ BUCLE_DESPLAZAR_IZQUIERDA
    EXX
    EX DE,HL
COMPONER_CELDA_IZQUIERDA:
    LD (HL),E
    INC HL
    LD (HL),A
    INC HL
    LD (HL),D
    INC HL
    EXX
    LD A,L
    EXX
    LD (HL),A
    INC HL
    LD (HL),C
    INC HL
    EXX
    LD A,H
    EXX
    LD (HL),A
    INC HL
    POP DE
    POP BC
    EXX
    POP HL
    LD A,C
    LD B,A
    AND A
    EXX
    LD A,B
    JR Z,FIN_FILA_IZQUIERDA
    EX DE,HL
    EXX
BUCLE_DESPLAZAR_IZQUIERDA_2:
    AND A
    RL H
    RL L
    RLA
    EXX
    SCF
    RL C
    RL H
    RL L
    EXX
    DJNZ BUCLE_DESPLAZAR_IZQUIERDA_2
    EXX
    EX DE,HL
FIN_FILA_IZQUIERDA:
    JP ESCRIBIR_FILA_ACTOR
VOLTEAR_PATRON_HORIZONTAL:
    PUSH AF
    PUSH HL
    PUSH DE
    PUSH BC
    LD B,$30
    LD A,($91C7)
    LD C,A
    LD HL,($91C5)
BUCLE_VOLTEAR_FILA:
    PUSH BC
    PUSH HL
    LD B,C
    PUSH BC
    LD DE,$91C1
BUCLE_INVERTIR_BITS_BYTE:
    LD C,(HL)
    RLC C
    RRA
    RLC C
    RRA
    RLC C
    RRA
    RLC C
    RRA
    RLC C
    RRA
    RLC C
    RRA
    RLC C
    RRA
    RLC C
    RRA
    LD (DE),A
    INC HL
    DEC DE
    DJNZ BUCLE_INVERTIR_BITS_BYTE
    POP BC
    POP HL
    INC DE
    LD B,$00
    EX DE,HL
    LDIR
    EX DE,HL
    POP BC
    DJNZ BUCLE_VOLTEAR_FILA
    JR SALIR_MOTOR_ACTORES
CALCULAR_LIMITE_INTERCAMBIO:
    PUSH AF
    PUSH HL
    PUSH DE
    PUSH BC
    LD DE,($91C5)
    LD A,($91C8)
    ADD A,A
    LD C,A
    LD B,$00
    LD L,C
    LD H,B
    ADD HL,HL
    ADD HL,BC
    ADD HL,DE
COMPROBAR_INTERCAMBIO_NECESARIO:
    LD B,$00
    LD A,($91C7)
    ADD A,A
    LD C,A
    AND A
    SBC HL,BC
    LD A,D
    XOR H
    JR NZ,BUCLE_INTERCAMBIAR_DATOS
    LD A,E
    XOR L
    JR Z,SALIR_MOTOR_ACTORES
BUCLE_INTERCAMBIAR_DATOS:
    PUSH HL
    LD B,C
INTERCAMBIAR_BYTE:
    LD A,(DE)
    LD C,(HL)
    LD (HL),A
    LD A,C
    LD (DE),A
    INC DE
    INC HL
    DJNZ INTERCAMBIAR_BYTE
    POP HL
    LD A,D
    XOR H
    JR NZ,COMPROBAR_INTERCAMBIO_NECESARIO
    LD A,E
    XOR L
    JR NZ,COMPROBAR_INTERCAMBIO_NECESARIO
; --- SALIR_MOTOR_ACTORES (antes FIN_MOTOR_ACTORES): mismo nombre
; EXACTO que MSX (sesion 56 continuacion 30) -- mismo epilogo
; (POP BC/DE/HL/AF + RET), identico. ---
SALIR_MOTOR_ACTORES:
    POP BC
    POP DE
    POP HL
    POP AF
    RET
; ==============================================================
;  DIBUJAR_ACTORES_PENDIENTES ($945A-$94FB, 162 B) -- RESUELTO POR
;  COMPLETO sesion 56 (antes CODE_945A, encontrado tirando del hilo de
;  CODE_9534/TICK_REDIBUJADO_VBLANK). Motor de dibujado de sprites
;  ALTERNATIVO a MOTOR_ACTORES (ya resuelto sesion 28) -- consume la
;  MISMA CONTADOR_ACTORES_ACTIVOS/TABLA_ACTORES_ACTIVOS ($9F9A, 10
;  bytes/actor) que MOTOR_ACTORES rellena, pero en vez de dibujar en
;  el momento en que MOTOR_ACTORES decide la posicion, los ENCOLA y
;  este dibuja todos los pendientes de una vez, sincronizado con
;  WAIT_VBLANK (via TICK_REDIBUJADO_VBLANK) -- candidato a evitar
;  parpadeo/desgarro dibujando todos los sprites justo en el mismo
;  instante del barrido, no repartido a lo largo del frame.
;
;  Usa el truco clasico Z80 de leer datos de sprite con POP en vez de
;  LD/INC (SP se redirige a apuntar a los datos del sprite via
;  "LD SP,HL"; ($91CC) guarda el SP real mientras tanto). Por cada
;  actor pendiente (registro de 10 bytes en TABLA_ACTORES_ACTIVOS):
;  offset 2-3=direccion destino, offset 4=numero de filas, offset
;  5-6=puntero a los datos del sprite (mascara+patron intercalados,
;  consumidos via POP), offset 7-9=TRES bytes que se escriben,
;  automodificando, en 6 posiciones de BLIT_ACTOR_PENDIENTE (cada
;  offset se copia a 2 posiciones gemelas) -- normalmente esas 6
;  posiciones son la instruccion "LD (HL),A" que guarda el pixel
;  compuesto; sustituirla por otro byte (candidato: $00=NOP) permite
;  "apagar" celdas concretas de la rejilla 2x3 del sprite para formas
;  irregulares, sin necesitar una rutina de blit distinta por forma.
;  Termina restaurando SP y poniendo CONTADOR_ACTORES_ACTIVOS a 0
;  (vacia la cola para el siguiente frame).
; ==============================================================
DIBUJAR_ACTORES_PENDIENTES:
    LD A,($91C9)
    AND A
    RET Z
    LD IX,$9F9A
    LD ($91CC),SP
BUCLE_ACTOR_PENDIENTE:
    EX AF,AF'
    LD A,(IX+$07)
    LD ($9497),A
    LD ($94B5),A
    LD A,(IX+$08)
    LD ($949D),A
    LD ($94AF),A
    LD A,(IX+$09)
    LD ($94A3),A
    LD ($94A9),A
    LD L,(IX+$05)
    LD H,(IX+$06)
    LD SP,HL
    LD L,(IX+$02)
    LD H,(IX+$03)
    LD B,(IX+$04)
BLIT_ACTOR_PENDIENTE:
    POP DE
    LD A,(HL)
    AND E
    OR D
    LD (HL),A
    INC L
    POP DE
    LD A,(HL)
    AND E
    OR D
    LD (HL),A
    INC L
    POP DE
    LD A,(HL)
    AND E
    OR D
    LD (HL),A
    INC H
    POP DE
    LD A,(HL)
    AND E
    OR D
    LD (HL),A
    DEC L
    POP DE
    LD A,(HL)
    AND E
    OR D
    LD (HL),A
    DEC L
    POP DE
    LD A,(HL)
    AND E
    OR D
    LD (HL),A
    INC H
    LD A,H
    AND $06
    JP NZ,BLIT_ACTOR_PENDIENTE_SIGUIENTE_FILA
    LD A,L
    ADD A,$20
    LD L,A
    JR C,BLIT_ACTOR_PENDIENTE_SIGUIENTE_FILA
    LD A,H
    SUB $08
    LD H,A
BLIT_ACTOR_PENDIENTE_SIGUIENTE_FILA:
    DJNZ BLIT_ACTOR_PENDIENTE
    LD DE,$000A
    ADD IX,DE
    EX AF,AF'
    DEC A
    JP NZ,BUCLE_ACTOR_PENDIENTE
    LD SP,($91CC)
    XOR A
    LD ($91C9),A
    RET
    NOP
    NOP
    NOP
    NOP
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    LD (HL),A
    NOP
    NOP
    NOP
    NOP
; --- ACTIVAR_INTERRUPCION_MODO_2: RESUELTA (sesion 1 de analisis de
; madmix_body.asm). Rellena la pagina $F600-$F6FF con el byte $60 (el
; clasico truco "diamante" de interrupciones en modo 2 del Z80: como
; todos los bytes de la tabla son iguales, el vector leido durante el
; ciclo de interrupcion siempre resuelve a la palabra en $6060,
; sea cual sea el bus de datos real) -- I=$F6, IM 2. CONFIRMADO: en
; $6060 hay literalmente "JP ENTRADA_INTERRUPCION_VBLANK" (ver mas abajo,
; dentro de la zona de "datos disfrazados de codigo" que sigue a
; MOTOR_INICIO). Equivalente ROL de ACTIVAR_INTERRUPCION_MODO_1 en MSX
; (activar la interrupcion periodica del motor), pero MECANISMO
; realmente distinto -- MSX usa el modo 1 del Z80 con el VDP como
; disparador; aqui, sin VDP, se usa el modo 2 con la tabla diamante,
; la tecnica estandar en juegos de Spectrum para tener una
; interrupcion fiable de 50Hz. Nombre propio (mismo patron que
; ACTIVAR_INTERRUPCION_MODO_1) para reflejar la diferencia real de
; hardware, siguiendo la convencion del proyecto (ver
; src/README.md). ---
ACTIVAR_INTERRUPCION_MODO_2:
    LD HL,$F600
    LD D,H
    LD E,L
    INC DE
    LD (HL),$60
    LD BC,$0100
    LD A,H
    LDIR
    LD I,A
    IM 2
    RET
; --- ENTRADA_INTERRUPCION_VBLANK: la rutina de servicio de
; interrupcion real (ISR), destino del vector IM2 en $6060 (ver
; ACTIVAR_INTERRUPCION_MODO_2). MISMO NOMBRE que en MSX
; (madmix1_body.asm, $882A) -- mismo ROL exacto: es el manejador de la
; interrupcion periodica de 50Hz del motor (alli disparada por VBLANK
; del VDP, aqui por el temporizador de la ULA -- ambas son, en la
; practica, "una vez por fotograma"). Guarda TODOS los registros
; (incluidos el juego alterno EXX/EX AF,AF' e IX/IY) antes de llamar a
; TICK_REDIBUJADO_VBLANK y DESPACHAR_EFECTO_SONIDO, termina con EI/RETI.
; DESPACHAR_EFECTO_SONIDO (antes CODE_8F55) RESUELTA POR COMPLETO
; sesion 56 -- el consumidor real de EVENTO_SONIDO_PENDIENTE (variable
; ya conocida desde sesion 39), el tercer subsistema de sonido del
; juego (efectos cortos de jugabilidad, ver su propia cabecera de
; seccion). TICK_REDIBUJADO_VBLANK (antes CODE_9534) RESUELTA POR
; COMPLETO sesion 56 -- ver su propia cabecera junto a
; DIBUJAR_ACTORES_PENDIENTES para el detalle completo. CORRIGE la
; hipotesis anterior ("mantenimiento cada 256 interrupciones"): en
; realidad es una bandera de un solo uso ($91C2), NO un contador de
; 256 -- solo hace el trabajo extra cuando WAIT_VBLANK la puso a 1
; justo antes del HALT que disparo esta interrupcion en concreto. ---
ENTRADA_INTERRUPCION_VBLANK:
    PUSH AF
    PUSH HL
    PUSH DE
    PUSH BC
    EXX
    EX AF,AF'
    PUSH AF
    PUSH HL
    PUSH DE
    PUSH BC
    PUSH IX
    PUSH IY
    CALL TICK_REDIBUJADO_VBLANK
    CALL DESPACHAR_EFECTO_SONIDO
    POP IY
    POP IX
    POP BC
    POP DE
    POP HL
    POP AF
    EX AF,AF'
    EXX
    POP BC
    POP DE
    POP HL
    POP AF
    EI
    RETI
; TICK_REDIBUJADO_VBLANK (antes CODE_9534) -- se llama en TODAS las
; interrupciones (desde ENTRADA_INTERRUPCION_VBLANK) pero solo hace
; trabajo real cuando $91C2 valia exactamente 1 al entrar -- WAIT_VBLANK
; (mas abajo) es la UNICA que pone $91C2 a 1, justo antes de EI/HALT,
; asi que este bloque solo se ejecuta cuando la interrupcion que
; despierta a WAIT_VBLANK es esta misma (no cualquier otra). Los
; OUT ($FF) no van a ningun puerto real decodificado en un Spectrum de
; 48K (solo el bit0 de la direccion importa para la ULA, y $FF es
; impar) -- son relleno de temporizacion puro (11 T-estados fijos cada
; uno) alrededor de DIBUJAR_ACTORES_PENDIENTES, candidato a acotar su
; ventana de ejecucion a un numero de T-estados predecible.
TICK_REDIBUJADO_VBLANK:
    LD A,($91C2)
    LD B,A
    XOR A
    LD ($91C2),A
    INC A
    CP B
    JR NZ,FIN_TICK_REDIBUJADO_VBLANK
    CALL REFRESCAR_ESQUEMA_COLOR_NIVEL
    LD A,$01
    OUT ($FF),A
    CALL DIBUJAR_ACTORES_PENDIENTES
    XOR A
    OUT ($FF),A
FIN_TICK_REDIBUJADO_VBLANK:
    RET
; ==============================================================
;  PREPARAR_TABLA_ESQUEMA_COLOR ($954E-$95AA) -- RESUELTA sesion 56
;  (antes CODE_954E, "sin analizar todavia"). Llamada UNA SOLA VEZ
;  desde INICIO, justo despues de CARGAR_MARCO_DECORATIVO -- y ese
;  orden importa: en cuanto el marco decorativo ya esta dibujado en
;  pantalla, su bitmap/atributos fuente ($E3F2-$EFA1,
;  BITMAP_MARCO_DECORATIVO, ya resuelto) dejan de hacer falta, y esta
;  rutina REUTILIZA exactamente esa misma memoria como area de
;  trabajo para REFRESCAR_ESQUEMA_COLOR_NIVEL/BUCLE_MEZCLA_ESQUEMA_COLOR
;  (mas abajo) -- el clasico truco Spectrum de reciclar datos de carga
;  que ya no hacen falta como scratch RAM.
;
;  Escribe, con paso fijo de 31 bytes por fila (144 filas, lineas de
;  pixel 16 a 159 -- la banda central de pantalla, sin las franjas de
;  arriba/abajo), SOLO 3 de los 31 bytes de cada "fila": offset +0/+1
;  = direccion de pantalla real (via CALCULAR_DIRECCION_PANTALLA) para
;  la columna 16; offset +2/+3 = un puntero de encadenado (tabla
;  paralela con paso 32, no 31 -- se desalinea progresivamente de la
;  tabla anterior a proposito o por reciclado, sin confirmar cual);
;  offset +28/+29 = direccion de pantalla para la columna 28. El resto
;  de cada fila (24 de los 31 bytes) NO se toca -- se queda con los
;  bytes que dejo el bitmap del marco decorativo, usados como relleno
;  por BUCLE_MEZCLA_ESQUEMA_COLOR sin que su valor concreto parezca
;  importar para que el mecanismo funcione (verificado por simulacion,
;  ver mas abajo).
; ==============================================================
PREPARAR_TABLA_ESQUEMA_COLOR:
    LD HL,$E400
    LD C,$80
    LD B,$10
BUCLE_TABLA_COLUMNA_16:
    EX DE,HL
    CALL CALCULAR_DIRECCION_PANTALLA
    EX DE,HL
    LD (HL),E
    INC HL
    LD (HL),D
    LD DE,$001F
    ADD HL,DE
    INC B
    LD A,B
    CP $A0
    JR NZ,BUCLE_TABLA_COLUMNA_16
    LD HL,$E402
    LD DE,$E410
    LD BC,$0020
    LD A,$90
BUCLE_TABLA_ENCADENADO:
    LD (HL),E
    INC HL
    LD (HL),D
    DEC HL
    ADD HL,BC
    EX DE,HL
    ADD HL,BC
    EX DE,HL
    DEC A
    JR NZ,BUCLE_TABLA_ENCADENADO
    LD C,$E0
    LD B,$10
    LD HL,$E41C
BUCLE_TABLA_COLUMNA_28:
    EX DE,HL
    CALL CALCULAR_DIRECCION_PANTALLA
    EX DE,HL
    LD (HL),E
    INC HL
    LD (HL),D
    LD DE,$001F
    ADD HL,DE
    INC B
    LD A,B
    CP $A0
    JR NZ,BUCLE_TABLA_COLUMNA_28
    LD HL,$E3FF
    LD B,$90
BUCLE_TABLA_ENCADENADO_2:
    LD DE,$001F
    ADD HL,DE
    LD E,L
    LD D,H
    INC DE
    INC DE
    LD (HL),E
CONTINUAR_TABLA_ENCADENADO_2:
    INC HL
    LD (HL),D
    DJNZ BUCLE_TABLA_ENCADENADO_2
    LD (HL),$00
    RET
ESCRIBIR_COLOR_ACTUAL_X2:
    INC HL
    LD (HL),A
    INC HL
    LD (HL),A
    RET
; ==============================================================
;  REFRESCAR_ESQUEMA_COLOR_NIVEL ($95B0-$965D) -- llamada desde
;  TICK_REDIBUJADO_VBLANK (ver su cabecera) cada vez que WAIT_VBLANK
;  disparo la interrupcion que la despierta. Tres partes bien
;  diferenciadas, RESUELTAS sesion 56:
;   1) Relleno de atributos del HUD/icono de nivel: 18 filas desde
;      $5844 con el color en REGISTRO_NIVEL_ICONO_HUD, mas 4 celdas
;      sueltas ($5950/$5952/$5970/$5972) con COLOR_ACTUAL via
;      ESCRIBIR_COLOR_ACTUAL_X2 (el "LD HL,$592F" justo antes es
;      vestigial -- se sobreescribe sin usarse, igual que otros
;      vestigios ya documentados en el proyecto).
;   2) "LD HL,$0000/LD D,H/LD E,L/LD BC,$0160/LDIR": con HL=DE=$0000
;      la LDIR NO mueve ningun dato de verdad (copia cada byte sobre
;      si mismo) -- es relleno de temporizacion puro (352*21 T-estados),
;      EXACTAMENTE el mismo truco ya documentado en
;      LIMPIAR_PANTALLA_MENU/BUCLE_ESPERA_TECLA_MENU (ver mas arriba).
;      CORRIGE una lectura anterior de este mismo bloque como
;      "limpieza de 352 bytes en $0000" -- no limpia nada, $0000 es
;      ROM.
;   3) BUCLE_MEZCLA_ESQUEMA_COLOR (ver su propia cabecera): el
;      intercambio SP/PUSH/POP/EXX sobre PREPARAR_TABLA_ESQUEMA_COLOR.
; ==============================================================
REFRESCAR_ESQUEMA_COLOR_NIVEL:
    LD HL,$603B
    LD A,(HL)
    LD (HL),A
    OUT ($FE),A
    LD (HL),$00
    LD A,(REGISTRO_NIVEL_ICONO_HUD)
    LD C,A
    LD HL,$5844
    LD B,$12
BUCLE_RELLENAR_ATRIBUTOS_HUD:
    PUSH BC
    LD E,L
    LD D,H
    INC DE
    LD (HL),C
    LD BC,$0017
    LDIR
    LD BC,$0009
    ADD HL,BC
    POP BC
    DJNZ BUCLE_RELLENAR_ATRIBUTOS_HUD
    LD HL,$592F
    LD A,(COLOR_ACTUAL)
    LD HL,$594F
    CALL ESCRIBIR_COLOR_ACTUAL_X2
    LD HL,$596F
    CALL ESCRIBIR_COLOR_ACTUAL_X2
    LD HL,$0000
    LD D,H
    LD E,L
    LD BC,$0160
    LDIR
    LD A,$02
    OUT ($FF),A
    LD ($91CC),SP
    LD IX,$E400
; --- BUCLE_MEZCLA_ESQUEMA_COLOR (antes CODE_95FB): es EL VOLCADO del
; lienzo de GESTIONAR_SCROLL/REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM
; ($E404 en adelante) a la pantalla REAL entrelazada -- ALGORITMO
; DERIVADO POR COMPLETO (sesion 56, tools/mmcanvas_sim.py, instrumentado
; para registrar cada "LD SP,xx"): la tecnica es amortizar el coste de
; CALCULAR_DIRECCION_PANTALLA (~10 instrucciones de rotacion de bits)
; calculandolo UNA SOLA VEZ por nivel (en PREPARAR_TABLA_ESQUEMA_COLOR,
; ver su cabecera) en vez de una vez por byte cada fotograma.
;
; PREPARAR_TABLA_ESQUEMA_COLOR deja, dentro de cada fila de 31 bytes de
; su tabla (144 filas, una por linea de pixel jugable, $E400+), DOS
; direcciones de pantalla real YA RESUELTAS: offset+0/+1 = direccion de
; la columna de caracter 16, offset+28/+29 = columna 28 (288 llamadas a
; CALCULAR_DIRECCION_PANTALLA en total, no 3456).
;
; Este bucle recorre esa tabla usando CADA direccion pre-calculada como
; nuevo valor de SP: "LD SP,IX / POP IX/HL/AF/DE/BC / EXX / POP HL/DE/BC"
; lee 16 bytes seguidos DEL LIENZO (SP=IX apunta dentro de la fila de
; datos del laberinto, no de la tabla de direcciones) -- de ellos, el
; primer POP (a IX) trae la direccion de pantalla YA CALCULADA (la de
; columna 16, guardada ahi por PREPARAR_TABLA_ESQUEMA_COLOR). Con
; "LD SP,IX" el codigo salta a ESA direccion real y hace 2 PUSH de 6
; bytes cada uno (banco normal y alterno via EXX, 12 bytes en total) --
; como PUSH decrementa antes de escribir, esos 12 bytes caen HACIA ATRAS
; desde el ancla, cubriendo las columnas 4-15. La misma danza se repite
; una segunda vez con el segundo ancla (columna 28, tambien leido del
; mismo tramo), escribiendo hacia atras las columnas 16-27 -- entre los
; dos anclajes, las 24 columnas EXACTAS del area jugable de esa fila,
; sin huecos ni solape. Verificado columna a columna: pantalla[fila,
; columna 4..27] = lienzo[fila, byte 0..23], copia directa sin
; transformacion (el "trabajo" ya lo hizo la formula de direccionamiento
; al escribir las 2 anclas). El avance a la SIGUIENTE fila sale del
; propio HL leido en esta pasada (el "encadenado" de paso 32 que
; PREPARAR_TABLA_ESQUEMA_COLOR tambien dejo preparado) -- por eso el
; bucle entrelaza la cadena de IX con la de HL en vez de solo incrementar
; un puntero. Repite hasta que el byte alto de IX llega a 0 (fin de las
; 144 filas).
;
; VERIFICADO por simulacion (sesion 56): con un nivel real cargado antes
; (no el lienzo vacio, que fue el error de una caracterizacion previa de
; esta cabecera), escribe 3456 direcciones de pantalla real (144 filas x
; 24 columnas, $4044-$577B) cada VBLANK relevante (llamada desde
; REFRESCAR_ESQUEMA_COLOR_NIVEL via TICK_REDIBUJADO_VBLANK), estable
; fotograma a fotograma. Cierra el hallazgo del lienzo: ya no falta
; ninguna pieza del mecanismo de dibujado del laberinto.
; ---
BUCLE_MEZCLA_ESQUEMA_COLOR:
    LD SP,IX
    POP IX
    POP HL
    POP AF
    POP DE
    POP BC
    EXX
    POP HL
    POP DE
    POP BC
    LD SP,IX
    PUSH BC
    PUSH DE
    PUSH HL
    EXX
    PUSH BC
    PUSH DE
    PUSH AF
    LD SP,HL
    POP AF
    POP HL
    POP DE
    POP BC
    EXX
    POP DE
    POP BC
    POP HL
    POP IX
    LD SP,HL
    PUSH BC
    PUSH DE
    EXX
    PUSH BC
    PUSH DE
    PUSH HL
    PUSH AF
    LD SP,IX
    POP IX
    POP HL
    POP AF
    POP DE
    POP BC
    EXX
    POP HL
    POP DE
    POP BC
    LD SP,IX
    PUSH BC
    PUSH DE
    PUSH HL
    EXX
    PUSH BC
    PUSH DE
    PUSH AF
    LD SP,HL
    POP AF
    POP HL
    POP DE
    POP BC
    EXX
    POP DE
    POP BC
    POP HL
    POP IX
    LD SP,HL
    PUSH BC
    PUSH DE
    EXX
    PUSH BC
    PUSH DE
    PUSH HL
    PUSH AF
    LD A,IXH
    AND A
    JP NZ,BUCLE_MEZCLA_ESQUEMA_COLOR
    LD SP,($91CC)
    RET
; CALCULAR_DIRECCION_PANTALLA (antes CODE_9656): RESUELTA POR COMPLETO
; sesion 56 mediante derivacion algebraica bit a bit de las 10
; instrucciones (no por ejecucion) -- formula ESTANDAR de calculo de
; direccion de pantalla del Spectrum: entrada B=Y (linea de pixel,
; 0-191), C=columna<<3 (columna de 0-31 en los 5 bits altos de C, los
; 3 bits bajos de C se descartan). Salida HL = $4000 | (Y7<<12)|
; (Y6<<11)|(Y2<<10)|(Y1<<9)|(Y0<<8) | (Y5<<7)|(Y4<<6)|(Y3<<5)|columna
; -- exactamente la formula clasica de dividir Y en los tres campos
; entrelazados de la memoria de pantalla del 48K. Llamada con C=$80
; (columna 16) y C=$E0 (columna 28) por el preparador de tablas de
; REFRESCAR_ESQUEMA_COLOR_NIVEL (ver su cabecera).
CALCULAR_DIRECCION_PANTALLA:
    PUSH AF
    LD A,B
    AND A
    RRA
    SCF
    RRA
    AND A
    RRA
    XOR B
    AND $F8
    XOR B
    LD H,A
    LD A,C
    RLCA
    RLCA
    RLCA
    XOR B
    AND $C7
    XOR B
    RLCA
    RLCA
    LD L,A
    POP AF
    RET
RESET_CONTADOR_ACTORES:
    XOR A
    LD ($91C9),A
    RET
; --- WAIT_VBLANK: RESUELTA Y RENOMBRADA (sesion 26), mismo nombre
; EXACTO que en MSX (madmix1_body.asm, JT_WAIT_VBLANK en la tabla de
; saltos de START). Mecanismo: pone a 1 la bandera $91C2 (la misma que
; lee/limpia TICK_REDIBUJADO_VBLANK, el ayudante de ENTRADA_INTERRUPCION_VBLANK,
; sesion 22) y hace EI/HALT -- espera literalmente a la siguiente
; interrupcion de 50Hz antes de continuar. Es, junto con
; ENTRADA_INTERRUPCION_VBLANK, la piedra angular del ritmo de fotogramas
; del motor -- llamada 10 veces en total, incluida 2 veces seguidas
; dentro del bucle principal (BUCLE_PRINCIPAL_JUEGO, confirmado en
; sesion 34, ver mas abajo). Ademas es una de las 11 entradas de
; TABLA_SALTOS_MOTOR ($9198, sesion 22-23/34) -- tabla de saltos
; publica sin llamador real, antepasado directo de JT_* en MSX (ver
; comentario completo junto a la tabla).
WAIT_VBLANK:
    LD A,$01
    LD ($91C2),A
    EI
    HALT
    RET
GESTIONAR_SCROLL:
    LD HL,(REGISTRO_NIVEL_POSICION_COMECOCOS)
    LD C,A
    LD A,L
    AND $03
    JR Z,COMPROBAR_ALINEAMIENTO_SCROLL_Y
    LD A,C
    AND $03
    LD C,A
COMPROBAR_ALINEAMIENTO_SCROLL_Y:
    LD A,H
    AND $03
    LD A,C
    JR Z,DECIDIR_DIRECCION_SCROLL
    AND $0C
; DECIDIR_DIRECCION_SCROLL: RESUELTA (sesion 45). Orden de bits DISTINTO
; al de MSX (SCROLL_ARRIBA/ABAJO/DERECHA/IZQUIERDA-fallthrough alli) --
; aqui es DERECHA/IZQUIERDA/ABAJO/ARRIBA-fallthrough. NO es un error:
; cada version lee su propio teclado/joystick con su propio orden de
; bits, y lo unico que debe coincidir es que CADA version sea
; consistente consigo misma. Confirmado descifrando TABLA_TECLAS_MODO_0
; ($9B45, ver mas abajo): esquema QAOP clasico de Topo Soft -- Q=arriba,
; A=abajo, O=izquierda, P=derecha -- que produce exactamente este orden
; de bits (P=bit0=DERECHA, O=bit1=IZQUIERDA, A=bit2=ABAJO, Q=bit3=ARRIBA).
; Verificado tambien por un desarrollador externo con su propio
; desensamblado independiente del binario de Spectrum (mismas
; direcciones $97A9/$9760/$96BE/$96A0, mismo orden) -- ver FINDINGS.md
; sesion 45.
DECIDIR_DIRECCION_SCROLL:
    RRA
    JP C,SCROLL_DERECHA
    RRA
    JP C,SCROLL_IZQUIERDA
    RRA
    JP C,SCROLL_ABAJO
    RRA
    RET NC
SCROLL_ARRIBA:
    LD HL,$0400
    LD ($6038),HL
    LD HL,$E404
    PUSH HL
    EXX
    LD C,$00
    EXX
    LD A,$FF
    LD BC,$FFE0
    LD DE,$F5E4
    LD L,E
    LD H,D
    ADD HL,BC
    ADD HL,BC
    ADD HL,BC
    ADD HL,BC
    JR BUCLE_MOVER_BLOQUE_VERTICAL
SCROLL_ABAJO:
    LD HL,$FC00
    LD ($6038),HL
    LD HL,$F584
    PUSH HL
    EXX
    LD C,$23
    EXX
    LD A,$01
    LD BC,$0020
    LD DE,$E404
    LD L,E
    LD H,D
    ADD HL,BC
    ADD HL,BC
    ADD HL,BC
    ADD HL,BC
BUCLE_MOVER_BLOQUE_VERTICAL:
    PUSH AF
    LD A,$8C
BUCLE_LDI_VERTICAL:
    PUSH HL
    PUSH DE
    PUSH BC
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    POP BC
    POP HL
    ADD HL,BC
    EX DE,HL
    POP HL
    ADD HL,BC
    DEC A
    JP NZ,BUCLE_LDI_VERTICAL
    EXX
    LD HL,(REGISTRO_NIVEL_POSICION_COMECOCOS)
    POP AF
    ADD A,H
    LD H,A
    RES 0,L
    LD (REGISTRO_NIVEL_POSICION_COMECOCOS),HL
    ADD A,C
    LD H,A
    EXX
    POP DE
BUCLE_REDIBUJAR_FILA_VERTICAL:
    CALL MAPEAR_LOSETA_A_GRAFICO
    LD B,$20
    LD C,$FF
    LD A,$0C
BUCLE_TILE_VERTICAL:
    EX AF,AF'
    LD A,E
    LDI
    LDI
    ADD A,B
    LD E,A
    LDI
    LDI
    ADD A,B
    LD E,A
    LDI
    LDI
    ADD A,B
    LD E,A
    LDI
    LDI
    ADD A,$A2
    LD E,A
    EXX
    LD A,$04
    ADD A,L
    LD L,A
    EXX
    CALL MAPEAR_LOSETA_A_GRAFICO
    EX AF,AF'
    DEC A
    JR NZ,BUCLE_TILE_VERTICAL
    LD DE,($6038)
    RET
SCROLL_IZQUIERDA:
    LD HL,$0004
    LD ($6038),HL
    EXX
    LD C,$00
    LD D,$F0
    EXX
    LD A,$FF
    LD HL,$E404
    PUSH HL
    PUSH AF
    LD DE,$0020
    LD C,$90
BUCLE_FILA_IZQUIERDA:
    PUSH HL
    XOR A
    LD B,$02
BUCLE_RRD_IZQUIERDA:
    RRD
    INC L
    RRD
    INC L
    RRD
    INC L
    RRD
    INC L
    RRD
    INC L
    RRD
    INC L
    RRD
    INC L
    RRD
    INC L
    RRD
    INC L
    RRD
    INC L
    RRD
    INC L
    RRD
    INC L
    DJNZ BUCLE_RRD_IZQUIERDA
    POP HL
    ADD HL,DE
    DEC C
    JR NZ,BUCLE_FILA_IZQUIERDA
    JR PREPARAR_REDIBUJAR_COLUMNA
SCROLL_DERECHA:
    LD HL,$00FC
    LD ($6038),HL
    EXX
    LD C,$2F
    LD D,$0F
    EXX
    LD A,$01
    LD HL,$E41B
    PUSH HL
    PUSH AF
    LD DE,$0020
    LD C,$90
BUCLE_FILA_DERECHA:
    PUSH HL
    XOR A
    LD B,$02
BUCLE_RLD_DERECHA:
    RLD
    DEC L
    RLD
    DEC L
    RLD
    DEC L
    RLD
    DEC L
    RLD
    DEC L
    RLD
    DEC L
    RLD
    DEC L
    RLD
    DEC L
    RLD
    DEC L
    RLD
    DEC L
    RLD
    DEC L
    RLD
    DEC L
    DJNZ BUCLE_RLD_DERECHA
    POP HL
    ADD HL,DE
    DEC C
    JP NZ,BUCLE_FILA_DERECHA
PREPARAR_REDIBUJAR_COLUMNA:
    EXX
    LD HL,(REGISTRO_NIVEL_POSICION_COMECOCOS)
    POP AF
    ADD A,L
    LD L,A
    RES 0,H
    LD (REGISTRO_NIVEL_POSICION_COMECOCOS),HL
    ADD A,C
    LD L,A
    XOR D
    AND $01
    LD IX,COPIAR_COLUMNA_ALINEADA
    JR Z,PREPARAR_BUCLE_TILE_HORIZONTAL
    LD IX,COPIAR_COLUMNA_DESALINEADA
PREPARAR_BUCLE_TILE_HORIZONTAL:
    LD IY,CONTINUAR_TILE_HORIZONTAL
    LD A,D
    EXX
    POP DE
    LD C,A
    LD B,$09
BUCLE_TILE_HORIZONTAL:
    PUSH BC
    CALL MAPEAR_LOSETA_A_GRAFICO
    EX DE,HL
    JP (IX)
; CONTINUAR_TILE_HORIZONTAL ($981D) -- destino REAL de "JP (IY)" al
; final de COPIAR_COLUMNA_ALINEADA/COPIAR_COLUMNA_DESALINEADA (IY fijo
; desde PREPARAR_BUCLE_TILE_HORIZONTAL) -- sin llamador visible por
; CALL/JP directo, solo alcanzable via el registro IY.
CONTINUAR_TILE_HORIZONTAL:
    EX DE,HL
    EXX
    LD A,$04
    ADD A,H
    LD H,A
    EXX
    POP BC
    DJNZ BUCLE_TILE_HORIZONTAL
    LD DE,($6038)
    RET
; COPIAR_COLUMNA_ALINEADA ($982C) -- destino REAL de "JP (IX)" en
; BUCLE_TILE_HORIZONTAL cuando IX=$982C (columna alineada a byte,
; copia directa) -- sin llamador visible por CALL/JP directo, solo
; alcanzable via el registro IX.
COPIAR_COLUMNA_ALINEADA:
    EX DE,HL
    LD C,$FF
    LD B,$20
    LD A,$04
BUCLE_COPIAR_COLUMNA_ALINEADA:
    EX AF,AF'
    LD A,E
    LDI
    INC L
    ADD A,B
    LD E,A
    LDI
    INC L
    ADD A,B
    LD E,A
    LDI
    INC L
    ADD A,B
    LD E,A
    LDI
    INC L
    ADD A,B
    LD E,A
    LD A,D
    ADC A,$00
    LD D,A
    EX AF,AF'
    DEC A
    JP NZ,BUCLE_COPIAR_COLUMNA_ALINEADA
    EX DE,HL
    JP (IY)
; COPIAR_COLUMNA_DESALINEADA ($9855) -- destino REAL de "JP (IX)" en
; BUCLE_TILE_HORIZONTAL cuando IX=$9855 (columna con desplazamiento de
; sub-byte, mezcla via RRCA+AND+OR contra el contenido ya en pantalla)
; -- sin llamador visible por CALL/JP directo, solo alcanzable via el
; registro IX.
COPIAR_COLUMNA_DESALINEADA:
    LD B,$20
    LD A,$04
BUCLE_COPIAR_COLUMNA_DESALINEADA:
    EX AF,AF'
    LD A,(DE)
    RRCA
    RRCA
    RRCA
    RRCA
    AND C
    OR (HL)
    LD (HL),A
    INC E
    INC E
    LD A,L
    ADD A,B
    LD L,A
    LD A,(DE)
    RRCA
    RRCA
    RRCA
    RRCA
    AND C
    OR (HL)
    LD (HL),A
    INC E
    INC E
    LD A,L
    ADD A,B
    LD L,A
    LD A,(DE)
    RRCA
    RRCA
    RRCA
    RRCA
    AND C
    OR (HL)
    LD (HL),A
    INC E
    INC E
    LD A,L
    ADD A,B
    LD L,A
    LD A,(DE)
    RRCA
    RRCA
    RRCA
    RRCA
    AND C
    OR (HL)
    LD (HL),A
    INC E
    INC E
    LD A,L
    ADD A,B
    LD L,A
    LD A,H
    ADC A,$00
    LD H,A
    EX AF,AF'
    DEC A
    JP NZ,BUCLE_COPIAR_COLUMNA_DESALINEADA
    JP (IY)
; MAPEAR_LOSETA_A_GRAFICO: RESUELTA POR COMPLETO (sesion 46), mismo
; nombre EXACTO que MSX -- coincidencia INSTRUCCION A INSTRUCCION con
; su equivalente (madmix1_body.asm:1667), incluidos sus mismos
; "vestigios" ya documentados alli: el "AND $3F" (6 bits, no 7 como
; CONSULTAR_TIPO_LOSETA) es igual en ambas versiones -- no es un fallo
; de Spectrum, es asi en el original. Calcula: (a) direccion grafica
; real de la loseta en GRAFICOS_LOSETAS (=$C600+indice*32, guardada en
; $91C5, candidata a variable equivalente a $8433 de MSX, sin nombre
; confirmado alli tampoco) y (b) alterna el bit 7 de
; TABLA_TIPOS_LOSETA[indice] SOLO si el bit 7 del byte crudo de la
; celda del nivel esta activo (candidato a flag de "loseta ya
; visitada/comida"). El "AND $00" justo antes de leer (HL) anula esa
; lectura por completo -- MSX lo documenta como vestigio probable de
; una comprobacion mas compleja simplificada en algun momento del
; desarrollo original; como CONSULTAR_TIPO_LOSETA enmascara con AND
; $1F (bits 0-4), este toggle de bit 7 no afecta al despacho real de
; tipo de loseta -- efecto observable nulo en el juego, igual que en
; MSX. $91C7 (candidata a variable equivalente a $8435 de MSX, tampoco
; con nombre confirmado alli) recibe siempre el valor $02 (proposito
; exacto sin confirmar en ninguna de las 2 versiones). Ver FINDINGS.md
; sesion 46 para el detalle completo. ---
MAPEAR_LOSETA_A_GRAFICO:
    PUSH AF
    PUSH DE
    PUSH BC
    EXX
    LD A,H
    AND $7C
    RRCA
    RRCA
    LD B,A
    LD A,L
    AND $7C
    RLCA
    RR B
    RRA
    RR B
    RRA
    RR B
    RRA
    LD C,A
    PUSH BC
    EXX
    POP BC
    LD HL,$FC60
    ADD HL,BC
    LD A,(HL)
    LD B,A
    AND $7F
    LD L,$00
    RRA
    RR L
    RRA
    RR L
    RRA
    RR L
    LD H,A
    LD DE,GRAFICOS_LOSETAS
    ADD HL,DE
    LD ($91C5),HL
    EXX
    LD A,H
    AND $03
    ADD A,A
    ADD A,A
    LD E,A
    LD A,L
    RRCA
    RRCA
    LD A,E
    RLA
    EXX
    ADD A,L
    LD L,A
    PUSH HL
    LD A,$02
    LD ($91C7),A
    LD A,B
    AND $3F
    LD HL,TABLA_TIPOS_LOSETA
    ADD A,L
    LD L,A
    LD A,H
    ADC A,$00
    LD H,A
    LD A,B
    LD B,$10
    AND $80
    LD D,A
    LD A,(HL)
    AND $00
    XOR D
    LD D,A
    JR Z,RESTAURAR_Y_SALIR_MAPEAR_LOSETA
    XOR (HL)
    LD (HL),A
RESTAURAR_Y_SALIR_MAPEAR_LOSETA:
    POP HL
    POP BC
    POP DE
    POP AF
    RET
REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM:
    LD B,$24
    LD DE,$E404
    EXX
    LD HL,(REGISTRO_NIVEL_POSICION_COMECOCOS)
    EXX
BUCLE_REDIBUJAR_PANTALLA:
    PUSH BC
    EXX
    PUSH HL
    EXX
    PUSH DE
    CALL BUCLE_REDIBUJAR_FILA_VERTICAL
    POP HL
    LD BC,$0080
    ADD HL,BC
    EX DE,HL
    EXX
    POP HL
    INC H
    EXX
    POP BC
    DJNZ BUCLE_REDIBUJAR_PANTALLA
    LD HL,$0000
    CALL DIBUJAR_MARCADOR_PUNTOS
    LD B,$B0
    LD C,$48
    CALL CALCULAR_DIRECCION_PANTALLA
    PUSH HL
    EX DE,HL
    LD A,$08
BUCLE_DIBUJAR_ICONO_HUD_1:
    LD HL,$9F8E
    PUSH DE
    LD BC,$000C
    LDIR
    POP DE
    INC D
    DEC A
    JR NZ,BUCLE_DIBUJAR_ICONO_HUD_1
    POP HL
    LD BC,$0020
    ADD HL,BC
    EX DE,HL
    LD A,$08
BUCLE_DIBUJAR_ICONO_HUD_2:
    LD HL,$9F8E
    PUSH DE
    LD BC,$000C
    LDIR
    POP DE
    INC D
    DEC A
    JR NZ,BUCLE_DIBUJAR_ICONO_HUD_2
    LD A,(VIDAS_RESTANTES)
    AND A
    RET Z
    LD B,A
    LD E,$24
BUCLE_DIBUJAR_VIDAS:
    PUSH BC
    LD A,$20
    LD D,$9A
    LD B,$02
    CALL MOTOR_ACTORES
    LD A,E
    ADD A,$0C
    LD E,A
    POP BC
    DJNZ BUCLE_DIBUJAR_VIDAS
    LD HL,$9A7B
    LD (HL),$30
    LD DE,$9A7C
    LD BC,$0005
    LDIR
    LD HL,$0000
    CALL DIBUJAR_MARCADOR_PUNTOS
    RET
MAPEAR_LOSETA_RELATIVA_A_ABSOLUTA:
    PUSH AF
    PUSH BC
    LD HL,(REGISTRO_NIVEL_POSICION_COMECOCOS)
    LD D,H
    LD E,L
    LD A,H
    ADD A,B
    AND $7C
    RRCA
    RRCA
    LD B,A
    LD A,L
    ADD A,C
    AND $7C
    RLCA
    RR B
    RRA
    RR B
    RRA
    RR B
    RRA
    LD C,A
    LD HL,$FC60
    ADD HL,BC
    POP BC
    POP AF
    RET
CONSULTAR_TIPO_LOSETA:
    PUSH HL
    PUSH DE
    LD A,(HL)
    AND $7F
    LD HL,TABLA_TIPOS_LOSETA
    ADD A,L
    LD L,A
    LD A,H
    ADC A,$00
    LD H,A
    LD A,(HL)
    AND $1F
    POP DE
    POP HL
    RET
REDIBUJAR_LOSETA_BUFFER_VRAM:
    PUSH HL
    PUSH DE
    PUSH AF
    LD HL,(REGISTRO_NIVEL_POSICION_COMECOCOS)
    LD A,H
    AND $03
    LD H,A
    LD A,L
    AND $02
    RR H
    RRA
    LD L,A
    LD A,B
    ADD A,A
    ADD A,H
    LD H,A
    LD A,C
    ADD A,A
    ADD A,L
    LD L,A
    LD BC,$E404
    ADD HL,BC
    EX DE,HL
    POP AF
    AND $7F
    LD L,$00
    RRA
    RR L
    RRA
    RR L
    RRA
    RR L
    LD H,A
    LD BC,GRAFICOS_LOSETAS
    ADD HL,BC
    LD B,$10
BUCLE_COPIAR_LOSETA_VRAM:
    PUSH BC
    LDI
    LDI
    LD BC,$001E
    EX DE,HL
    ADD HL,BC
    EX DE,HL
    POP BC
    DJNZ BUCLE_COPIAR_LOSETA_VRAM
    POP DE
    POP HL
    RET
DIBUJAR_MARCADOR_PUNTOS:
    PUSH AF
    PUSH HL
    PUSH DE
    PUSH BC
    PUSH IX
    LD A,(INDICE_CICLO_NIVELES)
    AND A
    LD IX,$9A89
    JR NZ,DIBUJAR_TEXTO_MARCADOR
    EX DE,HL
    LD HL,(PUNTUACION)
    ADD HL,DE
    LD (PUNTUACION),HL
    LD A,H
    LD DE,$2710
    SBC HL,DE
    LD IX,$9A82
    JR NC,DIBUJAR_TEXTO_MARCADOR
    ADD HL,DE
    LD DE,$9A7B
    CALL CONVERTIR_PUNTUACION_A_TEXTO
    LD IX,$9A7B
; --- DIBUJAR_TEXTO_MARCADOR (antes CODE_9A30): RESUELTA sesion 56.
; Cola comun de las 3 ramas de DIBUJAR_MARCADOR_PUNTOS -- decidido ya
; que IX apunta a la etiqueta a pintar (digitos de puntuacion en
; BUFFER_DIGITOS_PUNTUACION, TEXTO_BESTIA "BESTIA" o
; TEXTO_DEMO " DEMO "), aqui se fija la posicion fija de
; pantalla del marcador (B=$B0=Y176, C=$B0->columna 22, formula de
; CALCULAR_DIRECCION_PANTALLA) y se llama a DIBUJAR_CADENA_VRAM (rutina
; de dibujo de cadena en VRAM, hermana de ESCRIBIR_PATRON_VRAM pero para
; una cadena completa terminada en $FF en vez de un solo caracter). ---
DIBUJAR_TEXTO_MARCADOR:
    LD B,$B0
    LD C,$B0
    CALL DIBUJAR_CADENA_VRAM
    POP IX
    POP BC
    POP DE
    POP HL
    POP AF
    RET
; --- CONVERTIR_PUNTUACION_A_TEXTO (antes CODE_9A3E): RESUELTA sesion
; 56. Convierte el valor binario de HL (la puntuacion) en digitos ASCII
; escritos en el buffer apuntado por DE ($9A7B, BUFFER_DIGITOS_PUNTUACION)
; mediante division por resta repetida contra TABLA_VALORES_DECIMAL_
; PUNTUACION (1000,100,10). Guarda la direccion del buffer en el par DE
; sombra (EXX) como puntero de escritura fijo, mientras el DE primario
; hace de contador de posicion dentro del buffer (INC E en
; ESCRIBIR_DIGITO_PUNTUACION). ---
CONVERTIR_PUNTUACION_A_TEXTO:
    PUSH DE
    EXX
    POP DE
    EXX
    LD IX,$9A75
    LD DE,$0000
; --- BUCLE_CONVERTIR_PUNTUACION (antes CODE_9A49): RESUELTA sesion 56
; (nombre ya anticipado en el comentario de TABLA_VALORES_DECIMAL_
; PUNTUACION, mas abajo). Por cada divisor de la tabla (1000,100,10):
; lo carga en BC y resetea el contador de digito (A=0). Se detiene --
; cae fuera del bucle sin volver aqui-- en cuanto el divisor leido es
; 10, que hace doble uso de centinela de fin de tabla. ---
BUCLE_CONVERTIR_PUNTUACION:
    XOR A
    LD C,(IX+$00)
    LD B,(IX+$01)
    INC IX
    INC IX
; --- BUCLE_RESTAR_DIVISOR (antes CODE_9A54): RESUELTA sesion 56. Resta
; el divisor actual (BC) de HL repetidamente mientras no haya acarreo,
; contando en A cuantas veces cupo -- ese conteo es el digito decimal
; correspondiente a este divisor (division por resta repetida). ---
BUCLE_RESTAR_DIVISOR:
    INC A
    SBC HL,BC
    JR NC,BUCLE_RESTAR_DIVISOR
    DEC A
    CALL ESCRIBIR_DIGITO_PUNTUACION
    ADD HL,BC
    LD A,B
    OR C
    CP $0A
    JR NZ,BUCLE_CONVERTIR_PUNTUACION
    LD A,L
    CALL ESCRIBIR_DIGITO_PUNTUACION
    RET
; --- ESCRIBIR_DIGITO_PUNTUACION (antes CODE_9A69): RESUELTA sesion 56.
; Escribe un digito ya calculado (en A, valor binario 0-9) como caracter
; ASCII ($30+digito) en la posicion actual del buffer (direccion en el
; DE sombra + offset del DE primario), y avanza el offset (INC E) para
; el siguiente digito. ---
ESCRIBIR_DIGITO_PUNTUACION:
    PUSH HL
    EXX
    PUSH DE
    EXX
    POP HL
    ADD HL,DE
    ADD A,$30
    LD (HL),A
    POP HL
    INC E
    RET
; --- $9A75-$9A8F: DATOS DISFRAZADOS DE CODIGO -- RESUELTO sesion 56.
; El desensamblado mecanico decodificaba esta zona como instrucciones
; con sentido superficial (mismo fenomeno ya visto en otras tablas del
; fichero), pero es DATA real, confirmada por las referencias directas
; "LD IX,$9A75/$9A7B/$9A82/$9A89" en el codigo de alrededor:
;  - TABLA_VALORES_DECIMAL_PUNTUACION ($9A75, 3 palabras: 1000,100,10)
;    -- divisores para convertir PUNTUACION (binario) a texto decimal
;    por resta repetida; leida por BUCLE_CONVERTIR_PUNTUACION, que se
;    detiene al llegar precisamente al divisor 10 (el propio valor 10
;    hace doble uso de centinela de fin de tabla).
;  - BUFFER_DIGITOS_PUNTUACION ($9A7B, 6 bytes "000000" + $FF) -- donde
;    se escriben los digitos formateados, despues dibujado en pantalla
;    con la MISMA rutina de patrones de fuente que ESCRIBIR_PATRON_VRAM
;    (indices de caracter, no ASCII estandar, aunque coinciden con
;    ASCII en el rango de digitos y letras usado aqui).
;  - TEXTO_BESTIA ($9A82, "BESTIA"+$FF) -- se dibuja en
;    vez del marcador cuando la puntuacion alcanza el limite ($2710=
;    10000) en vez de seguir formateando digitos.
;  - TEXTO_DEMO ($9A89, " DEMO "+$FF) -- se dibuja en vez
;    del marcador mientras el ciclador de demo esta activo
;    (INDICE_CICLO_NIVELES != 0).
;
; NOMBRES ALINEADOS CON MSX (sesion 56 continuacion 31): BUFFER_
; DIGITOS_PUNTUACION (antes BUFFER_TEXTO_PUNTUACION), TEXTO_BESTIA
; (antes ETIQUETA_PUNTUACION_MAXIMA) y TEXTO_DEMO (antes ETIQUETA_
; PUNTUACION_DEMO) -- MSX tiene el MISMO contenido byte a byte con
; esos mismos nombres exactos (madmix1_body.asm:2188-2193).
TABLA_VALORES_DECIMAL_PUNTUACION:
    DW 1000,100,10
BUFFER_DIGITOS_PUNTUACION:
    DB $30,$30,$30,$30,$30,$30,$FF
TEXTO_BESTIA:
    DB $42,$45,$53,$54,$49,$41,$FF        ; "BESTIA"
TEXTO_DEMO:
    DB $20,$44,$45,$4D,$4F,$20,$FF        ; " DEMO "
; --- DIBUJAR_CADENA_VRAM (antes CODE_9A90): RESUELTA sesion 56.
; Hermana de ESCRIBIR_PATRON_VRAM pero para una cadena completa: IX
; apunta a una secuencia de indices de patron de fuente terminada en
; $FF (digitos ya convertidos, o las etiquetas fijas "BESTIA"/" DEMO "),
; B/C = posicion de pantalla inicial (formato de CALCULAR_DIRECCION_
; PANTALLA). Dibuja cada caracter y avanza la posicion de columna,
; con el mismo manejo de salto de tercio de pantalla que el resto de
; rutinas de dibujo de texto del motor. ---
DIBUJAR_CADENA_VRAM:
    CALL CALCULAR_DIRECCION_PANTALLA
    EX DE,HL
; --- BUCLE_DIBUJAR_CARACTER (antes CODE_9A94): RESUELTA sesion 56.
; Bucle por caracter: lee el siguiente indice de IX (fin de cadena si
; es $FF), y calcula la direccion del patron de fuente correspondiente
; (misma formula base+A*8 que ESCRIBIR_PATRON_VRAM, TABLA_FUENTE_BASE
; $9EFE + $9FFE por la resta de H en vez de suma explicita de DE). ---
BUCLE_DIBUJAR_CARACTER:
    LD A,(IX+$00)
    INC IX
    CP $FF
    RET Z
    PUSH DE
    LD L,A
    LD H,$00
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL
    DEC H
    LD BC,$9FFE
    ADD HL,BC
    LD B,$08
; --- BUCLE_COPIAR_FILA_DOBLE (antes CODE_9AAA): RESUELTA sesion 56.
; Bucle por fila del patron (8 iteraciones): copia el byte de fuente y
; lo escribe DOS VECES seguidas (duplicar la fila -- doble altura, 16
; lineas de pixel por caracter en vez de 8), avanza el puntero de
; fuente, y comprueba el cruce de tercio de pantalla (AND $06, mismo
; chequeo estandar que en otras rutinas de dibujo de texto del motor,
; adaptado a que D avanza de 2 en 2 por la duplicacion). Las 3
; sub-etapas mecanicas (duplicar fila / avanzar fuente / iniciar
; chequeo) no tienen salto entrante propio -- caida directa, sin
; nombre individual. ---
BUCLE_COPIAR_FILA_DOBLE:
    LD A,(HL)
    LD (DE),A
    INC D
    LD (DE),A                          ; duplica la fila (doble altura)
    INC D
    INC HL                              ; avanza puntero de fuente
    LD A,D
    AND $06                             ; chequeo de cruce de tercio de pantalla
    JP NZ,CONTINUAR_FILA_DOBLE
    LD A,E
    ADD A,$20
    LD E,A
    JR C,CONTINUAR_FILA_DOBLE
    LD A,D
    SUB $08
    LD D,A
CONTINUAR_FILA_DOBLE:
    DJNZ BUCLE_COPIAR_FILA_DOBLE
    POP DE
    INC E
    JR BUCLE_DIBUJAR_CARACTER
; --- LEER_ENTRADA: RESUELTA Y RENOMBRADA (sesion 26), mismo nombre
; EXACTO que en MSX (madmix1_body.asm, $8E3C, JT_LEER_ENTRADA) --
; coincidencia estructural muy fuerte, casi instruccion a instruccion:
;   - $9B84 = FLAG_ENTRADA_BLOQUEADA (bit 0: si esta activo, RET
;     inmediato -- misma puerta de bloqueo que en MSX).
;   - $9B81 = ACUMULADOR_ENTRADA (se limpia si A=0 al entrar, se deja
;     acumular si A!=0 -- mismo convenio que MSX). Aqui ademas guarda
;     el valor anterior en $9B83 antes de limpiar (paso extra sin
;     equivalente MSX, sin analizar).
;   - Segun ($91B9) (candidato MODO_ENTRADA) despacha a distintas
;     tablas de teclas ($9B45/$9B72, y 2 destinos mas via
;     LEER_JOYSTICK_SINCLAIR/LEER_JOYSTICK_KEMPSTON) -- Spectrum
;     distingue mas de 2 modos (CP $02 con 3 ramas) frente al simple
;     0/no-0 de MSX: CONFIRMADO en sesion 56 que es soporte de 2 tipos
;     de joystick ademas del teclado (Sinclair Interface 2 emulado por
;     teclado, y Kempston real via IN A,($1F)).
;   - ESCANEAR_FILAS_TECLADO (mas abajo) hace el mismo bucle de 5
;     lecturas con RL E que ESCANEAR_FILAS_TECLADO en MSX, y
;     COMPROBAR_PAUSA (mas abajo, SET 5,E -- MISMO numero de bit que
;     en MSX) es la 6a prueba compartida.
; Es la entrada 5 de TABLA_SALTOS_MOTOR ($9198), en la MISMA posicion
; relativa que JT_LEER_ENTRADA en MSX respecto a
; JT_WAIT_VBLANK/JT_ACTIVAR_INTERRUPCION (3 seguidas en el mismo orden
; en ambas versiones) -- tabla resuelta por completo en sesion 34
; (sin llamador real, antepasado directo de JT_* en MSX). ---
LEER_ENTRADA:
    LD HL,FLAG_ENTRADA_BLOQUEADA                  ; FLAG_ENTRADA_BLOQUEADA (candidato)
    BIT 0,(HL)
    RET NZ
    LD HL,$9B81                  ; ACUMULADOR_ENTRADA (candidato)
; AND A / JR NZ,DESPACHAR_MODO_ENTRADA (antes etiqueta CODE_9ACF, sin
; salto entrante -- caida directa): decide si limpiar ACUMULADOR_ENTRADA
; (A=0, parametro de LEER_ENTRADA, guardando antes su valor previo en
; $9B83) o dejarlo acumular (A!=0).
    AND A
    JR NZ,DESPACHAR_MODO_ENTRADA
    LD A,(HL)
    LD ($9B83),A                 ; sin equivalente MSX identificado
    XOR A
    LD (HL),A
; --- DESPACHAR_MODO_ENTRADA (antes CODE_9AD8): RESUELTA sesion 56. Lee
; MODO_ENTRADA ($91B9) y despacha segun su valor: 0 -> sigue a
; CARGAR_TABLA_MODO_0, 1 -> LEER_JOYSTICK_SINCLAIR, 2 ->
; LEER_JOYSTICK_KEMPSTON, 3 -> carga TABLA_TECLAS_MODO_3. ---
DESPACHAR_MODO_ENTRADA:
    LD A,($91B9)                 ; MODO_ENTRADA (candidato)
    AND A
    JR Z,CARGAR_TABLA_MODO_0
    CP $02
    JP C,LEER_JOYSTICK_SINCLAIR
    JP Z,LEER_JOYSTICK_KEMPSTON
    LD IX,TABLA_TECLAS_MODO_3
    JP ESCANEAR_TABLA_TECLAS
; --- CARGAR_TABLA_MODO_0 (antes CODE_9AED): RESUELTA sesion 56. Carga
; TABLA_TECLAS_MODO_0 (esquema QAOP por defecto, MODO_ENTRADA=0) antes
; de entrar al escaneo compartido. ---
CARGAR_TABLA_MODO_0:
    LD IX,TABLA_TECLAS_MODO_0
; --- ESCANEAR_TABLA_TECLAS (antes CODE_9AF1): RESUELTA sesion 56.
; Motor de escaneo compartido por los 3 modos basados en teclado (0, 1
; y 3): resetea E=0, B=5 y entra al bucle de escaneo de fila
; (ESCANEAR_FILAS_TECLADO), que cae en COMPROBAR_PAUSA como epilogo
; comun (prueba pausa + anti-jitter + fusion en el acumulador). El
; modo 2 (Kempston, ver LEER_JOYSTICK_KEMPSTON) no lo usa -- lee el
; puerto directamente sin escanear teclado. ---
ESCANEAR_TABLA_TECLAS:
    LD E,$00
    LD B,$05
ESCANEAR_FILAS_TECLADO:
    CALL COMPROBAR_TECLA
    JR NZ,TECLA_NO_PULSADA
    SCF
    RL E
    JP CONTINUAR_ESCANEO_TECLADO
; --- TECLA_NO_PULSADA (antes CODE_9B00): RESUELTA sesion 56. Camino
; "tecla NO pulsada": mete un bit 0 en E (RL E con acarreo a 0). ---
TECLA_NO_PULSADA:
    AND A
    RL E
; --- CONTINUAR_ESCANEO_TECLADO (antes CODE_9B03): RESUELTA sesion 56.
; Cola comun de ESCANEAR_FILAS_TECLADO: avanza el puntero de tabla
; (INC IX x2) y repite el bucle. ---
CONTINUAR_ESCANEO_TECLADO:
    INC IX
    INC IX
    DJNZ ESCANEAR_FILAS_TECLADO
; --- COMPROBAR_PAUSA: RESUELTA Y RENOMBRADA (sesion 26), mismo nombre
; EXACTO que en MSX -- la 6a prueba de tecla compartida por todos los
; modos de entrada (bit 5 de E, mismo numero de bit que MSX). Aqui
; ademas resuelve conflictos de direcciones opuestas pulsadas a la vez
; (arriba+abajo o izquierda+derecha): si ambos bits de un eje estan a
; 1, los sustituye por los del acumulador anterior ($9B83, ver
; LEER_ENTRADA) -- posible anti-jitter sin equivalente MSX
; identificado. Termina fundiendo (OR) con ACUMULADOR_ENTRADA. ---
COMPROBAR_PAUSA:
    LD IX,TABLA_TECLA_PAUSA
    CALL COMPROBAR_TECLA
    JR NZ,RESOLVER_CONFLICTO_VERTICAL
    SET 5,E
; --- RESOLVER_CONFLICTO_VERTICAL (antes CODE_9B14): RESUELTA sesion
; 56. Si ABAJO+ARRIBA (bits 2-3, mascara $0C) estan a 1 a la vez, los
; sustituye por los del acumulador anterior ($9B83) -- anti-jitter del
; eje vertical. ---
RESOLVER_CONFLICTO_VERTICAL:
    LD A,E
    AND $0C
    CP $0C
    JR NZ,RESOLVER_CONFLICTO_HORIZONTAL
    LD A,E
    AND $13
    LD E,A
    LD A,($9B83)
    AND $0C
    OR E
    LD E,A
; --- RESOLVER_CONFLICTO_HORIZONTAL (antes CODE_9B26): RESUELTA sesion
; 56. Mismo mecanismo que RESOLVER_CONFLICTO_VERTICAL mas arriba, para
; DERECHA+IZQUIERDA (bits 0-1, mascara $03). ---
RESOLVER_CONFLICTO_HORIZONTAL:
    LD A,E
    AND $03
    CP $03
    JR NZ,FUNDIR_ACUMULADOR_ENTRADA
    LD A,E
    AND $1C
    LD E,A
    LD A,($9B83)
    AND $03
    OR E
    LD E,A
; --- FUNDIR_ACUMULADOR_ENTRADA (antes CODE_9B38): RESUELTA sesion 56.
; Paso final de COMPROBAR_PAUSA: funde (OR) el resultado con
; ACUMULADOR_ENTRADA (HL, heredado de LEER_ENTRADA) y lo guarda. ---
FUNDIR_ACUMULADOR_ENTRADA:
    LD A,E
    OR (HL)
    LD (HL),A
    RET
; --- COMPROBAR_TECLA: RESUELTA Y RENOMBRADA (sesion 26) -- equivalente
; Spectrum de COMPROBAR_TECLA_MSX (mismo rol, puerto distinto: aqui
; IX+0=valor a enviar al puerto ULA $FE para seleccionar media fila de
; teclado, IX+1=mascara de bit para la tecla concreta). Devuelve el
; resultado del AND en el flag Z para el llamador (DJNZ/JR NZ en
; ESCANEAR_FILAS_TECLADO/COMPROBAR_PAUSA). ---
COMPROBAR_TECLA:
    LD A,(IX+$00)
    IN A,($FE)
    AND (IX+$01)
    RET
; TABLA_TECLAS_MODO_0 ($9B45, sesion 45): modo de entrada por defecto
; (MODO_ENTRADA=0) -- 5 pares (puerto ULA,mascara de bit) consumidos
; por COMPROBAR_TECLA/ESCANEAR_FILAS_TECLADO, escaneados en este orden
; y acumulados en E via RL E (el ULTIMO entra en el bit MENOS
; significativo). Descifrado: esquema QAOP clasico de Topo Soft --
; Q=arriba, A=abajo, O=izquierda, P=derecha. Esto produce
; DECIDIR_DIRECCION_SCROLL (mas arriba): bit0=P=DERECHA,
; bit1=O=IZQUIERDA, bit2=A=ABAJO, bit3=Q=ARRIBA. TABLA_TECLA_PAUSA
; (justo despues) es la 6a tecla que prueba COMPROBAR_PAUSA (bit 5).
TABLA_TECLAS_MODO_0:
    DB $7F,$01                   ; SPACE (bit4 final, sin uso en el dispatch de 4 direcciones)
    DB $FB,$01                   ; Q -> ARRIBA
    DB $FD,$01                   ; A -> ABAJO
    DB $DF,$02                   ; O -> IZQUIERDA
    DB $DF,$01                   ; P -> DERECHA
TABLA_TECLA_PAUSA:
    DB $BF,$10                   ; H (pausa)
; --- LEER_JOYSTICK_SINCLAIR (antes CODE_9B51): RESUELTA sesion 56.
; Modo 1: emulacion de joystick Sinclair Interface 2 via teclado --
; escanea TABLA_TECLAS_MODO_1A (puerto derecho) via ESCANEAR_TABLA_
; TECLAS (con CALL, para volver aqui), luego TABLA_TECLAS_MODO_1B
; (puerto izquierdo) con JR (definitivo, el RET final de COMPROBAR_PAUSA
; devuelve al llamador original de LEER_ENTRADA). Ambas lecturas se
; funden (OR) en COMPROBAR_PAUSA -- ambos puertos Sinclair activan las
; mismas 4 direcciones. ---
LEER_JOYSTICK_SINCLAIR:
    LD IX,TABLA_TECLAS_MODO_1A
    CALL ESCANEAR_TABLA_TECLAS
; --- LEER_JOYSTICK_SINCLAIR_PUERTO_IZQUIERDO (antes CODE_9B58):
; RESUELTA sesion 56. No es destino de ningun JR/JP explicito -- es la
; direccion de retorno del CALL ESCANEAR_TABLA_TECLAS de encima (tras
; escanear el puerto DERECHO Sinclair y volver aqui). Segunda mitad de
; LEER_JOYSTICK_SINCLAIR: escanea TABLA_TECLAS_MODO_1B (puerto
; IZQUIERDO, teclas 0,9,8,7,6) con JR (definitivo esta vez, el RET
; final de COMPROBAR_PAUSA devuelve al llamador original de
; LEER_ENTRADA). ---
LEER_JOYSTICK_SINCLAIR_PUERTO_IZQUIERDO:
    LD IX,TABLA_TECLAS_MODO_1B
    JR ESCANEAR_TABLA_TECLAS
; TABLA_TECLAS_MODO_1A/1B ($9B5E/$9B68, sesion 45): "modo 1"
; (MODO_ENTRADA=1) -- emulacion de joystick Sinclair Interface 2 via
; teclado: fila numerica 1-5 (puerto derecho) y 0,9,8,7,6 (puerto
; izquierdo), fundidas (OR) entre si en COMPROBAR_PAUSA -- ambos
; puertos Sinclair activan las mismas 4 direcciones.
TABLA_TECLAS_MODO_1A:
    DB $F7,$10                   ; 5
    DB $F7,$08                   ; 4 -> ARRIBA
    DB $F7,$04                   ; 3 -> ABAJO
    DB $F7,$01                   ; 1 -> IZQUIERDA
    DB $F7,$02                   ; 2 -> DERECHA
TABLA_TECLAS_MODO_1B:
    DB $EF,$01                   ; 0
    DB $EF,$02                   ; 9 -> ARRIBA
    DB $EF,$04                   ; 8 -> ABAJO
    DB $EF,$10                   ; 6 -> IZQUIERDA
    DB $EF,$08                   ; 7 -> DERECHA
; TABLA_TECLAS_MODO_3 ($9B72, sesion 45): "modo 3" (MODO_ENTRADA>=3)
; -- esquema alternativo con teclas 0,7,6,5,8, sin proposito exacto
; confirmado todavia (candidato: variante redefinible o resto de
; pruebas de desarrollo).
TABLA_TECLAS_MODO_3:
    DB $EF,$01                   ; 0
    DB $EF,$08                   ; 7 -> ARRIBA
    DB $EF,$10                   ; 6 -> ABAJO
    DB $F7,$10                   ; 5 -> IZQUIERDA
    DB $EF,$04                   ; 8 -> DERECHA
; --- LEER_JOYSTICK_KEMPSTON (antes CODE_9B7C): RESUELTA sesion 56.
; Modo 2: joystick Kempston por hardware -- lee el puerto $1F
; directamente (puerto ESTANDAR Kempston) y mete el byte tal cual en
; E, sin pasar por ESCANEAR_TABLA_TECLAS. El formato Kempston
; (bit0=derecha,bit1=izquierda,bit2=abajo,bit3=arriba) coincide con el
; bit layout QAOP ya establecido para E, de ahi que no haga falta
; reordenar bits antes de saltar a COMPROBAR_PAUSA. ---
LEER_JOYSTICK_KEMPSTON:
    IN A,($1F)
    LD E,A
    JR COMPROBAR_PAUSA
    NOP
    NOP
    NOP
FLAG_ENTRADA_BLOQUEADA:                ; $9B84, 1 byte -- mismo nombre
                                        ; EXACTO que MSX, confirmado
                                        ; sesion 39 (bit 0: si esta
                                        ; activo, LEER_ENTRADA no lee
                                        ; entrada nueva este fotograma).
    DB $00
; ==============================================================
;  TABLA_TIPOS_LOSETA ($9B85, 91 bytes) -- RESUELTA POR COMPLETO
;  (sesion 44), mismo nombre EXACTO que MSX. Consultada por
;  CONSULTAR_TIPO_LOSETA ($99A9): HL=TABLA_TIPOS_LOSETA+indice
;  de loseta (AND $7F sobre el byte bruto de la celda del
;  nivel), A=(HL) AND $1F. Los 91 bytes son IDENTICOS BYTE A
;  BYTE a TABLA_TIPOS_LOSETA de MSX (bloque reservado
;  $8EC4-$8F23 en madmix1_body.asm), incluidos los 2 bytes
;  finales de relleno. Igual que en MSX, el tipo NO distingue
;  muro de suelo (las 45 losetas de muro, indices 0-44, y las
;  3 primeras de suelo con bola, 45-47, comparten tipo 0).
;  Los 4 bytes justo antes ($9B81-$9B84) son un bloque
;  reservado analogo al de MSX (ACUMULADOR_ENTRADA/relleno/
;  FLAG_ENTRADA_BLOQUEADA), con un byte extra propio de
;  Spectrum ($9B83, valor anterior del acumulador, ver
;  LEER_ENTRADA) que MSX no tiene. Ver FINDINGS.md sesion 44
;  para el detalle completo.
; ==============================================================
TABLA_TIPOS_LOSETA:
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01
    DB $02,$02,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F
    DB $0F,$0F,$10,$00,$11,$00,$0F,$00,$00,$12,$00,$00,$00,$00,$13,$13
    DB $00,$00,$0A,$0A,$00,$00,$00,$00,$00,$00,$00
    DB $00,$00  ; relleno final (2 bytes), igual que MSX
; --- INICIO: arranque real del motor (sesion 1 de analisis de
; madmix_body.asm, comparado con INICIO en MSX/madmix1_body.asm,
; $8F24). Destino de "JP INICIO" desde MOTOR_INICIO ($6000, el punto
; de entrada real que salta LOADER.bin) -- MOTOR_INICIO es aqui el
; equivalente estructural de START/JT_INICIO en MSX (una JP inicial
; a la rutina real, con la "API publica" del motor en algun sitio
; cercano, ver mas abajo).
;
; NOTA (sesion 29): esta version de Spectrum es la ORIGINAL; la
; version de MSX es un PORT hecho a partir de esta (confirmado por el
; usuario, ver src/README.md) -- las diferencias de mecanismo de abajo
; se describen como adaptaciones que tuvo que hacer MSX, no al reves.
;
; Coincidencias claras con INICIO de MSX:
;   - Fija el SP y hace DI antes de nada mas (MSX: LD SP,$0FFF).
;   - Llama a la rutina de activacion de interrupciones nada mas
;     empezar (aqui: ACTIVAR_INTERRUPCION_MODO_2, modo 2 del Z80 con
;     la tabla "diamante" de $F600; MSX tuvo que adaptarlo al modo 1
;     con el VDP como disparador -- de ahi que incluso el NOMBRE
;     difiera, ver esa rutina).
;   - Espera pulsacion de tecla antes de continuar (aqui: bucle
;     ESPERAR_TECLA_INICIO leyendo el puerto $FE directo; MSX tuvo que adaptarlo
;     a COMPROBAR_PULSACION, un escaneo de matriz de teclado via PSG,
;     al no tener un puerto de teclado tan directo como la ULA) --
;     misma idea, mecanismo MSX adaptado.
;   - Justo despues de la espera, inicializa el estado de partida:
;     4 variables consecutivas que coinciden EXACTAS en cantidad,
;     orden y VALOR con las que fija INICIO de MSX en REINICIAR_PARTIDA
;     (VIDAS_RESTANTES=3, HL=0->PUNTUACION, NIVEL_ACTUAL=1, CONTADOR_VUELTAS_NIVELES=0) frente a MSX
;     (VIDAS_RESTANTES=3, PUNTUACION=0, NIVEL_ACTUAL=1,
;     CONTADOR_VUELTAS_NIVELES=0) -- ver comentario junto a REINICIAR_PARTIDA
;     mas abajo. Coincidencia demasiado exacta (4 variables, mismo
;     orden, mismos valores) para ser casualidad.
;
; Diferencia notable: MSX llama a DIBUJAR_PORTADA (redibuja el logo)
; nada mas activar interrupciones -- una llamada AÑADIDA por el port
; MSX que este original Spectrum no tiene (ni podria tener: aqui la
; portada vivia en la MISMA memoria que ahora ocupa este motor,
; $EA60-$FADD cae dentro de $6000-$EFB5, ver src/README.md -- para
; cuando CODE.bin se carga y salta aqui, el codigo de la portada YA NO
; EXISTE en RAM, se sobreescribio, asi que aqui NUNCA pudo llamarse de
; nuevo; MSX, con otro mapa de memoria, si pudo permitirselo).
; ---
INICIO:
    LD SP,$5FFF
    DI
    CALL ACTIVAR_INTERRUPCION_MODO_2
    DI
; --- ESPERAR_TECLA_INICIO (antes CODE_9BEA): RESUELTA sesion 56.
; Bucle de espera de tecla al arrancar el juego, con la musica de
; presentacion sonando de fondo (equivalente Spectrum de
; COMPROBAR_PULSACION en MSX, ver cabecera de INICIO mas arriba). ---
ESPERAR_TECLA_INICIO:
    LD HL,GUION_CANCION_PRESENTACION_CANAL_A  ; CONFIRMADO: musica de presentacion (ver cabecera)
    LD ($E212),HL               ; PUNTERO_CANAL_A (operando automodificable, ver REPRODUCIR_SONIDO)
    LD HL,GUION_CANCION_PRESENTACION_CANAL_B  ; misma cancion, canal B
    LD ($E216),HL               ; PUNTERO_CANAL_B (idem)
    CALL REPRODUCIR_SONIDO      ; CONFIRMADO sesion 55 (antes CODE_E1F9, hipotesis
                                ; sesion 1): motor de sonido/musica por altavoz.
                                ; RESUELTO POR COMPLETO -- ver cabecera de seccion
                                ; junto a ISR_SONIDO ($E038) para el analisis
                                ; completo (motor de 2 canales dirigido por
                                ; interrupcion: instala un manejador temporal en
                                ; $6061-$6062, canal A=tono via IX, canal B=
                                ; percusion via IY).
    XOR A
    IN A,($FE)                  ; puerto ULA -- lee teclado (equivalente
                                ; Spectrum de COMPROBAR_PULSACION en MSX)
    CPL
    AND $1F                     ; media fila de teclado (5 teclas)
    JR Z,ESPERAR_TECLA_INICIO               ; sin tecla -> repite (bucle de espera)
    CALL CARGAR_MARCO_DECORATIVO               ; HIPOTESIS: limpia pantalla + relleno
                                ; RLE de bitmap (ver su propio analisis)
    CALL PREPARAR_TABLA_ESQUEMA_COLOR               ; RESUELTA sesion 56 (ver
                                ; su cabecera, junto a REFRESCAR_ESQUEMA_COLOR_NIVEL):
                                ; reutiliza la memoria de BITMAP_MARCO_DECORATIVO,
                                ; ya consumida por CARGAR_MARCO_DECORATIVO justo
                                ; arriba, como tabla de trabajo para el HUD.
; --- REINICIAR_PARTIDA (antes CODE_9C07): RESUELTA sesion 56, mismo
; nombre EXACTO que MSX por la correspondencia ya confirmada abajo.
; Reentrada real de INICIO (igual que MSX tiene 2
; puntos de reentrada, REINICIAR_PARTIDA y PANTALLA_PRESENTACION_NIVEL).
; Este bloque inicializa 4 variables de estado de partida que
; coinciden EXACTAS en cantidad, orden y valor con las que fija
; REINICIAR_PARTIDA en MSX. NIVEL_ACTUAL y CONTADOR_VUELTAS_NIVELES ya
; CONFIRMADAS de forma independiente en sesion 24 (ver CARGAR_NIVEL) --
; VIDAS_RESTANTES/PUNTUACION siguen como hipotesis fuerte por la misma
; correspondencia. Las 4 ya son etiquetas reales desde sesion 25 (ver
; la zona de variables tras MOTOR_INICIO). ---
REINICIAR_PARTIDA:
    CALL LEER_TECLA_MENU         ; CORREGIDO sesion 54: NO es VACIAR_CANALES_SONIDO
                                ; (hipotesis de sesion 22/40 descartada, ver
                                ; FINDINGS.md) -- es el segundo punto de entrada
                                ; a PROCESAR_MENU_CONTROLES (antes CODE_8A3F).
                                ; Al reiniciar partida, vuelve a procesar el
                                ; menu de seleccion de controles.
    LD A,3                       ; HIPOTESIS: VIDAS_RESTANTES
    LD (VIDAS_RESTANTES),A
    LD HL,0                      ; HIPOTESIS: PUNTUACION
    LD (PUNTUACION),HL
    LD A,1                       ; NIVEL_ACTUAL (CONFIRMADO sesion 24)
    LD (NIVEL_ACTUAL),A
    XOR A                        ; CONTADOR_VUELTAS_NIVELES (CONFIRMADO sesion 24)
    LD (CONTADOR_VUELTAS_NIVELES),A
    SCF                          ; carry=1 (posible flag "partida nueva")
    JR PREPARAR_INICIO_NIVEL
; --- PANTALLA_PRESENTACION_NIVEL (antes CODE_9C21): RESUELTA sesion
; 56, mismo nombre EXACTO que MSX -- la otra mitad del patron de doble
; entrada (reentrada "nivel siguiente", sin resetear vidas/puntuacion,
; frente a REINICIAR_PARTIDA arriba que si las resetea). ---
PANTALLA_PRESENTACION_NIVEL:
    AND A                        ; carry=0 (posible flag "reentrada de nivel") --
                                ; mismo patron de doble entrada que
                                ; REINICIAR_PARTIDA/PANTALLA_PRESENTACION_NIVEL en MSX
; --- PREPARAR_INICIO_NIVEL (antes CODE_9C22): RESUELTA POR COMPLETO
; (sesion 23, datos confirmados sesion 56 continuacion 23) -- las 3
; llamadas a DIBUJAR_TEXTO_VRAM que siguen (equivalente exacto de la
; rutina homonima de MSX, ver arriba) encajan letra por letra con lo
; que dice MSX de su bloque equivalente: "Dibuja 3 lineas de texto de
; HUD/pantalla segun el nivel actual y dos flags del registro de
; nivel" (comentario de INICIO en madmix1_body.asm):
;   1. Copia 2 bytes de TABLA_NUMEROS_NIVEL (indexada por nivel*2) al
;      "00" final de TEXTO_FASE (offset+8), y dibuja TEXTO_FASE
;      (" FASE 00") en $484C.
;   2. Si viene de "partida nueva" (SCF en REINICIAR_PARTIDA/PANTALLA_PRESENTACION_NIVEL), espera
;      50 frames (~1s) y llama a REPRODUCIR_SONIDO otra vez (motor de
;      sonido, RESUELTO sesion 55, ver ISR_SONIDO).
;   3. Si el flag en $603E esta activo, suma su valor a VIDAS_RESTANTES
;      (candidato VIDAS_RESTANTES) topando en 5, y dibuja TEXTO_EXTRA
;      ("EXTRA") en $48CE.
;   4. Si $600E=1 y VIDAS_RESTANTES(vidas)<4, dibuja TEXTO_VIDA_EXTRA
;      ("EN LA PROXIMA... EXTRA") en $5045 -- pese al nombre historico
;      de la rutina que lo dispara (COMPROBAR_AVISO_ULTIMA_VIDA), el
;      contenido real confirma que anuncia la PROXIMA vida extra, no
;      un aviso de ultima vida (ver hallazgo continuacion 18).
; Termina esperando 80 frames (~1.6s) -- tiempo de lectura del HUD
; antes de continuar. Encaja con PREPARAR_INICIO_NIVEL de MSX (la
; secuencia "nivel cargado -> HUD -> esperar" de las transiciones,
; NO el bucle de cada frame). REINICIAR_ESTADO_NIVEL (mas abajo) es candidato a
; ser el resto de esa misma secuencia (llama a REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM dos veces,
; separadas por APLICAR_ATRIBUTOS_MARCO_COMPLETO -- el relleno RLE de atributos visto en
; sesion 22, candidato a APLICAR_COLOR_PANTALLA) -- sin analizar
; todavia mas alla de aqui. ---
PREPARAR_INICIO_NIVEL:
    PUSH AF
    CALL CARGAR_NIVEL               ; RESUELTA sesion 24 -- carga el registro
                                ; de 20 bytes del nivel actual y decodifica
                                ; su matriz a $FC60 (ver su propio analisis)
    LD A,(NIVEL_ACTUAL)                 ; NIVEL_ACTUAL (CONFIRMADO sesion 24)
    ADD A,A
    LD HL,TABLA_NUMEROS_NIVEL
    ADD A,L
    LD L,A
    LD A,H
    ADC A,$00
    LD H,A
    LD DE,TEXTO_FASE+8            ; el "00" final de " FASE 00"
    LDI
    LDI
    LD HL,$484C                 ; texto HUD 1/3
    LD DE,TEXTO_FASE
    CALL DIBUJAR_TEXTO_VRAM
    POP AF
    JR NC,COMPROBAR_VIDA_EXTRA
    EI
    LD B,$32                     ; 50 frames (~1s)
; --- BUCLE_ESPERA_PARTIDA_NUEVA (antes CODE_9C49): RESUELTA sesion
; 56. Espera 50 frames (~1s), solo en el camino "partida nueva" (carry
; de REINICIAR_PARTIDA), antes de repetir la musica de presentacion. ---
BUCLE_ESPERA_PARTIDA_NUEVA:
    HALT
    DJNZ BUCLE_ESPERA_PARTIDA_NUEVA
    LD HL,GUION_CANCION_PRESENTACION_CANAL_A
    LD ($E212),HL
    LD HL,GUION_CANCION_PRESENTACION_CANAL_B
    LD ($E216),HL
    CALL REPRODUCIR_SONIDO        ; motor de sonido, RESUELTO sesion 55
; --- COMPROBAR_VIDA_EXTRA (antes CODE_9C5B): RESUELTA sesion 56.
; Comprueba el flag $603E (bonus de vida extra pendiente); si esta
; activo, suma su valor a VIDAS_RESTANTES (topando en 5) y dibuja
; TEXTO_EXTRA ("EXTRA"). ---
COMPROBAR_VIDA_EXTRA:
    LD HL,$603E
    LD A,(HL)
    LD (HL),$00
    AND A
    JR Z,COMPROBAR_AVISO_ULTIMA_VIDA
    LD HL,VIDAS_RESTANTES                 ; HIPOTESIS VIDAS_RESTANTES
    ADD A,(HL)
    CP $05
    JR NC,COMPROBAR_AVISO_ULTIMA_VIDA
    LD (HL),A
    LD HL,$48CE                 ; texto HUD 2/3
    LD DE,TEXTO_EXTRA
    CALL DIBUJAR_TEXTO_VRAM
; --- COMPROBAR_AVISO_ULTIMA_VIDA (antes CODE_9C76): RESUELTA sesion
; 56. Comprueba el flag $600E; si esta activo y quedan menos de 4
; vidas, dibuja TEXTO_VIDA_EXTRA ("EN LA PROXIMA... EXTRA") -- pese al
; nombre historico de esta rutina, el contenido real confirma que
; anuncia la PROXIMA vida extra, no un aviso de ultima vida (ver
; hallazgo continuacion 18). ---
COMPROBAR_AVISO_ULTIMA_VIDA:
    LD A,($600E)
    CP $01
    JR NZ,CONTINUAR_TRAS_AVISOS_HUD
    LD A,(VIDAS_RESTANTES)                 ; HIPOTESIS VIDAS_RESTANTES
    CP $04
    JR NC,CONTINUAR_TRAS_AVISOS_HUD
    LD HL,$5045                 ; texto HUD 3/3
    LD DE,TEXTO_VIDA_EXTRA
    CALL DIBUJAR_TEXTO_VRAM
; --- CONTINUAR_TRAS_AVISOS_HUD (antes CODE_9C8D): RESUELTA sesion 56.
; Convergencia tras los 2 avisos condicionales de arriba, antes de
; esperar el tiempo de lectura del HUD. ---
CONTINUAR_TRAS_AVISOS_HUD:
    EI
    LD B,$50                     ; 80 frames (~1.6s) -- tiempo de lectura del HUD
; --- BUCLE_ESPERA_LECTURA_HUD (antes CODE_9C90): RESUELTA sesion 56.
; Espera 80 frames (~1.6s), tiempo de lectura del HUD antes de
; continuar a REINICIAR_ESTADO_NIVEL. ---
BUCLE_ESPERA_LECTURA_HUD:
    HALT
    DJNZ BUCLE_ESPERA_LECTURA_HUD
; --- REINICIAR_ESTADO_NIVEL (antes CODE_9C93): RESUELTA sesion 56.
; Reinicia selector de sprite/direccion/temporizadores, redibuja la
; pantalla completa y busca la columna del HUD (BUSCAR_COLUMNA_HUD, mas
; abajo). Tambien es la reentrada "quedan vidas" desde
; BUCLE_PRINCIPAL_JUEGO tras perder una. ---
REINICIAR_ESTADO_NIVEL:
    CALL INICIALIZAR_ITEMS_NIVEL
    CALL REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM
    CALL APLICAR_ATRIBUTOS_MARCO_COMPLETO               ; relleno RLE de atributos (sesion 22,
                                ; candidato APLICAR_COLOR_PANTALLA)
    LD A,(MODO_ESPECIAL)
    CP $03
    LD A,$0E
    JR Z,GUARDAR_SELECTOR_SPRITE_INICIAL
    XOR A
; --- GUARDAR_SELECTOR_SPRITE_INICIAL (antes CODE_9CA6): RESUELTA
; sesion 56. Convergencia de las 2 ramas de arriba (A=$0E si
; MODO_ESPECIAL=3, si no A=0) antes de guardar el selector de sprite
; inicial del comecocos. CORREGIDO sesion 56 continuacion 30: por un
; momento se renombro a GUARDAR_SELECTOR_SPRITE_COMECOCOS por similitud
; con MSX, pero ese nombre ya lo tiene, con razon, la convergencia de
; ENLACE_MOTOR_MOVIMIENTO_COLISION/PREPARAR_SCROLL mas arriba (mismo
; patron EXACTO -- bit7/centinela -- que el GUARDAR_SELECTOR_SPRITE_
; COMECOCOS real de MSX); esta de aqui es una convergencia DISTINTA
; (inicializacion de nivel, no lectura de entrada), asi que se
; mantiene con nombre propio para no chocar. ---
GUARDAR_SELECTOR_SPRITE_INICIAL:
    LD (SELECTOR_SPRITE_COMECOCOS),A
    XOR A
    LD (DIRECCION_DE_MOVIMIENTO),A
    LD (DIRECCION_FORZADA),A
    LD (TEMPORIZADOR_DIRECCION_FORZADA),A
    LD (TEMPORIZADOR_PARPADEO_BOLA),A
    CALL REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM
    LD A,$01
    LD (FLAG_ENTRADA_BLOQUEADA),A
    LD HL,TABLA_POSICIONES_HUD
    LD A,(TABLA_POSICIONES_HUD+18)
    LD (COLOR_ACTUAL),A
    LD A,(TABLA_POSICIONES_HUD+17)
    LD C,A
; --- BUSCAR_COLUMNA_HUD (antes CODE_9CCB): RESUELTA sesion 56, mismo
; nombre EXACTO que MSX (equivalente confirmado: MSX describe esta
; misma fase como "animacion de busqueda del HUD", ver comentario de
; INICIO mas arriba). Bucle que llama a ENLACE_MOTOR_MOVIMIENTO_COLISION
; y espera VBLANK en cada vuelta hasta que C (icono buscado, AND $78)
; coincide con el byte leido -- animacion de "recorrer" el HUD hasta
; encontrar la columna correcta. ---
BUSCAR_COLUMNA_HUD:
    PUSH BC
    PUSH HL
    CALL ENLACE_MOTOR_MOVIMIENTO_COLISION
    POP HL
    POP BC
    LD A,C
    AND $78
    CP (HL)
    LD A,(HL)
    LD (REGISTRO_NIVEL_ICONO_HUD),A
    PUSH AF
    CALL WAIT_VBLANK
    POP AF
    LD (TABLA_POSICIONES_HUD+15),HL
    INC HL
    JR NZ,BUSCAR_COLUMNA_HUD
    XOR A
    LD (FLAG_ENTRADA_BLOQUEADA),A
    LD A,C
    AND $48
    XOR $5F
    LD (TEXTO_VACIO_1+1),A         ; atributo de TEXTO_VACIO_1 (idem MSX, offset+1 del registro)
    LD (TEXTO_READY+1),A           ; atributo de TEXTO_READY -- las 3 comparten el mismo color
    LD (TEXTO_VACIO_2+1),A         ; atributo de TEXTO_VACIO_2
    LD HL,$488C
    LD DE,TEXTO_VACIO_1
    CALL DIBUJAR_TEXTO_VRAM
    LD HL,$48AC
    LD DE,TEXTO_READY
    CALL DIBUJAR_TEXTO_VRAM
    LD HL,$48CC
    LD DE,TEXTO_VACIO_2
    CALL DIBUJAR_TEXTO_VRAM
    LD HL,GUION_CANCION_INICIO_NIVEL_CANAL_A  ; CONFIRMADO: musica de inicio de nivel (ver cabecera)
    LD ($E212),HL
    LD HL,GUION_CANCION_INICIO_NIVEL_CANAL_B  ; misma cancion, canal B
    LD ($E216),HL
    CALL REPRODUCIR_SONIDO        ; motor de sonido, RESUELTO sesion 55
    XOR A
    LD (TEMPORIZADOR_PARPADEO_BOLA),A
; --- BUCLE_PRINCIPAL_JUEGO: CONFIRMADO (sesion 34), mismo nombre
; EXACTO que en MSX (madmix1_body.asm, $9078). Abre con "leer entrada
; (ENLACE_MOTOR_MOVIMIENTO_COLISION -> MOTOR_MOVIMIENTO_COLISION -> LEER_ENTRADA) + esperar VBLANK", el
; patron clasico de un bucle de juego por fotograma, y se reentra
; ciclicamente via JP BUCLE_PRINCIPAL_JUEGO (ver mas abajo). Estructura
; PRACTICAMENTE IDENTICA a MSX instruccion a instruccion: comprueba
; MODO_ESPECIAL_ACTIVO/decrementa temporizador (misma variable, mismo
; patron AND A/JR Z + DEC/JR NZ), alinea la posicion del comecocos a
; multiplo de 4 (AND $FC), resta 1 a VIDAS_RESTANTES -- aqui via ADD
; con un delta en $6003 en vez del SUB $01 de MSX, logrando el mismo
; resultado con signo de acarreo invertido (ADD desborda cuando SI
; quedan vidas, en vez de SUB pidiendo prestado cuando NO quedan) --
; posible equivalente Spectrum del truco de "vidas infinitas"
; parcheable que tiene MSX en su version SUB. Sin vidas: dibuja el
; texto de $484B (candidato GAME OVER) y espera ~150 frames (B=$96),
; igual que MSX. VERIFICAR_FIN_NIVEL (mas abajo, antes CODE_9D8B)
; compara CONTADOR_BOLAS_COMIDAS contra un objetivo en $6019
; (candidato REGISTRO_NIVEL_OBJETIVO_BOLAS) e incrementa NIVEL_ACTUAL
; con el mismo tope CP $10=16 que MSX (CP 16); VERIFICAR_ENTRADA (antes
; CODE_9DB8) sondea el mismo BIT 5,A de pausa que MSX. Resuelve
; tambien la pregunta pendiente desde sesion 26 ("falta verificar que
; se reentra ciclicamente"). ---
BUCLE_PRINCIPAL_JUEGO:
    CALL ENLACE_MOTOR_MOVIMIENTO_COLISION
    CALL WAIT_VBLANK
    LD HL,MODO_ESPECIAL_ACTIVO
    LD A,(HL)
    CP $02
    JR NZ,COMPROBAR_TEMPORIZADOR_MODO_ESPECIAL
    LD DE,COLOR_ACTUAL
    LD A,(DE)
    LD (COLOR_GUARDADO),A
    LD A,(REGISTRO_NIVEL_ICONO_HUD)
    LD (DE),A
COMPROBAR_TEMPORIZADOR_MODO_ESPECIAL:
    AND A
    JR Z,VERIFICAR_FIN_NIVEL
    DEC (HL)
    JR NZ,VERIFICAR_FIN_NIVEL
    LD A,(COLOR_GUARDADO)
    LD (COLOR_ACTUAL),A
    LD HL,GUION_CANCION_FIN_MODO_ESPECIAL_CANAL_A  ; CONFIRMADO: fin de MODO_ESPECIAL (ver cabecera)
    LD ($E212),HL
    LD HL,GUION_CANCION_FIN_MODO_ESPECIAL_CANAL_B  ; misma cancion, canal B
    LD ($E216),HL
    CALL REPRODUCIR_SONIDO        ; motor de sonido, RESUELTO sesion 55
    CALL DESTELLO_ICONO_COLOR_HUD
    LD HL,(REGISTRO_NIVEL_POSICION_COMECOCOS)
    LD A,L
    AND $FC
    LD L,A
    LD (REGISTRO_NIVEL_POSICION_COMECOCOS),HL
    LD HL,VIDAS_RESTANTES
    LD A,($6003)
    ADD A,(HL)
    LD (HL),A
    CP $FF
    JP C,REINICIAR_ESTADO_NIVEL
    CALL LIMPIAR_PANTALLA_MENU    ; reutilizada aqui fuera del menu de
                                    ; controles como limpiador de pantalla
                                    ; generico (sesion 54)
    CALL WAIT_VBLANK
    LD HL,$484B
    LD DE,TEXTO_GAME_OVER
    CALL DIBUJAR_TEXTO_VRAM
    EI
    LD B,$96
BUCLE_ESPERA_GAME_OVER:
    HALT
    DJNZ BUCLE_ESPERA_GAME_OVER
    JP REINICIAR_PARTIDA
VERIFICAR_FIN_NIVEL:
    CALL ACTUALIZAR_PARPADEO_BOLA
    LD HL,(CONTADOR_BOLAS_COMIDAS)
    LD DE,($6019)
    AND A
    SBC HL,DE
    JR NZ,VERIFICAR_ENTRADA
    LD HL,NIVEL_ACTUAL
    INC (HL)
    LD A,(HL)
    CP $10
    JR NZ,PREPARAR_TRANSICION_NIVEL
    LD (HL),$01
    LD A,(CONTADOR_VUELTAS_NIVELES)
    INC A
    LD (CONTADOR_VUELTAS_NIVELES),A
PREPARAR_TRANSICION_NIVEL:
    CALL DESTELLO_ICONO_COLOR_HUD
    LD A,($600E)
    LD ($603E),A
    JP PANTALLA_PRESENTACION_NIVEL
VERIFICAR_ENTRADA:
    XOR A
    CALL LEER_ENTRADA
    BIT 5,A
    JR Z,CONTINUAR_BUCLE_PRINCIPAL
    EI
    LD B,$32
; --- BUCLE_PAUSA (antes BUCLE_ESPERA_PAUSA): mismo nombre EXACTO que
; MSX (sesion 56 continuacion 31) -- ambas son "HALT/DJNZ", pausa fija
; de 50 frames tras detectar la tecla de pausa. ---
BUCLE_PAUSA:
    HALT
    DJNZ BUCLE_PAUSA
ESPERAR_TECLA_REANUDAR:
    XOR A
    CALL LEER_ENTRADA
    AND $3F
    JR Z,ESPERAR_TECLA_REANUDAR
CONTINUAR_BUCLE_PRINCIPAL:
    JP BUCLE_PRINCIPAL_JUEGO
ACTUALIZAR_PARPADEO_BOLA:
    LD HL,TEMPORIZADOR_PARPADEO_BOLA
    INC (HL)
    LD A,(HL)
    AND $40
    RLCA
    RLCA
    ADD A,$38
    LD HL,(POSICION_PARPADEO_BOLA)
    LD (HL),A
    RET
; --- DESTELLO_ICONO_COLOR_HUD (antes REPINTAR_ICONOS_HUD, sesion 56
; continuacion 22): mismo nombre EXACTO que MSX (madmix1_body.asm
; $9116, IDENTICA instruccion a instruccion, incluidas las mismas
; variables REGISTRO_NIVEL_ICONO_HUD/COLOR_ACTUAL/WAIT_VBLANK) --
; CORREGIDO (correccion heredada de MSX): NO es un "repintado", es un
; PARPADEO/DESTELLO rapido de icono+color mientras recorre hacia atras
; (DEC HL) TABLA_POSICIONES_HUD desde donde la dejo BUSCAR_COLUMNA_HUD
; (TABLA_POSICIONES_HUD+15), hasta el centinela $00 de fin de tabla. ---
DESTELLO_ICONO_COLOR_HUD:
    LD A,(COLOR_ACTUAL)
    LD (TABLA_POSICIONES_HUD+18),A
    LD HL,(TABLA_POSICIONES_HUD+15)
BUCLE_DESTELLO_ICONO_COLOR_HUD:
    PUSH BC
    PUSH HL
    POP HL
    POP BC
    LD A,(HL)
    AND A
    LD (REGISTRO_NIVEL_ICONO_HUD),A
    LD (COLOR_ACTUAL),A
    PUSH AF
    CALL WAIT_VBLANK
    POP AF
    DEC HL
    JP NZ,BUCLE_DESTELLO_ICONO_COLOR_HUD
    RET
    NOP
; --- TABLA_POSICIONES_HUD (sesion 56 continuacion 22): mismo nombre
; EXACTO que MSX, confirmado byte a byte (08 48 10 50 18 58 20 60 28
; 68 30 70 38 78 40 00 00 00 00 -- identicos). +15 (word) = puntero de
; busqueda guardado por BUSCAR_COLUMNA_HUD; +17 = columna/icono
; objetivo; +18 = COLOR_ACTUAL guardado -- ambos consumidos por
; DESTELLO_ICONO_COLOR_HUD. Sigue como datos disfrazados de codigo
; (ver cabecera $9E01-$9E8D mas abajo), solo se etiqueta el inicio. ---
TABLA_POSICIONES_HUD:
    DB $08,$48, $10,$50, $18,$58, $20,$60
    DB $28,$68, $30,$70, $38,$78, $40
    DB $00,$00,$00,$00      ; offsets 15-18: puntero de busqueda (word,
                            ; +15) + columna objetivo (+17) + color
                            ; guardado (+18), relleno en tiempo real --
                            ; ver cabecera de arriba
; --- TEXTO_FASE (sesion 56 continuacion 23, dato real -- antes parte
; del tramo "datos disfrazados de codigo"): mismo nombre EXACTO que
; MSX. Plantilla del indicador de nivel " FASE 00" -- el "00" final se
; sobreescribe en tiempo real con 2 bytes de TABLA_NUMEROS_NIVEL
; (indexada por NIVEL_ACTUAL*2, ver PREPARAR_INICIO_NIVEL) antes de
; dibujarse via DIBUJAR_TEXTO_VRAM. ---
TEXTO_FASE:
    DB $08,$46," FASE 00"
; --- TABLA_NUMEROS_NIVEL (sesion 56 continuacion 23, dato real): mismo
; nombre EXACTO que MSX -- 32 bytes (16 pares "espacio+digito"),
; indexada por NIVEL_ACTUAL*2 para obtener los 2 caracteres que
; sustituyen el "00" final de TEXTO_FASE. ---
TABLA_NUMEROS_NIVEL:
    DB " 0 1 2 3 4 5 6 7 8 9101112131415"
; --- TEXTO_VIDA_EXTRA (sesion 56 continuacion 23, dato real): mismo
; nombre EXACTO que MSX -- dibujado por COMPROBAR_AVISO_ULTIMA_VIDA
; (flag $600E; pese al nombre historico de esa rutina, el contenido real
; confirma que anuncia la PROXIMA vida extra, no un aviso de ultima
; vida -- ver hallazgo continuacion 18). ---
TEXTO_VIDA_EXTRA:
    DB $16,$47,"EN LA PROXIMA... EXTRA"
; --- TEXTO_EXTRA (sesion 56 continuacion 23, dato real): mismo nombre
; EXACTO que MSX -- dibujado por COMPROBAR_VIDA_EXTRA (flag $603E). ---
TEXTO_EXTRA:
    DB $05,$42,"EXTRA"
; --- TEXTO_VACIO_1/TEXTO_READY/TEXTO_VACIO_2 (nombradas continuacion
; 18, convertidas a dato real aqui continuacion 23): mismos nombres
; EXACTOS que MSX -- trio blanco/READY?/blanco dibujado por
; BUSCAR_COLUMNA_HUD/REINICIAR_ESTADO_NIVEL tras cargar cada nivel. El
; atributo (offset+1 de cada registro) se sobreescribe en tiempo real
; con el color derivado de la columna de camara (ver esas rutinas). ---
TEXTO_VACIO_1:
    DB $0A,$00,"          "
TEXTO_READY:
    DB $0A,$00,"  READY?  "
TEXTO_VACIO_2:
    DB $0A,$00,"          "
; --- TEXTO_GAME_OVER (nombrada continuacion 19, convertida a dato real
; aqui continuacion 23): mismo nombre EXACTO que MSX -- dibujado por
; BUCLE_PRINCIPAL_JUEGO cuando VIDAS_RESTANTES llega a $FF (sin
; vidas). ---
TEXTO_GAME_OVER:
    DB $0B,$42,"ESTAS FRITO"
; ==============================================================
;  PTR_TABLA_SPRITES ($9E8E, 64 entradas x 4 bytes = 256 bytes) --
;  CORREGIDA en sesion 31: la sesion 30 se equivoco al asumir que
;  la tabla solo tenia 28 entradas (paro justo donde parecia
;  empezar TABLA_FUENTE). En realidad tiene las 64 completas que
;  ya predecia el guarda de MOTOR_ACTORES (sesion 28, E contra
;  $40=64) -- el mismo numero que MSX. Confirmado sin ambiguedad
;  leyendo bytes crudos de FISICO/CODE.bin mas alla de la entrada
;  27: las 36 entradas siguientes (28-63) tienen exactamente el
;  mismo patron estructural (puntero +144 exacto, p2 SIEMPRE 24)
;  que las primeras 28, terminan con un centinela de 12 bytes
;  $FF y enlazan EXACTO, sin hueco, con TABLA_ACTORES_ACTIVOS
;  ($9F9A, ya identificada en sesion 28) -- imposible que sea
;  casualidad (36 saltos consecutivos de +144 exactos). La
;  supuesta TABLA_FUENTE de 736 bytes en $9EFE (sesion 23/30) NO
;  empezaba ahi de verdad: $9EFE es la propia entrada 28 de esta
;  tabla. La fuente real de texto esta mas adelante, ver abajo.
;
;  Cada entrada: puntero de 16 bits a los graficos reales del
;  sprite (144 bytes cada uno) + 2 parametros (byte 3 -- offset/
;  variante, valores vistos: 0/4/6; byte 4 SIEMPRE 24). Indexada
;  por B (indice de sprite, candidato SELECTOR_SPRITE_COMECOCOS
;  con el bit 7 ya separado) dentro de MOTOR_ACTORES.
;
;  FORMATO DE PIXEL CORREGIDO en sesion 31: NO es una imagen de
;  48x24 px como se penso en sesion 30. Renderizando en PNG (no
;  solo ASCII-art) se ve con claridad que cada bloque de 144
;  bytes son en realidad DOS planos de 24x24 px de 72 bytes cada
;  uno (3 bytes/fila x 24 filas), tecnica clasica de sprite
;  enmascarado Z80: plano izquierdo (AND-mask, bit=1 preserva
;  fondo/transparente) + plano derecho (OR-pattern, el dibujo
;  real, bit=1 fuerza tinta). Confirmado programaticamente sobre
;  los 64 sprites: la combinacion (AND=0,OR=1) practicamente no
;  aparece nunca (<0.1% de los bits), como exige ese esquema.
;  Los 144 bytes por sprite y el offset de cada entrada NO
;  cambian -- solo la interpretacion correcta de como pintarlos.
;
;  Los 64 punteros son EXACTOS multiplos de 144 bytes desde
;  $A1DE hasta $C54E (entrada 63), sin ningun hueco entre
;  sprites -- bloque de graficos perfectamente compacto de
;  $A1DE a $C5DD. Extraidos a fichero individual cada uno
;  (data/img/sprites/) y renderizados en recursos/sprites.html
;  (AND-mask + OR-pattern, 24x24 px) para identificacion visual
;  -- misma metodologia que las 15 formas del logo de la
;  portada (sesiones 6-7) y que ptrtable_sprites.html en el
;  proyecto MSX. Los mismos 4032 bytes de las primeras 28
;  entradas coinciden byte a byte con los primeros 4032 bytes
;  de la tabla de 64 sprites de MSX (ver sesion 30) -- las 36
;  entradas nuevas (28-63) no se han comparado byte a byte con
;  MSX todavia (posible trabajo futuro).
; ==============================================================
; Antes de aqui hubo un bloque de constantes EQU (sesiones 30/31,
; ampliado sesion 56) para direcciones CODE_XXXX autorreferenciadas por
; el desensamblado mecanico dentro de $9E3F-$9ED0 (entonces "datos
; disfrazados de codigo"). CONTINUACION 23: esa zona (TABLA_POSICIONES_
; HUD/TEXTO_FASE/TABLA_NUMEROS_NIVEL/TEXTO_VIDA_EXTRA/TEXTO_EXTRA/
; TEXTO_VACIO_1/TEXTO_READY/TEXTO_VACIO_2/TEXTO_GAME_OVER, ver sus
; cabeceras mas arriba) se reconvirtio POR COMPLETO a DB real -- las
; instrucciones mecanicas que autorreferenciaban esas constantes ya no
; existen, asi que las 21 constantes EQU que quedaban aqui se
; eliminaron por quedar huerfanas (comprobado: 0 referencias en todo
; el fichero tras la conversion). Otras 14 EQU de esta misma familia
; (CODE_9E51 mas 13 entre $A101 y $BF01) ya se habian depurado justo
; antes en esta misma sesion por el mismo motivo -- ver FINDINGS.md,
; sesion 56 continuaciones 21 y 23, para el detalle completo.
PTR_TABLA_SPRITES:
    DW SPR00_PM_VULN_DER_CERRADA
    DB 6,24
    DW SPR01_PM_VULN_DER_BOCA90
    DB 6,24
    DW SPR02_PM_VULN_DER_BOCA95
    DB 6,24
    DW SPR03_PM_VULN_ABAJO_CERRADA
    DB 0,24
    DW SPR04_PM_VULN_ABAJO_SEMI
    DB 0,24
    DW SPR05_PM_VULN_ABAJO_MAS
    DB 0,24
    DW SPR06_PM_VULN_ARRIBA
    DB 0,24
    DW SPR07_PM_INV_DER_CERRADA
    DB 6,24
    DW SPR08_PM_INV_DER_BOCA90
    DB 6,24
    DW SPR09_PM_INV_DER_BOCA95
    DB 6,24
    DW SPR10_PM_INV_ABAJO_CERRADA
    DB 0,24
    DW SPR11_PM_INV_ABAJO_MAS
    DB 0,24
    DW SPR12_PM_AVION_ARRIBA
    DB 0,24
    DW SPR13_PM_OBRA_DER
    DB 4,24
    DW SPR14_PM_OBRA_ABAJO
    DB 0,24
    DW SPR15_PM_OBRA_ARRIBA
    DB 0,24
    DW SPR16_PM_HIPO_DER_1
    DB 0,24
    DW SPR17_PM_HIPO_DER_2
    DB 0,24
    DW SPR18_PM_HIPO_DER_3
    DB 0,24
    DW SPR19_PM_HIPO_ABAJO_1
    DB 0,24
    DW SPR20_PM_HIPO_ABAJO_2
    DB 0,24
    DW SPR21_PM_HIPO_ARRIBA_1
    DB 0,24
    DW SPR22_PM_HIPO_ARRIBA_2
    DB 0,24
    DW SPR23_PM_TANQUE_DER
    DB 0,24
    DW SPR24_PM_HIPO_ABAJO_3
    DB 0,24
    DW SPR25_PM_HIPO_ARRIBA_3
    DB 0,24
    DW SPR26_DESCONOCIDO_CIRCULOS
    DB 0,24
    DW SPR27_FANTASMA_DER_1
    DB 0,24
    DW SPR28_FANTASMA_DER_2
    DB 0,24
    DW SPR29_FANTASMA_ABAJO_1
    DB 0,24
    DW SPR30_FANTASMA_ABAJO_2
    DB 0,24
    DW SPR31_FANTASMA_ARRIBA_1
    DB 0,24
    DW SPR32_FANTASMA_ARRIBA_2
    DB 0,24
    DW SPR33_FANTASMA_VULN_DER_1
    DB 0,24
    DW SPR34_FANTASMA_VULN_DER_2
    DB 0,24
    DW SPR35_FANTASMA_VULN_ABAJO_1
    DB 0,24
    DW SPR36_FANTASMA_VULN_ABAJO_2
    DB 0,24
    DW SPR37_MARIQUITA_ABAJO
    DB 0,24
    DW SPR38_MARIQUITA_ARRIBA
    DB 0,24
    DW SPR39_MARIQUITA_DER
    DB 6,24
    DW SPR40_MUERTE_PM_SEQ0
    DB 0,24
    DW SPR41_MUERTE_PM_SEQ1
    DB 0,24
    DW SPR42_MUERTE_PM_SEQ2
    DB 0,24
    DW SPR43_MUERTE_PM_SEQ3
    DB 0,24
    DW SPR44_MUERTE_PM_SEQ4
    DB 0,24
    DW SPR45_REPUGNANTE_DER_1
    DB 6,24
    DW SPR46_REPUGNANTE_DER_2
    DB 6,24
    DW SPR47_REPUGNANTE_DER_3
    DB 6,24
    DW SPR48_REPUGNANTE_ABAJO_1
    DB 0,24
    DW SPR49_REPUGNANTE_ABAJO_2
    DB 0,24
    DW SPR50_REPUGNANTE_ABAJO_3
    DB 0,24
    DW SPR51_REPUGNANTE_ARRIBA_1
    DB 0,24
    DW SPR52_REPUGNANTE_ARRIBA_2
    DB 0,24
    DW SPR53_REPUGNANTE_ARRIBA_3
    DB 0,24
    DW SPR54_REPUGNANTE_DESPEINADO
    DB 0,24
    DW SPR55_PUNTOS_400
    DB 0,24
    DW SPR56_PUNTOS_600
    DB 0,24
    DW SPR57_PM_INV_ABAJO_SEMI
    DB 0,24
    DW SPR58_MUERTE_PM_RED1
    DB 0,24
    DW SPR59_MUERTE_PM_RED2
    DB 0,24
    DW SPR60_MUERTE_PM_RED3
    DB 0,24
    DW SPR61_MUERTE_PM_RED4
    DB 0,24
    DW SPR62_FANTASMA_MUERTO
    DB 0,24
    DW SPR63_NULO
    DB 0,24
; Centinela de 12 bytes ($FF), $9F8E-$9F99 -- separa la tabla de
; punteros de TABLA_ACTORES_ACTIVOS. Significado exacto sin
; confirmar (posible terminador/alineacion); valor real preservado.
    DB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; TABLA_ACTORES_ACTIVOS ($9F9A, 100 bytes = 10 actores x 10 bytes) --
; candidata desde sesion 28 (MOTOR_ACTORES calcula IX = $9F9A +
; CONTADOR_ACTORES_ACTIVOS x 10). Confirmada aqui: 100 bytes a cero
; en el volcado original (estado de reposo antes de que arranque la
; partida), terminando EXACTO donde empieza la fuente de texto real
; ($9FFE) -- ver mas abajo.
TABLA_ACTORES_ACTIVOS:
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
; TABLA_FUENTE -- CORREGIDA en sesion 31. La sesion 23 encontro que
; ESCRIBIR_PATRON_VRAM hace LD DE,TABLA_FUENTE (formula base) + A*8,
; y la sesion 30 asumio (mal) que los datos de la fuente empezaban
; fisicamente justo ahi, en $9EFE. En realidad esa direccion es solo
; la BASE ARITMETICA de la formula: los codigos de caracter usados de
; verdad por el HUD son bytes >=$20 (ver DIBUJAR_TEXTO_VRAM), asi que
; los primeros 32 caracteres (codigos 0-31, offsets $9EFE-$9FFD) nunca
; se leen -- ese hueco es en realidad el resto de PTR_TABLA_SPRITES
; (entradas 28-63) mas TABLA_ACTORES_ACTIVOS. La fuente real (bytes
; que SI se leen) empieza en $9FFE (caracter codigo $20) y ocupa 480
; bytes (60 caracteres x 8 bytes) hasta $A1DD, justo antes del primer
; sprite. Confirmado visualmente: renderizados como bitmaps 8x8 se ven
; simbolos/puntuacion, digitos 0-9 y letras A-F reconocibles en fila.
TABLA_FUENTE:                          ; $9FFE, 480 bytes (60 caracteres
                                        ; x 8 bytes, empieza en codigo $20)
    INCBIN "data/img/texto/tabla_fuente.img"
; TABLA_FUENTE_BASE = $9EFE = TABLA_FUENTE - $100 ($20 codigos de caracter x 8
; bytes que nunca se usan, ver ESCRIBIR_PATRON_VRAM) -- constante EQU, no
; ocupa bytes ni desplaza nada; solo reproduce el operando literal original.
TABLA_FUENTE_BASE EQU TABLA_FUENTE - $100
SPR00_PM_VULN_DER_CERRADA:                          ; $A1DE, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos vulnerable a la derecha, boca cerrada
    INCBIN "data/img/sprites/00_pm_vuln_der_cerrada.spr"
SPR01_PM_VULN_DER_BOCA90:                          ; $A26E, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos vulnerable a la derecha, boca abierta 90 grados
    INCBIN "data/img/sprites/01_pm_vuln_der_boca90.spr"
SPR02_PM_VULN_DER_BOCA95:                          ; $A2FE, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos vulnerable a la derecha, boca abierta 95 grados (mas abierta)
    INCBIN "data/img/sprites/02_pm_vuln_der_boca95.spr"
SPR03_PM_VULN_ABAJO_CERRADA:                          ; $A38E, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos vulnerable hacia abajo, boca cerrada
    INCBIN "data/img/sprites/03_pm_vuln_abajo_cerrada.spr"
SPR04_PM_VULN_ABAJO_SEMI:                          ; $A41E, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos vulnerable hacia abajo, boca semi abierta
    INCBIN "data/img/sprites/04_pm_vuln_abajo_semi.spr"
SPR05_PM_VULN_ABAJO_MAS:                          ; $A4AE, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos vulnerable hacia abajo, boca mas abierta
    INCBIN "data/img/sprites/05_pm_vuln_abajo_mas.spr"
SPR06_PM_VULN_ARRIBA:                          ; $A53E, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos vulnerable hacia arriba (de espaldas), unica vista
    INCBIN "data/img/sprites/06_pm_vuln_arriba.spr"
SPR07_PM_INV_DER_CERRADA:                          ; $A5CE, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos invencible a la derecha, boca cerrada
    INCBIN "data/img/sprites/07_pm_inv_der_cerrada.spr"
SPR08_PM_INV_DER_BOCA90:                          ; $A65E, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos invencible a la derecha, boca abierta 90 grados
    INCBIN "data/img/sprites/08_pm_inv_der_boca90.spr"
SPR09_PM_INV_DER_BOCA95:                          ; $A6EE, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos invencible a la derecha, boca abierta 95 grados
    INCBIN "data/img/sprites/09_pm_inv_der_boca95.spr"
SPR10_PM_INV_ABAJO_CERRADA:                          ; $A77E, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos invencible hacia abajo, boca cerrada
    INCBIN "data/img/sprites/10_pm_inv_abajo_cerrada.spr"
SPR11_PM_INV_ABAJO_MAS:                          ; $A80E, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos invencible hacia abajo, boca mas abierta
    INCBIN "data/img/sprites/11_pm_inv_abajo_mas.spr"
SPR12_PM_AVION_ARRIBA:                          ; $A89E, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos convertido en avion, hacia arriba
    INCBIN "data/img/sprites/12_pm_avion_arriba.spr"
SPR13_PM_OBRA_DER:                          ; $A92E, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos obra (saca bolas) hacia la derecha
    INCBIN "data/img/sprites/13_pm_obra_der.spr"
SPR14_PM_OBRA_ABAJO:                          ; $A9BE, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos obra (saca bolas) hacia abajo
    INCBIN "data/img/sprites/14_pm_obra_abajo.spr"
SPR15_PM_OBRA_ARRIBA:                          ; $AA4E, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos obra (saca bolas) hacia arriba (de espaldas)
    INCBIN "data/img/sprites/15_pm_obra_arriba.spr"
SPR16_PM_HIPO_DER_1:                          ; $AADE, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos hipopotamo (pisa fantasmas) a la derecha, paso 1
    INCBIN "data/img/sprites/16_pm_hipo_der_1.spr"
SPR17_PM_HIPO_DER_2:                          ; $AB6E, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos hipopotamo a la derecha, paso 2
    INCBIN "data/img/sprites/17_pm_hipo_der_2.spr"
SPR18_PM_HIPO_DER_3:                          ; $ABFE, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos hipopotamo a la derecha, paso 3
    INCBIN "data/img/sprites/18_pm_hipo_der_3.spr"
SPR19_PM_HIPO_ABAJO_1:                          ; $AC8E, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos hipopotamo hacia abajo, paso 1
    INCBIN "data/img/sprites/19_pm_hipo_abajo_1.spr"
SPR20_PM_HIPO_ABAJO_2:                          ; $AD1E, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos hipopotamo hacia abajo, paso 2
    INCBIN "data/img/sprites/20_pm_hipo_abajo_2.spr"
SPR21_PM_HIPO_ARRIBA_1:                          ; $ADAE, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos hipopotamo hacia arriba, paso 1
    INCBIN "data/img/sprites/21_pm_hipo_arriba_1.spr"
SPR22_PM_HIPO_ARRIBA_2:                          ; $AE3E, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos hipopotamo hacia arriba, paso 2
    INCBIN "data/img/sprites/22_pm_hipo_arriba_2.spr"
SPR23_PM_TANQUE_DER:                          ; $AECE, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos tanque a la derecha
    INCBIN "data/img/sprites/23_pm_tanque_der.spr"
SPR24_PM_HIPO_ABAJO_3:                          ; $AF5E, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos hipopotamo hacia abajo, paso 3
    INCBIN "data/img/sprites/24_pm_hipo_abajo_3.spr"
SPR25_PM_HIPO_ARRIBA_3:                          ; $AFEE, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos hipopotamo hacia arriba, paso 3
    INCBIN "data/img/sprites/25_pm_hipo_arriba_3.spr"
SPR26_DESCONOCIDO_CIRCULOS:                          ; $B07E, 144 bytes (2 planos AND/OR de 24x24 px) -- Sprite con cuatro circulos en el centro -- pendiente identificar
    INCBIN "data/img/sprites/26_desconocido_circulos.spr"
SPR27_FANTASMA_DER_1:                          ; $B10E, 144 bytes (2 planos AND/OR de 24x24 px) -- Fantasma a la derecha, paso 1
    INCBIN "data/img/sprites/27_fantasma_der_1.spr"
SPR28_FANTASMA_DER_2:                          ; $B19E, 144 bytes (2 planos AND/OR de 24x24 px) -- Fantasma a la derecha, paso 2
    INCBIN "data/img/sprites/28_fantasma_der_2.spr"
SPR29_FANTASMA_ABAJO_1:                          ; $B22E, 144 bytes (2 planos AND/OR de 24x24 px) -- Fantasma hacia abajo, paso 1
    INCBIN "data/img/sprites/29_fantasma_abajo_1.spr"
SPR30_FANTASMA_ABAJO_2:                          ; $B2BE, 144 bytes (2 planos AND/OR de 24x24 px) -- Fantasma hacia abajo, paso 2
    INCBIN "data/img/sprites/30_fantasma_abajo_2.spr"
SPR31_FANTASMA_ARRIBA_1:                          ; $B34E, 144 bytes (2 planos AND/OR de 24x24 px) -- Fantasma hacia arriba (de espaldas), paso 1
    INCBIN "data/img/sprites/31_fantasma_arriba_1.spr"
SPR32_FANTASMA_ARRIBA_2:                          ; $B3DE, 144 bytes (2 planos AND/OR de 24x24 px) -- Fantasma hacia arriba (de espaldas), paso 2
    INCBIN "data/img/sprites/32_fantasma_arriba_2.spr"
SPR33_FANTASMA_VULN_DER_1:                          ; $B46E, 144 bytes (2 planos AND/OR de 24x24 px) -- Fantasma vulnerable a la derecha, paso 1
    INCBIN "data/img/sprites/33_fantasma_vuln_der_1.spr"
SPR34_FANTASMA_VULN_DER_2:                          ; $B4FE, 144 bytes (2 planos AND/OR de 24x24 px) -- Fantasma vulnerable a la derecha, paso 2
    INCBIN "data/img/sprites/34_fantasma_vuln_der_2.spr"
SPR35_FANTASMA_VULN_ABAJO_1:                          ; $B58E, 144 bytes (2 planos AND/OR de 24x24 px) -- Fantasma vulnerable hacia abajo, paso 1
    INCBIN "data/img/sprites/35_fantasma_vuln_abajo_1.spr"
SPR36_FANTASMA_VULN_ABAJO_2:                          ; $B61E, 144 bytes (2 planos AND/OR de 24x24 px) -- Fantasma vulnerable hacia abajo, paso 2
    INCBIN "data/img/sprites/36_fantasma_vuln_abajo_2.spr"
SPR37_MARIQUITA_ABAJO:                          ; $B6AE, 144 bytes (2 planos AND/OR de 24x24 px) -- Mariquita hacia abajo
    INCBIN "data/img/sprites/37_mariquita_abajo.spr"
SPR38_MARIQUITA_ARRIBA:                          ; $B73E, 144 bytes (2 planos AND/OR de 24x24 px) -- Mariquita hacia arriba
    INCBIN "data/img/sprites/38_mariquita_arriba.spr"
SPR39_MARIQUITA_DER:                          ; $B7CE, 144 bytes (2 planos AND/OR de 24x24 px) -- Mariquita a la derecha
    INCBIN "data/img/sprites/39_mariquita_der.spr"
SPR40_MUERTE_PM_SEQ0:                          ; $B85E, 144 bytes (2 planos AND/OR de 24x24 px) -- Muerte comecocos (bola pequenya), secuencia 0
    INCBIN "data/img/sprites/40_muerte_pm_seq0.spr"
SPR41_MUERTE_PM_SEQ1:                          ; $B8EE, 144 bytes (2 planos AND/OR de 24x24 px) -- Muerte comecocos (bola grande), secuencia 1
    INCBIN "data/img/sprites/41_muerte_pm_seq1.spr"
SPR42_MUERTE_PM_SEQ2:                          ; $B97E, 144 bytes (2 planos AND/OR de 24x24 px) -- Muerte comecocos (descomposicion), secuencia 2
    INCBIN "data/img/sprites/42_muerte_pm_seq2.spr"
SPR43_MUERTE_PM_SEQ3:                          ; $BA0E, 144 bytes (2 planos AND/OR de 24x24 px) -- Muerte comecocos (descomposicion), secuencia 3
    INCBIN "data/img/sprites/43_muerte_pm_seq3.spr"
SPR44_MUERTE_PM_SEQ4:                          ; $BA9E, 144 bytes (2 planos AND/OR de 24x24 px) -- Muerte comecocos (descomposicion), secuencia 4 -- ultimo sprite de la muerte
    INCBIN "data/img/sprites/44_muerte_pm_seq4.spr"
SPR45_REPUGNANTE_DER_1:                          ; $BB2E, 144 bytes (2 planos AND/OR de 24x24 px) -- Repugnantoso a la derecha, paso 1
    INCBIN "data/img/sprites/45_repugnante_der_1.spr"
SPR46_REPUGNANTE_DER_2:                          ; $BBBE, 144 bytes (2 planos AND/OR de 24x24 px) -- Repugnantoso a la derecha, paso 2
    INCBIN "data/img/sprites/46_repugnante_der_2.spr"
SPR47_REPUGNANTE_DER_3:                          ; $BC4E, 144 bytes (2 planos AND/OR de 24x24 px) -- Repugnantoso a la derecha, paso 3
    INCBIN "data/img/sprites/47_repugnante_der_3.spr"
SPR48_REPUGNANTE_ABAJO_1:                          ; $BCDE, 144 bytes (2 planos AND/OR de 24x24 px) -- Repugnantoso hacia abajo, paso 1
    INCBIN "data/img/sprites/48_repugnante_abajo_1.spr"
SPR49_REPUGNANTE_ABAJO_2:                          ; $BD6E, 144 bytes (2 planos AND/OR de 24x24 px) -- Repugnantoso hacia abajo, paso 2
    INCBIN "data/img/sprites/49_repugnante_abajo_2.spr"
SPR50_REPUGNANTE_ABAJO_3:                          ; $BDFE, 144 bytes (2 planos AND/OR de 24x24 px) -- Repugnantoso hacia abajo, paso 3
    INCBIN "data/img/sprites/50_repugnante_abajo_3.spr"
SPR51_REPUGNANTE_ARRIBA_1:                          ; $BE8E, 144 bytes (2 planos AND/OR de 24x24 px) -- Repugnantoso hacia arriba (de espaldas), paso 1
    INCBIN "data/img/sprites/51_repugnante_arriba_1.spr"
SPR52_REPUGNANTE_ARRIBA_2:                          ; $BF1E, 144 bytes (2 planos AND/OR de 24x24 px) -- Repugnantoso hacia arriba (de espaldas), paso 2
    INCBIN "data/img/sprites/52_repugnante_arriba_2.spr"
SPR53_REPUGNANTE_ARRIBA_3:                          ; $BFAE, 144 bytes (2 planos AND/OR de 24x24 px) -- Repugnantoso hacia arriba (de espaldas), paso 3
    INCBIN "data/img/sprites/53_repugnante_arriba_3.spr"
SPR54_REPUGNANTE_DESPEINADO:                          ; $C03E, 144 bytes (2 planos AND/OR de 24x24 px) -- Repugnantoso despeinado hacia abajo (?) -- pendiente identificar
    INCBIN "data/img/sprites/54_repugnante_despeinado.spr"
SPR55_PUNTOS_400:                          ; $C0CE, 144 bytes (2 planos AND/OR de 24x24 px) -- 400 puntos (aparece donde se comio un fantasma)
    INCBIN "data/img/sprites/55_puntos_400.spr"
SPR56_PUNTOS_600:                          ; $C15E, 144 bytes (2 planos AND/OR de 24x24 px) -- 600 puntos (aparece donde se comio un fantasma)
    INCBIN "data/img/sprites/56_puntos_600.spr"
SPR57_PM_INV_ABAJO_SEMI:                          ; $C1EE, 144 bytes (2 planos AND/OR de 24x24 px) -- Comecocos invencible hacia abajo, boca semi abierta
    INCBIN "data/img/sprites/57_pm_inv_abajo_semi.spr"
SPR58_MUERTE_PM_RED1:                          ; $C27E, 144 bytes (2 planos AND/OR de 24x24 px) -- Muerte comecocos hacia abajo, triste, reduccion 1 -- inicio real de la secuencia de muerte
    INCBIN "data/img/sprites/58_muerte_pm_red1.spr"
SPR59_MUERTE_PM_RED2:                          ; $C30E, 144 bytes (2 planos AND/OR de 24x24 px) -- Muerte comecocos a la derecha, triste, reduccion 2
    INCBIN "data/img/sprites/59_muerte_pm_red2.spr"
SPR60_MUERTE_PM_RED3:                          ; $C39E, 144 bytes (2 planos AND/OR de 24x24 px) -- Muerte comecocos hacia arriba (de espaldas), reduccion 3
    INCBIN "data/img/sprites/60_muerte_pm_red3.spr"
SPR61_MUERTE_PM_RED4:                          ; $C42E, 144 bytes (2 planos AND/OR de 24x24 px) -- Muerte comecocos, izquierda, triste, reduccion 4 -- sigue en SPR40
    INCBIN "data/img/sprites/61_muerte_pm_red4.spr"
SPR62_FANTASMA_MUERTO:                          ; $C4BE, 144 bytes (2 planos AND/OR de 24x24 px) -- Fantasma muerto
    INCBIN "data/img/sprites/62_fantasma_muerto.spr"
SPR63_NULO:                          ; $C54E, 144 bytes (2 planos AND/OR de 24x24 px) -- Sprite nulo (blanco o negro, todo ceros)
    INCBIN "data/img/sprites/63_nulo.spr"
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
; ==============================================================
;  GRAFICOS_LOSETAS ($C600, 91 losetas x 32 bytes = 2912 bytes)
;  -- RESUELTA POR COMPLETO (sesion 41), mismo nombre EXACTO que
;  MSX. Localizada desde REDIBUJAR_LOSETA_BUFFER_VRAM ($99BD):
;  calcula direccion = $C600 + indice_loseta*32 (3 rotaciones
;  de bit = *32) y vuelca 16 filas x 2 bytes (LDI/LDI x16) al
;  buffer de pantalla -- MISMO formato exacto que MSX (16x16 px
;  monocromo, 2 bytes/fila). CONFIRMADO por comparacion directa:
;  los 2912 bytes son IDENTICOS BYTE A BYTE a GRAFICOS_LOSETAS de
;  MSX (recursos/graficos.html del proyecto hermano) -- mismo
;  fenomeno ya visto con los sprites, la fuente y las tablas de
;  animacion: MSX reutilizo estos graficos del original Spectrum
;  sin tocar un bit. Renderizadas en recursos/graficos.html con
;  los mismos nombres candidatos que identifico el usuario en el
;  proyecto MSX (misma numeracion e identidad visual: muros de
;  hierro/cemento/ladrillo, suelo con/sin bola, flechas, pistas
;  de tanque/avion, trampillas, items, decoracion). Sesion 42:
;  extraidas a ficheros individuales en data/img/tiles/*.til (32
;  bytes cada uno), mismo nombre de fichero EXACTO que MSX
;  (data/tiles/*.til), incluidas via INCBIN igual que los sprites
;  -- antes embebidos como DB inline. Ver FINDINGS.md sesiones
;  41/42 para el detalle completo.
; ==============================================================
GRAFICOS_LOSETAS:
    INCBIN "data/img/tiles/00_muro_hierro_pieza_individual.til"  ; tile 0
    INCBIN "data/img/tiles/01_muro_hierro_limite_superior_vertical.til"  ; tile 1
    INCBIN "data/img/tiles/02_muro_hierro_pared_vertical.til"  ; tile 2
    INCBIN "data/img/tiles/03_muro_hierro_limite_inferior_vertical.til"  ; tile 3
    INCBIN "data/img/tiles/04_muro_hierro_limite_izquierdo_horizontal.til"  ; tile 4
    INCBIN "data/img/tiles/05_muro_hierro_pared_horizontal.til"  ; tile 5
    INCBIN "data/img/tiles/06_muro_hierro_limite_derecho_horizontal.til"  ; tile 6
    INCBIN "data/img/tiles/07_muro_hierro_esquina_inf_izq.til"  ; tile 7
    INCBIN "data/img/tiles/08_muro_hierro_esquina_inf_der.til"  ; tile 8
    INCBIN "data/img/tiles/09_muro_hierro_esquina_sup_izq.til"  ; tile 9
    INCBIN "data/img/tiles/10_muro_hierro_esquina_sup_der.til"  ; tile 10
    INCBIN "data/img/tiles/11_muro_hierro_horizontal_union_abajo.til"  ; tile 11
    INCBIN "data/img/tiles/12_muro_hierro_horizontal_union_arriba.til"  ; tile 12
    INCBIN "data/img/tiles/13_muro_hierro_vertical_union_derecha.til"  ; tile 13
    INCBIN "data/img/tiles/14_muro_hierro_vertical_union_izquierda.til"  ; tile 14
    INCBIN "data/img/tiles/15_muro_hierro_cruce.til"  ; tile 15
    INCBIN "data/img/tiles/16_muro_cemento_pieza_individual.til"  ; tile 16
    INCBIN "data/img/tiles/17_muro_cemento_limite_superior_vertical.til"  ; tile 17
    INCBIN "data/img/tiles/18_muro_cemento_pared_vertical.til"  ; tile 18
    INCBIN "data/img/tiles/19_muro_cemento_limite_inferior_vertical.til"  ; tile 19
    INCBIN "data/img/tiles/20_muro_cemento_limite_izquierdo_horizontal.til"  ; tile 20
    INCBIN "data/img/tiles/21_muro_cemento_pared_horizontal.til"  ; tile 21
    INCBIN "data/img/tiles/22_muro_cemento_limite_derecho_horizontal.til"  ; tile 22
    INCBIN "data/img/tiles/23_muro_cemento_esquina_inf_izq.til"  ; tile 23
    INCBIN "data/img/tiles/24_muro_cemento_esquina_inf_der.til"  ; tile 24
    INCBIN "data/img/tiles/25_muro_cemento_esquina_sup_izq.til"  ; tile 25
    INCBIN "data/img/tiles/26_muro_cemento_esquina_sup_der.til"  ; tile 26
    INCBIN "data/img/tiles/27_muro_cemento_horizontal_union_abajo.til"  ; tile 27
    INCBIN "data/img/tiles/28_muro_cemento_horizontal_union_arriba.til"  ; tile 28
    INCBIN "data/img/tiles/29_muro_cemento_vertical_union_derecha.til"  ; tile 29
    INCBIN "data/img/tiles/30_muro_cemento_vertical_union_izquierda.til"  ; tile 30
    INCBIN "data/img/tiles/31_muro_cemento_cruce.til"  ; tile 31
    INCBIN "data/img/tiles/32_muro_ladrillo_pieza_individual.til"  ; tile 32
    INCBIN "data/img/tiles/33_muro_ladrillo_limite_superior_vertical.til"  ; tile 33
    INCBIN "data/img/tiles/34_muro_ladrillo_pared_vertical.til"  ; tile 34
    INCBIN "data/img/tiles/35_muro_ladrillo_limite_inferior_vertical.til"  ; tile 35
    INCBIN "data/img/tiles/36_muro_ladrillo_limite_izquierdo_horizontal.til"  ; tile 36
    INCBIN "data/img/tiles/37_muro_ladrillo_pared_horizontal.til"  ; tile 37
    INCBIN "data/img/tiles/38_muro_ladrillo_limite_derecho_horizontal.til"  ; tile 38
    INCBIN "data/img/tiles/39_muro_ladrillo_esquina_inf_izq.til"  ; tile 39
    INCBIN "data/img/tiles/40_muro_ladrillo_esquina_inf_der.til"  ; tile 40
    INCBIN "data/img/tiles/41_muro_ladrillo_esquina_sup_izq.til"  ; tile 41
    INCBIN "data/img/tiles/42_muro_ladrillo_esquina_sup_der.til"  ; tile 42
    INCBIN "data/img/tiles/43_muro_ladrillo_horizontal_union_abajo.til"  ; tile 43
    INCBIN "data/img/tiles/44_muro_ladrillo_horizontal_union_arriba.til"  ; tile 44
    INCBIN "data/img/tiles/45_suelo_con_bola_1.til"  ; tile 45
    INCBIN "data/img/tiles/46_suelo_con_bola_2.til"  ; tile 46
    INCBIN "data/img/tiles/47_suelo_con_bola_3.til"  ; tile 47
    INCBIN "data/img/tiles/48_suelo_con_bola_clavada_1.til"  ; tile 48
    INCBIN "data/img/tiles/49_suelo_con_bola_clavada_2.til"  ; tile 49
    INCBIN "data/img/tiles/50_suelo_con_bola_clavada_3.til"  ; tile 50
    INCBIN "data/img/tiles/51_flecha_arriba.til"  ; tile 51
    INCBIN "data/img/tiles/52_flecha_abajo.til"  ; tile 52
    INCBIN "data/img/tiles/53_flecha_izquierda.til"  ; tile 53
    INCBIN "data/img/tiles/54_flecha_derecha.til"  ; tile 54
    INCBIN "data/img/tiles/55_pista_tanque_vertical.til"  ; tile 55
    INCBIN "data/img/tiles/56_linea_electrica_puerta_fantasmas_a.til"  ; tile 56
    INCBIN "data/img/tiles/57_linea_electrica_puerta_fantasmas_b.til"  ; tile 57
    INCBIN "data/img/tiles/58_pista_avion_recto.til"  ; tile 58
    INCBIN "data/img/tiles/59_item_suelo_sin_confirmar.til"  ; tile 59
    INCBIN "data/img/tiles/60_item_bola_de_poder.til"  ; tile 60
    INCBIN "data/img/tiles/61_item_hipopotamo.til"  ; tile 61
    INCBIN "data/img/tiles/62_item_herramienta.til"  ; tile 62
    INCBIN "data/img/tiles/63_suelo_sin_bola_1.til"  ; tile 63
    INCBIN "data/img/tiles/64_suelo_sin_bola_2.til"  ; tile 64
    INCBIN "data/img/tiles/65_suelo_sin_bola_3.til"  ; tile 65
    INCBIN "data/img/tiles/66_loseta_solida_negra.til"  ; tile 66
    INCBIN "data/img/tiles/67_trampilla_a_abajo_izquierda.til"  ; tile 67
    INCBIN "data/img/tiles/68_trampilla_a_abajo_derecha.til"  ; tile 68
    INCBIN "data/img/tiles/69_trampilla_b_abajo_derecha.til"  ; tile 69
    INCBIN "data/img/tiles/70_muro_ladrillo_suelto.til"  ; tile 70
    INCBIN "data/img/tiles/71_trampilla_b_arriba_izquierda.til"  ; tile 71
    INCBIN "data/img/tiles/72_trampilla_b_arriba_derecha.til"  ; tile 72
    INCBIN "data/img/tiles/73_trampilla_b_abajo_izquierda.til"  ; tile 73
    INCBIN "data/img/tiles/74_trampilla_a_arriba_izquierda.til"  ; tile 74
    INCBIN "data/img/tiles/75_trampilla_a_arriba_derecha.til"  ; tile 75
    INCBIN "data/img/tiles/76_trampilla_transicion_arriba_izquierda.til"  ; tile 76
    INCBIN "data/img/tiles/77_trampilla_transicion_arriba_derecha.til"  ; tile 77
    INCBIN "data/img/tiles/78_trampilla_transicion_abajo_izquierda.til"  ; tile 78
    INCBIN "data/img/tiles/79_trampilla_transicion_abajo_derecha.til"  ; tile 79
    INCBIN "data/img/tiles/80_puerta_fantasmas_inicio_izquierdo.til"  ; tile 80
    INCBIN "data/img/tiles/81_puerta_fantasmas_inicio_derecho.til"  ; tile 81
    INCBIN "data/img/tiles/82_pista_avion_remate_izquierdo.til"  ; tile 82
    INCBIN "data/img/tiles/83_pista_avion_remate_derecho.til"  ; tile 83
    INCBIN "data/img/tiles/84_mosaico_comecocos_1.til"  ; tile 84
    INCBIN "data/img/tiles/85_mosaico_comecocos_2.til"  ; tile 85
    INCBIN "data/img/tiles/86_mosaico_comecocos_3.til"  ; tile 86
    INCBIN "data/img/tiles/87_mosaico_comecocos_4.til"  ; tile 87
    INCBIN "data/img/tiles/88_estrella_pequena.til"  ; tile 88
    INCBIN "data/img/tiles/89_estrella_mediana.til"  ; tile 89
    INCBIN "data/img/tiles/90_estrella_grande.til"  ; tile 90
; ==============================================================
;  $D160-$EFB5 -- reconstruccion mecanica de primera pasada,
;  volcada como DB directamente desde FISICO/CODE.bin (sesion 41,
;  correccion de un desajuste de bytes propio al reconstruir
;  GRAFICOS_LOSETAS -- ver FINDINGS.md) en vez de mantener el
;  desensamblado mecanico de primera pasada, que quedo invalidado
;  por ese desajuste. Incluye el tramo final compartido con el
;  payload de portada, $EA60-$EFB5. Sesion 51: $D160-$DBDF
;  RESUELTOS (CUERPO_L11-L14, ver abajo). Sesion 55: $E038-$E37F
;  RESUELTO POR COMPLETO (motor de sonido, ver su propia cabecera
;  mas abajo). CERRADO sesion 56: $DBE0-$E037 (guiones de demo +
;  49 fragmentos de cancion/SFX) y $E380-$EFB5 (mas guiones de demo +
;  bitmap del marco decorativo + relleno) tambien identificados por
;  completo -- no queda ningun byte sin identificar en todo el rango
;  $D160-$EFB5.
; ==============================================================
CUERPO_L11:  ; $D160, 672 bytes -- nivel 11. RESUELTOS POR COMPLETO
; (sesion 51) los 4 cuerpos de nivel restantes (11-14) que TABLA_NIVELES
; referencia fuera del rango de sesion 50 -- mismo patron de
; verificacion por aritmetica de punteros, encajan EXACTOS y sin
; hueco entre si. Ver FINDINGS.md sesion 51.
    INCBIN "data/niveles/body_l11.bin"
CUERPO_L12:  ; $D400, 608 bytes -- nivel 12.
    INCBIN "data/niveles/body_l12.bin"
CUERPO_L13:  ; $D660, 672 bytes -- nivel 13.
    INCBIN "data/niveles/body_l13.bin"
CUERPO_L14:  ; $D900, 736 bytes -- nivel 14. Localizado por aritmetica de
; punteros de TABLA_NIVELES contra este rango (sesion 51, mismo
; patron que sesion 50): encaja EXACTO y sin hueco justo despues
; de CUERPO_L13.
    INCBIN "data/niveles/body_l14.bin"
; $DBE0 -- fin de CUERPO_L14. $DBE0-$DD17 (312 B) RESUELTO POR
; COMPLETO en sesion 56: son GUIONES DE DEMO (entrada de joystick
; pregrabada) para INICIAR_DEMO/TABLA_PERFILES_DEMO -- NO datos de
; sonido, corrige la caracterizacion de sesiones 53/55 (ver cabecera
; de INICIAR_DEMO mas arriba para la correccion completa y el formato
; de par (umbral_frames,direccion)). 4 guiones indexados por
; TABLA_PERFILES_DEMO (niveles 1/2/4/5 -- el de nivel 5 vive en
; $E380, fuera de este bloque) mas 4 guiones "huerfanos" con el mismo
; formato pero sin indice conocido que los referencie (candidato:
; tomas descartadas/version antigua del ciclo de demo).
;
; NOMBRES ALINEADOS CON MSX (sesion 56 continuacion 30): MSX tiene el
; MISMO fenomeno exacto (madmix1_body.asm ~4544) con los MISMOS
; nombres -- GUION_DEMO_NIVEL1/2/4/5 (sin guion bajo antes del numero,
; antes GUION_DEMO_NIVEL_1/2/4/5 aqui) y GUION_DEMO_SINREF_1-6 (antes
; GUION_DEMO_EXTRA_1-6 aqui -- MSX tambien tiene 6 "huerfanos", mismo
; termino "SINREF" = sin referencia conocida, mas preciso que "EXTRA").
GUION_DEMO_NIVEL1:          ; $DBE0, nivel 1 -- TABLA_PERFILES_DEMO entrada 0
    INCBIN "data/sound/demo/00_guion_demo_nivel1_dbe0.bin"
GUION_DEMO_NIVEL2:          ; $DC20, nivel 2 -- TABLA_PERFILES_DEMO entrada 1
    INCBIN "data/sound/demo/01_guion_demo_nivel2_dc20.bin"
GUION_DEMO_SINREF_1:          ; $DC7E, sin indice conocido en TABLA_PERFILES_DEMO
    INCBIN "data/sound/demo/02_guion_demo_extra_dc7e.bin"
GUION_DEMO_NIVEL4:          ; $DC90, nivel 4 -- TABLA_PERFILES_DEMO entrada 2
    INCBIN "data/sound/demo/03_guion_demo_nivel4_dc90.bin"
GUION_DEMO_SINREF_2:          ; $DCD2, sin indice conocido en TABLA_PERFILES_DEMO
    INCBIN "data/sound/demo/04_guion_demo_extra_dcd2.bin"
GUION_DEMO_SINREF_3:          ; $DCD6, sin indice conocido en TABLA_PERFILES_DEMO
    INCBIN "data/sound/demo/05_guion_demo_extra_dcd6.bin"
GUION_DEMO_SINREF_4:          ; $DCEE, sin indice conocido en TABLA_PERFILES_DEMO
    INCBIN "data/sound/demo/06_guion_demo_extra_dcee.bin"
; $DD00-$DD17 (24 bytes): relleno a cero antes del motor de musica.
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    DB $00,$00,$00,$00,$00,$00,$00,$00
; $DD18 -- aqui empieza el motor de musica de verdad (ISR_SONIDO,
; $E038), ver su cabecera de seccion mas abajo. 49 fragmentos
; (6 guiones + 43 subpatrones compartidos) localizados y extraidos en
; sesion 56 con tools/mmsnd_tool.py -- INCBIN en el mismo orden exacto
; en que aparecen en memoria (verificado sin huecos). Sigue sin
; desensamblar cancion por cancion; herramientas de texto/WAV en
; tools/mmsnd_tool.py / tools/mmsnd_render.py.
    INCBIN "data/sound/spt/00_subpatron_AB_dd18.spt"  ; $DD18, 5 B
    INCBIN "data/sound/spt/01_subpatron_B_dd1d.spt"  ; $DD1D, 7 B
    INCBIN "data/sound/spt/02_subpatron_B_dd24.spt"  ; $DD24, 7 B
    INCBIN "data/sound/spt/03_subpatron_B_dd2b.spt"  ; $DD2B, 13 B
    INCBIN "data/sound/spt/04_subpatron_B_dd38.spt"  ; $DD38, 7 B
    INCBIN "data/sound/spt/05_subpatron_B_dd3f.spt"  ; $DD3F, 7 B
    INCBIN "data/sound/spt/06_subpatron_B_dd46.spt"  ; $DD46, 13 B
    INCBIN "data/sound/spt/07_subpatron_A_dd53.spt"  ; $DD53, 11 B
    INCBIN "data/sound/spt/08_subpatron_B_dd5e.spt"  ; $DD5E, 4 B
    INCBIN "data/sound/spt/09_subpatron_A_dd62.spt"  ; $DD62, 17 B
    INCBIN "data/sound/spt/10_subpatron_B_dd73.spt"  ; $DD73, 17 B
    INCBIN "data/sound/spt/11_subpatron_A_dd84.spt"  ; $DD84, 12 B
    INCBIN "data/sound/spt/12_subpatron_A_dd90.spt"  ; $DD90, 12 B
    INCBIN "data/sound/spt/13_subpatron_A_dd9c.spt"  ; $DD9C, 17 B
    INCBIN "data/sound/spt/14_subpatron_A_ddad.spt"  ; $DDAD, 18 B
    INCBIN "data/sound/spt/15_subpatron_A_ddbf.spt"  ; $DDBF, 11 B
    INCBIN "data/sound/spt/16_subpatron_A_ddca.spt"  ; $DDCA, 19 B
    INCBIN "data/sound/spt/17_subpatron_A_dddd.spt"  ; $DDDD, 13 B
    INCBIN "data/sound/spt/18_subpatron_A_ddea.spt"  ; $DDEA, 21 B
    INCBIN "data/sound/spt/19_subpatron_A_ddff.spt"  ; $DDFF, 49 B
    INCBIN "data/sound/spt/20_subpatron_B_de30.spt"  ; $DE30, 17 B
    INCBIN "data/sound/spt/21_subpatron_B_de41.spt"  ; $DE41, 13 B
    INCBIN "data/sound/spt/22_subpatron_A_de4e.spt"  ; $DE4E, 34 B
    INCBIN "data/sound/spt/23_subpatron_A_de70.spt"  ; $DE70, 18 B
    INCBIN "data/sound/spt/24_subpatron_A_de82.spt"  ; $DE82, 18 B
    INCBIN "data/sound/spt/25_subpatron_A_de94.spt"  ; $DE94, 9 B
    INCBIN "data/sound/spt/26_subpatron_A_de9d.spt"  ; $DE9D, 16 B
    INCBIN "data/sound/spt/27_subpatron_A_dead.spt"  ; $DEAD, 19 B
    INCBIN "data/sound/spt/28_subpatron_A_dec0.spt"  ; $DEC0, 20 B
    INCBIN "data/sound/spt/29_subpatron_A_ded4.spt"  ; $DED4, 20 B
    INCBIN "data/sound/spt/30_subpatron_A_dee8.spt"  ; $DEE8, 25 B
    INCBIN "data/sound/spt/31_subpatron_A_df01.spt"  ; $DF01, 12 B
    INCBIN "data/sound/spt/32_subpatron_A_df0d.spt"  ; $DF0D, 14 B
    INCBIN "data/sound/spt/33_subpatron_A_df1b.spt"  ; $DF1B, 13 B
    INCBIN "data/sound/spt/34_subpatron_A_df28.spt"  ; $DF28, 32 B
    INCBIN "data/sound/spt/35_subpatron_A_df48.spt"  ; $DF48, 12 B
    INCBIN "data/sound/spt/36_subpatron_A_df54.spt"  ; $DF54, 12 B
    INCBIN "data/sound/spt/37_subpatron_A_df60.spt"  ; $DF60, 12 B
    INCBIN "data/sound/spt/38_subpatron_A_df6c.spt"  ; $DF6C, 14 B
    INCBIN "data/sound/spt/39_subpatron_A_df7a.spt"  ; $DF7A, 10 B
    INCBIN "data/sound/spt/40_subpatron_B_df84.spt"  ; $DF84, 13 B
    INCBIN "data/sound/spt/41_subpatron_B_df91.spt"  ; $DF91, 13 B
    INCBIN "data/sound/spt/42_subpatron_A_df9e.spt"  ; $DF9E, 25 B
; --- Las 3 canciones: RASTREADOS sesion 56 continuacion 33 los 4
; unicos sitios de todo el fichero que escriben $E212/$E216 antes de
; CALL REPRODUCIR_SONIDO (unicos disparadores posibles) -- mapeo
; CONFIRMADO: CANCION_PRESENTACION suena en ESPERAR_TECLA_INICIO
; (pantalla de titulo) y otra vez en BUCLE_ESPERA_PARTIDA_NUEVA (solo
; al arrancar partida nueva); CANCION_INICIO_NIVEL suena al final de
; BUSCAR_COLUMNA_HUD (cada vez que arranca a jugarse un nivel -- nueva
; partida, siguiente nivel, o tras perder una vida);
; CANCION_FIN_MODO_ESPECIAL suena en BUCLE_PRINCIPAL_JUEGO cuando
; MODO_ESPECIAL_ACTIVO llega a 0 (se acaba el efecto de bola de
; poder/hipopotamo). Encaja con el tamano: PRESENTACION (80 B) es una
; melodia real, INICIO_NIVEL/FIN_MODO_ESPECIAL (14 B cada una) son
; jingles cortos, no canciones completas.
GUION_CANCION_PRESENTACION_CANAL_A:
    INCBIN "data/sound/snd/01_cancion1_canalA_dfb7.snd"  ; $DFB7, 19 B
GUION_CANCION_PRESENTACION_CANAL_B:
    INCBIN "data/sound/snd/01_cancion1_canalB_dfca.snd"  ; $DFCA, 61 B
GUION_CANCION_INICIO_NIVEL_CANAL_A:
    INCBIN "data/sound/snd/02_cancion2_canalA_e007.snd"  ; $E007, 7 B
GUION_CANCION_INICIO_NIVEL_CANAL_B:
    INCBIN "data/sound/snd/02_cancion2_canalB_e00e.snd"  ; $E00E, 7 B
GUION_CANCION_FIN_MODO_ESPECIAL_CANAL_A:
    INCBIN "data/sound/snd/03_cancion3_canalA_e015.snd"  ; $E015, 7 B
GUION_CANCION_FIN_MODO_ESPECIAL_CANAL_B:
    INCBIN "data/sound/snd/03_cancion3_canalB_e01c.snd"  ; $E01C, 7 B
; $E023-$E037 (21 bytes): relleno a cero, confirmado sesion 56.
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    DB $00,$00,$00,$00,$00
; ==============================================================
;  MOTOR DE SONIDO ($E038-$E37F, 840 bytes) -- RESUELTO POR COMPLETO
;  (sesion 55), desensamblado a mano instruccion a instruccion,
;  verificado por convergencia de todos los saltos internos (mismo
;  metodo que sesiones 40-41/54). Subsistema propio de Spectrum, sin
;  equivalente MSX (que usa el PSG AY-3-8910 en su lugar, ver
;  [[madmix_sound_chip_differences_expected]]).
;
;  CORRECCION DE ALCANCE respecto a sesion 53: el hallazgo del
;  prologo DI/PUSH en $E038 solo demostraba que el tramo EMPEZABA con
;  codigo real, no que los 3966 bytes completos ($E038-$EFB5) lo
;  fueran. En realidad el motor real ocupa solo estos 840 bytes
;  ($E038-$E37F); el resto ($E380-$EFB5, ~3586 bytes) es MAS DATOS,
;  pero NO todo son guiones de cancion/SFX como se penso al principio:
;  CERRADO sesion 56 -- de esos ~3586 bytes, 114 son mas guiones de
;  demo (ver GUION_DEMO_NIVEL5/EXTRA_5/EXTRA_6 mas abajo) y 3012 son
;  el bitmap del marco decorativo (BITMAP_MARCO_DECORATIVO) + relleno
;  final. No queda ningun byte de este tramo sin identificar.
;
;  ARQUITECTURA (motor de 2 "canales" dirigido por interrupcion,
;  tipico de reproductores de altavoz en Spectrum 48K):
;   - ISR_SONIDO se instala como el vector de interrupcion modo 2
;     real del juego (parchea $6061-$6062, guardando el valor
;     anterior en ISR_VECTOR_GUARDADO para restaurarlo al terminar)
;     -- se re-ejecuta en CADA interrupcion (50 veces/seg) mientras el
;     sonido esta activo. Cada tick decrementa 2 contadores de
;     duracion (uno por canal, ver truco de codigo automodificable
;     mas abajo); cuando un contador llega a 0, lee el siguiente byte
;     de guion del canal (via IX/IY) y lo despacha.
;   - Canal A (registro IX): generador de TONO/melodia. Sus bytes de
;     guion son "notas" (bits0-5 = indice en TABLA_TONOS_CANAL_A,
;     bits6-7 = indice en TABLA_DURACIONES) o comandos especiales
;     $FF/$FE/$FD/$FC/$FB/$FA (fin de cancion, reset, llamada/retorno
;     a subpatron via pila privada, y 2 parches de codigo
;     automodificable para variantes de vibrato/tempo).
;   - Canal B (registro IY): generador de PERCUSION. Sus bytes de
;     guion usan bits0-2 como indice (0-7) en TABLA_PERCUSION, tabla
;     de saltos a solo 4 rutinas de ruido reales (cada una duplicada
;     dos veces, ocupando las 8 entradas) que hacen OUT ($FE),A
;     directamente durante la propia interrupcion (percusion muy
;     corta, no usa el bucle de primer plano).
;   - El TONO real de canal A no lo genera la interrupcion, sino un
;     bucle activo en primer plano (BUCLE_TONO_CANAL_A) que alterna
;     el altavoz continuamente mientras no se pulse ninguna tecla --
;     REPRODUCIR_SONIDO (el punto de entrada real, antes CODE_E1F9,
;     llamado 4 veces desde fuera) cae directamente en el una vez
;     configurado todo, y no vuelve hasta que el guion señala
;     "terminado" (FLAG_ESTADO_SONIDO=2) o el jugador pulsa una tecla.
;     La ISR preserva AF/BC/DE/HL en su prologo precisamente para no
;     romper los contadores del bucle activo mientras lo interrumpe.
;   - TRUCO DE CODIGO AUTOMODIFICABLE (x4 -- corregido sesion 55,
;     inicialmente se documentaron solo 3), ahorro tipico de memoria
;     en 8 bits: (1) los contadores de duracion de cada canal son el
;     operando inmediato de sendas "LD A,n" (FLAG_DURACION_CANAL_A/B
;     en $E03E/$E048), parcheado directamente por la propia ISR en
;     vez de usar una variable aparte; (2) los punteros de guion de
;     cada canal son el operando de "LD IX,nn"/"LD IY,nn" en
;     REPRODUCIR_SONIDO ($E212/$E216) -- por eso quien llama escribe
;     ahi (ver INICIO y demas sitios de llamada) antes del CALL; (3)
;     los comandos $FB/$FA de canal A no cargan un parametro, sino
;     que SOBRESCRIBEN 8 bytes de codigo ejecutable dentro del propio
;     bucle de tono (TONO_PATRON_BASE, $E24D-$E254) con una de 2
;     variantes precompiladas (COPIAR_PATRON_TONO/PATRON_TONO_1/2);
;     (4) el periodo de tono activo ($E23E, escrito por CANAL_A_NOTA)
;     es el operando de "LD BC,$0000" dentro de BUCLE_TONO_CANAL_A --
;     este SE ME PASO en el primer analisis de esta sesion (crei que
;     el bucle de tono ignoraba la tabla de tonos por completo);
;     confirmado con un simulador Z80 minimo escrito para la ocasion
;     (verifica $E23E=$00FB -> ~277 Hz, $E23E=$013C -> ~209 Hz,
;     coincide con la escala cromatica de TABLA_TONOS_CANAL_A). El
;     bucle usa un SEGUNDO contador (DE, mitad del periodo) que
;     conmuta el MISMO bit de altavoz a una tasa relacionada (tambien
;     con su propio operando automodificable, $E25C y $E26E) --
;     produce un tono con algo de "textura" en vez de un cuadrado puro.
;   - PERCUSION_3/PERCUSION_4 leen una tabla de 2 valores por
;     iteracion desde $0280 (zona de sistema en RAM baja, reutilizada
;     como area de trabajo) -- candidato sin confirmar por que esa
;     direccion en concreto ni quien la rellena.
; ==============================================================
FLAG_DURACION_CANAL_A EQU $E03E    ; operando automodificable de "LD A,$00" en ISR_SONIDO
FLAG_DURACION_CANAL_B EQU $E048    ; operando automodificable de "LD A,$00" en PROCESAR_CANAL_B_TICK
ISR_SONIDO:
    DI
    PUSH AF
    PUSH BC
    PUSH DE
    PUSH HL
    LD A,$00                       ; FLAG_DURACION_CANAL_A ($E03E, automodificado)
    OR A
    JP Z,PROCESAR_NOTA_CANAL_A
    DEC A
    LD (FLAG_DURACION_CANAL_A),A
PROCESAR_CANAL_B_TICK:
    LD A,$00                       ; FLAG_DURACION_CANAL_B ($E048, automodificado)
    OR A
    JP Z,PROCESAR_NOTA_CANAL_B
    DEC A
    LD (FLAG_DURACION_CANAL_B),A
FIN_ISR_SONIDO:
    POP HL
    POP DE
    POP BC
    POP AF
    EI
    RETI
PROCESAR_NOTA_CANAL_A:
    LD A,(IX+$00)
    INC IX
    CP $FF
    JR NZ,CANAL_A_CMD_FE
    LD A,$02                       ; FLAG_ESTADO_SONIDO=2 ("terminado")
    LD (FLAG_ESTADO_SONIDO),A
    LD HL,BUCLE_TONO_CANAL_A
    LD ($E277),HL                  ; direccion de reanudacion del bucle de tono
    JP FIN_ISR_SONIDO
CANAL_A_CMD_FE:
    CP $FE
    JR NZ,CANAL_A_CMD_FD
    LD HL,BUCLE_TONO_CANAL_A
    LD ($E277),HL
    LD A,$00
    LD (FLAG_ESTADO_SONIDO),A
    LD A,(TABLA_DURACIONES)        ; duracion por defecto (indice 0)
    LD (FLAG_DURACION_CANAL_A),A
    JP PROCESAR_CANAL_B_TICK
CANAL_A_CMD_FD:                    ; "llamar a subpatron", guarda retorno en PILA_CANAL_A
    CP $FD
    JR NZ,CANAL_A_CMD_FC
    LD L,(IX+$00)
    INC IX
    LD H,(IX+$00)
    INC IX
    LD (SP_GUARDADO_TEMP),SP
    LD SP,(PILA_CANAL_A)
    PUSH IX
    PUSH HL
    POP IX                         ; IX = direccion del subpatron (HL); IX antiguo queda en la pila privada
    LD (PILA_CANAL_A),SP
    LD SP,(SP_GUARDADO_TEMP)
    JP PROCESAR_NOTA_CANAL_A
CANAL_A_CMD_FC:                    ; "retornar de subpatron"
    CP $FC
    JR NZ,CANAL_A_CMD_FB
    LD (SP_GUARDADO_TEMP),SP
    LD SP,(PILA_CANAL_A)
    POP IX
    LD (PILA_CANAL_A),SP
    LD SP,(SP_GUARDADO_TEMP)
    JP PROCESAR_NOTA_CANAL_A
CANAL_A_CMD_FB:                    ; parche de codigo automodificable, variante 1
    CP $FB
    JR NZ,CANAL_A_CMD_FA
    LD HL,PATRON_TONO_1
    CALL COPIAR_PATRON_TONO
    JP PROCESAR_NOTA_CANAL_A
CANAL_A_CMD_FA:                    ; parche de codigo automodificable, variante 2
    CP $FA
    JR NZ,CANAL_A_NOTA
    LD HL,PATRON_TONO_2
    CALL COPIAR_PATRON_TONO
    JP PROCESAR_NOTA_CANAL_A
CANAL_A_NOTA:                      ; nota normal: bits0-5=tono, bits6-7=duracion
    LD B,A
    AND $3F
    LD L,A
    LD H,$00
    ADD HL,HL
    LD DE,TABLA_TONOS_CANAL_A
    ADD HL,DE
    LD E,(HL)
    INC HL
    LD D,(HL)
    LD ($E23E),DE                  ; periodo de tono activo -- CUARTO caso de codigo
                                    ; automodificable del motor (sesion 55): $E23E-E23F
                                    ; es el operando de "LD BC,$0000" dentro de
                                    ; BUCLE_TONO_CANAL_A, verificado por simulacion Z80
                                    ; (ver su cabecera)
    LD HL,BUCLE_TONO_CANAL_A
    LD ($E277),HL
    LD A,$01                       ; FLAG_ESTADO_SONIDO=1 ("sonando")
    LD (FLAG_ESTADO_SONIDO),A
    LD A,B
    AND $C0
    RLCA
    RLCA                           ; bits6-7 de la nota -> indice 0-3
    LD L,A
    LD H,$00
    LD DE,TABLA_DURACIONES
    ADD HL,DE
    LD A,(HL)
    LD (FLAG_DURACION_CANAL_A),A
    JP PROCESAR_CANAL_B_TICK
PROCESAR_NOTA_CANAL_B:
    LD A,(IY+$00)
    CP $FF                         ; fin de guion -- a diferencia de canal A, no marca "terminado"
    JP Z,FIN_ISR_SONIDO
    INC IY
    CP $FE
    JR NZ,CANAL_B_CMD_FD
    LD A,(TABLA_DURACIONES)
    LD (FLAG_DURACION_CANAL_B),A
    JP FIN_ISR_SONIDO
CANAL_B_CMD_FD:                    ; "llamar a subpatron", guarda retorno en PILA_CANAL_B
    CP $FD
    JR NZ,CANAL_B_CMD_FC
    LD L,(IY+$00)
    INC IY
    LD H,(IY+$00)
    INC IY
    LD (SP_GUARDADO_TEMP),SP
    LD SP,(PILA_CANAL_B)
    PUSH IY
    PUSH HL
    POP IY
    LD (PILA_CANAL_B),SP
    LD SP,(SP_GUARDADO_TEMP)
    JP PROCESAR_NOTA_CANAL_B
CANAL_B_CMD_FC:                    ; "retornar de subpatron"
    CP $FC
    JR NZ,CANAL_B_NOTA
    LD (SP_GUARDADO_TEMP),SP
    LD SP,(PILA_CANAL_B)
    POP IY
    LD (PILA_CANAL_B),SP
    LD SP,(SP_GUARDADO_TEMP)
    JP PROCESAR_NOTA_CANAL_B
CANAL_B_NOTA:                      ; percusion: bits0-2 = indice 0-7 en TABLA_PERCUSION
    AND $07
    LD L,A
    LD H,$00
    ADD HL,HL
    LD DE,TABLA_PERCUSION
    ADD HL,DE
    LD A,(HL)
    INC HL
    LD H,(HL)
    LD L,A
    LD A,(TABLA_DURACIONES)
    LD (FLAG_DURACION_CANAL_B),A
    JP (HL)                        ; salta a una de las 4 rutinas PERCUSION_*
PERCUSION_1:
    LD E,$32
    LD C,$00
PERCUSION_1_LOOP:
    LD B,C
PERCUSION_1_ESPERA1:
    DJNZ PERCUSION_1_ESPERA1
    LD A,(BYTE_SALIDA_ALTAVOZ)
    OUT ($FE),A
    LD A,C
    ADD A,$02
    LD C,A
    LD B,A
PERCUSION_1_ESPERA2:
    DJNZ PERCUSION_1_ESPERA2
    LD A,(BYTE_SALIDA_ALTAVOZ)
    OR $F8
    OUT ($FE),A
    DEC E
    JR NZ,PERCUSION_1_LOOP
    JP FIN_ISR_SONIDO
PERCUSION_2:
    LD E,$32
    LD C,$00
PERCUSION_2_LOOP:
    LD B,C
PERCUSION_2_ESPERA1:
    DJNZ PERCUSION_2_ESPERA1
    LD A,(BYTE_SALIDA_ALTAVOZ)
    OUT ($FE),A
    LD A,C
    ADD A,$04
    LD C,A
    LD B,A
PERCUSION_2_ESPERA2:
    DJNZ PERCUSION_2_ESPERA2
    LD A,(BYTE_SALIDA_ALTAVOZ)
    OR $F8
    OUT ($FE),A
    DEC E
    JR NZ,PERCUSION_2_LOOP
    JP FIN_ISR_SONIDO
PERCUSION_3:                       ; lee pares de $0280 en vez de generarlos por formula
    LD E,$4B
    LD HL,$0280
PERCUSION_3_LOOP:
    LD B,(HL)
PERCUSION_3_ESPERA1:
    DJNZ PERCUSION_3_ESPERA1
    LD A,(BYTE_SALIDA_ALTAVOZ)
    OUT ($FE),A
    INC HL
    LD B,(HL)
PERCUSION_3_ESPERA2:
    DJNZ PERCUSION_3_ESPERA2
    INC HL
    LD A,(BYTE_SALIDA_ALTAVOZ)
    OR $F8
    OUT ($FE),A
    DEC E
    JR NZ,PERCUSION_3_LOOP
    JP FIN_ISR_SONIDO
PERCUSION_4:                       ; recorre los 8 bits de cada byte de $0280 ("ruido")
    LD E,$50
    LD HL,$0280
PERCUSION_4_LOOP:
    LD C,(HL)
    INC HL
    LD B,$08
PERCUSION_4_BITS:
    RRC C
    LD A,C
    AND $F0
    LD D,A
    LD A,(BYTE_SALIDA_ALTAVOZ)
    AND $07
    OR D
    OUT ($FE),A
    DJNZ PERCUSION_4_BITS
    DEC E
    JR NZ,PERCUSION_4_LOOP
    JP FIN_ISR_SONIDO
REPRODUCIR_SONIDO:                 ; punto de entrada externo real (antes CODE_E1F9)
    XOR A
    LD (FLAG_ESTADO_SONIDO),A
    LD (FLAG_DURACION_CANAL_A),A
    LD (FLAG_DURACION_CANAL_B),A
    DI
    LD HL,($6061)
    LD (ISR_VECTOR_GUARDADO),HL
    LD HL,ISR_SONIDO
    LD ($6061),HL                  ; instala ISR_SONIDO como vector IM2 real del juego
    LD IX,$E210                    ; PUNTERO_CANAL_A: operando automodificable ($E212-E213),
                                    ; el llamador escribe ahi (LD ($E212),HL) antes de este CALL
    LD IY,$E214                    ; PUNTERO_CANAL_B: idem, operando en $E216-E217
    LD HL,PILA_CANAL_A_MEM
    LD (PILA_CANAL_A),HL
    LD HL,PILA_CANAL_B_MEM
    LD (PILA_CANAL_B),HL
    EI
BUCLE_TONO_CANAL_A:                 ; bucle activo de primer plano -- genera el tono real
    XOR A
    IN A,($FE)
    OR $E0
    INC A
    JP NZ,DETENER_SONIDO            ; alguna tecla pulsada -> abortar
    LD A,(FLAG_ESTADO_SONIDO)
    OR A
    JR Z,BUCLE_TONO_CANAL_A          ; sin nota activa -- esperar
    CP $02
    JP Z,DETENER_SONIDO              ; "terminado" (comando $FF de canal A)
    LD A,(BYTE_SALIDA_ALTAVOZ)
    EX AF,AF'
    LD BC,$0000                     ; PERIODO_TONO_CANAL_A: operando automodificable
                                    ; ($E23E-E23F) -- CORREGIDO sesion 55 (ver abajo):
                                    ; CANAL_A_NOTA escribe aqui mismo con
                                    ; "LD ($E23E),DE" el periodo real leido de
                                    ; TABLA_TONOS_CANAL_A. Verificado por simulacion:
                                    ; periodo $00FB -> ~277 Hz (Do#4), periodo $013C
                                    ; -> ~209 Hz (Sol#3), coincide con la escala
                                    ; cromatica de la tabla. CORRIGE la hipotesis
                                    ; inicial de esta sesion (que daba este operando
                                    ; por fijo a 0, sin usar la tabla de tonos).
    LD HL,TONO_LOOP_INTERNO
    LD ($E277),HL
    LD D,B
    LD E,C
    DEC DE
    LD ($E25C),BC                   ; guarda el periodo real como valor de recarga
                                    ; de BC (operando automodificable del "LD BC,$0000"
                                    ; de mas abajo, dentro de TONO_LOOP_INTERNO)
TONO_PATRON_BASE:                   ; 8 bytes automodificables, ver CANAL_A_CMD_FB/FA
    LD ($E26E),DE                   ; guarda el semiperiodo como valor de recarga de
                                    ; DE (operando automodificable del "LD DE,$0000"
                                    ; de TONO_LOOP_EXTERNO)
    SRL D
    RR E                             ; fin de la region automodificable (8 bytes)
TONO_LOOP_INTERNO:                  ; BC cuenta el periodo completo; al llegar a 0
                                    ; conmuta el altavoz y SE RECARGA con el periodo
                                    ; real (no con 0 -- ver nota de automodificacion
                                    ; arriba), repitiendo indefinidamente.
    DEC BC
    LD A,B
    OR C
    JP NZ,TONO_LOOP_EXTERNO
    LD BC,$0000                     ; operando automodificable ($E25C-E25D), recarga = periodo real
    EX AF,AF'
    XOR $F8
    OUT ($FE),A                      ; toggle del altavoz
    EX AF,AF'
    JP TONO_LOOP_EXTERNO
TONO_LOOP_EXTERNO:                  ; DE hace lo mismo con el semiperiodo -- dos
                                    ; contadores independientes conmutando el MISMO
                                    ; bit de salida a tasas relacionadas (periodo y
                                    ; periodo/2), en vez de un solo cuadrado puro.
    DEC DE
    LD A,D
    OR E
    JP NZ,TONO_LOOP_INTERNO
    LD DE,$0000                     ; operando automodificable ($E26E-E26F), recarga = semiperiodo
    EX AF,AF'
    XOR $F8
    OUT ($FE),A
    EX AF,AF'
    JP TONO_LOOP_INTERNO
DETENER_SONIDO:
    DI
    LD HL,(ISR_VECTOR_GUARDADO)
    LD ($6061),HL                    ; restaura el vector IM2 original del juego
    RET
COPIAR_PATRON_TONO:                  ; sobrescribe los 8 bytes de TONO_PATRON_BASE
    LD DE,TONO_PATRON_BASE
    LD BC,$0008
    LDIR
    RET
PATRON_TONO_1:                       ; variante: SRL D/RR E primero, luego guarda en $E26E
    DB $CB,$3A,$CB,$1B,$ED,$53,$6E,$E2
PATRON_TONO_2:                       ; variante: identica al patron base (restaura el orden original)
    DB $ED,$53,$6E,$E2,$CB,$3A,$CB,$1B
TABLA_PERCUSION:                     ; $E29A, 8 punteros -- solo 4 rutinas reales, cada una x2
    DW PERCUSION_1,PERCUSION_2,PERCUSION_3,PERCUSION_4
    DW PERCUSION_1,PERCUSION_2,PERCUSION_3,PERCUSION_4
FLAG_ESTADO_SONIDO:
    DB $00                            ; $E2AA -- 0=silencio, 1=sonando, 2=terminado
ISR_VECTOR_GUARDADO:
    DW $0000                          ; $E2AB-E2AC -- vector IM2 original, guardado/restaurado
BYTE_SALIDA_ALTAVOZ:
    DB $00                            ; $E2AD -- nivel de salida actual del altavoz/borde
TABLA_DURACIONES:
    DB 5,11,17,23                     ; $E2AE-E2B1 -- duracion en frames, indexada por bits6-7 de la nota
SP_GUARDADO_TEMP:
    DW $0000                          ; $E2B2-E2B3 -- SP salvado durante el intercambio a pila privada
PILA_CANAL_A:
    DW PILA_CANAL_A_MEM               ; $E2B4-E2B5 -- puntero de pila privada de canal A
PILA_CANAL_B:
    DW PILA_CANAL_B_MEM               ; $E2B6-E2B7 -- puntero de pila privada de canal B
TABLA_TONOS_CANAL_A:                  ; $E2B8, 64 palabras (128 bytes) -- periodos de tono,
                                       ; escala cromatica descendente (razon ~1.06 entre
                                       ; entradas consecutivas, ver FINDINGS.md sesion 55).
                                       ; Solo 41 entradas en uso real; el resto (indices
                                       ; 41-63) queda a 0 sin usar.
    DW 633,597,564,532,502,474,447,422,399,376,355,335,316,299,282,266
    DW 251,237,224,211,199,188,178,168,158,149,141,133,126,118,112,106
    DW 100,94,89,84,79,75,70,67,63,0,0,0,0,0,0,0
    DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB $00,$00,$00,$00                ; relleno antes de las pilas privadas
PILA_CANAL_A_MEM:                     ; $E33C, 50 bytes -- espacio de pila real de canal A
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    DB $00,$00
PILA_CANAL_B_MEM:                     ; $E36E, 18 bytes -- espacio de pila real de canal B
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    DB $00,$00
; $E380 -- fin del motor de sonido. $E380-$E3D7 (88 B) RESUELTO en
; sesion 56: GUION_DEMO_NIVEL5, el cuarto guion de TABLA_PERFILES_DEMO
; (ver cabecera de INICIAR_DEMO/$DBE0 mas arriba) -- confirma que
; TABLA_PERFILES_DEMO no vive toda en $DBE0-$DD17, este ultimo guion
; se coloco aparte. CERRADO sesion 56: el resto de este tramo
; ($E3D8-$EFB5) tambien quedo identificado por completo -- ver los 3
; bloques siguientes (2 guiones de demo mas, el bitmap del marco
; decorativo, y relleno a cero). Sin equivalente MSX.
GUION_DEMO_NIVEL5:          ; $E380, nivel 5 -- TABLA_PERFILES_DEMO entrada 3 (sesion 56)
    INCBIN "data/sound/demo/07_guion_demo_nivel5_e380.bin"
; $E3D8-$E3F1 (26 bytes): sesion 56 -- misma cadena de razonamiento
; que confirmo GUION_DEMO_NIVEL5 justo arriba: la extraccion de ESE
; guion (88 bytes, $E380-$E3D7) termina en un par (umbral,direccion)
; $01,$00,$FF,$FF -- un terminador limpio y genuino, no un corte
; arbitrario -- así que estos 26 bytes que le siguen son una zona
; aparte. Decodifican, con el MISMO formato ya confirmado por el
; consumidor real de INICIAR_DEMO (par umbral/direccion terminado en
; direccion=$FF), como 2 guiones cortos mas, ambos con su propio
; terminador limpio. PERO, igual que GUION_DEMO_SINREF_1-4: ningun
; indice de TABLA_PERFILES_DEMO apunta aqui (sus 4 entradas -- niveles
; 1/2/4/5 -- ya estan localizadas por completo), asi que NO hay
; ejecucion real confirmada que los lea -- candidato razonable
; (formato + terminador limpio coinciden con los guiones confirmados),
; no confirmado por un llamador real. Etiquetados igual que
; GUION_DEMO_SINREF_1-4 por coherencia.
GUION_DEMO_SINREF_5:          ; $E3D8, sin indice conocido en TABLA_PERFILES_DEMO
    INCBIN "data/sound/demo/08_guion_demo_extra_e3d8.bin"
GUION_DEMO_SINREF_6:          ; $E3DE, sin indice conocido en TABLA_PERFILES_DEMO
    INCBIN "data/sound/demo/09_guion_demo_extra_e3de.bin"
; $E3F2 -- RESUELTO POR COMPLETO sesion 56 (CORRIGE el hallazgo
; anterior de la misma sesion, "189 guiones de musica huerfanos" --
; ver cabecera de MARCO DECORATIVO junto a CARGAR_MARCO_DECORATIVO,
; $904A, para el analisis completo). Bitmap RLE-comprimido del marco
; decorativo, descomprimido a $4000 por CARGAR_MARCO_DECORATIVO.
BITMAP_MARCO_DECORATIVO:               ; $E3F2, 2992 bytes
    INCBIN data/img/marco_decorativo/bitmap_e3f2.bin
; $EFA2-$EFB5 (20 bytes): relleno a cero tras el bitmap del marco decorativo.
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    DB $00,$00,$00,$00
MOTOR_FIN:
