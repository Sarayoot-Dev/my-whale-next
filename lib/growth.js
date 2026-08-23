"use client";

import {
  loadTable,
  lookupLms,
  calculateZScore,
  ageInDays as pgAgeInDays,
} from "@pedi-growth/core";

// WHO reference z-scores for the percentile band lines we draw on the chart.
const PERCENTILE_Z = {
  p3: -1.8808,
  p15: -1.0364,
  p50: 0,
  p85: 1.0364,
  p97: 1.8808,
};

// WHO 0-5y tables run 0-1856 days (~60 months) — the only range this app needs.
export const MAX_AGE_DAYS = 1856;

const TABLES = {
  weight: { boys: "wfa-boys-0-5", girls: "wfa-girls-0-5" },
  height: { boys: "lhfa-boys-0-5", girls: "lhfa-girls-0-5" },
};

function zToValue(z, { L, M, S }) {
  return Math.abs(L) < 1e-6 ? M * Math.exp(S * z) : M * Math.pow(1 + L * S * z, 1 / L);
}

export function ageInDaysFromDob(dob, at = new Date()) {
  if (!dob) return null;
  return pgAgeInDays(new Date(dob), at);
}

// Percentile band lines (P3/P15/P50/P85/P97) from birth to `maxAgeDays`, for
// plotting the child's own weight/height points against.
export async function getGrowthPercentileCurve(indicator, gender, maxAgeDays) {
  const sexKey = gender === "female" ? "girls" : "boys";
  const table = await loadTable(TABLES[indicator][sexKey]);
  const capped = Math.min(Math.max(maxAgeDays, 60), MAX_AGE_DAYS);
  const step = 15;
  const points = [];
  for (let d = 0; d <= capped; d += step) {
    const lms = lookupLms(table, d);
    if (!lms) continue;
    const row = { ageDays: d, ageMonths: +(d / 30.4375).toFixed(1) };
    for (const [label, z] of Object.entries(PERCENTILE_Z)) {
      row[label] = +zToValue(z, lms).toFixed(2);
    }
    points.push(row);
  }
  return points;
}

// z-score + percentile for one measurement (weight in kg or height in cm) at a
// given age — thin wrapper so callers don't need to know the sex-key mapping.
export async function getGrowthZScore(indicator, gender, ageDays, measurement) {
  const sex = gender === "female" ? "female" : "male";
  return calculateZScore({
    indicator: indicator === "weight" ? "weight-for-age" : "length-height-for-age",
    sex,
    ageInDays: Math.min(Math.max(ageDays, 0), MAX_AGE_DAYS),
    measurement,
  });
}
