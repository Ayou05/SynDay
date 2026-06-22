import { apiClient } from "./api.js";
import { db } from "./db.js";

let syncing = false;

export async function flushOutbox() {
  if (syncing || !navigator.onLine) return;
  syncing = true;
  try {
    const operations = await db.outbox
      .where("next_attempt_at")
      .belowOrEqual(Date.now())
      .sortBy("created_at");

    for (const operation of operations) {
      try {
        if (operation.type === "task-update") {
          await apiClient.updateTask(operation.entity_id, operation.payload);
        } else if (operation.type === "task-create") {
          const task = await apiClient.createTask(operation.payload);
          if (operation.entity_id) {
            await db.tasks.delete(operation.entity_id);
            await db.tasks.put(task);
          }
        } else if (operation.type === "focus-start") {
          const session = await apiClient.startFocus(operation.payload);
          if (operation.entity_id) {
            await db.focusSessions.delete(operation.entity_id);
          }
          await db.focusSessions.put(session);
        } else if (operation.type === "focus-stop") {
          const session = await apiClient.stopFocus(operation.operation_id);
          await db.focusSessions.put(session);
        } else if (operation.type === "task-delete") {
          try {
            await apiClient.deleteTask(operation.entity_id);
          } catch (error) {
            if (error.status !== 404) throw error;
          }
          await db.tasks.delete(operation.entity_id);
        }
        await db.outbox.delete(operation.local_id);
      } catch (error) {
        if (error.status === 409 || error.status === 401) {
          break;
        }
        const attempts = (operation.attempts || 0) + 1;
        await db.outbox.update(operation.local_id, {
          attempts,
          next_attempt_at: Date.now() + Math.min(300_000, 2 ** attempts * 1000),
        });
      }
    }
  } finally {
    syncing = false;
  }
}

export function startSyncLoop() {
  window.addEventListener("online", flushOutbox);
  const timer = window.setInterval(flushOutbox, 15_000);
  flushOutbox();
  return () => {
    window.removeEventListener("online", flushOutbox);
    window.clearInterval(timer);
  };
}
