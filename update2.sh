#!/usr/bin/env bash
set -e
echo 'Updating My Whale with quick-log, delete, and reminder features...'
rm -rf app/api
cat > '.env.local.example' << 'MYWHALE_EOF'
# Firebase (from Firebase Console > Project settings)
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=
NEXT_PUBLIC_FIREBASE_PROJECT_ID=
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=
NEXT_PUBLIC_FIREBASE_APP_ID=

# Firestore database id — leave as "default" unless you created a differently named database
NEXT_PUBLIC_FIRESTORE_DB_ID=default

# Shared family namespace — same value on every family member's device
NEXT_PUBLIC_FAMILY_ID=toon-family

# Single child for now (multi-child support can come later)
NEXT_PUBLIC_CHILD_ID=main

# LINE LIFF (from LINE Developers Console) — leave blank while testing in a plain browser
NEXT_PUBLIC_LIFF_ID=
MYWHALE_EOF
cat > '.gitignore' << 'MYWHALE_EOF'
node_modules/
.next/
out/
.env.local
.env*.local
.DS_Store
*.log
MYWHALE_EOF
cat > 'README.md' << 'MYWHALE_EOF'
# My Whale — v2

Family baby-tracking app. Next.js + Firebase (Firestore/Auth) + LINE LIFF.
Shared family data model (`families/toon-family/...`) so everyone signed in
with a Google account sees the same records — same idea as the old single-file
PWA, but split into real pages/components so one bug doesn't take down the
whole app.

**Scope for this version (agreed):** health timeline (milk/sleep/vaccine/
growth/doctor), calendar of appointments, one-shot AI daily summary.
Chat companion / gamification are deliberately left for a later version.

## Setup — entirely from your phone via GitHub Codespaces

1. **Create an empty repo** on github.com (GitHub app or mobile browser).
   Do NOT add a README/gitignore when creating it — leave it fully empty.
2. Open the repo → **Code → Codespaces → Create codespace on main**.
   This opens a full VS Code in your browser, no install needed.
3. In the Codespaces **terminal** (bottom panel), paste the entire contents
   of `setup.sh` (provided alongside this README) and press enter. It
   recreates every project file and runs `npm install` — no file upload
   required.
4. Copy the example env file and fill in your real keys:
   ```
   cp .env.local.example .env.local
   ```
   Open `.env.local` in the editor and fill in:
   - **Firebase**: Firebase Console → Project settings → your web app's config
   - **NEXT_PUBLIC_FIRESTORE_DB_ID**: `default` (matches the existing project)
   - **NEXT_PUBLIC_FAMILY_ID**: `toon-family` (same family data as before)
   - **ANTHROPIC_API_KEY**: from console.anthropic.com (separate from claude.ai)
   - **NEXT_PUBLIC_LIFF_ID**: leave blank for now — only needed once you wrap
     this in a LINE LIFF app; the site works in a normal browser without it
5. Run it:
   ```
   npm run dev
   ```
   Codespaces will prompt to open a forwarded port in the browser — that's
   your live app, viewable and testable straight from your phone.
