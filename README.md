# My Whale — v2

Family baby-tracking app. Next.js + Firebase (Firestore/Auth) + LINE LIFF.
Shared family data model (`families/toon-family/...`) so everyone signed in
with a Google account sees the same records — same idea as the old single-file
PWA, but split into real pages/components so one bug doesn't take down the
whole app.

**Scope for this version (agreed):** health timeline (milk/sleep/vaccine/
growth/doctor), calendar of appointments, one-shot AI daily summary.
Chat companion / gamification are deliberately left for a later version.

## Setup — entirely from your phone via GitHub Codespaces

1. **Create an empty repo** on github.com (GitHub app or mobile browser).
   Do NOT add a README/gitignore when creating it — leave it fully empty.
2. Open the repo → **Code → Codespaces → Create codespace on main**.
   This opens a full VS Code in your browser, no install needed.
3. In the Codespaces **terminal** (bottom panel), paste the entire contents
   of `setup.sh` (provided alongside this README) and press enter. It
   recreates every project file and runs `npm install` — no file upload
   required.
4. Copy the example env file and fill in your real keys:
   ```
   cp .env.local.example .env.local
   ```
   Open `.env.local` in the editor and fill in:
   - **Firebase**: Firebase Console → Project settings → your web app's config
   - **NEXT_PUBLIC_FIRESTORE_DB_ID**: `default` (matches the existing project)
   - **NEXT_PUBLIC_FAMILY_ID**: `toon-family` (same family data as before)
   - **ANTHROPIC_API_KEY**: from console.anthropic.com (separate from claude.ai)
   - **NEXT_PUBLIC_LIFF_ID**: leave blank for now — only needed once you wrap
     this in a LINE LIFF app; the site works in a normal browser without it
5. Run it:
   ```
   npm run dev
   ```
   Codespaces will prompt to open a forwarded port in the browser — that's
   your live app, viewable and testable straight from your phone.
6. When ready to publish, push this repo to GitHub (Codespaces has a Source
   Control tab with buttons for this, no command line needed) and connect it
   on [vercel.com](https://vercel.com) → New Project → import the repo. Add
   the same environment variables in Vercel's project settings.

## Firestore security rules

Same rule as before — data lives under a shared family path:

```
match /databases/default/documents {
  match /families/toon-family/{document=**} {
    allow read, write: if request.auth != null;
  }
}
```

## Project structure

```
app/
  page.js              Dashboard — child card, growth snapshot, AI summary
  timeline/page.js      Unified activity log + quick-add form
  calendar/page.js      Appointments (doctor/vaccine/events)
  settings/page.js      Child profile + sign out
  api/ai-summary/route.js   Server-side, single-call Claude request
lib/
  firebase.js          Auth + Firestore init (popup-first sign-in,
                        named "default" database — both lessons learned
                        from the previous version's bugs)
  family.js             Firestore read/write helpers, live subscriptions
  liff.js               LINE LIFF init, safe no-op outside the LINE app
components/
  BottomNav.js
```

## What's different from the old version (and why)

- **Multiple files instead of one HTML file** — a bug in the sleep form
  can't silently break the vaccine form anymore.
- **Firebase JS SDK instead of hand-rolled Firestore REST calls** — removes
  the whole class of bugs from manually building query URLs.
- **Live `onSnapshot` subscriptions** — every family member's screen updates
  automatically; no manual refresh, no stale data.
- **Popup-first Google sign-in** with redirect only as an explicit fallback —
  this is what caused the login loop in the PWA before.
