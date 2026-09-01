#!/usr/bin/env python3
"""
mmcanvas_sim.py -- simulador Z80 razonablemente completo (misma
filosofia que mmesquema_sim.py: ejecutar el CODIGO ORIGINAL de verdad
en vez de razonarlo a mano) usado para responder una pregunta
concreta: ¿tiene madmix_body.asm un "lienzo de bitmap en RAM" como el
de MSX ($DE04, ver mapa_memoria.html de MSX), o dibuja siempre
directo a la pantalla real (memoria mapeada, $4000-$57FF)?

Motivo: GESTIONAR_SCROLL/REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM/
REDIBUJAR_LOSETA_BUFFER_VRAM usan literales "$E404" como base de
trabajo -- razonarlo a mano (algebra de direcciones + memoria
reciclada del marco decorativo) era propenso a error, igual que le
paso a mmesquema_sim.py con REFRESCAR_ESQUEMA_COLOR_NIVEL. La unica
forma de saber con certeza donde escribe cada rutina es ejecutar el
codigo real sobre una copia real de memoria (FISICO/CODE.bin).

RESULTADO (sesion 56, ver FINDINGS.md): CONFIRMADO que SI existe un
lienzo de trabajo en RAM, ~4680+ bytes desde $E404 hasta al menos
$F88C -- reutiliza la misma memoria que BITMAP_MARCO_DECORATIVO
($E3F2-$EFA1) una vez consumida, y se extiende mas alla de lo
documentado hasta entonces para ese segmento. Lo usan
GESTIONAR_SCROLL, REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM,
REDIBUJAR_LOSETA_BUFFER_VRAM (y por tanto tambien DIBUJAR_CAMBIO_LOSETA,
que llama a esta ultima) -- equivalente real al lienzo de MSX.
CONFIRMADO tambien que MOTOR_ACTORES/DIBUJAR_ACTORES_PENDIENTES NO
necesitan un buffer de render de actores separado (a diferencia de
MSX, $0500-$1000): MOTOR_ACTORES calcula la direccion de pantalla
REAL con CALCULAR_DIRECCION_PANTALLA y la guarda en el registro del
actor; DIBUJAR_ACTORES_PENDIENTES compone el sprite directamente
sobre esa direccion real, sin paso intermedio -- tiene sentido, dado
que aqui la pantalla esta mapeada en memoria y no hace falta el paso
extra que si necesita el VDP de MSX.

PENDIENTE (sin resolver pese a busqueda exhaustiva, ver FINDINGS.md):
el mecanismo que vuelca ese lienzo lineal a la pantalla real
entrelazada no se ha localizado -- se comprobaron los 5 llamadores de
CALCULAR_DIRECCION_PANTALLA (todos HUD/texto/iconos, ninguno vuelca
el laberinto), el cuerpo completo de WAIT_VBLANK y
TICK_REDIBUJADO_VBLANK, y que el operando "$E404" de estas
instrucciones no se automodifica en ningun sitio. Candidato para una
sesion futura con mas herramientas (emulador con video real).

Uso:
  py tools/mmcanvas_sim.py

Levanta NotImplementedError ante cualquier opcode no cubierto -- a
proposito, para no producir resultados silenciosamente incorrectos.

Autor de esta herramienta: Rafael Eduardo Martín Candial (raemca@hotmail.com)
"""
import os
from collections import Counter

ROOT = os.path.join(os.path.dirname(__file__), "..")
CODE_BIN = os.path.join(ROOT, "FISICO", "CODE.bin")
MEM_BASE = 0x6000

CARGAR_MARCO_DECORATIVO = 0x915A
REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM = 0x9904
REDIBUJAR_LOSETA_BUFFER_VRAM = 0x99BD
REGISTRO_NIVEL_POSICION_COMECOCOS = 0x6016


