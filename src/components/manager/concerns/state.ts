// The concerns inbox: loading and filtering it, and answering, resolving or
// escalating the open one.
import { AVATAR, resolveAsset } from '@/utils/cloudinaryUrl'
import { CONCERN_CATEGORY_LABEL, ticketNoOf } from '@/utils/format'
import { type Concern, FILTERS } from './model'
import { type LivePayload, useLiveData } from '@/utils/useLiveData'
import { authUser, supabase } from '@/utils/supabase'
import { computed, ref } from 'vue'
import { errorMessage } from '@/utils/errors'
import { signRows } from '@/utils/upload'
import { useNotify } from '@/utils/notify'

export function createManagerConcerns() {
  const notify = useNotify()

  const loading = ref(true)
  const error = ref('')
  const rows = ref<Concern[]>([])
  const query = ref('')
  const filter = ref<(typeof FILTERS)[number]['key']>('all')
  const filtersOpen = ref(false)

  const detailOpen = ref(false)
  const selected = ref<Concern | null>(null)
  const response = ref('')
  const deciding = ref(false)
  const escalating = ref(false)

  const visibleRows = computed(() => {
    const q = query.value.trim().toLowerCase()
    return rows.value.filter((c) => {
      if (filter.value !== 'all' && c.status !== filter.value) return false
      if (!q) return true
      return (
        c.studentName.toLowerCase().includes(q) ||
        c.description.toLowerCase().includes(q) ||
        (CONCERN_CATEGORY_LABEL[c.category] || c.category).toLowerCase().includes(q)
      )
    })
  })

  function openDetail(c: Concern) {
    selected.value = c
    response.value = c.managerResponse
    detailOpen.value = true
  }

  async function load() {
    loading.value = true
    error.value = ''
    try {
      const { data: authData } = await authUser()
      const user = authData?.user
      if (!user) {
        error.value = 'Not logged in.'
        return
      }

      const { data, error: loadError } = await supabase
        .from('concerns')
        .select(
          'id, lease_id, category, description, status, reported_at, manager_response, photo_url, leases!inner(landlord_id, student_id, users!leases_student_id_fkey(full_name, avatar_color, avatar_url), rooms(accommodation_id, room_number, label, accommodations(name))), tickets(ticket_no)',
        )
        .eq('leases.landlord_id', user.id)
        .order('reported_at', { ascending: false })
      if (loadError) throw loadError
      await signRows('concerns', data, 'photo_url')

      rows.value = (data ?? []).map((c) => {
        const lease = c.leases as unknown as {
          student_id: string
          users: { full_name: string | null; avatar_color: string | null; avatar_url: string | null } | null
          rooms: { accommodation_id: string | null; room_number: string | null; label: string | null; accommodations: { name: string | null } | null } | null
        }
        const room = lease.rooms
        return {
          id: c.id,
          leaseId: c.lease_id,
          studentId: lease.student_id,
          photoUrl: c.photo_url || '',
          accommodationId: room?.accommodation_id || null,
          category: c.category,
          description: c.description || '',
          status: c.status,
          reportedAt: c.reported_at,
          managerResponse: c.manager_response || '',
          where: room?.accommodations?.name || room?.label || 'Accommodation',
          studentName: lease.users?.full_name || 'A student',
          avatarColor: lease.users?.avatar_color ?? null,
          avatarUrl: lease.users?.avatar_url ? resolveAsset(lease.users.avatar_url, AVATAR) : null,
          escalatedTicketNo: ticketNoOf(c.tickets),
        }
      })

    } catch (e) {
      error.value = errorMessage(e, 'Something went wrong.')
    } finally {
      loading.value = false
    }
  }

  /**
   * New reports and status/response edits land live; RLS scopes the feed to this
   * landlord/landlady's own leases. Both handlers patch `rows` in place rather than
   * refetching — a concerns feed grows one row at a time, so a full reload for
   * each would be wasteful.
   */
  async function onConcernInserted(payload: LivePayload) {
    const id = (payload.new as { id: string }).id
    if (rows.value.some((r) => r.id === id)) return
    const { data } = await supabase
      .from('concerns')
      .select(
        'id, lease_id, category, description, status, reported_at, manager_response, photo_url, leases!inner(landlord_id, student_id, users!leases_student_id_fkey(full_name, avatar_color, avatar_url), rooms(accommodation_id, room_number, label, accommodations(name))), tickets(ticket_no)',
      )
      .eq('id', id)
      .maybeSingle()
    if (!data) return
    await signRows('concerns', [data], 'photo_url')
    const lease = data.leases as unknown as {
      student_id: string
      users: { full_name: string | null; avatar_color: string | null; avatar_url: string | null } | null
      rooms: { accommodation_id: string | null; room_number: string | null; label: string | null; accommodations: { name: string | null } | null } | null
    }
    const room = lease.rooms
    rows.value = [
      {
        id: data.id,
        leaseId: data.lease_id,
        studentId: lease.student_id,
        photoUrl: data.photo_url || '',
        accommodationId: room?.accommodation_id || null,
        category: data.category,
        description: data.description || '',
        status: data.status,
        reportedAt: data.reported_at,
        managerResponse: data.manager_response || '',
        where: room?.accommodations?.name || room?.label || 'Accommodation',
        studentName: lease.users?.full_name || 'A student',
        avatarColor: lease.users?.avatar_color ?? null,
        avatarUrl: lease.users?.avatar_url ? resolveAsset(lease.users.avatar_url, AVATAR) : null,
        escalatedTicketNo: ticketNoOf(data.tickets),
      },
      ...rows.value,
    ]
  }

  function onConcernUpdated(payload: LivePayload) {
    const row = payload.new as { id: string; status: string; manager_response: string | null }
    const patch = (c: Concern) => {
      c.status = row.status
      c.managerResponse = row.manager_response || ''
    }
    const listed = rows.value.find((c) => c.id === row.id)
    if (listed) patch(listed)
    if (selected.value?.id === row.id) patch(selected.value)
  }

  const { refresh } = useLiveData({
    key: 'manager-concerns',
    load,
    watch: () => [
      { table: 'concerns', event: 'INSERT', onChange: (p) => void onConcernInserted(p) },
      { table: 'concerns', event: 'UPDATE', onChange: onConcernUpdated },
    ],
  })

  async function decide(next: 'acknowledged' | 'in_progress' | 'resolved' | 'rejected') {
    if (deciding.value || !selected.value) return
    deciding.value = true
    try {
      const payload: {
        status: string
        manager_response: string | null
        acknowledged_at?: string
        in_progress_at?: string
        resolved_at?: string
      } = {
        status: next,
        manager_response: response.value.trim() || null,
      }
      if (next === 'acknowledged') payload.acknowledged_at = new Date().toISOString()
      if (next === 'in_progress') payload.in_progress_at = new Date().toISOString()
      if (next === 'resolved' || next === 'rejected') payload.resolved_at = new Date().toISOString()

      const { error: updateError } = await supabase.from('concerns').update(payload).eq('id', selected.value.id)
      if (updateError) throw updateError

      selected.value.status = next
      selected.value.managerResponse = response.value.trim()
      const row = rows.value.find((r) => r.id === selected.value?.id)
      if (row) {
        row.status = next
        row.managerResponse = response.value.trim()
      }

      notify.success('Updated.')
      if (next === 'resolved' || next === 'rejected') detailOpen.value = false
    } catch (e) {
      notify.error(errorMessage(e, 'Could not update this concern.'))
    } finally {
      deciding.value = false
    }
  }

  /** Raises the concern as an OSAS ticket on the same lease/accommodation, for issues the landlord/landlady can't resolve alone. */
  async function escalate() {
    if (escalating.value || !selected.value) return
    escalating.value = true
    try {
      const { data: authData } = await authUser()
      const user = authData?.user
      if (!user) throw new Error('Not logged in.')

      const c = selected.value
      const { data: created, error: insertError } = await supabase.from('tickets').insert({
        landlord_id: user.id,
        accommodation_id: c.accommodationId,
        lease_id: c.leaseId,
        concern_id: c.id,
        student_id: c.studentId,
        reporter_name: c.studentName,
        subject: `Escalated concern: ${CONCERN_CATEGORY_LABEL[c.category] || c.category}`,
        description: c.description || null,
        category: 'accommodation',
        status: 'open',
        priority: 'medium',
      }).select('ticket_no').single()
      // 23505: this concern already has its OSAS ticket (escalated from another device).
      if (insertError && insertError.code !== '23505') throw insertError
      if (!created) {
        void refresh()
        notify.info('This concern was already escalated to OSAS.')
        return
      }
      c.escalatedTicketNo = created.ticket_no
      const row = rows.value.find((r) => r.id === c.id)
      if (row) row.escalatedTicketNo = created.ticket_no

      notify.success('Escalated to OSAS.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not escalate this concern.'))
    } finally {
      escalating.value = false
    }
  }

  // Pull-to-refresh goes through useLiveData's refresh rather than load(): it
  // loads silently (no skeleton behind the spinner) and resets the freshness
  // clock, so returning to the screen does not immediately fetch again.
  function onPull(done: () => void) {
    void refresh().finally(done)
  }

  return {
    notify,
    loading,
    error,
    rows,
    query,
    filter,
    filtersOpen,
    detailOpen,
    selected,
    response,
    deciding,
    escalating,
    visibleRows,
    openDetail,
    load,
    onConcernInserted,
    onConcernUpdated,
    refresh,
    decide,
    escalate,
    onPull,
  }
}
