"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import Script from "next/script";
import { watchAuth, signIn, initGoogleSignIn } from "@/lib/firebase";
import { getChild, saveChild, watchActivities, watchAppointments } from "@/lib/family";
import { uploadChildProfilePhoto } from "@/lib/storage";
import { resizeImageToJpeg } from "@/lib/image";
import BottomNav from "@/components/BottomNav";
import WaveDivider from "@/components/WaveDivider";

const CHILD_ID = process.env.NEXT_PUBLIC_CHILD_ID || "main";

// How long after the last milk feed we start nudging "time to feed again".
const FEED_REMINDER_HOURS = 3;

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

function dobLabel(dob) {
  if (!dob) return "ยังไม่ระบุวันเกิด";
  return new Date(dob).toLocaleDateString("th-TH", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

function elapsedLabel(date) {
  if (!date) return null;
  const diffMs = Date.now() - date.getTime();
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

function isSameDate(a, b) {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

function greeting() {
  const hour = new Date().getHours();
  if (hour < 11) return "สวัสดีตอนเช้าครับ";
  if (hour < 17) return "สวัสดีตอนบ่ายครับ";
  return "สวัสดีตอนเย็นครับ";
}

export default function Dashboard() {
  const [user, setUser] = useState(undefined);
  const [child, setChild] = useState(null);
  const [activities, setActivities] = useState([]);
  const [appointments, setAppointments] = useState([]);
  const [dismissedAlerts, setDismissedAlerts] = useState([]);
  const [uploadingPhoto, setUploadingPhoto] = useState(false);
  const [, forceTick] = useState(0);
  const photoInputRef = useRef(null);

  useEffect(() => watchAuth(setUser), []);

  useEffect(() => {
    if (!user) return;
    getChild(CHILD_ID).then(setChild);
    const unsubActivities = watchActivities(CHILD_ID, setActivities, { max: 200 });
    const unsubAppointments = watchAppointments(CHILD_ID, setAppointments);
    return () => {
      unsubActivities();
      unsubAppointments();
    };
  }, [user]);

  useEffect(() => {
    const id = setInterval(() => forceTick((t) => t + 1), 60000);
    return () => clearInterval(id);
  }, []);

  const latestGrowth = activities.find((a) => a.type === "growth" && a.value);
  const latestMilk = activities.find((a) => a.type === "milk" && a.createdAt?.toDate);

  const yesterday = useMemo(() => {
    const y = new Date();
    y.setDate(y.getDate() - 1);
    return y;
  }, []);

  const yesterdaySummary = useMemo(() => {
    const isYesterday = (a) => a.createdAt?.toDate && isSameDate(a.createdAt.toDate(), yesterday);
    const milkOz = activities
      .filter((a) => a.type === "milk" && isYesterday(a))
      .reduce((sum, a) => sum + (Number(a.amountOz) || 0), 0);
    const sleepMinutes = activities
      .filter((a) => a.type === "sleep" && isYesterday(a))
      .reduce((sum, a) => sum + (Number(a.durationMin) || 0), 0);
    const diaperCount = activities.filter((a) => a.type === "diaper" && isYesterday(a)).length;
    return {
      milkOz,
      sleepHours: Math.round((sleepMinutes / 60) * 10) / 10,
      diaperCount,
    };
  }, [activities, yesterday]);

  const alerts = useMemo(() => {
    const list = [];
    const lastMilkAt = latestMilk?.createdAt?.toDate?.();
    if (lastMilkAt) {
      const hoursSince = (Date.now() - lastMilkAt.getTime()) / 3600000;
      if (hoursSince >= FEED_REMINDER_HOURS) {
        list.push({
          id: "feed-due",
          icon: "🍼",
          text: `ถึงเวลาให้นมแล้ว — ผ่านมา ${Math.floor(hoursSince)} ชม. จากมื้อล่าสุด`,
        });
      }
    }
    const today = new Date().toISOString().slice(0, 10);
    appointments
      .filter((a) => a.type === "vaccine" && a.date === today)
      .forEach((a) => list.push({ id: `vaccine-${a.id}`, icon: "💉", text: `วันนี้มีนัดฉีดวัคซีน: ${a.title}` }));
    return list.filter((a) => !dismissedAlerts.includes(a.id));
  }, [latestMilk, appointments, dismissedAlerts]);

  async function handlePhotoChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadingPhoto(true);
    try {
      const blob = await resizeImageToJpeg(file, 800, 0.8);
      const photoURL = await uploadChildProfilePhoto(CHILD_ID, blob);
      await saveChild(CHILD_ID, { photoURL });
      setChild((c) => ({ ...c, photoURL }));
    } catch (err) {
      console.error("profile photo upload failed", err);
    } finally {
      setUploadingPhoto(false);
      if (photoInputRef.current) photoInputRef.current.value = "";
    }
  }

  return (
    <main className="mx-auto min-h-screen max-w-md px-4 pb-24 pt-8">
      <Script
        src="https://accounts.google.com/gsi/client"
        strategy="afterInteractive"
        onLoad={initGoogleSignIn}
      />
      <header className="mb-2 flex items-start justify-between">
        <div>
          <h1 className="font-display text-2xl font-bold text-abyss">🐳 My Whale</h1>
          <WaveDivider className="mt-2 text-shallow" />
        </div>
        {user && (
          <div className="flex gap-1">
            <Link
              href="/gallery"
              aria-label="แกลเลอรี่"
              className="flex h-10 w-10 items-center justify-center rounded-full bg-white text-lg shadow-log"
            >
              📷
            </Link>
            <Link
              href="/settings"
              aria-label="ตั้งค่า"
              className="flex h-10 w-10 items-center justify-center rounded-full bg-white text-lg shadow-log"
            >
              ⚙️
            </Link>
          </div>
        )}
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
          {alerts.length > 0 && (
            <div className="space-y-2 rounded-xl2 bg-glow/20 p-4 shadow-log">
              {alerts.map((a) => (
                <div key={a.id} className="flex items-center justify-between gap-3">
                  <div className="flex items-center gap-2">
                    <span className="text-lg" aria-hidden="true">{a.icon}</span>
                    <p className="text-sm font-medium text-abyss">{a.text}</p>
                  </div>
                  <button
                    onClick={() => setDismissedAlerts((d) => [...d, a.id])}
                    aria-label="ปิดการแจ้งเตือน"
                    className="shrink-0 rounded-full px-2 py-1 text-xs text-abyss/40 hover:bg-white/60"
                  >
                    ✕
                  </button>
                </div>
              ))}
            </div>
          )}

          <section className="rounded-xl2 bg-white p-5 shadow-log">
            <p className="mb-3 text-sm text-abyss/60">{greeting()}</p>
            <div className="flex items-center gap-4">
              <button
                type="button"
                onClick={() => photoInputRef.current?.click()}
                aria-label="เปลี่ยนรูปโปรไฟล์ลูก"
                className="relative flex h-20 w-20 shrink-0 items-center justify-center overflow-hidden rounded-full bg-gradient-to-br from-shallow to-tide/20 text-4xl shadow-log"
              >
                {child?.photoURL ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={child.photoURL} alt="" className="h-full w-full object-cover" />
                ) : (
                  "🐳"
                )}
                {uploadingPhoto && (
                  <span className="absolute inset-0 flex items-center justify-center bg-abyss/40 text-xs text-white">
                    ...
                  </span>
                )}
                <span className="absolute bottom-0 right-0 flex h-6 w-6 items-center justify-center rounded-full bg-tide text-xs shadow-log">
                  📷
                </span>
              </button>
              <input
                ref={photoInputRef}
                type="file"
                accept="image/*"
                onChange={handlePhotoChange}
                className="hidden"
              />
              <div>
                <p className="font-display text-xl font-semibold text-abyss">
                  {child?.name || "ยังไม่ตั้งชื่อ"}
                </p>
                <p className="text-sm text-abyss/50">{child?.dob ? ageLabel(child.dob) : "ยังไม่ระบุวันเกิด"}</p>
                <p className="text-xs text-abyss/40">{dobLabel(child?.dob)}</p>
              </div>
            </div>
          </section>

          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <p className="mb-2 text-xs font-semibold text-abyss/50">น้ำหนัก/ส่วนสูงล่าสุด</p>
            {latestGrowth ? (
              <div className="flex gap-6">
                <div>
                  <p className="text-lg font-semibold text-abyss">{latestGrowth.value.weight} กก.</p>
                  <p className="text-[11px] text-abyss/40">น้ำหนัก</p>
                </div>
                <div>
                  <p className="text-lg font-semibold text-abyss">{latestGrowth.value.height} ซม.</p>
                  <p className="text-[11px] text-abyss/40">ส่วนสูง</p>
                </div>
              </div>
            ) : (
              <p className="text-sm text-abyss/30">
                ยังไม่มีบันทึก —{" "}
                <Link href="/health/growth" className="text-tide underline">
                  เพิ่มที่ศูนย์สุขภาพ
                </Link>
              </p>
            )}
          </section>

          <section className="rounded-xl2 bg-white p-4 shadow-log">
            <p className="mb-2 text-xs font-semibold text-abyss/50">สรุปเมื่อวาน</p>
            <div className="grid grid-cols-3 gap-2 text-center">
              <div>
                <p className="text-lg font-semibold text-abyss">{yesterdaySummary.milkOz}</p>
                <p className="text-[11px] text-abyss/40">🍼 ออนส์</p>
              </div>
              <div>
                <p className="text-lg font-semibold text-abyss">{yesterdaySummary.sleepHours}</p>
                <p className="text-[11px] text-abyss/40">🌙 ชม.</p>
              </div>
              <div>
                <p className="text-lg font-semibold text-abyss">{yesterdaySummary.diaperCount}</p>
                <p className="text-[11px] text-abyss/40">🧷 ครั้ง</p>
              </div>
            </div>
          </section>

          {latestMilk && (
            <p className="text-center text-xs text-abyss/40">
              ให้นมล่าสุด {elapsedLabel(latestMilk.createdAt.toDate())}
            </p>
          )}
        </div>
      )}

      <BottomNav />
    </main>
  );
}
