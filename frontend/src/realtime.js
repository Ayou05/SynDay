const POLL_INTERVAL_MS = 12_000;

// GoEasy remains the server-side fan-out provider, but the mobile bundle must
// not download executable JavaScript from a CDN at runtime. Until the SDK is
// pinned as a local dependency, foreground consistency uses a low-frequency
// durable-notification poll. APNs/FCM/OPPO remain responsible for background
// delivery.
export async function connectRealtime(_userID, _channel, onEvent) {
  let stopped = false;
  let polling = false;
  const poll = () => {
    if (stopped || polling || !navigator.onLine) return;
    polling = true;
    Promise.resolve(onEvent({ event: "notification_poll", payload: {} }))
      .catch(() => {
        // The durable inbox will be retried by the next foreground poll.
      })
      .finally(() => {
        polling = false;
      });
  };
  const timer = window.setInterval(poll, POLL_INTERVAL_MS);
  window.addEventListener("online", poll);
  poll();

  return () => {
    stopped = true;
    window.clearInterval(timer);
    window.removeEventListener("online", poll);
  };
}
