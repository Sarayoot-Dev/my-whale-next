"use client";

import { useEffect, useState } from "react";
import { watchAuth } from "@/lib/firebase";
import { addAppointment, watchAppointments } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

const APPT_TYPES = {
  doctor: { label: "นัดแพทย์", icon: "🩺" },
  vaccine: { label: "วัคซีน", icon: "💉" },
  event: { label: "วันสำคัญ", icon: "🎉" },
};

export default function CalendarPage() {
  const [user, setUser] = useState(undefined);
  const [appointments, setAppointments] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [type, setType] = useState("doctor");
  const [title, setTitle] = useState("");
  const [date, setDate] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    return watchAppointments(CHILD_ID, setAppointments);
  }, [user]);

  const today = new Date().toISOString().slice(0, 10);
  const upcoming = appointments.filter((a) => a.date >= today);
  const past = appointments.filter((a) => a.date < today);

  async function handleSave(e) {
    e.preventDefault();
    if (!title || !date) return;
    setSaving(true);
    try {
      await addAppointment(CHILD_ID, { type, title, date });
      setTitle("");
      setDate("");
      setShowForm(false);
    } finally {
      setSaving(false);
    }
  }

  function renderItem(a) {
    return (
      <li key={a.id} className="flex items-center gap-3 rounded-xl2 bg-white p-3 shadow-log">
        <span className="text-xl" aria-hidden="true">
          {APPT_TYPES[a.type]?.icon}
        </span>
        <div>
          <p className="text-sm font-medium text-abyss">{a.title}</p>
          <p className="tabular-data text-xs text-abyss/40">{a.date}</p>
        </div>
      </li>
    );
  }

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2 flex items-center justify-between">
        <div>
          <h1 className="font-display text-2xl font-bold text-abyss">ปฏิทินนัดหมาย</h1>
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
          <div className="flex gap-2">
            {Object.entries(APPT_TYPES).map(([key, meta]) => (
              <button
                type="button"
                key={key}
                onClick={() => setType(key)}
                className={`rounded-full px-3 py-1.5 text-sm ${
                  type === key ? "bg-tide text-white" : "bg-surface text-abyss/50"
                }`}
              >
                {meta.icon} {meta.label}
              </button>
            ))}
          </div>
          <input
            type="text"
            placeholder="ชื่อรายการ เช่น นัดฉีดวัคซีนเข็มที่ 3"
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

      <section className="mb-6 mt-4">
        <h2 className="mb-2 text-sm font-semibold text-abyss/60">กำลังจะถึง</h2>
        <ul className="space-y-2">
          {upcoming.map(renderItem)}
          {upcoming.length === 0 && (
            <li className="rounded-xl2 bg-white p-4 text-center text-sm text-abyss/30 shadow-log">
              ไม่มีนัดหมายที่กำลังจะถึง
            </li>
          )}
        </ul>
      </section>

      {past.length > 0 && (
        <section>
          <h2 className="mb-2 text-sm font-semibold text-abyss/60">ผ่านมาแล้ว</h2>
          <ul className="space-y-2 opacity-60">{past.map(renderItem)}</ul>
        </section>
      )}

      <BottomNav />
    </main>
  );
}
