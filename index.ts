import { createClient } from "npm:@supabase/supabase-js@2";

// Public browser calls carry a user JWT, never the service-role key.
// Authentication is checked below even when gateway JWT verification is disabled.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS")
    return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return reply(405, { error: "Use POST." });

  const authorization = request.headers.get("Authorization");
  const match = authorization?.match(/^Bearer\s+(.+)$/i);
  if (!match)
    return reply(401, { error: "Log in before deleting your account." });

  const url = Deno.env.get("SUPABASE_URL");
  const serverKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serverKey)
    return reply(500, { error: "Account deletion is not configured yet." });

  const admin = createClient(url, serverKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // This makes an Auth server request: do not trust a client-supplied ID or decoded JWT.
  const { data: identity, error: identityError } = await admin.auth.getUser(
    match[1],
  );
  if (identityError || !identity.user) {
    return reply(401, {
      error: "Your session expired. Log in again to delete your account.",
    });
  }
  const userId = identity.user.id;

  let body: { confirmation?: string; userId?: unknown };
  try {
    body = await request.json();
  } catch {
    return reply(400, { error: "Invalid request." });
  }
  if (body.confirmation !== "DELETE_MY_ACCOUNT") {
    return reply(400, { error: "Confirm account deletion in the app first." });
  }
  // A supplied user ID is deliberately never used; only the verified caller is targeted.

  const { data: ready, error: setupError } = await admin.rpc(
    "scheduler_delete_preflight",
  );
  if (setupError || ready !== true) {
    return reply(503, {
      error:
        "Account deletion is not set up yet. Ask your project administrator to run scheduler-setup.sql.",
    });
  }

  let stage = "pictures";
  try {
    const pictures = admin.storage.from("profile-pictures");
    // New uploads are flat files in this UUID folder. Delete every batch, including
    // old uploads whose previous cleanup failed. No other user's folder is read.
    for (let batch = 0; ; batch++) {
      if (batch >= 100)
        throw new Error("Too many picture batches for one request.");
      const { data: files, error: listError } = await pictures.list(userId, {
        limit: 100,
        offset: 0,
        sortBy: { column: "name", order: "asc" },
      });
      if (listError) throw listError;
      if (!files?.length) break;
      if (files.some((file) => !file.id || file.name.includes("/"))) {
        throw new Error("Unexpected nested folder in picture storage.");
      }
      const { error: removeError } = await pictures.remove(
        files.map((file) => `${userId}/${file.name}`),
      );
      if (removeError) throw removeError;
    }

    stage = "account";
    // Hard deletion: the BEFORE DELETE trigger removes app rows in the same DB
    // transaction. A DB constraint/trigger failure rolls back those row deletions.
    const { error: deleteError } = await admin.auth.admin.deleteUser(
      userId,
      false,
    );
    if (deleteError) throw deleteError;
    return reply(200, { deleted: true });
  } catch {
    // Do not report success when anything fails. Picture removal cannot be rolled
    // back with the DB transaction, so explain that a retry may still be needed.
    return reply(500, {
      error:
        stage === "pictures"
          ? "Could not finish removing your pictures. Your account has not been deleted. Some pictures may already be removed; please try again."
          : "Could not finish deleting your account. Your profile picture may already be removed. Please try again or ask your project administrator to check database links.",
    });
  }
});
