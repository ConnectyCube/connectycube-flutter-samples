importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js");

firebase.initializeApp({
  apiKey: "...",
  authDomain: "...",
  databaseURL: "...",
  projectId: "...",
  storageBucket: "...",
  messagingSenderId: "...",
  appId: "...",
  measurementId: "..."
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((message) => {
  console.log("onBackgroundMessage", message);
    if (Notification.permission === "granted") {
      self.registration.showNotification('Connectycube Flutter Chat sample', {body: message.data.message})
    }

    else if (Notification.permission !== "denied") {
      Notification.requestPermission().then(function (permission) {
        if (permission === "granted") {
          self.registration.showNotification('Connectycube Flutter Chat sample', {body: message.data.message})
        }
      });
    }
});
