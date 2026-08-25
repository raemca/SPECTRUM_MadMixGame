#!/usr/bin/env python3
"""
mmsnd_render.py -- renderiza guiones de sonido (data/sound/snd/*.snd,
data/sound/spt/*.spt) a WAV.

A diferencia de la herramienta homonima de MSX (que REIMPLEMENTA la
logica del reproductor a mano en Python), esta ejecuta el CODIGO
ORIGINAL: un simulador Z80 minimo (solo los ~40 opcodes que aparecen
en el motor, $E038-$E37F) corre sobre una copia real de la memoria
(FISICO/CODE.bin), con interrupciones simuladas a 50 Hz, y registra
cada OUT ($FE),A real para reconstruir la forma de onda. Se eligio
este enfoque porque razonar el mecanismo a mano llevo a una
conclusion incorrecta (ver FINDINGS.md sesion 56): el bucle de tono
usa codigo automodificable de una forma facil de pasar por alto
leyendo el listado; ejecutarlo de verdad evita ese tipo de error.

Bit de audio: se toma el bit 4 de cada valor escrito en el puerto
$FE (el bit de altavoz real del 48K); el resto de bits (borde, MIC)
se ignoran para el audio.

Uso:
  py mmsnd_render.py render fichero.snd salida.wav [--channel A|B]
  py mmsnd_render.py render-pair canalA.snd canalB.snd salida.wav
  py mmsnd_render.py render-all carpeta/ salida_carpeta/

Opciones comunes:
  --rate HZ       frecuencia de muestreo del WAV (defecto 44100)
  --tickhz HZ     tasa de interrupcion del motor (defecto 50, PAL)
  --max-ticks N   limite de seguridad en ticks de 1/tickhz s (defecto 200)
  --clock HZ      reloj del Z80 (defecto 3500000)

Autor de esta herramienta: Rafael Eduardo Martín Candial (raemca@hotmail.com)
"""

import sys
import os
import re
import wave
import bisect

ROOT = os.path.join(os.path.dirname(__file__), "..")
CODE_BIN = os.path.join(ROOT, "FISICO", "CODE.bin")
MEM_BASE = 0x6000

REPRODUCIR_SONIDO = 0xE1F9
PUNTERO_CANAL_A = 0xE212
PUNTERO_CANAL_B = 0xE216
IM2_VECTOR = 0x6061
FLAG_ESTADO_SONIDO = 0xE2AA
# Guiones "vacios" para el canal que no se renderiza. IMPORTANTE: canal A
# usa $FF ("END") para poner FLAG_ESTADO_SONIDO=2, que hace que
# BUCLE_TONO_CANAL_A llame a DETENER_SONIDO y pare el motor entero -- si
# se usara $FF para silenciar canal A, el motor se apagaria antes de que
# canal B llegase a sonar. Por eso el canal A "vacio" es una tirada larga
# de $FE (RESET, no termina nada, solo reinicia la duracion) en vez de un
# $FF. Canal B en cambio SI puede silenciarse con un $FF sencillo: su fin
# solo devuelve de la interrupcion (FIN_ISR_SONIDO), no para el motor.
SILENCIO_CANAL_B = 0xFFFF  # 1 byte $FF
SILENCIO_CANAL_A = 0xFF00  # 255 bytes $FE (cubre max-ticks por defecto de sobra)


# ---------------------------------------------------------------- CPU

