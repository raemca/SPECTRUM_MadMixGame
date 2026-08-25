; ============================================================
;  Bloque de PORTADA/presentacion embebido en MAD-MIX.bas
;  (Topo Soft 1988) - ZX Spectrum 48K -- 4222 bytes.
;
;  MAD-MIX.bas (el primer programa del .tzx, 4317 bytes) NO es solo
;  BASIC: son 3 lineas de BASIC real (81 bytes, ver
;  load_cas/madmix_bas.bas) seguidas, EN EL MISMO BLOQUE de cinta
;  tipo "Program" (sin cabecera CODE aparte -- viaja dentro del
;  area de programa/variables), de: un stub de 14 bytes
;  (load_cas/portada_stub_body.asm, $5D1C) + ESTE fichero, los 4222
;  bytes que el stub copia con LDIR.
;
;  El stub corre en $5D1C (donde aterriza el BASIC) y hace
;  LD HL,$5D2A / LD DE,$EA60 / LD BC,4222 / LDIR / JP DIBUJAR_LOGO_TOPOSOFT
;  (= $EBD8) -- es decir, este bloque se ESCRIBE en la cinta/BASIC en
;  una direccion (`$5D2A`, justo detras del stub) pero esta pensado
;  para EJECUTARSE en OTRA bien distinta (`$EA60`): typico truco de
;  reubicacion (equivalente al PHASE/DEPHASE que usa
;  madmix_scr_body.asm en el proyecto hermano de MSX). Por eso este
;  fichero se desensamblo tomando como base $EA60 (su direccion
;  REAL de ejecucion), no $5D2A (su direccion de transito en el
;  BASIC) -- verificado: el JP del stub aterriza limpio en
;  DIBUJAR_LOGO_TOPOSOFT (un inicio de instruccion real, LD A,0) solo
;  con esta hipotesis. Ver load_cas/portada_stub_body.asm.
;
;  $EA60-$FADD cae DENTRO del rango de direcciones que mas tarde
;  ocupara CODE.bin ($6000-$EFB5) -- esta portada usa esa memoria
;  de forma TEMPORAL, antes de que LOADER.bin cargue el motor real
;  ahi encima (ver load_cas/loader_body.asm). Mismo patron
;  arquitectonico que madmix_scr_body.asm/madmix1_body.asm en MSX.
;
;  RECONSTRUCCION MECANICA DE PRIMERA PASADA (ver madmix_body.asm
;  para el detalle completo del metodo -- mismo dasm2asm.py).
;
;  VERIFICACION: recompilado con SjASMPlus (ORG $EA60, INCLUDE,
;  SAVEBIN) y comparado byte a byte contra los 4222 bytes de cola
;  de MAD-MIX.bas (extraidos aparte) -- 0 diferencias.
;
; Ingeniería inversa, herramientas y documentación de este proyecto: Rafael Eduardo Martín Candial (raemca@hotmail.com)
; ============================================================

; Generado mecanicamente a partir de Z80Dasm.exe + dasm2asm.py
; (traduccion literal, sin analisis semantico todavia -- ver FINDINGS.md)
;
; ATRIBUTO_INICIO_SOFT: constante (EQU, sin ocupar bytes), no direccion
; ejecutable. $59EF = celda de atributo de fila 15, columna 15
; ($5800 + 15*32 + 15) -- exactamente donde DIBUJAR_SOFT_ROTANDO dibuja
; "SOFT" (fila de pixel 120 = fila de atributo 15, columna fija 15).
; Usada literalmente 3 veces en este fichero (sesion 20: antes cada
; una repetia el mismo "$59EF" suelto) -- ANIMAR_PUNTO_LUZ_SOFT (punto
; de partida del punto de luz), el valor por defecto compilado del
; parametro \$EC50 dentro de RELLENAR_COLOR_TOPO, y DIBUJAR_LOGO_TOPOSOFT
; (que fija \$EC50 a este mismo valor antes de la primera llamada) --
; siempre la MISMA celda conceptual, de ahi la constante compartida.
ATRIBUTO_INICIO_SOFT EQU $59EF
PORTADA_PAYLOAD_INICIO:
; --- ANIMAR_PUNTO_LUZ_SOFT: analizada a mano (2026-08-09), confirmada
; por descripcion visual del usuario (ver FINDINGS.md, sesion 4 --
; "logo animado de Topo Soft" al arrancar). Anima con HALT/HALT
; (~40ms/paso) 8 columnas de atributos de color en 2 filas contiguas
; ($59EF-$59F6 y +$20 = fila siguiente, filas 15-16 de 24, columnas
; 15-22), alternando tinta roja brillante ($42) y blanca brillante
; ($47) sobre papel negro.
;
; MUY PROBABLE (sesion 10, comparando con el LOGOTOPO.CM de MSX, ya
; resuelto y confirmado visualmente por el usuario alli): es el
; equivalente Spectrum de ANIMAR_PUNTO_LUZ_SOFT -- "un punto de luz
; que recorre 'Soft' por su linea superior tras terminar de rotar,
; acabando junto a la estrella". Coincide en POSICION (fila de
; atributo 15, columna 15 = exactamente donde DIBUJAR_SOFT_ROTANDO dibuja
; "SOFT", fila de pixel 120 = fila de atributo 15) y en ORDEN dentro
; de la secuencia maestra (justo despues de las 3 llamadas a
; DIBUJAR_SOFT_ROTANDO, justo antes de DIBUJAR_ESTRELLA_ANIMADA -- identico en
; ambas versiones). Aqui se llama tambien como subrutina normal (ver
; "CALL ANIMAR_PUNTO_LUZ_SOFT" mas abajo en DIBUJAR_LOGO_TOPOSOFT)
; -- repite la MISMA animacion sobre las MISMAS 8 columnas (HL/DE/BC
; se recargan aqui siempre con los mismos valores fijos). RET solo
; cuando HL llega a DE (fin de las 8 columnas). ---
ANIMAR_PUNTO_LUZ_SOFT:
    LD HL,ATRIBUTO_INICIO_SOFT          ; primera celda de atributo (fila 15, col 15)
    LD DE,ATRIBUTO_INICIO_SOFT+8        ; celda de parada, 8 columnas mas alla (fila 15, col 23)
    LD BC,32                           ; una fila completa de atributos (stride)
    EI
.BUCLE_AVANZAR_PUNTO:
    HALT
    HALT                                ; ~40ms de pausa entre columnas (2 interrupciones)
    AND A
    SBC HL,DE                          ; compara HL con DE (fin de bucle)
    RET Z
    ADD HL,DE                          ; deshace la resta, restaura HL
    LD (HL),$42                        ; fila 15: tinta roja brillante / papel negro
    PUSH HL
    ADD HL,BC                          ; += 32 -> misma columna, fila 16
    LD (HL),$42                        ; fila 16: tinta roja brillante / papel negro
    POP HL
    INC HL                             ; siguiente columna
    PUSH HL
    LD (HL),$47                        ; fila 15: tinta blanca brillante / papel negro
    ADD HL,BC
    LD (HL),$47                        ; fila 16: tinta blanca brillante / papel negro
    POP HL
    JR .BUCLE_AVANZAR_PUNTO
