import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Origin": "*",
  "Content-Type": "application/json",
};

const publicErrorCodes = new Set([
  "app_user_disabled",
  "auth_user_not_found",
  "current_membership_immutable",
  "invalid_invitation_input",
  "invalid_live_session",
  "invitation_already_exists",
  "invitation_email_mismatch",
  "invitation_expired",
  "invitation_not_approved",
  "invitation_not_available",
  "invitation_not_found",
  "invitation_not_revocable",
  "member_not_onboarding",
  "membership_not_found",
  "organization_manager_required",
  "organization_not_available",
  "organization_owner_required",
  "onboarding_completion_required",
  "onboarding_expired",
  "onboarding_relogin_required",
  "onboarding_not_required",
  "provision_cleanup_required",
  "user_already_member_elsewhere",
]);

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

class ProvisioningError extends Error {
  readonly code: string;

  constructor(code: string) {
    super(code);
    this.name = "ProvisioningError";
    this.code = code;
  }
}

type JsonObject = Record<string, unknown>;

type Actor = {
  authUserId: string;
  sessionId: string;
  issuer: string;
  token: string;
};

function response(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    headers: corsHeaders,
    status,
  });
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new ProvisioningError("member_provisioning_unavailable");
  }
  return value;
}

function publishableKey(): string {
  const keyMap = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (keyMap) {
    try {
      const parsed = JSON.parse(keyMap) as JsonObject;
      const defaultKey = parsed.default;
      if (typeof defaultKey === "string") {
        const value = Deno.env.get(defaultKey)?.trim();
        if (value) return value;
      }
    } catch {
      // Fall through to the compatibility environment names.
    }
  }

  for (const name of ["SUPABASE_PUBLISHABLE_KEY", "SUPABASE_ANON_KEY"]) {
    const value = Deno.env.get(name)?.trim();
    if (value) return value;
  }
  throw new ProvisioningError("member_provisioning_unavailable");
}

function serviceKey(): string {
  for (const name of ["SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SECRET_KEY"]) {
    const value = Deno.env.get(name)?.trim();
    if (value) return value;
  }
  throw new ProvisioningError("member_provisioning_unavailable");
}

function decodeJwtPayload(token: string): JsonObject {
  const segment = token.split(".")[1];
  if (!segment) throw new ProvisioningError("invalid_live_session");

  try {
    const normalized = segment.replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
    const bytes = Uint8Array.from(atob(padded), (character) =>
      character.charCodeAt(0)
    );
    const parsed = JSON.parse(new TextDecoder().decode(bytes));
    if (!parsed || typeof parsed !== "object") {
      throw new Error("invalid payload");
    }
    return parsed as JsonObject;
  } catch {
    throw new ProvisioningError("invalid_live_session");
  }
}

function stringValue(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized ? normalized : null;
}

function requiredUuid(value: unknown, code = "invalid_invitation_input"): string {
  const normalized = stringValue(value);
  if (!normalized || !uuidPattern.test(normalized)) {
    throw new ProvisioningError(code);
  }
  return normalized;
}

function normalizedEmail(value: unknown): string {
  const email = stringValue(value)?.toLowerCase();
  if (!email || email.length > 320 || email.length < 3 || !email.includes("@")) {
    throw new ProvisioningError("invalid_invitation_input");
  }
  return email;
}

function normalizedRole(value: unknown): string {
  const role = stringValue(value)?.toLowerCase();
  if (!role || !["org_owner", "org_admin", "teacher"].includes(role)) {
    throw new ProvisioningError("invalid_invitation_input");
  }
  return role;
}

function errorCode(error: unknown, fallback: string): string {
  if (error instanceof ProvisioningError) return error.code;
  const message = error instanceof Error ? error.message.trim() : "";
  const firstLine = message.split("\n", 1)[0]?.trim() ?? "";
  return publicErrorCodes.has(firstLine) ? firstLine : fallback;
}

function asObject(value: unknown): JsonObject {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new ProvisioningError("member_provisioning_failed");
  }
  return value as JsonObject;
}

function withoutInviteCode(invitation: JsonObject): JsonObject {
  const copy = { ...invitation };
  delete copy.invite_code;
  return copy;
}

function generateTemporaryPassword(): string {
  const alphabet =
    "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%^&*";
  const output: string[] = [];
  const limit = Math.floor(256 / alphabet.length) * alphabet.length;

  while (output.length < 24) {
    const bytes = new Uint8Array(32);
    crypto.getRandomValues(bytes);
    for (const byte of bytes) {
      if (byte >= limit) continue;
      output.push(alphabet[byte % alphabet.length]);
      if (output.length === 24) break;
    }
  }

  return output.join("");
}

