#!/usr/bin/env python3
"""Write a 4 s, 440 Hz, stereo, 48 kHz, 16-bit test tone (no dependencies beyond the stdlib)."""
import math, struct, sys, wave

out = sys.argv[1] if len(sys.argv) > 1 else "tone.wav"
rate, secs, freq, amp = 48000, 4, 440.0, 0.3
frames = bytearray()
for n in range(rate * secs):
    v = int(amp * 32767 * math.sin(2 * math.pi * freq * n / rate))
    frames += struct.pack("<hh", v, v)
with wave.open(out, "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(rate); w.writeframes(bytes(frames))
print(f"wrote {out}")