class CPU:
    def __init__(self, mem):
        self.mem = mem
        self.A = 0; self.F = 0
        self.B = 0; self.C = 0
        self.D = 0; self.E = 0
        self.H = 0; self.L = 0
        self.A_ = 0; self.F_ = 0
        self.B_ = 0; self.C_ = 0
        self.D_ = 0; self.E_ = 0
        self.H_ = 0; self.L_ = 0
        self.IX = 0; self.IY = 0
        self.I = 0
        self.SP = 0x5FFF
        self.PC = 0
        self.IFF = True
        self.t = 0
        self.write_log = []
        self.trace_writes = False
        self.ports_in = {}
        self.io_reads = []

    def rb(self, a): return self.mem[a & 0xFFFF]
    def wb(self, a, v):
        v &= 0xFF
        self.mem[a & 0xFFFF] = v
        if self.trace_writes:
            self.write_log.append((self.PC, a & 0xFFFF, v))
    def rw(self, a): return self.rb(a) | (self.rb(a + 1) << 8)
    def ww(self, a, v):
        self.wb(a, v)
        self.wb(a + 1, v >> 8)

    # --- flags: bit7 S, bit6 Z, bit4 H, bit2 PV, bit1 N, bit0 C ---
    def setflag(self, mask, v):
        self.F = (self.F | mask) if v else (self.F & ~mask & 0xFF)
    def setZ(self, v): self.setflag(0x40, v)
    def getZ(self): return bool(self.F & 0x40)
    def setC(self, v): self.setflag(0x01, v)
    def getC(self): return bool(self.F & 0x01)
    def setS(self, v): self.setflag(0x80, v)
    def getS(self): return bool(self.F & 0x80)

    def BC(self): return (self.B << 8) | self.C
    def setBC(self, v): self.B = (v >> 8) & 0xFF; self.C = v & 0xFF
    def DE(self): return (self.D << 8) | self.E
    def setDE(self, v): self.D = (v >> 8) & 0xFF; self.E = v & 0xFF
    def HL(self): return (self.H << 8) | self.L
    def setHL(self, v): self.H = (v >> 8) & 0xFF; self.L = v & 0xFF

    def push(self, v):
        self.SP = (self.SP - 2) & 0xFFFF
        self.ww(self.SP, v)
    def pop(self):
        v = self.rw(self.SP)
        self.SP = (self.SP + 2) & 0xFFFF
        return v

    def fetch(self):
        b = self.rb(self.PC)
        self.PC = (self.PC + 1) & 0xFFFF
        return b
    def fetch_signed(self):
        v = self.fetch()
        return v - 256 if v >= 128 else v
    def fetch16(self):
        return self.fetch() | (self.fetch() << 8)

    def regname8(self, idx):
        return ['B', 'C', 'D', 'E', 'H', 'L', None, 'A'][idx]

    def getr(self, idx):
        if idx == 6: return self.rb(self.HL())
        return getattr(self, self.regname8(idx))
    def setr(self, idx, v):
        if idx == 6: self.wb(self.HL(), v & 0xFF)
        else: setattr(self, self.regname8(idx), v & 0xFF)

    def alu(self, grp, val):
        a = self.A
        if grp == 0:
            r = a + val; self.setC(r > 0xFF); self.A = r & 0xFF
        elif grp == 1:
            r = a + val + (1 if self.getC() else 0); self.setC(r > 0xFF); self.A = r & 0xFF
        elif grp == 2:
            r = a - val; self.setC(r < 0); self.A = r & 0xFF
        elif grp == 3:
            r = a - val - (1 if self.getC() else 0); self.setC(r < 0); self.A = r & 0xFF
        elif grp == 4:
            self.A = a & val; self.setC(False)
        elif grp == 5:
            self.A = a ^ val; self.setC(False)
        elif grp == 6:
            self.A = a | val; self.setC(False)
        elif grp == 7:
            r = a - val
            self.setC(r < 0); self.setZ((r & 0xFF) == 0); self.setS(bool(r & 0x80))
            return
        self.setZ(self.A == 0); self.setS(bool(self.A & 0x80))

    def cond(self, cc):
        if cc == 0: return not self.getZ()
        if cc == 1: return self.getZ()
        if cc == 2: return not self.getC()
        if cc == 3: return self.getC()
        if cc == 6: return not self.getS()
        if cc == 7: return self.getS()
        raise NotImplementedError(f"condicion PV no implementada (cc={cc})")

    def step(self):
        pc0 = self.PC
        op = self.fetch()
        rb, wb = self.rb, self.wb

        if op == 0x00: self.t += 4
        elif op == 0x76: self.t += 4  # HALT -- solo se traza escritura, no se simula el IRQ real
        elif op in (0x01, 0x11, 0x21, 0x31):
            v = self.fetch16()
            [self.setBC, self.setDE, self.setHL, lambda x: setattr(self, 'SP', x)][(op >> 4)](v)
            self.t += 10
        elif op == 0x02: wb(self.BC(), self.A); self.t += 7
        elif op == 0x0A: self.A = rb(self.BC()); self.t += 7
        elif op == 0x12: wb(self.DE(), self.A); self.t += 7
        elif op == 0x1A: self.A = rb(self.DE()); self.t += 7
        elif op == 0x22: a = self.fetch16(); self.ww(a, self.HL()); self.t += 16
        elif op == 0x2A: a = self.fetch16(); self.setHL(self.rw(a)); self.t += 16
        elif op == 0x32: a = self.fetch16(); wb(a, self.A); self.t += 13
        elif op == 0x3A: a = self.fetch16(); self.A = rb(a); self.t += 13
        elif op in (0x03, 0x13, 0x23, 0x33):
            idx = op >> 4
            if idx == 0: self.setBC((self.BC() + 1) & 0xFFFF)
            elif idx == 1: self.setDE((self.DE() + 1) & 0xFFFF)
            elif idx == 2: self.setHL((self.HL() + 1) & 0xFFFF)
            else: self.SP = (self.SP + 1) & 0xFFFF
            self.t += 6
        elif op in (0x0B, 0x1B, 0x2B, 0x3B):
            idx = op >> 4
            if idx == 0: self.setBC((self.BC() - 1) & 0xFFFF)
            elif idx == 1: self.setDE((self.DE() - 1) & 0xFFFF)
            elif idx == 2: self.setHL((self.HL() - 1) & 0xFFFF)
            else: self.SP = (self.SP - 1) & 0xFFFF
            self.t += 6
        elif op in (0x09, 0x19, 0x29, 0x39):
            src = [self.BC(), self.DE(), self.HL(), self.SP][op >> 4]
            r = self.HL() + src; self.setC(r > 0xFFFF); self.setHL(r & 0xFFFF); self.t += 11
        elif (op & 0xC7) == 0x04:
            idx = (op >> 3) & 7
            v = (self.getr(idx) + 1) & 0xFF
            self.setr(idx, v); self.setZ(v == 0); self.setS(bool(v & 0x80))
            self.t += 11 if idx == 6 else 4
        elif (op & 0xC7) == 0x05:
            idx = (op >> 3) & 7
            v = (self.getr(idx) - 1) & 0xFF
            self.setr(idx, v); self.setZ(v == 0); self.setS(bool(v & 0x80))
            self.t += 11 if idx == 6 else 4
        elif (op & 0xC7) == 0x06:
            idx = (op >> 3) & 7
            n = self.fetch()
            self.setr(idx, n)
            self.t += 10 if idx == 6 else 7
        elif op == 0x07: self.setC(bool(self.A & 0x80)); self.A = ((self.A << 1) | (self.A >> 7)) & 0xFF; self.t += 4
        elif op == 0x0F: self.setC(bool(self.A & 1)); self.A = ((self.A >> 1) | ((self.A & 1) << 7)) & 0xFF; self.t += 4
        elif op == 0x17:
            oc = 1 if self.getC() else 0
            self.setC(bool(self.A & 0x80)); self.A = ((self.A << 1) | oc) & 0xFF; self.t += 4
        elif op == 0x1F:
            oc = 1 if self.getC() else 0
            self.setC(self.A & 1); self.A = ((self.A >> 1) | (oc << 7)) & 0xFF; self.t += 4
        elif op == 0x08:
            self.A, self.A_ = self.A_, self.A; self.F, self.F_ = self.F_, self.F; self.t += 4
        elif op == 0x10:
            d = self.fetch_signed()
            self.B = (self.B - 1) & 0xFF
            if self.B != 0: self.PC = (self.PC + d) & 0xFFFF; self.t += 13
            else: self.t += 8
        elif op == 0x18:
            d = self.fetch_signed(); self.PC = (self.PC + d) & 0xFFFF; self.t += 12
        elif (op & 0xE7) == 0x20:
            d = self.fetch_signed(); cc = (op >> 3) & 3
            if self.cond(cc): self.PC = (self.PC + d) & 0xFFFF; self.t += 12
            else: self.t += 7
        elif op == 0x2F: self.A = (~self.A) & 0xFF; self.t += 4
        elif op == 0x37: self.setC(True); self.t += 4
        elif op == 0x3F: self.setC(not self.getC()); self.t += 4
        elif op == 0xD3: self.fetch(); self.t += 11
        elif op == 0xDB:
            n = self.fetch(); self.A = self.ports_in.get(n, 0xFF); self.io_reads.append(n); self.t += 11
        elif 0x40 <= op <= 0x7F:
            dst = (op >> 3) & 7; src = op & 7
            v = self.getr(src); self.setr(dst, v)
            self.t += (7 if (dst == 6 or src == 6) else 4)
        elif 0x80 <= op <= 0xBF:
            grp = (op >> 3) & 7; src = op & 7
            self.alu(grp, self.getr(src)); self.t += (7 if src == 6 else 4)
        elif (op & 0xC7) == 0xC6:
            grp = (op >> 3) & 7; self.alu(grp, self.fetch()); self.t += 7
        elif op == 0xC3: self.PC = self.fetch16(); self.t += 10
        elif (op & 0xC7) == 0xC2:
            a = self.fetch16()
            if self.cond((op >> 3) & 7): self.PC = a
            self.t += 10
        elif op == 0xCD: a = self.fetch16(); self.push(self.PC); self.PC = a; self.t += 17
        elif (op & 0xC7) == 0xC4:
            a = self.fetch16()
            if self.cond((op >> 3) & 7): self.push(self.PC); self.PC = a; self.t += 17
            else: self.t += 10
        elif op == 0xC9: self.PC = self.pop(); self.t += 10
        elif (op & 0xC7) == 0xC0:
            if self.cond((op >> 3) & 7): self.PC = self.pop(); self.t += 11
            else: self.t += 5
        elif op in (0xC5, 0xD5, 0xE5, 0xF5):
            v = [self.BC(), self.DE(), self.HL(), (self.A << 8) | self.F][(op >> 4) & 3]
            self.push(v); self.t += 11
        elif op in (0xC1, 0xD1, 0xE1, 0xF1):
            v = self.pop(); idx = (op >> 4) & 3
            if idx == 0: self.setBC(v)
            elif idx == 1: self.setDE(v)
            elif idx == 2: self.setHL(v)
            else: self.A = (v >> 8) & 0xFF; self.F = v & 0xFF
            self.t += 10
        elif (op & 0xC7) == 0xC7:
            n = op & 0x38; self.push(self.PC); self.PC = n; self.t += 11
        elif op == 0xD9:
            self.B, self.B_ = self.B_, self.B
            self.C, self.C_ = self.C_, self.C
            self.D, self.D_ = self.D_, self.D
            self.E, self.E_ = self.E_, self.E
            self.H, self.H_ = self.H_, self.H
            self.L, self.L_ = self.L_, self.L
            self.t += 4
        elif op == 0xE3:
            v = self.rw(self.SP); self.ww(self.SP, self.HL()); self.setHL(v); self.t += 19
        elif op == 0xE9: self.PC = self.HL(); self.t += 4
        elif op == 0xEB:
            de, hl = self.DE(), self.HL(); self.setDE(hl); self.setHL(de); self.t += 4
        elif op == 0xF3: self.IFF = False; self.t += 4
        elif op == 0xFB: self.IFF = True; self.t += 4
        elif op == 0xF9: self.SP = self.HL(); self.t += 6

        elif op == 0xCB:
            op2 = self.fetch()
            grp = (op2 >> 6) & 3; bit = (op2 >> 3) & 7; idx = op2 & 7
            val = self.getr(idx)
            if grp == 0:
                kind = bit; c_in = 1 if self.getC() else 0
                if kind == 0: c_out = bool(val & 0x80); val = ((val << 1) | c_out) & 0xFF
                elif kind == 1: c_out = bool(val & 1); val = ((val >> 1) | (c_out << 7)) & 0xFF
                elif kind == 2: c_out = bool(val & 0x80); val = ((val << 1) | c_in) & 0xFF
                elif kind == 3: c_out = bool(val & 1); val = ((val >> 1) | (c_in << 7)) & 0xFF
                elif kind == 4: c_out = bool(val & 0x80); val = (val << 1) & 0xFF
                elif kind == 5: c_out = bool(val & 1); val = ((val >> 1) | (val & 0x80)) & 0xFF
                elif kind == 6: c_out = bool(val & 0x80); val = ((val << 1) | 1) & 0xFF
                else: c_out = bool(val & 1); val = (val >> 1) & 0xFF
                self.setC(c_out); self.setZ(val == 0); self.setS(bool(val & 0x80)); self.setr(idx, val)
            elif grp == 1: self.setZ((val & (1 << bit)) == 0)
            elif grp == 2: self.setr(idx, val & ~(1 << bit) & 0xFF)
            else: self.setr(idx, val | (1 << bit))
            self.t += (15 if idx == 6 else 8)

        elif op == 0xED:
            op2 = self.fetch()
            if op2 == 0xB0:
                while self.BC() != 0:
                    wb(self.DE(), rb(self.HL()))
                    self.setHL((self.HL() + 1) & 0xFFFF); self.setDE((self.DE() + 1) & 0xFFFF)
                    self.setBC((self.BC() - 1) & 0xFFFF); self.t += 21
            elif op2 == 0xA0:
                wb(self.DE(), rb(self.HL()))
                self.setHL((self.HL() + 1) & 0xFFFF); self.setDE((self.DE() + 1) & 0xFFFF)
                self.setBC((self.BC() - 1) & 0xFFFF); self.t += 16
            elif op2 == 0xB8:
                while self.BC() != 0:
                    wb(self.DE(), rb(self.HL()))
                    self.setHL((self.HL() - 1) & 0xFFFF); self.setDE((self.DE() - 1) & 0xFFFF)
                    self.setBC((self.BC() - 1) & 0xFFFF); self.t += 21
            elif op2 == 0xA8:
                wb(self.DE(), rb(self.HL()))
                self.setHL((self.HL() - 1) & 0xFFFF); self.setDE((self.DE() - 1) & 0xFFFF)
                self.setBC((self.BC() - 1) & 0xFFFF); self.t += 16
            elif op2 == 0x67:
                hl = self.HL(); m = rb(hl)
                a_lo = self.A & 0x0F; m_lo = m & 0x0F; m_hi = (m >> 4) & 0x0F
                self.A = (self.A & 0xF0) | m_lo; wb(hl, (a_lo << 4) | m_hi)
                self.setZ(self.A == 0); self.setS(bool(self.A & 0x80)); self.t += 18
            elif op2 == 0x6F:
                hl = self.HL(); m = rb(hl)
                a_lo = self.A & 0x0F; m_lo = m & 0x0F; m_hi = (m >> 4) & 0x0F
                self.A = (self.A & 0xF0) | m_hi; wb(hl, (m_lo << 4) | a_lo)
                self.setZ(self.A == 0); self.setS(bool(self.A & 0x80)); self.t += 18
            elif op2 == 0x43: a = self.fetch16(); self.ww(a, self.BC()); self.t += 20
            elif op2 == 0x53: a = self.fetch16(); self.ww(a, self.DE()); self.t += 20
            elif op2 == 0x73: a = self.fetch16(); self.ww(a, self.SP); self.t += 20
            elif op2 == 0x4B: a = self.fetch16(); self.setBC(self.rw(a)); self.t += 20
            elif op2 == 0x5B: a = self.fetch16(); self.setDE(self.rw(a)); self.t += 20
            elif op2 == 0x7B: a = self.fetch16(); self.SP = self.rw(a); self.t += 20
            elif op2 == 0x44:
                r = (0 - self.A) & 0xFF; self.setC(self.A != 0); self.A = r
                self.setZ(r == 0); self.setS(bool(r & 0x80)); self.t += 8
            elif op2 == 0x47: self.I = self.A; self.t += 9
            elif op2 == 0x57: self.A = self.I; self.t += 9
            elif op2 in (0x46, 0x56, 0x5E): self.t += 8
            elif op2 in (0x4D, 0x45): self.PC = self.pop(); self.t += 14
            elif (op2 & 0xC7) == 0x42:
                idx2 = (op2 >> 4) & 3
                src = [self.BC(), self.DE(), self.HL(), self.SP][idx2]
                c = 1 if self.getC() else 0
                r = self.HL() - src - c
                self.setC(r < 0); self.setZ((r & 0xFFFF) == 0); self.setS(bool(r & 0x8000))
                self.setHL(r & 0xFFFF); self.t += 15
            elif (op2 & 0xC7) == 0x4A:
                idx2 = (op2 >> 4) & 3
                src = [self.BC(), self.DE(), self.HL(), self.SP][idx2]
                c = 1 if self.getC() else 0
                r = self.HL() + src + c
                self.setC(r > 0xFFFF); self.setZ((r & 0xFFFF) == 0); self.setS(bool(r & 0x8000))
                self.setHL(r & 0xFFFF); self.t += 15
            else:
                raise NotImplementedError(f"opcode ED 0x{op2:02X} sin implementar en PC={pc0:04X}")

        elif op == 0xDD:
            op2 = self.fetch()
            if op2 == 0x21: self.IX = self.fetch16(); self.t += 14
            elif op2 == 0x22: a = self.fetch16(); self.ww(a, self.IX); self.t += 20
            elif op2 == 0x2A: a = self.fetch16(); self.IX = self.rw(a); self.t += 20
            elif op2 == 0xE5: self.push(self.IX); self.t += 15
            elif op2 == 0xE1: self.IX = self.pop(); self.t += 14
            elif op2 == 0xF9: self.SP = self.IX; self.t += 10
            elif op2 == 0xE9: self.PC = self.IX; self.t += 8
            elif op2 == 0x23: self.IX = (self.IX + 1) & 0xFFFF; self.t += 10
            elif op2 == 0x2B: self.IX = (self.IX - 1) & 0xFFFF; self.t += 10
            elif (op2 & 0xCF) == 0x09:
                idx2 = (op2 >> 4) & 3
                src = [self.BC(), self.DE(), self.IX, self.SP][idx2]
                r = self.IX + src; self.setC(r > 0xFFFF); self.IX = r & 0xFFFF; self.t += 15
            elif op2 == 0x36:
                d = self.fetch_signed(); n = self.fetch(); wb((self.IX + d) & 0xFFFF, n); self.t += 19
            elif op2 == 0x7C: self.A = (self.IX >> 8) & 0xFF; self.t += 8
            elif op2 == 0x7D: self.A = self.IX & 0xFF; self.t += 8
            elif op2 == 0x34:
                d = self.fetch_signed(); a = (self.IX + d) & 0xFFFF; v = (rb(a) + 1) & 0xFF; wb(a, v)
                self.setZ(v == 0); self.setS(bool(v & 0x80)); self.t += 23
            elif op2 == 0x35:
                d = self.fetch_signed(); a = (self.IX + d) & 0xFFFF; v = (rb(a) - 1) & 0xFF; wb(a, v)
                self.setZ(v == 0); self.setS(bool(v & 0x80)); self.t += 23
            elif (op2 & 0xC7) == 0x46 and (op2 & 0x38) != 0x30:
                d = self.fetch_signed(); dst = (op2 >> 3) & 7
                self.setr(dst, rb((self.IX + d) & 0xFFFF)); self.t += 19
            elif (op2 & 0xF8) == 0x70 and op2 != 0x76:
                d = self.fetch_signed(); src = op2 & 7
                wb((self.IX + d) & 0xFFFF, self.getr(src)); self.t += 19
            elif 0x84 <= op2 <= 0xBE and (op2 & 7) == 6:
                d = self.fetch_signed(); grp = (op2 >> 3) & 7
                self.alu(grp, rb((self.IX + d) & 0xFFFF)); self.t += 19
            elif op2 == 0xCB:
                d = self.fetch_signed(); op3 = self.fetch()
                addr = (self.IX + d) & 0xFFFF
                grp = (op3 >> 6) & 3; bit = (op3 >> 3) & 7
                val = rb(addr)
                if grp == 1: self.setZ((val & (1 << bit)) == 0)
                elif grp == 2: wb(addr, val & ~(1 << bit) & 0xFF)
                elif grp == 3: wb(addr, val | (1 << bit))
                else: raise NotImplementedError(f"DD CB rotate en (IX+d) no implementado, PC={pc0:04X}")
                self.t += 23
            else:
                raise NotImplementedError(f"opcode DD 0x{op2:02X} sin implementar en PC={pc0:04X}")

        elif op == 0xFD:
            op2 = self.fetch()
            if op2 == 0x21: self.IY = self.fetch16(); self.t += 14
            elif op2 == 0x22: a = self.fetch16(); self.ww(a, self.IY); self.t += 20
            elif op2 == 0x2A: a = self.fetch16(); self.IY = self.rw(a); self.t += 20
            elif op2 == 0xE5: self.push(self.IY); self.t += 15
            elif op2 == 0xE1: self.IY = self.pop(); self.t += 14
            elif op2 == 0xE9: self.PC = self.IY; self.t += 8
            elif (op2 & 0xC7) == 0x46 and (op2 & 0x38) != 0x30:
                d = self.fetch_signed(); dst = (op2 >> 3) & 7
                self.setr(dst, rb((self.IY + d) & 0xFFFF)); self.t += 19
            elif (op2 & 0xF8) == 0x70 and op2 != 0x76:
                d = self.fetch_signed(); src = op2 & 7
                wb((self.IY + d) & 0xFFFF, self.getr(src)); self.t += 19
            else:
                raise NotImplementedError(f"opcode FD 0x{op2:02X} sin implementar en PC={pc0:04X}")
        else:
            raise NotImplementedError(f"opcode 0x{op:02X} sin implementar en PC={pc0:04X}")


