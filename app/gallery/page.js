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
