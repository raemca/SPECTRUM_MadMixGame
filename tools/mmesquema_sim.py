#!/usr/bin/env python3
"""
mmesquema_sim.py -- simulador Z80 minimo (misma filosofia que
mmsnd_render.py: ejecutar el CODIGO ORIGINAL de verdad en vez de
razonarlo a mano) para verificar PREPARAR_TABLA_ESQUEMA_COLOR y
BUCLE_MEZCLA_ESQUEMA_COLOR (antes CODE_954E/CODE_95FB), el
intercambio de registros via SP/PUSH/POP/EXX dentro de
REFRESCAR_ESQUEMA_COLOR_NIVEL (ver src/madmix_body.asm, $95B0).

Motivo: razonar esa rutina a mano (algebra de bits instruccion a
instruccion) llevaba a hipotesis contradictorias sobre si camina una
lista enlazada real, que direcciones toca y si se estabiliza -- la
unica forma de saberlo con certeza es correr el codigo real sobre una
copia real de memoria (FISICO/CODE.bin) y observar. Ver FINDINGS.md
sesion 56 para el hallazgo completo.

Uso:
  py mmesquema_sim.py

No es un emulador Z80 general: implementa solo los opcodes que
aparecen en PREPARAR_TABLA_ESQUEMA_COLOR, REFRESCAR_ESQUEMA_COLOR_NIVEL,
BUCLE_MEZCLA_ESQUEMA_COLOR y CALCULAR_DIRECCION_PANTALLA -- levanta
excepcion ante cualquier otro opcode, a proposito.

Autor de esta herramienta: Rafael Eduardo Martín Candial (raemca@hotmail.com)
"""
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")
CODE_BIN = os.path.join(ROOT, "FISICO", "CODE.bin")
MEM_BASE = 0x6000

PREPARAR_TABLA_ESQUEMA_COLOR = 0x954E
REFRESCAR_ESQUEMA_COLOR_NIVEL = 0x95B0
BUCLE_MEZCLA_ESQUEMA_COLOR = 0x95FB
REGISTRO_NIVEL_ICONO_HUD = 0x6018
COLOR_ACTUAL = 0x6037


