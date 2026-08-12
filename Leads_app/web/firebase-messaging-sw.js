// Firebase Cloud Messaging Service Worker
// This file is required in the /web directory for FCM to work on the web.
// It must be served at the root path: /firebase-messaging-sw.js

importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey:            'AIzaSyDlcfUvrHo9TPvC8TDY2F8rn5HCxwKCEos',
  appId:             '1:625049701631:web:ab17a375e2937eaf1f90ca',
  messagingSenderId: '625049701631',
  projectId:         'worktrack-7a319',
  authDomain:        'worktrack-7a319.firebaseapp.com',
  storageBucket:     'worktrack-7a319.firebasestorage.app',
  measurementId:     'G-8MVH5W61YC',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);

  const notificationTitle  = payload.notification?.title  ?? 'WorkTrack Notification';
  const notificationOptions = {
    body: payload.notification?.body ?? '',
    icon: '/icons/Icon-192.png',
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
