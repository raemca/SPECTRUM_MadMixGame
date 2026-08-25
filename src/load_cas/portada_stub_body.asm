; ============================================================
;  Stub de reubicacion de la portada (Topo Soft 1988) - ZX Spectrum
;  48K -- 14 bytes, $5D1C. Parte de MAD-MIX.bas (el primer programa
;  del .tzx): tras las 3 lineas de BASIC real (ver madmix_bas.bas),
;  el MISMO bloque de cinta "Program" trae pegados, sin cabecera
;  propia, este stub + 4222 bytes de payload (ver ../portada_body.asm)
;  -- toda la cola aterriza junta en memoria en una sola carga.
;
;  La linea 20 de madmix_bas.bas hace "RANDOMIZE USR 23836"
;  (23836 = $5D1C decimal) -- salta aqui DIRECTAMENTE. Este stub
;  copia con LDIR los 4222 bytes que le siguen en memoria ($5D2A,
;  donde aterrizaron pegados a este stub) hasta su direccion REAL
;  de ejecucion ($EA60, dentro del rango de memoria que mas tarde
;  ocupara el motor de CODE.bin) y salta ahi con JP $EBD8 (un punto
;  408 bytes dentro del bloque reubicado, no su primer byte --
;  verificado: cae exacto en un inicio de instruccion real,
;  LD A,$00, solo con esta hipotesis de direccion de destino).
;
;  VERIFICACION: recompilado con SjASMPlus (ORG $5D1C) y comparado
;  byte a byte contra los 14 bytes reales -- 0 diferencias.
;
; Ingeniería inversa, herramientas y documentación de este proyecto: Rafael Eduardo Martín Candial (raemca@hotmail.com)
; ============================================================

PORTADA_STUB_INICIO:               ; $5D1C -- destino de RANDOMIZE USR 23836
    LD HL, $5D2A                   ; origen: justo detras de este stub
    LD DE, $EA60                   ; destino real de ejecucion (dentro
                                    ; del rango de memoria de CODE.bin)
    LD BC, 4222                    ; bytes a copiar
    LDIR
    JP DIBUJAR_LOGO_TOPOSOFT    ; entra 408 bytes dentro del bloque
                                    ; reubicado (= $EBD8, ver portada_body.asm)
PORTADA_STUB_FIN:                  ; $5D2A -- 14 bytes totales
