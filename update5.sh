#!/usr/bin/env bash
set -e
echo 'Fixing photo picker to allow choosing from album...'
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
mkdir -p 'app/gallery'
cat > 'app/gallery/page.js' << 'MYWHALE_EOF'
"use client";

import { useEffect, useRef, useState } from "react";
import { watchAuth } from "@/lib/firebase";
import { uploadPhoto, deletePhoto, watchPhotos } from "@/lib/storage";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

export default function GalleryPage() {
  const [user, setUser] = useState(undefined);
  const [photos, setPhotos] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState("");
  const fileInputRef = useRef(null);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    return watchPhotos(CHILD_ID, setPhotos);
  }, [user]);

  async function handleFileChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    setError("");
    try {
      await uploadPhoto(CHILD_ID, file, user?.displayName || "");
    } catch (err) {
      console.error(err);
      setError("อัพโหลดไม่สำเร็จ ลองใหม่อีกครั้งครับ (ตรวจสอบว่าเปิด Firebase Storage แล้วหรือยัง)");
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  }

  async function handleDelete(photo) {
    if (!window.confirm("ลบรูปนี้ใช่ไหม?")) return;
    await deletePhoto(CHILD_ID, photo.id, photo.path);
  }

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2 flex items-center justify-between">
        <div>
          <h1 className="font-display text-2xl font-bold text-abyss">แกลเลอรี่</h1>
          <WaveDivider className="mt-2 w-16 text-shallow" />
        </div>
        <button
          onClick={() => fileInputRef.current?.click()}
          disabled={uploading}
          className="h-11 rounded-full bg-tide px-5 text-sm font-semibold text-white shadow-log disabled:opacity-60"
        >
          {uploading ? "กำลังอัพโหลด..." : "+ เพิ่มรูป"}
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          onChange={handleFileChange}
          className="hidden"
        />
      </header>

      {error && (
        <p className="mt-3 rounded-xl2 bg-white p-3 text-xs text-abyss/60 shadow-log">{error}</p>
      )}

      <div className="mt-4 grid grid-cols-2 gap-3">
        {photos.map((p) => (
          <div key={p.id} className="group relative overflow-hidden rounded-xl2 shadow-log">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={p.url} alt="" className="aspect-square w-full object-cover" />
            <button
              onClick={() => handleDelete(p)}
              aria-label="ลบรูปนี้"
              className="absolute right-1.5 top-1.5 rounded-full bg-white/90 px-2 py-1 text-[11px] text-abyss/60 shadow-log"
            >
              ลบ
            </button>
          </div>
        ))}
        {photos.length === 0 && (
          <div className="col-span-2 rounded-xl2 bg-white p-6 text-center text-sm text-abyss/30 shadow-log">
            ยังไม่มีรูป — กด + เพิ่มรูป เพื่อเริ่มเก็บความทรงจำ
          </div>
        )}
      </div>

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
  background-color: #EAF4FB;
  background-image: radial-gradient(ellipse 100% 35% at 50% 0%, rgba(214, 236, 251, 0.7), rgba(234, 244, 251, 0) 70%);
  background-repeat: no-repeat;
  color: #2D3A4A;
}

@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}

:focus-visible {
  outline: 2px solid #4F9DDE;
  outline-offset: 2px;
}

.tabular-data {
  font-variant-numeric: tabular-nums;
}
MYWHALE_EOF
mkdir -p 'app'
cat > 'app/layout.js' << 'MYWHALE_EOF'
import { Taviraj, Noto_Sans_Thai } from "next/font/google";
import "./globals.css";
import BubbleWatermark from "@/components/BubbleWatermark";

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
  themeColor: "#2D3A4A",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }) {
  return (
    <html lang="th" className={`${display.variable} ${body.variable}`}>
      <body className="font-body min-h-screen antialiased">
        <BubbleWatermark />
        {children}
      </body>
    </html>
  );
}
MYWHALE_EOF
mkdir -p 'app/milestones'
cat > 'app/milestones/page.js' << 'MYWHALE_EOF'
"use client";

