import "./styles.css";
import QRCode from "qrcode";
import { invoke } from "@tauri-apps/api/core";
import { apiClient } from "./api.js";
import { currentSession, signIn, signOut, signUp } from "./auth.js";
import { cacheToday, db, enqueueOperation, readCachedToday } from "./db.js";
import { startSyncLoop } from "./sync.js";
import { connectRealtime } from "./realtime.js";
import { config } from "./config.js";
import {
  clearScheduledNotifications,
  ensureNotificationPermission,
  listenForNotificationActions,
  scheduleDailyReminders,
} from "./notifications.js";

const app = document.querySelector("#app");

const state = {
  session: null,
  route: "today",
  loading: true,
  online: navigator.onLine,
  today: {
    tasks: [],
    summary: {
      total_tasks: 0,
      completed_tasks: 0,
      completion_percent: 0,
      focus_seconds: 0,
      current_streak: 0,
    },
  },
  taskComposerOpen: false,
  authMode: "signin",
  message: "",
  focus: null,
  focusTicker: null,
  partner: null,
  pairing: null,
  review: null,
  settings: null,
  scannerOpen: false,
  scannerStream: null,
  scannerFrame: null,
  plans: [],
  planComposerOpen: false,
  editingPlan: null,
  calendar: null,
  reviewDate: "",
  coupleReport: null,
  dangerMode: "",
  autoStoppingFocus: false,
  taskMenuID: "",
  notifications: [],
  disconnectRealtime: null,
  disconnectNotificationActions: null,
  pendingBackgroundRender: false,
  loadingRoute: false,
  savingSettings: false,
};

function seedPreviewState() {
  state.today = {
    tasks: [
      {
        id: "preview-1",
        title: "精读 CATTI 二笔真题一篇",
        category: "course",
        planned_time: "09:30:00",
        status: "completed",
        is_pinned: true,
        version: 2,
        encouragement: "难句拆开之后，路就清楚了。",
      },
      {
        id: "preview-2",
        title: "复习核心词组 40 个",
        category: "self_study",
        planned_time: "14:00:00",
        status: "pending",
        is_pinned: false,
        version: 1,
      },
      {
        id: "preview-3",
        title: "完成汉译英段落练习",
        category: "temporary",
        planned_time: null,
        status: "pending",
        is_pinned: false,
        version: 1,
      },
    ],
    summary: {
      total_tasks: 3,
      completed_tasks: 1,
      completion_percent: 33,
      focus_seconds: 3240,
      current_streak: 18,
      pending_milestone: 0,
    },
  };
  state.partner = {
    display_name: "嘉",
    completion_percent: 67,
    current_streak: 23,
    is_focusing: true,
    focus_started_at: new Date(Date.now() - 28 * 60 * 1000).toISOString(),
    focus_room_id: "preview-room",
    tasks: [
      { id: "p1", title: "听写新闻材料", status: "completed" },
      { id: "p2", title: "复盘错题", status: "completed" },
      { id: "p3", title: "视译练习 20 分钟", status: "pending" },
    ],
  };
  state.review = {
    id: "preview-review",
    business_date: businessDateString(),
    title: "2026年06月23日 每日学习复盘",
    full_text:
      "今日完成 1 项任务，累计专注 54 分钟。\n\n课程任务中的真题精读已经完成，重点难句完成了拆分与回看。\n\n尚未完成的两项任务集中在下午，可能与连续学习后的注意力回落有关。\n\n明天先完成一段汉译英，再进入词组复习。",
  };
  state.calendar = {
    month: "2026-06-01",
    days: Array.from({ length: 22 }, (_, index) => ({
      business_date: `2026-06-${String(index + 1).padStart(2, "0")}`,
      qualified: ![4, 11, 17].includes(index + 1),
      exempt: [7, 14, 21].includes(index + 1),
    })),
  };
  state.settings = {
    settings: {
      display_name: "Kyle",
      ai_tone: "restrained",
      external_checkin_enabled: true,
      bedtime: "00:30:00",
      notification_review_enabled: true,
      notification_bedtime_enabled: true,
      notification_partner_enabled: true,
      notification_streak_enabled: true,
    },
    leave_days: [],
  };
  state.plans = [
    {
      id: "preview-plan",
      title: "CATTI 真题精读",
      category: "course",
      recurrence: "daily",
      weekdays: [],
      planned_time: "09:30:00",
      starts_on: "2026-06-23",
      is_active: true,
    },
  ];
}