; --- DIBUJAR_FORMA_ANIMADA: rutina de dibujo de bajo nivel de TODO el
; logo animado de Topo Soft (analizada sesiones 5-6-9-10, ver
; FINDINGS.md). Copia 27 filas x 3 bytes desde una de las 15 formas
; identificadas en LOGO_SOFT_1..LOGO_ESTRELLA_4 a la pantalla, segun
; 4 parametros autoemodificados:
;   - $EA8E (operando de "LD HL,14" mas abajo) -- indice*2 en
;     TABLA_PUNTEROS_FORMAS -> QUE forma se dibuja (0-14).
;   - $EA83 (operando de "LD HL,110" mas abajo) -- indice en
;     TABLA_FILAS_PANTALLA (fila de pantalla superior de las 27 que
;     se van a copiar) -> DONDE (fila) se dibuja.
;   - $EAB6 (operando de "LD HL,22" en el bucle de copia,
;     .BUCLE_SEGMENTO) -- desplazamiento de columna -> en que
;     columna se dibuja.
;   - $EAC0 (opcode de la instruccion justo tras "LD A,(DE)" en
;     .BUCLE_BYTE, normalmente NOP) -- COMO se combina cada byte:
;     copia directa (NOP, el caso normal) o mezcla con OR (HL) cuando
;     vale $B6 (solo lo activa DIBUJAR_O1_TOPO). RESUELTO sesion 18
;     comparando con MSX ($94F3 en logotopo_cm_body.asm, mismo
;     mecanismo exacto, mismo valor $B6, tambien solo para O1_TOPO).
; Los valores compilados por defecto (14, 110, 22) son exactamente
; la posicion fija de la ESTRELLA (DIBUJAR_ESTRELLA_ANIMADA) -- por eso
; coinciden con las dimensiones hardcodeadas de esta rutina (27
; filas x 3 bytes = exacto el tamano de LOGO_ESTRELLA_1..4): la
; estrella no se mueve, solo cicla de forma, asi que sus parametros
; son los "de fabrica" del codigo.
;
; Las dimensiones 27x3 estan HARDCODEADAS (literales "LD C,27"/"LD B,3"
; mas abajo, no se leen de la cabecera de la forma) y aplican SIEMPRE,
; para las 15 formas, no solo la estrella -- cada llamada dibuja
; realmente solo un fragmento de 81 bytes leidos linealmente desde el
; principio de cada forma. Investigado en sesion 19: la cabecera real
; de cada forma ($EABE/$EAB3) declara un ancho/alto de fila MAYOR para
; las otras 6 formas (SOFT=8x16, T=9x86, O1=5x46, P=6x73, O2=6x53
; bytes/filas), y renderizar esos bytes crudos con ese ancho "real"
; produce contornos limpios (una "O" reconocible, etc.), mientras que
; renderizarlos con la ventana fija de 3 bytes/fila que usa esta
; rutina los corta en diagonal -- SUGERIA un posible glitch visual.
; DESCARTADO por el usuario (sesion 19, testigo directo del juego
; original): T-O-P-O aparecen limpias, una a una, con movimiento, SIN
; parpadeo ni distorsion visible. Conclusion: la ventana fija de 27x3
; (24x27 pixeles, el tamano real de una letra gruesa de este logo) ES
; el tamano correcto y unico con el que se dibuja cada forma -- las
; cabeceras $EABE/$EAB3, pese a que su producto coincide con el
; tamano del fichero, NO describen el ancho real usado para dibujar
; (de hecho $EABE esta confirmado como codigo muerto, sesion 17, y
; $EAB3 solo alimenta el contador de filas de RESTAURAR_FRANJA_FONDO,
; no el dibujo). Los bytes de cada forma mas alla de los primeros 81
; nunca se leen para dibujar -- que sean coincidencia de tamano,
; metadata heredada de otra herramienta, o datos de otro proposito
; queda sin resolver, pero ya NO se sospecha de ningun problema visual.
; Ver FINDINGS.md sesion 19 para el detalle completo.
;
; Llamada, directa o via DIBUJAR_FORMA_TEMPORIZADA (helper trivial:
; EI/HALT/JP DIBUJAR_FORMA_ANIMADA -- "espera 1 frame y dibuja"), desde
; TODAS las secuencias de animacion del logo: DIBUJAR_SOFT_ROTANDO (7
; fotogramas rotando en su sitio), DIBUJAR_T_TOPO (se asienta en fila
; 50), DIBUJAR_P_TOPO_ANIMADA (desliza columna 26->10 en fila 62),
; DIBUJAR_O1_TOPO (cae filas 6->62), DIBUJAR_O2_TOPO_ANIMADA (rebota filas
; 62->22->62) y DIBUJAR_ESTRELLA_ANIMADA (cicla 4 fotogramas en su sitio) --
; todas invocadas en orden desde DIBUJAR_LOGO_TOPOSOFT ($EBD8, el
; punto de entrada real de toda la portada). Ver FINDINGS.md sesion
; 10 para el mapa completo de la secuencia maestra. ---
DIBUJAR_FORMA_ANIMADA:
    LD HL,110                          ; $EA83 -- fila inicial (autoemodificado;
                                        ; 110 es el valor compilado por defecto,
                                        ; se sobreescribe siempre antes de usarse)
    ADD HL,HL
    LD DE,TABLA_FILAS_PANTALLA         ; tabla de direcciones de fila de pantalla
    ADD HL,DE
    LD (VARIABLES_TRABAJO_FORMA+2),HL
    LD HL,14                           ; $EA8E -- indice de forma (autoemodificado;
                                        ; 14 = LOGO_ESTRELLA_4 en TABLA_PUNTEROS_FORMAS,
                                        ; valor compilado por defecto, se sobreescribe siempre)
    ADD HL,HL
    LD DE,TABLA_PUNTEROS_FORMAS ; tabla de punteros a forma
    ADD HL,DE
    LD E,(HL)
    INC HL
    LD D,(HL)
    LD HL,TABLA_FORMAS                  ; base de la zona de datos de forma (= $EF1C)
    ADD HL,DE
    LD A,(HL)
    LD ($EABE),A                       ; cabecera 1 (sesion 19: su producto con la
                                        ; cabecera 2 coincide con el tamano del
                                        ; fichero de cada forma, pero NO es el ancho
                                        ; usado para dibujar -- ver comentario en la
                                        ; cabecera de DIBUJAR_FORMA_ANIMADA). Su unico
                                        ; consumidor es el calculo MUERTO de
                                        ; RESTAURAR_FRANJA_FONDO (sesion 17).
    INC HL
    LD A,(HL)
    LD ($EAB3),A                       ; cabecera 2 -- TAMPOCO la usa esta rutina
                                        ; para dibujar (siempre 27 filas fijas, ver
                                        ; comentario en la cabecera de arriba) -- pero
                                        ; SI es una variable viva: RESTAURAR_FRANJA_FONDO
                                        ; la lee como contador real de filas a
                                        ; restaurar (solo se usa para O1/O2).
    INC HL
    LD (VARIABLES_TRABAJO_FORMA),HL                      ; resto = puntero a los 81 bytes de forma (fuente)
    DI
    LD (SP_GUARDADO_PORTADA),SP
    LD SP,(VARIABLES_TRABAJO_FORMA+2)                      ; SP = &tabla_filas[fila inicial] -- lectura rapida
    LD C,27                            ; filas