6. When ready to publish, push this repo to GitHub (Codespaces has a Source
   Control tab with buttons for this, no command line needed) and connect it
   on [vercel.com](https://vercel.com) → New Project → import the repo. Add
   the same environment variables in Vercel's project settings.

## Firestore security rules

Same rule as before — data lives under a shared family path:

```
match /databases/default/documents {
  match /families/toon-family/{document=**} {
    allow read, write: if request.auth != null;
  }
}
```

## Project structure

```
app/
  page.js              Dashboard — child card, growth snapshot, AI summary
  timeline/page.js      Unified activity log + quick-add form
  calendar/page.js      Appointments (doctor/vaccine/events)
  settings/page.js      Child profile + sign out
  api/ai-summary/route.js   Server-side, single-call Claude request
lib/
  firebase.js          Auth + Firestore init (popup-first sign-in,
                        named "default" database — both lessons learned
                        from the previous version's bugs)
  family.js             Firestore read/write helpers, live subscriptions
  liff.js               LINE LIFF init, safe no-op outside the LINE app
components/
  BottomNav.js
```

## What's different from the old version (and why)

- **Multiple files instead of one HTML file** — a bug in the sleep form
  can't silently break the vaccine form anymore.
- **Firebase JS SDK instead of hand-rolled Firestore REST calls** — removes
  the whole class of bugs from manually building query URLs.
- **Live `onSnapshot` subscriptions** — every family member's screen updates
  automatically; no manual refresh, no stale data.
- **Popup-first Google sign-in** with redirect only as an explicit fallback —
  this is what caused the login loop in the PWA before.
MYWHALE_EOF
mkdir -p 'app/calendar'
cat > 'app/calendar/page.js' << 'MYWHALE_EOF'
"use client";

import { useEffect, useState } from "react";
import { watchAuth } from "@/lib/firebase";
import { addAppointment, watchAppointments } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

const APPT_TYPES = {
  doctor: { label: "นัดแพทย์", icon: "🩺" },
  vaccine: { label: "วัคซีน", icon: "💉" },
  event: { label: "วันสำคัญ", icon: "🎉" },
};

export default function CalendarPage() {
  const [user, setUser] = useState(undefined);
  const [appointments, setAppointments] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [type, setType] = useState("doctor");
  const [title, setTitle] = useState("");
  const [date, setDate] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    return watchAppointments(CHILD_ID, setAppointments);
  }, [user]);

  const today = new Date().toISOString().slice(0, 10);
  const upcoming = appointments.filter((a) => a.date >= today);
  const past = appointments.filter((a) => a.date < today);

  async function handleSave(e) {
    e.preventDefault();
    if (!title || !date) return;
    setSaving(true);
    try {
      await addAppointment(CHILD_ID, { type, title, date });
      setTitle("");
      setDate("");
      setShowForm(false);
    } finally {
      setSaving(false);
    }
  }

  function renderItem(a) {
    return (
      <li key={a.id} className="flex items-center gap-3 rounded-xl2 bg-white p-3 shadow-log">
        <span className="text-xl" aria-hidden="true">
          {APPT_TYPES[a.type]?.icon}
        </span>
        <div>
          <p className="text-sm font-medium text-abyss">{a.title}</p>
          <p className="tabular-data text-xs text-abyss/40">{a.date}</p>
        </div>
      </li>
    );
  }

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2 flex items-center justify-between">
        <div>
          <h1 className="font-display text-2xl font-bold text-abyss">ปฏิทินนัดหมาย</h1>
          <WaveDivider className="mt-2 w-16 text-shallow" />
        </div>
        <button
          onClick={() => setShowForm((v) => !v)}
          className="h-11 rounded-full bg-tide px-5 text-sm font-semibold text-white shadow-log"
        >
          {showForm ? "ปิด" : "+ เพิ่ม"}
        </button>
      </header>

      {showForm && (
        <form onSubmit={handleSave} className="mb-4 mt-4 space-y-3 rounded-xl2 bg-white p-4 shadow-log">
          <div className="flex gap-2">
            {Object.entries(APPT_TYPES).map(([key, meta]) => (
              <button
                type="button"
                key={key}
                onClick={() => setType(key)}
                className={`rounded-full px-3 py-1.5 text-sm ${
                  type === key ? "bg-tide text-white" : "bg-surface text-abyss/50"
                }`}
              >
                {meta.icon} {meta.label}
              </button>
            ))}
          </div>
          <input
            type="text"
            placeholder="ชื่อรายการ เช่น นัดฉีดวัคซีนเข็มที่ 3"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
            required
          />
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
            required
          />
          <button
            type="submit"
            disabled={saving}
            className="h-11 w-full rounded-full bg-abyss text-sm font-semibold text-white disabled:opacity-60"
          >
            {saving ? "กำลังบันทึก..." : "บันทึก"}
          </button>
        </form>
      )}

      <section className="mb-6 mt-4">
        <h2 className="mb-2 text-sm font-semibold text-abyss/60">กำลังจะถึง</h2>
        <ul className="space-y-2">
          {upcoming.map(renderItem)}
          {upcoming.length === 0 && (
            <li className="rounded-xl2 bg-white p-4 text-center text-sm text-abyss/30 shadow-log">
              ไม่มีนัดหมายที่กำลังจะถึง
            </li>
          )}
        </ul>
      </section>

      {past.length > 0 && (
        <section>
          <h2 className="mb-2 text-sm font-semibold text-abyss/60">ผ่านมาแล้ว</h2>
          <ul className="space-y-2 opacity-60">{past.map(renderItem)}</ul>
        </section>
      )}

      <BottomNav />
    </main>
  );
}
MYWHALE_EOF
mkdir -p 'app'
cat > 'app/globals.css' << 'MYWHALE_EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  color-scheme: light;
}