function escapeHTML(value = "") {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function formatSeconds(totalSeconds = 0) {
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  return hours
    ? `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`
    : `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

function dateHeading(date = businessDateString()) {
  const parsed = /^\d{4}-\d{2}-\d{2}$/.test(date)
    ? new Date(`${date}T12:00:00+08:00`)
    : new Date(Date.now() - 4 * 60 * 60 * 1000);
  return new Intl.DateTimeFormat("zh-CN", {
    timeZone: "Asia/Shanghai",
    year: "numeric",
    month: "long",
    day: "numeric",
    weekday: "long",
  }).format(parsed);
}

function businessDateString(now = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Shanghai",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date(now.getTime() - 4 * 60 * 60 * 1000));
  const value = (type) => parts.find((part) => part.type === type)?.value || "";
  return `${value("year")}-${value("month")}-${value("day")}`;
}

function currentMonthStart() {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Shanghai",
    year: "numeric",
    month: "2-digit",
  }).formatToParts(new Date(Date.now() - 4 * 60 * 60 * 1000));
  const year = parts.find((part) => part.type === "year").value;
  const month = parts.find((part) => part.type === "month").value;
  return `${year}-${month}-01`;
}

function recalculateSummary() {
  const total = state.today.tasks.length;
  const completed = state.today.tasks.filter((task) => task.status === "completed").length;
  state.today.summary.total_tasks = total;
  state.today.summary.completed_tasks = completed;
  state.today.summary.completion_percent = total ? Math.round((completed / total) * 100) : 0;
}

function userIsEditing() {
  return document.activeElement?.matches("input, textarea, select") || false;
}

function renderBackgroundUpdate() {
  if (userIsEditing()) {
    state.pendingBackgroundRender = true;
    return;
  }
  state.pendingBackgroundRender = false;
  render();
}

async function loadToday() {
  state.today = await readCachedToday();
  recalculateSummary();
  render();
  if (!navigator.onLine || !state.session) return;
  state.loadingRoute = true;
  render();
  try {
    const payload = await apiClient.today();
    state.today = payload;
    await cacheToday(payload);
  } catch (error) {
    state.message = error.message;
  }
  state.loadingRoute = false;
  recalculateSummary();
  render();
}

async function restoreActiveFocus() {
  if (!state.session) return;
  if (navigator.onLine) {
    try {
      state.focus = await apiClient.activeFocus();
      await db.focusSessions.put(state.focus);
      startFocusTicker();
      return;
    } catch (error) {
      if (error.status !== 404) state.message = error.message;
    }
  }
  const local = await db.focusSessions.where("status").equals("active").last();
  if (local) {
    state.focus = local;
    startFocusTicker();
  }
}

function deviceID() {
  let id = localStorage.getItem("synday-device-id");
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem("synday-device-id", id);
  }
  return id;
}

async function registerPendingPushToken() {
  if (!state.session || !navigator.onLine) return;
  const token = localStorage.getItem("synday-apns-token");
  if (!token) return;
  try {
    await apiClient.registerDevice({
      platform: "ios",
      provider: "apns",
      token,
      device_id: deviceID(),
    });
  } catch {
    // Retried on the next app launch or network recovery.
  }
}

function authView() {
  const signingUp = state.authMode === "signup";
  return `
    <main class="auth-shell">
      <section class="auth-brand">
        <p class="brand-mark" aria-hidden="true">朝 · 夕</p>
        <h1>SynDay<br />朝夕同序</h1>
        <p>把自己的节奏守好，也知道有人正与你一起。</p>
      </section>
      <section class="auth-panel">
        <h2>${signingUp ? "创建账号" : "欢迎回来"}</h2>
        <form id="auth-form" class="form-stack">
          ${
            signingUp
              ? `<label>昵称<input name="displayName" autocomplete="nickname" maxlength="30" required /></label>`
              : ""
          }
          <label>邮箱<input name="email" type="email" autocomplete="email" required /></label>
          <label>密码<input name="password" type="password" autocomplete="${
            signingUp ? "new-password" : "current-password"
          }" minlength="8" required /></label>
          <button class="primary-button" type="submit">${signingUp ? "创建并进入" : "登录"}</button>
        </form>
        <button id="toggle-auth" class="text-button auth-switch" type="button">
          ${signingUp ? "已有账号，直接登录" : "第一次使用？创建账号"}
        </button>
        ${state.message ? `<p class="inline-message error" role="alert">${escapeHTML(state.message)}</p>` : ""}
      </section>
    </main>
  `;
}

function taskRow(task) {
  const complete = task.status === "completed";
  const encouragement = task.encouragement || "今天的进度已经留下。";
  return `
    <li class="task-item ${complete ? "is-complete" : ""}" data-task-id="${escapeHTML(task.id)}">
      <button
        class="task-check"
        data-action="toggle-task"
        type="button"
        role="checkbox"
        aria-label="${complete ? "撤销完成" : "标记完成"}：${escapeHTML(task.title)}"
        aria-checked="${complete}"
      >${complete ? "✓" : ""}</button>
      <div>
        <p class="task-title">${escapeHTML(task.title)}</p>
        <div class="task-meta">${escapeHTML(categoryName(task.category))}${
          task.planned_time ? ` · ${escapeHTML(task.planned_time.slice(0, 5))}` : " · 全天"
        }</div>
      </div>
      <button class="more-button" data-action="open-task-menu" type="button" aria-label="任务操作">···</button>
      <div class="ai-inline" aria-live="polite">${escapeHTML(encouragement)}</div>
      ${
        state.taskMenuID === task.id
          ? `<div class="task-inline-actions">
              <button class="text-button" data-action="pin-task" type="button">${task.is_pinned ? "取消置顶" : "置顶任务"}</button>
              ${task.status === "pending" ? `<button class="text-button danger-text" data-action="delete-task" type="button">删除</button>` : ""}
              <button class="text-button" data-action="close-task-menu" type="button">收起</button>
            </div>`
          : ""
      }
    </li>
  `;
}

function categoryName(category) {
  return {
    course: "课程任务",
    self_study: "自主学习",
    temporary: "临时新增",
  }[category] || category;
}

function taskComposer() {
  if (!state.taskComposerOpen) return "";
  return `
    <form id="task-form" class="inline-composer">
      <div class="composer-heading">
        <h3>新增今日任务</h3>
        <button type="button" class="text-button" data-action="close-composer">收起</button>
      </div>
      <label>
        任务名称
        <input name="title" maxlength="200" placeholder="准备完成什么？" required autofocus />
      </label>
      <div class="form-row">
        <label>
          类型
          <select name="category">
            <option value="course">课程任务</option>
            <option value="self_study">自主学习</option>
            <option value="temporary">临时新增</option>
          </select>
        </label>
        <label>
          时间（可选）
          <input name="plannedTime" type="time" />
        </label>
      </div>
      <button class="primary-button" type="submit">加入今天</button>
    </form>
  `;
}

function todayView() {
  const summary = state.today.summary;
  return `
    <header class="topbar">
      <div>
        <p class="eyebrow">${dateHeading()}</p>
        <h1>今天，也稳稳向前。</h1>
      </div>
      <span class="connection-dot ${state.online ? "is-online" : ""}" aria-label="${
        state.online ? "网络正常" : "离线模式"
      }"></span>
    </header>
    ${
      summary.pending_milestone
        ? `<section class="milestone-card">
            <div><p class="eyebrow">里程碑</p><strong>${summary.pending_milestone} 天</strong><span>你已经把坚持变成了一种生活节奏。</span></div>
            <button class="text-button" data-action="dismiss-milestone" data-milestone="${summary.pending_milestone}" type="button">收下</button>
          </section>`
        : ""
    }

    <section class="summary-grid" aria-label="今日概览">
      <article class="summary-card">
        <span class="summary-label">今日完成率</span>
        <strong class="summary-value">${summary.completion_percent || 0}%</strong>
      </article>
      <article class="summary-card">
        <span class="summary-label">连续打卡</span>
        <strong class="summary-value">🔥 ${summary.current_streak || 0}天</strong>
      </article>
    </section>

    <section aria-labelledby="today-heading">
      <div class="section-header">
        <h2 id="today-heading">今日待办</h2>
        <button class="text-button" data-action="open-composer" type="button">新增任务</button>
      </div>
      ${taskComposer()}
      ${
        state.today.tasks.length
          ? `<ul class="task-list">${state.today.tasks.map(taskRow).join("")}</ul>`
          : `<div class="empty-state"><p>今天还没有任务。</p><span>先放下一件真正想完成的事。</span></div>`
      }
    </section>

    <button class="focus-card" data-route="focus" type="button">
      <span>
        <strong>开始一段专注</strong>
        <small>${state.focus ? `正在专注 · ${formatSeconds(focusElapsed())}` : "TA 目前不在专注中"}</small>
      </span>
      <span aria-hidden="true">→</span>
    </button>
  `;
}

function focusElapsed() {
  if (!state.focus) return 0;
  return Math.max(0, Math.floor((Date.now() - new Date(state.focus.started_at).getTime()) / 1000));
}

function focusView() {
  if (state.focus) {
    const elapsed = focusElapsed();
    const planned = state.focus.planned_seconds;
    const remaining = planned ? Math.max(0, planned - elapsed) : elapsed;
    return `
      <section class="focus-session-screen">
        <p class="eyebrow">${state.focus.share_with_partner ? "伴侣可以看到你正在专注" : "本次暂不共享"}</p>
        <h1>${planned ? "保持在此刻" : "专注正在发生"}</h1>
        <time class="focus-time" aria-live="off">${formatSeconds(remaining)}</time>
        <p class="focus-support">${elapsed < 60 ? "满一分钟后计入今天" : "这段投入已经计入今天"}</p>
        <button class="primary-button focus-stop" data-action="stop-focus" type="button">结束专注</button>
      </section>
    `;
  }
  return `
    <header class="page-header">
      <p class="eyebrow">专注</p>
      <h1>给这一段时间一个边界。</h1>
    </header>
    <section class="mode-card">
      <h2>正计时</h2>
      <p>坐下就开始，准备离开时结束。</p>
      <button class="primary-button" data-action="start-countup" type="button">开始正计时</button>
    </section>
    <section class="mode-card soft">
      <h2>倒计时</h2>
      <div class="duration-grid">
        ${[15, 25, 45, 60]
          .map(
            (minutes) =>
              `<button data-action="start-countdown" data-minutes="${minutes}" type="button">${minutes}<small>分钟</small></button>`,
          )
          .join("")}
      </div>
    </section>
    <label class="share-toggle">
      <span><strong>允许 TA 加入</strong><small>对方可以在你专注期间加入陪伴</small></span>
      <input id="share-focus" type="checkbox" checked />
    </label>
  `;
}

function coupleView() {
  if (state.partner) {
    const metrics = state.coupleReport?.metrics;
    return `
      <header class="page-header">
        <p class="eyebrow">同序</p>
        <h1>各自认真，也在一起。</h1>
      </header>
      <section class="partner-card">
        <div class="partner-card-heading">
          <span class="partner-avatar">${escapeHTML((state.partner.display_name || "TA").slice(0, 1))}</span>
          <div><strong>${escapeHTML(state.partner.display_name || "TA")}</strong><small>${
            state.partner.is_focusing ? `正在专注 · ${formatSeconds(Math.floor((Date.now() - new Date(state.partner.focus_started_at).getTime()) / 1000))}` : "现在不在专注中"
          }</small></div>
        </div>
        <div class="partner-stats">
          <span><strong>${state.partner.completion_percent}%</strong>今日完成率</span>
          <span><strong>${state.partner.current_streak}天</strong>个人连胜</span>
        </div>
        ${
          state.partner.is_focusing && state.partner.focus_room_id
            ? `<button class="primary-button full-width" data-action="join-partner-focus" data-room-id="${escapeHTML(state.partner.focus_room_id)}" type="button">加入 TA 的专注</button>`
            : ""
        }
      </section>
      <section class="partner-tasks">
        <h2>TA 的今日待办</h2>
        <ul class="read-only-tasks">
          ${state.partner.tasks
            .map(
              (task) => `<li class="${task.status === "completed" ? "is-complete" : ""}">
                <span>${task.status === "completed" ? "✓" : "○"}</span>
                <p>${escapeHTML(task.title)}</p>
              </li>`,
            )
            .join("")}
        </ul>
      </section>
      ${
        metrics
          ? `<section class="monthly-report-card">
              <p class="eyebrow">${escapeHTML(state.coupleReport.month.slice(0, 7))} 同行简报</p>
              <div class="monthly-report-grid">
                <span><strong>${metrics.user_a_checkin_days || 0} / ${metrics.user_b_checkin_days || 0}</strong>双方有效天数</span>
                <span><strong>${Math.round((metrics.shared_overlap_seconds || 0) / 60)} 分钟</strong>共同专注</span>
                <span><strong>${metrics.couple_current_streak || 0} 天</strong>相伴连胜</span>
                <span><strong>${metrics.couple_best_streak || 0} 天</strong>本月最佳</span>
              </div>
            </section>`
          : ""
      }
    `;
  }
  if (state.pairing) {
    return `
      <header class="page-header">
        <p class="eyebrow">同序星图</p>
        <h1>让两个人的节奏相遇。</h1>
      </header>
      <section class="pairing-card">
        ${
          state.pairing.qr
            ? `<div class="star-code">
                <img src="${state.pairing.qr}" alt="情侣绑定二维码" />
                <i></i><i></i><i></i><i></i>
              </div>`
            : ""
        }
        <p>让 TA 扫描星图，或输入这组 6 位码</p>
        <strong class="pairing-code">${escapeHTML(state.pairing.code)}</strong>
        <small>5 分钟内有效 · 仅可使用一次</small>
        <button class="primary-button full-width" data-action="confirm-pairing" data-pairing-id="${escapeHTML(state.pairing.id)}" type="button">我确认绑定</button>
      </section>
    `;
  }
  return `
    <header class="page-header">
      <p class="eyebrow">同序</p>
      <h1>各自认真，也在一起。</h1>
    </header>
    <section class="partner-presence">
      <span class="presence-orbit" aria-hidden="true"><i></i><i></i></span>
      <div>
        <strong>尚未绑定伴侣</strong>
        <p>用同序星图，让两个人的学习节奏相遇。</p>
      </div>
      <button class="primary-button" data-action="create-pairing" type="button">生成同序星图</button>
      <button class="secondary-button" data-action="open-scanner" type="button">扫描 TA 的同序星图</button>
      ${
        state.scannerOpen
          ? `<section class="inline-scanner">
              <video id="pairing-scanner-video" playsinline muted aria-label="同序星图扫描画面"></video>
              <div class="scanner-guide" aria-hidden="true"></div>
              <p>将同序星图放入框内。识别后会自动进入双方确认。</p>
              <button class="text-button" data-action="close-scanner" type="button">停止扫描</button>
            </section>`
          : ""
      }
      <form id="claim-pairing-form" class="pairing-code-form">
        <input name="code" inputmode="numeric" pattern="[0-9]{6}" maxlength="6" placeholder="输入 6 位码" aria-label="6 位绑定码" />
        <button class="secondary-button" type="submit">加入</button>
      </form>
    </section>
  `;
}

function reviewView() {
  const calendar = calendarView();
  if (state.review) {
    return `
      <header class="page-header">
        <p class="eyebrow">每日复盘</p>
        <h1>把今天看清，不把自己说重。</h1>
      </header>
      <form id="review-form" class="review-card">
        <label class="review-date-picker">查看日期<input id="review-date-input" type="date" value="${escapeHTML(
          state.review.business_date,
        )}" /></label>
        <div class="review-date">${escapeHTML(state.review.title)}</div>
        <textarea name="fullText" class="review-editor" rows="16">${escapeHTML(state.review.full_text)}</textarea>
        <div class="review-actions">
          <button class="primary-button" type="submit">保存修改</button>
          <button class="secondary-button" data-action="copy-compact-review" type="button">复制精简版</button>
        </div>
      </form>
      ${calendar}
    `;
  }
  return `
    <header class="page-header">
      <p class="eyebrow">每日复盘</p>
      <h1>把今天看清，不把自己说重。</h1>
    </header>
    <section class="review-card">
      <label class="review-date-picker">查看日期<input id="review-date-input" type="date" value="${escapeHTML(
        state.reviewDate,
      )}" /></label>
      <div class="review-date">${dateHeading(state.reviewDate || businessDateString())}</div>
      <h2>今日复盘将在 23:30 准备好</h2>
      <p>客观数据会持续更新到次日 04:00。你写下的内容始终可以修改。</p>
      <div class="review-metrics">
        <span><strong>${state.today.summary.completed_tasks || 0}</strong>完成任务</span>
        <span><strong>${Math.floor((state.today.summary.focus_seconds || 0) / 60)}</strong>专注分钟</span>
      </div>
    </section>
    ${calendar}
  `;
}

function calendarView() {
  if (!state.calendar) return "";
  const month = state.calendar.month;
  const [year, monthNumber] = month.split("-").map(Number);
  const firstWeekday = new Date(`${month}T12:00:00+08:00`).getUTCDay();
  const daysInMonth = new Date(Date.UTC(year, monthNumber, 0)).getUTCDate();
  const byDate = new Map(state.calendar.days.map((day) => [day.business_date, day]));
  const cells = [];
  for (let index = 0; index < firstWeekday; index += 1) cells.push("<i></i>");
  for (let day = 1; day <= daysInMonth; day += 1) {
    const date = `${year}-${String(monthNumber).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
    const record = byDate.get(date);
    const className = record?.exempt ? "is-exempt" : record?.qualified ? "is-qualified" : "is-empty";
    cells.push(`<button class="${className}" data-review-date="${date}" type="button">${day}</button>`);
  }
  return `
    <section class="calendar-card">
      <div class="section-header"><h2>${year}年${monthNumber}月</h2><span class="calendar-legend">学习 · 请假 · 断档</span></div>
      <div class="calendar-weekdays">${["日", "一", "二", "三", "四", "五", "六"].map((day) => `<span>${day}</span>`).join("")}</div>
      <div class="calendar-grid">${cells.join("")}</div>
    </section>
  `;
}

