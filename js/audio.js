// Music and sound effects.
// Two pieces of music, each looping without a seam: one behind the menus, one for the run (always
// the same). They are the files named in assets/music/tracks.json; if the run's file is missing,
// a built-in theme generated note by note takes over.

const MUSIC_DIR = 'assets/music/';

let ac = null, sfxOut = null, musicOut = null;
let timer = null, step = 0, nextT = 0, root = 0;
let tracks = {}, listLoading = null;          // { menu: { file, loopStart?, loopEnd? }, run: { ... } }
const buffers = new Map();
let source = null, wanted = '', current = 0;  // wanted: '' (silence), 'menu' or 'run'

const hz = (semi) => 220 * Math.pow(2, semi / 12);

// Built-in themes: 16-step arpeggio over a 4-bar bass line. A loop is seamless by construction.
const THEMES = [
  { name: 'Canopée', bpm: 112, wave: 'triangle', scale: [0, 3, 5, 7, 10, 12, 15], arp: [0, 2, 3, 2, 4, 3, 2, 1, 0, 2, 3, 5, 4, 3, 2, 1], bass: [0, 0, -4, -2], drums: 0 },
  { name: 'Grande évasion', bpm: 132, wave: 'square', scale: [0, 2, 4, 7, 9, 12, 14], arp: [0, 2, 4, 2, 5, 4, 2, 1, 0, 3, 4, 6, 5, 4, 2, 4], bass: [0, -5, -3, -7], drums: 1 },
  { name: 'La relique', bpm: 98, wave: 'sine', scale: [0, 2, 3, 7, 9, 12, 14], arp: [0, 3, 4, 3, 5, 3, 4, 2, 0, 3, 4, 6, 5, 4, 3, 1], bass: [0, -2, -4, -2], drums: 0 },
  { name: 'Tambours', bpm: 124, wave: 'triangle', scale: [0, 3, 5, 7, 10, 12, 15], arp: [0, 0, 3, 2, 0, 0, 4, 3, 0, 0, 3, 5, 4, 3, 2, 3], bass: [0, 0, 3, -2], drums: 2 },
];

function tone(out, freq, dur, type, vol, when = 0, slideTo = 0) {
  const t = ac.currentTime + when;
  const o = ac.createOscillator(), g = ac.createGain();
  o.type = type;
  o.frequency.setValueAtTime(freq, t);
  if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
  g.gain.setValueAtTime(vol, t);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o.connect(g).connect(out);
  o.start(t); o.stop(t + dur + 0.02);
}

// A burst of hiss around `freq`: the grain of wood breaking, which no plain tone can give.
let hiss = null;
function noise(out, dur, vol, freq, when = 0) {
  if (!hiss) {
    hiss = ac.createBuffer(1, ac.sampleRate / 2, ac.sampleRate);
    const d = hiss.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }
  const t = ac.currentTime + when, src = ac.createBufferSource(), f = ac.createBiquadFilter(), g = ac.createGain();
  src.buffer = hiss; f.type = 'bandpass'; f.frequency.value = freq; f.Q.value = 0.8;
  g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  src.connect(f).connect(g).connect(out);
  src.start(t, Math.random() * 0.3, dur + 0.02);
}

function schedule() {
  const th = THEMES[current % THEMES.length];
  const beat = 60 / th.bpm / 2;                        // eighth notes
  while (nextT < ac.currentTime + 0.3) {
    const when = Math.max(0, nextT - ac.currentTime);
    const base = root + th.bass[Math.floor(step / 8) % 4];
    const lead = th.wave === 'square' ? 0.05 : 0.10;
    tone(musicOut, hz(base + th.scale[th.arp[step % 16]]), beat * 0.9, th.wave, lead, when);
    if (step % 4 === 0) tone(musicOut, hz(base - 24), beat * 3.2, 'sine', 0.22, when);
    if (step % 4 === 0) tone(musicOut, 130, 0.12, 'sine', 0.25, when, 40);              // kick
    if (th.drums >= 1 && step % 4 === 2) tone(musicOut, 900, 0.05, 'square', 0.03, when, 300);   // hat
    if (th.drums >= 2 && (step % 8 === 3 || step % 8 === 6)) tone(musicOut, 190, 0.14, 'sine', 0.2, when, 90);  // tom
    if (step % 8 === 6) tone(musicOut, hz(base + 19), beat * 1.8, 'sine', 0.05, when);
    step++; nextT += beat;
  }
}

