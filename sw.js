// Offline cache. Bump VERSION at each release so players get the new files (and VERSION in js/main.js with it).
const VERSION = 'jungle-loop-0.19.0';
// The code is fetched up front; images and music are kept as the game asks for them,
// so this list never has to follow the art.
const FILES = ['./', 'index.html', 'style.css', 'icon.svg', 'manifest.webmanifest',
  'js/main.js', 'js/game.js', 'js/render.js', 'js/audio.js', 'js/save.js', 'js/progress.js', 'js/ambient.js', 'js/demo.js', 'js/debug.js'];

self.addEventListener('install', (e) => {
  // straight from the server, never from the browser's own cache: that one may still hold the old files
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(FILES.map((f) => new Request(f, { cache: 'reload' })))).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  // lists anyone may edit (coin patterns, music): the network first, the kept copy only when offline
  if (/\.(txt|json)$/.test(new URL(e.request.url).pathname)) {
    e.respondWith(fetch(e.request).then((res) => { const copy = res.clone(); caches.open(VERSION).then((c) => c.put(e.request, copy)); return res; }).catch(() => caches.match(e.request, { ignoreSearch: true })));
    return;
  }
  const art = new URL(e.request.url).pathname.includes('/assets/');
  // a picture or a sound not yet kept: checked with the server, in case the browser's cache holds an older one
  e.respondWith(caches.match(e.request, { ignoreSearch: true }).then((hit) => hit || fetch(art ? new Request(e.request, { cache: 'no-cache' }) : e.request).then((res) => {
    if (res.status === 200 && art) {                     // (the music player asks for pieces of a file: those are not kept)
      const copy = res.clone();
      caches.open(VERSION).then((c) => c.put(e.request, copy));
    }
    return res;
  })));
});
