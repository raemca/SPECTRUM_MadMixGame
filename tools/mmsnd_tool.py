#!/usr/bin/env python3
"""
mmsnd_tool.py -- desensamblador/ensamblador de los guiones del motor
de sonido (data/sound/snd/*.snd + data/sound/spt/*.spt). Inspirada en
la herramienta homonima de MSX (mmsnd_tool.py/mmsnd_render.py), pero
MAS SIMPLE: el formato de Spectrum no necesita mapa de direcciones
externo porque cada guion termina con un byte $FF/$FC real dentro del
propio fichero (MSX no tenia marcador de fin en el bytecode y
necesitaba reconstruir un mapa de memoria completo solo para saber
donde paraba cada cancion).

Formato de comando (motor RESUELTO sesion 55, ver ISR_SONIDO en
madmix_body.asm y FINDINGS.md sesion 55): un byte por paso.
  0x00-0xF9  -> NOTA (nota de canal A: bits0-5=tono, bits6-7=duracion;
                nota de canal B: bits0-2=indice de percusion 0-7)
  0xFF       -> END       (fin de guion -- en canal A marca "terminado")
  0xFE       -> RESET     (reinicia duracion al valor por defecto)
  0xFD nn nn -> CALL 0xnnnn (llama a un subpatron por direccion absoluta
                de 16 bits -- referencia CRUZADA a otro fichero .spt/.snd
                de esta misma carpeta; ver src/data/sound/manifest.txt)
  0xFC       -> RETURN    (retorna del subpatron actual)
  0xFB       -> PATCH1    (parche de codigo automodificable, variante 1)
  0xFA       -> PATCH2    (parche de codigo automodificable, variante 2)

.snd = los 6 guiones reales disparados desde fuera del motor (3
parejas canal A/canal B, ver REPRODUCIR_SONIDO). .spt = los 43
subpatrones compartidos, alcanzables solo via CALL desde un .snd u
otro .spt -- localizados en sesion 55 trazando los 3 guiones
conocidos hasta agotar todos los CALL. Sesion 55: quedan ~4000 bytes
de esta misma zona ($DBE0-$E037/$E380-$EFB5) sin disparador conocido
todavia -- ver FINDINGS.md.

Uso:
  py mmsnd_tool.py disasm fichero.snd fichero.txt
  py mmsnd_tool.py asm fichero.txt fichero.snd
  py mmsnd_tool.py roundtrip fichero.snd
  py mmsnd_tool.py roundtrip-all carpeta/

Autor de esta herramienta: Rafael Eduardo Martín Candial (raemca@hotmail.com)
"""

import sys
import os

END = 0xFF
RESET = 0xFE
CALL = 0xFD
RETURN = 0xFC
PATCH1 = 0xFB
PATCH2 = 0xFA

OPS0 = {END: "END", RESET: "RESET", RETURN: "RETURN", PATCH1: "PATCH1", PATCH2: "PATCH2"}
NAME_TO_OP0 = {v: k for k, v in OPS0.items()}

WARNING_BANNER = """; !!! AVISO -- LEE ESTO ANTES DE EDITAR !!!
; Ingenieria inversa, herramientas y documentacion de este proyecto: Rafael Eduardo Martin Candial (raemca@hotmail.com)
; Guion de sonido de {name} -- {n} bytes.
; Motor RESUELTO sesion 55 (ver ISR_SONIDO en madmix_body.asm). Puedes
; cambiar el VALOR de una nota o el destino de un CALL; NO añadas ni
; quites lineas -- el tamaño es FIJO, el motor lee estos bytes
; directamente desde RAM en las direcciones originales.
; bytes={n}
"""


class DecodeError(Exception):
    pass


def disassemble(data: bytes, name: str) -> str:
    lines = [WARNING_BANNER.format(name=name, n=len(data))]
    i = 0
    n = len(data)
    while i < n:
        b = data[i]
        if b in OPS0:
            lines.append(OPS0[b])
            i += 1
            if b in (END, RETURN):
                break
        elif b == CALL:
            if i + 2 >= n:
                raise DecodeError(f"offset {i}: CALL truncado, faltan bytes de direccion")
            lo, hi = data[i + 1], data[i + 2]
            addr = lo | (hi << 8)
            lines.append(f"CALL 0x{addr:04X}")
            i += 3
        else:
            lines.append(f"NOTE 0x{b:02X}")
            i += 1
    if i < n:
        raise DecodeError(f"offset {i}: quedan {n - i} bytes tras END/RETURN")
    return "\n".join(lines) + "\n"


def assemble(text: str) -> bytes:
    out = bytearray()
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.split(";", 1)[0].strip()
        if not line:
            continue
        parts = line.split()
        mnemonic = parts[0]
        if mnemonic in NAME_TO_OP0:
            if len(parts) != 1:
                raise DecodeError(f"linea {lineno}: {mnemonic} no lleva operando")
            out.append(NAME_TO_OP0[mnemonic])
        elif mnemonic == "CALL":
            if len(parts) != 2:
                raise DecodeError(f"linea {lineno}: CALL espera 1 operando (direccion)")
            addr = int(parts[1], 16)
            out.append(CALL)
            out.append(addr & 0xFF)
            out.append((addr >> 8) & 0xFF)
        elif mnemonic == "NOTE":
            if len(parts) != 2:
                raise DecodeError(f"linea {lineno}: NOTE espera 1 operando")
            out.append(int(parts[1], 16))
        else:
            raise DecodeError(f"linea {lineno}: mnemonico desconocido '{mnemonic}'")
    return bytes(out)


def cmd_disasm(args):
    bin_path, txt_path = args
    with open(bin_path, "rb") as f:
        data = f.read()
    text = disassemble(data, os.path.basename(bin_path))
    with open(txt_path, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"escrito {txt_path} ({len(data)} bytes)")


def cmd_asm(args):
    txt_path, bin_path = args
    with open(txt_path, encoding="utf-8") as f:
        text = f.read()
    data = assemble(text)
    with open(bin_path, "wb") as f:
        f.write(data)
    print(f"escrito {bin_path} ({len(data)} bytes)")


def _roundtrip_one(bin_path):
    with open(bin_path, "rb") as f:
        original = f.read()
    text = disassemble(original, os.path.basename(bin_path))
    rebuilt = assemble(text)
    return original == rebuilt, len(original), len(rebuilt)


def cmd_roundtrip(args):
    (bin_path,) = args
    ok, n1, n2 = _roundtrip_one(bin_path)
    status = "OK" if ok else f"FALLO ({n1} bytes -> {n2} bytes)"
    print(f"{bin_path}: {status}")
    if not ok:
        sys.exit(1)


def cmd_roundtrip_all(args):
    (folder,) = args
    all_ok = True
    exts = (".snd", ".spt")
    for name in sorted(os.listdir(folder)):
        if not name.endswith(exts):
            continue
        path = os.path.join(folder, name)
        ok, n1, n2 = _roundtrip_one(path)
        print(f"{'OK  ' if ok else 'FAIL'} {name} ({n1} bytes)")
        all_ok = all_ok and ok
    sys.exit(0 if all_ok else 1)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    cmd = sys.argv[1]
    args = sys.argv[2:]
    dispatch = {
        "disasm": cmd_disasm,
        "asm": cmd_asm,
        "roundtrip": cmd_roundtrip,
        "roundtrip-all": cmd_roundtrip_all,
    }
    fn = dispatch.get(cmd)
    if fn is None:
        print(__doc__)
        sys.exit(1)
    fn(args)


if __name__ == "__main__":
    main()
