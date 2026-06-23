import {
  Importance,
  Schedule,
  Visibility,
  cancel,
  cancelAll,
  channels,
  createChannel,
  isPermissionGranted,
  onAction,
  requestPermission,
  sendNotification,
} from "@tauri-apps/plugin-notification";

const CHANNELS = [
  {
    id: "review",
    name: "每日复盘",
    description: "23:30 每日复盘提醒",
    importance: Importance.High,
    visibility: Visibility.Private,
    sound: "review_wood",
  },
  {
    id: "bedtime",
    name: "睡前提醒",
    description: "就寝前一小时的轻提醒",
    importance: Importance.Default,
    visibility: Visibility.Private,
    sound: "bedtime_bell",
  },
  {
    id: "partner_task",
    name: "伴侣完成任务",
    description: "伴侣完成一项任务",
    importance: Importance.Default,
    visibility: Visibility.Private,
    sound: "partner_task",
  },
  {
    id: "partner_join",
    name: "伴侣加入专注",
    description: "伴侣加入你的专注",
    importance: Importance.Default,
    visibility: Visibility.Private,
    sound: "partner_join",
  },
  {
    id: "streak",
    name: "连胜里程碑",
    description: "连胜里程碑提示",
    importance: Importance.Default,
    visibility: Visibility.Private,
    sound: "streak_milestone",
  },
];

export function isTauriRuntime() {
  return Boolean(window.__TAURI_INTERNALS__);
}

function mobilePlatform() {
  const userAgent = navigator.userAgent || "";
  if (/Android/i.test(userAgent)) return "android";
  if (
    /iPhone|iPad|iPod/i.test(userAgent) ||
    (/Macintosh/i.test(userAgent) && navigator.maxTouchPoints > 1)
  ) {
    return "ios";
  }
  return "desktop";
}

function soundResource(name) {
  return mobilePlatform() === "ios" ? `${name}.wav` : name;
}

export async function ensureNotificationPermission(prompt = false) {
  if (!isTauriRuntime()) return false;
  let granted = await isPermissionGranted();
  if (!granted && prompt) {
    granted = (await requestPermission()) === "granted";
  }
  return granted;
}

export async function configureNotificationChannels() {
  if (!isTauriRuntime() || mobilePlatform() !== "android") return;
  const existing = new Set((await channels()).map((channel) => channel.id));
  for (const channel of CHANNELS) {
    if (!existing.has(channel.id)) {
      await createChannel({
        ...channel,
        vibration: true,
        lights: false,
      });
    }
  }
}

export async function scheduleDailyReminders({
  bedtime,
  externalCheckinEnabled,
  reviewEnabled = true,
}) {
  if (!(await ensureNotificationPermission(false))) return false;
  await configureNotificationChannels();
  await Promise.allSettled([cancel([23_300]), cancel([23_301])]);

  if (reviewEnabled) {
    await sendNotification({
      id: 23_300,
      title: externalCheckinEnabled ? "该完成今天的学习复盘了" : "今天的复盘已经准备好",
      body: externalCheckinEnabled ? "整理后即可复制到外部打卡。" : "用几分钟看看今天发生了什么。",
      channelId: "review",
      sound: soundResource("review_wood"),
      schedule: Schedule.interval({ hour: 23, minute: 30 }, true),
      extra: { route: "review" },
    });
  }

  if (bedtime) {
    const [hour, minute] = bedtime.split(":").map(Number);
    await sendNotification({
      id: 23_301,
      title: "离计划休息还有一小时",
      body: "如果今天还有想完成的事，现在只选最重要的一项。",
      channelId: "bedtime",
      sound: soundResource("bedtime_bell"),
      schedule: Schedule.interval({ hour: (hour + 23) % 24, minute }, true),
      extra: { route: "today" },
    });
  }
  return true;
}

export async function listenForNotificationActions(onRoute) {
  if (!isTauriRuntime()) return () => {};
  const listener = await onAction((notification) => {
    const route = notification.extra?.route;
    if (typeof route === "string") onRoute(route);
  });
  return () => listener.unregister();
}

export async function clearScheduledNotifications() {
  if (!isTauriRuntime()) return;
  await cancelAll();
}
