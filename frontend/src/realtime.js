import { config } from "./config.js";

let client = null;
let subscribedChannel = "";

function loadGoEasySDK() {
  if (window.GoEasy) return Promise.resolve(window.GoEasy);
  return new Promise((resolve, reject) => {
    const existing = document.querySelector('script[data-synday-goeasy="true"]');
    if (existing) {
      existing.addEventListener("load", () => resolve(window.GoEasy), { once: true });
      existing.addEventListener("error", reject, { once: true });
      return;
    }
    const script = document.createElement("script");
    script.src = "https://cdn.goeasy.io/goeasy-2.13.15.min.js";
    script.async = true;
    script.dataset.syndayGoeasy = "true";
    script.addEventListener("load", () => resolve(window.GoEasy), { once: true });
    script.addEventListener("error", reject, { once: true });
    document.head.append(script);
  });
}

export async function connectRealtime(userID, onEvent) {
  if (!config.goEasyAppKey || !userID) return () => {};
  const GoEasy = await loadGoEasySDK();
  client ||= GoEasy.getInstance({
    host: config.goEasyHost,
    appkey: config.goEasyAppKey,
    modules: ["pubsub"],
  });
  await new Promise((resolve, reject) => {
    client.connect({
      id: userID,
      onSuccess: resolve,
      onFailed: reject,
      onProgress: () => {},
    });
  });
  const channel = `user:${userID}`;
  if (subscribedChannel && subscribedChannel !== channel) {
    client.pubsub.unsubscribe({ channel: subscribedChannel });
  }
  subscribedChannel = channel;
  client.pubsub.subscribe({
    channel,
    onMessage: (message) => {
      try {
        onEvent(JSON.parse(message.content));
      } catch {
        onEvent({ event: "unknown", payload: { content: message.content } });
      }
    },
    onSuccess: () => {},
    onFailed: () => {},
  });
  return () => {
    if (subscribedChannel) {
      client?.pubsub.unsubscribe({ channel: subscribedChannel });
      subscribedChannel = "";
    }
  };
}