class CPU:
    """Simulador Z80 minimo (subconjunto de opcodes usado por
    PREPARAR_TABLA_ESQUEMA_COLOR/REFRESCAR_ESQUEMA_COLOR_NIVEL/
    BUCLE_MEZCLA_ESQUEMA_COLOR/CALCULAR_DIRECCION_PANTALLA)."""

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
        self.SP = 0x5FFF
        self.PC = 0
        self.IFF = True
        self.t = 0
        self.write_log = []  # (pc, addr, val), solo si trace_writes
        self.trace_writes = False

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

    def setZ(self, v):
        self.F = (self.F | 0x40) if v else (self.F & ~0x40)
    def getZ(self): return bool(self.F & 0x40)
    def setC(self, v):
        self.F = (self.F | 0x01) if v else (self.F & ~0x01)
    def getC(self): return bool(self.F & 0x01)

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

    def step(self):
        pc0 = self.PC
        op = self.fetch()
        rb, wb = self.rb, self.wb
        if op == 0xC5: self.push(self.BC()); self.t += 11
        elif op == 0xD5: self.push(self.DE()); self.t += 11
        elif op == 0xE5: self.push(self.HL()); self.t += 11
        elif op == 0xF5: self.push((self.A << 8) | self.F); self.t += 11
        elif op == 0xC1: self.setBC(self.pop()); self.t += 10
        elif op == 0xD1: self.setDE(self.pop()); self.t += 10
        elif op == 0xE1: self.setHL(self.pop()); self.t += 10
        elif op == 0xF1:
            v = self.pop(); self.A = v >> 8; self.F = v & 0xFF; self.t += 10
        elif op == 0xDD and rb(self.PC) == 0xE1: self.fetch(); self.IX = self.pop(); self.t += 14
        elif op == 0xDD and rb(self.PC) == 0xF9: self.fetch(); self.SP = self.IX; self.t += 10
        elif op == 0xDD and rb(self.PC) == 0x7C: self.fetch(); self.A = (self.IX >> 8) & 0xFF; self.t += 8
        elif op == 0xDD and rb(self.PC) == 0x21:
            self.fetch(); self.IX = self.fetch() | (self.fetch() << 8); self.t += 14
        elif op == 0xF9: self.SP = self.HL(); self.t += 6
        elif op == 0xD9:  # EXX
            self.B, self.B_ = self.B_, self.B
            self.C, self.C_ = self.C_, self.C
            self.D, self.D_ = self.D_, self.D
            self.E, self.E_ = self.E_, self.E
            self.H, self.H_ = self.H_, self.H
            self.L, self.L_ = self.L_, self.L
            self.t += 4
        elif op == 0xEB:  # EX DE,HL
            de, hl = self.DE(), self.HL()
            self.setDE(hl); self.setHL(de); self.t += 4
        elif op == 0x3E: self.A = self.fetch(); self.t += 7
        elif op == 0x3A:
            a = self.fetch() | (self.fetch() << 8); self.A = rb(a); self.t += 13
        elif op == 0x21: self.setHL(self.fetch() | (self.fetch() << 8)); self.t += 10
        elif op == 0x11: self.setDE(self.fetch() | (self.fetch() << 8)); self.t += 10
        elif op == 0x01: self.setBC(self.fetch() | (self.fetch() << 8)); self.t += 10
        elif op == 0x36: n = self.fetch(); wb(self.HL(), n); self.t += 10
        elif op == 0xED and rb(self.PC) == 0x73:
            self.fetch(); a = self.fetch() | (self.fetch() << 8); self.ww(a, self.SP); self.t += 20
        elif op == 0xED and rb(self.PC) == 0x7B:
            self.fetch(); a = self.fetch() | (self.fetch() << 8); self.SP = self.rw(a); self.t += 20
        elif op == 0xED and rb(self.PC) == 0xB0:  # LDIR
            self.fetch()
            while self.BC() != 0:
                wb(self.DE(), rb(self.HL()))
                self.setHL((self.HL() + 1) & 0xFFFF)
                self.setDE((self.DE() + 1) & 0xFFFF)
                self.setBC((self.BC() - 1) & 0xFFFF)
                self.t += 21
        elif op == 0xE6: self.A &= self.fetch(); self.setZ(self.A == 0); self.t += 7
        elif op == 0xFE:
            n = self.fetch(); self.setZ(self.A == n); self.setC(self.A < n); self.t += 7
        elif op == 0x3D: self.A = (self.A - 1) & 0xFF; self.setZ(self.A == 0); self.t += 4
        elif op == 0x04: self.B = (self.B + 1) & 0xFF; self.setZ(self.B == 0); self.t += 4
        elif op == 0x23: self.setHL((self.HL() + 1) & 0xFFFF); self.t += 6
        elif op == 0x2B: self.setHL((self.HL() - 1) & 0xFFFF); self.t += 6
        elif op == 0x13: self.setDE((self.DE() + 1) & 0xFFFF); self.t += 6
        elif op == 0x1F:  # RRA
            oc = 1 if self.getC() else 0
            self.setC(self.A & 1)
            self.A = ((self.A >> 1) | (oc << 7)) & 0xFF
            self.t += 4
        elif op == 0x37: self.setC(True); self.t += 4  # SCF
        elif op == 0x09: self.setHL((self.HL() + self.BC()) & 0xFFFF); self.t += 11
        elif op == 0x19: self.setHL((self.HL() + self.DE()) & 0xFFFF); self.t += 11
        elif op == 0x20:
            d = self.fetch()
            if d >= 128: d -= 256
            if not self.getZ(): self.PC = (self.PC + d) & 0xFFFF; self.t += 12
            else: self.t += 7
        elif op == 0xC2:
            a = self.fetch() | (self.fetch() << 8)
            if not self.getZ(): self.PC = a
            self.t += 10
        elif op == 0xCD:
            a = self.fetch() | (self.fetch() << 8); self.push(self.PC); self.PC = a; self.t += 17
        elif op == 0xC9: self.PC = self.pop(); self.t += 10
        elif op == 0x07: self.A = ((self.A << 1) | (self.A >> 7)) & 0xFF; self.t += 4  # RLCA
        elif op == 0xD3: self.fetch(); self.t += 11  # OUT (n),A -- puerto ignorado
        elif op == 0x06: self.B = self.fetch(); self.t += 7
        elif op == 0x0E: self.C = self.fetch(); self.t += 7
        elif op == 0x10:
            d = self.fetch()
            if d >= 128: d -= 256
            self.B = (self.B - 1) & 0xFF
            if self.B != 0: self.PC = (self.PC + d) & 0xFFFF; self.t += 13
            else: self.t += 8
        elif 0x80 <= op <= 0xBF:  # ALU A,r (incluye AND A, XOR B, etc.)
            regnames = ['B', 'C', 'D', 'E', 'H', 'L', None, 'A']
            src = op & 7; grp = (op >> 3) & 7
            if src == 6: val = rb(self.HL()); self.t += 7
            else: val = getattr(self, regnames[src]); self.t += 4
            if grp == 4: self.A &= val
            elif grp == 5: self.A ^= val
            else: raise NotImplementedError(f"grupo ALU 0x{op:02X} sin implementar en PC={pc0:04X}")
            self.setZ(self.A == 0)
        elif 0x40 <= op <= 0x7F and op != 0x76:  # LD r,r' (incluye LD (HL),r y LD r,(HL))
            regnames = ['B', 'C', 'D', 'E', 'H', 'L', None, 'A']
            dst = (op >> 3) & 7; src = op & 7
            if src == 6: val = rb(self.HL()); self.t += 7
            else: val = getattr(self, regnames[src]); self.t += 4
            if dst == 6: wb(self.HL(), val)
            else: setattr(self, regnames[dst], val)
        else:
            raise NotImplementedError(f"opcode 0x{op:02X} sin implementar en PC={pc0:04X}")


