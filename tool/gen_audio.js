// Synthesises 99 Numbers' background music and the newer sound effects into
// assets/audio as 16-bit mono WAV — pure Node, no samples, so there's no
// licensing question. Run from the project root: node tool/gen_audio.js
//
// Same approach as block-puzzle-app's tool/gen_music.js, but original
// material and a different palette so the two games don't sound alike:
// - bgm_menu.wav: calm, curious — marimba melody over a soft pad, F major,
//   92 bpm, 16 bars.
// - bgm_game.wav: focused, driving — the same marimba as lead over a 16th-
//   note pluck arpeggio, pumping bass and a soft four-on-the-floor, A minor
//   (vi-IV-I-V), 132 bpm, 16 bars.
// - sfx_wrong.wav: short low double-buzz for a wrong cell.
// - sfx_game_over.wav: gentle descending phrase ending on a minor chord.
// - sfx_win.wav: rising arpeggio + bright chord.
//
// Loops are rendered with the last notes' ring-out folded back onto the
// start, so the file is exactly N bars long and loops without a gap.
const fs = require('fs');
const path = require('path');

const RATE = 22050;
const OUT = path.join(__dirname, '..', 'assets', 'audio');
fs.mkdirSync(OUT, { recursive: true });

let seed = 99;
const noise = () => {
  seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return seed / 0x3fffffff - 1;
};

function write(name, samples, peak = 0.75) {
  let max = 0;
  for (const s of samples) max = Math.max(max, Math.abs(s));
  const gain = max > 0 ? peak / max : 1;
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((s, i) => data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, s * gain)) * 32767), i * 2));
  const head = Buffer.alloc(44);
  head.write('RIFF', 0);
  head.writeUInt32LE(36 + data.length, 4);
  head.write('WAVEfmt ', 8);
  head.writeUInt32LE(16, 16);
  head.writeUInt16LE(1, 20);
  head.writeUInt16LE(1, 22);
  head.writeUInt32LE(RATE, 24);
  head.writeUInt32LE(RATE * 2, 28);
  head.writeUInt16LE(2, 32);
  head.writeUInt16LE(16, 34);
  head.write('data', 36);
  head.writeUInt32LE(data.length, 40);
  fs.writeFileSync(path.join(OUT, name), Buffer.concat([head, data]));
  console.log(name, (samples.length / RATE).toFixed(2) + 's', Math.round((44 + data.length) / 1024) + 'KB');
}

const TAIL = 1.5;
const buf = (seconds) => new Float64Array(Math.round(seconds * RATE));
const midiFreq = (n) => 440 * Math.pow(2, (n - 69) / 12);
const TAU = 2 * Math.PI;

function lowpass(x, cutoff) {
  const a = 1 - Math.exp((-TAU * cutoff) / RATE);
  let y = 0;
  for (let i = 0; i < x.length; i++) {
    y += a * (x[i] - y);
    x[i] = y;
  }
  return x;
}

// Mixes `synth(t, dur)` into `target` from `startSec` for `durSec` (+ the
// voice's own release, which the synth handles via t > dur).
function addNote(target, startSec, durSec, synth, ringSec = 0) {
  const from = Math.round(startSec * RATE);
  const count = Math.round((durSec + ringSec) * RATE);
  for (let i = 0; i < count && from + i < target.length; i++) {
    if (from + i >= 0) target[from + i] += synth(i / RATE, durSec);
  }
}

// Folds everything past `loopSec` back onto the start → seamless loop.
function foldLoop(x, loopSec) {
  const n = Math.round(loopSec * RATE);
  const out = x.slice(0, n);
  for (let i = n; i < x.length; i++) out[i - n] += x[i];
  return out;
}

// ---- voices -----------------------------------------------------------------

// Marimba: struck bar — fundamental plus the characteristic 4th partial that
// dies fast, so it's bright on the attack and mellow after.
const marimba = (f, gain = 1) => (t) => {
  const a = Math.min(1, t * 600);
  return gain * a * (Math.sin(TAU * f * t) * Math.exp(-t * 5) + 0.35 * Math.sin(TAU * 4 * f * t) * Math.exp(-t * 28) + 0.12 * Math.sin(TAU * 10 * f * t) * Math.exp(-t * 60));
};

// Soft pad: slow attack/release, two slightly detuned sines + octave.
const pad = (f, gain = 0.2) => (t, dur) => {
  const att = Math.min(1, t / 0.35);
  const rel = t > dur ? Math.max(0, 1 - (t - dur) / 0.6) : 1;
  return gain * att * rel * (Math.sin(TAU * f * t) + Math.sin(TAU * f * 1.004 * t) + 0.3 * Math.sin(TAU * 2 * f * t));
};

// Bass with a strong 2nd/3rd harmonic so it's still audible on phone
// speakers, which can't reproduce the fundamental.
const bass = (f, gain = 0.6, decay = 4) => (t, dur) => {
  const a = Math.min(1, t * 400);
  const rel = t > dur ? Math.max(0, 1 - (t - dur) / 0.05) : 1;
  return gain * a * rel * Math.exp(-t * decay) * (Math.sin(TAU * f * t) + 0.5 * Math.sin(TAU * 2 * f * t) + 0.25 * Math.sin(TAU * 3 * f * t));
};