function settingsView() {
  const settings = state.settings?.settings || {
    display_name: "",
    ai_tone: "restrained",
    external_checkin_enabled: false,
    bedtime: "",
    notification_review_enabled: true,
    notification_bedtime_enabled: true,
    notification_partner_enabled: true,
    notification_streak_enabled: true,
  };
  return `
    <header class="page-header">
      <p class="eyebrow">设置</p>
      <h1>让提醒保持分寸。</h1>
    </header>
    <form id="settings-form" class="settings-list">
      <button class="secondary-button full-width notification-permission" data-action="enable-notifications" type="button">启用系统通知并安排提醒</button>
      <div class="section-header notification-controls">
        <h2>通知</h2>
        <button class="text-button" data-action="silence-all-notifications" type="button">全部静默</button>
      </div>
      <label class="setting-field">昵称<input name="displayName" value="${escapeHTML(settings.display_name)}" maxlength="30" /></label>
      <label class="setting-field">AI 激励语气
        <select name="aiTone">
          <option value="restrained" ${settings.ai_tone === "restrained" ? "selected" : ""}>克制温和</option>
          <option value="companion" ${settings.ai_tone === "companion" ? "selected" : ""}>朋友陪伴</option>
          <option value="concise" ${settings.ai_tone === "concise" ? "selected" : ""}>简短有力</option>
        </select>
      </label>
      <label class="setting-field">计划就寝时间<input name="bedtime" type="time" value="${escapeHTML(
        settings.bedtime?.slice(0, 5) || "",
      )}" /></label>
      ${[
        ["externalCheckin", "外部打卡模式", "23:30 使用更明确的复盘提醒", settings.external_checkin_enabled],
        ["reviewNotification", "复盘提醒", "柔和木鱼提示音", settings.notification_review_enabled],
        ["bedtimeNotification", "睡前提醒", "轻钟提示音", settings.notification_bedtime_enabled],
        ["partnerNotification", "情侣动态", "纸页声与双音和弦", settings.notification_partner_enabled],
        ["streakNotification", "连胜里程碑", "明亮三音提示", settings.notification_streak_enabled],
      ]
        .map(
          ([name, title, subtitle, checked]) => `
            <label class="setting-row">
              <span><strong>${title}</strong><small>${subtitle}</small></span>
              <input name="${name}" type="checkbox" ${checked ? "checked" : ""} />
            </label>
          `,
        )
        .join("")}
      <button class="primary-button full-width" type="submit">保存设置</button>
    </form>
    <section class="plans-section">
      <div class="section-header"><h2>重复计划</h2><button class="text-button" data-action="open-plan-composer" type="button">新增计划</button></div>
      ${planComposer()}
      <ul class="plan-list">
        ${state.plans
          .filter((plan) => plan.is_active)
          .map(
            (plan) => `<li>
              <button data-action="edit-plan" data-plan-id="${plan.id}" type="button">
                <strong>${escapeHTML(plan.title)}</strong>
                <small>${plan.recurrence === "daily" ? "每天" : plan.recurrence === "weekly" ? `每周 ${plan.weekdays.join("、")}` : plan.starts_on}${plan.planned_time ? ` · ${plan.planned_time.slice(0, 5)}` : ""}</small>
              </button>
              <button class="text-button danger-text" data-action="disable-plan" data-plan-id="${plan.id}" type="button">停用</button>
            </li>`,
          )
          .join("") || "<li class=\"muted-row\">还没有重复计划</li>"}
      </ul>
    </section>
    <section class="leave-section">
      <h2>休息与请假</h2>
      <form id="leave-form" class="leave-form">
        <select name="kind"><option value="temporary_leave">临时请假</option><option value="weekly_rest">固定休息日</option></select>
        <input name="businessDate" type="date" value="${businessDateString()}" />
        <select name="weekday"><option value="1">周一</option><option value="2">周二</option><option value="3">周三</option><option value="4">周四</option><option value="5">周五</option><option value="6">周六</option><option value="7">周日</option></select>
        <button class="secondary-button" type="submit">添加</button>
      </form>
      <ul class="leave-list">${(state.settings?.leave_days || [])
        .map(
          (leave) => `<li><span>${leave.kind === "weekly_rest" ? `每周休息 · 周${leave.weekday}` : `临时请假 · ${leave.business_date}`}</span><button class="text-button" data-action="delete-leave" data-leave-id="${leave.id}" type="button">删除</button></li>`,
        )
        .join("")}</ul>
    </section>
    <section class="danger-zone">
      <h2>账号与关系</h2>
      ${
        state.partner
          ? state.dangerMode === "unbind"
            ? `<div class="inline-danger-confirm"><p>解绑后双方将立即停止共享数据，历史个人记录不会删除。</p><button class="secondary-button" data-action="confirm-unbind" type="button">确认解绑</button><button class="text-button" data-action="close-danger" type="button">取消</button></div>`
            : `<button class="secondary-button full-width" data-action="open-unbind" type="button">解绑伴侣</button>`
          : ""
      }
      ${
        state.dangerMode === "delete-account"
          ? `<form id="delete-account-form" class="inline-danger-confirm">
              <p>账号将进入 7 天冷静期。请输入密码再次确认。</p>
              <input name="password" type="password" autocomplete="current-password" placeholder="当前密码" required />
              <button class="secondary-button danger-button" type="submit">申请注销账号</button>
              <button class="text-button" data-action="close-danger" type="button">取消</button>
            </form>`
          : `<button class="text-button danger-text full-width" data-action="open-delete-account" type="button">注销账号并删除数据</button>`
      }
    </section>
    <button class="secondary-button full-width" data-action="signout" type="button">退出登录</button>
  `;
}

