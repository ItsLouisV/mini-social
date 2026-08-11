import { AccessToken } from 'npm:livekit-server-sdk@2'
import { TrackSource } from 'npm:@livekit/protocol'
import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
}

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, 'Content-Type': 'application/json' },
})

const idPattern = /^[A-Za-z0-9_-]{8,128}$/
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

Deno.serve(async (req) => {
  const requestId = crypto.randomUUID()
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ code: 'METHOD_NOT_ALLOWED', requestId }, 405)

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ code: 'UNAUTHORIZED', requestId }, 401)

    let body: Record<string, unknown>
    try {
      body = await req.json()
    } catch (_) {
      return json({ code: 'INVALID_JSON', requestId }, 400)
    }

    const callId = typeof body.callId === 'string' ? body.callId : ''
    const deviceId = typeof body.deviceId === 'string' ? body.deviceId : ''
    const clientSessionId = typeof body.clientSessionId === 'string' ? body.clientSessionId : ''
    if (!uuidPattern.test(callId) || !idPattern.test(deviceId) || !idPattern.test(clientSessionId)) {
      return json({ code: 'INVALID_REQUEST', requestId }, 400)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const apiKey = Deno.env.get('LIVEKIT_API_KEY')
    const apiSecret = Deno.env.get('LIVEKIT_API_SECRET')
    const serverUrl = Deno.env.get('LIVEKIT_URL')
    if (!supabaseUrl || !anonKey || !apiKey || !apiSecret || !serverUrl) {
      console.error(JSON.stringify({ requestId, code: 'SERVER_CONFIG_MISSING' }))
      return json({ code: 'SERVER_UNAVAILABLE', requestId }, 503)
    }

    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) return json({ code: 'UNAUTHORIZED', requestId }, 401)

    // RLS guarantees only a participant can read this row.
    const { data: call, error: callError } = await supabase
      .from('calls')
      .select('id,caller_id,callee_id,type,status,room_name,answered_device_id,ended_at')
      .eq('id', callId)
      .maybeSingle()

    if (callError) {
      console.error(JSON.stringify({ requestId, code: 'CALL_LOOKUP_FAILED' }))
      return json({ code: 'CALL_LOOKUP_FAILED', requestId }, 500)
    }
    if (!call || (call.caller_id !== user.id && call.callee_id !== user.id)) {
      return json({ code: 'CALL_NOT_FOUND', requestId }, 404)
    }
    if (call.status !== 'accepted' || call.ended_at) {
      return json({ code: 'CALL_NOT_JOINABLE', requestId }, 409)
    }
    if (user.id === call.callee_id && call.answered_device_id !== deviceId) {
      return json({ code: 'ANSWERED_ON_ANOTHER_DEVICE', requestId }, 409)
    }

    const role = user.id === call.caller_id ? 'caller' : 'callee'
    const identity = `${user.id}:${deviceId}:${clientSessionId}`
    const displayName = String(user.user_metadata?.full_name ?? 'User').slice(0, 100)
    const token = new AccessToken(apiKey, apiSecret, {
      identity,
      name: displayName,
      ttl: '10m',
      metadata: JSON.stringify({ userId: user.id, callId, deviceId, role }),
    })
    token.addGrant({
      roomJoin: true,
      room: call.room_name,
      canPublish: true,
      canSubscribe: true,
      canPublishData: false,
      canPublishSources: call.type === 'video'
        ? [TrackSource.MICROPHONE, TrackSource.CAMERA]
        : [TrackSource.MICROPHONE],
    })

    return json({
      serverUrl,
      participantToken: await token.toJwt(),
      participantIdentity: identity,
      expiresIn: 600,
      callId,
    }, 201)
  } catch (error) {
    console.error(JSON.stringify({ requestId, code: 'TOKEN_ISSUE_FAILED', error: String(error) }))
    return json({ code: 'TOKEN_ISSUE_FAILED', requestId }, 500)
  }
})
