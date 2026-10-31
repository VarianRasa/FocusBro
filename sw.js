// Service Worker for FocusBro Documentation
const CACHE_NAME = 'focusbro-docs-v1.0.0';
const OFFLINE_URL = '/offline.html';

// Files to cache for offline functionality
const CACHE_FILES = [
  '/',
  '/index.html',
  '/docs/getting-started.html',
  '/docs/features.html',
  '/docs/user-guide.html',
  '/docs/faq.html',
  '/docs/troubleshooting.html',
  '/privacy.html',
  '/terms.html',
  '/changelog.html',
  '/gallery.html',
  '/offline.html',
  '/assets/css/style.css',
  '/assets/css/responsive.css',
  '/assets/js/main.js',
  '/assets/images/focusbro-logo.png',
  '/assets/images/favicon.png',
  '/manifest.json'
];

// Install event - cache files
self.addEventListener('install', event => {
  console.log('Service Worker: Installing...');
  
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('Service Worker: Caching files');
        return cache.addAll(CACHE_FILES);
      })
      .then(() => {
        console.log('Service Worker: Cached all files successfully');
        return self.skipWaiting();
      })
      .catch(error => {
        console.error('Service Worker: Cache failed', error);
      })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', event => {
  console.log('Service Worker: Activating...');
  
  event.waitUntil(
    caches.keys()
      .then(cacheNames => {
        return Promise.all(
          cacheNames.map(cacheName => {
            if (cacheName !== CACHE_NAME) {
              console.log('Service Worker: Deleting old cache', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      })
      .then(() => {
        console.log('Service Worker: Activated successfully');
        return self.clients.claim();
      })
  );
});

// Fetch event - serve cached files when offline
self.addEventListener('fetch', event => {
  // Skip non-GET requests
  if (event.request.method !== 'GET') {
    return;
  }

  // Skip external requests
  if (!event.request.url.startsWith(self.location.origin)) {
    return;
  }

  event.respondWith(
    caches.match(event.request)
      .then(cachedResponse => {
        // Return cached version if available
        if (cachedResponse) {
          console.log('Service Worker: Serving from cache', event.request.url);
          return cachedResponse;
        }

        // Try to fetch from network
        return fetch(event.request)
          .then(response => {
            // Check if response is valid
            if (!response || response.status !== 200 || response.type !== 'basic') {
              return response;
            }

            // Clone response for caching
            const responseToCache = response.clone();

            // Add to cache for future use
            caches.open(CACHE_NAME)
              .then(cache => {
                cache.put(event.request, responseToCache);
              });

            console.log('Service Worker: Fetched and cached', event.request.url);
            return response;
          })
          .catch(error => {
            console.log('Service Worker: Fetch failed, serving offline page', error);
            
            // Serve offline page for navigation requests
            if (event.request.destination === 'document') {
              return caches.match(OFFLINE_URL);
            }
            
            // For other requests, just fail
            throw error;
          });
      })
  );
});

// Background sync for analytics (when online)
self.addEventListener('sync', event => {
  if (event.tag === 'analytics-sync') {
    event.waitUntil(syncAnalytics());
  }
});

// Push notifications (for future updates)
self.addEventListener('push', event => {
  if (event.data) {
    const data = event.data.json();
    const options = {
      body: data.body,
      icon: '/assets/images/icon-192x192.png',
      badge: '/assets/images/icon-72x72.png',
      vibrate: [100, 50, 100],
      data: {
        dateOfArrival: Date.now(),
        primaryKey: data.primaryKey
      },
      actions: [
        {
          action: 'explore',
          title: 'View Update',
          icon: '/assets/images/icon-96x96.png'
        },
        {
          action: 'close',
          title: 'Close',
          icon: '/assets/images/icon-96x96.png'
        }
      ]
    };

    event.waitUntil(
      self.registration.showNotification(data.title, options)
    );
  }
});

// Notification click handler
self.addEventListener('notificationclick', event => {
  event.notification.close();

  if (event.action === 'explore') {
    event.waitUntil(
      clients.openWindow('/')
    );
  }
});

// Helper function to sync analytics data
async function syncAnalytics() {
  try {
    // Get stored analytics data
    const cache = await caches.open('analytics-cache');
    const requests = await cache.keys();
    
    // Send each analytics request
    for (const request of requests) {
      try {
        await fetch(request);
        await cache.delete(request);
        console.log('Service Worker: Analytics synced');
      } catch (error) {
        console.log('Service Worker: Analytics sync failed, will retry');
      }
    }
  } catch (error) {
    console.error('Service Worker: Analytics sync error', error);
  }
}

// Message handler for communication with main thread
self.addEventListener('message', event => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  
  if (event.data && event.data.type === 'GET_VERSION') {
    event.ports[0].postMessage({ version: CACHE_NAME });
  }
});

// Periodic background sync (for browsers that support it)
self.addEventListener('periodicsync', event => {
  if (event.tag === 'content-sync') {
    event.waitUntil(syncContent());
  }
});

// Helper function to sync content updates
async function syncContent() {
  try {
    // Check for content updates
    const response = await fetch('/api/version');
    const data = await response.json();
    
    if (data.version !== CACHE_NAME) {
      // New version available, update cache
      const cache = await caches.open(CACHE_NAME);
      await cache.addAll(CACHE_FILES);
      console.log('Service Worker: Content updated');
    }
  } catch (error) {
    console.log('Service Worker: Content sync failed');
  }
}
