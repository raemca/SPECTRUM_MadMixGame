; ============================================================
;  main.asm -- punto de entrada UNICO de compilacion del proyecto
;  Spectrum. Une, en una sola pasada de SjASMPlus (un solo espacio de
;  simbolos), los 5 fragmentos ya reconstruidos y verificados, cada
;  uno en su direccion real, y vuelca cada uno a su propio binario en
;  build/ (para luego empaquetarlos en el .tzx reconstruido con
;  tools/gen_tzx_file.py).
;
;  Invocar SIEMPRE con el directorio de trabajo en src/ (lo hace
;  tools/build_all.py) -- SjASMPlus resuelve INCLUDE/INCBIN/SAVEBIN
;  relativos al cwd del proceso, no a la ubicacion de cada fichero
;  (por eso las rutas de abajo, y el INCBIN dentro de
;  load_cas/screen_body.asm, estan escritas relativas a src/).
;
;  Ver FINDINGS.md para el detalle de cada fragmento; src/README.md
;  para el estado de cada uno (analisis semantico completo vs.
;  reconstruccion mecanica de primera pasada).
;
; Ingeniería inversa, herramientas y documentación de este proyecto: Rafael Eduardo Martín Candial (raemca@hotmail.com)
; ============================================================

    DEVICE ZXSPECTRUM48

; --- Pantalla de carga: dato, no codigo (ver load_cas/screen_body.asm) ---
    ORG $4000
    INCLUDE "load_cas/screen_body.asm"
    SAVEBIN "build/SCREEN.bin", PANTALLA_CARGA, FIN_PANTALLA_CARGA - PANTALLA_CARGA

; --- Stub de reubicacion de la portada (14 bytes, destino de
; RANDOMIZE USR 23836 en madmix_bas.bas) ---
    ORG $5D1C
    INCLUDE "load_cas/portada_stub_body.asm"
    SAVEBIN "build/PORTADA_STUB.bin", PORTADA_STUB_INICIO, PORTADA_STUB_FIN - PORTADA_STUB_INICIO

; --- Payload de portada: viaja en la cinta pegado al stub (direccion
; de transito $5D2A), pero esta escrito para ejecutarse en $EA60 (ver
; portada_body.asm) -- se ensambla aqui en su direccion REAL. ---
    ORG $EA60
    INCLUDE "portada_body.asm"
    SAVEBIN "build/PORTADA_PAYLOAD.bin", PORTADA_PAYLOAD_INICIO, PORTADA_PAYLOAD_FIN - PORTADA_PAYLOAD_INICIO

; --- Motor completo del juego (CODE.bin), $6000-$EFB5 ---
    ORG $6000
    INCLUDE "madmix_body.asm"
    SAVEBIN "build/CODE.bin", MOTOR_INICIO, MOTOR_FIN - MOTOR_INICIO

; --- Cargador de cinta (LOADER.bin), $EFB6-$F079 -- contiguo justo
; detras del motor, sin hueco. ---
    ORG $EFB6
    INCLUDE "load_cas/loader_body.asm"
    SAVEBIN "build/LOADER.bin", PUNTO_ENTRADA_LOADER, FIN_LOADER_BIN - PUNTO_ENTRADA_LOADER