.BUCLE_SEGMENTO:
    POP DE                             ; DE = direccion real de esta fila de pantalla
    LD HL,22                           ; $EAB6 -- desplazamiento de columna (autoemodificado;
                                        ; 22 es el valor compilado por defecto)
    ADD HL,DE
    LD DE,(VARIABLES_TRABAJO_FORMA)
    LD B,3                             ; bytes por fila (24 pixeles)
.BUCLE_BYTE:
    LD A,(DE)
    NOP                                 ; $EAC0 -- opcode autoemodificado (RESUELTO
                                        ; sesion 18 comparando con MSX): normalmente
                                        ; NOP (copia directa via LD (HL),A mas abajo),
                                        ; pero DIBUJAR_O1_TOPO lo cambia a $B6 = OR (HL)
                                        ; -- combina el byte nuevo con lo que ya hay en
                                        ; pantalla en vez de sobreescribirlo. Sin etiqueta
                                        ; propia (igual que $EA83/$EA8E/$EAB6: es el
                                        ; operando/opcode de una instruccion, no una celda
                                        ; de datos independiente). Mismo mecanismo EXACTO
                                        ; que $94F3 en logotopo_cm_body.asm de MSX (alli
                                        ; tambien activado solo para O1_TOPO, con el mismo
                                        ; valor $B6 -- ver comentario alli).
    INC DE
    LD (HL),A
    INC HL
    DJNZ .BUCLE_BYTE
    LD (VARIABLES_TRABAJO_FORMA),DE
    DEC C
    JR NZ,.BUCLE_SEGMENTO
    LD SP,(SP_GUARDADO_PORTADA)
    EI
    RET
; RESTAURAR_FRANJA_FONDO: sus 2 primeras operaciones (guardar columna
; en $EB07, y calcular un puntero indexado por altura de forma dentro
; de LDI_EXTRA_HUERFANOS y guardarlo en $EB10) son CALCULOS MUERTOS --
; confirmado (sesion 17): ni $EB07 ni $EB10 se leen en NINGUN sitio de
; los 5 binarios reconstruidos, solo se escriben aqui. HIPOTESIS (no
; demostrada): en una version anterior de esta rutina, la franja de
; fondo a restaurar tenia ANCHURA VARIABLE segun la forma (columna de
; inicio en $EB07, numero de LDI a ejecutar segun una tabla indexada
; por la cabecera $EABE en $EB10) -- luego se simplifico a una franja
; de ANCHURA FIJA de 6 bytes (RESTAURAR_FRANJA_FILA) y estos calculos
; se quedaron sin borrar. Ver LDI_EXTRA_HUERFANOS mas abajo, que
; encaja con la misma hipotesis (bytes de LDI de mas, tambien
; huerfanos, justo antes de RESTAURAR_FRANJA_FILA).
RESTAURAR_FRANJA_FONDO:
    DI
    LD A,($EAB6)
    LD ($EB07),A                       ; MUERTO: nunca se lee $EB07
    LD A,($EABE)
    LD E,A
    LD D,0                              ; DE = cabecera 1 (ancho declarado, sin usar)
    LD HL,32                           ; 32 - cabecera -> indice dentro de
                                        ; LDI_EXTRA_HUERFANOS (calculo muerto,
                                        ; ver cabecera de esta rutina)
    AND A
    SBC HL,DE
    ADD HL,HL
    LD DE,LDI_EXTRA_HUERFANOS
    ADD HL,DE
    LD ($EB10),HL                      ; MUERTO: nunca se lee $EB10
    LD HL,($EA83)
    ADD HL,HL
    LD DE,TABLA_FILAS_PANTALLA
    ADD HL,DE
    LD (VARIABLES_TRABAJO_FORMA+2),HL
    LD A,($EAB3)
.BUCLE_RESTAURAR_FRANJA:
    LD HL,(VARIABLES_TRABAJO_FORMA+2)
    LD E,(HL)
    INC HL
    LD D,(HL)
    INC HL
    LD (VARIABLES_TRABAJO_FORMA+2),HL
    LD HL,15                           ; desplazamiento fijo de columna
                                        ; (bytes) dentro de la fila de pantalla
    ADD HL,DE
    EX DE,HL                            ; DE = direccion real de pantalla a restaurar
    LD HL,$8738                        ; traduccion pantalla->buffer guardado:
                                        ; DE(pantalla, $4000-$57FF) + $8738 =
                                        ; direccion en el buffer de GUARDAR_PANTALLA_LOGO
                                        ; ($C738-$4000 = $8738, ver esa rutina)
    ADD HL,DE
    CALL RESTAURAR_FRANJA_FILA
    DEC A
    JR NZ,.BUCLE_RESTAURAR_FRANJA
    EI
    RET
DIBUJAR_SOFT_ROTANDO:
    LD A,120                            ; fila 120 (fija -- fila de atributo 15)
    LD ($EA83),A
    LD A,15                             ; columna 15 (fija)
    LD ($EAB6),A
    XOR A
    LD ($EAC0),A        ; NOP (copia directa) -- ver DIBUJAR_FORMA_ANIMADA
    LD HL,TABLA_ANIMACION_SOFT
.BUCLE_FOTOGRAMA:
    LD A,(HL)
    CP $FF                              ; $FF = fin de TABLA_ANIMACION_SOFT
    RET Z
    LD ($EA8E),A
    PUSH HL
    CALL DIBUJAR_FORMA_TEMPORIZADA
    POP HL
    INC HL
    HALT
    JR .BUCLE_FOTOGRAMA
DIBUJAR_T_TOPO:
    LD A,7                              ; indice de forma 7 = LOGO_T
    LD ($EA8E),A
    LD A,50                             ; fila 50 (fija)
    LD ($EA83),A
    LD A,0                               ; columna inicial (bucle 0,1,2 -- se asienta)
.BUCLE_POSICION:
    CP 3                                 ; recorridas las 3 columnas -> fin
    RET Z
    LD ($EAB6),A
    PUSH AF
    HALT
    CALL DIBUJAR_FORMA_TEMPORIZADA
    POP AF
    INC A
    JR .BUCLE_POSICION
DIBUJAR_P_TOPO_ANIMADA:
    LD A,9                               ; indice de forma 9 = LOGO_P
    LD ($EA8E),A
    LD A,62                              ; fila 62 (fija)
    LD ($EA83),A
    LD A,26                              ; columna inicial (desliza 26 -> 10)
