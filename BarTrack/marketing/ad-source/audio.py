import numpy as np, wave
SR = 48000; DUR = 10.0
N = int(SR * DUR); mix = np.zeros((N, 2))
rng = np.random.default_rng(7)
def place(sig, t, gain=1.0, pan=0.0):
    i = int(t * SR); j = min(N, i + len(sig))
    if i >= N: return
    l, r = gain * (1 - max(0, pan)), gain * (1 + min(0, pan))
    mix[i:j, 0] += sig[:j - i] * l; mix[i:j, 1] += sig[:j - i] * r
def env(n, attack=0.002, decay=0.2):
    t = np.arange(n) / SR
    return np.minimum(1, t / attack) * np.exp(-t / decay)
def kick(level=1.0):
    n = int(0.45 * SR); t = np.arange(n) / SR
    f = 45 + 110 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    click = rng.standard_normal(n) * np.exp(-t * 400) * 0.25
    return (np.sin(ph) * np.exp(-t * 7) + click) * level
def hat():
    n = int(0.08 * SR); x = rng.standard_normal(n)
    x = np.diff(np.concatenate([[0], x]))  # crude high-pass
    return x * env(n, 0.001, 0.02) * 0.25
def blip(freq, dur=0.22):
    n = int(dur * SR); t = np.arange(n) / SR
    s = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2 * t)
    return s * env(n, 0.003, 0.07)
def alarm():
    n = int(0.16 * SR); t = np.arange(n) / SR
    s = np.sign(np.sin(2 * np.pi * 740 * t)) * 0.35 + np.sin(2 * np.pi * 1480 * t) * 0.2
    return s * env(n, 0.003, 0.09)
def whoosh(dur=0.45):
    n = int(dur * SR); x = rng.standard_normal(n)
    out = np.zeros(n); a = 0.0; y = 0.0
    for i in range(n):  # sweeping one-pole low-pass
        a = 0.02 + 0.5 * (i / n) ** 2
        y += a * (x[i] - y); out[i] = y
    e = np.sin(np.pi * np.arange(n) / n) ** 2
    return out * e * 0.7
def boom():
    n = int(1.6 * SR); t = np.arange(n) / SR
    f = 38 + 60 * np.exp(-t * 12)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.2)
    return s * 1.1
def chime():
    n = int(1.5 * SR); t = np.arange(n) / SR
    s = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(660, .5), (990, .35), (1320, .25), (1980, .12)])
    return s * env(n, 0.005, 0.5) * 0.6
def pad():
    t = np.arange(N) / SR
    s = sum(np.sin(2 * np.pi * f * t + p) for f, p in [(55, 0), (82.4, 1), (110, 2), (164.8, .5)])
    lfo = 0.6 + 0.4 * np.sin(2 * np.pi * 0.25 * t)
    e = np.clip(t / 1.0, 0, 1) * np.clip((8.4 - t) / 0.3, 0, 1)
    return s * lfo * e * 0.035

mix[:, 0] += pad(); mix[:, 1] += pad()
# 120 BPM beat until the logo hit
for k in range(17):
    t = k * 0.5
    if t < 8.4: place(kick(0.9 if k % 2 == 0 else 0.7), t)
for k in range(17):
    t = 0.25 + k * 0.5
    if 2.2 <= t < 8.3: place(hat(), t, 0.8, pan=0.3 if k % 2 else -0.3)
# headline hits
for t in (0.10, 0.45, 0.85): place(kick(0.6), t)
# rep blips, rising pitch
for t, f in zip([2.75, 3.3, 3.85, 4.4, 4.95], [880, 988, 1109, 1175, 932]):
    place(blip(f), t, 0.45)
# stop alarm
for t in (5.15, 5.33, 5.51): place(alarm(), t, 0.5)
# transitions
for t in (2.05, 6.5, 8.1): place(whoosh(), t, 0.6)
# end card
place(boom(), 8.45, 1.0); place(chime(), 8.47, 0.55)
# master: soft-clip, normalise, fade out
m = np.tanh(mix * 1.2)
m /= np.max(np.abs(m)) / 0.89
fade = np.clip((DUR - np.arange(N) / SR) / 0.5, 0, 1)[:, None]
m *= fade
pcm = (m * 32767).astype(np.int16)
with wave.open("audio.wav", "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print("ok", pcm.shape)
