; ============================================================
;  SCREEN.scr (version de cinta, Topo Soft 1988) - ZX Spectrum 48K
;  Pantalla de carga -- 6912 bytes, cargada por LOADER.bin en $4000
;  (la direccion de pantalla estandar del Spectrum: $4000-$57FF
;  patron de pixeles + $5800-$5AFF atributos de color) -- ver
;  load_cas/loader_body.asm.
;
;  NO es codigo -- es un bitmap. Se probo pasarla por Z80Dasm.exe
;  igual que el resto (ver FISICO/SCREEN.scr.dasm.txt) solo para
;  comprobarlo: el resultado son paginas de NOP (byte $00, zonas en
;  negro de la imagen) seguidas de instrucciones sin ningun sentido
;  como flujo de programa -- confirma que es un bitmap sin
;  comprimir, no ejecutable. Se trata como recurso de datos (INCBIN),
;  igual que data/img/*.img en el proyecto hermano de MSX, en vez de
;  fingir un desensamblado que no significa nada.
;
;  Copia byte a byte identica del original en
;  data/img/pantalla_carga.img (verificado por construccion --
;  INCBIN no transforma nada).
;
;  NOTA de ruta: SjASMPlus resuelve INCLUDE/INCBIN relativos al
;  directorio de TRABAJO del proceso, no a la ubicacion de este
;  fichero -- por eso la ruta de abajo es relativa a src/ (el cwd
;  real usado por tools/build_all.py), no a load_cas/. Mismo
;  convenio que el proyecto hermano de MSX (ver su build_all.py).
;
; Ingeniería inversa, herramientas y documentación de este proyecto: Rafael Eduardo Martín Candial (raemca@hotmail.com)
; ============================================================

PANTALLA_CARGA:                    ; $4000
    INCBIN "data/img/pantalla_carga.img"
FIN_PANTALLA_CARGA:                ; $5AC0 -- 6912 bytes totales