.BUCLE_POSICION:
    CP 10                                ; llegada a columna 10 -> fin
    RET Z
    LD ($EAB6),A
    PUSH AF
    CALL DIBUJAR_FORMA_TEMPORIZADA
    POP AF
    DEC A
    JR .BUCLE_POSICION
DIBUJAR_O1_TOPO:
    LD A,$B6                           ; opcode real de OR (HL) -- activa el
                                        ; combinado con lo que ya hay en pantalla,
                                        ; solo para O1 (igual que en MSX)
    LD ($EAC0),A
    LD A,8                               ; indice de forma 8 = LOGO_O1
    LD ($EA8E),A
    LD A,7                               ; columna 7 (fija durante toda la caida)
    LD ($EAB6),A
    LD A,6                               ; fila inicial (cae 6 -> 62, paso 8)
.BUCLE_SEGMENTO:
    CP 70                                ; 70 = una fila mas alla de la ultima (62):
                                        ; marca el final del bucle, ver mas abajo
    JR Z,.ULTIMO_SEGMENTO
    LD ($EA83),A
    PUSH AF
    CALL DIBUJAR_FORMA_ANIMADA
    HALT
    CALL RESTAURAR_FRANJA_FONDO
    POP AF
    ADD A,8                              ; siguiente fila (paso de 8)
    JR .BUCLE_SEGMENTO
.ULTIMO_SEGMENTO:
    JP DIBUJAR_FORMA_ANIMADA
DIBUJAR_O2_TOPO_ANIMADA:
    LD A,10                              ; indice de forma 10 = LOGO_O2
    LD ($EA8E),A
    LD HL,TABLA_TRAZO_O2_TOPO
.BUCLE_TRAZO:
    LD A,(HL)
    CP $FF                              ; $FF = fin de TABLA_TRAZO_O2_TOPO
    JR Z,.ULTIMO_TRAZO
    INC HL
    LD ($EAB6),A
    LD A,(HL)
    INC HL
    LD ($EA83),A
    PUSH HL
    CALL DIBUJAR_FORMA_ANIMADA
    HALT
    CALL RESTAURAR_FRANJA_FONDO
    POP HL
    JR .BUCLE_TRAZO
.ULTIMO_TRAZO:
    JP DIBUJAR_FORMA_ANIMADA
DIBUJAR_ESTRELLA_ANIMADA:
    LD HL,TABLA_ANIMACION_ESTRELLA
.BUCLE_FOTOGRAMA:
    LD A,(HL)
    CP $FF                              ; $FF = fin de TABLA_ANIMACION_ESTRELLA
    RET Z
    PUSH HL
    LD ($EA8E),A
    LD A,22                              ; columna 22 (fija -- coincide con el
                                        ; valor compilado por defecto de $EAB6
                                        ; en DIBUJAR_FORMA_ANIMADA)
    LD ($EAB6),A
    LD A,110                             ; fila 110 (fija -- coincide con el
                                        ; valor compilado por defecto de $EA83
                                        ; en DIBUJAR_FORMA_ANIMADA)
    LD ($EA83),A
    CALL DIBUJAR_FORMA_TEMPORIZADA
    HALT
    HALT
    HALT
    POP HL
    INC HL
    JR .BUCLE_FOTOGRAMA
; --- DIBUJAR_LOGO_TOPOSOFT: el punto de entrada REAL de toda la
; portada (destino del "JP $EBD8" del stub, ver load_cas/portada_stub_body.asm).
; Orquesta, en orden, toda la animacion del logo -- ver FINDINGS.md
; sesion 10 para el detalle completo de cada pieza. ---
DIBUJAR_LOGO_TOPOSOFT:
    LD A,0
    LD ($EAC0),A        ; NOP (copia directa) -- valor por defecto
                                        ; al arrancar toda la secuencia
    CALL LIMPIAR_TABLA_COLOR_VRAM
    CALL DIBUJAR_T_TOPO
    CALL PAUSA_ENTRE_LETRAS
    CALL DIBUJAR_P_TOPO_ANIMADA
    CALL PAUSA_ENTRE_LETRAS
    CALL GUARDAR_PANTALLA_LOGO
    CALL DIBUJAR_O1_TOPO
    CALL PAUSA_ENTRE_LETRAS
    CALL GUARDAR_PANTALLA_LOGO
    CALL DIBUJAR_O2_TOPO_ANIMADA
    CALL PAUSA_ENTRE_LETRAS
    CALL ANIMAR_COLOR_TOPO
    ; Parametriza y llama a RELLENAR_COLOR_TOPO (ver esa rutina): 2
    ; filas x 8 celdas (BC=7+1) de rojo brillante ($42), empezando en
    ; ATRIBUTO_INICIO_SOFT -- prepara el fondo de color justo donde
    ; DIBUJAR_SOFT_ROTANDO va a dibujar "SOFT" a continuacion.
    LD A,$42                            ; $EC5A: color = rojo brillante/papel negro
    LD ($EC5A),A
    LD A,2                               ; $EC4E: 2 filas
    LD ($EC4E),A
    LD A,7                               ; $EC57: ancho de franja - 1 (8 celdas)
    LD ($EC57),A
    LD HL,ATRIBUTO_INICIO_SOFT          ; $EC50: celda inicial (fila 15, col 15)
    LD ($EC50),HL
    CALL RELLENAR_COLOR_TOPO
    CALL DIBUJAR_SOFT_ROTANDO
    CALL DIBUJAR_SOFT_ROTANDO
    CALL DIBUJAR_SOFT_ROTANDO
    CALL ANIMAR_PUNTO_LUZ_SOFT
    CALL DIBUJAR_ESTRELLA_ANIMADA
    RET
; LIMPIAR_TABLA_COLOR_VRAM: borra la pantalla completa -- rellena las
; 768 celdas de atributos ($5800-$5AFF) con $47 (tinta blanca
; brillante/papel negro) y los 6144 bytes de bitmap ($4000-$57FF) con
; 0, con el truco de "1 escritura + LDIR" (escribe el primer byte a
; mano, luego LDIR copia ese mismo byte al resto del bloque). Tambien
; actualiza BORDCR ($5C48, variable de sistema de la ROM: color de
; borde x8 + atributos de la mitad inferior de pantalla) y pone el
; borde a negro con OUT ($FE),A. Primer paso de la secuencia maestra.
LIMPIAR_TABLA_COLOR_VRAM:
    LD A,$47                           ; tinta blanca brillante / papel negro
    LD ($5C48),A                       ; BORDCR (variable de sistema de la ROM)
    LD A,0                               ; borde negro
    OUT ($FE),A
    LD HL,$5800                        ; inicio de atributos
    LD DE,$5801
    LD BC,767                           ; 767+1 = 768 celdas (24 filas x 32 columnas)
    LD (HL),$47
    LDIR
    LD HL,$4000                        ; inicio de bitmap
    LD DE,$4001
    LD BC,6143                          ; 6143+1 = 6144 bytes (todo el bitmap)
    LD (HL),0
    LDIR
    RET