class CPU:
    """Simulador Z80 minimo: solo los opcodes usados por ISR_SONIDO/
    REPRODUCIR_SONIDO y sus rutinas (E038-E37F). No es un emulador
    Z80 general -- levanta excepcion ante cualquier opcode no
    contemplado, a proposito, para no fingir precision que no tiene."""

    def __init__(self, mem):
        self.mem = mem
        self.A = 0; self.F = 0
        self.B = 0; self.C = 0
        self.D = 0; self.E = 0
        self.H = 0; self.L = 0
        self.A_ = 0; self.F_ = 0
        self.IX = 0; self.IY = 0
        self.SP = 0x5FFF
        self.PC = 0
        self.IFF = True
        self.t = 0
        self.out_log = []  # (t_states, value)

    def rb(self, a): return self.mem[a & 0xFFFF]
    def wb(self, a, v): self.mem[a & 0xFFFF] = v & 0xFF
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

    def interrupt(self, im2_vector_addr):
        if self.IFF:
            target = self.rw(im2_vector_addr)
            self.push(self.PC)
            self.PC = target
            self.IFF = False
            self.t += 13

    def step(self):
        pc0 = self.PC
        op = self.fetch()
        rb, wb = self.rb, self.wb
        if op == 0xF3: self.IFF = False; self.t += 4  # DI
        elif op == 0xFB: self.IFF = True; self.t += 4  # EI
        elif op == 0xC5: self.push(self.BC()); self.t += 11
        elif op == 0xD5: self.push(self.DE()); self.t += 11
        elif op == 0xE5: self.push(self.HL()); self.t += 11
        elif op == 0xF5: self.push((self.A << 8) | self.F); self.t += 11
        elif op == 0xC1: self.setBC(self.pop()); self.t += 10
        elif op == 0xD1: self.setDE(self.pop()); self.t += 10
        elif op == 0xE1: self.setHL(self.pop()); self.t += 10
        elif op == 0xF1:
            v = self.pop(); self.A = v >> 8; self.F = v & 0xFF; self.t += 10
        elif op == 0xDD and rb(self.PC) == 0xE5: self.fetch(); self.push(self.IX); self.t += 15
        elif op == 0xDD and rb(self.PC) == 0xE1: self.fetch(); self.IX = self.pop(); self.t += 14
        elif op == 0xFD and rb(self.PC) == 0xE5: self.fetch(); self.push(self.IY); self.t += 15
        elif op == 0xFD and rb(self.PC) == 0xE1: self.fetch(); self.IY = self.pop(); self.t += 14
        elif op == 0x3E: self.A = self.fetch(); self.t += 7
        elif op == 0x3A:
            a = self.fetch() | (self.fetch() << 8); self.A = rb(a); self.t += 13
        elif op == 0x32:
            a = self.fetch() | (self.fetch() << 8); wb(a, self.A); self.t += 13
        elif op == 0x21: self.setHL(self.fetch() | (self.fetch() << 8)); self.t += 10
        elif op == 0x11: self.setDE(self.fetch() | (self.fetch() << 8)); self.t += 10
        elif op == 0x01: self.setBC(self.fetch() | (self.fetch() << 8)); self.t += 10
        elif op == 0xDD and rb(self.PC) == 0x21:
            self.fetch(); self.IX = self.fetch() | (self.fetch() << 8); self.t += 14
        elif op == 0xFD and rb(self.PC) == 0x21:
            self.fetch(); self.IY = self.fetch() | (self.fetch() << 8); self.t += 14
        elif op == 0x22:
            a = self.fetch() | (self.fetch() << 8); self.ww(a, self.HL()); self.t += 16
        elif op == 0x2A:
            a = self.fetch() | (self.fetch() << 8); self.setHL(self.rw(a)); self.t += 16
        elif op == 0xED and rb(self.PC) == 0x53:
            self.fetch(); a = self.fetch() | (self.fetch() << 8); self.ww(a, self.DE()); self.t += 20
        elif op == 0xED and rb(self.PC) == 0x43:
            self.fetch(); a = self.fetch() | (self.fetch() << 8); self.ww(a, self.BC()); self.t += 20
        elif op == 0xED and rb(self.PC) == 0x73:
            self.fetch(); a = self.fetch() | (self.fetch() << 8); self.ww(a, self.SP); self.t += 20
        elif op == 0xED and rb(self.PC) == 0x7B:
            self.fetch(); a = self.fetch() | (self.fetch() << 8); self.SP = self.rw(a); self.t += 20
        elif op == 0xED and rb(self.PC) == 0x4D:
            self.fetch(); self.PC = self.pop(); self.t += 14  # RETI
        elif op == 0xED and rb(self.PC) == 0xB0:  # LDIR
            self.fetch()
            while self.BC() != 0:
                wb(self.DE(), rb(self.HL()))
                self.setHL((self.HL() + 1) & 0xFFFF)
                self.setDE((self.DE() + 1) & 0xFFFF)
                self.setBC((self.BC() - 1) & 0xFFFF)
                self.t += 21
        elif op == 0xDD and rb(self.PC) == 0x7E:
            self.fetch(); self.fetch(); self.A = rb(self.IX); self.t += 19
        elif op == 0xDD and rb(self.PC) == 0x6E:
            self.fetch(); self.fetch(); self.L = rb(self.IX); self.t += 19
        elif op == 0xDD and rb(self.PC) == 0x66:
            self.fetch(); self.fetch(); self.H = rb(self.IX); self.t += 19
        elif op == 0xFD and rb(self.PC) == 0x7E:
            self.fetch(); self.fetch(); self.A = rb(self.IY); self.t += 19
        elif op == 0xFD and rb(self.PC) == 0x6E:
            self.fetch(); self.fetch(); self.L = rb(self.IY); self.t += 19
        elif op == 0xFD and rb(self.PC) == 0x66:
            self.fetch(); self.fetch(); self.H = rb(self.IY); self.t += 19
        elif op == 0xDD and rb(self.PC) == 0x23:
            self.fetch(); self.IX = (self.IX + 1) & 0xFFFF; self.t += 10
        elif op == 0xFD and rb(self.PC) == 0x23:
            self.fetch(); self.IY = (self.IY + 1) & 0xFFFF; self.t += 10
        elif op == 0xB7: self.setZ(self.A == 0); self.t += 4  # OR A
        elif op == 0xF6: self.A |= self.fetch(); self.setZ(self.A == 0); self.t += 7
        elif op == 0xE6: self.A &= self.fetch(); self.setZ(self.A == 0); self.t += 7
        elif op == 0xEE: self.A ^= self.fetch(); self.setZ(self.A == 0); self.t += 7
        elif op == 0xAF: self.A = 0; self.setZ(True); self.t += 4  # XOR A
        elif op == 0xFE:
            n = self.fetch(); self.setZ(self.A == n); self.setC(self.A < n); self.t += 7
        elif op == 0x3D: self.A = (self.A - 1) & 0xFF; self.setZ(self.A == 0); self.t += 4
        elif op == 0x3C: self.A = (self.A + 1) & 0xFF; self.setZ(self.A == 0); self.t += 4
        elif op == 0x0B: self.setBC((self.BC() - 1) & 0xFFFF); self.t += 6
        elif op == 0x1B: self.setDE((self.DE() - 1) & 0xFFFF); self.t += 6
        elif op == 0x1D: self.E = (self.E - 1) & 0xFF; self.setZ(self.E == 0); self.t += 4
        elif op == 0x23: self.setHL((self.HL() + 1) & 0xFFFF); self.t += 6
        elif op == 0xC6: self.A = (self.A + self.fetch()) & 0xFF; self.t += 7
        elif op == 0x09: self.setHL((self.HL() + self.BC()) & 0xFFFF); self.t += 11
        elif op == 0x19: self.setHL((self.HL() + self.DE()) & 0xFFFF); self.t += 11
        elif op == 0x29: self.setHL((self.HL() + self.HL()) & 0xFFFF); self.t += 11
        elif op == 0x18:
            d = self.fetch()
            if d >= 128: d -= 256
            self.PC = (self.PC + d) & 0xFFFF; self.t += 12
        elif op == 0x20:
            d = self.fetch()
            if d >= 128: d -= 256
            if not self.getZ(): self.PC = (self.PC + d) & 0xFFFF; self.t += 12
            else: self.t += 7
        elif op == 0x28:
            d = self.fetch()
            if d >= 128: d -= 256
            if self.getZ(): self.PC = (self.PC + d) & 0xFFFF; self.t += 12
            else: self.t += 7
        elif op == 0xC3: self.PC = self.fetch() | (self.fetch() << 8); self.t += 10
        elif op == 0xC2:
            a = self.fetch() | (self.fetch() << 8)
            if not self.getZ(): self.PC = a
            self.t += 10
        elif op == 0xCA:
            a = self.fetch() | (self.fetch() << 8)
            if self.getZ(): self.PC = a
            self.t += 10
        elif op == 0xE9: self.PC = self.HL(); self.t += 4  # JP (HL)
        elif op == 0xCD:
            a = self.fetch() | (self.fetch() << 8); self.push(self.PC); self.PC = a; self.t += 17
        elif op == 0xC9: self.PC = self.pop(); self.t += 10
        elif op == 0x10:
            d = self.fetch()
            if d >= 128: d -= 256
            self.B = (self.B - 1) & 0xFF
            if self.B != 0: self.PC = (self.PC + d) & 0xFFFF; self.t += 13
            else: self.t += 8
        elif op == 0x08:  # EX AF,AF'
            self.A, self.A_ = self.A_, self.A
            self.F, self.F_ = self.F_, self.F
            self.t += 4
        elif op == 0x07: self.A = ((self.A << 1) | (self.A >> 7)) & 0xFF; self.t += 4  # RLCA
        elif op == 0xCB and rb(self.PC) == 0x09:
            self.fetch(); c0 = self.C & 1; self.C = ((self.C >> 1) | (c0 << 7)) & 0xFF; self.t += 8
        elif op == 0xCB and rb(self.PC) == 0x3A:  # SRL D
            self.fetch(); self.setC(self.D & 1); self.D = (self.D >> 1) & 0xFF; self.t += 8
        elif op == 0xCB and rb(self.PC) == 0x1B:  # RR E
            self.fetch()
            oc = self.getC(); self.setC(self.E & 1)
            self.E = ((self.E >> 1) | (0x80 if oc else 0)) & 0xFF; self.t += 8
        elif op == 0xDB: self.fetch(); self.A = 0xFF; self.t += 11  # IN A,(n): sin tecla pulsada
        elif op == 0x06: self.B = self.fetch(); self.t += 7
        elif op == 0x0E: self.C = self.fetch(); self.t += 7
        elif op == 0x16: self.D = self.fetch(); self.t += 7
        elif op == 0x1E: self.E = self.fetch(); self.t += 7
        elif op == 0x26: self.H = self.fetch(); self.t += 7
        elif op == 0x2E: self.L = self.fetch(); self.t += 7
        elif op == 0xD3:
            self.fetch(); self.out_log.append((self.t, self.A)); self.t += 11
        elif 0x80 <= op <= 0xBF:
            regnames = ['B', 'C', 'D', 'E', 'H', 'L', None, 'A']
            src = op & 7; grp = (op >> 3) & 7
            if src == 6: val = rb(self.HL()); self.t += 7
            else: val = getattr(self, regnames[src]); self.t += 4
            if grp == 0: self.A = (self.A + val) & 0xFF
            elif grp == 1: self.A = (self.A + val + (1 if self.getC() else 0)) & 0xFF
            elif grp == 2: self.A = (self.A - val) & 0xFF
            elif grp == 3: self.A = (self.A - val - (1 if self.getC() else 0)) & 0xFF
            elif grp == 4: self.A &= val
            elif grp == 5: self.A ^= val
            elif grp == 6: self.A |= val
            elif grp == 7:
                self.setZ(self.A == val); self.setC(self.A < val); return
            self.setZ(self.A == 0)
        elif 0x40 <= op <= 0x7F and op != 0x76:
            regnames = ['B', 'C', 'D', 'E', 'H', 'L', None, 'A']
            dst = (op >> 3) & 7; src = op & 7
            if src == 6: val = rb(self.HL()); self.t += 7
            else: val = getattr(self, regnames[src]); self.t += 4
            if dst == 6: wb(self.HL(), val)
            else: setattr(self, regnames[dst], val)
        else:
            raise NotImplementedError(f"opcode 0x{op:02X} sin implementar en PC={pc0:04X}")


