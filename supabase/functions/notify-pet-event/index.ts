// Supabase Edge Function — notify-pet-event
// Triggered by DB webhook on INSERT/UPDATE to the `pets` table.
// Uses FCM HTTP v1 API (service account auth).
//
// Required secrets:
//   FIREBASE_SERVICE_ACCOUNT  = full JSON content of the service account key
//   SUPABASE_URL              = auto-set by Supabase
//   SUPABASE_SERVICE_ROLE_KEY = auto-set by Supabase

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { encode as base64url } from 'https://deno.land/std@0.168.0/encoding/base64url.ts'

const SB_URL = Deno.env.get('SUPABASE_URL')!
const SB_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const SA_RAW = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!

// ─── JWT / OAuth2 helper ────────────────────────────────────────────────────

async function getAccessToken(sa: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const payload = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }

  const enc = (obj: unknown) =>
    base64url(new TextEncoder().encode(JSON.stringify(obj)))

  const unsigned = `${enc(header)}.${enc(payload)}`

  // Import private key
  const pemBody = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s/g, '')
  const keyBuf = Uint8Array.from(atob(pemBody), c => c.charCodeAt(0))
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8', keyBuf,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false, ['sign'],
  )

  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsigned),
  )
  const jwt = `${unsigned}.${base64url(new Uint8Array(sig))}`

  // Exchange JWT for access token
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  })
  const data = await res.json()
  return data.access_token as string
}

// ─── Main ───────────────────────────────────────────────────────────────────

serve(async (req) => {
  try {
    const payload = await req.json()
    const type   = payload.type   as string
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

    // Get all FCM tokens
    const sb = createClient(SB_URL, SB_KEY)
    const { data: profiles } = await sb
      .from('profiles')
      .select('fcm_token')
      .not('fcm_token', 'is', null)

    const tokens: string[] = (profiles ?? [])
      .map((p: Record<string, unknown>) => p.fcm_token as string)
      .filter(Boolean)

    if (tokens.length === 0) return ok({ sent: 0, reason: 'no tokens' })

    // Get OAuth2 access token
    const sa = JSON.parse(SA_RAW)
    const accessToken = await getAccessToken(sa)
    const projectId = sa.project_id as string

    // Send one notification per token (V1 API sends one at a time)
    const results = await Promise.allSettled(
      tokens.map(token =>
        fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title, body },
              android: { priority: 'high', notification: { sound: 'default', channel_id: 'petfyco_alerts' } },
              apns: { payload: { aps: { sound: 'default', badge: 1 } } },
            },
          }),
        }).then(r => r.json())
      )
    )

    const sent = results.filter(r => r.status === 'fulfilled').length
    return ok({ sent, total: tokens.length, title })

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
