"""Original synthesized combat Foley, elemental accents, and nonverbal effort vocals.

All signals are generated here: seeded noise, oscillators, resonances, and
formant-filtered glottal pulses. No recordings, speech, or external samples.
Existing music is not modified. Requires Python + NumPy; output is 48 kHz PCM.
"""
from pathlib import Path
import wave
import numpy as np

RATE = 48000
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RNG = np.random.default_rng(710_2026)


def clock(seconds):
    return np.arange(round(seconds * RATE), dtype=np.float64) / RATE


def band(signal, low=0., high=12000.):
    spectrum = np.fft.rfft(signal)
    frequencies = np.fft.rfftfreq(len(signal), 1 / RATE)
    response = 1 / (1 + (frequencies / high) ** 6)
    if low > 0:
        response *= 1 - 1 / (1 + (frequencies / low) ** 6)
    return np.fft.irfft(spectrum * response, n=len(signal))


def noise(t, low=50, high=7000):
    result = band(RNG.standard_normal(len(t)), low, high)
    return result / max(np.std(result), .01)


def tone(t, start, end, fall=20):
    frequency = end + (start - end) * np.exp(-t * fall)
    return np.sin(np.cumsum(frequency) * (2 * np.pi / RATE))


def envelope(t, decay, attack=.002):
    return (1 - np.exp(-t / attack)) * np.exp(-t * decay)