# ------------------------------------------------------------- memoria

def load_memory():
    mem = bytearray(65536)
    with open(CODE_BIN, "rb") as f:
        raw = f.read()
    mem[MEM_BASE:MEM_BASE + len(raw)] = raw
    mem[SILENCIO_CANAL_B] = 0xFF
    for i in range(254):  # no llega a pisar SILENCIO_CANAL_B en $FFFF
        mem[SILENCIO_CANAL_A + i] = 0xFE
    return mem


ADDR_RE = re.compile(r"_([0-9a-fA-F]{4})\.(snd|spt|bin|txt)$")


def addr_from_filename(path):
    m = ADDR_RE.search(os.path.basename(path))
    if not m:
        raise ValueError(f"no se pudo extraer la direccion del nombre de fichero: {path}")
    return int(m.group(1), 16)


def channel_from_filename(path):
    name = os.path.basename(path)
    if "canalA" in name or re.search(r"_A_", name):
        return "A"
    if "canalB" in name or re.search(r"_B_", name):
        return "B"
    return None


def load_script_bytes(path):
    if path.endswith(".txt"):
        sys.path.insert(0, os.path.dirname(__file__))
        import mmsnd_tool
        with open(path, encoding="utf-8") as f:
            return mmsnd_tool.assemble(f.read())
    with open(path, "rb") as f:
        return f.read()


