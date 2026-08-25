#!/usr/bin/env python3
"""Convierte una salida de Z80Dasm.exe a fuente SjASMPlus compilable,
etiquetando (<prefijo>XXXX) todo destino de CALL/JP/JR/DJNZ que caiga
en una direccion donde Z80Dasm decodifico una instruccion de verdad.
El resto de operandos con direccion absoluta se dejan tal cual (hex
literal) -- solo se etiquetan saltos/llamadas, no cualquier referencia
a una direccion (evita relabelizar constantes que solo coinciden con
una direccion por casualidad).

Primer paso mecanico de reconstruccion: garantiza (por construccion,
ya que el desensamblado de Z80Dasm es lineal byte a byte) que el
resultado recompila IDENTICO al binario original, ENTIENDA O NO
todavia el analisis que es codigo real y que son datos malinterpretados
como codigo -- ver madmix_body.asm/portada_body.asm para el resultado
real sobre los binarios de este proyecto, y FINDINGS.md para el
detalle de como se uso.

3 formas de instruccion no documentada que SjASMPlus rechaza como
texto (aunque el Z80 real las ejecuta: "IYH,H" tipo mezclas de medio-
registro IX/IY con el H/L simple) se vuelcan como DB con los bytes
reales en vez de mnemonico, para no perder ni cambiar nada.

Uso: py dasm2asm.py <entrada.dasm.txt> <salida.asm> <prefijo_etiqueta> <nombre_entrada> <nombre_fin>
"""
import re
import sys

LINE_RE = re.compile(r'^\s*(\S+)(?:\s+(.*?))?\s*;\s*([0-9A-Fa-f]{6})\s+((?:[0-9A-Fa-f]{2}\s*)+)$')
BRANCH_MNEM = {"call", "jp", "jr", "djnz"}
ADDR_IN_OPERAND_RE = re.compile(r'\$([0-9A-Fa-f]{2,4})')
RISKY_UNDOC_RE = re.compile(r'^(IX[HL]|IY[HL]),([HL])$|^([HL]),(IX[HL]|IY[HL])$', re.IGNORECASE)


def parse(path):
    entries = []
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if not line.strip():
                continue
            if line.startswith("z80dasm") or line.startswith("Copyright"):
                continue
            m = LINE_RE.match(line)
            if not m:
                raise ValueError("linea no reconocida: {!r}".format(line))
            mnem, operands, addr_hex, bytes_hex = m.groups()
            addr = int(addr_hex, 16) & 0xFFFF
            entries.append({
                "mnem": mnem,
                "operands": operands or "",
                "addr": addr,
                "nbytes": len(bytes_hex.split()),
                "bytes": bytes_hex.split(),
            })
    return entries


def rewrite_operand(operands, addr_set, label_prefix):
    def repl(m):
        val = int(m.group(1), 16)
        if len(m.group(1)) == 4 and val in addr_set:
            return "{}{:04X}".format(label_prefix, val)
        return m.group(0)
    return ADDR_IN_OPERAND_RE.sub(repl, operands)


def convert(in_path, out_path, label_prefix, entry_name, end_name):
    entries = parse(in_path)
    addr_index = {e["addr"]: i for i, e in enumerate(entries)}
    base = entries[0]["addr"]
    last = entries[-1]["addr"] + entries[-1]["nbytes"]

    targets = set()
    for e in entries:
        if e["mnem"].lower() in BRANCH_MNEM:
            for m in ADDR_IN_OPERAND_RE.finditer(e["operands"]):
                if len(m.group(1)) == 4:
                    val = int(m.group(1), 16)
                    if val in addr_index:
                        targets.add(val)

    out = []
    out.append("; Generado mecanicamente a partir de Z80Dasm.exe + tools/dasm2asm.py")
    out.append("; (traduccion literal, sin analisis semantico todavia -- ver FINDINGS.md)")
    out.append("{}:".format(entry_name))
    for e in entries:
        if e["addr"] in targets:
            out.append("{}{:04X}:".format(label_prefix, e["addr"]))
        operands = rewrite_operand(e["operands"], targets, label_prefix)
        if RISKY_UNDOC_RE.match(operands.strip().upper()):
            out.append("    DB {}".format(",".join("${}".format(b.upper()) for b in e["bytes"])))
        elif operands:
            out.append("    {} {}".format(e["mnem"].upper(), operands.upper()))
        else:
            out.append("    {}".format(e["mnem"].upper()))
    out.append("{}:".format(end_name))

    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")

    print("OK: {} lineas, direcciones {:04X}-{:04X}, {} etiquetas".format(
        len(entries), base, last - 1, len(targets)))


def main(argv):
    if len(argv) != 5:
        print(__doc__)
        return 1
    convert(*argv)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
