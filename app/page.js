"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { watchAuth, signIn } from "@/lib/firebase";
import { getChild, watchActivities, addActivity, deleteActivity, ACTIVITY_TYPES } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

const TYPE_ACCENT = {
  milk: "border-glow",
  sleep: "border-tide",
  diaper: "border-glow",
  vaccine: "border-tide",
  growth: "border-shallow",
  doctor: "border-glow",
};

const FUNCTIONS = [
  { key: "milk", label: "บันทึกการกินนม", icon: "🍼", href: "/timeline?type=milk" },
  { key: "sleep", label: "บันทึกการนอน", icon: "🌙", href: "/timeline?type=sleep" },
  { key: "diaper", label: "เปลี่ยนแพมเพิส", icon: "🧷", href: "/timeline?type=diaper" },
  { key: "growth", label: "บันทึกการเจริญเติบโต", icon: "📏", href: "/timeline?type=growth" },
  { key: "gallery", label: "แกลเลอรี่", icon: "📷", href: "/gallery" },
  { key: "milestones", label: "ไทม์ไลน์พัฒนาการ", icon: "⭐", href: "/milestones" },
  { key: "stats", label: "สถิติ & กราฟ", icon: "📊", href: "/stats" },
  { key: "more", label: "เพิ่มเติม", icon: "⚙️", href: "/settings" },
];

function ageLabel(dob) {
  if (!dob) return "";
  const birth = new Date(dob);
  const now = new Date();
  let months =
    (now.getFullYear() - birth.getFullYear()) * 12 +
    (now.getMonth() - birth.getMonth());
  if (now.getDate() < birth.getDate()) months -= 1;
  if (months < 1) return "แรกเกิด";
  if (months < 24) return `${months} เดือน`;
  return `${Math.floor(months / 12)} ปี ${months % 12} เดือน`;
}

function elapsedLabel(ts) {
  if (!ts?.toDate) return null;
  const diffMs = Date.now() - ts.toDate().getTime();
  const minutes = Math.floor(diffMs / 60000);
  if (minutes < 1) return "เมื่อสักครู่";
  if (minutes < 60) return `${minutes} นาทีที่แล้ว`;
  const hours = Math.floor(minutes / 60);
  const remMinutes = minutes % 60;
  if (hours < 24) {
    return remMinutes > 0 ? `${hours} ชม. ${remMinutes} นาทีที่แล้ว` : `${hours} ชม. ที่แล้ว`;
  }
  return `${Math.floor(hours / 24)} วันที่แล้ว`;
}

