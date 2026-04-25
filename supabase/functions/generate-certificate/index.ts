// @ts-nocheck
// Supabase Edge Function - Certificate Generation
// Generates PDF certificates with QR verification

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CertificateRequest {
  trainingRecordId: string
  templateId?: string
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { trainingRecordId, templateId }: CertificateRequest = await req.json()

    // Get training record
    const { data: trainingRecord, error: recordError } = await supabaseClient
      .from('training_records')
      .select(`
        *,
        employee:employees(id, employee_number, full_name, email),
        course:courses(id, name, unique_code),
        gtp:gtp_masters(id, name, unique_code)
      `)
      .eq('id', trainingRecordId)
      .single()

    if (recordError || !trainingRecord) {
      return new Response(
        JSON.stringify({ error: 'Training record not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Generate certificate number
    const certNumber = `CERT-${trainingRecord.organization_id.slice(0, 8)}-${Date.now()}`

    // Generate QR code data for verification
    const qrData = JSON.stringify({
      certNumber,
      employeeId: trainingRecord.employee.employee_number,
      courseName: trainingRecord.course?.name || trainingRecord.gtp?.name,
      completionDate: trainingRecord.completion_date,
      verifyUrl: `${Deno.env.get('PUBLIC_URL')}/verify/${certNumber}`,
    })

    // Generate verification hash
    const encoder = new TextEncoder()
    const data = encoder.encode(JSON.stringify(trainingRecord) + certNumber)
    const hashBuffer = await crypto.subtle.digest('SHA-256', data)
    const hashArray = Array.from(new Uint8Array(hashBuffer))
    const verificationHash = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')

    // Create certificate record
    const certificateData = {
      organization_id: trainingRecord.organization_id,
      certificate_number: certNumber,
      template_id: templateId || null,
      employee_id: trainingRecord.employee.id,
      training_record_id: trainingRecordId,
      course_id: trainingRecord.course_id,
      gtp_id: trainingRecord.gtp_id,
      certificate_type: trainingRecord.course_id ? 'course_completion' : 'gtp_completion',
      title: `Certificate of Completion`,
      description: `Awarded for successful completion of ${trainingRecord.course?.name || trainingRecord.gtp?.name}`,
      issue_date: new Date().toISOString().split('T')[0],
      expiry_date: trainingRecord.expiry_date,
      score: trainingRecord.assessment_score,
      certificate_data: {
        employeeName: trainingRecord.employee.full_name,
        employeeNumber: trainingRecord.employee.employee_number,
        courseName: trainingRecord.course?.name || trainingRecord.gtp?.name,
        completionDate: trainingRecord.completion_date,
        score: trainingRecord.assessment_score,
        duration: trainingRecord.duration_hours,
      },
      qr_code_data: qrData,
      verification_hash: verificationHash,
      issued_by: trainingRecord.esignature_id ? null : 'system',
      status: 'active',
    }

    const { data: certificate, error: certError } = await supabaseClient
      .from('certificates')
      .insert(certificateData)
      .select()
      .single()

    if (certError) {
      throw certError
    }

    // Update training record with certificate
    await supabaseClient
      .from('training_records')
      .update({ certificate_id: certificate.id })
      .eq('id', trainingRecordId)

    return new Response(
      JSON.stringify({
        success: true,
        certificateId: certificate.id,
        certificateNumber: certNumber,
        verificationHash,
        qrData,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error: any) {
    console.error('Certificate generation error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