function planComposer() {
  if (!state.planComposerOpen) return "";
  const plan = state.editingPlan || {};
  const weekdays = plan.weekdays || [1, 2, 3, 4, 5];
  return `
    <form id="plan-form" class="inline-composer plan-composer">
      <div class="composer-heading"><h3>${plan.id ? "编辑计划" : "新增计划"}</h3><button class="text-button" data-action="close-plan-composer" type="button">收起</button></div>
      <input name="title" value="${escapeHTML(plan.title || "")}" placeholder="计划名称" maxlength="200" required />
      <div class="form-row">
        <select name="category">
          <option value="course" ${plan.category === "course" ? "selected" : ""}>课程任务</option>
          <option value="self_study" ${plan.category === "self_study" ? "selected" : ""}>自主学习</option>
        </select>
        <select name="recurrence">
          <option value="daily" ${plan.recurrence === "daily" ? "selected" : ""}>每天</option>
          <option value="weekly" ${plan.recurrence === "weekly" ? "selected" : ""}>每周指定日</option>
          <option value="once" ${plan.recurrence === "once" ? "selected" : ""}>仅一次</option>
        </select>
      </div>
      <div class="weekday-picker">${[1, 2, 3, 4, 5, 6, 7]
        .map(
          (day) => `<label><input name="weekdays" type="checkbox" value="${day}" ${weekdays.includes(day) ? "checked" : ""}/><span>${"一二三四五六日"[day - 1]}</span></label>`,
        )
        .join("")}</div>
      <div class="form-row">
        <label>开始日期<input name="startsOn" type="date" value="${plan.starts_on || businessDateString()}" required /></label>
        <label>计划时间<input name="plannedTime" type="time" value="${plan.planned_time?.slice(0, 5) || ""}" /></label>
      </div>
      <label class="compact-check"><input name="isPinned" type="checkbox" ${plan.is_pinned ? "checked" : ""}/>作为每日置顶任务</label>
      <button class="primary-button" type="submit">${plan.id ? "保存计划" : "创建计划"}</button>
    </form>
  `;
}

