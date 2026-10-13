# Layover Ledger — Google sign-in + online Supabase setup

This is a version of Layover Ledger that runs as its own website instead of
inside Claude: it stores your trips in a real online database (Supabase)
and signs you in with your actual Google account. There are three things
to set up before it works: the database, Google sign-in, and hosting.

Everything below is free — reusing one of your existing Supabase projects,
a Google Cloud OAuth client, and either Netlify or Firebase Hosting on
their free tiers.

## 1. Set up the database (Supabase)

You already have two Supabase projects, so reuse one of those rather than
creating a third.

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard) and open
   whichever of your two projects you want this app to use.
2. In the left sidebar, open **SQL Editor** → **New query**.
3. Open the `schema.sql` file included with this app, paste its entire
   contents into the editor, and click **Run**. This creates four tables
   (`trips`, `expenses`, `cards`, `bookings`) and locks each row to the
   account that created it, so no one else can ever see your data — even
   though the database is shared infrastructure.
4. In the left sidebar, open **Project Settings** → **API**. You'll need
   two values from this page in a minute:
   - **Project URL** (looks like `https://xxxxxxxx.supabase.co`)
   - **anon / public** key (a long string — this one is safe to put in
     client-side code; it can't do anything your Row Level Security
     policies from `schema.sql` don't allow)

Keep this tab open — you'll come back to enable Google sign-in in step 3.

## 2. Create a Google OAuth client

Real "Sign in with Google" requires a Google Cloud project with an OAuth
client. This is separate from — but works well alongside — Firebase
Hosting if you choose that option in step 4, since Firebase projects are
Google Cloud projects.

1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. If you don't already have a project you want to use, create one (top
   dropdown → **New Project**). Free, no billing required for this.
3. Go to **APIs & Services → OAuth consent screen**. Choose **External**,
   fill in the required fields (app name, your email), and save. You can
   leave it in "Testing" mode with yourself as a test user, or publish it —
   either works for personal use.
4. Go to **APIs & Services → Credentials → Create Credentials → OAuth
   client ID**.
   - Application type: **Web application**
   - Name: anything, e.g. "Layover Ledger"
   - Under **Authorized redirect URIs**, add your Supabase callback URL.
     It's your Project URL from step 1 with `/auth/v1/callback` appended,
     e.g.: `https://xxxxxxxx.supabase.co/auth/v1/callback`
   - Click **Create**. Copy the **Client ID** and **Client Secret** shown.

## 3. Turn on Google sign-in in Supabase

1. Back in your Supabase project, go to **Authentication → Providers**.
2. Find **Google** in the list and enable it.
3. Paste in the **Client ID** and **Client Secret** from step 2.
4. Save.

That's the entire backend. Supabase now handles the OAuth handshake with
Google directly — this app never sees your Google password, only a signed
session token back from Supabase.

## 4. Fill in your keys and deploy the app

Open `index.html` in a text editor and find these two lines near the top
of the `<script>` section:

```js
var SUPABASE_URL = "YOUR_SUPABASE_PROJECT_URL";
var SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";
```

Replace the placeholder strings with the **Project URL** and **anon key**
from step 1. Save the file.

Now put it online. Keep **all** of these files together in one folder
when you deploy — `index.html` is the app itself, but `manifest.json`,
`sw.js`, and the `icons/` folder are what let it be installed as an app
(see the section below). Hosting choice doesn't change anything about the
code — pick whichever is more convenient:

### Option A — Netlify (drag-and-drop, easiest)