function extractActor(
  token: string,
  userId: string,
  payload: JsonObject
): Actor {
  const sessionId = stringValue(payload.session_id);
  const issuer = stringValue(payload.iss);
  if (!sessionId || !uuidPattern.test(sessionId) || !issuer) {
    throw new ProvisioningError("invalid_live_session");
  }
  return { authUserId: userId, issuer, sessionId, token };
}

async function authenticate(
  url: string,
  key: string,
  request: Request
): Promise<{ actor: Actor; userClient: ReturnType<typeof createClient> }> {
  const header = request.headers.get("Authorization") ?? "";
  if (!header.toLowerCase().startsWith("bearer ")) {
    throw new ProvisioningError("invalid_live_session");
  }
  const token = header.slice(7).trim();
  if (!token) throw new ProvisioningError("invalid_live_session");

  const payload = decodeJwtPayload(token);
  const userClient = createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data, error } = await userClient.auth.getUser(token);
  if (error || !data.user) {
    throw new ProvisioningError("invalid_live_session");
  }
  return { actor: extractActor(token, data.user.id, payload), userClient };
}

async function callUserRpc(
  userClient: ReturnType<typeof createClient>,
  name: string,
  params: JsonObject
): Promise<JsonObject> {
  const { data, error } = await userClient.rpc(name, params);
  if (error) {
    throw new ProvisioningError(errorCode(error, "member_provisioning_failed"));
  }
  return asObject(data);
}

async function callServiceRpc(
  adminClient: ReturnType<typeof createClient>,
  name: string,
  params: JsonObject
): Promise<JsonObject> {
  const { data, error } = await adminClient.rpc(name, params);
  if (error) {
    throw new ProvisioningError(errorCode(error, "member_provisioning_failed"));
  }
  return asObject(data);
}

async function findAuthUserByEmail(
  adminClient: ReturnType<typeof createClient>,
  email: string
): Promise<JsonObject | null> {
  for (let page = 1; page <= 100; page += 1) {
    const { data, error } = await adminClient.auth.admin.listUsers({
      page,
      perPage: 1000,
    });
    if (error) throw new ProvisioningError("member_provisioning_failed");

    const users = data?.users ?? [];
    const found = users.find(
      (user) => stringValue(user.email)?.toLowerCase() === email
    );
    if (found) return found as unknown as JsonObject;
    if (users.length < 1000) return null;
  }
  throw new ProvisioningError("member_provisioning_failed");
}

async function createAuthUser(
  adminClient: ReturnType<typeof createClient>,
  email: string,
  organizationId: string,
  invitationId: string
): Promise<{ user: JsonObject; temporaryPassword: string }> {
  const temporaryPassword = generateTemporaryPassword();
  const { data, error } = await adminClient.auth.admin.createUser({
    email,
    email_confirm: true,
    password: temporaryPassword,
    user_metadata: {
      xueqing_invitation_id: invitationId,
      xueqing_organization_id: organizationId,
      xueqing_provisioning: true,
    },
  });
  if (error || !data.user) {
    throw new ProvisioningError("member_provisioning_failed");
  }
  return {
    temporaryPassword,
    user: data.user as unknown as JsonObject,
  };
}

async function provisionInvitation(
  actor: Actor,
  userClient: ReturnType<typeof createClient>,
  adminClient: ReturnType<typeof createClient>,
  invitation: JsonObject,
  displayName: string | null
): Promise<JsonObject> {
  const invitationId = requiredUuid(invitation.id, "invitation_not_found");
  const organizationId = requiredUuid(
    invitation.organization_id,
    "organization_not_available"
  );
  const email = normalizedEmail(invitation.email);
  const status = stringValue(invitation.status);

  if (status === "pending_owner_approval") {
    return {
      ok: true,
      mode: "owner_approval",
      invitation: withoutInviteCode(invitation),
    };
  }
  if (status !== "pending") {
    throw new ProvisioningError("invitation_not_available");
  }

  const existingUser = await findAuthUserByEmail(adminClient, email);
  if (existingUser) {
    return {
      ok: true,
      mode: "invite_code",
      invitation,
    };
  }

  const created = await createAuthUser(
    adminClient,
    email,
    organizationId,
    invitationId
  );
  try {
    const businessResult = await callServiceRpc(
      adminClient,
      "provision_organization_member_from_auth",
      {
        p_actor_auth_user_id: actor.authUserId,
        p_actor_issuer: actor.issuer,
        p_actor_session_id: actor.sessionId,
        p_display_name: displayName,
        p_invitation_id: invitationId,
        p_target_auth_user_id: requiredUuid(
          created.user.id,
          "member_provisioning_failed"
        ),
      }
    );
    return {
      email,
      expires_at: businessResult.onboarding_expires_at,
      membership_id: businessResult.membership_id,
      mode: "temporary_password",
      ok: true,
      organization_id: organizationId,
      role: invitation.role,
      status: "onboarding",
      temporary_password: created.temporaryPassword,
    };
  } catch (error) {
    const { error: cleanupError } = await adminClient.auth.admin.deleteUser(
      requiredUuid(created.user.id, "member_provisioning_failed")
    );
    if (cleanupError) {
      // Do not log the email or password. The marker metadata on the Auth
      // user allows an operator to identify this orphan in the dashboard.
      console.error("member provisioning cleanup failed");
      throw new ProvisioningError("provision_cleanup_required");
    }
    try {
      await callUserRpc(userClient, "revoke_organization_invitation", {
        p_invitation_id: invitationId,
      });
    } catch {
      // The pending invitation is still recoverable through the management
      // screen's “provision existing invitation” action.
    }
    throw error;
  }
}