function nav() {
  const icons = {
    today:
      '<svg viewBox="0 0 24 24"><path d="M4 10.5 12 4l8 6.5v8a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 18.5z"/><path d="M9 20v-6h6v6"/></svg>',
    focus:
      '<svg viewBox="0 0 24 24"><circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.5 2.5M9 3h6"/></svg>',
    couple:
      '<svg viewBox="0 0 24 24"><path d="M20.8 8.7c0 5-8.8 10.3-8.8 10.3S3.2 13.7 3.2 8.7A4.7 4.7 0 0 1 12 6.4a4.7 4.7 0 0 1 8.8 2.3Z"/></svg>',
    review:
      '<svg viewBox="0 0 24 24"><path d="M6 4h12a2 2 0 0 1 2 2v14H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z"/><path d="M8 9h8M8 13h8M8 17h5"/></svg>',
    settings:
      '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M19 12a7 7 0 0 0-.1-1l2-1.6-2-3.4-2.5 1a7 7 0 0 0-1.8-1L14.2 3h-4.4l-.4 3a7 7 0 0 0-1.8 1L5.1 6 3 9.4 5.1 11a7 7 0 0 0 0 2L3 14.6 5.1 18l2.5-1a7 7 0 0 0 1.8 1l.4 3h4.4l.4-3a7 7 0 0 0 1.8-1l2.5 1 2-3.4-2-1.6a7 7 0 0 0 .1-1Z"/></svg>',
  };
  const items = [
    ["today", "今日"],
    ["focus", "专注"],
    ["couple", "同序"],
    ["review", "复盘"],
    ["settings", "设置"],
  ];
  return `
    <nav class="bottom-nav" aria-label="主导航">
      ${items
        .map(
          ([route, label]) => `
            <button class="nav-item" data-route="${route}" type="button" ${
              state.route === route ? 'aria-current="page"' : ""
            }>
              <span class="nav-icon" aria-hidden="true">${icons[route]}</span>
              <span>${label}</span>
            </button>
          `,
        )
        .join("")}
    </nav>
  `;
}

function render() {
  state.pendingBackgroundRender = false;
  if (state.loading) {
    app.innerHTML = `<main class="loading-screen"><span class="loading-mark">朝夕</span></main>`;
    return;
  }
  if (!state.session) {
    app.innerHTML = authView();
    bindEvents();
    return;
  }

  const views = {
    today: todayView,
    focus: focusView,
    couple: coupleView,
    review: reviewView,
    settings: settingsView,
  };
  app.innerHTML = `
    <main class="app-shell route-${state.route}">
      ${state.message ? `<p class="global-message" role="status">${escapeHTML(state.message)}</p>` : ""}
      ${
        state.notifications[0]
          ? `<aside class="notification-inline" data-notification-id="${escapeHTML(state.notifications[0].id)}">
              <div><strong>${escapeHTML(state.notifications[0].title)}</strong><span>${escapeHTML(state.notifications[0].body)}</span></div>
              <button class="text-button" data-action="dismiss-notification" type="button">知道了</button>
            </aside>`
          : ""
      }
      ${state.loadingRoute ? '<div class="route-loading">加载中…</div>' : ''}
      ${views[state.route]()}
    </main>
    ${nav()}
  `;
  bindEvents();
}

function bindEvents() {
  document.querySelector("#toggle-auth")?.addEventListener("click", () => {
    state.authMode = state.authMode === "signin" ? "signup" : "signin";
    state.message = "";
    render();
  });

  document.querySelector("#auth-form")?.addEventListener("submit", handleAuth);
  document.querySelector("#task-form")?.addEventListener("submit", handleCreateTask);
  document.querySelector("#claim-pairing-form")?.addEventListener("submit", handleClaimPairing);
  document.querySelector("#review-form")?.addEventListener("submit", handleSaveReview);
  document.querySelector("#settings-form")?.addEventListener("submit", handleSaveSettings);
  document.querySelector("#plan-form")?.addEventListener("submit", handleSavePlan);
  document.querySelector("#leave-form")?.addEventListener("submit", handleCreateLeave);
  document.querySelector("#delete-account-form")?.addEventListener("submit", handleDeleteAccount);
  document.querySelector("#review-date-input")?.addEventListener("change", (event) => {
    state.reviewDate = event.target.value;
    loadReview(event.target.value);
  });
  document.querySelectorAll("[data-review-date]").forEach((element) => {
    element.addEventListener("click", () => {
      state.reviewDate = element.dataset.reviewDate;
      loadReview(state.reviewDate);
    });
  });

  document.querySelectorAll("[data-route]").forEach((element) => {
    element.addEventListener("click", () => {
      state.route = element.dataset.route;
      if (state.route === "couple") loadPartner();
      if (state.route === "review") loadReview();
      if (state.route === "settings") loadSettings();
      render();
    });
  });

  document.querySelectorAll("[data-action]").forEach((element) => {
    element.addEventListener("click", () => handleAction(element));
  });
}

async function handleAuth(event) {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  state.message = "";
  try {
    state.session =
      state.authMode === "signup"
        ? await signUp(form.get("email"), form.get("password"), form.get("displayName"))
        : await signIn(form.get("email"), form.get("password"));
    if (!state.session) {
      state.message = "请前往邮箱完成验证，然后回来登录。";
    } else {
      await initializeAuthenticatedSession();
    }
  } catch (error) {
    state.message = error.message;
  }
  render();
}

async function handleCreateTask(event) {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  const operationID = crypto.randomUUID();
  const optimistic = {
    id: `local-${operationID}`,
    title: form.get("title").trim(),
    category: form.get("category"),
    planned_time: form.get("plannedTime") || null,
    status: "pending",
    is_pinned: false,
    version: 1,
    encouragement: "先把它放在今天，接下来只需开始。",
  };
  state.today.tasks.push(optimistic);
  recalculateSummary();
  state.taskComposerOpen = false;
  render();

  const payload = {
    title: optimistic.title,
    category: optimistic.category,
    planned_time: optimistic.planned_time,
    is_pinned: false,
    operation_id: operationID,
  };
  try {
    const created = await apiClient.createTask(payload);
    Object.assign(optimistic, created);
    await db.tasks.delete(`local-${operationID}`);
    await db.tasks.put(created);
  } catch {
    await enqueueOperation({
      type: "task-create",
      entity_id: optimistic.id,
      payload,
      operation_id: operationID,
    });
    await db.tasks.put(optimistic);
  }
  recalculateSummary();
  render();
}