def write(name, signal):
    signal = signal - signal.mean()
    fade = min(round(.004 * RATE), len(signal) // 3)
    signal[:fade] *= np.linspace(0, 1, fade)
    signal[-fade:] *= np.linspace(1, 0, fade)
    signal /= max(1, np.max(np.abs(signal)) / .78)
    assert np.isfinite(signal).all()
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as target:
        target.setnchannels(1)
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes((signal * 32767).astype("<i2").tobytes())


def hit(heavy=False):
    t = clock(.40 if heavy else .24)
    body = tone(t, 165 if heavy else 230, 43 if heavy else 76, 39) * envelope(t, 13 if heavy else 25) * .65
    skin = noise(t, 320, 6500) * envelope(t, 57) * .20
    slap = noise(t, 1800, 12500) * envelope(t, 135, .0005) * .12
    grit = noise(t, 70, 1600) * envelope(t, 23 if heavy else 43) * .20
    return np.tanh((body + skin + slap + grit) * 1.3) * .75


def swing(heavy=False):
    t = clock(.34 if heavy else .21)
    center = .11 if heavy else .075
    sweep = np.exp(-((t - center) / (.067 if heavy else .045)) ** 2)
    air = noise(t, 350 if heavy else 1100, 4300 if heavy else 10500) * sweep * .17
    low = tone(t, 310, 75 if heavy else 155, 12) * sweep * .075
    cloth = noise(t, 750, 8500) * np.exp(-((t - center - .033) / .012) ** 2) * .085
    return air + low + cloth


def effort(index, strong=False):
    """A brief ah/uh effort: glottal pulses through vowel formants, not sampled speech."""
    t = clock(.44 if strong else .27)
    f0 = 143 + index * 21 + (80 if strong else 30) * np.exp(-t * 12) - t * 90
    f0 += 3 * np.sin(2 * np.pi * 21 * t)
    phase = np.cumsum(f0) / RATE
    source = np.zeros(len(t))
    for harmonic in range(1, 45):
        source += np.sin(2 * np.pi * harmonic * phase + harmonic * .09) / harmonic ** 1.15
    source += noise(t, 180, 8500) * (.11 if strong else .06)
    frequencies = np.fft.rfftfreq(len(t), 1 / RATE)
    formants = [(710, 130, 1.0), (1150, 180, .6), (2500, 300, .24)] if strong else [(540 + index * 50, 110, 1.0), (920 + index * 70, 170, .48), (2300, 270, .18)]
    response = np.zeros(len(frequencies))
    for frequency, width, gain in formants:
        response += gain * np.exp(-.5 * ((frequencies - frequency) / width) ** 2)
    shaped = np.fft.irfft(np.fft.rfft(source) * response, n=len(t))
    shaped /= max(.01, np.max(np.abs(shaped)))
    shape = envelope(t, 8 if strong else 15, .011)
    breath = noise(t, 900, 7500) * envelope(t, 18, .024) * .07
    return np.tanh(shaped * 1.6) * shape * .62 + breath


def elemental(style):
    t = clock(.55)
    if style == "fire":
        flutter = .35 + .65 * np.sin(2 * np.pi * 63 * t) ** 6
        return noise(t, 120, 6000) * flutter * envelope(t, 14) * .20
    if style in ("ice", "precision"):
        sound = np.zeros(len(t))
        for f in ([1730, 2960, 4630, 7150] if style == "ice" else [2240, 4130, 6310]):
            sound += np.sin(2 * np.pi * f * t + .5) * np.exp(-t * (12 + f / 310)) * .12
        return sound + noise(t, 3100, 13000) * envelope(t, 52) * .08
    if style == "sonic":
        return sum(np.sin(2 * np.pi * f * t) for f in [380, 770, 1155]) * envelope(t, 13) * .085 + noise(t, 1800, 6800) * envelope(t, 31) * .035
    if style == "thorn":
        return noise(t, 620, 5500) * envelope(t, 24) * .16 + tone(t, 210, 82, 26) * envelope(t, 28) * .12
    if style == "crimson":
        return noise(t, 1800, 10000) * envelope(t, 31) * .12 + tone(t, 720, 160, 19) * envelope(t, 22) * .07
    if style == "seismic":
        return tone(t, 105, 31, 19) * envelope(t, 9) * .48 + noise(t, 35, 540) * envelope(t, 15) * .18
    if style == "void":
        return (tone(t, 280, 54, 11) + np.sin(2 * np.pi * 57 * t) * .5) * envelope(t, 9) * .19
    if style == "wind":
        return noise(t, 520, 4800) * np.exp(-((t - .10) / .074) ** 2) * .12 + np.sin(2 * np.pi * 1480 * t) * envelope(t, 24) * .04
    if style == "electric":
        crackle = (RNG.random(len(t)) > .996) * RNG.uniform(-1, 1, len(t))
        return noise(t, 1700, 11000) * envelope(t, 27) * .09 + band(crackle, 200, 13500) * np.exp(-t * 11) * 2.5 + tone(t, 470, 115, 18) * envelope(t, 22) * .05
    raise ValueError(style)


def main():
    write("punch_light", hit())
    write("punch_heavy", hit(True))
    write("swing_light", swing())
    write("swing_heavy", swing(True))
    t = clock(.18)
    write("cloth_hit", noise(t, 400, 7500) * envelope(t, 40) * .14)
    t = clock(.48)
    modes = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * decay) * gain for f, decay, gain in [(1420, 18, .20), (2671, 23, .13), (4379, 34, .10), (6088, 43, .045)])
    write("guard_clash", modes + noise(t, 1400, 13000) * envelope(t, 110) * .12)
    t = clock(.31)
    write("land", tone(t, 145, 42, 42) * envelope(t, 22) * .46 + noise(t, 90, 2900) * envelope(t, 32) * .14)
    write("jump", swing() * .6)
    for index in range(3):
        write(f"voice_grunt_{index}", effort(index))
    for index in range(2):
        write(f"voice_yelp_{index}", effort(index, True))
    for style in ["fire", "sonic", "ice", "thorn", "crimson", "seismic", "precision", "void", "wind", "electric"]:
        write("style_" + style, elemental(style))
    t = clock(.95)
    charge_env = np.sin(np.pi * np.minimum(t / .95, 1)) ** .65
    charge = (np.sin(2 * np.pi * (80 * t + 390 * t ** 2)) * .19 + noise(t, 1200, 6200) * .055) * charge_env
    write("super_charge", charge)
    t = clock(.53)
    write("super_swing", noise(t, 260, 6500) * np.exp(-((t - .12) / .08) ** 2) * .28 + tone(t, 480, 38, 13) * envelope(t, 10) * .30)
    t = clock(1.1)
    boom = tone(t, 150, 30, 32) * envelope(t, 4.9) * .68
    boom += noise(t, 60, 2800) * envelope(t, 8) * .21
    boom += noise(t, 1200, 10000) * envelope(t, 70) * .18
    echo = round(.13 * RATE)
    boom[echo:] += boom[:-echo] * .18
    write("super_boom", np.tanh(boom * 1.3) * .78)
    print("Rendered 26 original combat Foley, elemental, synthetic effort, and super WAVs to", OUT)


if __name__ == "__main__":
    main()
