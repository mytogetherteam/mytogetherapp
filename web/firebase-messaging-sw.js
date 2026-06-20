/* Firebase Cloud Messaging service worker for PWA background push. */
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDvyZGjQsgZuZ5VT3wmqAI0edN040x_FxM',
  authDomain: 'mytogether-daf3f.firebaseapp.com',
  projectId: 'mytogether-daf3f',
  storageBucket: 'mytogether-daf3f.firebasestorage.app',
  messagingSenderId: '972280179999',
  appId: '1:972280179999:web:2948e4ee866168ad69542a',
});

const messaging = firebase.messaging();
const ALERT_CACHE = 'mytogether-payment-alerts-v1';

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

function assetUrl(path) {
  return self.location.origin + '/' + path.replace(/^\//, '');
}

function iconUrl() {
  return assetUrl('icons/Icon-192.png');
}

function alertSoundUrl() {
  return assetUrl('sounds/warning.mp3');
}

function normalizePayload(payload) {
  const data = payload.data || {};
  const type = data.type || data.notificationType || payload.type;
  const subType = data.subType || data.sub_type || payload.subType;
  const isPaymentAlert =
    type === 'PAYMENT_REMINDER' ||
    subType === 'PAYMENT_SLIP_REQUEST_ORDER';
  const orderId =
    data.referenceId ||
    data.orderId ||
    data.order_id ||
    payload.referenceId ||
    payload.orderId ||
    'payment';
  const title =
    payload.notification?.title ||
    data.title ||
    (isPaymentAlert ? 'Payment Required' : 'MyTogether');
  const body =
    payload.notification?.body ||
    data.body ||
    data.message ||
    (isPaymentAlert
      ? 'Please upload your payment slip.'
      : 'You have a new update.');

  return {
    title: title,
    body: body,
    isPaymentAlert: isPaymentAlert,
    orderId: orderId,
    data: Object.assign({}, data, {
      type: type || data.type,
      subType: subType || data.subType,
      referenceId: orderId,
      orderId: orderId,
      title: title,
      body: body,
    }),
  };
}

function storePendingPaymentAlert(orderId) {
  var payload = JSON.stringify({
    orderId: orderId || 'payment',
    at: Date.now(),
  });

  return caches
    .open(ALERT_CACHE)
    .then(function (cache) {
      return cache.put(
        new Request('pending-payment-alert'),
        new Response(payload, { headers: { 'Content-Type': 'application/json' } })
      );
    })
    .catch(function (err) {
      console.log('[firebase-messaging-sw.js] store pending alert failed', err);
    });
}

function buildNotificationPayload(payload) {
  const normalized = normalizePayload(payload);

  return {
    title: normalized.title,
    body: normalized.body,
    isPaymentAlert: normalized.isPaymentAlert,
    orderId: normalized.orderId,
    options: {
      body: normalized.body,
      icon: iconUrl(),
      badge: iconUrl(),
      data: normalized.data,
      tag: normalized.isPaymentAlert
        ? 'payment-' + normalized.orderId
        : 'mytogether-update',
      requireInteraction: normalized.isPaymentAlert,
      silent: false,
      renotify: true,
      vibrate: normalized.isPaymentAlert
        ? [400, 200, 400, 200, 400]
        : [200, 100, 200],
    },
  };
}

function notifyOpenClients(title, body, orderId) {
  return self.clients
    .matchAll({ type: 'window', includeUncontrolled: true })
    .then(function (clientList) {
      clientList.forEach(function (client) {
        client.postMessage({
          type: 'PAYMENT_ALERT',
          orderId: orderId,
          title: title,
          body: body,
        });
      });
    });
}

function tryPlayAlertSoundInServiceWorker() {
  try {
    var audio = new Audio(alertSoundUrl());
    audio.loop = true;
    return audio.play().catch(function (err) {
      console.log('[firebase-messaging-sw.js] SW audio blocked:', err);
    });
  } catch (err) {
    console.log('[firebase-messaging-sw.js] SW audio unavailable:', err);
    return Promise.resolve();
  }
}

function showPushNotification(payload) {
  const built = buildNotificationPayload(payload);
  const tasks = [self.registration.showNotification(built.title, built.options)];

  if (built.isPaymentAlert) {
    tasks.push(storePendingPaymentAlert(built.orderId));
    tasks.push(notifyOpenClients(built.title, built.body, built.orderId));
    tasks.push(tryPlayAlertSoundInServiceWorker());
  }

  return Promise.all(tasks);
}

messaging.onBackgroundMessage(function (payload) {
  console.log('[firebase-messaging-sw.js] onBackgroundMessage', payload);
  return showPushNotification(payload);
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  const data = event.notification.data || {};
  const orderId =
    data.referenceId || data.orderId || data.order_id || null;
  const targetUrl = self.location.origin + '/';

  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then(function (clientList) {
        for (var i = 0; i < clientList.length; i++) {
          var client = clientList[i];
          if (
            client.url.indexOf(self.location.origin) === 0 &&
            'focus' in client
          ) {
            client.postMessage({
              type: 'PAYMENT_ALERT',
              orderId: orderId,
              fromNotificationClick: true,
            });
            return client.focus();
          }
        }

        if (clients.openWindow) {
          return clients.openWindow(targetUrl).then(function (client) {
            if (client) {
              client.postMessage({
                type: 'PAYMENT_ALERT',
                orderId: orderId,
                fromNotificationClick: true,
              });
            }
          });
        }
      })
  );
});
