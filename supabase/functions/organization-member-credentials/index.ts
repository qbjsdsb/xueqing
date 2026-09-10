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
  "credential_update_failed",
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
  "member_provisioning_failed",
  "member_provisioning_unavailable",
  "membership_not_found",
  "organization_manager_required",
  "organization_not_available",
  "organization_owner_required",
  "onboarding_completion_required",
  "onboarding_expired",
  "onboarding_relogin_required",
  "onboarding_not_required",
  "provision_cleanup_required",
  "provision_recovery_required",
  "role_not_allowed",
  "user_already_member_elsewhere",
]);

// Auth/session IDs are UUIDs, but deterministic fictional fixtures may use version-0 UUID-shaped ids.
// Authorization is database-backed, so validate canonical UUID shape without depending on version bits.
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

class ProvisioningError extends Error {
  readonly code: string;

  constructor(code: string) {
    super(code);
    this.name = "ProvisioningError";
    this.code = code;
  }
}

type JsonObject = Record<string, unknown>;

const inferDatabaseClient = () => createClient('', '');
type DatabaseClient = ReturnType<typeof inferDatabaseClient>;

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

function mappedKey(environmentName: string): string | null {
  const raw = Deno.env.get(environmentName)?.trim();
  if (!raw) return null;

  try {
    const parsed = JSON.parse(raw) as JsonObject;
    const defaultKey = stringValue(parsed.default);
    if (!defaultKey) return null;

    // Hosted Supabase projects currently expose the actual sb_* key in the
    // JSON map. Older/local setups may instead put an environment variable
    // name there, so support both without ever returning the variable name as
    // if it were a credential.
    if (defaultKey.startsWith("sb_")) return defaultKey;
    return Deno.env.get(defaultKey)?.trim() ?? null;
  } catch {
    return null;
  }
}

function publishableKey(): string {
  const mapped = mappedKey("SUPABASE_PUBLISHABLE_KEYS");
  if (mapped) return mapped;

  for (const name of ["SUPABASE_PUBLISHABLE_KEY", "SUPABASE_ANON_KEY"]) {
    const value = Deno.env.get(name)?.trim();
    if (value) return value;
  }
  throw new ProvisioningError("member_provisioning_unavailable");
}

function serviceKey(): string {
  const mapped = mappedKey("SUPABASE_SECRET_KEYS");
  if (mapped) return mapped;

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

  let message = "";
  if (error instanceof Error) {
    message = error.message.trim();
  } else if (error && typeof error === "object") {
    const candidate = error as Record<string, unknown>;
    message = [candidate.message, candidate.details, candidate.hint, candidate.code]
      .filter((value): value is string => typeof value === "string")
      .map((value) => value.trim())
      .filter(Boolean)
      .join("\n");
  } else if (typeof error === "string") {
    message = error.trim();
  }

  const firstLine = message.split("\n", 1)[0]?.trim() ?? "";
  if (publicErrorCodes.has(firstLine)) return firstLine;
  for (const code of publicErrorCodes) {
    if (message.includes(code)) return code;
  }
  return fallback;
}

function asObject(value: unknown): JsonObject {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new ProvisioningError("member_provisioning_failed");
  }
  return value as JsonObject;
}

function objectValue(value: unknown): JsonObject | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
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
): Promise<{ actor: Actor; userClient: DatabaseClient }> {
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
  userClient: DatabaseClient,
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
  adminClient: DatabaseClient,
  name: string,
  params: JsonObject
): Promise<JsonObject> {
  const { data, error } = await adminClient.rpc(name, params);
  if (error) {
    throw new ProvisioningError(errorCode(error, "member_provisioning_failed"));
  }
  return asObject(data);
}

async function waitMilliseconds(milliseconds: number): Promise<void> {
  await new Promise<void>((resolve) => setTimeout(resolve, milliseconds));
}

