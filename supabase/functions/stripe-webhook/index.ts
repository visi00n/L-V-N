import { createClient } from "jsr:@supabase/supabase-js@2";
import Stripe from "npm:stripe@17.7.0";
import { jsonResponse } from "../_shared/cors.ts";
import { requireEnv } from "../_shared/env.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const stripe = new Stripe(requireEnv("STRIPE_SECRET_KEY"));
    const signature = req.headers.get("stripe-signature");

    if (!signature) {
      return jsonResponse({ error: "Missing Stripe signature." }, 400);
    }

    const rawBody = await req.text();
    const event = await stripe.webhooks.constructEventAsync(
      rawBody,
      signature,
      requireEnv("STRIPE_WEBHOOK_SECRET"),
    );

    const admin = createClient(
      requireEnv("SUPABASE_URL"),
      requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    );

    if (event.type === "checkout.session.completed") {
      const session = event.data.object as Stripe.Checkout.Session;

      await admin
        .from("ticket_orders")
        .update({
          status: "paid",
          stripe_payment_intent_id:
            typeof session.payment_intent === "string" ? session.payment_intent : session.payment_intent?.id,
        })
        .eq("stripe_checkout_session_id", session.id);

      if (session.metadata?.event_id && session.metadata?.buyer_id) {
        await admin.from("event_members").upsert({
          event_id: session.metadata.event_id,
          user_id: session.metadata.buyer_id,
          role: "member",
        });
      }
    }

    if (event.type === "checkout.session.expired") {
      const session = event.data.object as Stripe.Checkout.Session;

      await admin
        .from("ticket_orders")
        .update({ status: "expired" })
        .eq("stripe_checkout_session_id", session.id);
    }

    return jsonResponse({ received: true });
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : "Unknown error" }, 400);
  }
});