async function handleAction(element) {
  const action = element.dataset.action;
  if (action === "open-composer") {
    state.taskComposerOpen = true;
    render();
    return;
  }
  if (action === "open-task-menu") {
    state.taskMenuID = element.closest("[data-task-id]")?.dataset.taskId || "";
    render();
    return;
  }
  if (action === "close-task-menu") {
    state.taskMenuID = "";
    render();
    return;
  }
  if (action === "delete-task") {
    const taskID = element.closest("[data-task-id]")?.dataset.taskId;
    const task = state.today.tasks.find((candidate) => candidate.id === taskID);
    if (!task || task.status !== "pending") return;
    state.today.tasks = state.today.tasks.filter((candidate) => candidate.id !== taskID);
    state.taskMenuID = "";
    recalculateSummary();
    render();
    if (taskID.startsWith("local-")) {
      await db.tasks.delete(taskID);
      const pending = await db.outbox.filter((operation) => operation.entity_id === taskID).toArray();
      await db.outbox.bulkDelete(pending.map((operation) => operation.local_id));
      return;
    }
    try {
      await apiClient.deleteTask(taskID);
      await db.tasks.delete(taskID);
    } catch {
      await enqueueOperation({
        type: "task-delete",
        entity_id: taskID,
        payload: {},
        operation_id: crypto.randomUUID(),
      });
    }
    return;
  }
  if (action === "close-composer") {
    state.taskComposerOpen = false;
    render();
    return;
  }
  if (action === "signout") {
    state.disconnectRealtime?.();
    state.disconnectRealtime = null;
    if (navigator.onLine) {
      try {
        await apiClient.unregisterDevice(deviceID());
      } catch {
        // Signing out must not be blocked by a temporary network failure.
      }
    }
    try {
      await clearScheduledNotifications();
    } catch {
      // The OS will discard expired reminders even if cleanup is unavailable.
    }
    await signOut();
    state.session = null;
    state.route = "today";
    render();
    return;
  }
  if (action === "dismiss-notification") {
    const container = element.closest("[data-notification-id]");
    const id = container?.dataset.notificationId;
    state.notifications = state.notifications.filter((notification) => notification.id !== id);
    render();
    if (id) {
      try {
        await apiClient.markNotificationRead(id);
      } catch {
        // The durable row remains unread and can be retried on the next launch.
      }
    }
    return;
  }
  if (action === "dismiss-milestone") {
    const milestone = Number(element.dataset.milestone);
    try {
      await apiClient.markMilestoneSeen(milestone);
      state.today.summary.pending_milestone = 0;
    } catch (error) {
      state.message = error.message;
    }
    render();
    return;
  }
  if (action === "silence-all-notifications") {
    const settings = state.settings?.settings;
    if (settings) {
      settings.notification_review_enabled = false;
      settings.notification_bedtime_enabled = false;
      settings.notification_partner_enabled = false;
      settings.notification_streak_enabled = false;
    }
    state.message = "通知已在表单中全部关闭，保存设置后生效。";
    render();
    return;
  }
  if (action === "open-unbind") {
    state.dangerMode = "unbind";
    render();
    return;
  }
  if (action === "open-delete-account") {
    state.dangerMode = "delete-account";
    render();
    return;
  }
  if (action === "close-danger") {
    state.dangerMode = "";
    render();
    return;
  }
  if (action === "confirm-unbind") {
    try {
      await apiClient.unbindCouple();
      state.partner = null;
      state.coupleReport = null;
      state.dangerMode = "";
      state.message = "已解除绑定。";
    } catch (error) {
      state.message = error.status === 404 ? "当前没有已绑定的伴侣。" : error.message;
    }
    render();
    return;
  }
  if (action === "open-plan-composer") {
    state.editingPlan = null;
    state.planComposerOpen = true;
    render();
    return;
  }
  if (action === "close-plan-composer") {
    state.planComposerOpen = false;
    state.editingPlan = null;
    render();
    return;
  }
  if (action === "edit-plan") {
    state.editingPlan = state.plans.find((plan) => plan.id === element.dataset.planId) || null;
    state.planComposerOpen = Boolean(state.editingPlan);
    render();
    return;
  }
  if (action === "disable-plan") {
    try {
      await apiClient.disablePlan(element.dataset.planId);
      state.plans = state.plans.filter((plan) => plan.id !== element.dataset.planId);
      state.message = "计划已停用，历史任务不会改变。";
    } catch (error) {
      state.message = error.message;
    }
    render();
    return;
  }
  if (action === "delete-leave") {
    try {
      await apiClient.deleteLeave(element.dataset.leaveId);
      state.settings.leave_days = state.settings.leave_days.filter(
        (leave) => leave.id !== element.dataset.leaveId,
      );
    } catch (error) {
      state.message = error.message;
    }
    render();
    return;
  }
  if (action === "create-pairing") {
    try {
      const pairing = await apiClient.createPairing();
      const url = `synday://pair/${pairing.token}`;
      state.pairing = { ...pairing, qr: await QRCode.toDataURL(url, { width: 260, margin: 1 }) };
    } catch (error) {
      state.message = error.message;
    }
    render();
    return;
  }
  if (action === "open-scanner") {
    state.scannerOpen = true;
    render();
    await startPairingScanner();
    return;
  }
  if (action === "close-scanner") {
    stopPairingScanner();
    state.scannerOpen = false;
    render();
    return;
  }
  if (action === "confirm-pairing") {
    try {
      const result = await apiClient.confirmPairing(element.dataset.pairingId);
      state.message = result.status === "bound" ? "绑定完成。" : "已确认，等待 TA 确认。";
      if (result.status === "bound") {
        state.pairing = null;
        await loadPartner();
      }
    } catch (error) {
      state.message = error.message;
    }
    render();
    return;
  }
  if (action === "join-partner-focus") {
    try {
      state.focus = await apiClient.joinFocus({
        room_id: element.dataset.roomId,
        mode: "shared_countup",
        operation_id: crypto.randomUUID(),
      });
      state.route = "focus";
      startFocusTicker();
    } catch (error) {
      state.message = error.message;
    }
    render();
    return;
  }
  if (action === "copy-compact-review") {
    try {
      await navigator.clipboard.writeText(state.review?.compact_text || "");
      state.message = "精简版已复制。";
    } catch {
      state.message = "暂时无法写入剪贴板，请长按复盘文字复制。";
    }
    render();
    return;
  }
  if (action === "enable-notifications") {
    const granted = await ensureNotificationPermission(true);
    if (granted) {
      await scheduleDailyReminders({
        bedtime: state.settings?.settings?.bedtime,
        externalCheckinEnabled: state.settings?.settings?.external_checkin_enabled,
        reviewEnabled: state.settings?.settings?.notification_review_enabled,
      });
      state.message = "通知已启用并安排。";
    } else {
      state.message = "未获得通知权限，可稍后在系统设置中开启。";
    }
    render();
    return;
  }
  if (action === "toggle-task" || action === "pin-task") {
    const item = element.closest("[data-task-id]");
    const task = state.today.tasks.find((candidate) => candidate.id === item.dataset.taskId);
    if (!task) return;
    const previousStatus = task.status;
    const previousPinned = task.is_pinned;
    const previousCompletedAt = task.completed_at;
    const apiAction =
      action === "toggle-task"
        ? task.status === "completed"
          ? "uncomplete"
          : "complete"
        : task.is_pinned
          ? "unpin"
          : "pin";
    if (apiAction === "complete") {
      task.status = "completed";
      task.completed_at = new Date().toISOString();
    }
    if (apiAction === "uncomplete") {
      task.status = "pending";
      task.completed_at = null;
    }
    if (apiAction === "pin") task.is_pinned = true;
    if (apiAction === "unpin") task.is_pinned = false;
    state.taskMenuID = "";
    state.today.tasks.sort(
      (left, right) =>
        Number(right.is_pinned) - Number(left.is_pinned) ||
        String(left.planned_time || "99:99").localeCompare(String(right.planned_time || "99:99")),
    );
    recalculateSummary();
    render();
    if (apiAction === "complete") {
      const encouragement = document
        .querySelector(`[data-task-id="${CSS.escape(task.id)}"]`)
        ?.querySelector(".ai-inline");
      requestAnimationFrame(() => encouragement?.classList.add("is-visible"));
      window.setTimeout(() => encouragement?.classList.remove("is-visible"), 4000);
    }
    const payload = {
      action: apiAction,
      version: task.version || 1,
      operation_id: crypto.randomUUID(),
    };
    try {
      const updated = await apiClient.updateTask(task.id, payload);
      Object.assign(task, updated);
      await db.tasks.put(task);
    } catch (error) {
      if (error.status && error.status >= 400 && error.status < 500) {
        // Server returned a real error — rollback optimistic update
        task.status = previousStatus;
        task.is_pinned = previousPinned;
        task.completed_at = previousCompletedAt;
        recalculateSummary();
        state.message = error.message;
        render();
      } else {
        // Network error — keep optimistic state and queue for retry
        await enqueueOperation({
          type: "task-update",
          entity_id: task.id,
          payload,
          operation_id: payload.operation_id,
        });
        await db.tasks.put(task);
      }
    }
    return;
  }
  if (action === "start-countup" || action === "start-countdown") {
    const plannedSeconds =
      action === "start-countdown" ? Number(element.dataset.minutes) * 60 : null;
    const input = {
      mode: plannedSeconds ? "solo_countdown" : "solo_countup",
      planned_seconds: plannedSeconds,
      share_with_partner: document.querySelector("#share-focus")?.checked ?? true,
      operation_id: crypto.randomUUID(),
    };
    try {
      state.focus = await apiClient.startFocus(input);
    } catch {
      state.focus = {
        id: `local-${input.operation_id}`,
        ...input,
        started_at: new Date().toISOString(),
        status: "active",
      };
      await db.focusSessions.put(state.focus);
      await enqueueOperation({
        type: "focus-start",
        entity_id: state.focus.id,
        payload: input,
        operation_id: input.operation_id,
      });
    }
    startFocusTicker();
    render();
    return;
  }
  if (action === "stop-focus") {
    await finishFocus();
  }
}

