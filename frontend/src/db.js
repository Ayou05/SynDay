import Dexie from "dexie";

export const db = new Dexie("synday");

db.version(1).stores({
  tasks: "id, business_date, status, is_pinned, updated_at",
  focusSessions: "id, status, business_date, started_at",
  outbox: "++local_id, &operation_id, created_at, next_attempt_at",
  cache: "key, updated_at",
  preferences: "key",
});

export async function cacheToday(payload) {
  await db.transaction("rw", db.tasks, db.cache, async () => {
    await db.tasks.clear();
    if (payload.tasks?.length) {
      await db.tasks.bulkPut(payload.tasks);
    }
    await db.cache.put({
      key: "today-summary",
      value: payload.summary,
      updated_at: new Date().toISOString(),
    });
  });
}

export async function readCachedToday() {
  const [tasks, summaryRecord] = await Promise.all([
    db.tasks.toArray(),
    db.cache.get("today-summary"),
  ]);
  return {
    tasks,
    summary: summaryRecord?.value || {
      business_date: "",
      total_tasks: tasks.length,
      completed_tasks: tasks.filter((task) => task.status === "completed").length,
      completion_percent: 0,
      focus_seconds: 0,
      current_streak: 0,
    },
  };
}

export async function enqueueOperation(operation) {
  return db.outbox.put({
    ...operation,
    operation_id: operation.operation_id || crypto.randomUUID(),
    created_at: new Date().toISOString(),
    next_attempt_at: Date.now(),
    attempts: 0,
  });
}

