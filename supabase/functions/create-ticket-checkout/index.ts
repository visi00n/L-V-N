import { createClient } from "jsr:@supabase/supabase-js@2";
import Stripe from "npm:stripe@17.7.0";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { requireEnv } from "../_shared/env.ts";

type CheckoutRequest = {
  eventId?: string;
  quantity?: number;
  successUrl?: string;
  cancelUrl?: string;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const supabaseUrl = requireEnv("SUPABASE_URL");
    const supabaseAnonKey = requireEnv("SUPABASE_ANON_KEY");
    const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
    const stripeSecretKey = requireEnv("STRIPE_SECRET_KEY");
    const appUrl = Deno.env.get("LIVIN_APP_URL") ?? "livin://payments";
    const webUrl = Deno.env.get("LIVIN_WEB_URL") ?? "https://example.com";

    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const admin = createClient(supabaseUrl, serviceRoleKey);

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return jsonResponse({ error: "You must be signed in to buy a ticket." }, 401);
    }

    const body = (await req.json()) as CheckoutRequest;
    const quantity = Math.max(1, Math.min(body.quantity ?? 1, 10));

    if (!body.eventId) {
      return jsonResponse({ error: "eventId is required." }, 400);
    }

    const { data: event, error: eventError } = await admin
      .from("events")
      .select("id, host_id, title, starts_at, is_paid, ticket_price_cents")
      .eq("id", body.eventId)
      .single();

    if (eventError || !event) {
      return jsonResponse({ error: "Event not found." }, 404);
    }

    if (!event.is_paid || !event.ticket_price_cents) {
      return jsonResponse({ error: "This event is free." }, 409);
    }

    const { data: organizerAccount, error: accountError } = await admin
      .from("stripe_connect_accounts")
      .select("stripe_account_id, charges_enabled")
      .eq("user_id", event.host_id)
      .single();

    if (accountError || !organizerAccount?.stripe_account_id || !organizerAccount.charges_enabled) {
      return jsonResponse({ error: "Organizer payments are not ready yet." }, 409);
    }

    const stripe = new Stripe(stripeSecretKey);

    const unitAmount = event.ticket_price_cents;
    const amountTotal = unitAmount * quantity;
    const platformFee = Math.round(amountTotal * 0.1);

    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      client_reference_id: userData.user.id,
      customer_email: userData.user.email ?? undefined,
      line_items: [
        {
          quantity,
          price_data: {
            currency: "usd",
            unit_amount: unitAmount,
            product_data: {
              name: event.title,
            },
          },
        },
      ],
      payment_intent_data: {
        application_fee_amount: platformFee,
        transfer_data: {
          destination: organizerAccount.stripe_account_id,
        },
      },
      metadata: {
        event_id: event.id,
        buyer_id: userData.user.id,
        quantity: String(quantity),
      },
      success_url: body.successUrl ?? `${appUrl}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: body.cancelUrl ?? `${webUrl}/tickets/cancelled`,
    });

    const { error: orderError } = await admin.from("ticket_orders").insert({
      event_id: event.id,
      buyer_id: userData.user.id,
      stripe_checkout_session_id: session.id,
      amount_cents: amountTotal,
      platform_fee_cents: platformFee,
      status: "pending",
    });

    if (orderError) {
      return jsonResponse({ error: "Checkout created, but order storage failed." }, 500);
    }

    return jsonResponse({ checkoutSessionId: session.id, url: session.url });
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : "Unknown error" }, 500);
  }
});
