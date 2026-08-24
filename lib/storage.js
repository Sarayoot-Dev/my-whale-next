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

function profilePhotoPath(childId) {
  return `families/${FAMILY_ID}/children/${childId}/profile.jpg`;
}

// Fixed path (not a new file per upload like uploadPhoto) — each upload
// overwrites the previous profile photo.
export async function uploadChildProfilePhoto(childId, blob) {
  const fileRef = ref(storage, profilePhotoPath(childId));
  await uploadBytes(fileRef, blob, { contentType: "image/jpeg" });
  return getDownloadURL(fileRef);
}

// Uploads the file (or a pre-processed Blob — Blobs have no `.name`, so pass
// fileName explicitly in that case) to Storage, then records a small
// Firestore doc pointing at it — makes listing and deleting easy without
// paging through Storage itself.
export async function uploadPhoto(childId, file, uploadedBy, fileName) {
  const name = fileName || file.name || `photo-${Date.now()}.jpg`;
  const path = storagePath(childId, name);
  const fileRef = ref(storage, path);
  await uploadBytes(fileRef, file, { contentType: file.type || "image/jpeg" });
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