// Short plucked synth for the game track's 16th-note arpeggio.
const pluck = (f, gain = 0.25) => (t) => {
  const a = Math.min(1, t * 800);
  return gain * a * Math.exp(-t * 16) * (Math.sin(TAU * f * t) + 0.4 * Math.sin(TAU * 3 * f * t) + 0.2 * Math.sin(TAU * 5 * f * t));
};

function kick(target, startSec, gain = 0.55) {
  addNote(target, startSec, 0.18, (t) => {
    const f = 45 + 95 * Math.exp(-t * 30);
    return gain * Math.exp(-t * 22) * Math.sin(TAU * f * t);
  });
}

function hat(target, startSec, gain = 0.07) {
  const n = Math.round(0.04 * RATE);
  const raw = Float64Array.from({ length: n }, noise);
  const low = lowpass(raw.slice(), 6000);
  const from = Math.round(startSec * RATE);
  for (let i = 0; i < n && from + i < target.length; i++) {
    target[from + i] += (raw[i] - low[i]) * Math.exp((-i / n) * 6) * gain;
  }
}

function melody(target, barStart, spb, notes, gain = 1) {
  for (const [beat, midi, dur] of notes) {
    addNote(target, barStart + beat * spb, dur * spb, marimba(midiFreq(midi), gain), 1.2);
  }
}

// ---- tracks -------------------------------------------------------------------

function composeMenu() {
  const bpm = 92;
  const spb = 60 / bpm;
  const bars = 16;
  const loop = bars * 4 * spb;
  const x = buf(loop + TAIL);
  const prog = ['F', 'Dm', 'Bb', 'C', 'F', 'Am', 'Bb', 'C', 'Dm', 'Bb', 'F', 'C', 'Bb', 'C', 'F', 'C'];
  const PAD = { F: [53, 57, 60], Dm: [50, 53, 57], Bb: [50, 53, 58], C: [52, 55, 60], Am: [52, 57, 60] };
  const ROOT = { F: 41, Dm: 38, Bb: 46, C: 48, Am: 45 };
  const mel = [
    [[0, 77, 1], [1, 76, 0.5], [1.5, 74, 0.5], [2, 72, 1.5], [3.5, 69, 0.5]],
    [[0, 74, 1], [1, 72, 0.5], [1.5, 69, 0.5], [2, 65, 2]],
    [[0, 70, 0.5], [0.5, 74, 0.5], [1, 77, 1], [2, 74, 1], [3, 70, 1]],
    [[0, 72, 1.5], [1.5, 74, 0.5], [2, 76, 1], [3, 79, 1]],
    [[0, 81, 1], [1, 79, 0.5], [1.5, 77, 0.5], [2, 72, 1.5], [3.5, 77, 0.5]],
    [[0, 76, 1], [1, 72, 0.5], [1.5, 69, 0.5], [2, 72, 1], [3, 76, 1]],
    [[0, 74, 1], [1, 77, 1], [2, 82, 1], [3, 81, 0.5], [3.5, 79, 0.5]],
    [[0, 79, 2], [2, 76, 1], [3, 72, 1]],
    [[0, 74, 0.5], [0.5, 77, 0.5], [1, 81, 1], [2, 77, 1], [3, 74, 1]],
    [[0, 74, 0.5], [0.5, 77, 0.5], [1, 82, 1], [2, 77, 1], [3, 74, 1]],
    [[0, 72, 0.5], [0.5, 77, 0.5], [1, 81, 1], [2, 84, 1], [3, 81, 1]],
    [[0, 79, 1.5], [1.5, 76, 0.5], [2, 72, 2]],
    [[0, 82, 1], [1, 81, 0.5], [1.5, 79, 0.5], [2, 77, 1], [3, 74, 1]],
    [[0, 76, 1], [1, 79, 1], [2, 84, 1], [3, 79, 1]],
    [[0, 81, 1.5], [1.5, 79, 0.5], [2, 77, 2]],
    [[0, 72, 1], [1, 74, 1], [2, 76, 1], [3, 79, 1]],
  ];
  for (let b = 0; b < bars; b++) {
    const c = prog[b];
    const start = b * 4 * spb;
    for (const n of PAD[c]) addNote(x, start, 4 * spb, pad(midiFreq(n)), 0.6);
    addNote(x, start, 1.8 * spb, bass(midiFreq(ROOT[c]), 0.55, 2.5), 0.05);
    addNote(x, start + 2 * spb, 1.8 * spb, bass(midiFreq(ROOT[c] + 7), 0.4, 2.5), 0.05);
    melody(x, start, spb, mel[b], 0.9);
  }
  write('bgm_menu.wav', lowpass(foldLoop(x, loop), 7000), 0.7);
}

