"use client";

import { useEffect, useState } from "react";
import { watchAuth, signOut } from "@/lib/firebase";
import { getChild, saveChild, FAMILY_ID } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

export default function Settings() {
  const [user, setUser] = useState(undefined);
  const [name, setName] = useState("");
  const [dob, setDob] = useState("");
  const [gender, setGender] = useState("male");
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    getChild(CHILD_ID).then((c) => {
      if (!c) return;
      setName(c.name || "");
      setDob(c.dob || "");
      setGender(c.gender || "male");
    });
  }, [user]);

  async function handleSave(e) {
    e.preventDefault();
    setSaving(true);
    try {
      await saveChild(CHILD_ID, { name, dob, gender });
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2">
        <h1 className="font-display text-2xl font-bold text-abyss">ตั้งค่า</h1>
        <WaveDivider className="mt-2 w-16 text-shallow" />
      </header>

      {user && (
        <div className="mt-4 space-y-4">
          <form onSubmit={handleSave} className="space-y-3 rounded-xl2 bg-white p-4 shadow-log">
            <h2 className="text-sm font-semibold text-abyss/60">ข้อมูลลูก</h2>
            <input
              type="text"
              placeholder="ชื่อเล่น"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
            />
            <input
              type="date"
              value={dob}
              onChange={(e) => setDob(e.target.value)}
              className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
            />
            <div className="flex gap-2">
              {[
                { key: "male", label: "ชาย" },
                { key: "female", label: "หญิง" },
              ].map((g) => (
                <button
                  type="button"
                  key={g.key}
                  onClick={() => setGender(g.key)}
                  className={`flex-1 rounded-full px-3 py-1.5 text-sm ${
                    gender === g.key ? "bg-tide text-white" : "bg-surface text-abyss/50"
                  }`}
                >
                  {g.label}
                </button>
              ))}
            </div>
            <button
              type="submit"
              disabled={saving}
              className="h-11 w-full rounded-full bg-abyss text-sm font-semibold text-white disabled:opacity-60"
            >
              {saved ? "บันทึกแล้ว ✓" : saving ? "กำลังบันทึก..." : "บันทึกข้อมูล"}
            </button>
          </form>

          <div className="rounded-xl2 bg-white p-4 shadow-log">
            <h2 className="mb-1 text-sm font-semibold text-abyss/60">ครอบครัว</h2>
            <p className="text-xs text-abyss/40">
              ข้อมูลนี้ใช้ร่วมกันในครอบครัว: <span className="font-mono">{FAMILY_ID}</span>
            </p>
            <p className="mt-1 text-xs text-abyss/40">
              เข้าสู่ระบบด้วยบัญชี Google เดียวกันบนอุปกรณ์อื่น เพื่อให้เห็นข้อมูลชุดเดียวกัน
            </p>
          </div>

          <button
            onClick={signOut}
            className="h-11 w-full rounded-full border border-shallow text-sm font-semibold text-abyss/60"
          >
            ออกจากระบบ
          </button>
        </div>
      )}

      <BottomNav />
    </main>
  );
}