function greeting() {
  const hour = new Date().getHours();
  if (hour < 11) return "สวัสดีตอนเช้าครับ";
  if (hour < 17) return "สวัสดีตอนบ่ายครับ";
  return "สวัสดีตอนเย็นครับ";
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

export default function Dashboard() {
  const [user, setUser] = useState(undefined);
  const [child, setChild] = useState(null);
  const [activities, setActivities] = useState([]);
  const [quickLogging, setQuickLogging] = useState(false);
  const [, forceTick] = useState(0);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    getChild(CHILD_ID).then(setChild);
    const unsub = watchActivities(CHILD_ID, setActivities, { max: 50 });
    return unsub;
  }, [user]);

  useEffect(() => {
    const id = setInterval(() => forceTick((t) => t + 1), 30000);
    return () => clearInterval(id);
  }, []);

  const latestMilk = activities.find((a) => a.type === "milk");
  const todayCount = (type) => activities.filter((a) => a.type === type && isToday(a.createdAt)).length;

  async function quickLogMilk() {
    setQuickLogging(true);
    try {
      await addActivity(CHILD_ID, { type: "milk", note: "", createdBy: user?.displayName || "" });
    } finally {
      setQuickLogging(false);
    }
  }

  async function handleDelete(activityId) {
    if (!window.confirm("ลบรายการนี้ใช่ไหม?")) return;
    await deleteActivity(CHILD_ID, activityId);
  }

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2">
        <h1 className="font-display text-2xl font-bold text-abyss">🐳 My Whale</h1>
        <WaveDivider className="mt-2 text-shallow" />
      </header>

      {user === undefined && <p className="mt-6 text-sm text-tide/70">กำลังโหลด...</p>}

      {user === null && (
        <div className="mt-6 rounded-xl2 bg-white p-6 text-center shadow-log">
          <p className="mb-4 text-sm text-abyss/70">เข้าสู่ระบบเพื่อดูและบันทึกข้อมูลของลูก</p>
          <button
            onClick={signIn}
            className="rounded-full bg-tide px-6 py-2.5 font-semibold text-white transition hover:bg-abyss"
          >
            เข้าสู่ระบบด้วย Google
          </button>
        </div>
      )}

      {user && (
        <div className="mt-6 space-y-4">
          <section className="rounded-xl2 bg-white p-5 shadow-log">
            <p className="mb-3 text-sm text-abyss/60">{greeting()}</p>
            <div className="flex items-center gap-4">
              <div className="flex h-20 w-20 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-shallow to-tide/20 text-4xl shadow-log">
                🐳
              </div>
              <div>
                <p className="font-display text-xl font-semibold text-abyss">
                  {child?.name || "ยังไม่ตั้งชื่อ"}
                </p>
                <p className="text-sm text-abyss/50">
                  {child?.dob ? ageLabel(child.dob) : "ยังไม่ระบุวันเกิด"}
                </p>
              </div>
            </div>
          </section>

          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <p className="mb-2 text-xs font-semibold text-abyss/50">ภาพรวมวันนี้</p>
            <div className="grid grid-cols-3 gap-2 text-center">
              <div>
                <p className="text-lg font-semibold text-abyss">{todayCount("milk")}</p>
                <p className="text-[11px] text-abyss/40">🍼 ครั้ง</p>
              </div>
              <div>
                <p className="text-lg font-semibold text-abyss">{todayCount("sleep")}</p>
                <p className="text-[11px] text-abyss/40">🌙 ครั้ง</p>
              </div>
              <div>
                <p className="text-lg font-semibold text-abyss">{todayCount("diaper")}</p>
                <p className="text-[11px] text-abyss/40">🧷 ครั้ง</p>
              </div>
            </div>
          </section>

          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs text-abyss/40">ให้นมล่าสุด</p>
                <p className="text-sm font-medium text-abyss">
                  {latestMilk ? elapsedLabel(latestMilk.createdAt) : "ยังไม่มีบันทึก"}
                </p>
              </div>
              <button
                onClick={quickLogMilk}
                disabled={quickLogging}
                className="h-11 whitespace-nowrap rounded-full bg-glow px-4 text-sm font-semibold text-abyss disabled:opacity-60"
              >
                {quickLogging ? "กำลังบันทึก..." : "🍼 ให้นมแล้ว"}
              </button>
            </div>
          </section>

          <section>
            <p className="mb-2 text-sm font-semibold text-abyss/60">ฟังก์ชันหลัก</p>
            <div className="grid grid-cols-4 gap-3">
              {FUNCTIONS.map((f) => (
                <Link
                  key={f.key}
                  href={f.href}
                  className="flex flex-col items-center gap-1.5 rounded-xl2 bg-white p-3 text-center shadow-log"
                >
                  <span className="flex h-11 w-11 items-center justify-center rounded-full bg-surface text-xl">
                    {f.icon}
                  </span>
                  <span className="text-[11px] leading-tight text-abyss/70">{f.label}</span>
                </Link>
              ))}
            </div>
          </section>

          <section>
            <h2 className="mb-2 text-sm font-semibold text-abyss/60">กิจกรรมล่าสุด</h2>
            <ul className="space-y-2">
              {activities.slice(0, 5).map((a) => (
                <li
                  key={a.id}
                  className={`flex items-center justify-between gap-3 rounded-xl2 border-l-4 bg-white p-3 shadow-log ${TYPE_ACCENT[a.type] || "border-shallow"}`}
                >
                  <div className="flex items-center gap-3">
                    <span className="text-xl" aria-hidden="true">{ACTIVITY_TYPES[a.type]?.icon}</span>
                    <div>
                      <p className="text-sm font-medium text-abyss">{ACTIVITY_TYPES[a.type]?.label}</p>
                      {a.note && <p className="text-xs text-abyss/40">{a.note}</p>}
                    </div>
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
              {activities.length === 0 && (
                <li className="rounded-xl2 bg-white p-4 text-center text-sm text-abyss/30 shadow-log">
                  ยังไม่มีบันทึก — เริ่มบันทึกได้จากฟังก์ชันด้านบน
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
