"use client";

import { useCallback, useEffect, useState } from "react";
import Cropper from "react-easy-crop";

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
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState(null);

  useEffect(() => {
    const url = URL.createObjectURL(file);
    setImageSrc(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  const handleCropComplete = useCallback((_, pixels) => {
    setCroppedAreaPixels(pixels);
  }, []);

  async function handleSaveClick() {
    if (!croppedAreaPixels) return;
    const blob = await getCroppedBlob(imageSrc, croppedAreaPixels);
    onSave(blob);
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
            onCropChange={setCrop}
            onZoomChange={setZoom}
            onCropComplete={handleCropComplete}
          />
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
            className="h-8 flex-1 accent-tide"
            aria-label="ซูมรูป"
          />
        </label>

        {error && <p className="text-center text-xs text-red-500">{error}</p>}

        <div className="flex gap-3">
          <button
            type="button"
            onClick={onCancel}
            disabled={saving}
            className="h-14 flex-1 rounded-full border border-shallow text-base font-semibold text-abyss/60 disabled:opacity-60"
          >
            ยกเลิก
          </button>
          <button
            type="button"
            onClick={handleSaveClick}
            disabled={saving || !croppedAreaPixels}
            className="h-14 flex-1 rounded-full bg-tide text-base font-semibold text-white disabled:opacity-60"
          >
            {saving ? "กำลังบันทึก..." : "บันทึก"}
          </button>
        </div>
      </div>
    </div>
  );
}
