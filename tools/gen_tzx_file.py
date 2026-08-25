#!/usr/bin/env python3
"""
gen_tzx_file.py -- empaqueta los 5 binarios ya compilados en
src/build/ (ver tools/build_all.py) mas los 2 listados BASIC
editables (src/load_cas/*.bas) en un .tzx REAL, byte a byte
equivalente al original de 1988 (mismos bloques, mismas pausas,
mismo bloque de informacion de archivo -- ver FINDINGS.md sesion 1
para de donde salen esos valores).

Uso: py tools/gen_tzx_file.py

Genera: build/madmix_reconstruido.tzx (en la RAIZ del repo)

Y verifica automaticamente el resultado byte a byte contra
FISICO/Mad Mix Game.tzx, reportando cualquier diferencia.

Autor de esta herramienta: Rafael Eduardo Martín Candial (raemca@hotmail.com)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
SRC = os.path.join(ROOT, "src")
BUILD = os.path.join(SRC, "build")
LOAD_CAS = os.path.join(SRC, "load_cas")
OUT_DIR = os.path.join(ROOT, "build")
OUT_PATH = os.path.join(OUT_DIR, "madmix_reconstruido.tzx")
ORIGINAL = os.path.join(ROOT, "FISICO", "Mad Mix Game.tzx")

sys.path.insert(0, HERE)
import zxbasic_tool  # noqa: E402


def read(path):
    with open(path, "rb") as f:
        return f.read()


def standard_block(flag, payload, pause):
    data = bytes([flag]) + payload
    checksum = 0
    for b in data:
        checksum ^= b
    data = data + bytes([checksum])
    out = bytearray()
    out.append(0x10)
    out.append(pause & 0xFF)
    out.append((pause >> 8) & 0xFF)
    length = len(data)
    out.append(length & 0xFF)
    out.append((length >> 8) & 0xFF)
    out.extend(data)
    return bytes(out)


def header_block(prog_type, name, length, param1, param2, pause):
    name10 = name.encode("ascii")
    if len(name10) > 10:
        raise ValueError("nombre demasiado largo: " + name)
    name10 = name10 + b" " * (10 - len(name10))
    payload = bytes([prog_type]) + name10
    payload += bytes([length & 0xFF, (length >> 8) & 0xFF])
    payload += bytes([param1 & 0xFF, (param1 >> 8) & 0xFF])
    payload += bytes([param2 & 0xFF, (param2 >> 8) & 0xFF])
    return standard_block(0x00, payload, pause)


def archive_info_block():
    entries = [
        (0x00, b"MAD MIX GAME"),
        (0x01, b"TOPO / ERBE"),
        (0x05, b"GAME"),
        (0xFF, b"D.L. M-19452-1988. TZXed by johnny farragut"),
    ]
    data = bytes([len(entries)])
    for t, s in entries:
        data += bytes([t, len(s)]) + s
    out = bytearray()
    out.append(0x32)
    length = len(data)
    out.append(length & 0xFF)
    out.append((length >> 8) & 0xFF)
    out.extend(data)
    return bytes(out)


def tokenize(bas_path):
    text = open(bas_path, "r", encoding="utf-8").read()
    return zxbasic_tool.tok(text)


def main():
    for name in ("SCREEN.bin", "PORTADA_STUB.bin", "PORTADA_PAYLOAD.bin", "CODE.bin", "LOADER.bin"):
        if not os.path.exists(os.path.join(BUILD, name)):
            print("ERROR: falta src/build/{} -- ejecuta antes py tools/build_all.py".format(name))
            sys.exit(1)

    screen = read(os.path.join(BUILD, "SCREEN.bin"))
    portada_stub = read(os.path.join(BUILD, "PORTADA_STUB.bin"))
    portada_payload = read(os.path.join(BUILD, "PORTADA_PAYLOAD.bin"))
    code = read(os.path.join(BUILD, "CODE.bin"))
    loader = read(os.path.join(BUILD, "LOADER.bin"))

    madmix_basic = tokenize(os.path.join(LOAD_CAS, "madmix_bas.bas"))
    madmix2_basic = tokenize(os.path.join(LOAD_CAS, "madmix2_bas.bas"))

    madmix_full = madmix_basic + portada_stub + portada_payload
    if len(madmix_full) != 4317:
        print("ERROR: MAD-MIX.bas reconstruido mide {} bytes, se esperaban 4317".format(len(madmix_full)))
        sys.exit(1)
    if len(madmix2_basic) != 71:
        print("ERROR: MAD-MIX_2.bas reconstruido mide {} bytes, se esperaban 71".format(len(madmix2_basic)))
        sys.exit(1)

    out = bytearray()
    out += b"ZXTape!" + bytes([0x1A, 0x01, 0x0A])
    out += archive_info_block()
    out += header_block(0x00, "MAD-MIX", 4317, 0, 4317, pause=941)
    out += standard_block(0xFF, madmix_full, pause=8415)
    out += header_block(0x00, "MAD-MIX", 71, 0, 71, pause=944)
    out += standard_block(0xFF, madmix2_basic, pause=7098)
    out += header_block(0x03, "LOADER", 196, 61366, 0, pause=1)
    out += standard_block(0xFF, loader, pause=1)
    out += standard_block(0xFF, screen, pause=1)
    out += standard_block(0xFF, code, pause=0)

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT_PATH, "wb") as f:
        f.write(out)
    print("Generado: {} ({} bytes)".format(OUT_PATH, len(out)))

    if not os.path.exists(ORIGINAL):
        print("(no se encuentra el .tzx original en FISICO/ -- no se puede verificar)")
        return

    original = read(ORIGINAL)
    if bytes(out) == original:
        print("VERIFICACION: 0 diferencias -- {} bytes identicos byte a byte al original".format(len(original)))
    else:
        print("VERIFICACION: DIFERENCIAS encontradas")
        print("  original: {} bytes -- reconstruido: {} bytes".format(len(original), len(out)))
        n = min(len(original), len(out))
        diffs = 0
        first = None
        for i in range(n):
            if original[i] != out[i]:
                diffs += 1
                if first is None:
                    first = i
        print("  bytes distintos en el rango comun: {}".format(diffs))
        if first is not None:
            print("  primera diferencia en offset {} (0x{:X}): original={:02X} reconstruido={:02X}".format(
                first, first, original[first], out[first]))
            print("  contexto original    :", original[max(0, first - 8):first + 8].hex())
            print("  contexto reconstruido:", bytes(out)[max(0, first - 8):first + 8].hex())


if __name__ == "__main__":
    main()