def load_memory():
    mem = bytearray(65536)
    with open(CODE_BIN, "rb") as f:
        raw = f.read()
    mem[MEM_BASE:MEM_BASE + len(raw)] = raw
    return mem


def run_sub(cpu, addr, max_steps=500_000):
    """Ejecuta CALL addr (empuja un centinela $0000 como direccion de
    retorno) hasta que la subrutina hace RET."""
    cpu.push(0x0000)
    cpu.PC = addr
    steps = 0
    while cpu.PC != 0x0000 and steps < max_steps:
        cpu.step()
        steps += 1
    if steps >= max_steps:
        raise RuntimeError(f"limite de pasos alcanzado, PC={cpu.PC:04X}")
    return steps


def main():
    mem = load_memory()
    cpu = CPU(mem)
    cpu.SP = 0x5FFF

    # Fase 1: PREPARAR_TABLA_ESQUEMA_COLOR, tal como la llama INICIO
    # una sola vez, justo despues de CARGAR_MARCO_DECORATIVO -- con la
    # memoria REAL de CODE.bin ya cargada (incluye el bitmap del marco
    # decorativo todavia en $E3F2-$EFA1, que es la memoria que esta
    # rutina recicla).
    steps = run_sub(cpu, PREPARAR_TABLA_ESQUEMA_COLOR)
    print(f"PREPARAR_TABLA_ESQUEMA_COLOR: {steps} pasos ejecutados")

    print("\nPrimeras 6 filas de la tabla (paso 31 bytes desde $E400):")
    for k in range(6):
        base = 0xE400 + 31 * k
        addr_col16 = mem[base] | (mem[base + 1] << 8)
        chain = mem[base + 2] | (mem[base + 3] << 8)
        print(f"  fila {16 + k}: base={base:04X}  direccion_col16={addr_col16:04X}  encadenado={chain:04X}")

    # Fase 2: REFRESCAR_ESQUEMA_COLOR_NIVEL completa, varias veces
    # seguidas (como pasaria de verdad, una vez por interrupcion
    # relevante via TICK_REDIBUJADO_VBLANK), para ver si el numero de
    # iteraciones y la secuencia de IX del bucle se estabilizan.
    mem[REGISTRO_NIVEL_ICONO_HUD] = 0x07
    mem[COLOR_ACTUAL] = 0x42

    orig_wb = cpu.wb
    def traced_wb(a, v):
        if BUCLE_MEZCLA_ESQUEMA_COLOR <= cpu.PC < 0x9656:
            cpu.write_log.append((cpu.PC, a & 0xFFFF, v & 0xFF))
        return orig_wb(a, v)
    cpu.wb = traced_wb

    iter_log = []
    orig_step = cpu.step
    def traced_step():
        if cpu.PC == BUCLE_MEZCLA_ESQUEMA_COLOR:
            iter_log.append(cpu.IX)
        return orig_step()
    cpu.step = traced_step

    print("\nFotogramas sucesivos de REFRESCAR_ESQUEMA_COLOR_NIVEL "
          "(sin reconstruir la tabla, como en el juego real):")
    for frame in range(1, 6):
        iter_log.clear()
        steps = run_sub(cpu, REFRESCAR_ESQUEMA_COLOR_NIVEL)
        rango = f"{iter_log[0]:04X}..{iter_log[-1]:04X}" if iter_log else "-"
        print(f"  frame {frame}: {steps} pasos, {len(iter_log)} iteraciones "
              f"del bucle, IX {rango}")

    addrs = sorted(set(a for (_pc, a, _v) in cpu.write_log))
    bitmap = [a for a in addrs if 0x4000 <= a < 0x5800]
    print(f"\nDirecciones distintas escritas por BUCLE_MEZCLA_ESQUEMA_COLOR "
          f"en todos los fotogramas: {len(addrs)}")
    print(f"  de ellas, en el bitmap de pantalla real ($4000-$57FF): "
          f"{len(bitmap)}" + (f" -> {[hex(x) for x in bitmap]}" if bitmap else ""))


if __name__ == "__main__":
    main()
