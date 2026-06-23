import { currentSession } from "./auth.js";
import { config } from "./config.js";

export class APIError extends Error {
  constructor(message, status, body) {
    super(message);
    this.name = "APIError";
    this.status = status;
    this.body = body;
  }
}

export async function api(path, options = {}) {
  const session = await currentSession();
  if (!session?.access_token) {
    throw new APIError("登录已失效", 401);
  }

  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), 15_000);
  let response;
  try {
    response = await fetch(`${config.apiBaseUrl}${path}`, {
      ...options,
      signal: options.signal || controller.signal,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${session.access_token}`,
        ...options.headers,
      },
    });
  } catch (error) {
    throw new APIError(
      error?.name === "AbortError" ? "网络响应超时，请稍后重试" : "网络波动，请稍后重试",
      0,
    );
  } finally {
    window.clearTimeout(timeout);
  }

  let body = null;
  if (response.status !== 204) {
    const text = await response.text();
    if (text) {
      try {
        body = JSON.parse(text);
      } catch {
        body = { error: response.ok ? "服务返回了无法识别的内容" : "服务暂时不可用" };
      }
    }
  }
  if (!response.ok) {
    throw new APIError(body?.error || "请求失败", response.status, body);
  }
  return body;
}

export const apiClient = {
  today: () => api("/v1/today"),
  markMilestoneSeen: (milestone) =>
    api(`/v1/streak/milestones/${milestone}/seen`, {
      method: "POST",
      body: "{}",
    }),
  createTask: (input) =>
    api("/v1/tasks", {
      method: "POST",
      body: JSON.stringify(input),
    }),
  updateTask: (id, input) =>
    api(`/v1/tasks/${encodeURIComponent(id)}`, {
      method: "PATCH",
      body: JSON.stringify(input),
    }),
  deleteTask: (id) =>
    api(`/v1/tasks/${encodeURIComponent(id)}`, {
      method: "DELETE",
    }),
  startFocus: (input) =>
    api("/v1/focus/start", {
      method: "POST",
      body: JSON.stringify(input),
    }),
  activeFocus: () => api("/v1/focus/active"),
  stopFocus: (operationId) =>
    api("/v1/focus/stop", {
      method: "POST",
      body: JSON.stringify({ operation_id: operationId }),
    }),
  joinFocus: (input) =>
    api("/v1/focus/join", {
      method: "POST",
      body: JSON.stringify(input),
    }),
  partner: () => api("/v1/couple/partner"),
  coupleReport: (month) => api(`/v1/couple/reports?month=${encodeURIComponent(month)}`),
  createPairing: () => api("/v1/couple/pairings", { method: "POST", body: "{}" }),
  claimPairing: (input) =>
    api("/v1/couple/pairings/claim", { method: "POST", body: JSON.stringify(input) }),
  confirmPairing: (pairingId) =>
    api(`/v1/couple/pairings/${encodeURIComponent(pairingId)}/confirm`, {
      method: "POST",
      body: "{}",
    }),
  review: (date) => api(`/v1/reviews/current${date ? `?date=${encodeURIComponent(date)}` : ""}`),
  updateReview: (id, input) =>
    api(`/v1/reviews/${encodeURIComponent(id)}`, {
      method: "PUT",
      body: JSON.stringify(input),
    }),
  calendar: (month) => api(`/v1/calendar?month=${encodeURIComponent(month)}`),
  plans: () => api("/v1/plans"),
  createPlan: (input) =>
    api("/v1/plans", {
      method: "POST",
      body: JSON.stringify(input),
    }),
  updatePlan: (id, input) =>
    api(`/v1/plans/${encodeURIComponent(id)}`, {
      method: "PUT",
      body: JSON.stringify(input),
    }),
  disablePlan: (id) =>
    api(`/v1/plans/${encodeURIComponent(id)}`, {
      method: "DELETE",
    }),
  settings: () => api("/v1/settings"),
  updateSettings: (input) =>
    api("/v1/settings", {
      method: "PUT",
      body: JSON.stringify(input),
    }),
  createLeave: (input) =>
    api("/v1/settings/leave-days", {
      method: "POST",
      body: JSON.stringify(input),
    }),
  deleteLeave: (id) =>
    api(`/v1/settings/leave-days/${encodeURIComponent(id)}`, {
      method: "DELETE",
    }),
  notifications: () => api("/v1/notifications"),
  markNotificationRead: (id) =>
    api(`/v1/notifications/${encodeURIComponent(id)}/read`, {
      method: "PUT",
      body: "{}",
    }),
  registerDevice: (input) =>
    api("/v1/devices/current", {
      method: "PUT",
      body: JSON.stringify(input),
    }),
  unregisterDevice: (deviceId) =>
    api(`/v1/devices/current?device_id=${encodeURIComponent(deviceId)}`, {
      method: "DELETE",
    }),
  realtimeSession: () => api("/v1/realtime/session"),
  unbindCouple: () =>
    api("/v1/couple/binding", {
      method: "DELETE",
    }),
  requestAccountDeletion: () =>
    api("/v1/account", {
      method: "DELETE",
    }),
  cancelAccountDeletion: () =>
    api("/v1/account/deletion/cancel", {
      method: "POST",
      body: "{}",
    }),
};
