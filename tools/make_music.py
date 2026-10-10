"""Generates the game's two music loops (assets/audio/music_menu.wav, music_dive.wav).

Original music, synthesised from scratch with numpy: soft pads, a pulsing sine bass, plucked arpeggios
with an echo, and (dive track only) a gentle kick and hi-hat. The reverb is a circular convolution, so
both tracks loop seamlessly. Run:  python tools/make_music.py
"""
import wave
import numpy as np

SR = 22050
rng = np.random.default_rng(7)


def note(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def env(n, attack, release, sr=SR):
    e = np.ones(n)
    a, r = int(attack * sr), int(release * sr)
    if a: e[:a] = np.linspace(0, 1, a)
    if r: e[-r:] *= np.linspace(1, 0, r)
    return e


def pad(freqs, dur):
    """A soft evolving pad: detuned sines with slow tremolo."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in freqs:
        for detune in (-0.004, 0.0, 0.004):
            out += np.sin(2 * np.pi * f * (1 + detune) * t + rng.random() * 6.28) / 3
        out += 0.25 * np.sin(2 * np.pi * f * 2 * t)
    out *= 0.55 + 0.25 * np.sin(2 * np.pi * 0.2 * t + rng.random() * 6.28)
    return out / len(freqs) * env(n, 0.8, 0.8)


def pluck(freq, dur=0.9):
    n = int(dur * SR)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 2 * t) + 0.12 * np.sin(2 * np.pi * freq * 3 * t)
    return tone * np.exp(-t * 5.0) * env(n, 0.003, 0.05)


def bass(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2 * t)) * env(n, 0.01, 0.12) * np.exp(-t * 1.2)


def kick():
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * (45 + 90 * np.exp(-t * 28)) * t) * np.exp(-t * 14)


def hat():
    n = int(0.05 * SR)
    noise = rng.standard_normal(n)
    noise = np.diff(noise, prepend=0)          # crude high-pass
    return noise * np.exp(-np.arange(n) / SR * 80) * 0.35


def place(track, sound, start, gain=1.0):
    i = int(start * SR)
    end = min(len(track), i + len(sound))
    track[i:end] += sound[:end - i] * gain


def reverb(signal, seconds=2.2, wet=0.32):
    """Circular convolution with decaying noise, so the loop has no seam."""
    n = len(signal)
    ir_len = int(seconds * SR)
    ir = rng.standard_normal(ir_len) * np.exp(-np.arange(ir_len) / SR * 2.4)
    ir = np.concatenate([ir, np.zeros(n - ir_len)])
    ir /= np.abs(ir).sum() ** 0.5 * 12
    wet_signal = np.fft.irfft(np.fft.rfft(signal) * np.fft.rfft(ir), n)
    return signal * (1 - wet) + wet_signal * wet * 6


def echo(signal, delay, feedback=0.4, taps=4):
    out = signal.copy()
    d = int(delay * SR)
    for k in range(1, taps + 1):
        out += np.roll(signal, d * k) * feedback ** k
    return out


def build(bpm, chords, bars_per_chord, loops, arp_pattern, drums, bass_on):
    beat = 60.0 / bpm
    bar = beat * 4
    total_bars = len(chords) * bars_per_chord * loops
    n = int(total_bars * bar * SR)
    pads = np.zeros(n)
    arps = np.zeros(n)
    low = np.zeros(n)
    perc = np.zeros(n)
    bar_index = 0
    for _ in range(loops):
        for chord in chords:
            for _b in range(bars_per_chord):
                start = bar_index * bar
                place(pads, pad([note(m) for m in chord[1:]], bar), start, 0.5)
                root = chord[0]
                if bass_on:
                    for step in range(8):                         # eighth-note bass pulse
                        place(low, bass(note(root), beat * 0.5), start + step * beat * 0.5, 0.55 if step % 2 == 0 else 0.35)
                else:
                    place(low, bass(note(root), bar), start, 0.5)
                for step, degree in enumerate(arp_pattern):
                    if degree is None:
                        continue
                    place(arps, pluck(note(chord[1 + degree % (len(chord) - 1)] + 12 * (degree // (len(chord) - 1)))), start + step * beat * 0.5, 0.33)
                if drums:
                    for q in range(4):
                        place(perc, kick(), start + q * beat, 0.8 if q % 2 == 0 else 0.5)
                    for step in range(8):
                        place(perc, hat(), start + step * beat * 0.5 + beat * 0.25, 0.6)
                bar_index += 1
    mix = pads * 0.9 + echo(arps, beat * 0.75) * 0.9 + low * 0.8 + perc * 0.5
    mix = reverb(mix)
    return mix


def save(name, mix):
    mix = mix - mix.mean()
    mix = mix / np.abs(mix).max() * 0.82
    data = (mix * 32767).astype(np.int16)
    with wave.open(f"assets/audio/{name}.wav", "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())
    print(name, f"{len(data) / SR:.1f} s")


# Chords as [bass root, then chord tones] in MIDI. D minor mood for the deep sea.
MENU_CHORDS = [[38, 57, 62, 65, 69], [34, 58, 62, 65, 69], [36, 55, 60, 64, 67], [43, 59, 62, 67, 71]]   # Dm, Bb, C, G
DIVE_CHORDS = [[38, 62, 65, 69, 72], [36, 60, 64, 67, 71], [34, 58, 62, 65, 69], [41, 60, 65, 69, 72]]   # Dm, C, Bb, F

if __name__ == "__main__":
    save("music_menu", build(72, MENU_CHORDS, 1, 5, [0, None, 2, None, 1, None, 3, None], False, False))
    save("music_dive", build(112, DIVE_CHORDS, 2, 3, [0, 1, 2, 3, 2, 1, 2, 3], True, True))