type CommittedProvisioning = {
  email: string;
  expiresAt: unknown;
  membershipId: string;
  organizationId: string;
  role: string;
  status: string;
};

async function readCommittedProvisioning(
  adminClient: DatabaseClient,
  invitationId: string,
  organizationId: string,
  email: string,
  role: string,
  targetAuthUserId: string
): Promise<CommittedProvisioning | null> {
  const { data: invitation, error: invitationError } = await adminClient
    .from("organization_invitations")
    .select("id, organization_id, email, role, status, accepted_by_app_user_id")
    .eq("id", invitationId)
    .maybeSingle();
  if (invitationError) {
    throw new ProvisioningError("provision_cleanup_required");
  }

  const invitationObject = objectValue(invitation);
  if (
    !invitationObject ||
    stringValue(invitationObject.id) !== invitationId ||
    stringValue(invitationObject.organization_id) !== organizationId ||
    stringValue(invitationObject.email) !== email ||
    stringValue(invitationObject.role) !== role ||
    stringValue(invitationObject.status) !== "accepted"
  ) {
    return null;
  }

  const acceptedAppUserId = stringValue(
    invitationObject.accepted_by_app_user_id
  );
  if (!acceptedAppUserId) return null;

  const { data: appUser, error: appUserError } = await adminClient
    .from("app_users")
    .select("id, auth_provider, auth_subject_id, status")
    .eq("id", acceptedAppUserId)
    .maybeSingle();
  if (appUserError) {
    throw new ProvisioningError("provision_cleanup_required");
  }
  const appUserObject = objectValue(appUser);
  if (
    !appUserObject ||
    stringValue(appUserObject.auth_provider) !== "supabase" ||
    stringValue(appUserObject.auth_subject_id) !== targetAuthUserId ||
    stringValue(appUserObject.status) !== "active"
  ) {
    return null;
  }

  const { data: membership, error: membershipError } = await adminClient
    .from("organization_memberships")
    .select(
      "id, organization_id, app_user_id, status, onboarding_expires_at"
    )
    .eq("organization_id", organizationId)
    .eq("app_user_id", acceptedAppUserId)
    .eq("status", "onboarding")
    .limit(1)
    .maybeSingle();
  if (membershipError) {
    throw new ProvisioningError("provision_cleanup_required");
  }
  const membershipObject = objectValue(membership);
  const membershipId = stringValue(membershipObject?.id);
  if (!membershipObject || !membershipId) return null;

  const { data: membershipRole, error: membershipRoleError } =
    await adminClient
      .from("membership_roles")
      .select("role")
      .eq("organization_id", organizationId)
      .eq("membership_id", membershipId)
      .eq("role", role)
      .maybeSingle();
  if (membershipRoleError) {
    throw new ProvisioningError("provision_cleanup_required");
  }
  if (!objectValue(membershipRole)) return null;

  return {
    email,
    expiresAt: membershipObject.onboarding_expires_at,
    membershipId,
    organizationId,
    role,
    status: "onboarding",
  };
}

async function reconcileCommittedProvisioning(
  adminClient: DatabaseClient,
  invitationId: string,
  organizationId: string,
  email: string,
  role: string,
  targetAuthUserId: string
): Promise<CommittedProvisioning | null> {
  // A successful Postgres transaction can finish just after a transport
  // failure reaches the Edge Function. Give the commit a short, bounded
  // window to become visible before reporting recovery is required.
  for (const delay of [0, 100, 300, 700]) {
    if (delay > 0) await waitMilliseconds(delay);
    try {
      const committed = await readCommittedProvisioning(
        adminClient,
        invitationId,
        organizationId,
        email,
        role,
        targetAuthUserId
      );
      if (committed) return committed;
    } catch (error) {
      if (
        error instanceof ProvisioningError &&
        error.code === "provision_cleanup_required"
      ) {
        // A service-role read failure makes the transaction outcome unknown;
        // never delete an Auth user while that uncertainty remains.
        continue;
      }
      throw error;
    }
  }
  return null;
}