// Fetched once; everyone who asks waits for that same fetch.
function loadList() {
  return listLoading ??= (async () => {
    try {
      const r = await fetch(MUSIC_DIR + 'tracks.json', { cache: 'no-cache' });
      if (r.ok) tracks = await r.json();
    } catch { /* no list: the built-in theme */ }
  })();
}

// MP3 encoders pad both ends with silence, which would be heard at each loop: find the real sound.
function soundBounds(buf) {
  const d = buf.getChannelData(0), th = 0.004;
  let a = 0, b = d.length - 1;
  while (a < b && Math.abs(d[a]) < th) a++;
  while (b > a && Math.abs(d[b]) < th) b--;
  return [a / buf.sampleRate, (b + 1) / buf.sampleRate];
}

async function playFile(which) {
  const t = tracks[which];
  let buf = buffers.get(which);
  if (!buf) {
    const r = await fetch(MUSIC_DIR + t.file);
    buf = await ac.decodeAudioData(await r.arrayBuffer());
    buffers.set(which, buf);
  }
  if (wanted !== which || source) return;              // stopped or changed while loading
  const [a, b] = soundBounds(buf);
  source = ac.createBufferSource();
  source.buffer = buf; source.loop = true;
  source.loopStart = t.loopStart ?? a; source.loopEnd = t.loopEnd ?? b;
  source.connect(musicOut);
  source.start(0, source.loopStart);
}

function silence() {
  if (source) { try { source.stop(); } catch { /* already stopped */ } source = null; }
  if (timer) { clearInterval(timer); timer = null; }
}

loadList();   // a plain fetch: no need to wait for the first gesture

