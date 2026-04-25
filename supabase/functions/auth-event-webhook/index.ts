// Supabase Auth Event Webhook
// ─────────────────────────────────────────────────────────────────────────────
// Registered in: Supabase Dashboard → Authentication → Hooks
//                → Send Email  ← or a custom webhook URL pointed at this function
//
// This webhook fires on GoTrue auth EVENTS (SIGNED_IN, SIGNED_OUT, etc.)
// and writes to the login_audit_trail table.
//
// It is SEPARATE from the Custom Access Token Hook (auth-hook/index.ts).
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface AuthEventPayload {
  event: string
  user: {
    id: string
    email: string
    phone?: string
    app_metadata: Record<string, unknown>
    user_metadata: Record<string, unknown>
    created_at: string
  }
  session?: {
    access_token: string
    refresh_token: string
    expires_in: number
  }
}

serve(async (req: Request) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const payload: AuthEventPayload = await req.json()
    const { event, user, session } = payload

    const ipAddress =
      req.headers.get('x-forwarded-for') ??
      req.headers.get('x-real-ip') ??
      'unknown'
    const userAgent = req.headers.get('user-agent') ?? 'unknown'

    let action = event
    switch (event) {
      case 'SIGNED_IN':          action = 'login';                       break
      case 'SIGNED_OUT':         action = 'logout';                      break
      case 'TOKEN_REFRESHED':    action = 'token_refresh';               break
      case 'PASSWORD_RECOVERY':  action = 'password_recovery_requested'; break
      case 'USER_UPDATED':       action = 'profile_updated';             break
      case 'USER_DELETED':       action = 'account_deleted';             break
    }

    const mfaVerified = (user.app_metadata?.mfa_verified as boolean) ?? false
    const mfaMethod   = (user.app_metadata?.mfa_method   as string)  ?? null

    // Write audit row
    await supabase.from('login_audit_trail').insert({
      user_id:    user.id,
      username:   user.email,
      login_type: 'password',
      action,
      status:     'success',
      ip_address: ipAddress,
      user_agent: userAgent,
      session_id: session?.access_token
        ? await hashString(session.access_token.slice(-20))
        : null,
      mfa_method:  mfaMethod,
      mfa_verified: mfaVerified,
      device_info: { userAgent, timestamp: new Date().toISOString() },
    })

    // Update last_login_at on SIGNED_IN
    if (event === 'SIGNED_IN') {
      await supabase
        .from('employees')
        .update({ last_login_at: new Date().toISOString() })
        .eq('user_id', user.id)
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error)
    console.error('[auth-event-webhook] error:', message)
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})

async function hashString(str: string): Promise<string> {
  const encoder = new TextEncoder()
  const data = encoder.encode(str)
  const hashBuffer = await crypto.subtle.digest('SHA-256', data)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('').slice(0, 32)
}