function provisioningMetadata(user: JsonObject): JsonObject | null {
  // app_metadata is written through the Auth Admin API and is not editable
  // by the account holder. Never use user_metadata as recovery evidence: the
  // signed-in user can change it themselves.
  return objectValue(user.app_metadata);
}

function isMarkedProvisioningUser(
  user: JsonObject,
  organizationId: string,
  invitationId: string
): boolean {
  const metadata = provisioningMetadata(user);
  return (
    metadata?.xueqing_provisioning === true &&
    stringValue(metadata.xueqing_organization_id) === organizationId &&
    stringValue(metadata.xueqing_invitation_id) === invitationId
  );
}

async function findAuthUserByEmail(
  adminClient: DatabaseClient,
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
  adminClient: DatabaseClient,
  email: string,
  organizationId: string,
  invitationId: string
): Promise<{ user: JsonObject; temporaryPassword: string }> {
  const temporaryPassword = generateTemporaryPassword();
  const { data, error } = await adminClient.auth.admin.createUser({
    email,
    email_confirm: true,
    password: temporaryPassword,
    app_metadata: {
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

async function resetProvisioningAuthUser(
  adminClient: DatabaseClient,
  user: JsonObject,
  organizationId: string,
  invitationId: string
): Promise<{ temporaryPassword: string }> {
  const userId = requiredUuid(user.id, "member_provisioning_failed");
  const temporaryPassword = generateTemporaryPassword();
  const existingMetadata = provisioningMetadata(user) ?? {};
  const { data, error } = await adminClient.auth.admin.updateUserById(
    userId,
    {
      password: temporaryPassword,
      // Keep the recovery marker server-controlled. The member can edit
      // user_metadata, so it must never be used as provisioning evidence.
      app_metadata: {
        ...existingMetadata,
        xueqing_invitation_id: invitationId,
        xueqing_organization_id: organizationId,
        xueqing_provisioning: true,
      },
    }
  );
  if (error || !data.user) {
    throw new ProvisioningError("credential_update_failed");
  }
  return {
    temporaryPassword,
  };
}

async function provisionBusinessMember(
  actor: Actor,
  adminClient: DatabaseClient,
  invitationId: string,
  displayName: string | null,
  targetAuthUserId: string
): Promise<JsonObject> {
  return callServiceRpc(
    adminClient,
    "provision_organization_member_from_auth",
    {
      p_actor_auth_user_id: actor.authUserId,
      p_actor_issuer: actor.issuer,
      p_actor_session_id: actor.sessionId,
      p_display_name: displayName,
      p_invitation_id: invitationId,
      p_target_auth_user_id: targetAuthUserId,
    }
  );
}

function temporaryPasswordResult(
  invitation: JsonObject,
  businessResult: JsonObject | CommittedProvisioning,
  temporaryPassword: string | null
): JsonObject {
  const result: JsonObject = {
    email: stringValue(invitation.email) ?? businessResult.email,
    expires_at:
      "onboarding_expires_at" in businessResult
        ? businessResult.onboarding_expires_at
        : businessResult.expiresAt,
    membership_id:
      "membership_id" in businessResult
        ? businessResult.membership_id
        : businessResult.membershipId,
    mode: "temporary_password",
    ok: true,
    organization_id:
      stringValue(invitation.organization_id) ?? businessResult.organizationId,
    role: stringValue(invitation.role) ?? businessResult.role,
    status: businessResult.status ?? "onboarding",
  };
  if (temporaryPassword) result.temporary_password = temporaryPassword;
  return result;
}

async function recoverMarkedProvisioningUser(
  actor: Actor,
  adminClient: DatabaseClient,
  invitation: JsonObject,
  existingUser: JsonObject,
  displayName: string | null
): Promise<JsonObject> {
  const invitationId = requiredUuid(invitation.id, "invitation_not_found");
  const organizationId = requiredUuid(
    invitation.organization_id,
    "organization_not_available"
  );
  const email = normalizedEmail(invitation.email);
  const role = stringValue(invitation.role);
  if (!role) throw new ProvisioningError("invalid_invitation_input");
  const targetAuthUserId = requiredUuid(
    existingUser.id,
    "auth_user_not_found"
  );
  let businessResult: JsonObject | CommittedProvisioning;
  try {
    businessResult = await provisionBusinessMember(
      actor,
      adminClient,
      invitationId,
      displayName,
      targetAuthUserId
    );
  } catch (error) {
    const committed = await reconcileCommittedProvisioning(
      adminClient,
      invitationId,
      organizationId,
      email,
      role,
      targetAuthUserId
    );
    if (!committed) {
      // The Auth account and marker are intentionally retained. A later
      // “continue opening account” action can retry without changing a
      // credential for an account that the RPC may reject as unrelated.
      if (
        error instanceof ProvisioningError &&
        error.code !== "member_provisioning_failed"
      ) {
        throw error;
      }
      throw new ProvisioningError("provision_recovery_required");
    }
    businessResult = committed;
  }

  // Only reset the global Auth credential after the business RPC has proved
  // that this account belongs to this invitation. This prevents a marker (or
  // an unrelated existing membership) from causing a cross-organization
  // password reset.
  // A marked account may have obtained a session before the business
  // transaction outcome became ambiguous. Revoke it before issuing a fresh
  // temporary credential.
  await callServiceRpc(adminClient, "revoke_member_auth_sessions", {
    p_target_auth_user_id: targetAuthUserId,
  });
  const reset = await resetProvisioningAuthUser(
    adminClient,
    existingUser,
    organizationId,
    invitationId
  );
  return temporaryPasswordResult(
    { ...invitation, email, role },
    businessResult,
    reset.temporaryPassword
  );
}

async function provisionInvitation(
  actor: Actor,
  adminClient: DatabaseClient,
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
    if (isMarkedProvisioningUser(existingUser, organizationId, invitationId)) {
      return recoverMarkedProvisioningUser(
        actor,
        adminClient,
        invitation,
        existingUser,
        displayName
      );
    }
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
    const businessResult = await provisionBusinessMember(
      actor,
      adminClient,
      invitationId,
      displayName,
      requiredUuid(created.user.id, "member_provisioning_failed")
    );
    return temporaryPasswordResult(
      invitation,
      businessResult,
      created.temporaryPassword
    );
  } catch (error) {
    const targetAuthUserId = requiredUuid(
      created.user.id,
      "member_provisioning_failed"
    );
    const committed = await reconcileCommittedProvisioning(
      adminClient,
      invitationId,
      organizationId,
      email,
      stringValue(invitation.role) ?? "",
      targetAuthUserId
    );
    if (committed) {
      return temporaryPasswordResult(
        invitation,
        committed,
        created.temporaryPassword
      );
    }
    // The old implementation deleted the Auth user here. That is unsafe when
    // the RPC committed but its HTTP response was lost: the business rows do
    // not have a foreign key to auth.users and would become unrecoverable.
    // Keep the marked user and pending invitation so the next attempt can
    // reconcile or reissue credentials safely.
    if (
      error instanceof ProvisioningError &&
      error.code !== "member_provisioning_failed"
    ) {
      throw error;
    }
    throw new ProvisioningError("provision_recovery_required");
  }
}

async function provisionFromExistingInvitation(
  actor: Actor,
  userClient: DatabaseClient,
  adminClient: DatabaseClient,
  invitationId: string,
  displayName: string | null
): Promise<JsonObject> {
  const invitation = await callUserRpc(
    userClient,
    "reissue_organization_invitation",
    { p_invitation_id: invitationId }
  );
  return provisionInvitation(actor, adminClient, invitation, displayName);
}

async function reissueMemberCredential(
  actor: Actor,
  adminClient: DatabaseClient,
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