async function finishFocus() {
  if (!state.focus) return;
  const operationID = crypto.randomUUID();
  try {
    const stopped = await apiClient.stopFocus(operationID);
    await db.focusSessions.put(stopped);
    if (stopped.is_valid) {
      state.message = `本次专注 ${Math.floor(stopped.duration_seconds / 60)} 分钟，已计入今天。`;
    } else {
      state.message = "不足一分钟，本次不计入打卡。";
    }
  } catch {
    await enqueueOperation({ type: "focus-stop", payload: {}, operation_id: operationID });
    await db.focusSessions.update(state.focus.id, {
      status: "completed",
      ended_at: new Date().toISOString(),
    });
    state.message = "已在本地结束，联网后自动同步。";
  }
  state.focus = null;
  stopFocusTicker();
  state.route = "today";
  render();
}

async function handleClaimPairing(event) {
  event.preventDefault();
  const code = new FormData(event.currentTarget).get("code")?.trim();
  if (!code) return;
  await claimPairing({ code, token: "" });
}

async function claimPairing(input) {
  try {
    const pairing = await apiClient.claimPairing(input);
    stopPairingScanner();
    state.scannerOpen = false;
    state.pairing = { ...pairing, qr: "" };
    state.message = "已找到对方，请双方分别确认。";
  } catch (error) {
    state.message = error.message;
  }
  render();
}

function pairingTokenFromURL(rawURL) {
  try {
    const url = new URL(rawURL);
    if (url.protocol !== "synday:" || url.hostname !== "pair") return "";
    return url.pathname.replace(/^\/+/, "");
  } catch {
    return "";
  }
}

async function startPairingScanner() {
  const video = document.querySelector("#pairing-scanner-video");
  if (!video) return;
  if (!("BarcodeDetector" in window)) {
    state.message = "当前系统扫码能力不可用，请使用下方 6 位码完成绑定。";
    state.scannerOpen = false;
    render();
    return;
  }
  try {
    state.scannerStream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: { ideal: "environment" } },
      audio: false,
    });
    video.srcObject = state.scannerStream;
    await video.play();
    const detector = new BarcodeDetector({ formats: ["qr_code"] });
    const detect = async () => {
      if (!state.scannerOpen || !state.scannerStream) return;
      try {
        const codes = await detector.detect(video);
        const token = codes.map((code) => pairingTokenFromURL(code.rawValue)).find(Boolean);
        if (token) {
          await claimPairing({ code: "", token });
          return;
        }
      } catch {
        // Camera frames can be temporarily unavailable while the app resumes.
      }
      state.scannerFrame = requestAnimationFrame(detect);
    };
    detect();
  } catch {
    state.message = "无法使用相机，请检查权限或使用 6 位码绑定。";
    stopPairingScanner();
    state.scannerOpen = false;
    render();
  }
}

function stopPairingScanner() {
  if (state.scannerFrame) cancelAnimationFrame(state.scannerFrame);
  state.scannerFrame = null;
  state.scannerStream?.getTracks().forEach((track) => track.stop());
  state.scannerStream = null;
}

async function handleSaveReview(event) {
  event.preventDefault();
  try {
    state.review = await apiClient.updateReview(state.review.id, {
      full_text: new FormData(event.currentTarget).get("fullText"),
      version: state.review.version,
    });
    state.message = "复盘已保存。";
  } catch (error) {
    state.message = error.message;
  }
  render();
}

async function handleSaveSettings(event) {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  const payload = {
    display_name: form.get("displayName")?.trim() || "",
    ai_tone: form.get("aiTone"),
    external_checkin_enabled: form.has("externalCheckin"),
    bedtime: form.get("bedtime") || null,
    notification_review_enabled: form.has("reviewNotification"),
    notification_bedtime_enabled: form.has("bedtimeNotification"),
    notification_partner_enabled: form.has("partnerNotification"),
    notification_streak_enabled: form.has("streakNotification"),
  };
  try {
    state.settings ||= { settings: {}, leave_days: [] };
    state.settings.settings = await apiClient.updateSettings(payload);
    await scheduleDailyReminders({
      bedtime: payload.notification_bedtime_enabled ? payload.bedtime : null,
      externalCheckinEnabled: payload.external_checkin_enabled,
      reviewEnabled: payload.notification_review_enabled,
    });
    state.message = "设置已保存。";
  } catch (error) {
    state.message = error.message;
  }
  render();
}

async function handleSavePlan(event) {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  const recurrence = form.get("recurrence");
  const payload = {
    title: form.get("title")?.trim(),
    category: form.get("category"),
    recurrence,
    starts_on: form.get("startsOn"),
    ends_on: null,
    weekdays: recurrence === "weekly" ? form.getAll("weekdays").map(Number) : [],
    planned_time: form.get("plannedTime") || null,
    is_pinned: form.has("isPinned"),
    version: state.editingPlan?.version || 0,
  };
  try {
    const saved = state.editingPlan
      ? await apiClient.updatePlan(state.editingPlan.id, payload)
      : await apiClient.createPlan(payload);
    const index = state.plans.findIndex((plan) => plan.id === saved.id);
    if (index >= 0) state.plans[index] = saved;
    else state.plans.unshift(saved);
    state.planComposerOpen = false;
    state.editingPlan = null;
    state.message = "重复计划已保存。";
  } catch (error) {
    state.message = error.message;
  }
  render();
}

async function handleCreateLeave(event) {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  const kind = form.get("kind");
  const payload = {
    kind,
    business_date: kind === "temporary_leave" ? form.get("businessDate") : null,
    weekday: kind === "weekly_rest" ? Number(form.get("weekday")) : null,
  };
  try {
    const leave = await apiClient.createLeave(payload);
    state.settings.leave_days.push(leave);
    state.message = kind === "temporary_leave" ? "请假日已添加。" : "固定休息日已更新。";
  } catch (error) {
    state.message = error.message;
  }
  render();
}

