// Minimal service worker: makes the app installable and lets the shell
// (this page, its manifest, its icons) keep loading if you're offline.
// Anything cross-origin -- your Supabase project's API, Google Fonts, the
// supabase-js CDN script -- is left completely alone: this only ever
// intercepts requests back to the same site the page was loaded from, so
// sign-in and data calls are never cached or delayed.
//
// Network-first: every request tries the network first, so a fresh
// deploy shows up the moment you reload -- the cache is only a fallback
// for when there's no connection at all. (An earlier cache-first version
// of this file could show a stale, already-fixed bug for a visit or two
// after every update -- this avoids that.)

var CACHE_NAME = "layover-ledger-v2";
var APP_SHELL = ["./", "./index.html", "./manifest.json"];

self.addEventListener("install", function (event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function (cache) {
      return cache.addAll(APP_SHELL);
    })
  );
  self.skipWaiting();
});

self.addEventListener("activate", function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(
        keys.filter(function (k) { return k !== CACHE_NAME; })
          .map(function (k) { return caches.delete(k); })
      );
    })
  );
  self.clients.claim();
});

self.addEventListener("fetch", function (event) {
  var req = event.request;
  if (req.method !== "GET" || req.url.indexOf(self.location.origin) !== 0) {
    return; // cross-origin (Supabase, fonts, CDN) or non-GET: let the browser handle it normally
  }
  event.respondWith(
    fetch(req).then(function (res) {
      if (res && res.ok) {
        var copy = res.clone();
        caches.open(CACHE_NAME).then(function (cache) { cache.put(req, copy); });
      }
      return res;
    }).catch(function () {
      return caches.match(req);
    })
  );
});