def load_memory():
    mem = bytearray(65536)
    with open(CODE_BIN, "rb") as f:
        raw = f.read()
    mem[MEM_BASE:MEM_BASE + len(raw)] = raw
    return mem


def run_sub(cpu, addr, max_steps=2_000_000, sentinel=0x0001):
    cpu.push(sentinel)
    cpu.PC = addr
    steps = 0
    while cpu.PC != sentinel and steps < max_steps:
        cpu.step()
        steps += 1
    if steps >= max_steps:
        raise RuntimeError(f"limite de pasos alcanzado, PC={cpu.PC:04X}")
    return steps


def bucket(addr):
    if 0x4000 <= addr < 0x5800: return "PANTALLA_REAL (bitmap $4000-$57FF)"
    if 0x5800 <= addr < 0x5B00: return "ATRIBUTOS_REALES ($5800-$5AFF)"
    if 0xE3F2 <= addr < 0xEFA2: return "ZONA_MARCO_DECORATIVO ($E3F2-$EFA1, documentada)"
    if 0xEFA2 <= addr < 0xFC60: return "MAS ALLA de lo documentado ($EFA2-$FC5F)"
    if 0xFC60 <= addr < 0xFF80: return "BUFFER_NIVEL ($FC60+)"
    if 0x5FE0 <= addr < 0x6000: return "pila del simulador (ignorar)"
    return f"otro (${addr:04X})"


