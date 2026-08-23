"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { watchAuth } from "@/lib/firebase";
import { getChild, saveChild, watchActivities } from "@/lib/family";
import { getGrowthPercentileCurve, ageInDaysFromDob } from "@/lib/growth";
import { MILESTONE_CHECKLIST } from "@/lib/checklists";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";
import {
  ResponsiveContainer,
  ComposedChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
} from "recharts";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

const BAND_STYLE = {
  p3: "#D6ECFB",
  p50: "#4F9DDE",
  p97: "#D6ECFB",
};

export default function MilestonesPage() {
  const [user, setUser] = useState(undefined);
  const [child, setChild] = useState(null);
  const [activities, setActivities] = useState([]);
  const [milestonesDone, setMilestonesDone] = useState({});
  const [weightCurve, setWeightCurve] = useState([]);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    getChild(CHILD_ID).then((c) => {
      setChild(c);
      setMilestonesDone(c?.milestonesDone || {});
    });
    return watchActivities(CHILD_ID, setActivities, { max: 300 });
  }, [user]);

  const gender = child?.gender === "female" ? "female" : "male";
  const ageDaysNow = child?.dob ? ageInDaysFromDob(child.dob) : null;

  useEffect(() => {
    if (ageDaysNow == null) return;
    getGrowthPercentileCurve("weight", gender, Math.max(ageDaysNow + 90, 180)).then(setWeightCurve);
  }, [ageDaysNow, gender]);

  const chartData = useMemo(() => {
    if (!child?.dob) return [];
    const points = activities
      .filter((a) => a.type === "growth" && a.value)
      .map((a) => {
        const d = a.createdAt?.toDate ? a.createdAt.toDate() : null;
        const ageDays = d ? ageInDaysFromDob(child.dob, d) : null;
        return ageDays != null
          ? { ageMonths: +(ageDays / 30.4375).toFixed(1), child: a.value.weight }
          : null;
      })
      .filter(Boolean);
    const map = new Map(weightCurve.map((c) => [c.ageMonths, { ...c }]));
    points.forEach((p) => {
      const existing = map.get(p.ageMonths) || { ageMonths: p.ageMonths };
      existing.child = p.child;
      map.set(p.ageMonths, existing);
    });
    return Array.from(map.values()).sort((a, b) => a.ageMonths - b.ageMonths);
  }, [weightCurve, activities, child]);

  async function toggleMilestone(key) {
    const next = { ...milestonesDone, [key]: !milestonesDone[key] };
    setMilestonesDone(next);
    await saveChild(CHILD_ID, { milestonesDone: { [key]: next[key] } });
  }

  const totalItems = MILESTONE_CHECKLIST.reduce((sum, g) => sum + g.items.length, 0);
  const doneItems = Object.values(milestonesDone).filter(Boolean).length;

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2 flex items-center gap-2">
        <Link href="/health" aria-label="กลับ" className="text-xl text-abyss/40">
          ←
        </Link>
        <div>
          <h1 className="font-display text-2xl font-bold text-abyss">พัฒนาการ</h1>
          <WaveDivider className="mt-2 w-16 text-shallow" />
        </div>
      </header>

      {user && (
        <div className="mt-4 space-y-4">
          {child?.dob && (
            <section className="rounded-xl2 bg-white p-4 shadow-log">
              <div className="mb-1 flex items-center justify-between">
                <p className="text-sm font-semibold text-abyss/60">แนวโน้มน้ำหนัก (WHO)</p>
                <Link href="/health/growth" className="text-xs text-tide underline">
                  ดูกราฟเต็ม →
                </Link>
              </div>
              <div style={{ width: "100%", height: 140 }}>
                <ResponsiveContainer>
                  <ComposedChart data={chartData} margin={{ top: 4, right: 4, left: -20, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#D6ECFB" />
                    <XAxis dataKey="ageMonths" type="number" tick={{ fontSize: 9, fill: "#2D3A4A" }} />
                    <YAxis tick={{ fontSize: 9, fill: "#2D3A4A" }} width={24} />
                    <Tooltip />
                    {Object.entries(BAND_STYLE).map(([key, color]) => (
                      <Line
                        key={key}
                        type="monotone"
                        dataKey={key}
                        stroke={color}
                        strokeWidth={1}
                        dot={false}
                        strokeDasharray={key === "p50" ? undefined : "4 3"}
                        connectNulls
                        isAnimationActive={false}
                      />
                    ))}
                    <Line
                      type="monotone"
                      dataKey="child"
                      stroke="#FFD166"
                      strokeWidth={2.5}
                      dot={{ r: 3, fill: "#FFD166" }}
                      connectNulls
                      isAnimationActive={false}
                    />
                  </ComposedChart>
                </ResponsiveContainer>
              </div>
            </section>
          )}

          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <div className="mb-3 flex items-center justify-between">
              <h2 className="text-sm font-semibold text-abyss/60">checklist พัฒนาการตามช่วงอายุ</h2>
              <span className="text-xs text-abyss/40">
                {doneItems}/{totalItems}
              </span>
            </div>
            <div className="space-y-4">
              {MILESTONE_CHECKLIST.map((group) => (
                <div key={group.range}>
                  <p className="mb-1.5 text-xs font-semibold text-tide">{group.range}</p>
                  <ul className="space-y-1">
                    {group.items.map((item) => (
                      <li key={item.key}>
                        <label className="flex items-center gap-3 rounded-lg p-1.5 hover:bg-surface">
                          <input
                            type="checkbox"
                            checked={Boolean(milestonesDone[item.key])}
                            onChange={() => toggleMilestone(item.key)}
                            className="h-5 w-5 shrink-0 accent-tide"
                          />
                          <span
                            className={`text-sm ${
                              milestonesDone[item.key] ? "text-abyss/40 line-through" : "text-abyss"
                            }`}
                          >
                            {item.label}
                          </span>
                        </label>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          </section>
        </div>
      )}

      <BottomNav />
    </main>
  );
}
