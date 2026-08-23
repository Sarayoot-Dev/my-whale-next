"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { watchAuth } from "@/lib/firebase";
import { getChild, addActivity, watchActivities } from "@/lib/family";
import { getGrowthPercentileCurve, getGrowthZScore, ageInDaysFromDob } from "@/lib/growth";
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
  p3: { stroke: "#D6ECFB", label: "P3" },
  p15: { stroke: "#BFE1EC", label: "P15" },
  p50: { stroke: "#4F9DDE", label: "P50" },
  p85: { stroke: "#BFE1EC", label: "P85" },
  p97: { stroke: "#D6ECFB", label: "P97" },
};

function mergeChildSeries(curve, entries, valueKey) {
  const map = new Map(curve.map((c) => [c.ageMonths, { ...c }]));
  entries.forEach((e) => {
    const existing = map.get(e.ageMonths) || { ageMonths: e.ageMonths };
    existing.child = e.value[valueKey];
    map.set(e.ageMonths, existing);
  });
  return Array.from(map.values()).sort((a, b) => a.ageMonths - b.ageMonths);
}

export default function GrowthPage() {
  const [user, setUser] = useState(undefined);
  const [child, setChild] = useState(null);
  const [activities, setActivities] = useState([]);
  const [weight, setWeight] = useState("");
  const [height, setHeight] = useState("");
  const [saving, setSaving] = useState(false);
  const [weightCurve, setWeightCurve] = useState([]);
  const [heightCurve, setHeightCurve] = useState([]);
  const [weightZ, setWeightZ] = useState(null);
  const [heightZ, setHeightZ] = useState(null);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    getChild(CHILD_ID).then(setChild);
    return watchActivities(CHILD_ID, setActivities, { max: 300 });
  }, [user]);

  const gender = child?.gender === "female" ? "female" : "male";
  const ageDaysNow = child?.dob ? ageInDaysFromDob(child.dob) : null;

  useEffect(() => {
    if (ageDaysNow == null) return;
    const maxAge = Math.max(ageDaysNow + 90, 180);
    getGrowthPercentileCurve("weight", gender, maxAge).then(setWeightCurve);
    getGrowthPercentileCurve("height", gender, maxAge).then(setHeightCurve);
  }, [ageDaysNow, gender]);

  const growthEntries = useMemo(() => {
    if (!child?.dob) return [];
    return activities
      .filter((a) => a.type === "growth" && a.value)
      .map((a) => {
        const d = a.createdAt?.toDate ? a.createdAt.toDate() : null;
        const ageDays = d ? ageInDaysFromDob(child.dob, d) : null;
        return {
          ...a,
          ageDays,
          ageMonths: ageDays != null ? +(ageDays / 30.4375).toFixed(1) : null,
        };
      })
      .filter((a) => a.ageDays != null)
      .sort((a, b) => a.ageDays - b.ageDays);
  }, [activities, child]);

  const weightChartData = useMemo(
    () => mergeChildSeries(weightCurve, growthEntries, "weight"),
    [weightCurve, growthEntries]
  );
  const heightChartData = useMemo(
    () => mergeChildSeries(heightCurve, growthEntries, "height"),
    [heightCurve, growthEntries]
  );

  const latestGrowth = growthEntries[growthEntries.length - 1];

  useEffect(() => {
    if (!latestGrowth) {
      setWeightZ(null);
      setHeightZ(null);
      return;
    }
    getGrowthZScore("weight", gender, latestGrowth.ageDays, latestGrowth.value.weight).then(setWeightZ);
    getGrowthZScore("height", gender, latestGrowth.ageDays, latestGrowth.value.height).then(setHeightZ);
  }, [latestGrowth, gender]);

  async function handleSave(e) {
    e.preventDefault();
    if (!weight || !height) return;
    setSaving(true);
    try {
      await addActivity(CHILD_ID, {
        type: "growth",
        value: { weight: Number(weight), height: Number(height) },
      });
      setWeight("");
      setHeight("");
    } finally {
      setSaving(false);
    }
  }

  function renderChart(data, valueLabel) {
    return (
      <div style={{ width: "100%", height: 220 }}>
        <ResponsiveContainer>
          <ComposedChart data={data} margin={{ top: 4, right: 8, left: -12, bottom: 4 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#D6ECFB" />
            <XAxis
              dataKey="ageMonths"
              type="number"
              tick={{ fontSize: 10, fill: "#2D3A4A" }}
              label={{ value: "อายุ (เดือน)", position: "insideBottom", offset: -2, fontSize: 10 }}
            />
            <YAxis tick={{ fontSize: 10, fill: "#2D3A4A" }} width={32} />
            <Tooltip />
            {Object.entries(BAND_STYLE).map(([key, s]) => (
              <Line
                key={key}
                type="monotone"
                dataKey={key}
                stroke={s.stroke}
                strokeWidth={1}
                dot={false}
                strokeDasharray={key === "p50" ? undefined : "4 3"}
                name={s.label}
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
              name={valueLabel}
              connectNulls
              isAnimationActive={false}
            />
          </ComposedChart>
        </ResponsiveContainer>
      </div>
    );
  }

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2 flex items-center gap-2">
        <Link href="/health" aria-label="กลับ" className="text-xl text-abyss/40">
          ←
        </Link>
        <div>
          <h1 className="font-display text-2xl font-bold text-abyss">น้ำหนัก/ส่วนสูง</h1>
          <WaveDivider className="mt-2 w-16 text-shallow" />
        </div>
      </header>

      {user && !child?.dob && (
        <p className="mt-4 rounded-xl2 bg-white p-4 text-sm text-abyss/60 shadow-log">
          กรุณาระบุวันเกิดลูกที่หน้า{" "}
          <Link href="/settings" className="text-tide underline">
            ตั้งค่า
          </Link>{" "}
          ก่อน เพื่อคำนวณกราฟเทียบมาตรฐาน WHO
        </p>
      )}

      {user && child?.dob && (
        <div className="mt-4 space-y-4">
          <form onSubmit={handleSave} className="flex gap-2 rounded-xl2 bg-white p-4 shadow-log">
            <input
              type="number"
              step="0.01"
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
            <button
              type="submit"
              disabled={saving}
              className="shrink-0 rounded-full bg-tide px-4 text-sm font-semibold text-white disabled:opacity-60"
            >
              {saving ? "..." : "บันทึก"}
            </button>
          </form>

          {latestGrowth && (
            <section className="rounded-xl2 bg-white p-4 shadow-log">
              <p className="mb-2 text-xs font-semibold text-abyss/50">
                เปอร์เซ็นไทล์ล่าสุด (เทียบมาตรฐาน WHO)
              </p>
              <div className="flex gap-6">
                <div>
                  <p className="text-lg font-semibold text-abyss">
                    {weightZ ? `${weightZ.percentile.toFixed(0)} th` : "-"}
                  </p>
                  <p className="text-[11px] text-abyss/40">น้ำหนักตามอายุ</p>
                </div>
                <div>
                  <p className="text-lg font-semibold text-abyss">
                    {heightZ ? `${heightZ.percentile.toFixed(0)} th` : "-"}
                  </p>
                  <p className="text-[11px] text-abyss/40">ส่วนสูงตามอายุ</p>
                </div>
              </div>
            </section>
          )}

          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <p className="mb-1 text-sm font-semibold text-abyss/60">น้ำหนักตามอายุ (กก.)</p>
            {renderChart(weightChartData, "น้ำหนัก")}
          </section>

          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <p className="mb-1 text-sm font-semibold text-abyss/60">ส่วนสูงตามอายุ (ซม.)</p>
            {renderChart(heightChartData, "ส่วนสูง")}
          </section>

          <p className="text-center text-[11px] text-abyss/30">
            เส้นประคือช่วงเปอร์เซ็นไทล์ P3–P97 ตามมาตรฐาน WHO Child Growth Standards
          </p>
        </div>
      )}

      <BottomNav />
    </main>
  );
}