body {
  background-color: #F4F8FB;
  background-image: radial-gradient(ellipse 100% 40% at 50% 0%, rgba(191, 225, 236, 0.55), rgba(244, 248, 251, 0) 70%);
  background-repeat: no-repeat;
  color: #0F2A43;
}

/* Respect reduced motion preference */
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}

/* Visible keyboard focus ring everywhere */
:focus-visible {
  outline: 2px solid #2C6E8E;
  outline-offset: 2px;
}

/* Tabular numerals for data — weights and dates line up cleanly */
.tabular-data {
  font-variant-numeric: tabular-nums;
}
MYWHALE_EOF
mkdir -p 'app'
cat > 'app/layout.js' << 'MYWHALE_EOF'
import { Taviraj, Noto_Sans_Thai } from "next/font/google";
import "./globals.css";

const display = Taviraj({
  subsets: ["thai", "latin"],
  weight: ["600", "700"],
  variable: "--font-display",
  display: "swap",
});

const body = Noto_Sans_Thai({
  subsets: ["thai", "latin"],
  weight: ["400", "500", "600"],
  variable: "--font-body",
  display: "swap",
});

export const metadata = {
  title: "My Whale — บันทึกลูกน้อย",
  description: "แอปบันทึกและติดตามพัฒนาการลูกน้อยสำหรับครอบครัว",
  manifest: "/manifest.json",
};

export const viewport = {
  themeColor: "#0F2A43",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }) {
  return (
    <html lang="th" className={`${display.variable} ${body.variable}`}>
      <body className="font-body min-h-screen antialiased">
        {children}
      </body>
    </html>
  );
}
MYWHALE_EOF
mkdir -p 'app'
cat > 'app/page.js' << 'MYWHALE_EOF'
"use client";

import { useEffect, useState } from "react";
import { auth, signIn, watchAuth } from "@/lib/firebase";
import { getChild, watchActivities, addActivity, deleteActivity, ACTIVITY_TYPES } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

const TYPE_ACCENT = {
  milk: "border-glow",
  sleep: "border-tide",
  vaccine: "border-abyss",
  growth: "border-shallow",
  doctor: "border-glow",
};

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
    return remMinutes > 0
      ? `${hours} ชม. ${remMinutes} นาทีที่แล้ว`
      : `${hours} ชม. ที่แล้ว`;
  }
  const days = Math.floor(hours / 24);
  return `${days} วันที่แล้ว`;
}

