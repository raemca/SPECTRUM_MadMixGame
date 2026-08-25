#!/usr/bin/env python3
"""Detokenizador/tokenizador de BASIC de ZX Spectrum (48K).

Formato de programa: secuencia de lineas, cada una
  [num_linea: 2 bytes BIG-ENDIAN] [longitud_resto: 2 bytes LE]
  [cuerpo tokenizado...] [$0D]

Los numeros literales se guardan como los digitos ASCII tal cual se
escribieron, seguidos de un marcador $0E y 5 bytes de "numero oculto"
(forma binaria que usa el interprete, invisible en LIST). Este tool
los reconstruye recalculando esos 5 bytes a partir de los digitos; si
el recalculo no coincide exacto con el original (numeros grandes/
flotantes no cubiertos aun), se conserva el bloque entero en crudo
via escape para no perder ni un byte.

Cualquier byte no cubierto (control code no estandar, etc.) se
preserva exacto con el escape {$XX}, igual que hace msxbasic_tool.py
en el proyecto hermano de MSX -- ida y vuelta siempre sin perdidas,
aunque la tabla de tokens no cubra literalmente todo.

Comandos:
  detok <in.bas> <out.txt>   -- vuelca el binario tokenizado a texto editable
  tok   <in.txt> <out.bas>   -- vuelve a tokenizar el texto editable
  roundtrip <in.bas>         -- detok+tok en memoria y compara contra el original
"""
import sys

TOKENS = {
    0xA5: "RND", 0xA6: "INKEY$", 0xA7: "PI", 0xA8: "FN", 0xA9: "POINT",
    0xAA: "SCREEN$", 0xAB: "ATTR", 0xAC: "AT", 0xAD: "TAB", 0xAE: "VAL$",
    0xAF: "CODE", 0xB0: "VAL", 0xB1: "LEN", 0xB2: "SIN", 0xB3: "COS",
    0xB4: "TAN", 0xB5: "ASN", 0xB6: "ACS", 0xB7: "ATN", 0xB8: "LN",
    0xB9: "EXP", 0xBA: "INT", 0xBB: "SQR", 0xBC: "SGN", 0xBD: "ABS",
    0xBE: "PEEK", 0xBF: "IN", 0xC0: "USR", 0xC1: "STR$", 0xC2: "CHR$",
    0xC3: "NOT", 0xC4: "BIN", 0xC5: "OR", 0xC6: "AND", 0xC7: "<=",
    0xC8: ">=", 0xC9: "<>", 0xCA: "LINE", 0xCB: "THEN", 0xCC: "TO",
    0xCD: "STEP", 0xCE: "DEF FN", 0xCF: "CAT", 0xD0: "FORMAT",
    0xD1: "MOVE", 0xD2: "ERASE", 0xD3: "OPEN #", 0xD4: "CLOSE #",
    0xD5: "MERGE", 0xD6: "VERIFY", 0xD7: "BEEP", 0xD8: "CIRCLE",
    0xD9: "INK", 0xDA: "PAPER", 0xDB: "FLASH", 0xDC: "BRIGHT",
    0xDD: "INVERSE", 0xDE: "OVER", 0xDF: "OUT", 0xE0: "LPRINT",
    0xE1: "LLIST", 0xE2: "STOP", 0xE3: "READ", 0xE4: "DATA",
    0xE5: "RESTORE", 0xE6: "NEW", 0xE7: "BORDER", 0xE8: "CONTINUE",
    0xE9: "DIM", 0xEA: "REM", 0xEB: "FOR", 0xEC: "GO TO", 0xED: "GO SUB",
    0xEE: "INPUT", 0xEF: "LOAD", 0xF0: "LIST", 0xF1: "LET",
    0xF2: "PAUSE", 0xF3: "NEXT", 0xF4: "POKE", 0xF5: "PRINT",
    0xF6: "PLOT", 0xF7: "RUN", 0xF8: "SAVE", 0xF9: "RANDOMIZE",
    0xFA: "IF", 0xFB: "CLS", 0xFC: "DRAW", 0xFD: "CLEAR",
    0xFE: "RETURN", 0xFF: "COPY",
}
TOKENS_REV = {v: k for k, v in TOKENS.items()}
# todos los nombres de token, mas largos primero -- para reconocerlos en
# cualquier posicion del texto al retokenizar, sin depender de espacios
ALLTOKENS_SORTED = sorted(TOKENS.values(), key=len, reverse=True)