; RELLENAR_COLOR_TOPO: rellena N filas de atributos con un color,
; empezando en una celda dada -- rutina generica, TOTALMENTE
; autoemodificada (sesion 20: verificados los 4 operandos contra el
; listado compilado, direccion por direccion):
;   - $EC4E = operando de "LD A,2" (numero de filas a rellenar).
;   - $EC50 = operando de "LD HL,ATRIBUTO_INICIO_SOFT" (celda inicial).
;   - $EC57 = operando de "LD BC,7" (ancho de la franja MENOS 1: el
;     primer byte de cada fila se escribe con "LD (HL),$42" y despues
;     LDIR copia ese mismo byte BC veces mas -> BC+1 celdas por fila).
;   - $EC5A = operando de "LD (HL),$42" (color/atributo a usar).
; La usan DIBUJAR_LOGO_TOPOSOFT (antes de ANIMAR_PUNTO_LUZ_SOFT, franja
; de 2 filas x 8 celdas en ATRIBUTO_INICIO_SOFT) y ANIMAR_COLOR_TOPO
; (2 veces por vuelta, bloques cian/verde de 5/7 filas).
RELLENAR_COLOR_TOPO:
    LD A,2                              ; $EC4E -- filas (valor compilado
                                        ; por defecto, se sobreescribe siempre)
    LD HL,ATRIBUTO_INICIO_SOFT          ; $EC50 -- celda inicial (valor
                                        ; compilado por defecto, se
                                        ; sobreescribe siempre)
.BUCLE_FILA:
    PUSH HL
    PUSH HL
    POP DE
    INC DE
    LD BC,7                             ; $EC57 -- ancho de franja - 1
                                        ; (valor compilado por defecto,
                                        ; se sobreescribe siempre)
    LD (HL),$42                        ; $EC5A -- color (valor compilado
                                        ; por defecto: rojo brillante/papel
                                        ; negro, se sobreescribe siempre)
    LDIR                                ; copia el color a las BC celdas siguientes
    LD DE,32                           ; siguiente fila de atributos (32 celdas/fila)
    POP HL
    ADD HL,DE
    DEC A
    JR NZ,.BUCLE_FILA
    RET