export default function Dashboard() {
  const [user, setUser] = useState(undefined); // undefined = loading, null = signed out
  const [child, setChild] = useState(null);
  const [activities, setActivities] = useState([]);
  const [quickLogging, setQuickLogging] = useState(false);
  const [, forceTick] = useState(0);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    getChild(CHILD_ID).then(setChild);
    const unsub = watchActivities(CHILD_ID, setActivities, { max: 20 });
    return unsub;
  }, [user]);

  // Re-render every 30s so "X นาทีที่แล้ว" stays accurate without a refresh.
  useEffect(() => {
    const id = setInterval(() => forceTick((t) => t + 1), 30000);
    return () => clearInterval(id);
  }, []);

  const latestGrowth = activities.find((a) => a.type === "growth");
  const latestMilk = activities.find((a) => a.type === "milk");

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
        <h1 className="font-display text-2xl font-bold text-abyss">
          🐳 My Whale
        </h1>
        <WaveDivider className="mt-2 text-shallow" />
      </header>

      {user === undefined && (
        <p className="mt-6 text-sm text-tide/70">กำลังโหลด...</p>
      )}

      {user === null && (
        <div className="mt-6 rounded-xl2 bg-white p-6 text-center shadow-log">
          <p className="mb-4 text-sm text-abyss/70">
            เข้าสู่ระบบเพื่อดูและบันทึกข้อมูลของลูก
          </p>
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
            <div className="flex items-center gap-4">
              <div className="flex h-16 w-16 items-center justify-center rounded-full bg-gradient-to-br from-shallow to-tide/30 text-3xl">
                🐳
              </div>
              <div>
                <p className="font-display text-lg font-semibold text-abyss">
                  {child?.name || "ยังไม่ตั้งชื่อ"}
                </p>
                <p className="text-sm text-abyss/50">
                  {child?.dob ? ageLabel(child.dob) : "ยังไม่ระบุวันเกิด"}
                </p>
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

          {latestGrowth && (
            <section className="grid grid-cols-2 gap-3">
              <div className="rounded-xl2 bg-white p-4 shadow-log">
                <p className="text-xs text-abyss/40">น้ำหนักล่าสุด</p>
                <p className="tabular-data font-display text-2xl font-bold text-abyss">
                  {latestGrowth.value?.weight ?? "-"}
                  <span className="ml-1 text-sm font-body font-normal text-abyss/40">กก.</span>
                </p>
              </div>
              <div className="rounded-xl2 bg-white p-4 shadow-log">
                <p className="text-xs text-abyss/40">ส่วนสูงล่าสุด</p>
                <p className="tabular-data font-display text-2xl font-bold text-abyss">
                  {latestGrowth.value?.height ?? "-"}
                  <span className="ml-1 text-sm font-body font-normal text-abyss/40">ซม.</span>
                </p>
              </div>
            </section>
          )}

          <section>
            <h2 className="mb-2 text-sm font-semibold text-abyss/60">
              กิจกรรมล่าสุด
            </h2>
            <ul className="space-y-2">
              {activities.slice(0, 5).map((a) => (
                <li
                  key={a.id}
                  className={`flex items-center justify-between gap-3 rounded-xl2 border-l-4 bg-white p-3 shadow-log ${TYPE_ACCENT[a.type] || "border-shallow"}`}
                >
                  <div className="flex items-center gap-3">
                    <span className="text-xl" aria-hidden="true">
                      {ACTIVITY_TYPES[a.type]?.icon}
                    </span>
                    <div>
                      <p className="text-sm font-medium text-abyss">
                        {ACTIVITY_TYPES[a.type]?.label}
                      </p>
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
                  ยังไม่มีบันทึก — เริ่มบันทึกได้ที่แท็บไทม์ไลน์
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
MYWHALE_EOF
mkdir -p 'app/settings'
cat > 'app/settings/page.js' << 'MYWHALE_EOF'
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
MYWHALE_EOF
mkdir -p 'app/timeline'
cat > 'app/timeline/page.js' << 'MYWHALE_EOF'
"use client";

import { useEffect, useState } from "react";
import { auth, watchAuth } from "@/lib/firebase";
import { addActivity, deleteActivity, watchActivities, ACTIVITY_TYPES } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

const TYPE_ACCENT = {
  milk: "border-glow",
  sleep: "border-tide",
  vaccine: "border-abyss",
  growth: "border-shallow",
  doctor: "border-glow",
};

function formatTime(ts) {
  if (!ts?.toDate) return "";
  return ts.toDate().toLocaleString("th-TH", {
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default function Timeline() {
  const [user, setUser] = useState(undefined);
  const [activities, setActivities] = useState([]);
  const [filter, setFilter] = useState("all");
  const [showForm, setShowForm] = useState(false);
  const [type, setType] = useState("milk");
  const [note, setNote] = useState("");
  const [weight, setWeight] = useState("");
  const [height, setHeight] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    return watchActivities(CHILD_ID, setActivities, { max: 100 });
  }, [user]);

  const filtered =
    filter === "all" ? activities : activities.filter((a) => a.type === filter);

  async function handleDelete(activityId) {
    if (!window.confirm("ลบรายการนี้ใช่ไหม?")) return;
    await deleteActivity(CHILD_ID, activityId);
  }

  async function handleSave(e) {
    e.preventDefault();
    setSaving(true);
    try {
      const entry = { type, note, createdBy: user?.displayName || "" };
      if (type === "growth") {
        entry.value = { weight: Number(weight), height: Number(height) };
      }
      await addActivity(CHILD_ID, entry);
      setNote("");
      setWeight("");
      setHeight("");
      setShowForm(false);
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2 flex items-center justify-between">
        <div>
          <h1 className="font-display text-2xl font-bold text-abyss">ไทม์ไลน์</h1>
          <WaveDivider className="mt-2 w-16 text-shallow" />
        </div>
        <button
          onClick={() => setShowForm((v) => !v)}
          className="h-11 rounded-full bg-tide px-5 text-sm font-semibold text-white shadow-log"
        >
          {showForm ? "ปิด" : "+ บันทึก"}
        </button>
      </header>

      {showForm && (
        <form
          onSubmit={handleSave}
          className="mb-4 mt-4 space-y-3 rounded-xl2 bg-white p-4 shadow-log"
        >
          <div className="flex flex-wrap gap-2">
            {Object.entries(ACTIVITY_TYPES).map(([key, meta]) => (
              <button
                type="button"
                key={key}
                onClick={() => setType(key)}
                className={`rounded-full px-3 py-1.5 text-sm ${
                  type === key
                    ? "bg-tide text-white"
                    : "bg-surface text-abyss/50"
                }`}
              >
                {meta.icon} {meta.label}
              </button>
            ))}
          </div>

          {type === "growth" ? (
            <div className="flex gap-2">
              <input
                type="number"
                step="0.1"
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
            </div>
          ) : (
            <input
              type="text"
              placeholder="รายละเอียด (ไม่บังคับ)"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              className="w-full rounded-lg border border-shallow px-3 py-2 text-sm"
            />
          )}

          <button
            type="submit"
            disabled={saving}
            className="h-11 w-full rounded-full bg-abyss text-sm font-semibold text-white disabled:opacity-60"
          >
            {saving ? "กำลังบันทึก..." : "บันทึก"}
          </button>
        </form>
      )}

      <div className="mb-3 mt-4 flex gap-2 overflow-x-auto pb-1">
        <button
          onClick={() => setFilter("all")}
          className={`whitespace-nowrap rounded-full px-3 py-1.5 text-xs ${
            filter === "all" ? "bg-tide text-white" : "bg-white text-abyss/50 shadow-log"
          }`}
        >
          ทั้งหมด
        </button>
        {Object.entries(ACTIVITY_TYPES).map(([key, meta]) => (
          <button
            key={key}
            onClick={() => setFilter(key)}
            className={`whitespace-nowrap rounded-full px-3 py-1.5 text-xs ${
              filter === key ? "bg-tide text-white" : "bg-white text-abyss/50 shadow-log"
            }`}
          >
            {meta.icon} {meta.label}
          </button>
        ))}
      </div>

      <ul className="space-y-2">
        {filtered.map((a) => (
          <li
            key={a.id}
            className={`rounded-xl2 border-l-4 bg-white p-3 shadow-log ${TYPE_ACCENT[a.type] || "border-shallow"}`}
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span aria-hidden="true">{ACTIVITY_TYPES[a.type]?.icon}</span>
                <span className="text-sm font-medium text-abyss">
                  {ACTIVITY_TYPES[a.type]?.label}
                </span>
              </div>
              <div className="flex items-center gap-2">
                <span className="tabular-data text-xs text-abyss/40">{formatTime(a.createdAt)}</span>
                <button
                  onClick={() => handleDelete(a.id)}
                  aria-label="ลบรายการนี้"
                  className="rounded-full px-2 py-1 text-xs text-abyss/30 hover:bg-surface hover:text-abyss/60"
                >
                  ลบ
                </button>
              </div>
            </div>
            {a.type === "growth" && a.value && (
              <p className="mt-1 text-xs text-abyss/50">
                {a.value.weight} กก. · {a.value.height} ซม.
              </p>
            )}
            {a.note && <p className="mt-1 text-xs text-abyss/50">{a.note}</p>}
            {a.createdBy && (
              <p className="mt-1 text-xs text-tide/70">บันทึกโดย {a.createdBy}</p>
            )}
          </li>
        ))}
        {filtered.length === 0 && (
          <li className="rounded-xl2 bg-white p-6 text-center text-sm text-abyss/30 shadow-log">
            ยังไม่มีบันทึกในหมวดนี้
          </li>
        )}
      </ul>

      <BottomNav />
    </main>
  );
}
MYWHALE_EOF
mkdir -p 'components'
cat > 'components/BottomNav.js' << 'MYWHALE_EOF'
"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { watchAuth } from "@/lib/firebase";
import { watchAppointments } from "@/lib/family";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

const ITEMS = [
  { href: "/", label: "หน้าหลัก", icon: "🏠" },
  { href: "/timeline", label: "ไทม์ไลน์", icon: "📖" },
  { href: "/calendar", label: "ปฏิทิน", icon: "📅" },
  { href: "/settings", label: "ตั้งค่า", icon: "⚙️" },
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
          const active = pathname === item.href;
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
MYWHALE_EOF
mkdir -p 'components'
cat > 'components/WaveDivider.js' << 'MYWHALE_EOF'
export default function WaveDivider({ className = "" }) {
  return (
    <svg
      viewBox="0 0 400 20"
      preserveAspectRatio="none"
      className={`h-3 w-full ${className}`}
      aria-hidden="true"
    >
      <path
        d="M0 10 Q 25 2, 50 10 T 100 10 T 150 10 T 200 10 T 250 10 T 300 10 T 350 10 T 400 10"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  );
}
MYWHALE_EOF
cat > 'jsconfig.json' << 'MYWHALE_EOF'
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./*"]
    }
  }
}
MYWHALE_EOF
mkdir -p 'lib'
cat > 'lib/family.js' << 'MYWHALE_EOF'
"use client";

import {
  collection,
  doc,
  addDoc,
  updateDoc,
  deleteDoc,
  getDoc,
  setDoc,
  query,
  orderBy,
  limit as fsLimit,
  onSnapshot,
  Timestamp,
} from "firebase/firestore";
import { db } from "./firebase";

// Shared across every account in the family — matches the "families/{id}" path
// used by the previous PWA, so this can read the same underlying data model.
export const FAMILY_ID = process.env.NEXT_PUBLIC_FAMILY_ID || "toon-family";

function childPath(childId) {
  return `families/${FAMILY_ID}/children/${childId}`;
}

export async function getChild(childId) {
  const snap = await getDoc(doc(db, childPath(childId)));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}

export async function saveChild(childId, data) {
  return setDoc(doc(db, childPath(childId)), data, { merge: true });
}

// --- Activities: one collection, filtered by `type` (milk | sleep | vaccine | growth | doctor) ---

export async function addActivity(childId, activity) {
  return addDoc(collection(db, `${childPath(childId)}/activities`), {
    ...activity,
    createdAt: Timestamp.now(),
  });
}

export async function updateActivity(childId, activityId, data) {
  return updateDoc(doc(db, `${childPath(childId)}/activities/${activityId}`), data);
}

export async function deleteActivity(childId, activityId) {
  return deleteDoc(doc(db, `${childPath(childId)}/activities/${activityId}`));
}

// Live-subscribes so every family member's screen stays in sync (no manual refresh).
export function watchActivities(childId, callback, { max = 50 } = {}) {
  const q = query(
    collection(db, `${childPath(childId)}/activities`),
    orderBy("createdAt", "desc"),
    fsLimit(max)
  );
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
  });
}

// --- Appointments: doctor visits, vaccines due, important dates ---

export async function addAppointment(childId, appt) {
  return addDoc(collection(db, `${childPath(childId)}/appointments`), {
    ...appt,
    createdAt: Timestamp.now(),
  });
}

export async function deleteAppointment(childId, appointmentId) {
  return deleteDoc(doc(db, `${childPath(childId)}/appointments/${appointmentId}`));
}

export function watchAppointments(childId, callback, { max = 50 } = {}) {
  const q = query(
    collection(db, `${childPath(childId)}/appointments`),
    orderBy("date", "asc"),
    fsLimit(max)
  );
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
  });
}

export const ACTIVITY_TYPES = {
  milk: { label: "นม", icon: "🍼" },
  sleep: { label: "การนอน", icon: "🌙" },
  vaccine: { label: "วัคซีน", icon: "💉" },
  growth: { label: "น้ำหนัก/ส่วนสูง", icon: "📏" },
  doctor: { label: "พบแพทย์", icon: "🩺" },
};
MYWHALE_EOF
mkdir -p 'lib'
cat > 'lib/firebase.js' << 'MYWHALE_EOF'
"use client";

import { initializeApp, getApps, getApp } from "firebase/app";
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  signInWithRedirect,
  setPersistence,
  browserLocalPersistence,
  signOut as fbSignOut,
  onAuthStateChanged,
} from "firebase/auth";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

export const app = getApps().length ? getApp() : initializeApp(firebaseConfig);

// IMPORTANT: this project's Firestore database is named "default" (no parentheses),
// not the SDK's implicit "(default)" database. Passing the id explicitly avoids the
// silent 404s that cost a full debugging session last time.
const FIRESTORE_DB_ID = process.env.NEXT_PUBLIC_FIRESTORE_DB_ID || "default";
export const db = getFirestore(app, FIRESTORE_DB_ID);

export const auth = getAuth(app);
if (typeof window !== "undefined") {
  setPersistence(auth, browserLocalPersistence).catch((e) =>
    console.error("setPersistence error", e)
  );
}

const provider = new GoogleAuthProvider();

// Popup first, redirect only as an explicit fallback — signInWithRedirect inside
// a standalone PWA/LIFF webview is what caused the login loop before.
export async function signIn() {
  try {
    return await signInWithPopup(auth, provider);
  } catch (err) {
    if (err.code === "auth/popup-blocked" || err.code === "auth/popup-closed-by-user") {
      return signInWithRedirect(auth, provider);
    }
    throw err;
  }
}

export function signOut() {
  return fbSignOut(auth);
}

export function watchAuth(callback) {
  return onAuthStateChanged(auth, callback);
}
MYWHALE_EOF
mkdir -p 'lib'
cat > 'lib/liff.js' << 'MYWHALE_EOF'
"use client";

let liffInstance = null;

// Loaded lazily so the LIFF SDK never blocks a normal browser session —
// only matters once this is opened inside the LINE app.
export async function initLiff() {
  if (typeof window === "undefined") return null;
  if (liffInstance) return liffInstance;

  const liffId = process.env.NEXT_PUBLIC_LIFF_ID;
  if (!liffId) return null;

  const liff = (await import("@line/liff")).default;
  await liff.init({ liffId });
  liffInstance = liff;
  return liff;
}

export function isInLineApp() {
  return liffInstance ? liffInstance.isInClient() : false;
}
MYWHALE_EOF
cat > 'next.config.mjs' << 'MYWHALE_EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
};

export default nextConfig;
MYWHALE_EOF
cat > 'package.json' << 'MYWHALE_EOF'
{
  "name": "my-whale-next",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "14.2.35",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "firebase": "^10.12.4",
    "@line/liff": "^2.24.0"
  },
  "devDependencies": {
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.39",
    "tailwindcss": "^3.4.6"
  }
}
MYWHALE_EOF
cat > 'postcss.config.js' << 'MYWHALE_EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
MYWHALE_EOF
mkdir -p 'public'
cat > 'public/manifest.json' << 'MYWHALE_EOF'
{
  "name": "My Whale — บันทึกลูกน้อย",
  "short_name": "My Whale",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#EEF3F8",
  "theme_color": "#134074",
  "icons": []
}
MYWHALE_EOF
cat > 'tailwind.config.js' << 'MYWHALE_EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,jsx}",
    "./components/**/*.{js,jsx}",
  ],
  theme: {
    extend: {
      colors: {
        // "My Whale" — an ocean-depth scale, not a generic baby-pastel or SaaS-blue.
        // Named for where they sit in the water column, surface to abyss.
        surface: "#F4F8FB", // page background — icy surface water
        shallow: "#BFE1EC", // secondary chips, inactive states, dividers
        tide: "#2C6E8E",    // primary actions — mid-depth teal
        abyss: "#0F2A43",   // headers, body text — the deep
        glow: "#FFB84D",    // single warm accent — bioluminescence, used sparingly
      },
      fontFamily: {
        display: ["var(--font-display)"],
        body: ["var(--font-body)"],
      },
      borderRadius: {
        xl2: "1.25rem",
      },
      boxShadow: {
        log: "0 1px 2px rgba(15, 42, 67, 0.06), 0 4px 16px rgba(15, 42, 67, 0.06)",
      },
    },
  },
  plugins: [],
};
MYWHALE_EOF
echo 'Files updated. Reinstalling dependencies...'
npm install
echo ''
echo 'Done! Restart the dev server:'
echo '  Ctrl+C to stop the old one if still running, then: npm run dev'
