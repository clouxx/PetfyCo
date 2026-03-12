// Supabase Edge Function — notify-pet-event
// Triggered by DB webhook on INSERT/UPDATE to the `pets` table.
// Sends FCM push notifications to all registered devices.
//
// Required secrets (supabase secrets set):
//   FCM_SERVER_KEY = <your Firebase legacy server key>
//   SUPABASE_URL   = <auto-set by Supabase>
//   SUPABASE_SERVICE_ROLE_KEY = <auto-set by Supabase>

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FCM_KEY = Deno.env.get('FCM_SERVER_KEY')!
const SB_URL  = Deno.env.get('SUPABASE_URL')!
const SB_KEY  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

serve(async (req) => {
  try {
    const payload = await req.json()

    // Supabase DB webhook sends { type, table, record, old_record }
    const type   = payload.type   as string   // INSERT | UPDATE
    const record = payload.record as Record<string, unknown>

    if (!record) return ok({ skipped: true })

    const nombre = (record.nombre as string) ?? 'Una mascota'
    const estado = (record.estado as string) ?? ''

    let title = ''
    let body  = ''

    if (type === 'INSERT') {
      if (estado === 'perdido') {
        title = `🚨 ¡${nombre} está perdido/a!`
        body  = 'Ayúdanos a encontrarlo. Dale una segunda oportunidad ❤️'
      } else {
        title = `🐾 ¡${nombre} busca un hogar!`
        body  = 'Dale una segunda oportunidad ❤️'
      }
    } else if (type === 'UPDATE') {
      const oldEstado = (payload.old_record?.estado as string) ?? ''
      if (estado === 'adoptado' && oldEstado !== 'adoptado') {
        title = `🎉 ¡${nombre} fue adoptado/a! 💖`
        body  = 'Gracias a todos nuestros aliados de Petfyco, su apoyo marca la diferencia.'
      } else {
        return ok({ skipped: 'no relevant change' })
      }
    } else {
      return ok({ skipped: 'not INSERT or UPDATE' })
    }

    // Get all FCM tokens from profiles
    const sb = createClient(SB_URL, SB_KEY)
    const { data: profiles } = await sb
      .from('profiles')
      .select('fcm_token')
      .not('fcm_token', 'is', null)

    const tokens: string[] = (profiles ?? [])
      .map((p: Record<string, unknown>) => p.fcm_token as string)
      .filter(Boolean)

    if (tokens.length === 0) return ok({ sent: 0, reason: 'no tokens' })

    // Send via FCM legacy API
    const fcmRes = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Authorization': `key=${FCM_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        registration_ids: tokens,
        notification: { title, body, sound: 'default' },
        android: { priority: 'high', notification: { sound: 'default', channel_id: 'petfyco_alerts' } },
        apns:    { payload: { aps: { sound: 'default', badge: 1 } } },
      }),
    })

    const result = await fcmRes.json()
    return ok({ sent: tokens.length, title, fcm: result })

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 })
  }
})

function ok(data: unknown) {
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
}