function composeGame() {
  const bpm = 132;
  const spb = 60 / bpm;
  const bars = 16;
  const loop = bars * 4 * spb;
  const x = buf(loop + TAIL);
  const prog = ['Am', 'F', 'C', 'G'];
  const CH = { Am: [57, 60, 64], F: [53, 57, 60], C: [55, 60, 64], G: [55, 59, 62] };
  const ROOT = { Am: 45, F: 41, C: 48, G: 43 };
  const A = [
    [[0, 76, 1], [1.5, 74, 0.5], [2, 72, 1], [3, 69, 1]],
    [[0, 72, 1], [1.5, 74, 0.5], [2, 76, 1.5], [3.5, 77, 0.5]],
    [[0, 79, 1], [1, 76, 1], [2, 72, 1], [3, 76, 1]],
    [[0, 74, 2], [2.5, 71, 0.5], [3, 74, 1]],
  ];
  const A2 = [A[0], A[1],
    [[0, 79, 0.5], [0.5, 81, 0.5], [1, 79, 1], [2, 76, 1], [3, 72, 1]],
    [[0, 74, 3], [3, 71, 1]]];
  const B = [
    [[0, 81, 0.5], [0.5, 79, 0.5], [1, 76, 0.5], [1.5, 79, 0.5], [2, 81, 1], [3, 84, 1]],
    [[0, 84, 0.5], [0.5, 81, 0.5], [1, 77, 0.5], [1.5, 81, 0.5], [2, 84, 1.5], [3.5, 81, 0.5]],
    [[0, 79, 0.5], [0.5, 76, 0.5], [1, 72, 0.5], [1.5, 76, 0.5], [2, 79, 1], [3, 84, 1]],
    [[0, 83, 1.5], [1.5, 79, 0.5], [2, 74, 2]],
  ];
  const B2 = [B[0], B[1],
    [[0, 79, 0.5], [0.5, 84, 0.5], [1, 79, 0.5], [1.5, 76, 0.5], [2, 72, 1], [3, 76, 1]],
    [[0, 79, 1], [1, 74, 1], [2, 71, 1], [3, 74, 1]]];
  const mel = [...A, ...A2, ...B, ...B2];
  for (let b = 0; b < bars; b++) {
    const c = prog[b % 4];
    const start = b * 4 * spb;
    const step = spb / 4;
    const [r, t3, f5] = CH[c];
    const arp = [r, t3, f5, r + 12, f5, t3, r + 12, f5];
    // The arpeggio drops out for the first 2 bars so the loop "breathes" at
    // its seam instead of being a wall of 16ths forever.
    if (b >= 2) for (let i = 0; i < 16; i++) addNote(x, start + i * step, step, pluck(midiFreq(arp[i % 8])), 0.3);
    for (let i = 0; i < 8; i++) {
      const note = i % 2 === 0 ? ROOT[c] : ROOT[c] + 12;
      addNote(x, start + i * spb / 2, spb * 0.42, bass(midiFreq(note), 0.5, 6), 0.05);
    }
    for (let beat = 0; beat < 4; beat++) {
      kick(x, start + beat * spb);
      hat(x, start + (beat + 0.5) * spb);
    }
    melody(x, start, spb, mel[b], 0.85);
  }
  write('bgm_game.wav', lowpass(foldLoop(x, loop), 8000), 0.72);
}

// ---- sound effects --------------------------------------------------------------

function sfxWrong() {
  const x = buf(0.28);
  // Two quick, low, slightly buzzy blips — clearly "no", but soft enough to
  // hear dozens of times per run.
  const buzz = (f) => (t, dur) => {
    const env = Math.min(1, t * 400) * (t > dur ? Math.max(0, 1 - (t - dur) / 0.02) : 1);
    let s = 0;
    for (let k = 1; k <= 7; k += 2) s += Math.sin(TAU * f * k * t) / k;
    return env * s;
  };
  addNote(x, 0, 0.08, buzz(196), 0.02);
  addNote(x, 0.11, 0.12, buzz(165), 0.02);
  write('sfx_wrong.wav', lowpass(x, 2500), 0.55);
}

function sfxGameOver() {
  const x = buf(2.2);
  // Gentle descending marimba line settling on a soft D-minor chord.
  [[0, 76], [0.18, 72], [0.36, 69], [0.54, 65]].forEach(([s, n]) => addNote(x, s, 0.2, marimba(midiFreq(n)), 1));
  for (const n of [62, 65, 69]) {
    addNote(x, 0.78, 0.9, marimba(midiFreq(n), 0.7), 1);
    addNote(x, 0.78, 0.8, pad(midiFreq(n - 12), 0.25), 0.6);
  }
  write('sfx_game_over.wav', x, 0.7);
}

function sfxWin() {
  const x = buf(2.0);
  [[0, 72], [0.1, 76], [0.2, 79], [0.3, 84]].forEach(([s, n]) => addNote(x, s, 0.15, marimba(midiFreq(n)), 1));
  for (const n of [72, 76, 79, 88]) {
    addNote(x, 0.45, 0.8, marimba(midiFreq(n), 0.8), 1);
    addNote(x, 0.45, 0.7, pad(midiFreq(n - 12), 0.18), 0.6);
  }
  write('sfx_win.wav', x, 0.7);
}

composeMenu();
composeGame();
sfxWrong();
sfxGameOver();
sfxWin();
