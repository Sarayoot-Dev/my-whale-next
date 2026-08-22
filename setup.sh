#!/usr/bin/env bash
set -e
echo 'Creating My Whale Next.js project files...'
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

# Claude API key (from console.anthropic.com) — server-side only, never exposed to the browser
ANTHROPIC_API_KEY=
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
mkdir -p 'app/api/ai-summary'
cat > 'app/api/ai-summary/route.js' << 'MYWHALE_EOF'
import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

export async function POST(request) {
  try {
    const { child, recentActivities } = await request.json();

    const activitySummary = (recentActivities || [])
      .map((a) => `- ${a.type}${a.value ? ` (${JSON.stringify(a.value)})` : ""}${a.note ? `: ${a.note}` : ""}`)
      .join("\n") || "ยังไม่มีบันทึกล่าสุด";

    const message = await anthropic.messages.create({
      model: "claude-sonnet-4-5",
      max_tokens: 400,
      messages: [
        {
          role: "user",
          content: `คุณเป็นผู้ช่วยดูแลเด็กที่ให้คำแนะนำสั้น กระชับ และอบอุ่นสำหรับพ่อแม่ ตอบเป็นภาษาไทย ไม่เกิน 4-5 ประโยค ห้ามวินิจฉัยโรคหรือให้คำแนะนำทางการแพทย์เฉพาะเจาะจง แนะนำให้ปรึกษาแพทย์หากมีสัญญาณที่น่ากังวล

ข้อมูลเด็ก: ${child?.name || "ลูก"} อายุ ${child?.ageLabel || "ไม่ระบุ"}

บันทึกล่าสุด:
${activitySummary}

ช่วยสรุปภาพรวมสั้นๆ และให้คำแนะนำหรือกำลังใจสำหรับวันนี้`,
        },
      ],
    });

    const summary = message.content
      .filter((block) => block.type === "text")
      .map((block) => block.text)
      .join("\n");

    return Response.json({ summary });
  } catch (err) {
    console.error("ai-summary error", err);
    return Response.json({ error: "AI request failed" }, { status: 500 });
  }
}
MYWHALE_EOF
mkdir -p 'app/calendar'
cat > 'app/calendar/page.js' << 'MYWHALE_EOF'
"use client";