CTRL1 = {0x10: "INK", 0x11: "PAPER", 0x12: "FLASH", 0x13: "BRIGHT",
         0x14: "INVERSE", 0x15: "OVER"}
CTRL1_REV = {v: k for k, v in CTRL1.items()}
CTRL2 = {0x16: "AT", 0x17: "TAB"}
CTRL2_REV = {v: k for k, v in CTRL2.items()}


def encode_number(digits: str):
    """Recodifica un literal entero (0-65535) a los 5 bytes ocultos.
    Devuelve None si no se puede reproducir de forma segura (se
    conservara en crudo por el llamador)."""
    try:
        v = int(digits)
    except ValueError:
        return None
    if not (0 <= v <= 65535):
        return None
    return bytes([0x00, 0x00, v & 0xFF, (v >> 8) & 0xFF, 0x00])


def detok_line_body(body: bytes) -> str:
    out = []
    i = 0
    n = len(body)
    in_string = False
    while i < n:
        b = body[i]
        if in_string:
            if b == 0x22:  # comilla de cierre
                out.append('"')
                in_string = False
                i += 1
            elif 0x20 <= b <= 0x7E:
                out.append(chr(b))
                i += 1
            else:
                out.append("{{${:02X}}}".format(b))
                i += 1
            continue
        if b == 0x22:
            out.append('"')
            in_string = True
            i += 1
        elif b in TOKENS:
            out.append(TOKENS[b])
            i += 1
            if TOKENS[b] == "REM":
                # el resto de la linea tras REM es contenido arbitrario
                # (a veces datos binarios crudos, p.ej. UDGs) -- se
                # conserva byte a byte sin intentar interpretarlo
                rest = body[i:]
                if rest:
                    out.append("{{REMDATA:{}}}".format(rest.hex()))
                i = n
        elif b in CTRL1:
            if i + 1 < n:
                out.append("{{{}:{:02X}}}".format(CTRL1[b], body[i + 1]))
                i += 2
            else:
                out.append("{{${:02X}}}".format(b))
                i += 1
        elif b in CTRL2:
            if i + 2 < n:
                out.append("{{{}:{:02X},{:02X}}}".format(CTRL2[b], body[i + 1], body[i + 2]))
                i += 3
            else:
                out.append("{{${:02X}}}".format(b))
                i += 1
        elif 0x30 <= b <= 0x39:  # digito ascii -- posible numero con marcador oculto
            j = i
            while j < n and 0x30 <= body[j] <= 0x39:
                j += 1
            digits = body[i:j].decode("ascii")
            if j < n and body[j] == 0x0E and j + 6 <= n:
                hidden = body[j + 1:j + 6]
                recoded = encode_number(digits)
                if recoded == hidden:
                    out.append(digits)
                    i = j + 6
                    continue
                else:
                    out.append(digits)
                    out.append("{{NUM:" + hidden.hex().upper() + "}}")
                    i = j + 6
                    continue
            out.append(digits)
            i = j
        elif 0x20 <= b <= 0x7E:
            out.append(chr(b))
            i += 1
        else:
            out.append("{{${:02X}}}".format(b))
            i += 1
    return "".join(out)


def detok(data: bytes) -> str:
    lines = []
    i = 0
    n = len(data)
    while i < n:
        if i + 4 > n:
            lines.append("; {} bytes finales sin interpretar: {}".format(
                n - i, data[i:].hex()))
            break
        line_num = (data[i] << 8) | data[i + 1]
        length = data[i + 2] | (data[i + 3] << 8)
        body_start = i + 4
        body_end = body_start + length
        if body_end > n:
            lines.append("; linea {} declara longitud {} pero solo quedan {} bytes -- crudo: {}".format(
                line_num, length, n - body_start, data[body_start:].hex()))
            break
        body = data[body_start:body_end]
        if len(body) == 0 or body[-1] != 0x0D:
            # cuerpo sin CR final esperado -- se conserva completo en crudo
            lines.append("{} ; {{RAWLINE:{}}}".format(line_num, body.hex()))
        else:
            text = detok_line_body(body[:-1])
            lines.append("{} {}".format(line_num, text))
        i = body_end
    return "\n".join(lines) + "\n"


