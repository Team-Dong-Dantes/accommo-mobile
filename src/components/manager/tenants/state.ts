// Every accommodation with its rooms and leases, the search and filters over
// them, and deciding applications from the list.
import { AVATAR, CARD, resolveAsset } from '@/utils/cloudinaryUrl'
import { type Accommodation, FILTERS, type Lease, type Room } from './model'
import { authUser, supabase } from '@/utils/supabase'
import { computed, ref, watch } from 'vue'
import { requirePin } from '@/utils/requirePin'
import { errorMessage } from '@/utils/errors'
import { formatDate, formatPeso } from '@/utils/format'
import { respondToApplication } from '@/utils/applications'
import { useDeskPanels } from '@/utils/useDeskPanels'
import { useLiveData } from '@/utils/useLiveData'
import { useNotify } from '@/utils/notify'
import { useRoute, useRouter } from 'vue-router'

export function createTenantsState() {
  const router = useRouter()
  const notify = useNotify()

  const loading = ref(true)
  const error = ref('')
  const myId = ref('')
  const accommodations = ref<Accommodation[]>([])
  const activeTab = ref<'tenants' | 'payments' | 'history'>('tenants')
  // `?tab=payments` (the dashboard's "Verify payments" item) and `?tab=history`
  // (the history screens' "Rent history" link). Watched, not read once: this
  // screen is kept alive, so a later visit reuses the same instance.
  const route = useRoute()
  watch(
    () => route.query.tab,
    (tab) => {
      if (tab === 'payments' || tab === 'history') activeTab.value = tab
    },
    { immediate: true },
  )
  // Desktop has the room for both panels at once (see useDeskPanels).
  const { split, panelsIs, panelIs, panelsProps } = useDeskPanels(activeTab)
  // Bumped on every load so the Monthly rent and Rent history panels reload with the page.
  const loadVersion = ref(0)
  const toConfirm = ref(0)
  const query = ref('')
  const filter = ref<(typeof FILTERS)[number]['key']>('all')
  const filtersOpen = ref(false)
  const selectedAccId = ref('all')

  const collapsedAccIds = ref(new Set<string>())
  function toggleAcc(id: string) {
    const next = new Set(collapsedAccIds.value)
    if (next.has(id)) next.delete(id)
    else next.add(id)
    collapsedAccIds.value = next
  }

  // Counts pending applications + leave requests regardless of the current
  // search/status filter, so the badge still flags what needs attention even
  // when a property is collapsed or filtered out of view.
  const accAlertCounts = computed(() => {
    const map = new Map<string, number>()
    for (const acc of accommodations.value) {
      let count = 0
      for (const room of acc.rooms) {
        for (const l of room.leases) {
          if (l.status === 'pending' || l.status === 'leave_requested') count++
        }
      }
      map.set(acc.id, count)
    }
    return map
  })

  // Room count + occupied-tenant count per property, for the header subline —
  // also unfiltered, so it always reads as the property's real total.
  const accSummary = computed(() => {
    const map = new Map<string, { rooms: number; tenants: number; occupancyPct: number }>()
    for (const acc of accommodations.value) {
      let tenants = 0
      let capacity = 0
      for (const room of acc.rooms) {
        capacity += room.capacity ?? 0
        for (const l of room.leases) {
          if (l.status === 'active' || l.status === 'leave_requested') tenants++
        }
      }
      map.set(acc.id, { rooms: acc.rooms.length, tenants, occupancyPct: capacity ? Math.min(100, (tenants / capacity) * 100) : 0 })
    }
    return map
  })

  // Who lives in each property, for the stacked faces in its header — unfiltered
  // like the counts above, so searching never makes a property look emptier.
  const accTenants = computed(() => {
    const map = new Map<string, Lease[]>()
    for (const acc of accommodations.value) {
      map.set(acc.id, acc.rooms.flatMap((room) => room.leases.filter(isPayable)))
    }
    return map
  })

  // Accredited properties are the live ones. One whose accreditation lapsed
  // (expired permit, suspension) still has the tenants who moved in before, and
  // their stays and payments still need managing, so it stays while anyone lives there.
  const accreditedAccommodations = computed(() => accommodations.value.filter(
    (acc) => acc.status === 'accredited' || acc.rooms.some((room) => room.leases.length > 0),
  ))

  const visibleAccommodations = computed(() => {
    const q = query.value.trim().toLowerCase()
    return accreditedAccommodations.value
      .filter((acc) => selectedAccId.value === 'all' || acc.id === selectedAccId.value)
      .map((acc) => ({
        ...acc,
        rooms: acc.rooms
          .map((room) => ({
            ...room,
            leases: room.leases.filter((l) => {
              if (filter.value !== 'all' && l.status !== filter.value) return false
              if (!q) return true
              return (
                l.studentName.toLowerCase().includes(q) ||
                room.label.toLowerCase().includes(q) ||
                acc.name.toLowerCase().includes(q)
              )
            }),
          }))
          .filter((room) => (filter.value === 'all' && !q ? true : room.leases.length > 0)),
      }))
      .filter((acc) => acc.rooms.length > 0)
  })

  async function load(silent = false) {
    if (!silent) loading.value = true
    error.value = ''
    try {
      const { data: authData } = await authUser()
      const user = authData?.user
      if (!user) {
        error.value = 'Not logged in.'
        return
      }
      myId.value = user.id

      // Accommodations and leases both key only off the landlord/landlady's id, so they go
      // out together; rooms and payments each need an id list from this wave and
      // follow in the second one below.
      const [
        { data: accRows, error: accError },
        { data: leaseRows, error: leaseError },
      ] = await Promise.all([
        supabase
          .from('accommodations')
          .select('id,name,status,accommodation_images(url,sort_order)')
          .eq('landlord_id', user.id),
        supabase
          .from('leases')
          .select('id,status,room_id,student_id,start_date,monthly_rent,added_by_landlord,users!leases_student_id_fkey(full_name,avatar_color,avatar_url)')
          .eq('landlord_id', user.id)
          .neq('status', 'rejected'),
      ])
      if (accError) throw accError
      if (leaseError) throw leaseError

      const accIds = (accRows ?? []).map((a) => a.id)
      // Only current stays go on the room grid (the money panels load their own).
      const currentLeases = (leaseRows ?? []).filter((l) => ['active', 'pending', 'leave_requested'].includes(l.status))

      const { data: roomData, error: roomError } = accIds.length
        ? await supabase.from('rooms').select('id,label,room_number,capacity,status,accommodation_id').in('accommodation_id', accIds)
        : { data: [], error: null }
      if (roomError) throw roomError
      const roomRows = roomData ?? []

      const leasesByRoom = new Map<string, Lease[]>()
      for (const l of currentLeases) {
        const student = l.users as unknown as { full_name: string | null; avatar_color: string | null; avatar_url: string | null } | null
        const list = leasesByRoom.get(l.room_id) ?? []
        list.push({
          id: l.id,
          status: l.status,
          studentId: l.student_id,
          studentName: student?.full_name || 'A student',
          avatarColor: student?.avatar_color ?? null,
          avatarUrl: student?.avatar_url ? resolveAsset(student.avatar_url, AVATAR) : null,
          startDate: l.start_date,
          monthlyRent: Number(l.monthly_rent ?? 0),
          addedByLandlord: l.added_by_landlord,
        })
        leasesByRoom.set(l.room_id, list)
      }

      accommodations.value = (accRows ?? []).map((acc) => {
        const cover = [...((acc.accommodation_images ?? []) as { url: string; sort_order: number | null }[])].sort(
          (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0),
        )[0]
        return {
          id: acc.id,
          name: acc.name?.trim() || 'Unnamed accommodation',
          status: acc.status,
          coverUrl: cover?.url ? resolveAsset(cover.url, CARD) : '',
          rooms: roomRows
            .filter((r) => r.accommodation_id === acc.id)
            .map((r) => ({
              id: r.id,
              label: r.label || (r.room_number ? `Room ${r.room_number}` : 'Room'),
              capacity: r.capacity,
              status: r.status,
              leases: leasesByRoom.get(r.id) ?? [],
            })),
        }
      })
      // Closed by default — a landlord/landlady opens the properties they're checking,
      // rather than scrolling past every room in every property up front. Only
      // on the real first load: a silent (realtime-triggered) refresh must not
      // collapse whatever the landlord/landlady already has open.
      if (!silent) collapsedAccIds.value = new Set(accommodations.value.map((acc) => acc.id))

      loadVersion.value++
    } catch (e) {
      error.value = errorMessage(e, 'Something went wrong.')
    } finally {
      loading.value = false
    }
  }

  // Kept alive across tab switches (see MainLayout's KEEP_ALIVE_PAGES), so the
  // database pushes lease changes here instead of the page re-asking on every
  // return. utils/useLiveData.ts owns the whole policy — first load, the
  // subscription's lifetime, and how stale the data may be on return.
  const { refresh } = useLiveData({
    key: 'manager-tenants',
    load,
    // leases/payments are not in the realtime publication; every payment and
    // lease event notifies this user, so their notifications are the signal.
    watch: (uid) => [
      { table: 'leases', filter: `landlord_id=eq.${uid}` },
      { table: 'notifications', filter: `user_id=eq.${uid}` },
    ],
  })

  // Pull-to-refresh goes through useLiveData's refresh rather than load(): it
  // loads silently (no skeleton behind the spinner) and resets the freshness
  // clock, so returning to the screen does not immediately fetch again.
  function onPull(done: () => void) {
    void refresh().finally(done)
  }

  // Rent is stated as expected from leases.monthly_rent, not a collection/arrears
  // status — the payments table is too sparse against active leases to build that on.
  function leaseSubline(l: Lease): string {
    if (l.status === 'pending' && l.addedByLandlord) return `Awaiting QR check · move-in ${formatDate(l.startDate)}`
    if (l.status === 'pending') return `Requested move-in ${formatDate(l.startDate)}`
    const rent = l.monthlyRent ? `${formatPeso(l.monthlyRent)}/mo` : 'Rent not set'
    return `Since ${formatDate(l.startDate)} · ${rent}`
  }

  function accStatsLine(acc: Accommodation): string {
    const sum = accSummary.value.get(acc.id)
    const rooms = sum?.rooms ?? acc.rooms.length
    const tenants = sum?.tenants ?? 0
    const parts = [`${rooms} room${rooms === 1 ? '' : 's'}`, `${tenants} boarder${tenants === 1 ? '' : 's'}`]
    if (sum?.occupancyPct) parts.push(`${Math.round(sum.occupancyPct)}% full`)
    return parts.join(' · ')
  }

  function roomOccupancy(room: { leases: Lease[]; capacity: number | null }) {
    if (!room.capacity) return { label: `${room.leases.length} boarder${room.leases.length === 1 ? '' : 's'}`, full: false }
    const open = room.capacity - room.leases.length
    return open > 0 ? { label: `${open} open`, full: false } : { label: 'Full', full: true }
  }

  // Colors the property thumbnail's ring by how full it is — a fully rented
  // property is good news, so high occupancy reads green, not red.
  function occupancyTone(pct: number) {
    if (pct >= 90) return 'green'
    if (pct >= 50) return 'amber'
    return 'grey'
  }

  const decidingId = ref('')
  const addOpen = ref(false)

  const declineOpen = ref(false)
  const declineReason = ref('')
  const declineTarget = ref<{ lease: Lease } | null>(null)

  function openDecline(l: Lease) {
    declineTarget.value = { lease: l }
    declineReason.value = ''
    declineOpen.value = true
  }

  async function confirmDecline() {
    if (!declineTarget.value) return
    const { lease } = declineTarget.value
    await decideApplication(lease, 'rejected', declineReason.value.trim())
    declineOpen.value = false
    declineTarget.value = null
    declineReason.value = ''
  }

  async function decideApplication(l: Lease, decision: 'active' | 'rejected', reason?: string) {
    if (!(await requirePin({ confirm: decision === 'active', title: decision === 'active' ? 'Accept this application?' : 'Decline this application?', ...(decision === 'active' ? { message: 'They become the boarder of this room.' } : {}) }))) return
    if (decidingId.value) return
    decidingId.value = l.id
    try {
      await respondToApplication(l.id, decision, reason)
      if (decision === 'rejected') {
        for (const acc of accommodations.value) {
          for (const room of acc.rooms) room.leases = room.leases.filter((r) => r.id !== l.id)
        }
      } else {
        l.status = 'active'
      }
      notify.success(decision === 'active' ? 'Application accepted.' : 'Application declined.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not update this application.'))
    } finally {
      decidingId.value = ''
    }
  }

  function isPayable(l: Lease) {
    return l.status === 'active' || l.status === 'leave_requested'
  }

  // Log a payment and Add a student both start from the list: it becomes the
  // picker — a boarder for a payment, a room with an open bed for a student —
  // and everything else is disabled until one is tapped or picking is cancelled.
  // Every property opens, since a collapsed one hides what there is to pick.
  const picking = ref<'payment' | 'room' | null>(null)
  function togglePicking(mode: 'payment' | 'room') {
    picking.value = picking.value === mode ? null : mode
    if (picking.value) collapsedAccIds.value = new Set()
  }

  const paymentOpen = ref(false)
  const paymentLease = ref<Lease | null>(null)
  function pickLease(l: Lease) {
    if (!isPayable(l)) return
    picking.value = null
    paymentLease.value = l
    paymentOpen.value = true
  }

  // add_student_to_room takes only an 'available' room, and a full one has no bed.
  function hasOpenBed(room: Room) {
    return room.status === 'available' && (!room.capacity || room.leases.length < room.capacity)
  }
  const addRoom = ref<{ id: string; label: string; accommodation: string } | null>(null)
  function pickRoom(acc: Accommodation, room: Room) {
    if (!hasOpenBed(room)) return
    picking.value = null
    addRoom.value = { id: room.id, label: room.label, accommodation: acc.name }
    addOpen.value = true
  }

  return {
    router,
    notify,
    loading,
    error,
    myId,
    accommodations,
    activeTab,
    route,
    split,
    panelsIs,
    panelIs,
    panelsProps,
    loadVersion,
    toConfirm,
    query,
    filter,
    filtersOpen,
    selectedAccId,
    collapsedAccIds,
    toggleAcc,
    accAlertCounts,
    accSummary,
    accTenants,
    accreditedAccommodations,
    visibleAccommodations,
    load,
    refresh,
    onPull,
    leaseSubline,
    accStatsLine,
    roomOccupancy,
    occupancyTone,
    decidingId,
    addOpen,
    declineOpen,
    declineReason,
    declineTarget,
    openDecline,
    confirmDecline,
    decideApplication,
    isPayable,
    picking,
    togglePicking,
    paymentOpen,
    paymentLease,
    pickLease,
    hasOpenBed,
    addRoom,
    pickRoom,
  }
}
