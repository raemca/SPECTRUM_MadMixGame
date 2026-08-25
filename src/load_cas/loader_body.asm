; ============================================================
;  LOADER.bin (version de cinta, Topo Soft 1988) - ZX Spectrum 48K
;  El cargador real del juego -- 196 bytes, extraido del bloque
;  "LOADER" del .tzx original (CODE, direccion de carga $EFB6=61366)
;  y desensamblado byte a byte con Z80Dasm.exe (disasm limpio de
;  principio a fin, sin ambiguedad de offset, ver
;  FISICO/LOADER.bin.dasm.txt).
;
;  Invocado desde BASIC: "RANDOMIZE USR 61366" tras
;  "LOAD ""LOADER"" CODE" (ver MAD-MIX_2.bas, el segundo programa
;  BASIC del .tzx: contiene literalmente el texto "LOADER" y el
;  numero "61366" entre sus bytes tokenizados).
;
;  Hace DOS lecturas de cinta seguidas y salta al codigo cargado:
;    1) $4000, 6912 bytes  -- exactamente el tamano de pantalla del
;       Spectrum (6144 de patron + 768 de atributos, $4000-$5AFF) --
;       coincide byte a byte con SCREEN.scr, extraido del bloque de
;       cinta inmediatamente siguiente.
;    2) $6000, 36790 bytes -- coincide byte a byte con CODE.bin, el
;       bloque grande de cinta que sigue a la pantalla.
;  Tras cargar ambos, JP $6000 -- ahi debe estar el punto de entrada
;  real del motor de juego (pendiente de identificar dentro de
;  CODE.bin, aun sin desensamblar).
;
;  La subrutina de lectura de cinta (LEER_BLOQUE_CINTA, $EFD3) es una
;  COPIA RELOCADA de LD-BYTES, la rutina de carga de la ROM de 48K
;  ($0556 en adelante) -- verificado diferenciandola instruccion a
;  instruccion contra 48.rom (ZEsarUX). Mismo algoritmo (deteccion de
;  flancos por el bit 5 del puerto $FE, tono piloto, 2 pulsos de
;  sincronismo, lectura de bits por byte con paridad acumulada) y
;  MISMAS constantes de temporizacion ($9C, $C6, $C9, $D4, $CB, $B0,
;  $B2, $16), solo con las direcciones de CALL/JR relocadas a
;  $EFB6+. Diferencias frente al original, ambas en el preambulo:
;    - ROM: LD A,$0F / OUT ($FE),A (borde blanco al empezar) +
;      LD HL,$053F / PUSH HL (dependencia del mecanismo de error de
;      la ROM, RST $08/ERROR-3). Aqui: XOR A / OUT ($FE),A (borde
;      negro) y SIN el PUSH HL -- el cargador propio no depende de
;      la pila de errores de la ROM ni de re-entrar por RST $08.
;    - ROM: ...AND $20 / OR $02 / LD C,A, y mas adelante, al pasar de
;      tono piloto a lectura de bits, XOR $03 antes de LD C,A. Aqui
;      NINGUNA de las dos: solo AND $20 / LD C,A al principio, y un
;      LD A,C / LD C,A (funcionalmente un NOP) en el punto
;      equivalente al XOR $03. Efecto neto exacto sobre el valor
;      inicial del flag de paridad NO verificado al 100% -- pendiente
;      de confirmar que un LOAD real desde este cargador acepta bien
;      el byte de flag $FF de cada bloque (los dos bloques de cinta
;      ya extraidos -- SCREEN.scr y CODE.bin -- solo se puede
;      confirmar del todo cargandolos de verdad en un emulador).
;
; Ingeniería inversa, herramientas y documentación de este proyecto: Rafael Eduardo Martín Candial (raemca@hotmail.com)
; ============================================================

PUNTO_ENTRADA_LOADER:                  ; $EFB6 -- destino de RANDOMIZE USR 61366
    LD IX, $4000                       ; pantalla del Spectrum (patron+atributos)
    LD DE, 6912                        ; = SCREEN.scr, tamano exacto de pantalla
    LD A, $FF                          ; flag de bloque de datos (convencion estandar)
    SCF                                ; carry=1 -> modo LOAD (no VERIFY)
    CALL LEER_BLOQUE_CINTA
    LD IX, $6000                       ; destino del bloque de codigo/datos principal
    LD DE, 36790                       ; = CODE.bin
    LD A, $FF
    SCF
    CALL LEER_BLOQUE_CINTA
    JP $6000                           ; entra al motor del juego (aun sin desensamblar)