def tok_line_body(text: str) -> bytes:
    out = bytearray()
    i = 0
    n = len(text)
    in_string = False
    while i < n:
        c = text[i]
        if in_string:
            if c == '"':
                out.append(0x22)
                in_string = False
                i += 1
            elif c == "{" :
                j = text.index("}", i)
                tag = text[i + 1:j]
                out.extend(parse_escape(tag))
                i = j + 1
            else:
                out.append(ord(c))
                i += 1
            continue
        if c == '"':
            out.append(0x22)
            in_string = True
            i += 1
        elif c == "{":
            j = text.index("}", i)
            tag = text[i + 1:j]
            out.extend(parse_escape(tag))
            i = j + 1
        elif c.isdigit():
            j = i
            while j < n and text[j].isdigit():
                j += 1
            digits = text[i:j]
            out.extend(digits.encode("ascii"))
            # numero seguido opcionalmente de {NUM:...} explicito
            if j < n and text[j] == "{" and text[j + 1:j + 4] == "NUM":
                k = text.index("}", j)
                hexpart = text[j + 5:k]
                out.append(0x0E)
                out.extend(bytes.fromhex(hexpart))
                i = k + 1
            else:
                recoded = encode_number(digits)
                if recoded is None:
                    raise ValueError("numero {} no representable, usa {{NUM:..}} explicito".format(digits))
                out.append(0x0E)
                out.extend(recoded)
                i = j
        else:
            # coincidencia mas larga posible con cualquier token conocido,
            # en la posicion actual (no hace falta separador/espacio antes
            # ni despues: "BORDER0" reconoce "BORDER" igual que "BORDER 0")
            matched = False
            for name in ALLTOKENS_SORTED:
                if text.startswith(name, i):
                    out.append(TOKENS_REV[name])
                    i += len(name)
                    matched = True
                    break
            if matched:
                continue
            out.append(ord(c))
            i += 1
    out.append(0x0D)
    return bytes(out)


def parse_escape(tag: str) -> bytes:
    if tag.startswith("$"):
        return bytes([int(tag[1:], 16)])
    if ":" in tag:
        name, params = tag.split(":", 1)
        if name == "REMDATA":
            return bytes.fromhex(params)
        if name in CTRL1_REV:
            return bytes([CTRL1_REV[name], int(params, 16)])
        if name in CTRL2_REV:
            p1, p2 = params.split(",")
            return bytes([CTRL2_REV[name], int(p1, 16), int(p2, 16)])
    raise ValueError("escape no reconocido: {" + tag + "}")


def tok(text: str) -> bytes:
    out = bytearray()
    for raw_line in text.splitlines():
        if not raw_line.strip() or raw_line.lstrip().startswith(";"):
            continue
        parts = raw_line.split(" ", 1)
        line_num = int(parts[0])
        rest = parts[1] if len(parts) > 1 else ""
        if rest.startswith("{RAWLINE:") and rest.endswith("}"):
            body = bytes.fromhex(rest[len("{RAWLINE:"):-1])
        else:
            body = tok_line_body(rest)
        out.append((line_num >> 8) & 0xFF)
        out.append(line_num & 0xFF)
        length = len(body)
        out.append(length & 0xFF)
        out.append((length >> 8) & 0xFF)
        out.extend(body)
    return bytes(out)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    cmd = argv[0]
    if cmd == "detok":
        data = open(argv[1], "rb").read()
        text = detok(data)
        open(argv[2], "w", encoding="utf-8", newline="\n").write(text)
        print("OK: {} -> {} ({} bytes -> {} lineas)".format(argv[1], argv[2], len(data), text.count(chr(10))))
    elif cmd == "tok":
        text = open(argv[1], "r", encoding="utf-8").read()
        data = tok(text)
        open(argv[2], "wb").write(data)
        print("OK: {} -> {} ({} bytes)".format(argv[1], argv[2], len(data)))
    elif cmd == "roundtrip":
        data = open(argv[1], "rb").read()
        text = detok(data)
        data2 = tok(text)
        if data2 == data:
            print("OK: roundtrip identico, {} bytes".format(len(data)))
            return 0
        else:
            print("DIFERENCIAS: original {} bytes, recodificado {} bytes".format(len(data), len(data2)))
            n = min(len(data), len(data2))
            for i in range(n):
                if data[i] != data2[i]:
                    print("  primer byte distinto en offset {}: original={:02X} recodificado={:02X}".format(i, data[i], data2[i]))
                    print("  contexto original    :", data[max(0, i - 8):i + 8].hex())
                    print("  contexto recodificado:", data2[max(0, i - 8):i + 8].hex())
                    break
            return 1
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
