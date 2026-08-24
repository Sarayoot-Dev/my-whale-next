"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { watchAuth } from "@/lib/firebase";
import { getChild, saveChild } from "@/lib/family";
import { VACCINE_SCHEDULE } from "@/lib/checklists";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

function formatDateInput(dateStr) {
  if (!dateStr) return "";
  return new Date(`${dateStr}T12:00:00`).toLocaleDateString("th-TH", {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}

export default function VaccinePage() {
  const [user, setUser] = useState(undefined);
  const [vaccinesDone, setVaccinesDone] = useState({});
  const [doctorName, setDoctorName] = useState("");
  const [chronicConditions, setChronicConditions] = useState("");
  const [medications, setMedications] = useState("");
  const [drugAllergies, setDrugAllergies] = useState("");
  const [foodAllergies, setFoodAllergies] = useState("");
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [otherVaccines, setOtherVaccines] = useState([]);
  const [otherVaccineName, setOtherVaccineName] = useState("");
  const [otherVaccineDate, setOtherVaccineDate] = useState("");

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    getChild(CHILD_ID).then((c) => {
      setVaccinesDone(c?.vaccinesDone || {});
      setDoctorName(c?.doctorName || "");
      setChronicConditions(c?.chronicConditions || "");
      setMedications(c?.medications || "");
      setDrugAllergies(c?.drugAllergies || "");
      setFoodAllergies(c?.foodAllergies || "");
      setOtherVaccines(c?.otherVaccines || []);
    });
  }, [user]);

  async function toggleVaccine(key) {
    const next = { ...vaccinesDone, [key]: !vaccinesDone[key] };
    setVaccinesDone(next);
    await saveChild(CHILD_ID, { vaccinesDone: { [key]: next[key] } });
  }

  async function handleAddOtherVaccine(e) {
    e.preventDefault();
    if (!otherVaccineName.trim()) return;
    const next = [
      ...otherVaccines,
      { id: `${Date.now()}`, name: otherVaccineName.trim(), date: otherVaccineDate },
    ];
    setOtherVaccines(next);
    setOtherVaccineName("");
    setOtherVaccineDate("");
    await saveChild(CHILD_ID, { otherVaccines: next });
  }

  async function handleRemoveOtherVaccine(id) {
    const next = otherVaccines.filter((v) => v.id !== id);
    setOtherVaccines(next);
    await saveChild(CHILD_ID, { otherVaccines: next });
  }

  async function handleSaveInfo(e) {
    e.preventDefault();
    setSaving(true);
    try {
      await saveChild(CHILD_ID, {
        doctorName,
        chronicConditions,
        medications,
        drugAllergies,
        foodAllergies,
      });
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    } finally {
      setSaving(false);
    }
  }

  const doneCount = VACCINE_SCHEDULE.filter((v) => vaccinesDone[v.key]).length;

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2 flex items-center gap-2">
        <Link href="/health" aria-label="กลับ" className="text-xl text-abyss/40">
          ←
        </Link>
        <div>
          <h1 className="font-display text-2xl font-bold text-abyss">สมุดวัคซีน</h1>
          <WaveDivider className="mt-2 w-16 text-shallow" />
        </div>
      </header>

      {user && (
        <div className="mt-4 space-y-4">
          <form onSubmit={handleSaveInfo} className="space-y-3 rounded-xl2 bg-white p-4 shadow-log">
            <h2 className="text-sm font-semibold text-abyss/60">ข้อมูลสุขภาพประจำตัว</h2>
            <input
              type="text"
              placeholder="ชื่อคุณหมอประจำตัว"
              value={doctorName}
              onChange={(e) => setDoctorName(e.target.value)}
              className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
            />
            <input
              type="text"
              placeholder="โรคประจำตัว"
              value={chronicConditions}
              onChange={(e) => setChronicConditions(e.target.value)}
              className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
            />
            <input
              type="text"
              placeholder="ยาที่กินประจำ"
              value={medications}
              onChange={(e) => setMedications(e.target.value)}
              className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
            />
            <input
              type="text"
              placeholder="ประวัติแพ้ยา"
              value={drugAllergies}
              onChange={(e) => setDrugAllergies(e.target.value)}
              className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
            />
            <input
              type="text"
              placeholder="ประวัติแพ้อาหาร (เช่น ชื่ออาหาร + อาการแพ้)"
              value={foodAllergies}
              onChange={(e) => setFoodAllergies(e.target.value)}
              className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
            />
            <button
              type="submit"
              disabled={saving}
              className="h-11 w-full rounded-full bg-abyss text-sm font-semibold text-white disabled:opacity-60"
            >
              {saved ? "บันทึกแล้ว ✓" : saving ? "กำลังบันทึก..." : "บันทึกข้อมูล"}
            </button>
          </form>

          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <div className="mb-3 flex items-center justify-between">
              <h2 className="text-sm font-semibold text-abyss/60">รายการวัคซีน</h2>
              <span className="text-xs text-abyss/40">
                {doneCount}/{VACCINE_SCHEDULE.length} เข็ม
              </span>
            </div>
            <ul className="space-y-1">
              {VACCINE_SCHEDULE.map((v) => (
                <li key={v.key}>
                  <label className="flex items-center gap-3 rounded-lg p-2 hover:bg-surface">
                    <input
                      type="checkbox"
                      checked={Boolean(vaccinesDone[v.key])}
                      onChange={() => toggleVaccine(v.key)}
                      className="h-5 w-5 shrink-0 accent-tide"
                    />
                    <span
                      className={`flex-1 text-sm ${
                        vaccinesDone[v.key] ? "text-abyss/40 line-through" : "text-abyss"
                      }`}
                    >
                      {v.name}
                    </span>
                    <span className="shrink-0 text-[11px] text-abyss/40">{v.ageLabel}</span>
                  </label>
                </li>
              ))}
            </ul>
          </section>

          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <div className="mb-3 flex items-center justify-between">
              <h2 className="text-sm font-semibold text-abyss/60">วัคซีนอื่นๆ</h2>
              <span className="text-xs text-abyss/40">{otherVaccines.length} รายการ</span>
            </div>

            <form onSubmit={handleAddOtherVaccine} className="mb-3 space-y-2">
              <input
                type="text"
                placeholder="ชื่อวัคซีน เช่น RSV, IPD, Rabies"
                value={otherVaccineName}
                onChange={(e) => setOtherVaccineName(e.target.value)}
                className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
              />
              <div className="flex gap-2">
                <input
                  type="date"
                  value={otherVaccineDate}
                  max={new Date().toISOString().slice(0, 10)}
                  onChange={(e) => setOtherVaccineDate(e.target.value)}
                  className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
                />
                <button
                  type="submit"
                  className="h-10 shrink-0 rounded-full bg-tide px-4 text-sm font-semibold text-white"
                >
                  + เพิ่ม
                </button>
              </div>
            </form>

            <ul className="space-y-1">
              {otherVaccines.map((v) => (
                <li
                  key={v.id}
                  className="flex items-center justify-between gap-3 rounded-lg p-2 hover:bg-surface"
                >
                  <div className="flex-1">
                    <p className="text-sm text-abyss">{v.name}</p>
                    {v.date && (
                      <p className="text-[11px] text-abyss/40">{formatDateInput(v.date)}</p>
                    )}
                  </div>
                  <button
                    onClick={() => handleRemoveOtherVaccine(v.id)}
                    aria-label="ลบรายการนี้"
                    className="shrink-0 rounded-full px-2 py-1 text-xs text-abyss/30 hover:bg-white hover:text-abyss/60"
                  >
                    ลบ
                  </button>
                </li>
              ))}
              {otherVaccines.length === 0 && (
                <li className="py-2 text-center text-sm text-abyss/30">ยังไม่มีรายการ</li>
              )}
            </ul>
          </section>
        </div>
      )}

      <BottomNav />
    </main>
  );
}
