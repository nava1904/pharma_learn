// @ts-nocheck
// Supabase Edge Function - Send Notification
// Multi-channel notification delivery

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationRequest {
  templateCode: string
  recipientId: string
  variables: Record<string, string>
  channels?: string[]
  priority?: number
  scheduledAt?: string
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

    const body: NotificationRequest = await req.json()

    // Get template
    const { data: template, error: templateError } = await supabaseClient
      .from('notification_templates')
      .select('*')
      .eq('unique_code', body.templateCode)
      .eq('is_active', true)
      .single()

    if (templateError || !template) {
      return new Response(
        JSON.stringify({ error: 'Template not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get recipient
    const { data: employee, error: empError } = await supabaseClient
      .from('employees')
      .select('id, email, phone, full_name, user_id, organization_id')
      .eq('id', body.recipientId)
      .single()

    if (empError || !employee) {
      return new Response(
        JSON.stringify({ error: 'Recipient not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check notification preferences
    const { data: preferences } = await supabaseClient
      .from('notification_preferences')
      .select('*')
      .eq('user_id', employee.user_id)
      .eq('notification_type', template.notification_type)
      .single()

    // Replace template variables
    let subject = template.subject_template || ''
    let bodyText = template.body_template
    let htmlBody = template.html_template || ''

    for (const [key, value] of Object.entries(body.variables)) {
      const placeholder = `{{${key}}}`
      subject = subject.replace(new RegExp(placeholder, 'g'), value)
      bodyText = bodyText.replace(new RegExp(placeholder, 'g'), value)
      htmlBody = htmlBody.replace(new RegExp(placeholder, 'g'), value)
    }

    const results: any[] = []
    const channels = body.channels || [template.channel]

    for (const channel of channels) {
      // Check if channel is enabled in preferences
      if (preferences) {
        if (channel === 'email' && !preferences.email_enabled) continue
        if (channel === 'push' && !preferences.push_enabled) continue
        if (channel === 'sms' && !preferences.sms_enabled) continue
        if (channel === 'in_app' && !preferences.in_app_enabled) continue
      }

      if (channel === 'in_app') {
        // Create in-app notification
        const { data: notification, error: notifError } = await supabaseClient
          .from('user_notifications')
          .insert({
            user_id: employee.user_id,
            employee_id: employee.id,
            notification_type: template.notification_type,
            title: subject,
            message: bodyText,
            action_data: body.variables,
            priority: body.priority || 5,
          })
          .select()
          .single()

        if (!notifError) {
          results.push({ channel: 'in_app', success: true, id: notification.id })
        }
      } else {
        // Queue for external delivery
        const { data: queued, error: queueError } = await supabaseClient
          .from('notification_queue')
          .insert({
            organization_id: employee.organization_id,
            template_id: template.id,
            notification_type: template.notification_type,
            channel,
            recipient_id: employee.id,
            recipient_email: channel === 'email' ? employee.email : null,
            recipient_phone: channel === 'sms' ? employee.phone : null,
            subject,
            body: bodyText,
            html_body: htmlBody,
            variables_data: body.variables,
            priority: body.priority || 5,
            scheduled_at: body.scheduledAt || new Date().toISOString(),
            status: 'pending',
          })
          .select()
          .single()

        if (!queueError) {
          results.push({ channel, success: true, queued: true, id: queued.id })
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        results,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error: any) {
    console.error('Notification error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
