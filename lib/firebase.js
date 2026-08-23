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
