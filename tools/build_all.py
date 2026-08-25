#!/usr/bin/env python3
"""
build_all.py -- compila los 5 fragmentos reconstruidos (pantalla,
stub+payload de portada, motor y loader) desde el codigo fuente
(src/main.asm), en una sola invocacion de SjASMPlus.

Requiere SjASMPlus en el PATH (ver README.md, seccion "Requisitos").

Genera (todo dentro de src/build/):
  SCREEN.bin           -- pantalla de carga, $4000, 6912 bytes
  PORTADA_STUB.bin      -- stub de reubicacion, $5D1C, 14 bytes
  PORTADA_PAYLOAD.bin   -- codigo de portada, $EA60, 4222 bytes
  CODE.bin              -- motor del juego, $6000, 36790 bytes
  LOADER.bin            -- cargador de cinta, $EFB6, 196 bytes
  main.lst              -- listado completo

Este script NO genera el .tzx final -- eso lo hace
tools/gen_tzx_file.py, un paso aparte (tokeniza los 2 BASIC y empaqueta
todo en el .tzx reconstruido).

Uso: py tools/build_all.py

Autor de esta herramienta: Rafael Eduardo Martín Candial (raemca@hotmail.com)
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
SRC = os.path.join(ROOT, "src")


def main():
    # SjASMPlus no crea subcarpetas por si solo -- SAVEBIN falla con
    # "opening file for write" si build/ no existe.
    os.makedirs(os.path.join(SRC, "build"), exist_ok=True)

    # SjASMPlus resuelve las rutas de SAVEBIN/INCBIN relativas al
    # directorio de trabajo, no a la ubicacion de main.asm -- por eso
    # se invoca con cwd=src/ (main.asm usa rutas como "build/...").
    try:
        result = subprocess.run(["sjasmplus", "main.asm", "--lst=build/main.lst"], cwd=SRC)
    except FileNotFoundError:
        print("ERROR: no se encuentra 'sjasmplus' en el PATH (ver README.md, seccion Requisitos)")
        sys.exit(1)

    if result.returncode != 0:
        print("ERROR: sjasmplus devolvio codigo {}".format(result.returncode))
        sys.exit(result.returncode)

    print("Compilacion completa -- ver src/build/ (SCREEN.bin, PORTADA_STUB.bin, PORTADA_PAYLOAD.bin, CODE.bin, LOADER.bin)")
    print("Siguiente paso: py tools/gen_tzx_file.py")


if __name__ == "__main__":
    main()
