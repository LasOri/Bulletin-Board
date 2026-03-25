const CACHE_NAME = 'bulletin-board-v8';
const WASM_URL = 'BulletinBoard.wasm';

const PRECACHE_URLS = [
    './',
    './index.html',
    './styles.css',
    './BulletinBoard.js',
    './BulletinBoard.wasm',
    './favicon.ico',
    './manifest.json'
];

self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME).then(cache => {
            console.log('[SW] Pre-caching app shell');
            return cache.addAll(PRECACHE_URLS);
        }).then(() => self.skipWaiting())
    );
});

self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys().then(names =>
            Promise.all(
                names.filter(name => name !== CACHE_NAME)
                    .map(name => {
                        console.log('[SW] Deleting old cache:', name);
                        return caches.delete(name);
                    })
            )
        ).then(() => self.clients.claim())
    );
});

self.addEventListener('fetch', event => {
    const url = new URL(event.request.url);

    if (event.request.method !== 'GET') {
        return;
    }

    if (url.origin !== self.location.origin) {
        return;
    }

    if (url.pathname.endsWith(WASM_URL) ||
        url.pathname.endsWith('.js') ||
        url.pathname.endsWith('.css') ||
        url.pathname.endsWith('.html') ||
        url.pathname.endsWith('/')) {
        event.respondWith(
            caches.match(event.request).then(cached => {
                if (cached) {
                    if (!url.pathname.endsWith(WASM_URL)) {
                        fetchAndCache(event.request);
                    }
                    return cached;
                }
                return fetchAndCache(event.request);
            })
        );
    }
});

function fetchAndCache(request) {
    return fetch(request).then(response => {
        if (response.ok) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then(cache => cache.put(request, clone));
        }
        return response;
    }).catch(() => caches.match(request));
}

self.addEventListener('message', event => {
    if (event.data && event.data.type === 'SKIP_WAITING') {
        self.skipWaiting();
    }
});

self.addEventListener('sync', event => {
    if (event.tag === 'sync-articles') {
        event.waitUntil(syncArticles());
    }
});

async function syncArticles() {
    console.log('[SW] Background sync: refreshing articles');
    const clients = await self.clients.matchAll();
    clients.forEach(client => {
        client.postMessage({ type: 'SYNC_ARTICLES' });
    });
}

