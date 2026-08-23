"use client";

import { useEffect, useState } from "react";
import { watchAuth } from "@/lib/firebase";
import { addMilestone, deleteMilestone, watchMilestones, MILESTONE_COLORS } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

export default function MilestonesPage() {
  const [user, setUser] = useState(undefined);
  const [milestones, setMilestones] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [title, setTitle] = useState("");
  const [date, setDate] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    return watchMilestones(CHILD_ID, setMilestones);
  }, [user]);

  async function handleSave(e) {
    e.preventDefault();
    if (!title || !date) return;
    setSaving(true);
    try {
      await addMilestone(CHILD_ID, { title, date });
      setTitle("");
      setDate("");
      setShowForm(false);
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id) {
    if (!window.confirm("ลบรายการนี้ใช่ไหม?")) return;
    await deleteMilestone(CHILD_ID, id);
  }

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2 flex items-center justify-between">
        <div>
          <h1 className="font-display text-2xl font-bold text-abyss">ไทม์ไลน์พัฒนาการ</h1>
          <WaveDivider className="mt-2 w-16 text-shallow" />
        </div>
        <button
          onClick={() => setShowForm((v) => !v)}
          className="h-11 rounded-full bg-tide px-5 text-sm font-semibold text-white shadow-log"
        >
          {showForm ? "ปิด" : "+ เพิ่ม"}
        </button>
      </header>

      {showForm && (
        <form onSubmit={handleSave} className="mb-4 mt-4 space-y-3 rounded-xl2 bg-white p-4 shadow-log">
          <input
            type="text"
            placeholder="เช่น นั่งได้เอง, คลานได้, พูดคำแรก"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
            required
          />
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
            required
          />
          <button
            type="submit"
            disabled={saving}
            className="h-11 w-full rounded-full bg-abyss text-sm font-semibold text-white disabled:opacity-60"
          >
            {saving ? "กำลังบันทึก..." : "บันทึก"}
          </button>
        </form>
      )}

      <ul className="mt-4 space-y-4 border-l-2 border-shallow pl-4">
        {milestones.map((m, i) => (
          <li key={m.id} className="relative">
            <span
              className="absolute -left-[27px] top-0.5 flex h-5 w-5 items-center justify-center rounded-full text-[10px] font-bold text-white"
              style={{ backgroundColor: MILESTONE_COLORS[i % MILESTONE_COLORS.length] }}
              aria-hidden="true"
            >
              ★
            </span>
            <div className="flex items-center justify-between rounded-xl2 bg-white p-3 shadow-log">
              <div>
                <p className="text-sm font-medium text-abyss">{m.title}</p>
                <p className="tabular-data text-xs text-abyss/40">{m.date}</p>
              </div>
              <button
                onClick={() => handleDelete(m.id)}
                aria-label="ลบรายการนี้"
                className="rounded-full px-2 py-1 text-xs text-abyss/30 hover:bg-surface hover:text-abyss/60"
              >
                ลบ
              </button>
            </div>
          </li>
        ))}
        {milestones.length === 0 && (
          <li className="rounded-xl2 bg-white p-6 text-center text-sm text-abyss/30 shadow-log">
            ยังไม่มีบันทึกพัฒนาการ — กด + เพิ่ม เพื่อเริ่มบันทึก
          </li>
        )}
      </ul>

      <BottomNav />
    </main>
  );
}
