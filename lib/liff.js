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
