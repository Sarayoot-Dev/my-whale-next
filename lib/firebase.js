"use client";

import { initializeApp, getApps, getApp } from "firebase/app";
import {
  getAuth,
  GoogleAuthProvider,
  signInWithCredential,
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

const GOOGLE_CLIENT_ID = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID;

// Sign in via Google Identity Services (One Tap/FedCM) instead of Firebase's
// signInWithPopup/signInWithRedirect: both of those hop through authDomain
// (my-whale.firebaseapp.com), a different site from where this app is hosted,
// and the redirect result gets silently dropped once a browser blocks
// cross-site storage (Safari ITP, LINE's in-app webview, etc). GIS runs
// entirely on this origin and hands back an ID token directly.
export function initGoogleSignIn() {
  if (typeof window === "undefined" || !window.google?.accounts?.id) return;
  window.google.accounts.id.initialize({
    client_id: GOOGLE_CLIENT_ID,
    callback: (response) => {
      signInWithCredential(auth, GoogleAuthProvider.credential(response.credential)).catch(
        (e) => console.error("signInWithCredential error", e)
      );
    },
    use_fedcm_for_prompt: true,
  });
}

export function signIn() {
  if (typeof window === "undefined" || !window.google?.accounts?.id) {
    console.error("Google Identity Services not loaded yet");
    return;
  }
  window.google.accounts.id.prompt();
}

export function signOut() {
  return fbSignOut(auth);
}

export function watchAuth(callback) {
  return onAuthStateChanged(auth, callback);
}
