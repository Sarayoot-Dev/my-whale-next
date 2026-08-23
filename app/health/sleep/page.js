"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { Timestamp } from "firebase/firestore";
import { watchAuth } from "@/lib/firebase";
import { addActivity, deleteActivity, startSleep, endSleep, watchActivities } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

function formatDuration(min) {
  if (min == null) return "";
  const h = Math.floor(min / 60);
  const m = min % 60;
  return h > 0 ? `${h} ชม. ${m} นาที` : `${m} นาที`;
}

function formatDateTime(ts) {
  if (!ts?.toDate) return "";
  return ts.toDate().toLocaleString("th-TH", {
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default function SleepPage() {
  const [user, setUser] = useState(undefined);
  const [activities, setActivities] = useState([]);
  const [starting, setStarting] = useState(false);
  const [ending, setEnding] = useState(false);
  const [showManual, setShowManual] = useState(false);
  const [manualStart, setManualStart] = useState("");
  const [manualEnd, setManualEnd] = useState("");
  const [saving, setSaving] = useState(false);
  const [tick, setTick] = useState(0);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    return watchActivities(CHILD_ID, setActivities, { max: 100 });
  }, [user]);

  useEffect(() => {
    const id = setInterval(() => setTick((t) => t + 1), 30000);
    return () => clearInterval(id);
  }, []);

  const sleepEntries = activities.filter((a) => a.type === "sleep");
  const openSession = sleepEntries.find((a) => a.startedAt && !a.endedAt);
  const pastSessions = sleepEntries.filter((a) => a.endedAt);

  const elapsedLabel = useMemo(() => {
    if (!openSession?.startedAt?.toDate) return null;
    const diffMin = Math.floor((Date.now() - openSession.startedAt.toDate().getTime()) / 60000);
    return formatDuration(diffMin);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [openSession, tick]);

  async function handleStart() {
    setStarting(true);
    try {
      await startSleep(CHILD_ID);
    } finally {
      setStarting(false);
    }
  }

  async function handleEnd() {
    if (!openSession) return;
    setEnding(true);
    try {
      await endSleep(CHILD_ID, openSession.id, openSession.startedAt);
    } finally {
      setEnding(false);
    }
  }

  async function handleManualSave(e) {
    e.preventDefault();
    if (!manualStart || !manualEnd) return;
    const startedAt = Timestamp.fromDate(new Date(manualStart));
    const endedAt = Timestamp.fromDate(new Date(manualEnd));
    const durationMin = Math.round((endedAt.toMillis() - startedAt.toMillis()) / 60000);
    if (durationMin <= 0) return;
    setSaving(true);
    try {
      await addActivity(CHILD_ID, { type: "sleep", startedAt, endedAt, durationMin });
      setManualStart("");
      setManualEnd("");
      setShowManual(false);
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id) {
    if (!window.confirm("ลบรายการนี้ใช่ไหม?")) return;
    await deleteActivity(CHILD_ID, id);
  }

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2 flex items-center gap-2">
        <Link href="/health" aria-label="กลับ" className="text-xl text-abyss/40">
          ←
        </Link>
        <div>
          <h1 className="font-display text-2xl font-bold text-abyss">การนอน</h1>
          <WaveDivider className="mt-2 w-16 text-shallow" />
        </div>
      </header>

      {user && (
        <div className="mt-4 space-y-4">
          <section className="rounded-xl2 bg-white p-6 text-center shadow-log">
            {openSession ? (
              <>
                <p className="text-xs text-abyss/40">กำลังนอนมาแล้ว</p>
                <p className="my-2 font-display text-3xl font-bold text-tide">{elapsedLabel}</p>
                <button
                  onClick={handleEnd}
                  disabled={ending}
                  className="h-12 w-full rounded-full bg-glow text-sm font-semibold text-abyss disabled:opacity-60"
                >
                  {ending ? "..." : "☀️ ตื่นแล้ว"}
                </button>
              </>
            ) : (
              <>
                <p className="mb-3 text-sm text-abyss/50">ยังไม่ได้เริ่มจับเวลานอน</p>
                <button
                  onClick={handleStart}
                  disabled={starting}
                  className="h-12 w-full rounded-full bg-tide text-sm font-semibold text-white disabled:opacity-60"
                >
                  {starting ? "..." : "🌙 เริ่มนอน"}
                </button>
              </>
            )}
            <button
              onClick={() => setShowManual((v) => !v)}
              className="mt-3 text-xs text-abyss/40 underline"
            >
              {showManual ? "ปิด" : "ลืมกดจับเวลา? กรอกเองที่นี่"}
            </button>
          </section>

          {showManual && (
            <form
              onSubmit={handleManualSave}
              className="space-y-3 rounded-xl2 bg-white p-4 shadow-log"
            >
              <label className="block text-xs text-abyss/50">
                เวลาเริ่มนอน
                <input
                  type="datetime-local"
                  value={manualStart}
                  onChange={(e) => setManualStart(e.target.value)}
                  className="mt-1 w-full rounded-lg border border-shallow px-3 py-2 text-sm"
                  required
                />
              </label>
              <label className="block text-xs text-abyss/50">
                เวลาตื่น
                <input
                  type="datetime-local"
                  value={manualEnd}
                  onChange={(e) => setManualEnd(e.target.value)}
                  className="mt-1 w-full rounded-lg border border-shallow px-3 py-2 text-sm"
                  required
                />
              </label>
              <button
                type="submit"
                disabled={saving}
                className="h-11 w-full rounded-full bg-abyss text-sm font-semibold text-white disabled:opacity-60"
              >
                {saving ? "กำลังบันทึก..." : "บันทึก"}
              </button>
            </form>
          )}

          <section>
            <h2 className="mb-2 text-sm font-semibold text-abyss/60">ประวัติการนอน</h2>
            <ul className="space-y-2">
              {pastSessions.map((a) => (
                <li
                  key={a.id}
                  className="flex items-center justify-between rounded-xl2 bg-white p-3 shadow-log"
                >
                  <div>
                    <p className="text-sm font-medium text-abyss">{formatDuration(a.durationMin)}</p>
                    <p className="text-xs text-abyss/40">
                      {formatDateTime(a.startedAt)} – {formatDateTime(a.endedAt)}
                    </p>
                  </div>
                  <button
                    onClick={() => handleDelete(a.id)}
                    aria-label="ลบรายการนี้"
                    className="rounded-full px-2 py-1 text-xs text-abyss/30 hover:bg-surface hover:text-abyss/60"
                  >
                    ลบ
                  </button>
                </li>
              ))}
              {pastSessions.length === 0 && (
                <li className="rounded-xl2 bg-white p-6 text-center text-sm text-abyss/30 shadow-log">
                  ยังไม่มีประวัติการนอน
                </li>
              )}
            </ul>
          </section>
        </div>
      )}

      <BottomNav />
    </main>
  );
}