; --- ANIMAR_COLOR_TOPO: renombrada (sesion 10) por su equivalente en
; el LOGOTOPO.CM de MSX (mismo nombre alli, ya resuelto y confirmado
; visualmente: "el color de TOPO expandiendose desde el centro hacia
; los lados, justo despues de dibujar las 4 letras"). Coincide en
; POSICION dentro de la secuencia maestra (justo despues de
; DIBUJAR_O2_TOPO_ANIMADA, antes de RELLENAR_COLOR_TOPO+ANIMAR_PUNTO_LUZ_SOFT
; -- identico en ambas versiones). El mecanismo Z80 es distinto (esta
; version original Spectrum: 2 bloques de atributos, cian de 5 filas y
; verde de 7, cada uno deslizandose 9 columnas hacia la izquierda; el
; port a MSX lo adapto a 2 "cajas" VRAM separandose desde un centro,
; el mecanismo nativo de su VDP), pero es el mismo efecto en el mismo
; punto de la secuencia. Semantica visual EXACTA todavia sin confirmar
; en esta version (pendiente de verlo en emulador). ---
ANIMAR_COLOR_TOPO:
    LD A,2                               ; $EC57 inicial: ancho de franja - 1 = 2
                                        ; (arranca en 3 celdas de ancho)
    LD ($EC57),A
    LD HL,$58CB                        ; celda inicial del bloque cian (ver
                                        ; VARIABLES_TRABAJO_COLOR_TOPO)
    LD (VARIABLES_TRABAJO_COLOR_TOPO),HL
    LD HL,$596B                        ; celda inicial del bloque verde
    LD (VARIABLES_TRABAJO_COLOR_TOPO+2),HL
    LD B,9                               ; 9 vueltas de expansion
.BUCLE_EXPANSION:
    PUSH BC
    LD HL,(VARIABLES_TRABAJO_COLOR_TOPO)
    LD ($EC50),HL                      ; $EC50: celda inicial (bloque cian)
    DEC HL                              ; desliza 1 celda a la izquierda cada vuelta
    LD (VARIABLES_TRABAJO_COLOR_TOPO),HL
    LD A,5                               ; $EC4E: 5 filas (bloque cian)
    LD ($EC4E),A
    LD A,$45                            ; $EC5A: cian brillante/papel negro
    LD ($EC5A),A
    CALL RELLENAR_COLOR_TOPO
    LD HL,(VARIABLES_TRABAJO_COLOR_TOPO+2)
    LD ($EC50),HL                      ; $EC50: celda inicial (bloque verde)
    DEC HL                              ; desliza 1 celda a la izquierda cada vuelta
    LD (VARIABLES_TRABAJO_COLOR_TOPO+2),HL
    LD A,7                               ; $EC4E: 7 filas (bloque verde)
    LD ($EC4E),A
    LD A,$44                            ; $EC5A: verde brillante/papel negro
    LD ($EC5A),A
    CALL RELLENAR_COLOR_TOPO
    LD A,($EC57)
    ADD A,2                              ; ensancha 2 celdas mas cada vuelta
    LD ($EC57),A
    POP BC
    HALT
    HALT
    HALT
    DJNZ .BUCLE_EXPANSION
    RET
; RUIDO_ALTAVOZ_HUERFANO: bytes reales del original (verificados byte
; a byte, 0 diferencias), pero SIN NINGUN CALL/JP que apunte aqui en
; los 5 binarios reconstruidos -- huerfano, igual en espiritu al
; bloque de datos DATOS_HUERFANOS_9EEA de TABLA_FORMAS en MSX (mismo
; termino del proyecto para "bytes reales confirmados sin referencia
; conocida"). El RET incondicional de arriba corta cualquier flujo
; normal hacia aqui, asi que solo se ejecutaria si algo (no localizado)
; hiciera CALL/JP directo a esta direccion -- probablemente una
; llamada retirada en el desarrollo original de 1988 sin borrar el
; codigo (habria desplazado todas las direcciones siguientes).
;
; Comportamiento SI se llamara (analizado, no observado en emulador):
; genera hasta 50 pulsos de sonido por el altavoz (bit 4 del puerto
; $FE, alternando ON/OFF), pero cada pulso usa el registro R (refresco
; de DRAM, que las interrupciones de 50Hz hacen impredecible en la
; practica) como contador Y como condicion de salida -- "RET M" puede
; devolver el control de golpe en CUALQUIER comprobacion si el bit 7
; de R esta a 1 (~50% de probabilidad cada vez), asi que en la
; practica el numero real de pulsos es aleatorio y casi siempre mucho
; menor que 50. Efecto sonoro tipo "chisporroteo/estatica" de
; duracion aleatoria. Cae (sin RET propio) directamente en
; PAUSA_ENTRE_LETRAS de aqui abajo -- si se llamara, terminaria
; saliendo por el RET de la rutina PAUSE de la ROM. HL se carga a 280
; y se incrementa una vez (INC HL) pero no se usa para nada mas --
; posible resto de una version anterior de la rutina. ---
RUIDO_ALTAVOZ_HUERFANO:
    LD E,50
    XOR A
    LD R,A
    LD HL,280
.BUCLE_PULSO_ON:
    LD A,R
    LD B,A
.BUCLE_ESPERA_ON:
    LD A,R
    RET M
    DJNZ .BUCLE_ESPERA_ON
    LD A,$10                            ; bit 4 del puerto ULA = altavoz ON
                                        ; (mascara de bits, no cantidad)
    OUT ($FE),A
    LD A,R
    LD B,A
    INC HL
.BUCLE_ESPERA_OFF:
    LD A,R
    RET M
    DJNZ .BUCLE_ESPERA_OFF
    XOR A                                ; altavoz OFF (y borde negro)
    OUT ($FE),A
    DEC E
    JR NZ,.BUCLE_PULSO_ON
; PAUSA_ENTRE_LETRAS: pausa breve entre el dibujo de cada letra de
; "TOPO" -- llamada 4 veces desde DIBUJAR_LOGO_TOPOSOFT, siempre justo
; despues de dibujar una letra (T, P, O1, O2). No usa el punto de
; entrada normal del comando BASIC "PAUSE n" de la ROM ($1F3A, que
; primero LEE el parametro con FIND-INT2), sino que salta DIRECTAMENTE
; 3 bytes mas adentro, a $1F3D (PAUSE-1, el bucle HALT/DEC BC), con
; BC ya cargado a mano -- se ahorra el parseo de un parametro BASIC
; que aqui no existe. Por eso la pausa tambien es interrumpible: la
; ROM comprueba el bit 5 de FLAGS ($5C3B) -- "tecla pulsada" -- en
; cada interrupcion y sale antes de agotar las 5 si el jugador pulsa
; algo, el clasico "pulsa una tecla para saltar la animacion" del
; Spectrum (CONFIRMADO via ROM, sesion 14). Sin equivalente directo en
; MSX: alli cada rutina de letra trae su propio bucle local inline
; (".BUCLE_ESPERA_N_FRAMES" con HALT/DJNZ) en vez de una rutina
; compartida -- se mantiene nombre propio en espanol.
PAUSA_ENTRE_LETRAS:
    LD BC,5                        ; 5 interrupciones (~0.1s a 50Hz)
    JP $1F3D                       ; PAUSE-1 (ROM 48K): HALT/DEC BC/tecla?
; DIBUJAR_FORMA_TEMPORIZADA: "espera 1 frame y dibuja la forma actual"
; -- EI/HALT/JP DIBUJAR_FORMA_ANIMADA. La usan DIBUJAR_SOFT_ROTANDO/T/P
; y DIBUJAR_ESTRELLA_ANIMADA (las secuencias de posicion fija o casi
; fija; O1/O2 llaman a DIBUJAR_FORMA_ANIMADA directamente en su lugar).
DIBUJAR_FORMA_TEMPORIZADA:
    EI
    HALT
    JP DIBUJAR_FORMA_ANIMADA
; GUARDAR_PANTALLA_LOGO: vuelca la pantalla completa ($4000-$57FF,
; 6912 bytes = bitmap + atributos) al buffer de $C738 -- lo lee luego
; RESTAURAR_FRANJA_FONDO (via el truco +$8738) para restaurar el fondo
; que una forma en movimiento tapa al dibujarse encima. Llamada 2
; veces desde DIBUJAR_LOGO_TOPOSOFT, antes de DIBUJAR_O1_TOPO y de
; DIBUJAR_O2_TOPO_ANIMADA (las 2 unicas formas que se restauran). Sin
; equivalente en MSX (alli se borra la tabla de patrones entre letra y
; letra en vez de guardar/restaurar fondo).
GUARDAR_PANTALLA_LOGO:
    LD HL,$4000                        ; origen: pantalla real
    LD DE,$C738                        ; destino: buffer de fondo guardado
    LD BC,6912                          ; pantalla completa (6144 bitmap + 768 atributos)
    LDIR
    RET
TABLA_PUNTEROS_FORMAS:                  ; $ECF1, 30 bytes = 15 punteros de 2 bytes,
                                        ; indexados por $EA8E*2 en DIBUJAR_FORMA_ANIMADA.
                                        ;
                                        ; Cada valor es un DESPLAZAMIENTO desde TABLA_FORMAS
                                        ; ($EF1C), NO la direccion absoluta de cada forma --
                                        ; asi es como lo usa DIBUJAR_FORMA_ANIMADA en tiempo real
                                        ; (mas arriba en este fichero):
                                        ;
                                        ;   LD E,(HL) / INC HL / LD D,(HL)  ; DE = valor de esta tabla
                                        ;   LD HL,TABLA_FORMAS               ; HL = base fija
                                        ;   ADD HL,DE                       ; HL = base + desplazamiento
                                        ;
                                        ; Por eso cada entrada de abajo tiene que ser
                                        ; "LOGO_X-TABLA_FORMAS" (el desplazamiento) y NO
                                        ; "LOGO_X" a secas (la direccion absoluta): si aqui
                                        ; pusieramos la direccion absoluta, el ADD HL,DE de
                                        ; arriba sumaria TABLA_FORMAS + LOGO_X y el resultado
                                        ; caeria muy fuera de la memoria del Spectrum -- no es
                                        ; una eleccion de estilo, es el mismo calculo que hace
                                        ; el binario original de 1988 (tabla de desplazamientos
                                        ; + base fija, sumados en tiempo real). Verificado:
                                        ; con esta forma, la reconstruccion recompila 0
                                        ; diferencias contra el .tzx original -- si la tabla
                                        ; guardara direcciones absolutas en vez de
                                        ; desplazamientos, los BYTES resultantes no
                                        ; coincidirian con los del original (confirma que la
                                        ; tabla real de 1988 tambien guardaba desplazamientos).
                                        ;
                                        ; (la unica entrada que SI usa la etiqueta directa, sin
                                        ; resta, es "LD HL,TABLA_FORMAS" de arriba -- ahi el
                                        ; codigo real necesita la direccion absoluta como base,
                                        ; no un desplazamiento).
    DW LOGO_SOFT_1-TABLA_FORMAS
    DW LOGO_SOFT_2-TABLA_FORMAS
    DW LOGO_SOFT_3-TABLA_FORMAS
    DW LOGO_SOFT_4-TABLA_FORMAS
    DW LOGO_SOFT_5-TABLA_FORMAS
    DW LOGO_SOFT_6-TABLA_FORMAS
    DW LOGO_SOFT_7-TABLA_FORMAS
    DW LOGO_T-TABLA_FORMAS
    DW LOGO_O1-TABLA_FORMAS
    DW LOGO_P-TABLA_FORMAS
    DW LOGO_O2-TABLA_FORMAS
    DW LOGO_ESTRELLA_1-TABLA_FORMAS
    DW LOGO_ESTRELLA_2-TABLA_FORMAS
    DW LOGO_ESTRELLA_3-TABLA_FORMAS
    DW LOGO_ESTRELLA_4-TABLA_FORMAS
TABLA_ANIMACION_SOFT:                      ; $ED0F, 26 bytes
    ; Secuencia 0..6..0 (cada valor escrito en $EA8E por .BUCLE_FOTOGRAMA)
    ; -- son los 7 fotogramas de "SOFT" (LOGO_SOFT_1..7) rotando ida y
    ; vuelta. Termina en $FF (fin de guion) + 1 byte extra $FF sin
    ; explicar (relleno/alineacion, ver FINDINGS.md sesion 7).
    DB 1,1,2,2,3,3,4,4,5,5,6,6,5
    DB 5,4,4,3,3,2,2,1,1,0,0,$FF,$FF

TABLA_TRAZO_O2_TOPO:               ; $ED29, 31 bytes
    ; 15 pares (columna,fila) + $FF. Consumido por DIBUJAR_O2_TOPO_ANIMADA: la fila
    ; baja de 62 a 22 y vuelve a subir a 62 mientras la columna sube
    ; despacio -- movimiento curvo/rebote de una de las formas.
    DB 7,62,7,54,7,46,8,42,8,38,9,30,10
    DB 26,11,22,12,26,13,30,14,38,14,42,15,46
    DB 15,54,15,62,$FF

TABLA_ANIMACION_ESTRELLA:                  ; $ED48, 9 bytes
    ; Indices 11,12,13,12,11,12,13,14 + $FF (fin de tabla). Consumido por
    ; DIBUJAR_ESTRELLA_ANIMADA escribiendo cada valor en $EA8E -- cicla los 4
    ; fotogramas de la estrella (LOGO_ESTRELLA_1..4) en el mismo sitio.
    DB 11,12,13,12,11,12,13,14,$FF

; LDI_EXTRA_HUERFANOS: 52 bytes = 26 LDI consecutivos, SIN RET propio
; -- caen (si se ejecutaran) directamente en RESTAURAR_FRANJA_FILA
; (6 LDI + RET mas abajo), sumando 32 LDI + RET en total desde aqui.
; RESUELTO (sesion 17, antes "PORTADA_RELLENO_ED51 -- sin identificar
; del todo", sesion 7): INALCANZABLE -- ningun CALL/JP en los 5
; binarios reconstruidos apunta a esta direccion (mismo caso que
; RUIDO_ALTAVOZ_HUERFANO, sesion 15). HIPOTESIS (no demostrada): son
; los 26 LDI "de mas" de una version ANTERIOR y mas ancha de
; RESTAURAR_FRANJA_FILA -- 32 LDI (una franja de 32 bytes = 256
; pixeles) reducida despues a solo 6 (una franja de 48 pixeles), sin
; borrar el resto. Encaja con que el puntero calculado en
; RESTAURAR_FRANJA_FONDO indexado por altura de forma ($EB10, ver
; comentario alli) apunta precisamente DENTRO de este bloque -- y con
; que $ED,$A0 es literalmente el opcode de LDI, no un patron de
; relleno tipico (NOP/$00 seria mas normal para simple alineacion).
LDI_EXTRA_HUERFANOS:
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
    LDI
    LDI
; RESTAURAR_FRANJA_FILA: CONFIRMADA como rutina real, no relleno
; (sesion 16), y renombrada (antes COPIAR_6_BYTES, un nombre puramente
; mecanico) segun su EFECTO EN PANTALLA, no su implementacion: es el
; worker de una sola fila dentro de RESTAURAR_FRANJA_FONDO (que hace
; lo mismo para las 6-11 filas de una franja completa, ver
; .BUCLE_RESTAURAR_FRANJA mas arriba). Visualmente, es lo que evita
; que la animacion del logo deje "restos" o manchas al moverse: cada
; vez que una forma avanza a una posicion nueva, esta rutina repinta
; ENCIMA de la posicion anterior con el fondo que habia debajo antes
; de dibujar (guardado por GUARDAR_PANTALLA_LOGO), fila a fila --
; el efecto neto para el jugador es una forma que se desliza limpia
; sobre fondo negro, sin arrastrar pixeles de fotogramas previos.
; Mecanismo: HL = direccion origen (el buffer de fondo guardado, via
; el truco +$8738) y DE = direccion destino (la pantalla real,
; $4000-$57FF) -- copia 6 bytes (48 pixeles) por llamada. 6 LDI
; desenrollados (BC no controla el bucle, solo decrementa como efecto
; lateral de cada LDI) + RET. Convertida de bytes en bruto a
; mnemonicos reales.
RESTAURAR_FRANJA_FILA:
    LDI
    LDI
    LDI
    LDI
    LDI
    LDI
    RET

; Los siguientes 10 bytes (hasta TABLA_FILAS_PANTALLA) NO son una
; tabla ni codigo: son 5 variables de trabajo de 16 bits, cada una
; escrita antes de leerse en cada ejecucion (scratch RAM reutilizando
; hueco de la zona de datos estatica -- mismo patron que
; VARIABLES_TRABAJO_FORMA en MSX). Sus valores COMPILADOS aqui no son
; cero ni cabecera de fabrica: son RESTOS de una ejecucion real
; capturada en el volcado de memoria con el que se genero el .tzx
; (CONFIRMADO por aritmetica, sesion 16):
;   - VARIABLES_TRABAJO_FORMA (primer puntero) = $FADE, exactamente 1
;     byte pasado el ULTIMO
;     byte de todo este payload ($FADD, el final de LOGO_ESTRELLA_4)
;     -- coincide con "justo termino de copiar la ultima forma" en
;     DIBUJAR_FORMA_ANIMADA.
;   - los 2 punteros de ANIMAR_COLOR_TOPO valen exactamente 9 menos
;     que sus valores iniciales ($58CB/$596B) -- coincide con "justo
;     termino el bucle de 9 vueltas" (LD B,9) de esa rutina.
; Es decir: el .tzx original se genero volcando la RAM DESPUES de
; ejecutar (al menos) la portada una vez, no desde un binario recien
; ensamblado en limpio.
SP_GUARDADO_PORTADA:            ; $ED92, 2 bytes -- guarda/restaura el
                                ; SP real en DIBUJAR_FORMA_ANIMADA
                                ; (truco POP para leer TABLA_FILAS_PANTALLA
                                ; rapido). Sin equivalente en MSX (esta
                                ; optimizacion es propia del Z80/Spectrum).
    DW $FF3A                            ; resto de ejecucion real (SP valido
                                        ; cerca del tope de la RAM), ver arriba
VARIABLES_TRABAJO_FORMA:        ; $ED94, 4 bytes = 2 punteros. MISMO
                                ; NOMBRE que en MSX (logotopo_cm_body.asm)
                                ; -- agrupa los mismos 2 punteros de
                                ; trabajo de DIBUJAR_FORMA_ANIMADA (alli
                                ; a 0 en reposo, ROM limpia; aqui con
                                ; el resto de ejecucion real, ver arriba).
    DW $FADE                    ; puntero a datos de forma (= $96F4 en MSX)
    DW $EE78                    ; puntero a fila de pantalla (= $96F6 en MSX,
                                ; compartido con RESTAURAR_FRANJA_FONDO)
VARIABLES_TRABAJO_COLOR_TOPO:   ; $ED98, 4 bytes = 2 punteros que
                                ; ANIMAR_COLOR_TOPO desliza cada vuelta
                                ; (bloque cian y bloque verde). Sin
                                ; equivalente en MSX (alli usa 2 "cajas"
                                ; VRAM en vez de punteros RAM propios).
    DW $58C2                    ; puntero bloque cian
    DW $5962                    ; puntero bloque verde

TABLA_FILAS_PANTALLA:                  ; $ED9C, 384 bytes = 192 punteros
    ; de 2 bytes, uno por cada fila de pixel de la pantalla del Spectrum
    ; (0-191) -- CONFIRMADA byte a byte (sesion 7): entrada 0 = $4000,
    ; entrada 64 = $4800 (inicio exacto del tercio central), entrada 191
    ; = $56E0 (verificado con la formula real de direccion de pantalla).
    ; Usada por DIBUJAR_FORMA_ANIMADA (indexada por $EA83) para convertir
    ; "fila de pixel" en direccion real de pantalla sin calcularla cada
    ; vez. Termina justo en el byte anterior a TABLA_FORMAS, sin hueco.
    ;
    ; NO se renombro a TABLA_DELTA_POSICION (el nombre MSX del mismo
    ; ROL -- indexada por el mismo parametro, $94B2 alli/$EA83 aqui,
    ; desde DIBUJAR_FORMA_ANIMADA) a proposito: son estructuralmente
    ; distintas, no solo con nombre distinto. MSX guarda 24 SALTOS
    ; relativos (con los bits altos enmascarados antes de usarse,
    ; sin contenido de direccion real) que se SUMAN a una base; esta
    ; tabla guarda 192 DIRECCIONES DE PANTALLA REALES Y COMPLETAS,
    ; una por cada fila posible (no solo 24), sin necesitar ninguna
    ; suma posterior. Incluso siendo el mismo papel en el algoritmo,
    ; forzar el nombre igual habria sido enganoso -- ver
    ; src/README.md, seccion Convenciones.
    INCBIN "data/img/logo/tabla_filas_pantalla.img"

; ============================================================
; Formas del logo animado de Topo Soft -- IDENTIFICADAS (ver
; FINDINGS.md, sesion 6): 7 fotogramas de "SOFT" + las 4 letras
; T-O-P-O + 4 fotogramas de una estrella. Un fichero por forma en
; data/img/logo/, en el mismo orden que la tabla de punteros
; $ECF1 (indexada por $EA8E en DIBUJAR_FORMA_ANIMADA -- ver mas
; arriba). Cada fichero conserva byte a byte el bloque original
; completo, incluida su cabecera de 2 bytes (ancho/alto declarados --
; ver $EABE/$EAB3 en DIBUJAR_FORMA_ANIMADA, y la sesion 19 sobre por
; que NO son el ancho realmente usado para dibujar) -- NO son solo
; los pixeles.
;
; TABLA_FORMAS (alias de LOGO_SOFT_1, misma direccion): nombre igual
; al de logotopo_cm_body.asm de MSX, donde TABLA_PUNTEROS_FORMAS
; guarda desplazamientos relativos a esta misma base (alli tambien
; coincide con el inicio de su primera forma, FORMA_SOFT_1).
; ============================================================
TABLA_FORMAS:
LOGO_SOFT_1:
    ; SOFT, fotograma 1/7 -- 8 bytes/fila, cabecera 2 bytes, 128 de dibujo (16 filas), 130 total (0 muertos)
    INCBIN "data/img/logo/logo_soft_1.img"
LOGO_SOFT_2:
    ; SOFT, fotograma 2/7 -- igual formato que LOGO_SOFT_1
    INCBIN "data/img/logo/logo_soft_2.img"
LOGO_SOFT_3:
    ; SOFT, fotograma 3/7 -- igual formato que LOGO_SOFT_1
    INCBIN "data/img/logo/logo_soft_3.img"
LOGO_SOFT_4:
    ; SOFT, fotograma 4/7 -- igual formato que LOGO_SOFT_1
    INCBIN "data/img/logo/logo_soft_4.img"
LOGO_SOFT_5:
    ; SOFT, fotograma 5/7 -- igual formato que LOGO_SOFT_1
    INCBIN "data/img/logo/logo_soft_5.img"
LOGO_SOFT_6:
    ; SOFT, fotograma 6/7 -- igual formato que LOGO_SOFT_1
    INCBIN "data/img/logo/logo_soft_6.img"
LOGO_SOFT_7:
    ; SOFT, fotograma 7/7 -- igual formato que LOGO_SOFT_1
    INCBIN "data/img/logo/logo_soft_7.img"
LOGO_T:
    ; T de TOPO -- 9 bytes/fila, cabecera 2 bytes, 774 de dibujo (86 filas), 776 total (0 muertos) -- valores corregidos sesion 19-20 (cifras previas aproximadas del ajuste visual manual)
    INCBIN "data/img/logo/logo_t.img"
LOGO_O1:
    ; O (1a) de TOPO -- 5 bytes/fila, cabecera 2 bytes, 230 de dibujo (46 filas), 232 total (0 muertos)
    INCBIN "data/img/logo/logo_o1.img"
LOGO_P:
    ; P de TOPO -- 6 bytes/fila, cabecera 2 bytes, 438 de dibujo (73 filas), 440 total (0 muertos)
    INCBIN "data/img/logo/logo_p.img"
LOGO_O2:
    ; O (2a) de TOPO -- 6 bytes/fila, cabecera 2 bytes, 318 de dibujo (53 filas), 320 total (0 muertos)
    INCBIN "data/img/logo/logo_o2.img"
LOGO_ESTRELLA_1:
    ; estrella, fotograma 1/4 -- 3 bytes/fila, cabecera 2 bytes, 81 de dibujo (27 filas), 83 total (0 muertos) -- mismas dimensiones que DIBUJAR_FORMA_ANIMADA tiene hardcodeadas (C=27,B=3)
    INCBIN "data/img/logo/logo_estrella_1.img"
LOGO_ESTRELLA_2:
    ; estrella, fotograma 2/4 -- igual formato que LOGO_ESTRELLA_1
    INCBIN "data/img/logo/logo_estrella_2.img"
LOGO_ESTRELLA_3:
    ; estrella, fotograma 3/4 -- igual formato que LOGO_ESTRELLA_1
    INCBIN "data/img/logo/logo_estrella_3.img"
LOGO_ESTRELLA_4:
    ; estrella, fotograma 4/4 -- igual formato que LOGO_ESTRELLA_1
    INCBIN "data/img/logo/logo_estrella_4.img"
PORTADA_PAYLOAD_FIN:
