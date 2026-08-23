"use client";

import { useEffect, useState } from "react";
import { watchAuth } from "@/lib/firebase";
import { addActivity, deleteActivity, watchActivities } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

const KIND_OPTIONS = [
  { key: "pee", label: "ฉี่", icon: "💧" },
  { key: "poop", label: "อึ", icon: "💩" },
  { key: "both", label: "ทั้งคู่", icon: "💧💩" },
];

const CONSISTENCY_OPTIONS = [
  { key: "loose", label: "เหลว" },
  { key: "normal", label: "ปกติ" },
  { key: "hard", label: "แข็ง" },
];

const COLOR_OPTIONS = [
  { key: "yellow", label: "เหลือง", swatch: "#F2C94C" },
  { key: "green", label: "เขียว", swatch: "#6FCF97" },
  { key: "brown", label: "น้ำตาล", swatch: "#A9744F" },
  { key: "black-red", label: "ดำ-แดง ⚠️", swatch: "#8B2E2E" },
];

function timeLabel(ts) {
  if (!ts?.toDate) return "";
  return ts.toDate().toLocaleTimeString("th-TH", { hour: "2-digit", minute: "2-digit" });
}

function hoursAgoLabel(ts) {
  if (!ts?.toDate) return null;
  const diffMs = Date.now() - ts.toDate().getTime();
  const minutes = Math.floor(diffMs / 60000);
  if (minutes < 60) return `${minutes} นาทีที่แล้ว`;
  const hours = Math.floor(minutes / 60);
  const remMinutes = minutes % 60;
  return remMinutes > 0 ? `${hours} ชม. ${remMinutes} นาทีที่แล้ว` : `${hours} ชม. ที่แล้ว`;
}

function isToday(ts) {
  if (!ts?.toDate) return false;
  const d = ts.toDate();
  const now = new Date();
  return (
    d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate()
  );
}

function describe(a) {
  const kindLabel = KIND_OPTIONS.find((k) => k.key === a.kind)?.label || "";
  if (a.kind === "pee") return kindLabel;
  const consistencyLabel = CONSISTENCY_OPTIONS.find((c) => c.key === a.consistency)?.label;
  const colorLabel = COLOR_OPTIONS.find((c) => c.key === a.color)?.label;
  return [kindLabel, consistencyLabel, colorLabel].filter(Boolean).join(" · ");
}

export default function DiaperPage() {
  const [user, setUser] = useState(undefined);
  const [activities, setActivities] = useState([]);
  const [kind, setKind] = useState("pee");
  const [consistency, setConsistency] = useState("normal");
  const [color, setColor] = useState("yellow");
  const [saving, setSaving] = useState(false);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    return watchActivities(CHILD_ID, setActivities, { max: 200 });
  }, [user]);

  const diaperEntries = activities.filter((a) => a.type === "diaper");
  const lastEntry = diaperEntries[0];
  const todayCount = diaperEntries.filter((a) => isToday(a.createdAt)).length;
  const hasPoop = kind === "poop" || kind === "both";

  const lastPoopWarning =
    lastEntry?.color === "black-red" && (lastEntry.kind === "poop" || lastEntry.kind === "both");

  async function handleSave() {
    setSaving(true);
    try {
      const entry = { type: "diaper", kind };
      if (hasPoop) {
        entry.consistency = consistency;
        entry.color = color;
      }
      await addActivity(CHILD_ID, entry);
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
      <header className="mb-2">
        <h1 className="font-display text-2xl font-bold text-abyss">ขับถ่าย</h1>
        <WaveDivider className="mt-2 w-16 text-shallow" />
      </header>

      {user && (
        <div className="mt-4 space-y-4">
          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <div className="grid grid-cols-2 gap-4 text-center">
              <div>
                <p className="text-lg font-semibold text-abyss">
                  {lastEntry ? hoursAgoLabel(lastEntry.createdAt) : "ยังไม่มีบันทึก"}
                </p>
                <p className="text-[11px] text-abyss/40">ล่าสุด</p>
              </div>
              <div>
                <p className="text-lg font-semibold text-abyss">{todayCount}</p>
                <p className="text-[11px] text-abyss/40">ครั้งวันนี้</p>
              </div>
            </div>
          </section>

          {lastPoopWarning && (
            <div className="rounded-xl2 bg-red-50 p-3 text-center text-xs text-red-700 shadow-log">
              ⚠️ อึล่าสุดมีสีดำ-แดง หากเกิดขึ้นต่อเนื่องควรปรึกษาแพทย์
            </div>
          )}

          <section className="space-y-3 rounded-xl2 bg-white p-4 shadow-log">
            <div className="grid grid-cols-3 gap-2">
              {KIND_OPTIONS.map((k) => (
                <button
                  key={k.key}
                  onClick={() => setKind(k.key)}
                  className={`flex flex-col items-center gap-1 rounded-xl2 py-3 text-sm ${
                    kind === k.key ? "bg-tide text-white" : "bg-surface text-abyss/60"
                  }`}
                >
                  <span className="text-xl" aria-hidden="true">{k.icon}</span>
                  {k.label}
                </button>
              ))}
            </div>

            {hasPoop && (
              <>
                <div>
                  <p className="mb-1.5 text-xs font-semibold text-abyss/50">ลักษณะ</p>
                  <div className="flex gap-2">
                    {CONSISTENCY_OPTIONS.map((c) => (
                      <button
                        key={c.key}
                        onClick={() => setConsistency(c.key)}
                        className={`flex-1 rounded-full px-3 py-1.5 text-sm ${
                          consistency === c.key ? "bg-tide text-white" : "bg-surface text-abyss/50"
                        }`}
                      >
                        {c.label}
                      </button>
                    ))}
                  </div>
                </div>
                <div>
                  <p className="mb-1.5 text-xs font-semibold text-abyss/50">สี</p>
                  <div className="flex flex-wrap gap-2">
                    {COLOR_OPTIONS.map((c) => (
                      <button
                        key={c.key}
                        onClick={() => setColor(c.key)}
                        className={`flex items-center gap-1.5 rounded-full px-3 py-1.5 text-sm ${
                          color === c.key ? "bg-tide text-white" : "bg-surface text-abyss/50"
                        }`}
                      >
                        <span
                          className="h-3 w-3 rounded-full"
                          style={{ backgroundColor: c.swatch }}
                          aria-hidden="true"
                        />
                        {c.label}
                      </button>
                    ))}
                  </div>
                </div>
              </>
            )}

            <button
              onClick={handleSave}
              disabled={saving}
              className="h-11 w-full rounded-full bg-abyss text-sm font-semibold text-white disabled:opacity-60"
            >
              {saving ? "กำลังบันทึก..." : "บันทึก"}
            </button>
          </section>

          <ul className="space-y-2">
            {diaperEntries
              .filter((a) => isToday(a.createdAt))
              .map((a) => (
                <li
                  key={a.id}
                  className="flex items-center justify-between rounded-xl2 bg-white p-3 shadow-log"
                >
                  <div>
                    <p className="text-sm font-medium text-abyss">{describe(a)}</p>
                    <p className="text-xs text-abyss/40">{timeLabel(a.createdAt)}</p>
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
            {diaperEntries.filter((a) => isToday(a.createdAt)).length === 0 && (
              <li className="rounded-xl2 bg-white p-6 text-center text-sm text-abyss/30 shadow-log">
                ยังไม่มีบันทึกวันนี้
              </li>
            )}
          </ul>
        </div>
      )}

      <BottomNav />
    </main>
  );
}
