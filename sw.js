const CACHE_NAME = 'bulletin-board-v7';
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

    if (url.pathname.endsWith(WASM_URL) ||
        url.pathname.endsWith('.js') ||
        url.pathname.endsWith('.css') ||
        url.pathname.endsWith('.html') ||
        url.pathname.endsWith('/')) {
        event.respondWith(
            caches.match(event.request).then(cached => {
                if (cached) {
                    console.log('[SW] Cache hit:', url.pathname);
                    if (!url.pathname.endsWith(WASM_URL)) {
                        fetchAndCache(event.request);
                    }
                    return cached;
                }
                return fetchAndCache(event.request);
            })
        );
    }

    else if (url.origin === self.location.origin && url.pathname.startsWith('/api/')) {
        event.respondWith(
            fetch(event.request)
                .then(response => {
                    if (response.ok) {
                        const clone = response.clone();
                        caches.open(CACHE_NAME + '-api').then(cache => cache.put(event.request, clone));
                    }
                    return response;
                })
                .catch(() => {
                    return caches.match(event.request).then(cached => {
                        if (cached) {
                            console.log('[SW] Offline: serving cached API response');
                            return cached;
                        }
                        return new Response(
                            JSON.stringify({ error: 'Offline', offline: true }),
                            { headers: { 'Content-Type': 'application/json' } }
                        );
                    });
                })
        );
    }

    else if (url.hostname !== self.location.hostname) {
        const isFeedURL = url.pathname.endsWith('.xml') ||
            url.pathname.endsWith('/feed') ||
            url.pathname.endsWith('/rss') ||
            url.pathname.includes('/feeds/') ||
            url.pathname.includes('/frontpage');

        if (!isFeedURL) return;

        event.respondWith(
            fetch(event.request)
                .then(response => {
                    if (response.ok) {
                        const clone = response.clone();
                        caches.open(CACHE_NAME + '-feeds').then(cache => cache.put(event.request, clone));
                    }
                    return response;
                })
                .catch(() => {
                    return caches.match(event.request).then(cached => {
                        if (cached) {
                            console.log('[SW] Offline: serving cached feed');
                            return cached;
                        }
                        return new Response('Feed not available offline', { status: 503 });
                    });
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

