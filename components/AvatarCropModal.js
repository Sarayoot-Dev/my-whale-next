"use client";

import { useEffect, useState, useCallback } from "react";
import Cropper from "react-easy-crop";

// Mobile camera photos are routinely 3000-4000px / several MB. Reading that
// straight into a base64 data URI (the previous approach here) forces the
// browser to build a ~33% larger string and parse it on the main thread —
// on a mid-range phone that's a real, visible stall right as the modal
// opens. Downscaling through a canvas first keeps the same "no object-URL
// lifecycle to race" property (we hold the resulting blob URL in a plain
// local variable with explicit, single-owner cleanup below) while working
// with a fraction of the data: a crop preview never needs more detail than
// this anyway, and the final output is resized down to 800px regardless.
function loadPreviewBlobUrl(file, maxSize = 1600) {
  return new Promise((resolve, reject) => {
    const sourceUrl = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      let { width, height } = img;
      if (width > maxSize || height > maxSize) {
        if (width > height) {
          height = Math.round((height * maxSize) / width);
          width = maxSize;
        } else {
          width = Math.round((width * maxSize) / height);
          height = maxSize;
        }
      }
      const canvas = document.createElement("canvas");
      canvas.width = width;
      canvas.height = height;
      canvas.getContext("2d").drawImage(img, 0, 0, width, height);
      URL.revokeObjectURL(sourceUrl);
      canvas.toBlob(
        (blob) => (blob ? resolve(URL.createObjectURL(blob)) : reject(new Error("Canvas toBlob failed"))),
        "image/jpeg",
        0.9
      );
    };
    img.onerror = () => {
      URL.revokeObjectURL(sourceUrl);
      reject(new Error("Failed to load image"));
    };
    img.src = sourceUrl;
  });
}

// Draws the cropped region (in the source image's natural pixel coordinates,
// as reported by react-easy-crop's onCropComplete) onto a canvas and reads it
// back out as a JPEG blob. Runs before the existing resize/compress step, so
// this stays lossless-ish (quality 0.95) — final size/quality is enforced by
// resizeImageToJpeg() afterwards, same as before this feature existed.
function getCroppedBlob(imageSrc, cropPixels) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => {
      const canvas = document.createElement("canvas");
      canvas.width = cropPixels.width;
      canvas.height = cropPixels.height;
      canvas
        .getContext("2d")
        .drawImage(
          image,
          cropPixels.x,
          cropPixels.y,
          cropPixels.width,
          cropPixels.height,
          0,
          0,
          cropPixels.width,
          cropPixels.height
        );
      canvas.toBlob(
        (blob) => (blob ? resolve(blob) : reject(new Error("Canvas toBlob failed"))),
        "image/jpeg",
        0.95
      );
    };
    image.onerror = () => reject(new Error("Failed to load image"));
    image.src = imageSrc;
  });
}

export default function AvatarCropModal({ file, saving, error, onCancel, onSave }) {
  const [imageSrc, setImageSrc] = useState("");
  const [loadError, setLoadError] = useState("");
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState(null);

  useEffect(() => {
    let cancelled = false;
    let ownedUrl = null;
    setImageSrc("");
    setLoadError("");
    loadPreviewBlobUrl(file)
      .then((url) => {
        if (cancelled) {
          URL.revokeObjectURL(url);
          return;
        }
        ownedUrl = url;
        setImageSrc(url);
      })
      .catch((err) => {
        console.error(err);
        if (!cancelled) setLoadError("โหลดรูปนี้ไม่สำเร็จ ลองเลือกรูปอื่นดูครับ");
      });
    return () => {
      cancelled = true;
      if (ownedUrl) URL.revokeObjectURL(ownedUrl);
    };
  }, [file]);

  const handleCropComplete = useCallback((_, pixels) => {
    setCroppedAreaPixels(pixels);
  }, []);

  function handleMediaError() {
    setLoadError("เปิดไฟล์รูปนี้ไม่ได้ (อาจเป็นไฟล์ HEIC หรือไฟล์เสีย) ลองเลือกรูปอื่นดูครับ");
  }

  // Local flag covers the gap between tapping "บันทึก" and the parent's
  // `saving` prop turning true (cropping the canvas takes a beat) — without
  // it the button stays tappable for a moment after the first tap.
  const [preparing, setPreparing] = useState(false);
  const busy = saving || preparing;

  async function handleSaveClick() {
    if (!croppedAreaPixels || busy) return;
    setPreparing(true);
    try {
      const blob = await getCroppedBlob(imageSrc, croppedAreaPixels);
      onSave(blob);
    } finally {
      setPreparing(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-abyss">
      <div className="relative flex-1">
        {imageSrc && (
          <Cropper
            image={imageSrc}
            crop={crop}
            zoom={zoom}
            aspect={1}
            cropShape="round"
            showGrid={false}
            objectFit="contain"
            mediaProps={{ onError: handleMediaError }}
            onCropChange={setCrop}
            onZoomChange={setZoom}
            onCropComplete={handleCropComplete}
          />
        )}
        {!imageSrc && !loadError && (
          <p className="flex h-full items-center justify-center text-sm text-white/60">
            กำลังโหลดรูป...
          </p>
        )}
        {loadError && (
          <p className="flex h-full items-center justify-center px-8 text-center text-sm text-white/80">
            {loadError}
          </p>
        )}

        {/* Full-screen loading state while the crop/resize/upload/save chain
            runs, so the interactive cropper never sits there disabled with
            no clear feedback — the modal stays mounted and opaque the whole
            time this is up. */}
        {busy && (
          <div className="absolute inset-0 z-10 flex flex-col items-center justify-center gap-3 bg-abyss/95">
            <span
              className="h-10 w-10 animate-spin rounded-full border-4 border-white/25 border-t-white"
              aria-hidden="true"
            />
            <p className="text-sm text-white">กำลังบันทึกรูป...</p>
          </div>
        )}
      </div>

      <div className="space-y-4 bg-white p-4 pb-[max(1rem,env(safe-area-inset-bottom))] shadow-log">
        <label className="flex items-center gap-3">
          <span className="text-lg text-abyss/40" aria-hidden="true">
            🔍
          </span>
          <input
            type="range"
            min={1}
            max={3}
            step={0.01}
            value={zoom}
            onChange={(e) => setZoom(Number(e.target.value))}
            disabled={!imageSrc}
            className="h-8 flex-1 accent-tide disabled:opacity-40"
            aria-label="ซูมรูป"
          />
        </label>

        {error && <p className="text-center text-xs text-red-500">{error}</p>}

        <div className="flex gap-3">
          <button
            type="button"
            onClick={onCancel}
            disabled={busy}
            className="h-14 flex-1 rounded-full border border-shallow text-base font-semibold text-abyss/60 disabled:opacity-60"
          >
            ยกเลิก
          </button>
          <button
            type="button"
            onClick={handleSaveClick}
            disabled={busy || !croppedAreaPixels}
            className="h-14 flex-1 rounded-full bg-tide text-base font-semibold text-white disabled:opacity-60"
          >
            {busy ? "กำลังบันทึก..." : "บันทึก"}
          </button>
        </div>
      </div>
    </div>
  );
}
