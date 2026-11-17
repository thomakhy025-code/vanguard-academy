"""Original looping themes for Vanguard Academy. No third-party audio."""
import math
import random
import struct
import wave

SR = 22050


def write_wav(path, samples):
    fade = int(SR * 0.04)
    body = samples[:-fade]
    for i in range(fade):
        w = i / float(fade)
        head = samples[i]
        tail = samples[-fade + i]
        body[i] = (head[0] * w + tail[0] * (1.0 - w), head[1] * w + tail[1] * (1.0 - w))
    frames = bytearray()
    for left, right in body:
        peak = max(-1.0, min(1.0, left))
        frames += struct.pack("<h", int(peak * 32000))
        peak = max(-1.0, min(1.0, right))
        frames += struct.pack("<h", int(peak * 32000))
    with wave.open(path, "w") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(frames)


def env_hit(t, dur):
    if t < 0.0 or t > dur:
        return 0.0
    return math.exp(-t / dur * 5.0) * (1.0 - t / dur)


def tone(t, freq, amp):
    return math.sin(2.0 * math.pi * freq * t) * amp


def school(bars=8):
    bpm = 92.0
    beat = 60.0 / bpm
    bar = beat * 4.0
    total = bar * bars
    count = int(total * SR)
    chords = [
        (261.63, 329.63, 392.00),
        (196.00, 246.94, 392.00),
        (220.00, 261.63, 329.63),
        (174.61, 220.00, 349.23),
    ]
    melody = [523.25, 587.33, 659.25, 783.99, 659.25, 587.33, 523.25, 440.00]
    rng = random.Random(7)
    out = []
    for i in range(count + int(SR * 0.04)):
        t = i / float(SR)
        bar_i = int(t / bar) % 4
        local = t % bar
        chord = chords[bar_i]
        sample = 0.0
        for freq in chord:
            sample += tone(t, freq, 0.045)
            sample += tone(t, freq * 2.0, 0.012)
        pluck_i = int(local / (beat / 2.0))
        pluck_t = local - pluck_i * (beat / 2.0)
        sample += tone(t, chord[pluck_i % 3] * 2.0, 0.05) * env_hit(pluck_t, 0.28)
        if local < beat:
            sample += tone(t, 1046.5, 0.07) * env_hit(local, 0.55)
            sample += tone(t, 1568.0, 0.03) * env_hit(local, 0.4)
        note = melody[int(t / bar) % len(melody)]
        note_t = t % bar
        if note_t < beat * 2.0:
            sample += tone(t, note, 0.04) * env_hit(note_t, 1.3)
        sample += (rng.random() * 2.0 - 1.0) * 0.004
        sample *= 0.9
        delay = int(SR * 0.012)
        out.append(sample)
    stereo = []
    for i, sample in enumerate(out):
        other = out[i - delay] if i >= delay else sample
        stereo.append((sample, other * 0.92))
    return stereo


def battle(bars=8):
    bpm = 128.0
    beat = 60.0 / bpm
    bar = beat * 4.0
    total = bar * bars
    count = int(total * SR)
    roots = [164.81, 130.81, 196.00, 146.83]
    lead = [329.63, 392.00, 440.00, 493.88, 440.00, 392.00, 329.63, 493.88]
    rng = random.Random(3)
    out = []
    for i in range(count + int(SR * 0.04)):
        t = i / float(SR)
        bar_i = int(t / bar) % 4
        local = t % beat
        beat_i = int(t / beat) % 4
        root = roots[bar_i]
        sample = 0.0
        sample += tone(t, root / 2.0, 0.16) * env_hit(local, 0.22)
        sample += tone(t, root, 0.07)
        if beat_i in (0, 2):
            sample += tone(t, 70.0, 0.28) * env_hit(local, 0.12)
        if beat_i in (1, 3):
            noise = rng.random() * 2.0 - 1.0
            sample += noise * 0.18 * env_hit(local, 0.09)
            sample += tone(t, 180.0, 0.08) * env_hit(local, 0.08)
        if beat_i == 0 and local < 0.08:
            sample += tone(t, 988.0, 0.06) * env_hit(local, 0.2)
        step = int((t % bar) / (beat / 2.0))
        if step % 2 == 0:
            freq = lead[(bar_i * 2 + step // 2) % len(lead)]
            sample += tone(t, freq, 0.07) * env_hit(t % (beat / 2.0), 0.2)
            sample += tone(t, freq * 1.5, 0.03) * env_hit(t % (beat / 2.0), 0.16)
        sample = math.tanh(sample * 1.3) * 0.72
        out.append(sample)
    stereo = []
    delay = int(SR * 0.008)
    for i, sample in enumerate(out):
        other = out[i - delay] if i >= delay else sample
        stereo.append((sample, other))
    return stereo


if __name__ == "__main__":
    root = r"C:\Users\User\Documents\Unity ai game\Magicandswordupgradegame4\audio"
    write_wav(root + r"\between_bells.wav", school())
    write_wav(root + r"\ready_at_the_ring.wav", battle())
    print("wrote themes")
