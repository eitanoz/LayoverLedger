// Supabase Edge Function: flight-status
//
// Looks up a flight's current status (scheduled / active / landed /
// cancelled / diverted, plus any delay) from Aviationstack and returns a
// small, simplified JSON payload to the app. This runs server-side so the
// Aviationstack API key stays a secret (set with `supabase secrets set`)
// instead of being embedded in index.html, and so the app doesn't need to
// deal with any CORS/API quirks itself.
//
// Deploy with the Supabase CLI from your project folder:
//   supabase functions deploy flight-status
//   supabase secrets set AVIATIONSTACK_KEY=your_key_here
//
// See SETUP.md for the full walkthrough (getting a free Aviationstack key,
// installing the CLI, linking your project, deploying).

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const AVIATIONSTACK_KEY = Deno.env.get("AVIATIONSTACK_KEY");

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (!AVIATIONSTACK_KEY) {
    return json({ error: "AVIATIONSTACK_KEY is not configured on the server (supabase secrets set AVIATIONSTACK_KEY=...)" }, 500);
  }

  let flightIata = "";
  try {
    const body = await req.json();
    flightIata = String(body?.flight_iata || "").trim().toUpperCase();
  } catch (_e) {
    return json({ error: "Expected a JSON body like { flight_iata: \"TP123\" }" }, 400);
  }

  if (!flightIata) {
    return json({ error: "flight_iata is required" }, 400);
  }

  try {
    const url = "https://api.aviationstack.com/v1/flights?access_key=" +
      encodeURIComponent(AVIATIONSTACK_KEY) + "&flight_iata=" + encodeURIComponent(flightIata);
    const res = await fetch(url);
    const body = await res.json();

    if (body?.error) {
      return json({ error: body.error.message || "Flight lookup failed" }, 502);
    }

    const flight = (body?.data || [])[0];
    if (!flight) {
      return json({ error: "No live data for " + flightIata + " yet -- try again closer to the travel date" }, 404);
    }

    return json({
      status: flight.flight_status || "unknown",
      departure: {
        airport: flight.departure?.iata || null,
        scheduled: flight.departure?.scheduled || null,
        estimated: flight.departure?.estimated || null,
        delayMinutes: flight.departure?.delay || 0,
      },
      arrival: {
        airport: flight.arrival?.iata || null,
        scheduled: flight.arrival?.scheduled || null,
        estimated: flight.arrival?.estimated || null,
        delayMinutes: flight.arrival?.delay || 0,
      },
    });
  } catch (e) {
    return json({ error: "Flight lookup failed: " + String(e) }, 500);
  }
});
