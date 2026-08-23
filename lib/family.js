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

// --- Sleep timer: a "sleep" activity with startedAt set and endedAt null is
// the in-progress session; ending it fills in endedAt + durationMin. ---

export async function startSleep(childId) {
  return addActivity(childId, { type: "sleep", startedAt: Timestamp.now(), endedAt: null });
}

export async function endSleep(childId, activityId, startedAt) {
  const endedAt = Timestamp.now();
  const durationMin = Math.round((endedAt.toMillis() - startedAt.toMillis()) / 60000);
  return updateActivity(childId, activityId, { endedAt, durationMin });
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
