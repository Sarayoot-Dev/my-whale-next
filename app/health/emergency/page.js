"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { watchAuth } from "@/lib/firebase";
import { getChild, saveChild } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

export default function EmergencyPage() {
  const [user, setUser] = useState(undefined);
  const [insuranceProvider, setInsuranceProvider] = useState("");
  const [insurancePolicyNumber, setInsurancePolicyNumber] = useState("");
  const [contacts, setContacts] = useState([{ name: "", phone: "" }]);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    getChild(CHILD_ID).then((c) => {
      setInsuranceProvider(c?.insuranceProvider || "");
      setInsurancePolicyNumber(c?.insurancePolicyNumber || "");
      setContacts(c?.emergencyContacts?.length ? c.emergencyContacts : [{ name: "", phone: "" }]);
    });
  }, [user]);

  function updateContact(i, field, value) {
    setContacts((cs) => cs.map((c, idx) => (idx === i ? { ...c, [field]: value } : c)));
  }

  function addContact() {
    setContacts((cs) => [...cs, { name: "", phone: "" }]);
  }

  function removeContact(i) {
    setContacts((cs) => cs.filter((_, idx) => idx !== i));
  }

  async function handleSave(e) {
    e.preventDefault();
    setSaving(true);
    try {
      await saveChild(CHILD_ID, {
        insuranceProvider,
        insurancePolicyNumber,
        emergencyContacts: contacts.filter((c) => c.name || c.phone),
      });
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2 flex items-center gap-2">
        <Link href="/health" aria-label="กลับ" className="text-xl text-abyss/40">
          ←
        </Link>
        <div>
          <h1 className="font-display text-2xl font-bold text-abyss">ข้อมูลฉุกเฉิน</h1>
          <WaveDivider className="mt-2 w-16 text-shallow" />
        </div>
      </header>

      {user && (
        <form onSubmit={handleSave} className="mt-4 space-y-4">
          <section className="space-y-3 rounded-xl2 bg-white p-4 shadow-log">
            <h2 className="text-sm font-semibold text-abyss/60">ประกันสุขภาพ</h2>
            <input
              type="text"
              placeholder="บริษัทประกัน"
              value={insuranceProvider}
              onChange={(e) => setInsuranceProvider(e.target.value)}
              className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
            />
            <input
              type="text"
              placeholder="หมายเลขกรมธรรม์"
              value={insurancePolicyNumber}
              onChange={(e) => setInsurancePolicyNumber(e.target.value)}
              className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
            />
          </section>

          <section className="space-y-3 rounded-xl2 bg-white p-4 shadow-log">
            <h2 className="text-sm font-semibold text-abyss/60">เบอร์ติดต่อฉุกเฉิน</h2>
            {contacts.map((c, i) => (
              <div key={i} className="flex gap-2">
                <input
                  type="text"
                  placeholder="ชื่อ"
                  value={c.name}
                  onChange={(e) => updateContact(i, "name", e.target.value)}
                  className="w-1/2 rounded-lg border border-shallow px-3 py-2 text-sm"
                />
                <input
                  type="tel"
                  placeholder="เบอร์โทร"
                  value={c.phone}
                  onChange={(e) => updateContact(i, "phone", e.target.value)}
                  className="w-1/2 rounded-lg border border-shallow px-3 py-2 text-sm"
                />
                {contacts.length > 1 && (
                  <button
                    type="button"
                    onClick={() => removeContact(i)}
                    aria-label="ลบเบอร์นี้"
                    className="shrink-0 rounded-full px-2 text-xs text-abyss/30 hover:bg-surface hover:text-abyss/60"
                  >
                    ✕
                  </button>
                )}
              </div>
            ))}
            <button
              type="button"
              onClick={addContact}
              className="text-xs text-tide underline"
            >
              + เพิ่มเบอร์ติดต่อ
            </button>
          </section>

          <button
            type="submit"
            disabled={saving}
            className="h-11 w-full rounded-full bg-abyss text-sm font-semibold text-white disabled:opacity-60"
          >
            {saved ? "บันทึกแล้ว ✓" : saving ? "กำลังบันทึก..." : "บันทึกข้อมูล"}
          </button>
        </form>
      )}

      <BottomNav />
    </main>
  );
}
