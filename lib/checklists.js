// Static reference data — not user data, so it lives in code rather than Firestore.
// Simplified Thai EPI schedule; tick state is stored per-child in child.vaccinesDone.
export const VACCINE_SCHEDULE = [
  { key: "hbv1", ageLabel: "แรกเกิด", name: "ไวรัสตับอักเสบบี เข็มที่ 1 (HBV1)" },
  { key: "bcg", ageLabel: "แรกเกิด", name: "วัณโรค (BCG)" },
  { key: "dtphibhb1", ageLabel: "2 เดือน", name: "คอตีบ-บาดทะยัก-ไอกรน-ตับอักเสบบี-ฮิบ เข็มที่ 1" },
  { key: "opv1", ageLabel: "2 เดือน", name: "โปลิโอ (OPV) เข็มที่ 1" },
  { key: "dtphibhb2", ageLabel: "4 เดือน", name: "คอตีบ-บาดทะยัก-ไอกรน-ตับอักเสบบี-ฮิบ เข็มที่ 2" },
  { key: "opv2", ageLabel: "4 เดือน", name: "โปลิโอ เข็มที่ 2" },
  { key: "dtphibhb3", ageLabel: "6 เดือน", name: "คอตีบ-บาดทะยัก-ไอกรน-ตับอักเสบบี-ฮิบ เข็มที่ 3" },
  { key: "opv3", ageLabel: "6 เดือน", name: "โปลิโอ เข็มที่ 3" },
  { key: "je1", ageLabel: "9 เดือน", name: "ไข้สมองอักเสบเจอี เข็มที่ 1" },
  { key: "mmr1", ageLabel: "9-12 เดือน", name: "หัด-คางทูม-หัดเยอรมัน (MMR) เข็มที่ 1" },
  { key: "dtp4", ageLabel: "18 เดือน", name: "คอตีบ-บาดทะยัก-ไอกรน กระตุ้นเข็มที่ 4" },
  { key: "opv4", ageLabel: "18 เดือน", name: "โปลิโอ กระตุ้นเข็มที่ 4" },
  { key: "je2", ageLabel: "18 เดือน", name: "ไข้สมองอักเสบเจอี เข็มที่ 2" },
  { key: "dtp5", ageLabel: "4-6 ปี", name: "คอตีบ-บาดทะยัก-ไอกรน กระตุ้นเข็มที่ 5" },
  { key: "opv5", ageLabel: "4-6 ปี", name: "โปลิโอ กระตุ้นเข็มที่ 5" },
  { key: "mmr2", ageLabel: "4-6 ปี", name: "หัด-คางทูม-หัดเยอรมัน เข็มที่ 2" },
];

// Standard developmental milestone checklist grouped by age range; tick state
// lives in child.milestonesDone. Informational only, not a diagnostic tool.
export const MILESTONE_CHECKLIST = [
  {
    range: "0-3 เดือน",
    items: [
      { key: "m0-1", label: "ยกศีรษะได้ขณะคว่ำ" },
      { key: "m0-2", label: "ยิ้มตอบเมื่อมีคนยิ้มให้" },
      { key: "m0-3", label: "มองตามวัตถุที่เคลื่อนไหว" },
    ],
  },
  {
    range: "3-6 เดือน",
    items: [
      { key: "m3-1", label: "พลิกคว่ำ-หงายได้" },
      { key: "m3-2", label: "คว้าของเข้าปาก" },
      { key: "m3-3", label: "หัวเราะเสียงดัง" },
    ],
  },
  {
    range: "6-9 เดือน",
    items: [
      { key: "m6-1", label: "นั่งได้เองโดยไม่ต้องพยุง" },
      { key: "m6-2", label: "คลานได้" },
      { key: "m6-3", label: "ส่งเสียงพยางค์ เช่น มา-มา บา-บา" },
    ],
  },
  {
    range: "9-12 เดือน",
    items: [
      { key: "m9-1", label: "เกาะยืนได้" },
      { key: "m9-2", label: "หยิบของชิ้นเล็กด้วยนิ้วโป้งกับนิ้วชี้" },
      { key: "m9-3", label: "โบกมือบ๊ายบาย" },
    ],
  },
  {
    range: "12-18 เดือน",
    items: [
      { key: "m12-1", label: "เดินได้เอง" },
      { key: "m12-2", label: "พูดคำที่มีความหมายได้ 1-3 คำ" },
      { key: "m12-3", label: "ดื่มน้ำจากแก้วเองได้" },
    ],
  },
  {
    range: "18-24 เดือน",
    items: [
      { key: "m18-1", label: "วิ่งได้" },
      { key: "m18-2", label: "พูดเป็นวลี 2 คำ" },
      { key: "m18-3", label: "เลียนแบบท่าทางผู้ใหญ่" },
    ],
  },
  {
    range: "2-3 ปี",
    items: [
      { key: "m24-1", label: "ขึ้นบันไดสลับเท้าได้" },
      { key: "m24-2", label: "พูดเป็นประโยคสั้นๆ" },
      { key: "m24-3", label: "เล่นสมมติกับของเล่น" },
    ],
  },
];
