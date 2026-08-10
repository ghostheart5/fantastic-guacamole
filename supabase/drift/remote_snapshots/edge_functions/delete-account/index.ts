import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
}

function getRequiredEnv(name: string): string {
  const v = Deno.env.get(name)
  if (!v) throw new Error(`Missing env var: ${name}`)
  return v
}

function chunkArray<T>(arr: T[], size: number): T[][] {
  const out: T[][] = []
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size))
  return out
}

async function deleteStorageObjectsByOwner(supabaseAdmin: any, userId: string) {
  const { data: bucketsData, error: bucketsErr } = await supabaseAdmin
    .from('storage.objects')
    .select('bucket_id')
    .eq('owner_id', userId)

  if (bucketsErr) throw new Error(`Failed to list storage object buckets: ${bucketsErr.message}`)

  const bucketIds = Array.from(new Set((bucketsData ?? []).map((r: any) => r.bucket_id)))

  for (const bucketId of bucketIds) {
    const { data: objData, error: objErr } = await supabaseAdmin
      .from('storage.objects')
      .select('name')
      .eq('bucket_id', bucketId)
      .eq('owner_id', userId)

    if (objErr) throw new Error(`Failed to list storage objects for bucket ${bucketId}: ${objErr.message}`)

    const names: string[] = (objData ?? []).map((r: any) => r.name).filter(Boolean)
    if (!names.length) continue

    for (const namesChunk of chunkArray(names, 1000)) {
      const { error: rmErr } = await supabaseAdmin.storage
        .from(bucketId)
        .remove(namesChunk)
      if (rmErr) throw new Error(`Failed to remove storage objects in bucket ${bucketId}: ${rmErr.message}`)
    }
  }
}

async function bestEffortDeleteMultipartMetadata(supabaseAdmin: any, userId: string) {
  const { data: uploadIdsData, error: uploadIdsErr } = await supabaseAdmin
    .from('storage.s3_multipart_uploads')
    .select('id')
    .eq('owner_id', userId)

  if (uploadIdsErr) {
    console.warn('Multipart upload list failed:', uploadIdsErr)
    return
  }

  const uploadIds: string[] = (uploadIdsData ?? []).map((r: any) => r.id)
  if (!uploadIds.length) return

  const { error: partsErr } = await supabaseAdmin
    .from('storage.s3_multipart_uploads_parts')
    .delete()
    .in('upload_id', uploadIds)

  if (partsErr) console.warn('Multipart parts delete failed:', partsErr)

  const { error: uploadsErr } = await supabaseAdmin
    .from('storage.s3_multipart_uploads')
    .delete()
    .in('id', uploadIds)

  if (uploadsErr) console.warn('Multipart uploads delete failed:', uploadsErr)
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const serviceRoleKey = getRequiredEnv('SUPABASE_SERVICE_ROLE_KEY')
    const supabaseUrl = getRequiredEnv('SUPABASE_URL')

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401,
        headers: corsHeaders,
      })
    }

    const token = authHeader.replace('Bearer ', '')
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey)

    const { data: userData, error: userErr } = await supabaseAdmin.auth.getUser(token)
    if (userErr || !userData?.user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: corsHeaders,
      })
    }

    const userId = userData.user.id

    // STEP 1: Delete Storage objects owned by this user (all buckets)
    await deleteStorageObjectsByOwner(supabaseAdmin, userId)

    // STEP 1b: Best-effort delete multipart upload metadata owned by this user
    await bestEffortDeleteMultipartMetadata(supabaseAdmin, userId)

    // STEP 2: Delete user-owned DB rows in FK-safe order
    // Explicit dependency chain first
    const deletes: Array<{ table: string; col: string }> = [
      { table: 'focus_sessions', col: 'user_id' },
      { table: 'task_steps', col: 'user_id' },
      { table: 'goal_checkins', col: 'user_id' },
      { table: 'user_achievements', col: 'user_id' },
      { table: 'tasks', col: 'user_id' },
      { table: 'goals', col: 'user_id' },
      { table: 'habits', col: 'user_id' },

      // AI chat / coaching
      { table: 'smart coach notes', col: 'user_id' },
      { table: 'memoryEngine', col: 'user_id' },

      // Additional user-owned tables (by FK to auth.users.id)
      { table: 'purchase_bindings', col: 'user_id' },
      { table: 'user_daily_metrics', col: 'user_id' },
      { table: 'recurring_rules', col: 'user_id' },
      { table: 'user_devices', col: 'user_id' },
      { table: 'notifications', col: 'user_id' },
      { table: 'app_events', col: 'user_id' },
      { table: 'feedback_reports', col: 'user_id' },
      { table: 'subscriptions', col: 'user_id' },
      { table: 'entitlement_events', col: 'user_id' },
      { table: 'sync_queue', col: 'user_id' },

      { table: 'core_values', col: 'user_id' },
      { table: 'soul_maps', col: 'user_id' },
      { table: 'streaks', col: 'user_id' },
      { table: 'milestones', col: 'user_id' },
      { table: 'settings', col: 'user_id' },

      // Monetization
      { table: 'monetization_subscription_statuses', col: 'user_id' },
      { table: 'monetization_wallets', col: 'user_id' },
      { table: 'monetization_credit_transactions', col: 'user_id' },
      { table: 'monetization_purchases', col: 'user_id' },
      { table: 'monetization_entitlement_events', col: 'user_id' },

      // admin tools
      { table: 'admin_users', col: 'user_id' },
    ]

    for (const d of deletes) {
      const needsQuotes = d.table.includes(' ') || d.table.includes('-')
      const tbl = needsQuotes ? `"${d.table}"` : d.table

      const { error } = await supabaseAdmin.from(tbl as any).delete().eq(d.col as any, userId)
      if (error) throw new Error(`Delete failed for ${d.table}: ${error.message}`)
    }

    // STEP 2c: profiles uses profiles.id as FK to auth.users.id
    const { error: profilesErr } = await supabaseAdmin.from('profiles').delete().eq('id', userId)
    if (profilesErr) throw new Error(`Delete failed for profiles: ${profilesErr.message}`)

    // STEP 3: Finally delete the Auth user
    const { error: delErr } = await supabaseAdmin.auth.admin.deleteUser(userId)
    if (delErr) throw delErr

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: corsHeaders,
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      status: 500,
      headers: corsHeaders,
    })
  }
})