import { useEffect, useState } from "react";
import { watchAuth } from "@/lib/firebase";
import { addMilestone, deleteMilestone, watchMilestones, MILESTONE_COLORS } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

export default function MilestonesPage() {
  const [user, setUser] = useState(undefined);
  const [milestones, setMilestones] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [title, setTitle] = useState("");
  const [date, setDate] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    return watchMilestones(CHILD_ID, setMilestones);
  }, [user]);

  async function handleSave(e) {
    e.preventDefault();
    if (!title || !date) return;
    setSaving(true);
    try {
      await addMilestone(CHILD_ID, { title, date });
      setTitle("");
      setDate("");
      setShowForm(false);
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id) {
    if (!window.confirm("ลบรายการนี้ใช่ไหม?")) return;
    await deleteMilestone(CHILD_ID, id);
  }

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2 flex items-center justify-between">
        <div>
          <h1 className="font-display text-2xl font-bold text-abyss">ไทม์ไลน์พัฒนาการ</h1>
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
          <input
            type="text"
            placeholder="เช่น นั่งได้เอง, คลานได้, พูดคำแรก"
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

      <ul className="mt-4 space-y-4 border-l-2 border-shallow pl-4">
        {milestones.map((m, i) => (
          <li key={m.id} className="relative">
            <span
              className="absolute -left-[27px] top-0.5 flex h-5 w-5 items-center justify-center rounded-full text-[10px] font-bold text-white"
              style={{ backgroundColor: MILESTONE_COLORS[i % MILESTONE_COLORS.length] }}
              aria-hidden="true"
            >
              ★
            </span>
            <div className="flex items-center justify-between rounded-xl2 bg-white p-3 shadow-log">
              <div>
                <p className="text-sm font-medium text-abyss">{m.title}</p>
                <p className="tabular-data text-xs text-abyss/40">{m.date}</p>
              </div>
              <button
                onClick={() => handleDelete(m.id)}
                aria-label="ลบรายการนี้"
                className="rounded-full px-2 py-1 text-xs text-abyss/30 hover:bg-surface hover:text-abyss/60"
              >
                ลบ
              </button>
            </div>
          </li>
        ))}
        {milestones.length === 0 && (
          <li className="rounded-xl2 bg-white p-6 text-center text-sm text-abyss/30 shadow-log">
            ยังไม่มีบันทึกพัฒนาการ — กด + เพิ่ม เพื่อเริ่มบันทึก
          </li>
        )}
      </ul>

      <BottomNav />
    </main>
  );
}
MYWHALE_EOF
mkdir -p 'app'
cat > 'app/page.js' << 'MYWHALE_EOF'
"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { watchAuth, signIn } from "@/lib/firebase";
import { getChild, watchActivities, addActivity, deleteActivity, ACTIVITY_TYPES } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

const TYPE_ACCENT = {
  milk: "border-glow",
  sleep: "border-tide",
  diaper: "border-glow",
  vaccine: "border-tide",
  growth: "border-shallow",
  doctor: "border-glow",
};

const FUNCTIONS = [
  { key: "milk", label: "บันทึกการกินนม", icon: "🍼", href: "/timeline?type=milk" },
  { key: "sleep", label: "บันทึกการนอน", icon: "🌙", href: "/timeline?type=sleep" },
  { key: "diaper", label: "เปลี่ยนแพมเพิส", icon: "🧷", href: "/timeline?type=diaper" },
  { key: "growth", label: "บันทึกการเจริญเติบโต", icon: "📏", href: "/timeline?type=growth" },
  { key: "gallery", label: "แกลเลอรี่", icon: "📷", href: "/gallery" },
  { key: "milestones", label: "ไทม์ไลน์พัฒนาการ", icon: "⭐", href: "/milestones" },
  { key: "stats", label: "สถิติ & กราฟ", icon: "📊", href: "/stats" },
  { key: "more", label: "เพิ่มเติม", icon: "⚙️", href: "/settings" },
];

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
    return remMinutes > 0 ? `${hours} ชม. ${remMinutes} นาทีที่แล้ว` : `${hours} ชม. ที่แล้ว`;
  }
  return `${Math.floor(hours / 24)} วันที่แล้ว`;
}

