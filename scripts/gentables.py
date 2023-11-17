import argparse
import math

parser = argparse.ArgumentParser(prog="gentables", description="Generate lookup tables for DDS")
parser.add_argument("-p", dest="phase_bits", help="Phase bit width", required=True)
parser.add_argument("-w", dest="wf_bits", help="Waveform bit width", required=True)
args = parser.parse_args()

phase_bits = int(args.phase_bits)
wf_bits = int(args.wf_bits)
num_samples = 2**phase_bits 
max_ampl = 2**wf_bits - 1
format = f"%0{int(wf_bits/4)}x\n"

# Generate sine wave
f = open(f"sin-{phase_bits}-{wf_bits}.mem", "w")
with f:
    for i in range(num_samples):
        sample = int(math.sin((2 * math.pi * i) / num_samples) * (max_ampl / 2) + max_ampl / 2)
        f.write(format % sample)

# Generate triangle wave
f = open(f"tri-{phase_bits}-{wf_bits}.mem", "w")
scale = 2 * (max_ampl / num_samples)
with f:
    for i in range(0, int(num_samples / 4)):
        f.write(format % int(i * scale + max_ampl / 2))
    for i in range(0, int(num_samples / 2)):
        f.write(format % int(max_ampl - i * scale))
    for i in range(0, int(num_samples / 4)):
        f.write(format % int(i * scale))

    