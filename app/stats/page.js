"use client";

import { useEffect, useState } from "react";
import { watchAuth } from "@/lib/firebase";
import { watchActivities } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
} from "recharts";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

function lastNDays(n) {
  const days = [];
  for (let i = n - 1; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    days.push(d);
  }
  return days;
}

function dayLabel(d) {
  return d.toLocaleDateString("th-TH", { day: "numeric", month: "short" });
}

function sameDay(a, b) {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

export default function StatsPage() {
  const [user, setUser] = useState(undefined);
  const [activities, setActivities] = useState([]);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    return watchActivities(CHILD_ID, setActivities, { max: 300 });
  }, [user]);

  const days = lastNDays(7);
  const milkPerDay = days.map((d) => ({
    day: dayLabel(d),
    ครั้ง: activities.filter((a) => a.type === "milk" && a.createdAt?.toDate && sameDay(a.createdAt.toDate(), d)).length,
  }));

  const growthEntries = activities
    .filter((a) => a.type === "growth" && a.value)
    .slice()
    .reverse();
  const weightTrend = growthEntries.map((a) => ({
    day: a.createdAt?.toDate ? dayLabel(a.createdAt.toDate()) : "",
    กก: a.value.weight,
  }));
  const heightTrend = growthEntries.map((a) => ({
    day: a.createdAt?.toDate ? dayLabel(a.createdAt.toDate()) : "",
    ซม: a.value.height,
  }));

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2">
        <h1 className="font-display text-2xl font-bold text-abyss">สถิติ & กราฟ</h1>
        <WaveDivider className="mt-2 w-16 text-shallow" />
      </header>

      {user && (
        <div className="mt-4 space-y-4">
          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <p className="mb-2 text-sm font-semibold text-abyss/60">การกินนม (ครั้ง/วัน)</p>
            <div style={{ width: "100%", height: 160 }}>
              <ResponsiveContainer>
                <BarChart data={milkPerDay}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#D6ECFB" />
                  <XAxis dataKey="day" tick={{ fontSize: 11, fill: "#2D3A4A" }} />
                  <YAxis allowDecimals={false} tick={{ fontSize: 11, fill: "#2D3A4A" }} width={24} />
                  <Tooltip />
                  <Bar dataKey="ครั้ง" fill="#4F9DDE" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </section>

          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <p className="mb-2 text-sm font-semibold text-abyss/60">น้ำหนัก (กก.)</p>
            {weightTrend.length > 0 ? (
              <div style={{ width: "100%", height: 160 }}>
                <ResponsiveContainer>
                  <LineChart data={weightTrend}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#D6ECFB" />
                    <XAxis dataKey="day" tick={{ fontSize: 11, fill: "#2D3A4A" }} />
                    <YAxis tick={{ fontSize: 11, fill: "#2D3A4A" }} width={28} />
                    <Tooltip />
                    <Line type="monotone" dataKey="กก" stroke="#4F9DDE" strokeWidth={2} dot={{ r: 3 }} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <p className="py-6 text-center text-sm text-abyss/30">ยังไม่มีบันทึกน้ำหนัก</p>
            )}
          </section>

          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <p className="mb-2 text-sm font-semibold text-abyss/60">ส่วนสูง (ซม.)</p>
            {heightTrend.length > 0 ? (
              <div style={{ width: "100%", height: 160 }}>
                <ResponsiveContainer>
                  <LineChart data={heightTrend}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#D6ECFB" />
                    <XAxis dataKey="day" tick={{ fontSize: 11, fill: "#2D3A4A" }} />
                    <YAxis tick={{ fontSize: 11, fill: "#2D3A4A" }} width={28} />
                    <Tooltip />
                    <Line type="monotone" dataKey="ซม" stroke="#FFD166" strokeWidth={2} dot={{ r: 3 }} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <p className="py-6 text-center text-sm text-abyss/30">ยังไม่มีบันทึกส่วนสูง</p>
            )}
          </section>

          <p className="text-center text-xs text-abyss/30">
            กราฟการนอนแบบชั่วโมง/วัน จะแม่นยำขึ้นเมื่อเพิ่มฟีเจอร์ตัวจับเวลานอนในอนาคต
          </p>
        </div>
      )}

      <BottomNav />
    </main>
  );
}
