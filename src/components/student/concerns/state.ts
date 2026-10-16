// The student's concerns: loading and filtering them, the open one's
// progress, and reporting a new one.
import { CONCERN_CATEGORY_LABEL, ticketNoOf } from '@/utils/format'
import { type Concern, FILTERS } from './model'
import { type LivePayload, useLiveData } from '@/utils/useLiveData'
import { authUser, supabase } from '@/utils/supabase'
import { computed, reactive, ref } from 'vue'
import { errorMessage } from '@/utils/errors'
import { fetchCurrentLease } from '@/api/leases'
import { signRows, uploadSecureDocument } from '@/utils/upload'
import { useMyLandlordTitle } from '@/utils/myLandlordTitle'
import { useNotify } from '@/utils/notify'

export function createStudentConcerns() {
  const notify = useNotify()
  const myLandlord = useMyLandlordTitle()

  const loading = ref(true)
  const error = ref('')
  const rows = ref<Concern[]>([])
  const query = ref('')
  const filter = ref<(typeof FILTERS)[number]['key']>('all')
  const filtersOpen = ref(false)

  const activeLease = ref<{ id: string; managerId: string } | null>(null)

  const detailOpen = ref(false)
  const selected = ref<Concern | null>(null)
  const newOpen = ref(false)
  const submitting = ref(false)
  const form = reactive({ category: 'maintenance', description: '', photo: null as File | null })

  // A single timeline replaces the old step-tracker + activity list: each row
  // is "done" once its timestamp lands, so a rejected report still shows
  // whatever acknowledgement/in-progress steps actually happened before it closed.
  const timeline = computed(() => {
    if (!selected.value) return []
    const c = selected.value
    const closed = c.status === 'resolved' || c.status === 'rejected'
    return [
      { key: 'open', label: 'Reported', at: c.reportedAt as string | null, done: true, bad: false },
      { key: 'acknowledged', label: 'Acknowledged', at: c.acknowledgedAt, done: !!c.acknowledgedAt, bad: false },
      { key: 'in_progress', label: 'In progress', at: c.inProgressAt, done: !!c.inProgressAt, bad: false },
      { key: 'closed', label: c.status === 'rejected' ? 'Rejected' : 'Resolved', at: closed ? c.resolvedAt : null, done: closed, bad: c.status === 'rejected' },
    ]
  })

  function onPhotoSelected(event: Event) {
    const input = event.target as HTMLInputElement
    form.photo = input.files?.[0] || null
  }

  const visibleRows = computed(() => {
    const q = query.value.trim().toLowerCase()
    return rows.value.filter((c) => {
      if (filter.value !== 'all' && c.status !== filter.value) return false
      if (!q) return true
      return c.description.toLowerCase().includes(q) || (CONCERN_CATEGORY_LABEL[c.category] || c.category).toLowerCase().includes(q)
    })
  })

  function openDetail(c: Concern) {
    selected.value = c
    detailOpen.value = true
  }

  function openNew() {
    form.category = 'maintenance'
    form.description = ''
    form.photo = null
    newOpen.value = true
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

      const leaseRow = await fetchCurrentLease(user.id)
      activeLease.value = leaseRow ? { id: leaseRow.id, managerId: leaseRow.landlord_id } : null

      const { data, error: loadError } = await supabase
        .from('concerns')
        .select(
          'id, category, description, status, reported_at, acknowledged_at, in_progress_at, resolved_at, manager_response, photo_url, leases!inner(student_id, rooms(room_number, label, accommodations(name))), tickets(ticket_no)',
        )
        .eq('leases.student_id', user.id)
        .order('reported_at', { ascending: false })
      if (loadError) throw loadError
      await signRows('concerns', data, 'photo_url')

      rows.value = (data ?? []).map((c) => {
        const lease = c.leases as unknown as {
          rooms: { room_number: string | null; label: string | null; accommodations: { name: string | null } | null } | null
        }
        const room = lease.rooms
        return {
          id: c.id,
          category: c.category,
          description: c.description || '',
          status: c.status,
          reportedAt: c.reported_at,
          acknowledgedAt: c.acknowledged_at,
          inProgressAt: c.in_progress_at,
          resolvedAt: c.resolved_at,
          managerResponse: c.manager_response || '',
          photoUrl: c.photo_url || '',
          where: room?.accommodations?.name || room?.label || 'Your stay',
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
   * Live status/response updates from the landlord/landlady land on an open list or detail
   * sheet without a manual reload. Patched in place rather than refetched — only
   * these five fields ever change on an existing concern.
   */
  function onConcernUpdated(payload: LivePayload) {
    const row = payload.new as {
      id: string
      status: string
      acknowledged_at: string | null
      in_progress_at: string | null
      resolved_at: string | null
      manager_response: string | null
    }
    const patch = (c: Concern) => {
      c.status = row.status
      c.acknowledgedAt = row.acknowledged_at
      c.inProgressAt = row.in_progress_at
      c.resolvedAt = row.resolved_at
      c.managerResponse = row.manager_response || ''
    }
    const listed = rows.value.find((c) => c.id === row.id)
    if (listed) patch(listed)
    if (selected.value?.id === row.id) patch(selected.value)
  }

  // The lease id is only known once `load` has run, so the watch is evaluated
  // after it — see utils/useLiveData.ts.
  const { refresh } = useLiveData({
    key: 'student-concerns',
    load,
    watch: () =>
      activeLease.value
        ? [
            {
              table: 'concerns',
              event: 'UPDATE',
              filter: `lease_id=eq.${activeLease.value.id}`,
              onChange: onConcernUpdated,
            },
          ]
        : [],
  })

  async function submit() {
    if (submitting.value || !activeLease.value) return
    submitting.value = true
    try {
      // Private: stored as a cld: ref, shown through a signed link.
      const photoUrl = form.photo ? await uploadSecureDocument(form.photo) : null

      const { data: created, error: insertError } = await supabase
        .from('concerns')
        .insert({
          lease_id: activeLease.value.id,
          category: form.category,
          description: form.description.trim() || null,
          status: 'open',
          photo_url: photoUrl,
        })
        .select('id, category, description, status, reported_at, manager_response, photo_url')
        .single()
      if (insertError) throw insertError

      rows.value = [
        {
          id: created.id,
          category: created.category,
          description: created.description || '',
          status: created.status,
          reportedAt: created.reported_at,
          acknowledgedAt: null,
          inProgressAt: null,
          resolvedAt: null,
          managerResponse: '',
          photoUrl: form.photo ? URL.createObjectURL(form.photo) : '',
          where: 'Your stay',
          escalatedTicketNo: null,
        },
        ...rows.value,
      ]

      newOpen.value = false
      notify.success('Concern reported.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not submit your concern.'))
    } finally {
      submitting.value = false
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
    myLandlord,
    loading,
    error,
    rows,
    query,
    filter,
    filtersOpen,
    activeLease,
    detailOpen,
    selected,
    newOpen,
    submitting,
    form,
    timeline,
    onPhotoSelected,
    visibleRows,
    openDetail,
    openNew,
    load,
    onConcernUpdated,
    refresh,
    submit,
    onPull,
  }
}
