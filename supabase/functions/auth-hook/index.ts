// Supabase Custom Access Token Hook
// ─────────────────────────────────────────────────────────────────────────────
// Registered in: Supabase Dashboard → Authentication → Hooks
//                → Custom Access Token
//
// This hook fires synchronously before GoTrue mints each JWT.  It enriches
// app_metadata with the employee's PharmaLearn identity, permissions, and
// induction status so that every JWT is self-contained — no per-request DB
// calls needed in the API server.
//
// Reference: https://supabase.com/docs/guides/auth/auth-hooks#custom-access-token-hook
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface CustomAccessTokenPayload {
  event: 'custom_access_token'
  user_id: string
  claims: {
    sub: string
    email?: string
    phone?: string
    app_metadata: Record<string, unknown>
    user_metadata: Record<string, unknown>
    role?: string
    aud?: string
  }
}

serve(async (req: Request) => {
  // ── 1. Validate that this is the Custom Access Token event ───────────────
  const payload: CustomAccessTokenPayload = await req.json()

  if (payload.event !== 'custom_access_token') {
    return new Response(
      JSON.stringify({ error: 'Unexpected hook event: ' + payload.event }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    )
  }

  // ── 2. Service-role client for DB lookups ─────────────────────────────────
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  const userId = payload.user_id

  try {
    // ── 3. Load employee record ─────────────────────────────────────────────
    const { data: employee, error: empErr } = await supabase
      .from('employees')
      .select('id, organization_id, plant_id, induction_completed')
      .eq('user_id', userId)
      .maybeSingle()

    if (empErr) {
      console.error('[auth-hook] employee lookup error:', empErr.message)
      // Return empty additions so login still works — employee may be mid-creation
      return successResponse(payload.claims, {})
    }

    if (!employee) {
      // User exists in GoTrue but has no employees row yet (e.g. SSO provisioning)
      console.warn('[auth-hook] no employee record for user_id:', userId)
      return successResponse(payload.claims, {})
    }

    // ── 4. Load effective permissions ──────────────────────────────────────
    //  get_employee_permissions() returns a TEXT[] of permission strings, e.g.
    //  ["documents.approve", "courses.create", "reports.view", …]
    const { data: permsRaw, error: permsErr } = await supabase
      .rpc('get_employee_permissions', { p_employee_id: employee.id })

    const permissions: string[] = permsErr
      ? []
      : (Array.isArray(permsRaw) ? permsRaw as string[] : [])

    if (permsErr) {
      console.error('[auth-hook] permissions lookup error:', permsErr.message)
    }

    // ── 5. Return enriched claims ───────────────────────────────────────────
    return successResponse(payload.claims, {
      employee_id: employee.id,
      organization_id: employee.organization_id,
      plant_id: employee.plant_id,
      induction_completed: employee.induction_completed ?? false,
      permissions,
    })
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('[auth-hook] unexpected error:', message)
    // Fail open — user can still log in, but without enriched claims.
    // The API server will fall back to DB permission checks.
    return successResponse(payload.claims, {})
  }
})

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/** Merge [additions] into the existing app_metadata and return the hook response. */
function successResponse(
  claims: CustomAccessTokenPayload['claims'],
  additions: Record<string, unknown>,
): Response {
  return new Response(
    JSON.stringify({
      claims: {
        ...claims,
        app_metadata: {
          ...(claims.app_metadata ?? {}),
          ...additions,
        },
      },
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  )
}