function greeting() {
  const hour = new Date().getHours();
  if (hour < 11) return "สวัสดีตอนเช้าครับ";
  if (hour < 17) return "สวัสดีตอนบ่ายครับ";
  return "สวัสดีตอนเย็นครับ";
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

export default function Dashboard() {
  const [user, setUser] = useState(undefined);
  const [child, setChild] = useState(null);
  const [activities, setActivities] = useState([]);
  const [quickLogging, setQuickLogging] = useState(false);
  const [, forceTick] = useState(0);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    getChild(CHILD_ID).then(setChild);
    const unsub = watchActivities(CHILD_ID, setActivities, { max: 50 });
    return unsub;
  }, [user]);

  useEffect(() => {
    const id = setInterval(() => forceTick((t) => t + 1), 30000);
    return () => clearInterval(id);
  }, []);

  const latestMilk = activities.find((a) => a.type === "milk");
  const todayCount = (type) => activities.filter((a) => a.type === type && isToday(a.createdAt)).length;

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
        <h1 className="font-display text-2xl font-bold text-abyss">🐳 My Whale</h1>
        <WaveDivider className="mt-2 text-shallow" />
      </header>

      {user === undefined && <p className="mt-6 text-sm text-tide/70">กำลังโหลด...</p>}

      {user === null && (
        <div className="mt-6 rounded-xl2 bg-white p-6 text-center shadow-log">
          <p className="mb-4 text-sm text-abyss/70">เข้าสู่ระบบเพื่อดูและบันทึกข้อมูลของลูก</p>
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
            <p className="mb-3 text-sm text-abyss/60">{greeting()}</p>
            <div className="flex items-center gap-4">
              <div className="flex h-20 w-20 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-shallow to-tide/20 text-4xl shadow-log">
                🐳
              </div>
              <div>
                <p className="font-display text-xl font-semibold text-abyss">
                  {child?.name || "ยังไม่ตั้งชื่อ"}
                </p>
                <p className="text-sm text-abyss/50">
                  {child?.dob ? ageLabel(child.dob) : "ยังไม่ระบุวันเกิด"}
                </p>
              </div>
            </div>
          </section>

          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <p className="mb-2 text-xs font-semibold text-abyss/50">ภาพรวมวันนี้</p>
            <div className="grid grid-cols-3 gap-2 text-center">
              <div>
                <p className="text-lg font-semibold text-abyss">{todayCount("milk")}</p>
                <p className="text-[11px] text-abyss/40">🍼 ครั้ง</p>
              </div>
              <div>
                <p className="text-lg font-semibold text-abyss">{todayCount("sleep")}</p>
                <p className="text-[11px] text-abyss/40">🌙 ครั้ง</p>
              </div>
              <div>
                <p className="text-lg font-semibold text-abyss">{todayCount("diaper")}</p>
                <p className="text-[11px] text-abyss/40">🧷 ครั้ง</p>
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

          <section>
            <p className="mb-2 text-sm font-semibold text-abyss/60">ฟังก์ชันหลัก</p>
            <div className="grid grid-cols-4 gap-3">
              {FUNCTIONS.map((f) => (
                <Link
                  key={f.key}
                  href={f.href}
                  className="flex flex-col items-center gap-1.5 rounded-xl2 bg-white p-3 text-center shadow-log"
                >
                  <span className="flex h-11 w-11 items-center justify-center rounded-full bg-surface text-xl">
                    {f.icon}
                  </span>
                  <span className="text-[11px] leading-tight text-abyss/70">{f.label}</span>
                </Link>
              ))}
            </div>
          </section>

          <section>
            <h2 className="mb-2 text-sm font-semibold text-abyss/60">กิจกรรมล่าสุด</h2>
            <ul className="space-y-2">
              {activities.slice(0, 5).map((a) => (
                <li
                  key={a.id}
                  className={`flex items-center justify-between gap-3 rounded-xl2 border-l-4 bg-white p-3 shadow-log ${TYPE_ACCENT[a.type] || "border-shallow"}`}
                >
                  <div className="flex items-center gap-3">
                    <span className="text-xl" aria-hidden="true">{ACTIVITY_TYPES[a.type]?.icon}</span>
                    <div>
                      <p className="text-sm font-medium text-abyss">{ACTIVITY_TYPES[a.type]?.label}</p>
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
                  ยังไม่มีบันทึก — เริ่มบันทึกได้จากฟังก์ชันด้านบน
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
mkdir -p 'app/stats'
cat > 'app/stats/page.js' << 'MYWHALE_EOF'
"use client";

import { useEffect, useState } from "react";
import { watchAuth } from "@/lib/firebase";
import { watchActivities } from "@/lib/family";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
} from "recharts";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

function lastNDays(n) {
  const days = [];
  for (let i = n - 1; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    days.push(d);
  }
  return days;
}

function dayLabel(d) {
  return d.toLocaleDateString("th-TH", { day: "numeric", month: "short" });
}

function sameDay(a, b) {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

export default function StatsPage() {
  const [user, setUser] = useState(undefined);
  const [activities, setActivities] = useState([]);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    return watchActivities(CHILD_ID, setActivities, { max: 300 });
  }, [user]);

  const days = lastNDays(7);
  const milkPerDay = days.map((d) => ({
    day: dayLabel(d),
    ครั้ง: activities.filter((a) => a.type === "milk" && a.createdAt?.toDate && sameDay(a.createdAt.toDate(), d)).length,
  }));

  const growthEntries = activities
    .filter((a) => a.type === "growth" && a.value)
    .slice()
    .reverse();
  const weightTrend = growthEntries.map((a) => ({
    day: a.createdAt?.toDate ? dayLabel(a.createdAt.toDate()) : "",
    กก: a.value.weight,
  }));
  const heightTrend = growthEntries.map((a) => ({
    day: a.createdAt?.toDate ? dayLabel(a.createdAt.toDate()) : "",
    ซม: a.value.height,
  }));

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <header className="mb-2">
        <h1 className="font-display text-2xl font-bold text-abyss">สถิติ & กราฟ</h1>
        <WaveDivider className="mt-2 w-16 text-shallow" />
      </header>

      {user && (
        <div className="mt-4 space-y-4">
          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <p className="mb-2 text-sm font-semibold text-abyss/60">การกินนม (ครั้ง/วัน)</p>
            <div style={{ width: "100%", height: 160 }}>
              <ResponsiveContainer>
                <BarChart data={milkPerDay}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#D6ECFB" />
                  <XAxis dataKey="day" tick={{ fontSize: 11, fill: "#2D3A4A" }} />
                  <YAxis allowDecimals={false} tick={{ fontSize: 11, fill: "#2D3A4A" }} width={24} />
                  <Tooltip />
                  <Bar dataKey="ครั้ง" fill="#4F9DDE" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </section>

          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <p className="mb-2 text-sm font-semibold text-abyss/60">น้ำหนัก (กก.)</p>
            {weightTrend.length > 0 ? (
              <div style={{ width: "100%", height: 160 }}>
                <ResponsiveContainer>
                  <LineChart data={weightTrend}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#D6ECFB" />
                    <XAxis dataKey="day" tick={{ fontSize: 11, fill: "#2D3A4A" }} />
                    <YAxis tick={{ fontSize: 11, fill: "#2D3A4A" }} width={28} />
                    <Tooltip />
                    <Line type="monotone" dataKey="กก" stroke="#4F9DDE" strokeWidth={2} dot={{ r: 3 }} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <p className="py-6 text-center text-sm text-abyss/30">ยังไม่มีบันทึกน้ำหนัก</p>
            )}
          </section>

          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <p className="mb-2 text-sm font-semibold text-abyss/60">ส่วนสูง (ซม.)</p>
            {heightTrend.length > 0 ? (
              <div style={{ width: "100%", height: 160 }}>
                <ResponsiveContainer>
                  <LineChart data={heightTrend}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#D6ECFB" />
                    <XAxis dataKey="day" tick={{ fontSize: 11, fill: "#2D3A4A" }} />
                    <YAxis tick={{ fontSize: 11, fill: "#2D3A4A" }} width={28} />
                    <Tooltip />
                    <Line type="monotone" dataKey="ซม" stroke="#FFD166" strokeWidth={2} dot={{ r: 3 }} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <p className="py-6 text-center text-sm text-abyss/30">ยังไม่มีบันทึกส่วนสูง</p>
            )}
          </section>

          <p className="text-center text-xs text-abyss/30">
            กราฟการนอนแบบชั่วโมง/วัน จะแม่นยำขึ้นเมื่อเพิ่มฟีเจอร์ตัวจับเวลานอนในอนาคต
          </p>
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

import { useEffect, useState, Suspense } from "react";
import { useSearchParams } from "next/navigation";
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
  return (
    <Suspense fallback={null}>
      <TimelineContent />
    </Suspense>
  );
}

function TimelineContent() {
  const searchParams = useSearchParams();
  const presetType = searchParams.get("type");
  const [user, setUser] = useState(undefined);
  const [activities, setActivities] = useState([]);
  const [filter, setFilter] = useState(presetType || "all");
  const [showForm, setShowForm] = useState(Boolean(presetType));
  const [type, setType] = useState(presetType || "milk");
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
cat > 'components/BubbleWatermark.js' << 'MYWHALE_EOF'
export default function BubbleWatermark() {
  const bubbles = [
    { cx: 30, cy: 90, r: 22, o: 0.35 },
    { cx: 85, cy: 70, r: 10, o: 0.3 },
    { cx: 15, cy: 60, r: 7, o: 0.28 },
    { cx: 60, cy: 55, r: 16, o: 0.3 },
    { cx: 90, cy: 40, r: 6, o: 0.25 },
    { cx: 40, cy: 35, r: 9, o: 0.3 },
    { cx: 10, cy: 25, r: 14, o: 0.25 },
    { cx: 70, cy: 18, r: 5, o: 0.2 },
    { cx: 25, cy: 10, r: 6, o: 0.2 },
    { cx: 55, cy: 5, r: 11, o: 0.18 },
  ];

  return (
    <svg
      className="pointer-events-none fixed inset-0 -z-10 h-full w-full"
      viewBox="0 0 100 100"
      preserveAspectRatio="xMidYMax slice"
      aria-hidden="true"
    >
      {bubbles.map((b, i) => (
        <circle
          key={i}
          cx={b.cx}
          cy={b.cy}
          r={b.r}
          fill="#BFE1EC"
          fillOpacity={b.o}
        />
      ))}
    </svg>
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

// --- Activities: one collection, filtered by `type` ---

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

// --- Appointments ---

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

// --- Milestones: developmental firsts (sat up, crawled, first word...) ---

export async function addMilestone(childId, milestone) {
  return addDoc(collection(db, `${childPath(childId)}/milestones`), {
    ...milestone,
    createdAt: Timestamp.now(),
  });
}

export async function deleteMilestone(childId, milestoneId) {
  return deleteDoc(doc(db, `${childPath(childId)}/milestones/${milestoneId}`));
}

export function watchMilestones(childId, callback, { max = 50 } = {}) {
  const q = query(
    collection(db, `${childPath(childId)}/milestones`),
    orderBy("date", "desc"),
    fsLimit(max)
  );
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
  });
}

export const ACTIVITY_TYPES = {
  milk: { label: "นม", icon: "🍼" },
  sleep: { label: "การนอน", icon: "🌙" },
  diaper: { label: "เปลี่ยนแพมเพิส", icon: "🧷" },
  vaccine: { label: "วัคซีน", icon: "💉" },
  growth: { label: "น้ำหนัก/ส่วนสูง", icon: "📏" },
  doctor: { label: "พบแพทย์", icon: "🩺" },
};

export const MILESTONE_COLORS = ["#4F9DDE", "#6FCF97", "#F2C94C", "#F2994A", "#BB6BD9"];
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
mkdir -p 'lib'
cat > 'lib/storage.js' << 'MYWHALE_EOF'
"use client";

import {
  getStorage,
  ref,
  uploadBytes,
  getDownloadURL,
  deleteObject,
} from "firebase/storage";
import {
  collection,
  addDoc,
  deleteDoc,
  doc,
  query,
  orderBy,
  onSnapshot,
  Timestamp,
} from "firebase/firestore";
import { app, db } from "./firebase";

const FAMILY_ID = process.env.NEXT_PUBLIC_FAMILY_ID || "toon-family";
const storage = getStorage(app);

function photoDocsPath(childId) {
  return `families/${FAMILY_ID}/children/${childId}/photos`;
}

function storagePath(childId, fileName) {
  return `families/${FAMILY_ID}/children/${childId}/photos/${Date.now()}-${fileName}`;
}

// Uploads the file to Storage, then records a small Firestore doc pointing at
// it — makes listing and deleting easy without paging through Storage itself.
export async function uploadPhoto(childId, file, uploadedBy) {
  const path = storagePath(childId, file.name);
  const fileRef = ref(storage, path);
  await uploadBytes(fileRef, file);
  const url = await getDownloadURL(fileRef);
  return addDoc(collection(db, photoDocsPath(childId)), {
    url,
    path,
    uploadedBy: uploadedBy || "",
    createdAt: Timestamp.now(),
  });
}

export async function deletePhoto(childId, photoDocId, storagePathValue) {
  if (storagePathValue) {
    try {
      await deleteObject(ref(storage, storagePathValue));
    } catch (e) {
      // Already gone from Storage — still remove the Firestore record.
      console.warn("Storage delete skipped", e);
    }
  }
  return deleteDoc(doc(db, `${photoDocsPath(childId)}/${photoDocId}`));
}

export function watchPhotos(childId, callback) {
  const q = query(collection(db, photoDocsPath(childId)), orderBy("createdAt", "desc"));
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
  });
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
    "recharts": "^2.12.7"
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
        // "My Whale" — soft, friendly sky-blue palette (matches the ปลาวาฬ reference).
        surface: "#EAF4FB", // page background — pale sky blue
        shallow: "#D6ECFB", // chips, dividers, inactive states
        tide: "#4F9DDE",    // primary actions — bright friendly blue
        abyss: "#2D3A4A",   // headers, body text — soft navy, not harsh black
        glow: "#FFD166",    // single warm accent — golden star, used sparingly
      },
      fontFamily: {
        display: ["var(--font-display)"],
        body: ["var(--font-body)"],
      },
      borderRadius: {
        xl2: "1.25rem",
      },
      boxShadow: {
        log: "0 1px 2px rgba(45, 58, 74, 0.05), 0 6px 20px rgba(79, 157, 222, 0.10)",
      },
    },
  },
  plugins: [],
};
MYWHALE_EOF
echo 'Files updated. Installing dependencies...'
npm install
echo ''
echo 'Done! Restart the dev server:'
echo '  Ctrl+C to stop the old one if still running, then: npm run dev'