export const audio = {
  musicOn: true,
  sfxOn: true,

  // Browsers only allow sound after a user gesture: call this from one.
  unlock() {
    if (!ac) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return;
      ac = new AC();
      sfxOut = ac.createGain(); sfxOut.gain.value = 0.5; sfxOut.connect(ac.destination);
      musicOut = ac.createGain(); musicOut.gain.value = 0.5; musicOut.connect(ac.destination);
      loadList();
    }
    if (ac.state === 'suspended') ac.resume();
  },

  // Plays 'menu' or 'run' music, or nothing (''). Asking again for what already plays changes nothing,
  // so moving between the menu's screens never restarts the tune.
  async music(which) {
    if (!ac || !this.musicOn) which = '';
    if (which === wanted && (source || timer || !which)) return;
    wanted = which; silence();
    if (!which) return;
    await loadList();
    if (wanted !== which || source || timer) return;
    if (tracks[which]) { playFile(which).catch(() => { delete tracks[which]; wanted = ''; this.music(which); }); return; }
    if (which === 'run') { step = 0; nextT = ac.currentTime + 0.05; timer = setInterval(schedule, 100); }
  },

  // Built-in themes change key with the scenery.
  setBiome(i) { root = [0, -2, 3, -5][i] || 0; },

  sfx(name) {
    if (!ac || !this.sfxOn) return;
    const o = sfxOut;
    switch (name) {
      case 'jump': tone(o, 320, 0.14, 'square', 0.12, 0, 620); break;
      case 'coin': tone(o, 1320, 0.07, 'square', 0.10); tone(o, 1760, 0.12, 'square', 0.10, 0.06); break;
      case 'bounce': tone(o, 200, 0.25, 'sine', 0.3, 0, 800); break;
      case 'flap': tone(o, 520, 0.07, 'triangle', 0.09, 0, 900); break;
      case 'mount': [0, 7, 12, 19].forEach((s, k) => tone(o, hz(s + 12), 0.2, 'square', 0.14, k * 0.07)); break;
      case 'unmount': tone(o, 420, 0.3, 'square', 0.2, 0, 110); break;
      case 'bye': tone(o, 700, 0.12, 'triangle', 0.14, 0, 500); tone(o, 500, 0.16, 'triangle', 0.14, 0.12, 350); break;
      case 'roll': tone(o, 240, 0.22, 'triangle', 0.16, 0, 520); break;
      case 'heart': [12, 16, 19, 24].forEach((s, k) => tone(o, hz(s + 12), 0.22, 'triangle', 0.2, k * 0.07)); break;
      case 'grab': tone(o, 620, 0.08, 'triangle', 0.14, 0, 880); break;
      case 'drop': tone(o, 520, 0.1, 'triangle', 0.12, 0, 300); break;
      case 'fm': tone(o, 880, 0.1, 'square', 0.13); tone(o, 880, 0.1, 'square', 0.13, 0.18); tone(o, 880, 0.1, 'square', 0.13, 0.36); break;
      case 'rush': tone(o, 300, 0.5, 'sawtooth', 0.12, 0, 1400); break;
      case 'dodge': tone(o, 990, 0.08, 'triangle', 0.14); tone(o, 1320, 0.14, 'triangle', 0.14, 0.07); break;
      case 'break': tone(o, 180, 0.18, 'sawtooth', 0.25, 0, 50); break;
      // a crate: the crack, the planks giving way, the thud
      case 'crate': tone(o, 640, 0.04, 'square', 0.14, 0, 210); noise(o, 0.17, 0.55, 1300, 0.01); noise(o, 0.11, 0.3, 3400, 0.04); tone(o, 170, 0.17, 'sine', 0.38, 0.01, 52); break;
      case 'dash': tone(o, 200, 0.35, 'sawtooth', 0.18, 0, 1200); break;
      case 'slow': tone(o, 900, 0.6, 'sine', 0.2, 0, 150); break;
      case 'hit': tone(o, 240, 0.5, 'sawtooth', 0.3, 0, 40); break;
      case 'hurt': tone(o, 300, 0.22, 'square', 0.2, 0, 90); break;
      case 'gem': [12, 19, 24].forEach((s, k) => tone(o, hz(s + 12), 0.18, 'triangle', 0.18, k * 0.06)); break;
      case 'rewind': tone(o, 150, 0.7, 'triangle', 0.3, 0, 1400); break;
      case 'biome': tone(o, 660, 0.5, 'sine', 0.2, 0, 1320); tone(o, 990, 0.6, 'sine', 0.12, 0.1, 1980); break;
      case 'buy': tone(o, 660, 0.1, 'triangle', 0.25); tone(o, 990, 0.2, 'triangle', 0.25, 0.1); tone(o, 1320, 0.3, 'triangle', 0.2, 0.2); break;
      case 'no': tone(o, 160, 0.15, 'square', 0.15); break;
      case 'click': tone(o, 520, 0.05, 'square', 0.08, 0, 780); break;
      case 'record': [0, 4, 7, 12].forEach((s, k) => tone(o, hz(s + 12), 0.25, 'triangle', 0.2, k * 0.09)); break;
      case 'rumble': tone(o, 55, 0.8, 'sawtooth', 0.18, 0, 70); break;
      case 'boom': tone(o, 140, 0.9, 'sawtooth', 0.45, 0, 28); tone(o, 70, 1.1, 'square', 0.3, 0, 22); tone(o, 900, 0.25, 'sawtooth', 0.12, 0, 120); break;
      case 'shroom': [19, 24, 31].forEach((n, k) => tone(o, hz(n + 12), 0.25, 'sine', 0.12, k * 0.05)); break;
      case 'rustle': tone(o, 2400, 0.06, 'sawtooth', 0.03, 0, 900); break;
      case 'monkey': tone(o, 700, 0.09, 'square', 0.1, 0, 1100); tone(o, 800, 0.09, 'square', 0.1, 0.12, 1250); tone(o, 950, 0.12, 'square', 0.1, 0.24, 1400); break;
      case 'tick': tone(o, 1500, 0.03, 'square', 0.05); break;
      case 'quest': [7, 12, 16].forEach((s, k) => tone(o, hz(s + 12), 0.2, 'triangle', 0.2, k * 0.08)); break;
      case 'level': [0, 4, 7, 12, 16].forEach((s, k) => tone(o, hz(s + 12), 0.3, 'triangle', 0.2, k * 0.08)); break;
    }
  },
};