async function provisionFromExistingInvitation(
  actor: Actor,
  userClient: ReturnType<typeof createClient>,
  adminClient: ReturnType<typeof createClient>,
  invitationId: string,
  displayName: string | null
): Promise<JsonObject> {
  const invitation = await callUserRpc(
    userClient,
    "reissue_organization_invitation",
    { p_invitation_id: invitationId }
  );
  return provisionInvitation(
    actor,
    userClient,
    adminClient,
    invitation,
    displayName
  );
}

async function reissueMemberCredential(
  actor: Actor,
  adminClient: ReturnType<typeof createClient>,
  organizationId: string,
  membershipId: string
): Promise<JsonObject> {
  const prepared = await callServiceRpc(
    adminClient,
    "prepare_member_credential_reissue",
    {
      p_actor_auth_user_id: actor.authUserId,
      p_actor_session_id: actor.sessionId,
      p_membership_id: membershipId,
      p_organization_id: organizationId,
    }
  );
  const temporaryPassword = generateTemporaryPassword();
  const targetAuthUserId = requiredUuid(
    prepared.target_auth_user_id,
    "auth_user_not_found"
  );
  const { error } = await adminClient.auth.admin.updateUserById(
    targetAuthUserId,
    { password: temporaryPassword }
  );
  if (error) throw new ProvisioningError("credential_update_failed");

  await callServiceRpc(adminClient, "revoke_member_auth_sessions", {
    p_target_auth_user_id: targetAuthUserId,
  });

  return {
    email: prepared.email,
    expires_at: prepared.onboarding_expires_at,
    membership_id: prepared.membership_id,
    mode: "temporary_password",
    ok: true,
    organization_id: prepared.organization_id,
    status: "onboarding",
    temporary_password: temporaryPassword,
  };
}

async function handle(request: Request): Promise<Response> {
  if (request.method === "OPTIONS") return response({ ok: true });
  if (request.method !== "POST") return response({ ok: false, error: "method_not_allowed" }, 405);

  const url = requiredEnvironment("SUPABASE_URL");
  const { actor, userClient } = await authenticate(url, publishableKey(), request);
  const adminClient = createClient(url, serviceKey(), {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let input: JsonObject;
  try {
    input = asObject(await request.json());
  } catch {
    throw new ProvisioningError("invalid_invitation_input");
  }

  const action = stringValue(input.action);
  if (action === "provision") {
    const organizationId = requiredUuid(input.organization_id, "organization_not_available");
    const email = normalizedEmail(input.email);
    const role = normalizedRole(input.role);
    const invitation = await callUserRpc(
      userClient,
      "create_organization_invitation",
      {
        p_email: email,
        p_organization_id: organizationId,
        p_role: role,
      }
    );
    return response(
      await provisionInvitation(
        actor,
        userClient,
        adminClient,
        invitation,
        stringValue(input.display_name)
      )
    );
  }

  if (action === "provision_existing_invitation") {
    const invitationId = requiredUuid(input.invitation_id, "invitation_not_found");
    return response(
      await provisionFromExistingInvitation(
        actor,
        userClient,
        adminClient,
        invitationId,
        stringValue(input.display_name)
      )
    );
  }

  if (action === "reissue_member_credential") {
    const organizationId = requiredUuid(input.organization_id, "organization_not_available");
    const membershipId = requiredUuid(input.membership_id, "membership_not_found");
    return response(
      await reissueMemberCredential(
        actor,
        adminClient,
        organizationId,
        membershipId
      )
    );
  }

  throw new ProvisioningError("invalid_invitation_input");
}

Deno.serve(async (request) => {
  try {
    return await handle(request);
  } catch (error) {
    const code = errorCode(error, "member_provisioning_failed");
    return response({ error: code, ok: false });
  }
});