1. Go to [app.netlify.com/drop](https://app.netlify.com/drop).
2. Drag the whole folder (containing `index.html`, `manifest.json`,
   `sw.js`, and `icons/`) onto the page.
3. Netlify gives you a live URL (like `random-name-123.netlify.app`)
   within seconds. You can rename it or add a custom domain later, free.

### Option B — Firebase Hosting (if you'd rather stay inside Google Cloud)

Since you already made a Google Cloud project in step 2, this reuses it:

1. Install the Firebase CLI once: `npm install -g firebase-tools`
2. `firebase login`
3. In the folder containing `index.html`, run `firebase init hosting` and
   choose the Google Cloud project from step 2 when prompted. Set the
   public directory to the folder your `index.html` is in, and answer "No"
   to configuring it as a single-page app (it's a single plain HTML file).
4. `firebase deploy`
5. Firebase prints a live URL like `your-project.web.app`.

### One important step after you have a URL, either way

Go back to Google Cloud Console → **Credentials** → your OAuth client, and
add your live site's URL to **Authorized JavaScript origins** (e.g.
`https://your-project.web.app` or `https://your-site.netlify.app`). Google
will reject the sign-in popup from an origin it doesn't recognize.

**Note:** both Google sign-in and "Install as an app" (below) only work
once the site is actually deployed and opened over `https://` (or
`http://localhost` while testing). Opening `index.html` straight from your
computer's file browser won't work for either — that's the most common
reason "nothing happens" when you click a button.

## Installing it as an app

Once it's deployed, `manifest.json`, `sw.js`, and the icons make the site
installable, so it behaves like a regular app instead of a browser tab:

- **On a phone (Android/Chrome):** open the site, then use the browser
  menu → "Install app" or "Add to Home Screen." It gets its own icon and
  opens full-screen, no address bar.
- **On an iPhone (Safari):** open the site, tap the Share icon, then "Add
  to Home Screen."
- **On desktop (Chrome/Edge):** an install icon appears in the address
  bar; click it, or use the browser menu → "Install Layover Ledger."

It also keeps working offline for the parts already loaded (the app
shell), thanks to the included service worker — though you'll still need
a connection to sign in or sync new data with Supabase.

## Bookings: hotels, flights, cruises, attractions

Each trip now has a **Bookings** section (above the spending breakdown) for
the reservations themselves, separate from what they cost: tap **+ Add**,
pick a type (Hotel / Flight / Cruise / Attraction), and save a name,
confirmation number, dates, and — optionally — the date free cancellation
ends. A booking within 3 days of its cancellation deadline is flagged in
red so it doesn't sneak past you.

Flights get one more thing: a **live status check**. Save the flight
number (e.g. `TP123`) and the app will automatically check it once a day
starting two days before departure (and you can tap "Refresh" any time),
showing scheduled/active/landed/delayed/cancelled status right on the
trip page. This needs the one-time setup below — until you do it, flight
bookings still save everything else fine, but "Check status" will just
say live status isn't set up yet.

## 5. Set up live flight status (optional)

This step is separate from everything above — skip it if you don't need
live flight status, and come back to it later any time.

Real-time flight data comes from [Aviationstack](https://aviationstack.com/),
which has a free plan (100 requests/month, plenty for checking your own
flights around your travel dates). The lookup runs in a small Supabase
Edge Function rather than directly from the page, so your Aviationstack
key stays a secret on the server instead of being visible to anyone who
views your site's source.

1. Sign up free at [aviationstack.com](https://aviationstack.com/) and
   copy your **API access key** from their dashboard.
2. Install the Supabase CLI once: `npm install -g supabase`
3. `supabase login`
4. In your project folder, run `supabase link --project-ref your-project-ref`
   (find your project ref in Supabase → Project Settings → General).
5. Make sure the `supabase/functions/flight-status/index.ts` file included
   with this app is at that same path in your project folder.
6. Set your key as a secret (never put it in `index.html`):
   `supabase secrets set AVIATIONSTACK_KEY=your_key_here`
7. Deploy it: `supabase functions deploy flight-status`

That's it — no changes needed in `index.html`, it already knows how to
call this function once it's deployed.

## What's different from the Claude Artifact version

- **Sign-in is real now.** It's your actual Google account via Supabase
  Auth, not a name-and-password stored only on one device. Your trips
  follow you to any browser or device where you sign in with the same
  Google account.
- **The database is real and online**, not `localStorage` — Supabase
  Postgres, scoped to your account by the Row Level Security policies in
  `schema.sql`.
- **The "Ask" AI feature isn't in this version.** It relied on a
  Claude-Artifact-only capability that has no equivalent on a plain
  website — there's no way to port it without adding a server-side
  component (e.g., a Supabase Edge Function that calls an AI API with a
  secret key kept server-side, never in this file). Say the word if you'd
  like that built out later — it's a separate, larger piece of work.
- **It can be installed as an app** now (see above) — the Claude Artifact
  version can't offer that, since it only runs inside Claude.
- **Bookings (hotel/flight/cruise/attraction) with live flight status**
  (see above) are new in this version — not in the Claude Artifact, since
  live flight data needs a real outbound network call and a place to keep
  an API key secret, neither of which a sandboxed Artifact can do.
- Everything else — trip notes, country flags, currency conversion,
  categories including Cruise, light/dark theme — works the same as the
  Claude Artifact version.