# --------------------------------------------------------- simulacion

def run(mem, addr_a, addr_b, tickhz, max_ticks, clock):
    cpu = CPU(mem)
    cpu.ww(PUNTERO_CANAL_A, addr_a)
    cpu.ww(PUNTERO_CANAL_B, addr_b)
    cpu.PC = REPRODUCIR_SONIDO
    cpu.SP = 0x5FFF
    cpu.push(0x0000)  # centinela de retorno falso

    int_period = clock // tickhz
    next_int = int_period
    max_t = max_ticks * int_period
    steps = 0
    max_steps = max_ticks * 20000  # cota de seguridad independiente del tiempo simulado

    while cpu.t < max_t and steps < max_steps:
        if cpu.PC == 0x0000:
            break
        cpu.step()
        steps += 1
        if cpu.t >= next_int:
            cpu.interrupt(IM2_VECTOR)
            next_int += int_period
        if mem[FLAG_ESTADO_SONIDO] == 2 and addr_b == SILENCIO_CANAL_B:
            break  # cancion de canal A terminada, y canal B esta silenciado
    return cpu


def render_samples(out_log, duration_t, rate, clock):
    """Reconstruye una onda cuadrada de un bit (bit4 del puerto $FE,
    el altavoz real del 48K) a partir de los eventos OUT registrados."""
    times = [t for t, _ in out_log]
    bits = [1 if (v & 0x10) else 0 for _, v in out_log]
    n_samples = int(duration_t / clock * rate)
    samples = bytearray(n_samples)
    level = 0
    idx = 0
    for i in range(n_samples):
        t_state = i * clock / rate
        while idx < len(times) and times[idx] <= t_state:
            level = bits[idx]
            idx += 1
        samples[i] = 200 if level else 56  # +-72 alrededor de 128, con margen
    return bytes(samples)


