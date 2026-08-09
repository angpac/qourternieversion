self.addEventListener("push", (event) => {
  let data = { title: "Qourt", body: "" };
  try {
    data = event.data.json();
  } catch {
    // ignore malformed payloads
  }
  event.waitUntil(
    self.registration.showNotification(data.title || "Qourt", {
      body: data.body || "",
      icon: "/icon.png",
    })
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow("/status"));
});