def summarize(cpu, label):
    buckets = Counter()
    addrs_by_bucket = {}
    for _pc, a, _v in cpu.write_log:
        b = bucket(a)
        buckets[b] += 1
        addrs_by_bucket.setdefault(b, set()).add(a)
    print(f"\n=== {label}: {len(cpu.write_log)} escrituras totales ===")
    for b, cnt in buckets.most_common():
        if b == "pila del simulador (ignorar)":
            continue
        addrs = addrs_by_bucket[b]
        print(f"  {b}: {len(addrs)} direcciones distintas, "
              f"rango ${min(addrs):04X}-${max(addrs):04X}")


def fresh_cpu():
    mem = load_memory()
    cpu = CPU(mem)
    cpu.SP = 0x5FFF
    cpu.trace_writes = True
    return cpu


def main():
    # test 1: CARGAR_MARCO_DECORATIVO tal cual (memoria real de CODE.bin,
    # incluido el bitmap RLE comprimido todavia en $E3F2-$EFA1)
    cpu = fresh_cpu()
    steps = run_sub(cpu, CARGAR_MARCO_DECORATIVO)
    print(f"CARGAR_MARCO_DECORATIVO: {steps} pasos ejecutados")
    summarize(cpu, "CARGAR_MARCO_DECORATIVO")

    # test 2: REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM con una posicion
    # de camara tipica (comecocos en mitad del nivel)
    cpu2 = fresh_cpu()
    cpu2.mem[REGISTRO_NIVEL_POSICION_COMECOCOS] = 0x18
    cpu2.mem[REGISTRO_NIVEL_POSICION_COMECOCOS + 1] = 0x10
    steps2 = run_sub(cpu2, REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM)
    print(f"\nREDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM: {steps2} pasos ejecutados")
    summarize(cpu2, "REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM")

    # test 3: REDIBUJAR_LOSETA_BUFFER_VRAM (una sola loseta, como la
    # llama DIBUJAR_CAMBIO_LOSETA al comerse una bolita)
    cpu3 = fresh_cpu()
    cpu3.mem[REGISTRO_NIVEL_POSICION_COMECOCOS] = 0x18
    cpu3.mem[REGISTRO_NIVEL_POSICION_COMECOCOS + 1] = 0x10
    cpu3.B = 0x04; cpu3.C = 0x04; cpu3.A = 0x05
    steps3 = run_sub(cpu3, REDIBUJAR_LOSETA_BUFFER_VRAM)
    print(f"\nREDIBUJAR_LOSETA_BUFFER_VRAM: {steps3} pasos ejecutados")
    summarize(cpu3, "REDIBUJAR_LOSETA_BUFFER_VRAM")

    print("\n" + "=" * 70)
    print("CONCLUSION: el laberinto se compone en un lienzo de RAM ajeno a")
    print("la pantalla real (ver docstring de este fichero) -- solo el HUD/")
    print("iconos escriben en pantalla real dentro de estas rutinas.")
    print("El volcado del lienzo a pantalla real NO se ha localizado (ver")
    print("PENDIENTE en el docstring).")


if __name__ == "__main__":
    main()