; --- Copia relocada de LD-BYTES (ROM 48K, $0556), ver cabecera del
; fichero para el detalle de las diferencias frente al original.
; Recibe el flag esperado en A, el destino en IX y la longitud en DE;
; SCF antes de la llamada selecciona LOAD. Devuelve carry=1 en exito,
; carry=0 si aborta (timeout o paridad/flag no coincide). ---
LEER_BLOQUE_CINTA:                     ; $EFD3
    INC D                              ; truco de la ROM: no altera D (INC/DEC
    EX AF, AF'                         ; simetrico), solo sirve para colocar el
    DEC D                              ; EX AF,AF' de 1 byte en su sitio exacto
    DI
    XOR A                              ; borde negro (ROM original: $0F, blanco)
    OUT ($FE), A
    IN A, ($FE)
    RRA
    AND $20                            ; bit 5 del puerto $FE = entrada EAR (cinta)
    LD C, A                            ; C = flag de paridad, arranca en 0 o $20
    CP A                               ; siempre Z -- deja el RET NZ de abajo como
.PUNTO_REINTENTO:                      ; punto de aterrizaje compartido de reintento,
    RET NZ                             ; nunca dispara la primera vez (CP A es Z)
.REINTENTAR_TONO_PILOTO:
    CALL .DETECTAR_FLANCO              ; llamada DIRECTA (sin el wrapper de abajo)
    JR NC, .PUNTO_REINTENTO
    LD HL, $0040                       ; cuenta minima de flancos del tono piloto
.BUCLE_CONTAR_PILOTO:
    DJNZ .BUCLE_CONTAR_PILOTO
    DEC HL
    LD A, H
    OR L
    JR NZ, .BUCLE_CONTAR_PILOTO
    CALL .DETECTAR_FLANCO_SEGURO       ; aqui SI a traves del wrapper (ver abajo)
    JR NC, .PUNTO_REINTENTO
.PRIMER_SYNC:
    LD B, $9C                          ; primer pulso de sincronismo
    CALL .DETECTAR_FLANCO_SEGURO
    JR NC, .PUNTO_REINTENTO
    LD A, $C6
    CP B
    JR NC, .REINTENTAR_TONO_PILOTO     ; sync fuera de rango -> reintenta piloto
    INC H
    JR NZ, .PRIMER_SYNC
.SEGUNDO_SYNC:
    LD B, $C9                          ; segundo pulso de sincronismo
    CALL .DETECTAR_FLANCO              ; llamada directa otra vez
    JR NC, .PUNTO_REINTENTO
    LD A, B
    CP $D4
    JR NC, .SEGUNDO_SYNC
    CALL .DETECTAR_FLANCO              ; y otra vez directa
    RET NC                             ; fallo aqui = abandona (no reintenta piloto)
    LD A, C
    LD C, A                            ; NOP funcional (ROM: XOR $03 en su lugar,
                                        ; ver nota de cabecera sobre esta diferencia)
    LD H, $00                          ; H = acumulador de paridad del bloque
    LD B, $B0
    JR .BUCLE_LEER_BIT_ENTRADA
.BUCLE_LEER_BYTE:
    XOR A                              ; borde a negro entre bytes (parpadeo de
    OUT ($FE), A                       ; carga, igual que en LOAD.BIN de la MSX)
    EX AF, AF'
    JR NZ, .BIT_INTERMEDIO
    JR NC, .COMPROBAR_BYTE_FLAG
    LD (IX+0), L                       ; guarda el byte ya montado en L
    JR .AVANZA_BYTE
.BIT_INTERMEDIO:
    RL C
    XOR L
    RET NZ                             ; paridad no coincide a mitad de bloque -> aborta
    LD A, C
    RRA
    LD C, A
    INC DE
    JR .CONTINUA_BYTE
.COMPROBAR_BYTE_FLAG:                  ; comparacion especial del primer byte (el flag)
    LD A, (IX+0)
    XOR L
    RET NZ                             ; flag no coincide -> aborta
.AVANZA_BYTE:
    INC IX
.CONTINUA_BYTE:
    DEC DE
    EX AF, AF'
    LD B, $B2
.BUCLE_LEER_BIT_ENTRADA:
    LD L, $01                          ; L acumula los 8 bits del byte actual (marca "1")
.BUCLE_LEER_BIT:
    CALL .DETECTAR_FLANCO_SEGURO
    RET NC                             ; fin de datos / timeout -> sale
    LD A, $CB
    CP B
    RL L
    LD B, $B0
    JP NC, .BUCLE_LEER_BIT
    LD A, $01
    OUT ($FE), A                       ; borde a azul/rojo tras completar el byte
    LD A, H
    XOR L
    LD H, A                            ; acumula paridad total del bloque
    LD A, D
    OR E
    JR NZ, .BUCLE_LEER_BYTE            ; quedan bytes -> siguiente
    LD A, H
    CP $01                             ; paridad final debe dar 1 (bloque correcto)
    RET

; --- Wrapper: llama a .DETECTAR_FLANCO y devuelve directamente si no
; hay carry. Usado en el tramo de piloto/sync "seguro" y en el bucle
; de bits; los otros puntos de sync/piloto llaman a .DETECTAR_FLANCO
; DIRECTAMENTE (ver arriba) -- la diferencia entre pasar o no por
; este wrapper es de temporizacion (un CALL+RET de mas), no de
; comportamiento logico distinto; el porque de mezclar ambas formas
; en el mismo original no esta confirmado. ---
.DETECTAR_FLANCO_SEGURO:               ; $EFB6+... ($F05E en la copia original
    CALL .DETECTAR_FLANCO
    RET NC

; --- Deteccion de UN flanco en el puerto $FE (bit 5, entrada EAR),
; con espera/timeout de duracion fija. Si detecta el flanco a tiempo,
; invierte el flag de paridad esperado en C y devuelve carry=1. ---
.DETECTAR_FLANCO:
    LD A, $16                          ; cuenta fija de retardo entre muestras
.BUCLE_RETARDO:
    DEC A
    JR NZ, .BUCLE_RETARDO
    AND A
.REINTENTO_MUESTRA:
    INC B
    RET Z                              ; B desbordo a 0 -> timeout, sale sin carry
    LD A, $7F                          ; lee EAR (+ fila de teclado, sin uso aqui)
    IN A, ($FE)
    RRA
    RET NC                             ; nunca ocurre con esta mascara (ver ROM)
    XOR C
    AND $20
    JR Z, .REINTENTO_MUESTRA           ; aun no ha cambiado de estado -> reintenta
    LD A, C
    CPL
    LD C, A                            ; invierte el flag de paridad esperado
    SCF
    RET

FIN_LOADER_BIN:                        ; $F07A -- 196 bytes totales ($EFB6-$F079)