import { useEffect, useState } from "react";
import { watchAuth } from "@/lib/firebase";
import { addAppointment, watchAppointments } from "@/lib/family";
import BottomNav from "@/components/BottomNav";

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
      <li key={a.id} className="flex items-center gap-3 rounded-xl2 bg-white p-3 shadow-sm">
        <span className="text-xl" aria-hidden="true">
          {APPT_TYPES[a.type]?.icon}
        </span>
        <div>
          <p className="text-sm font-medium text-ink">{a.title}</p>
          <p className="text-xs text-ink/50">{a.date}</p>
        </div>
      </li>
    );
  }

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-6">
      <header className="mb-4 flex items-center justify-between">
        <h1 className="font-display text-xl font-bold text-ink">ปฏิทินนัดหมาย</h1>
        <button
          onClick={() => setShowForm((v) => !v)}
          className="rounded-full bg-wave px-4 py-1.5 text-sm font-semibold text-white"
        >
          {showForm ? "ปิด" : "+ เพิ่ม"}
        </button>
      </header>

      {showForm && (
        <form onSubmit={handleSave} className="mb-4 space-y-3 rounded-xl2 bg-white p-4 shadow-sm">
          <div className="flex gap-2">
            {Object.entries(APPT_TYPES).map(([key, meta]) => (
              <button
                type="button"
                key={key}
                onClick={() => setType(key)}
                className={`rounded-full px-3 py-1.5 text-sm ${
                  type === key ? "bg-wave text-white" : "bg-mist text-ink/60"
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
            className="w-full rounded-lg border border-foam/40 px-3 py-2 text-sm"
            required
          />
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="w-full rounded-lg border border-foam/40 px-3 py-2 text-sm"
            required
          />
          <button
            type="submit"
            disabled={saving}
            className="w-full rounded-full bg-deep py-2.5 text-sm font-semibold text-white disabled:opacity-60"
          >
            {saving ? "กำลังบันทึก..." : "บันทึก"}
          </button>
        </form>
      )}

      <section className="mb-6">
        <h2 className="mb-2 text-sm font-semibold text-ink/70">กำลังจะถึง</h2>
        <ul className="space-y-2">
          {upcoming.map(renderItem)}
          {upcoming.length === 0 && (
            <li className="rounded-xl2 bg-white p-4 text-center text-sm text-ink/40 shadow-sm">
              ไม่มีนัดหมายที่กำลังจะถึง
            </li>
          )}
        </ul>
      </section>

      {past.length > 0 && (
        <section>
          <h2 className="mb-2 text-sm font-semibold text-ink/70">ผ่านมาแล้ว</h2>
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
  background-color: #EEF3F8;
  color: #0B2447;
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
  outline: 2px solid #1C5D99;
  outline-offset: 2px;
}
MYWHALE_EOF
mkdir -p 'app'
cat > 'app/layout.js' << 'MYWHALE_EOF'
import { Noto_Serif_Thai, Noto_Sans_Thai } from "next/font/google";
import "./globals.css";

const display = Noto_Serif_Thai({
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
  themeColor: "#134074",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }) {
  return (
    <html lang="th" className={`${display.variable} ${body.variable}`}>
      <body className="font-body min-h-screen bg-mist antialiased">
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
import { getChild, watchActivities, ACTIVITY_TYPES } from "@/lib/family";
import BottomNav from "@/components/BottomNav";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

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

export default function Dashboard() {
  const [user, setUser] = useState(undefined); // undefined = loading, null = signed out
  const [child, setChild] = useState(null);
  const [activities, setActivities] = useState([]);
  const [aiText, setAiText] = useState("");
  const [aiLoading, setAiLoading] = useState(false);
  const [aiError, setAiError] = useState("");

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    getChild(CHILD_ID).then(setChild);
    const unsub = watchActivities(CHILD_ID, setActivities, { max: 20 });
    return unsub;
  }, [user]);

  const latestGrowth = activities.find((a) => a.type === "growth");

  async function askAi() {
    setAiLoading(true);
    setAiError("");
    setAiText("");
    try {
      const res = await fetch("/api/ai-summary", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          child: { name: child?.name, ageLabel: ageLabel(child?.dob) },
          recentActivities: activities.slice(0, 10).map((a) => ({
            type: a.type,
            note: a.note || "",
            value: a.value || "",
          })),
        }),
      });
      if (!res.ok) throw new Error("AI request failed");
      const data = await res.json();
      setAiText(data.summary);
    } catch (err) {
      setAiError("ขอคำแนะนำไม่สำเร็จ ลองใหม่อีกครั้งครับ");
    } finally {
      setAiLoading(false);
    }
  }

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-6">
      <header className="mb-5 flex items-center justify-between">
        <h1 className="font-display text-xl font-bold text-ink">🐳 My Whale</h1>
      </header>

      {user === undefined && (
        <p className="text-sm text-foam">กำลังโหลด...</p>
      )}

      {user === null && (
        <div className="rounded-xl2 bg-white p-6 text-center shadow-sm">
          <p className="mb-4 text-sm text-ink/70">
            เข้าสู่ระบบเพื่อดูและบันทึกข้อมูลของลูก
          </p>
          <button
            onClick={signIn}
            className="rounded-full bg-wave px-6 py-2.5 font-semibold text-white transition hover:bg-deep"
          >
            เข้าสู่ระบบด้วย Google
          </button>
        </div>
      )}

      {user && (
        <div className="space-y-4">
          <section className="rounded-xl2 bg-white p-5 shadow-sm">
            <div className="flex items-center gap-4">
              <div className="flex h-14 w-14 items-center justify-center rounded-full bg-mist text-2xl">
                🐳
              </div>
              <div>
                <p className="font-display text-lg font-semibold text-ink">
                  {child?.name || "ยังไม่ตั้งชื่อ"}
                </p>
                <p className="text-sm text-ink/60">
                  {child?.dob ? ageLabel(child.dob) : "ยังไม่ระบุวันเกิด"}
                </p>
              </div>
            </div>
          </section>

          {latestGrowth && (
            <section className="grid grid-cols-2 gap-3">
              <div className="rounded-xl2 bg-white p-4 shadow-sm">
                <p className="text-xs text-ink/50">น้ำหนักล่าสุด</p>
                <p className="font-display text-xl font-bold text-ink">
                  {latestGrowth.value?.weight ?? "-"} กก.
                </p>
              </div>
              <div className="rounded-xl2 bg-white p-4 shadow-sm">
                <p className="text-xs text-ink/50">ส่วนสูงล่าสุด</p>
                <p className="font-display text-xl font-bold text-ink">
                  {latestGrowth.value?.height ?? "-"} ซม.
                </p>
              </div>
            </section>
          )}

          <section className="rounded-xl2 bg-deep p-5 text-white shadow-sm">
            <p className="mb-1 text-sm font-semibold">✨ คำแนะนำ AI วันนี้</p>
            <p className="mb-3 text-xs text-white/70">
              สรุปจากบันทึกล่าสุดของลูก — ขอครั้งเดียว ไม่เก็บบทสนทนา
            </p>
            {aiText && (
              <p className="mb-3 whitespace-pre-wrap rounded-lg bg-white/10 p-3 text-sm">
                {aiText}
              </p>
            )}
            {aiError && (
              <p className="mb-3 text-sm text-coral">{aiError}</p>
            )}
            <button
              onClick={askAi}
              disabled={aiLoading}
              className="rounded-full bg-white px-5 py-2 text-sm font-semibold text-deep transition disabled:opacity-60"
            >
              {aiLoading ? "กำลังคิด..." : "ขอคำแนะนำวันนี้"}
            </button>
          </section>

          <section>
            <h2 className="mb-2 text-sm font-semibold text-ink/70">
              กิจกรรมล่าสุด
            </h2>
            <ul className="space-y-2">
              {activities.slice(0, 5).map((a) => (
                <li
                  key={a.id}
                  className="flex items-center gap-3 rounded-xl2 bg-white p-3 shadow-sm"
                >
                  <span className="text-xl" aria-hidden="true">
                    {ACTIVITY_TYPES[a.type]?.icon}
                  </span>
                  <div>
                    <p className="text-sm font-medium text-ink">
                      {ACTIVITY_TYPES[a.type]?.label}
                    </p>
                    {a.note && <p className="text-xs text-ink/50">{a.note}</p>}
                  </div>
                </li>
              ))}
              {activities.length === 0 && (
                <li className="rounded-xl2 bg-white p-4 text-center text-sm text-ink/40 shadow-sm">
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
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-6">
      <h1 className="mb-4 font-display text-xl font-bold text-ink">ตั้งค่า</h1>

      {user && (
        <>
          <form onSubmit={handleSave} className="mb-4 space-y-3 rounded-xl2 bg-white p-4 shadow-sm">
            <h2 className="text-sm font-semibold text-ink/70">ข้อมูลลูก</h2>
            <input
              type="text"
              placeholder="ชื่อเล่น"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full rounded-lg border border-foam/40 px-3 py-2 text-sm"
            />
            <input
              type="date"
              value={dob}
              onChange={(e) => setDob(e.target.value)}
              className="w-full rounded-lg border border-foam/40 px-3 py-2 text-sm"
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
                    gender === g.key ? "bg-wave text-white" : "bg-mist text-ink/60"
                  }`}
                >
                  {g.label}
                </button>
              ))}
            </div>
            <button
              type="submit"
              disabled={saving}
              className="w-full rounded-full bg-deep py-2.5 text-sm font-semibold text-white disabled:opacity-60"
            >
              {saved ? "บันทึกแล้ว ✓" : saving ? "กำลังบันทึก..." : "บันทึกข้อมูล"}
            </button>
          </form>

          <div className="mb-4 rounded-xl2 bg-white p-4 shadow-sm">
            <h2 className="mb-1 text-sm font-semibold text-ink/70">ครอบครัว</h2>
            <p className="text-xs text-ink/50">
              ข้อมูลนี้ใช้ร่วมกันในครอบครัว: <span className="font-mono">{FAMILY_ID}</span>
            </p>
            <p className="mt-1 text-xs text-ink/50">
              เข้าสู่ระบบด้วยบัญชี Google เดียวกันบนอุปกรณ์อื่น เพื่อให้เห็นข้อมูลชุดเดียวกัน
            </p>
          </div>

          <button
            onClick={signOut}
            className="w-full rounded-full border border-foam/40 py-2.5 text-sm font-semibold text-ink/70"
          >
            ออกจากระบบ
          </button>
        </>
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
import { addActivity, watchActivities, ACTIVITY_TYPES } from "@/lib/family";
import BottomNav from "@/components/BottomNav";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

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
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-6">
      <header className="mb-4 flex items-center justify-between">
        <h1 className="font-display text-xl font-bold text-ink">ไทม์ไลน์</h1>
        <button
          onClick={() => setShowForm((v) => !v)}
          className="rounded-full bg-wave px-4 py-1.5 text-sm font-semibold text-white"
        >
          {showForm ? "ปิด" : "+ บันทึก"}
        </button>
      </header>

      {showForm && (
        <form
          onSubmit={handleSave}
          className="mb-4 space-y-3 rounded-xl2 bg-white p-4 shadow-sm"
        >
          <div className="flex flex-wrap gap-2">
            {Object.entries(ACTIVITY_TYPES).map(([key, meta]) => (
              <button
                type="button"
                key={key}
                onClick={() => setType(key)}
                className={`rounded-full px-3 py-1.5 text-sm ${
                  type === key
                    ? "bg-wave text-white"
                    : "bg-mist text-ink/60"
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
                className="w-1/2 rounded-lg border border-foam/40 px-3 py-2 text-sm"
                required
              />
              <input
                type="number"
                step="0.1"
                placeholder="ส่วนสูง (ซม.)"
                value={height}
                onChange={(e) => setHeight(e.target.value)}
                className="w-1/2 rounded-lg border border-foam/40 px-3 py-2 text-sm"
                required
              />
            </div>
          ) : (
            <input
              type="text"
              placeholder="รายละเอียด (ไม่บังคับ)"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              className="w-full rounded-lg border border-foam/40 px-3 py-2 text-sm"
            />
          )}

          <button
            type="submit"
            disabled={saving}
            className="w-full rounded-full bg-deep py-2.5 text-sm font-semibold text-white disabled:opacity-60"
          >
            {saving ? "กำลังบันทึก..." : "บันทึก"}
          </button>
        </form>
      )}

      <div className="mb-3 flex gap-2 overflow-x-auto pb-1">
        <button
          onClick={() => setFilter("all")}
          className={`whitespace-nowrap rounded-full px-3 py-1.5 text-xs ${
            filter === "all" ? "bg-wave text-white" : "bg-white text-ink/60"
          }`}
        >
          ทั้งหมด
        </button>
        {Object.entries(ACTIVITY_TYPES).map(([key, meta]) => (
          <button
            key={key}
            onClick={() => setFilter(key)}
            className={`whitespace-nowrap rounded-full px-3 py-1.5 text-xs ${
              filter === key ? "bg-wave text-white" : "bg-white text-ink/60"
            }`}
          >
            {meta.icon} {meta.label}
          </button>
        ))}
      </div>

      <ul className="space-y-2">
        {filtered.map((a) => (
          <li key={a.id} className="rounded-xl2 bg-white p-3 shadow-sm">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span aria-hidden="true">{ACTIVITY_TYPES[a.type]?.icon}</span>
                <span className="text-sm font-medium text-ink">
                  {ACTIVITY_TYPES[a.type]?.label}
                </span>
              </div>
              <span className="text-xs text-ink/40">{formatTime(a.createdAt)}</span>
            </div>
            {a.type === "growth" && a.value && (
              <p className="mt-1 text-xs text-ink/60">
                {a.value.weight} กก. · {a.value.height} ซม.
              </p>
            )}
            {a.note && <p className="mt-1 text-xs text-ink/60">{a.note}</p>}
            {a.createdBy && (
              <p className="mt-1 text-xs text-foam">บันทึกโดย {a.createdBy}</p>
            )}
          </li>
        ))}
        {filtered.length === 0 && (
          <li className="rounded-xl2 bg-white p-6 text-center text-sm text-ink/40 shadow-sm">
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

import Link from "next/link";
import { usePathname } from "next/navigation";

const ITEMS = [
  { href: "/", label: "หน้าหลัก", icon: "🏠" },
  { href: "/timeline", label: "ไทม์ไลน์", icon: "📖" },
  { href: "/calendar", label: "ปฏิทิน", icon: "📅" },
  { href: "/settings", label: "ตั้งค่า", icon: "⚙️" },
];

export default function BottomNav() {
  const pathname = usePathname();

  return (
    <nav
      className="fixed bottom-0 left-0 right-0 z-20 border-t border-foam/40 bg-white/95 backdrop-blur"
      aria-label="เมนูหลัก"
    >
      <ul className="mx-auto flex max-w-md justify-between px-2">
        {ITEMS.map((item) => {
          const active = pathname === item.href;
          return (
            <li key={item.href} className="flex-1">
              <Link
                href={item.href}
                className={`flex flex-col items-center gap-0.5 py-2.5 text-xs transition-colors ${
                  active ? "text-wave" : "text-foam"
                }`}
                aria-current={active ? "page" : undefined}
              >
                <span className="text-lg" aria-hidden="true">
                  {item.icon}
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
    "@line/liff": "^2.24.0",
    "@anthropic-ai/sdk": "^0.27.0"
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
        // "My Whale" palette — deep ocean, not a generic baby-pastel or SaaS-blue.
        ink: "#0B2447",       // near-black navy for text
        deep: "#134074",      // primary deep sea blue
        wave: "#1C5D99",      // mid blue, primary actions
        foam: "#8DA9C4",      // soft desaturated blue, secondary surfaces
        mist: "#EEF3F8",      // page background
        coral: "#F2A65A",     // single warm accent — sparingly, for highlights/alerts
        kelp: "#3E8E7E",      // secondary accent — success/growth states
      },
      fontFamily: {
        display: ["var(--font-display)"],
        body: ["var(--font-body)"],
      },
      borderRadius: {
        xl2: "1.25rem",
      },
    },
  },
  plugins: [],
};
MYWHALE_EOF
echo 'All files created. Installing dependencies...'
npm install
echo ''
echo 'Done! Next steps:'
echo '1. Copy .env.local.example to .env.local and fill in your Firebase keys'
echo '2. Run: npm run dev'
