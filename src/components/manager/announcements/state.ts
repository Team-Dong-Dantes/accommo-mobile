// The landlord/landlady's announcements: loading, filtering, sending and
// removing them.
import { type AnnouncementDraft } from '@/components/manager/compose/model'
import { authUser, supabase } from '@/utils/supabase'
import { computed, onMounted, ref } from 'vue'
import { errorMessage } from '@/utils/errors'
import { formatDate } from '@/utils/format'
import { useNotify } from '@/utils/notify'

export function createAnnouncements() {
  type Accommodation = { id: string; name: string }
  type Mine = {
    id: string
    title: string
    accommodation_id: string | null
    published_at: string | null
    expires_at: string | null
    summary: string | null
    body: string
    event_at: string | null
    event_end: string | null
    deadline_at: string | null
    location: string | null
    image_url: string | null
  }

  // Everything the list and the detail beside it show.
  const MINE_COLUMNS =
    'id, title, accommodation_id, published_at, expires_at, summary, body, event_at, event_end, deadline_at, location, image_url'

  const notify = useNotify()

  const loading = ref(true)
  const sending = ref(false)
  const composeOpen = ref(false)
  const userId = ref('')
  const accommodations = ref<Accommodation[]>([])
  const mine = ref<Mine[]>([])

  // The announcement open beside the list (tablet and computer only).
  const selectedId = ref('')
  const selected = computed(() => mine.value.find((a) => a.id === selectedId.value) ?? null)
  const detailOpen = computed({
    get: () => Boolean(selected.value),
    set: (open: boolean) => {
      if (!open) selectedId.value = ''
    },
  })

  function houseName(id: string | null) {
    return accommodations.value.find((a) => a.id === id)?.name ?? 'Your accommodation'
  }

  const STATUS_FILTERS = [
    { key: 'all', label: 'All' },
    { key: 'sent', label: 'Sent' },
    { key: 'scheduled', label: 'Scheduled' },
    { key: 'ended', label: 'Ended' },
    { key: 'draft', label: 'Draft' },
  ] as const
  type StatusKey = Exclude<(typeof STATUS_FILTERS)[number]['key'], 'all'>

  function statusKey(a: Mine): StatusKey {
    if (!a.published_at) return 'draft'
    if (new Date(a.published_at).getTime() > Date.now()) return 'scheduled'
    if (a.expires_at && new Date(a.expires_at).getTime() < Date.now()) return 'ended'
    return 'sent'
  }

  function statusOf(a: Mine) {
    const key = statusKey(a)
    if (key === 'draft') return 'Draft'
    if (key === 'ended') return 'Ended'
    return `${key === 'scheduled' ? 'Scheduled' : 'Sent'} ${formatDate(a.published_at)}`
  }

  const query = ref('')
  const status = ref<(typeof STATUS_FILTERS)[number]['key']>('all')
  const houseId = ref('all')
  const filtersOpen = ref(false)
  const filterCount = computed(() => Number(status.value !== 'all') + Number(houseId.value !== 'all'))

  const visible = computed(() => {
    const q = query.value.trim().toLowerCase()
    return mine.value.filter((a) => {
      if (status.value !== 'all' && statusKey(a) !== status.value) return false
      if (houseId.value !== 'all' && a.accommodation_id !== houseId.value) return false
      if (!q) return true
      return [a.title, a.summary, a.body, a.location, houseName(a.accommodation_id)].some((t) => t?.toLowerCase().includes(q))
    })
  })

  /** `silent` skips the skeleton, so a pull-to-refresh spinner is the only chrome. */
  async function load(silent = false) {
    if (!silent) loading.value = true
    const { data } = await authUser()
    userId.value = data?.user?.id ?? ''
    if (!userId.value) {
      loading.value = false
      return
    }

    const [{ data: houses }, { data: rows }] = await Promise.all([
      supabase
        .from('accommodations')
        .select('id, name')
        .eq('landlord_id', userId.value)
        .order('name'),
      supabase
        .from('announcements')
        .select(MINE_COLUMNS)
        .not('accommodation_id', 'is', null)
        .order('published_at', { ascending: false, nullsFirst: true }),
    ])

    accommodations.value = houses ?? []
    mine.value = (rows ?? []) as Mine[]
    loading.value = false
  }

  function onPull(done: () => void) {
    void load(true).finally(done)
  }

  onMounted(load)

  // AnnouncementCompose owns the form, its validation and the tenant count; this
  // only does the insert. The overlay closes on success and stays open on failure,
  // so a rejected notice is never silently lost.
  async function send(draft: AnnouncementDraft) {
    sending.value = true
    try {
      const publishAt = draft.publishAt ? new Date(draft.publishAt).toISOString() : new Date().toISOString()
      // One row per house: a notice is addressed to an accommodation, and each
      // set of tenants reads (and dismisses) its own. Sent as a single insert so
      // it is all-or-nothing — two houses notified and a third silently missed
      // would be worse than an error.
      const rows = draft.accommodationIds.map((accommodationId) => ({
        title: draft.title.trim(),
        summary: draft.summary.trim() || null,
        body: draft.body.trim(),
        // Tenants are students; the audience column is ignored for house
        // notices, which are addressed by accommodation instead.
        audience: 'students' as const,
        accommodation_id: accommodationId,
        event_at: draft.eventAt ? new Date(draft.eventAt).toISOString() : null,
        event_end: draft.eventEnd ? new Date(draft.eventEnd).toISOString() : null,
        deadline_at: draft.deadlineAt ? new Date(draft.deadlineAt).toISOString() : null,
        location: draft.location.trim() || null,
        image_url: draft.imageUrl || null,
        author_id: userId.value,
        published_at: publishAt,
        expires_at: draft.expiresAt ? new Date(`${draft.expiresAt}T23:59:59`).toISOString() : null,
      }))

      const { data, error } = await supabase
        .from('announcements')
        .insert(rows)
        .select(MINE_COLUMNS)
      if (error) throw error

      mine.value = [...((data ?? []) as Mine[]), ...mine.value]
      composeOpen.value = false
      const houses = draft.accommodationIds.length
      notify.success(
        draft.publishAt
          ? houses > 1 ? `Scheduled for ${houses} houses.` : 'Scheduled.'
          : houses > 1 ? `Sent to ${houses} houses.` : 'Sent to your boarders.',
      )
    } catch (e) {
      notify.error(errorMessage(e, 'Could not send that announcement.'))
    } finally {
      sending.value = false
    }
  }

  async function remove(a: Mine) {
    const { error } = await supabase.from('announcements').delete().eq('id', a.id)
    if (error) {
      notify.error(error.message)
      return
    }
    mine.value = mine.value.filter((row) => row.id !== a.id)
    if (selectedId.value === a.id) selectedId.value = ''
    notify.success('Removed. Notifications already delivered stay in your boarders\' inbox.')
  }

  return {
    MINE_COLUMNS,
    notify,
    loading,
    sending,
    composeOpen,
    userId,
    accommodations,
    mine,
    selectedId,
    selected,
    detailOpen,
    houseName,
    STATUS_FILTERS,
    statusKey,
    statusOf,
    query,
    status,
    houseId,
    filtersOpen,
    filterCount,
    visible,
    load,
    onPull,
    send,
    remove,
  }
}