def write_wav(path, samples, rate):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(1)
        w.setframerate(rate)
        w.writeframes(samples)


# -------------------------------------------------------------- CLI

def cmd_render(args):
    opts, pos = _split_opts(args)
    snd_path, wav_path = pos
    rate = int(opts.get("--rate", 44100))
    tickhz = int(opts.get("--tickhz", 50))
    max_ticks = int(opts.get("--max-ticks", 200))
    clock = int(opts.get("--clock", 3500000))
    channel = opts.get("--channel") or channel_from_filename(snd_path) or "A"
    addr = addr_from_filename(snd_path)
    data = load_script_bytes(snd_path)

    mem = load_memory()
    mem[addr:addr + len(data)] = data
    if channel == "A":
        addr_a, addr_b = addr, SILENCIO_CANAL_B
    else:
        addr_a, addr_b = SILENCIO_CANAL_A, addr

    cpu = run(mem, addr_a, addr_b, tickhz, max_ticks, clock)
    samples = render_samples(cpu.out_log, cpu.t, rate, clock)
    write_wav(wav_path, samples, rate)
    dur = len(samples) / rate
    print(f"escrito {wav_path} ({dur:.2f}s, {len(cpu.out_log)} eventos OUT, canal {channel})")


def cmd_render_pair(args):
    opts, pos = _split_opts(args)
    a_path, b_path, wav_path = pos
    rate = int(opts.get("--rate", 44100))
    tickhz = int(opts.get("--tickhz", 50))
    max_ticks = int(opts.get("--max-ticks", 200))
    clock = int(opts.get("--clock", 3500000))

    addr_a = addr_from_filename(a_path)
    addr_b = addr_from_filename(b_path)
    data_a = load_script_bytes(a_path)
    data_b = load_script_bytes(b_path)

    mem = load_memory()
    mem[addr_a:addr_a + len(data_a)] = data_a
    mem[addr_b:addr_b + len(data_b)] = data_b

    cpu = run(mem, addr_a, addr_b, tickhz, max_ticks, clock)
    samples = render_samples(cpu.out_log, cpu.t, rate, clock)
    write_wav(wav_path, samples, rate)
    dur = len(samples) / rate
    print(f"escrito {wav_path} ({dur:.2f}s, {len(cpu.out_log)} eventos OUT, canales A+B)")


def cmd_render_all(args):
    opts, pos = _split_opts(args)
    folder, out_folder = pos
    os.makedirs(out_folder, exist_ok=True)
    exts = (".snd", ".spt")
    count = 0
    for name in sorted(os.listdir(folder)):
        if not name.endswith(exts):
            continue
        in_path = os.path.join(folder, name)
        out_path = os.path.join(out_folder, os.path.splitext(name)[0] + ".wav")
        try:
            cmd_render([in_path, out_path] + args[2:])
            count += 1
        except Exception as e:
            print(f"FALLO {name}: {e}")
    print(f"{count} ficheros renderizados")


def _split_opts(args):
    opts = {}
    pos = []
    i = 0
    while i < len(args):
        a = args[i]
        if a.startswith("--"):
            opts[a] = args[i + 1]
            i += 2
        else:
            pos.append(a)
            i += 1
    return opts, pos


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    cmd = sys.argv[1]
    args = sys.argv[2:]
    dispatch = {
        "render": cmd_render,
        "render-pair": cmd_render_pair,
        "render-all": cmd_render_all,
    }
    fn = dispatch.get(cmd)
    if fn is None:
        print(__doc__)
        sys.exit(1)
    fn(args)


if __name__ == "__main__":
    main()
