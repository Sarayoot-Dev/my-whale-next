"use client";

import { useEffect, useState, Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { auth, watchAuth } from "@/lib/firebase";
import { addActivity, deleteActivity, watchActivities, ACTIVITY_TYPES } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

const TYPE_ACCENT = {
  milk: "border-glow",
  sleep: "border-tide",
  vaccine: "border-abyss",
  growth: "border-shallow",
  doctor: "border-glow",
};

function formatTime(ts) {
  if (!ts?.toDate) return "";
  return ts.toDate().toLocaleString("th-TH", {
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default function Timeline() {
  return (
    <Suspense fallback={null}>
      <TimelineContent />
    </Suspense>
  );
}

function TimelineContent() {
  const searchParams = useSearchParams();
  const presetType = searchParams.get("type");
  const [user, setUser] = useState(undefined);
  const [activities, setActivities] = useState([]);
  const [filter, setFilter] = useState(presetType || "all");
  const [showForm, setShowForm] = useState(Boolean(presetType));
  const [type, setType] = useState(presetType || "milk");
  const [note, setNote] = useState("");
  const [weight, setWeight] = useState("");
  const [height, setHeight] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    return watchActivities(CHILD_ID, setActivities, { max: 100 });
  }, [user]);

  const filtered =
    filter === "all" ? activities : activities.filter((a) => a.type === filter);

  async function handleDelete(activityId) {
    if (!window.confirm("ลบรายการนี้ใช่ไหม?")) return;
    await deleteActivity(CHILD_ID, activityId);
  }

  async function handleSave(e) {
    e.preventDefault();
    setSaving(true);
    try {
      const entry = { type, note, createdBy: user?.displayName || "" };
      if (type === "growth") {
        entry.value = { weight: Number(weight), height: Number(height) };
      }
      await addActivity(CHILD_ID, entry);
      setNote("");
      setWeight("");
      setHeight("");
      setShowForm(false);
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2 flex items-center justify-between">
        <div>
          <h1 className="font-display text-2xl font-bold text-abyss">ไทม์ไลน์</h1>
          <WaveDivider className="mt-2 w-16 text-shallow" />
        </div>
        <button
          onClick={() => setShowForm((v) => !v)}
          className="h-11 rounded-full bg-tide px-5 text-sm font-semibold text-white shadow-log"
        >
          {showForm ? "ปิด" : "+ บันทึก"}
        </button>
      </header>

      {showForm && (
        <form
          onSubmit={handleSave}
          className="mb-4 mt-4 space-y-3 rounded-xl2 bg-white p-4 shadow-log"
        >
          <div className="flex flex-wrap gap-2">
            {Object.entries(ACTIVITY_TYPES).map(([key, meta]) => (
              <button
                type="button"
                key={key}
                onClick={() => setType(key)}
                className={`rounded-full px-3 py-1.5 text-sm ${
                  type === key
                    ? "bg-tide text-white"
                    : "bg-surface text-abyss/50"
                }`}
              >
                {meta.icon} {meta.label}
              </button>
            ))}
          </div>

          {type === "growth" ? (
            <div className="flex gap-2">
              <input
                type="number"
                step="0.1"
                placeholder="น้ำหนัก (กก.)"
                value={weight}
                onChange={(e) => setWeight(e.target.value)}
                className="w-1/2 rounded-lg border border-shallow px-3 py-2 text-sm"
                required
              />
              <input
                type="number"
                step="0.1"
                placeholder="ส่วนสูง (ซม.)"
                value={height}
                onChange={(e) => setHeight(e.target.value)}
                className="w-1/2 rounded-lg border border-shallow px-3 py-2 text-sm"
                required
              />
            </div>
          ) : (
            <input
              type="text"
              placeholder="รายละเอียด (ไม่บังคับ)"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
            />
          )}

          <button
            type="submit"
            disabled={saving}
            className="h-11 w-full rounded-full bg-abyss text-sm font-semibold text-white disabled:opacity-60"
          >
            {saving ? "กำลังบันทึก..." : "บันทึก"}
          </button>
        </form>
      )}

      <div className="mb-3 mt-4 flex gap-2 overflow-x-auto pb-1">
        <button
          onClick={() => setFilter("all")}
          className={`whitespace-nowrap rounded-full px-3 py-1.5 text-xs ${
            filter === "all" ? "bg-tide text-white" : "bg-white text-abyss/50 shadow-log"
          }`}
        >
          ทั้งหมด
        </button>
        {Object.entries(ACTIVITY_TYPES).map(([key, meta]) => (
          <button
            key={key}
            onClick={() => setFilter(key)}
            className={`whitespace-nowrap rounded-full px-3 py-1.5 text-xs ${
              filter === key ? "bg-tide text-white" : "bg-white text-abyss/50 shadow-log"
            }`}
          >
            {meta.icon} {meta.label}
          </button>
        ))}
      </div>

      <ul className="space-y-2">
        {filtered.map((a) => (
          <li
            key={a.id}
            className={`rounded-xl2 border-l-4 bg-white p-3 shadow-log ${TYPE_ACCENT[a.type] || "border-shallow"}`}
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span aria-hidden="true">{ACTIVITY_TYPES[a.type]?.icon}</span>
                <span className="text-sm font-medium text-abyss">
                  {ACTIVITY_TYPES[a.type]?.label}
                </span>
              </div>
              <div className="flex items-center gap-2">
                <span className="tabular-data text-xs text-abyss/40">{formatTime(a.createdAt)}</span>
                <button
                  onClick={() => handleDelete(a.id)}
                  aria-label="ลบรายการนี้"
                  className="rounded-full px-2 py-1 text-xs text-abyss/30 hover:bg-surface hover:text-abyss/60"
                >
                  ลบ
                </button>
              </div>
            </div>
            {a.type === "growth" && a.value && (
              <p className="mt-1 text-xs text-abyss/50">
                {a.value.weight} กก. · {a.value.height} ซม.
              </p>
            )}
            {a.note && <p className="mt-1 text-xs text-abyss/50">{a.note}</p>}
            {a.createdBy && (
              <p className="mt-1 text-xs text-tide/70">บันทึกโดย {a.createdBy}</p>
            )}
          </li>
        ))}
        {filtered.length === 0 && (
          <li className="rounded-xl2 bg-white p-6 text-center text-sm text-abyss/30 shadow-log">
            ยังไม่มีบันทึกในหมวดนี้
          </li>
        )}
      </ul>

      <BottomNav />
    </main>
  );
}
