"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { watchAuth } from "@/lib/firebase";
import { watchAppointments } from "@/lib/family";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

const ITEMS = [
  { href: "/", label: "หน้าหลัก", icon: "🏠" },
  { href: "/health", label: "ศูนย์สุขภาพ", icon: "🩺" },
  { href: "/feed", label: "Feed", icon: "🍼" },
  { href: "/diaper", label: "ขับถ่าย", icon: "🧷" },
  { href: "/calendar", label: "นัดหมาย", icon: "📅" },
];

export default function BottomNav() {
  const pathname = usePathname();
  const [dueSoonCount, setDueSoonCount] = useState(0);

  useEffect(() => {
    let unsubAppointments = null;
    const unsubAuth = watchAuth((user) => {
      if (unsubAppointments) {
        unsubAppointments();
        unsubAppointments = null;
      }
      if (!user) {
        setDueSoonCount(0);
        return;
      }
      unsubAppointments = watchAppointments(CHILD_ID, (appointments) => {
        const today = new Date().toISOString().slice(0, 10);
        const sevenDaysOut = new Date();
        sevenDaysOut.setDate(sevenDaysOut.getDate() + 7);
        const cutoff = sevenDaysOut.toISOString().slice(0, 10);
        const count = appointments.filter(
          (a) =>
            (a.type === "vaccine" || a.type === "doctor") &&
            a.date >= today &&
            a.date <= cutoff
        ).length;
        setDueSoonCount(count);
      });
    });
    return () => {
      unsubAuth();
      if (unsubAppointments) unsubAppointments();
    };
  }, []);

  return (
    <nav
      className="fixed bottom-0 left-0 right-0 z-20 border-t border-shallow/60 bg-white/95 backdrop-blur"
      aria-label="เมนูหลัก"
    >
      <ul className="mx-auto flex max-w-md justify-between px-3 py-2">
        {ITEMS.map((item) => {
          const active =
            item.href === "/" ? pathname === "/" : pathname.startsWith(item.href);
          const showBadge = item.href === "/calendar" && dueSoonCount > 0;
          return (
            <li key={item.href} className="flex-1">
              <Link
                href={item.href}
                className={`relative mx-1 flex flex-col items-center gap-1 rounded-2xl py-2 text-xs transition-colors ${
                  active ? "bg-shallow/70 text-abyss" : "text-tide/60"
                }`}
                aria-current={active ? "page" : undefined}
              >
                <span className="relative text-xl leading-none" aria-hidden="true">
                  {item.icon}
                  {showBadge && (
                    <span className="absolute -right-2 -top-1 flex h-4 min-w-[16px] items-center justify-center rounded-full bg-glow px-1 text-[10px] font-semibold text-abyss">
                      {dueSoonCount}
                    </span>
                  )}
                </span>
                <span className={active ? "font-semibold" : ""}>{item.label}</span>
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
