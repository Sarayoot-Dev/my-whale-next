"use client";

import Link from "next/link";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const MENU = [
  { href: "/health/growth", label: "น้ำหนัก/ส่วนสูง", icon: "📏", desc: "บันทึกและกราฟเทียบมาตรฐาน WHO" },
  { href: "/health/vaccine", label: "สมุดวัคซีน", icon: "💉", desc: "รายการฉีดวัคซีน + ข้อมูลสุขภาพประจำตัว" },
  { href: "/health/sleep", label: "การนอน", icon: "🌙", desc: "จับเวลานอน-ตื่น หรือกรอกเอง" },
  { href: "/health/milestones", label: "พัฒนาการ", icon: "⭐", desc: "checklist ตามช่วงอายุ + กราฟเติบโต" },
  { href: "/health/emergency", label: "ข้อมูลฉุกเฉิน", icon: "🚨", desc: "ประกันและเบอร์ติดต่อฉุกเฉิน" },
];

export default function HealthHub() {
  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2">
        <h1 className="font-display text-2xl font-bold text-abyss">ศูนย์สุขภาพ</h1>
        <WaveDivider className="mt-2 w-16 text-shallow" />
      </header>

      <div className="mt-4 space-y-3">
        {MENU.map((m) => (
          <Link
            key={m.href}
            href={m.href}
            className="flex items-center gap-4 rounded-xl2 bg-white p-4 shadow-log transition hover:bg-surface"
          >
            <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-surface text-2xl">
              {m.icon}
            </span>
            <div>
              <p className="text-sm font-semibold text-abyss">{m.label}</p>
              <p className="text-xs text-abyss/50">{m.desc}</p>
            </div>
          </Link>
        ))}
      </div>

      <BottomNav />
    </main>
  );
}
