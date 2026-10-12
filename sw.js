// SUWATI MEN FASHION — Service Worker (Home Screen App)
// Page တွေကို အမြဲ Internet ကနေ အသစ်ယူသည် (Update တွေ ချက်ချင်း ရောက်ရန်)၊ Internet မရှိမှသာ Offline Page ပြသည်
// Supabase (Order/Stock/ငွေ) Data များကို လုံးဝ Cache မလုပ်ပါ
const CACHE = 'suwati-app-v2';
const OFFLINE_URL = '/offline.html';
const PRECACHE = [OFFLINE_URL, '/app-icon-192.png', '/app-icon-512.png', '/admin-icon-192.png'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return; // Supabase/CDN — ပုံမှန်အတိုင်း Network

  if (req.mode === 'navigate') {
    e.respondWith(fetch(req).catch(() => caches.match(OFFLINE_URL)));
    return;
  }
  if (/\/(app|admin)-icon-[\w-]+\.png$|apple-touch-icon\.png$/.test(url.pathname)) {
    e.respondWith(caches.match(req).then((hit) => hit || fetch(req)));
  }
});

// ---------- 🔔 Order / Stock Notification (Web Push) ----------
self.addEventListener('push', (e) => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (err) { d = { body: e.data ? e.data.text() : '' }; }
  const title = d.title || 'SUWATI MEN FASHION';
  e.waitUntil(self.registration.showNotification(title, {
    body: d.body || '',
    icon: '/app-icon-192.png',
    badge: '/app-icon-192.png',
    tag: d.tag || undefined,
    renotify: !!d.tag,
    data: { url: d.url || '/' }
  }));
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const target = new URL((e.notification.data && e.notification.data.url) || '/', self.location.origin).href;
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
    for (const c of list) {
      if (c.url.split('#')[0].split('?')[0] === target.split('#')[0].split('?')[0] && 'focus' in c) {
        try { c.postMessage({ type: 'suwati-push-open', url: target }); } catch (err) {}
        return c.focus();
      }
    }
    return self.clients.openWindow ? self.clients.openWindow(target) : null;
  }));
});
