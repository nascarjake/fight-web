"""Render the original RIFT//RIOT synth-metal score and arcade sound effects.

No sampled recordings or third-party composition. Requires Python + NumPy only.
The shipped WAV files play directly in Godot; this is an offline authoring tool.
"""
from pathlib import Path
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)
RATE = 32000
RNG = np.random.default_rng(710)


def write(name, sound):
    peak = np.max(np.abs(sound))
    sound = sound / max(1, peak / .92)
    pcm = (sound * 32767).astype("<i2")
    with wave.open(str(OUT / (name + ".wav")), "wb") as f:
        f.setnchannels(1 if sound.ndim == 1 else 2)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm.tobytes())


def clock(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def guitar(freq, seconds, detune=0., mute=True):
    t = clock(seconds)
    fundamental = freq * (1 + detune)
    # Plucked harmonic body into a saturating amplifier/cabinet approximation.
    raw = np.zeros(len(t))
    for harmonic in range(1, 22):
        amp = (1 / harmonic ** 1.35) * np.exp(-t * harmonic * (1.8 if mute else .32))
        raw += amp * np.sin(2 * np.pi * fundamental * harmonic * t + .013 * harmonic)
    pick = RNG.standard_normal(len(t)) * np.exp(-t * 130) * .1
    raw = np.tanh((raw + pick) * 4)
    # Smooth the very high overtones without removing the pick transient.
    raw = np.convolve(raw, np.ones(7) / 7, mode="same")
    envelope = (1 - np.exp(-t * 850)) * np.exp(-t * (9 if mute else 1.5))
    envelope *= np.minimum(1, np.maximum(0, seconds - t) * 180)
    return raw * envelope


def kick():
    t = clock(.24)
    phase = 2 * np.pi * (47 * t + 2.1 * (1 - np.exp(-t * 45)))
    return np.sin(phase) * np.exp(-t * 19) + RNG.standard_normal(len(t)) * .15 * np.exp(-t * 200)


def snare():
    t = clock(.22)
    noise = RNG.standard_normal(len(t))
    noise = noise - np.convolve(noise, np.ones(9) / 9, mode="same")
    return .45 * noise * np.exp(-t * 24) + .42 * np.sin(2 * np.pi * 185 * t) * np.exp(-t * 35)


def cymbal(seconds=.09):
    t = clock(seconds)
    noise = RNG.standard_normal(len(t))
    noise = noise - np.convolve(noise, np.ones(4) / 4, mode="same")
    return noise * np.exp(-t * (7 / seconds)) * .22


beat = 60 / 164
duration = 32 * 4 * beat
mix = np.zeros((int(duration * RATE), 2))


def place(sound, when, volume, pan=0):
    start = int(when * RATE)
    length = min(len(sound), len(mix) - start)
    if length <= 0:
        return
    mix[start:start + length, 0] += sound[:length] * volume * (1 - pan * .5)
    mix[start:start + length, 1] += sound[:length] * volume * (1 + pan * .5)


roots = [0, 0, 3, 1, 0, 0, 6, 5, 0, 7, 5, 3, 0, 7, 6, 1]
for bar in range(32):
    chord = roots[bar % 16]
    for eighth in range(8):
        when = (bar * 4 + eighth * .5) * beat
        if (bar % 4 == 3 and eighth in (3, 7)) or (bar >= 16 and eighth == 5):
            continue
        note = chord if eighth in (0, 3, 6) else 0
        freq = 82.4069 * 2 ** (note / 12)
        sustain = bar >= 16 and eighth in (0, 6)
        length = beat * (1 if sustain else .46)
        for pan, detune in [(-.9, -.0025), (.9, .0025)]:
            chord_wave = guitar(freq, length, detune, not sustain)
            chord_wave += guitar(freq * 1.4983, length, detune, not sustain) * .65
            chord_wave += guitar(freq * 2, length, detune, not sustain) * .25
            place(chord_wave, when + (.006 if pan > 0 else 0), .125, pan)
        t = clock(beat * .46)
        bass = np.tanh(2 * np.sin(2 * np.pi * freq / 2 * t)) * np.exp(-t * 7)
        place(bass, when, .18)
        place(cymbal(), when, .32 if eighth % 2 == 0 else .22, .35)
    for position in ([0, .75, 1.5, 2, 2.5, 3.5] if bar % 2 else [0, .5, 1.75, 2, 2.75]):
        place(kick(), (bar * 4 + position) * beat, .6)
    for position in [1, 3]:
        place(snare(), (bar * 4 + position) * beat, .44, -.12)
    if bar % 4 == 0:
        place(cymbal(1.15), bar * 4 * beat, .38, .5)
    if bar % 4 == 3:
        for position in [3.25, 3.5, 3.75]:
            place(snare(), (bar * 4 + position) * beat, .24, (position - 3.5) * 2)

# Subtle stereo room taps keep the dense rhythm clear.
tap = int(.091 * RATE)
mix[tap:] += mix[:-tap, ::-1] * .065
mix = np.tanh(mix * 1.35) * .84
mix[:int(.006 * RATE)] *= np.linspace(0, 1, int(.006 * RATE))[:, None]
mix[-int(.012 * RATE):] *= np.linspace(1, 0, int(.012 * RATE))[:, None]
write("riot_engine", mix)

t = clock(.16)
write("menu_select", np.sin(2 * np.pi * (650 * t + 1800 * t * t)) * np.exp(-t * 40) * .28)
t = clock(.32)
write("impact", (np.sin(2 * np.pi * (70 * t + 2 * (1 - np.exp(-t * 40)))) * .6 + RNG.standard_normal(len(t)) * .25) * np.exp(-t * 27))
t = clock(.3)
write("block", (np.sin(2 * np.pi * 1450 * t) + np.sin(2 * np.pi * 2381 * t) * .7) * np.exp(-t * 35) * .24)
t = clock(.65)
write("burst", (RNG.standard_normal(len(t)) * .4 + np.sin(2 * np.pi * (42 * t + 9 * (1 - np.exp(-t * 10))))) * np.exp(-t * 8) * .5)
t = clock(.8)
write("round", sum(np.sin(2 * np.pi * f * t) for f in [164.81, 246.94, 329.63]) * np.exp(-t * 7) * .23)
print("Rendered original 46.8s stereo synth-metal loop and five sound effects to", OUT)