async function handleDeleteAccount(event) {
  event.preventDefault();
  const password = new FormData(event.currentTarget).get("password");
  try {
    const email = state.session?.user?.email;
    if (!email) throw new Error("无法读取当前邮箱，请重新登录后再试。");
    await signIn(email, password);
    const result = await apiClient.requestAccountDeletion();
    state.dangerMode = "";
    state.message = `注销申请已记录，可在 ${new Date(result.purge_after).toLocaleDateString("zh-CN")} 前登录撤销。`;
  } catch (error) {
    state.message = error.message;
  }
  render();
}

async function loadPartner(background = false) {
  if (config.previewMode) {
    render();
    return;
  }
  if (!background) {
    state.loadingRoute = true;
    render();
  }
  try {
    state.partner = await apiClient.partner();
    try {
      state.coupleReport = await apiClient.coupleReport(currentMonthStart());
    } catch {
      state.coupleReport = null;
    }
  } catch (error) {
    if (error.status !== 404) state.message = error.message;
    state.partner = null;
  }
  state.loadingRoute = false;
  if (background) renderBackgroundUpdate();
  else render();
}

async function loadReview(date = state.reviewDate) {
  if (config.previewMode) {
    render();
    return;
  }
  state.loadingRoute = true;
  render();
  try {
    const [calendarResult, reviewResult] = await Promise.allSettled([
      state.calendar ? Promise.resolve(state.calendar) : apiClient.calendar(currentMonthStart()),
      apiClient.review(date || undefined),
    ]);
    if (calendarResult.status === "fulfilled") state.calendar = calendarResult.value;
    if (reviewResult.status === "fulfilled") {
      state.review = reviewResult.value;
      state.reviewDate = state.review.business_date;
    } else if (reviewResult.reason.status !== 404) {
      state.message = reviewResult.reason.message;
      state.review = null;
    }
  } catch (error) {
    state.message = error.message;
    state.review = null;
  }
  state.loadingRoute = false;
  render();
}

async function loadSettings() {
  if (config.previewMode) {
    render();
    return;
  }
  state.loadingRoute = true;
  render();
  try {
    const [settings, plans] = await Promise.all([apiClient.settings(), apiClient.plans()]);
    state.settings = settings;
    state.plans = plans.plans || [];
  } catch (error) {
    state.message = error.message;
  }
  state.loadingRoute = false;
  render();
}

async function loadNotifications() {
  if (!state.session || !navigator.onLine) return;
  try {
    const result = await apiClient.notifications();
    const notifications = result.notifications || [];
    const changed =
      notifications.length !== state.notifications.length ||
      notifications.some((notification, index) => notification.id !== state.notifications[index]?.id);
    state.notifications = notifications;
    if (!changed && !state.pendingBackgroundRender) return;
  } catch {
    // Notification history is optional to the core task flow.
    return;
  }
  renderBackgroundUpdate();
}

async function startRealtime() {
  if (!state.session?.user?.id) return;
  state.disconnectRealtime?.();
  state.disconnectRealtime = null;
  try {
    state.disconnectRealtime = await connectRealtime(
      state.session.user.id,
      "",
      async (event) => {
        await loadNotifications();
        if (
          state.route === "couple" &&
          (event.event === "notification_poll" ||
            event.event === "partner_joined_focus" ||
            event.event === "partner_task_completed")
        ) {
          await loadPartner(true);
        }
      },
    );
  } catch {
    // The persisted notification inbox covers offline/realtime failures.
  }
}

function startFocusTicker() {
  stopFocusTicker();
  state.focusTicker = window.setInterval(() => {
    if (
      state.focus?.planned_seconds &&
      focusElapsed() >= state.focus.planned_seconds &&
      !state.autoStoppingFocus
    ) {
      state.autoStoppingFocus = true;
      finishFocus().finally(() => {
        state.autoStoppingFocus = false;
      });
      return;
    }
    updateFocusDisplay();
  }, 1000);
}

function updateFocusDisplay() {
  if (!state.focus) return;
  const elapsed = focusElapsed();
  if (state.route === "focus") {
    const planned = state.focus.planned_seconds;
    const displayed = planned ? Math.max(0, planned - elapsed) : elapsed;
    const time = document.querySelector(".focus-time");
    const support = document.querySelector(".focus-support");
    if (time) time.textContent = formatSeconds(displayed);
    if (support) {
      support.textContent = elapsed < 60 ? "满一分钟后计入今天" : "这段投入已经计入今天";
    }
  } else if (state.route === "today") {
    const summary = document.querySelector(".focus-card small");
    if (summary) summary.textContent = `正在专注 · ${formatSeconds(elapsed)}`;
  }
}

function stopFocusTicker() {
  if (state.focusTicker) window.clearInterval(state.focusTicker);
  state.focusTicker = null;
}

window.addEventListener("online", () => {
  state.online = true;
  loadNotifications();
  startRealtime();
  render();
});
window.addEventListener("offline", () => {
  state.online = false;
  render();
});
document.addEventListener("focusout", () => {
  requestAnimationFrame(() => {
    if (state.pendingBackgroundRender && !userIsEditing()) render();
  });
});

async function initializeAuthenticatedSession() {
  await restoreActiveFocus();
  await loadToday();
  await registerPendingPushToken();
  await loadNotifications();
  await startRealtime();
  const pendingPairingToken = localStorage.getItem("synday-pending-pairing-token");
  if (pendingPairingToken) {
    localStorage.removeItem("synday-pending-pairing-token");
    state.route = "couple";
    await claimPairing({ code: "", token: pendingPairingToken });
  }
}

async function installNativeListeners() {
  if (!window.__TAURI_INTERNALS__) return;
  try {
    state.disconnectNotificationActions = await listenForNotificationActions((route) => {
      if (!["today", "focus", "couple", "review", "settings"].includes(route)) return;
      state.route = route;
      if (route === "review") loadReview();
      else if (route === "couple") loadPartner();
      else if (route === "settings") loadSettings();
      else render();
    });
  } catch {
    // Opening the app still exposes the durable notification inbox.
  }
  try {
    const { listen } = await import("@tauri-apps/api/event");
    await listen("synday://push-token", async ({ payload }) => {
      localStorage.setItem("synday-apns-token", String(payload));
      await registerPendingPushToken();
    });
    const pendingToken = await invoke("pending_push_token");
    if (pendingToken) {
      localStorage.setItem("synday-apns-token", String(pendingToken));
      await registerPendingPushToken();
    }
  } catch {
    // Push token registration retries after the next native token event or launch.
  }
  try {
    const { getCurrent, onOpenUrl } = await import("@tauri-apps/plugin-deep-link");
    const handleURLs = (urls) => {
      const token = (urls || []).map(pairingTokenFromURL).find(Boolean);
      if (!token) return;
      if (!state.session) {
        localStorage.setItem("synday-pending-pairing-token", token);
        return;
      }
      state.route = "couple";
      claimPairing({ code: "", token });
    };
    handleURLs(await getCurrent());
    await onOpenUrl(handleURLs);
  } catch {
    // Pairing still supports QR scanning and the 6-digit code.
  }
}

async function bootstrap() {
  state.session = await currentSession();
  state.loading = false;
  if (config.previewMode) {
    seedPreviewState();
    render();
    return;
  }
  await installNativeListeners();
  startSyncLoop();
  render();
  if (state.session) {
    await initializeAuthenticatedSession();
  }
}

bootstrap();
