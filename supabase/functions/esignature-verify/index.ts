import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create, verify } from 'https://deno.land/x/djwt@v2.8/mod.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ESignatureRequest {
  entityType: string
  entityId: string
  action: string
  meaning: string
  reasonId?: string
  customReason?: string
  password: string
  biometricData?: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Get user from JWT
    const {
      data: { user },
    } = await supabaseClient.auth.getUser()

    if (!user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const body: ESignatureRequest = await req.json()

    // Verify password (re-authenticate)
    const { error: authError } = await supabaseClient.auth.signInWithPassword({
      email: user.email!,
      password: body.password,
    })

    if (authError) {
      // Log failed attempt
      await supabaseClient.from('login_audit_trail').insert({
        user_id: user.id,
        login_type: 'esignature',
        action: 'esignature_attempt',
        status: 'failed',
        failure_reason: 'Invalid password',
        ip_address: req.headers.get('x-forwarded-for') || 'unknown',
        user_agent: req.headers.get('user-agent'),
      })

      return new Response(
        JSON.stringify({ error: 'Invalid credentials' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get employee info
    const { data: employee } = await supabaseClient
      .from('employees')
      .select('id, organization_id, full_name')
      .eq('user_id', user.id)
      .single()

    if (!employee) {
      return new Response(
        JSON.stringify({ error: 'Employee not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get previous signature for hash chain
    const { data: lastSignature } = await supabaseClient
      .from('electronic_signatures')
      .select('hash_value')
      .order('signed_at', { ascending: false })
      .limit(1)
      .single()

    // Create signature data
    const signatureData = {
      signer_id: user.id,
      employee_id: employee.id,
      entity_type: body.entityType,
      entity_id: body.entityId,
      action: body.action,
      meaning: body.meaning,
      reason_id: body.reasonId,
      custom_reason: body.customReason,
      signed_at: new Date().toISOString(),
    }

    // Generate hash (SHA-256)
    const encoder = new TextEncoder()
    const data = encoder.encode(JSON.stringify(signatureData) + (lastSignature?.hash_value || ''))
    const hashBuffer = await crypto.subtle.digest('SHA-256', data)
    const hashArray = Array.from(new Uint8Array(hashBuffer))
    const hashValue = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')

    // Store e-signature
    const { data: signature, error: signError } = await supabaseClient
      .from('electronic_signatures')
      .insert({
        ...signatureData,
        hash_value: hashValue,
        previous_hash: lastSignature?.hash_value || null,
        ip_address: req.headers.get('x-forwarded-for') || null,
        user_agent: req.headers.get('user-agent'),
        biometric_verified: !!body.biometricData,
      })
      .select()
      .single()

    if (signError) {
      throw signError
    }

    // Log successful signature
    await supabaseClient.from('security_audit_trail').insert({
      user_id: user.id,
      action_type: 'esignature',
      action_description: `E-signature for ${body.entityType}: ${body.action}`,
      target_type: body.entityType,
      target_id: body.entityId,
      ip_address: req.headers.get('x-forwarded-for') || 'unknown',
      user_agent: req.headers.get('user-agent'),
    })

    return new Response(
      JSON.stringify({
        success: true,
        signatureId: signature.id,
        hashValue: hashValue,
        signedAt: signature.signed_at,
        signerName: employee.full_name,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('E-signature error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
