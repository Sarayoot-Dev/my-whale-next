"use client";

import { useEffect, useMemo, useState } from "react";
import { watchAuth } from "@/lib/firebase";
import { addActivity, deleteActivity, watchActivities } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
} from "recharts";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

const MILK_TYPES = { breast: "นมแม่", formula: "นมชง" };

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

export default function FeedPage() {
  const [user, setUser] = useState(undefined);
  const [activities, setActivities] = useState([]);
  const [kind, setKind] = useState("milk");
  const [amountOz, setAmountOz] = useState("");
  const [milkType, setMilkType] = useState("breast");
  const [menu, setMenu] = useState("");
  const [amount, setAmount] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    return watchActivities(CHILD_ID, setActivities, { max: 200 });
  }, [user]);

  const entriesOfKind = activities.filter((a) => a.type === kind);
  const lastEntry = entriesOfKind[0];
  const todayEntries = entriesOfKind.filter((a) => isToday(a.createdAt)).slice().reverse();

  const chartData = useMemo(
    () =>
      todayEntries.map((a) => ({
        time: timeLabel(a.createdAt),
        จำนวน: kind === "milk" ? Number(a.amountOz) || 0 : 1,
        label: kind === "milk" ? `${a.amountOz} oz (${MILK_TYPES[a.milkType] || ""})` : a.menu,
      })),
    [todayEntries, kind]
  );

  async function handleSave(e) {
    e.preventDefault();
    setSaving(true);
    try {
      if (kind === "milk") {
        if (!amountOz) return;
        await addActivity(CHILD_ID, { type: "milk", amountOz: Number(amountOz), milkType });
        setAmountOz("");
      } else {
        if (!menu) return;
        await addActivity(CHILD_ID, { type: "food", menu, amount });
        setMenu("");
        setAmount("");
      }
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
        <h1 className="font-display text-2xl font-bold text-abyss">Feed</h1>
        <WaveDivider className="mt-2 w-16 text-shallow" />
      </header>

      {user && (
        <div className="mt-4 space-y-4">
          <select
            value={kind}
            onChange={(e) => setKind(e.target.value)}
            className="w-full rounded-xl2 border border-shallow bg-white px-4 py-3 text-sm font-semibold text-abyss shadow-log"
          >
            <option value="milk">🍼 นม</option>
            <option value="food">🍚 อาหาร</option>
          </select>

          <form onSubmit={handleSave} className="space-y-3 rounded-xl2 bg-white p-4 shadow-log">
            {kind === "milk" ? (
              <>
                <input
                  type="number"
                  step="0.5"
                  placeholder="จำนวนออนส์"
                  value={amountOz}
                  onChange={(e) => setAmountOz(e.target.value)}
                  className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
                  required
                />
                <div className="flex gap-2">
                  {Object.entries(MILK_TYPES).map(([key, label]) => (
                    <button
                      type="button"
                      key={key}
                      onClick={() => setMilkType(key)}
                      className={`flex-1 rounded-full px-3 py-1.5 text-sm ${
                        milkType === key ? "bg-tide text-white" : "bg-surface text-abyss/50"
                      }`}
                    >
                      {label}
                    </button>
                  ))}
                </div>
              </>
            ) : (
              <>
                <input
                  type="text"
                  placeholder="เมนู"
                  value={menu}
                  onChange={(e) => setMenu(e.target.value)}
                  className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
                  required
                />
                <input
                  type="text"
                  placeholder="ปริมาณ เช่น 2 ช้อนโต๊ะ"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
                />
              </>
            )}
            <button
              type="submit"
              disabled={saving}
              className="h-11 w-full rounded-full bg-tide text-sm font-semibold text-white disabled:opacity-60"
            >
              {saving ? "กำลังบันทึก..." : "บันทึก"}
            </button>
          </form>

          <section className="rounded-xl2 bg-white p-4 text-center shadow-log">
            <p className="text-xs text-abyss/40">
              {kind === "milk" ? "ให้นมล่าสุด" : "กินอาหารล่าสุด"}
            </p>
            <p className="mt-1 text-lg font-semibold text-abyss">
              {lastEntry ? hoursAgoLabel(lastEntry.createdAt) : "ยังไม่มีบันทึก"}
            </p>
          </section>

          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <p className="mb-2 text-sm font-semibold text-abyss/60">
              {kind === "milk" ? "ปริมาณนมวันนี้ (ออนส์)" : "มื้ออาหารวันนี้"}
            </p>
            {chartData.length > 0 ? (
              <div style={{ width: "100%", height: 160 }}>
                <ResponsiveContainer>
                  <BarChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#D6ECFB" />
                    <XAxis dataKey="time" tick={{ fontSize: 10, fill: "#2D3A4A" }} />
                    <YAxis allowDecimals={false} tick={{ fontSize: 10, fill: "#2D3A4A" }} width={24} />
                    <Tooltip formatter={(v, n, p) => [p.payload.label, ""]} />
                    <Bar dataKey="จำนวน" fill="#4F9DDE" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <p className="py-6 text-center text-sm text-abyss/30">ยังไม่มีบันทึกวันนี้</p>
            )}
          </section>

          <ul className="space-y-2">
            {todayEntries
              .slice()
              .reverse()
              .map((a) => (
                <li
                  key={a.id}
                  className="flex items-center justify-between rounded-xl2 bg-white p-3 shadow-log"
                >
                  <div>
                    <p className="text-sm font-medium text-abyss">
                      {kind === "milk" ? `${a.amountOz} oz · ${MILK_TYPES[a.milkType] || ""}` : a.menu}
                      {kind === "food" && a.amount ? ` · ${a.amount}` : ""}
                    </p>
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
          </ul>
        </div>
      )}

      <BottomNav />
    </main>
  );
}
