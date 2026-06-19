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

messaging.onBackgroundMessage((payload) => {
  const title =
    payload.notification?.title || payload.data?.title || 'MyTogether';
  const body =
    payload.notification?.body ||
    payload.data?.body ||
    payload.data?.message ||
    '';
  const options = {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
  };
  return self.registration.showNotification(title, options);
});
