// The landlord/landlady home's data: portfolio, to-do list and money, loaded
// in two waves and kept fresh (and cached) by useLiveData.
import { CARD, resolveAsset } from '@/utils/cloudinaryUrl'
import { type LateAction, type Rent, rentSummary } from './money'
import { type Property } from '@/components/manager/property'
import { type Task } from '@/components/shared/dashboard'
import { authUser, supabase } from '@/utils/supabase'
import { concernTasks, paymentTasks, peopleTasks, permitTasks, profileTasks, standingTasks, titleCase, utilityTasks } from './tasks'
import { fetchLandlordMoney } from '@/api/landlordMoney'
import { loadProfileGaps } from '@/utils/profile'
import { ref } from 'vue'
import { useLiveData } from '@/utils/useLiveData'
import { useRouter } from 'vue-router'

export function useManagerDashboard() {
  const router = useRouter()

  const loading = ref(true)
  const error = ref('')
  const firstName = ref('there')
  const properties = ref<Property[]>([])
  const attention = ref<Task[]>([])
  const totalBeds = ref(0)
  const tenants = ref(0)

  // Money, worked out in load() so the kept-alive page and its cache hold plain numbers.

  const rent = ref<Rent>({ collected: 0, coming: 0, late: 0, total: 0 })
  const propRent = ref<Record<string, { paid: number; due: number; dot: boolean }>>({})
  const lateAction = ref<LateAction | null>(null)
  const confirmCount = ref(0)
  const unpaidBills = ref<{ amount: number; sub: string }>({ amount: 0, sub: 'All paid' })
  const applicants = ref<{ count: number; sub: string; route: string }>({ count: 0, sub: 'None new', route: '/manager/tenants' })
  const docsSentAt = ref<string | null>(null)
  const profileComplete = ref(true)

  async function load(silent = false) {
    if (!silent) loading.value = true
    error.value = ''
    try {
      const { data: auth } = await authUser()
      const user = auth?.user
      if (!user) {
        void router.push('/login')
        return
      }

      // Everything keyed only off the landlord/landlady's own id goes out at once. These
      // ran as nine round trips in series, which was comfortably the slowest
      // thing about the first screen a landlord/landlady sees.
      const [
        { data: profile },
        { data: accRows, error: accError },
        { data: leaseRows, error: leaseError },
        { data: concernRows },
        { data: peopleRows },
        { count: paymentsToVerify },
        { data: docRowsSent },
        money,
      ] = await Promise.all([
        supabase.from('users').select('full_name').eq('id', user.id).maybeSingle(),
        supabase
          .from('accommodations')
          .select('id, name, status, address, barangay, purok, city, accommodation_type, total_rooms')
          .eq('landlord_id', user.id),
        supabase
          .from('leases')
          .select('id, status, monthly_rent, room_id')
          .eq('landlord_id', user.id)
          .in('status', ['active', 'pending', 'leave_requested']),
        supabase
          .from('concerns')
          .select(
            'id, category, reported_at, leases!inner(landlord_id, users!leases_student_id_fkey(full_name), rooms(accommodations(name)))',
          )
          .eq('leases.landlord_id', user.id)
          .neq('status', 'resolved')
          .order('reported_at', { ascending: false })
          .limit(6),
        supabase
          .from('leases')
          .select(
            'id, status, start_date, leave_requested_at, users!leases_student_id_fkey(full_name), rooms(room_number, accommodations(name))',
          )
          .eq('landlord_id', user.id)
          .in('status', ['pending', 'leave_requested'])
          .limit(6),
        // Only the number: the list itself lives on Tenants → Payments.
        supabase
          .from('payments')
          .select('id, leases!inner(landlord_id)', { count: 'exact', head: true })
          .eq('leases.landlord_id', user.id)
          .eq('status', 'pending_verification'),
        // "Sent Oct 13" on the verification hero: the newest upload.
        supabase
          .from('verification_documents')
          .select('uploaded_at')
          .eq('user_id', user.id)
          .order('uploaded_at', { ascending: false })
          .limit(1),
        // A failed money read leaves the rent card at zero rather than blanking the whole screen.
        fetchLandlordMoney(user.id).catch((e) => {
          console.warn('dashboard: money read failed', e)
          return null
        }),
      ])
      if (accError) throw accError
      if (leaseError) throw leaseError

      firstName.value = String(profile?.full_name || 'there').split(' ')[0] || 'there'

      const accs = accRows || []
      const accIds = accs.map((a) => a.id)
      const accName = new Map(accs.map((a) => [a.id, a.name]))

      // Second wave: rooms, photos and permits all key off the accommodation ids
      // above, so they couldn't join the first — but they can go out together.
      // Skipped entirely for a landlord/landlady with no accommodations, which is half of
      // them (see the data notes in CLAUDE.md).
      let roomRows: {
        id: string
        accommodation_id: string
        capacity: number | null
        water_billing: string | null
        electric_billing: string | null
        wifi_billing: string | null
      }[] = []
      let imageRows: { accommodation_id: string; url: string; sort_order: number | null }[] = []
      let docRows: {
        id: string
        doc_type: string
        expires_at: string | null
        accommodation_id: string
      }[] = []
      if (accIds.length) {
        const [rooms, images, docs] = await Promise.all([
          supabase
            .from('rooms')
            .select('id, accommodation_id, capacity, water_billing, electric_billing, wifi_billing')
            .in('accommodation_id', accIds),
          supabase
            .from('accommodation_images')
            .select('accommodation_id, url, sort_order')
            .in('accommodation_id', accIds)
            .order('sort_order', { ascending: true }),
          supabase
            .from('accommodation_documents')
            .select('id, doc_type, expires_at, accommodation_id')
            .in('accommodation_id', accIds),
        ])
        if (rooms.error) throw rooms.error
        roomRows = rooms.data || []
        imageRows = images.data || []
        docRows = docs.data || []
      }

      const leases = leaseRows || []
      const roomToAcc = new Map(roomRows.map((r) => [r.id, r.accommodation_id]))
      const filledByAcc = new Map<string, number>()
      for (const l of leases) {
        if (l.status !== 'active') continue
        const accId = roomToAcc.get(l.room_id)
        if (accId) filledByAcc.set(accId, (filledByAcc.get(accId) || 0) + 1)
      }

      const capacityByAcc = new Map<string, number>()
      const roomCountByAcc = new Map<string, number>()
      for (const r of roomRows) {
        capacityByAcc.set(r.accommodation_id, (capacityByAcc.get(r.accommodation_id) || 0) + Number(r.capacity || 0))
        roomCountByAcc.set(r.accommodation_id, (roomCountByAcc.get(r.accommodation_id) || 0) + 1)
      }

      totalBeds.value = roomRows.reduce((n, r) => n + Number(r.capacity || 0), 0)
      tenants.value = leases.filter((l) => l.status === 'active').length
      docsSentAt.value = (Array.isArray(docRowsSent) ? docRowsSent[0]?.uploaded_at : null) ?? null

      // A photo per accommodation, fetched once for the whole portfolio.
      const photoByAcc = new Map<string, string>()
      for (const img of imageRows) {
        if (!photoByAcc.has(img.accommodation_id)) {
          photoByAcc.set(img.accommodation_id, resolveAsset(img.url, CARD))
        }
      }

      // Document tracking
      const { items: permitItems, expiredByAcc, expiringSoonByAcc } = permitTasks(docRows, accName)

      const items: Task[] = [...permitItems, ...utilityTasks(roomRows, accName)]

      properties.value = accs.map((a) => ({
        id: a.id,
        name: a.name,
        status: a.status,
        type: titleCase(a.accommodation_type),
        address: a.address || [a.purok, a.barangay, a.city].filter(Boolean).join(', '),
        roomCount: a.total_rooms ?? roomCountByAcc.get(a.id) ?? null,
        capacity: capacityByAcc.get(a.id) || 0,
        filled: filledByAcc.get(a.id) || 0,
        image: photoByAcc.get(a.id) || '',
        expired: expiredByAcc.get(a.id) || 0,
        expiringSoon: expiringSoonByAcc.get(a.id) || 0,
      }))

      // Rest of attention items (concerns, applications, leave requests). Both
      // sets were fetched in the first wave; the ordering here still decides
      // where they land among the equal-rank items, since the sort below is
      // stable.
      items.push(...concernTasks(concernRows), ...paymentTasks(paymentsToVerify), ...peopleTasks(peopleRows))

      // OSAS has hidden their listings (account_standing, written only by OSAS):
      // the first thing they should read, with the reason OSAS gave.
      const { data: standing } = await supabase
        .from('account_standing')
        .select('reason, restrictions')
        .eq('user_id', user.id)
        .maybeSingle()
      items.push(...standingTasks(standing))

      // Sex and birth date are blank on older accounts; one row opens the step-by-step flow.
      const missing = (await loadProfileGaps(user.id, false)).filter((g) => g.needed)
      items.push(...profileTasks(missing))

      attention.value = items.sort((a, b) => a.rank - b.rank)

      profileComplete.value = missing.length === 0

      // Applicants: pending leases, named from the first-wave people query.
      const pendingCount = leases.filter((l) => l.status === 'pending').length
      const firstPending = (peopleRows || []).find((l) => l.status === 'pending')
      const pRoom = firstPending?.rooms as unknown as { room_number: string | null } | null
      const pName = (firstPending?.users as unknown as { full_name: string } | null)?.full_name?.split(' ')[0]
      applicants.value = {
        count: pendingCount,
        sub: pName ? `${pName}${pRoom?.room_number ? ` · Room ${pRoom.room_number}` : ''}` : pendingCount ? 'Waiting on you' : 'None new',
        route: firstPending ? `/manager/tenant/${firstPending.id}` : '/manager/tenants',
      }

      // Rent card, late boarder, bills and per-property rent: all the same buildCollections the
      // Payments tab uses, so the numbers cannot disagree with it.
      const summary = rentSummary(money, properties.value)
      rent.value = summary.rent
      propRent.value = summary.propRent
      lateAction.value = summary.lateAction
      confirmCount.value = summary.confirmCount
      unpaidBills.value = summary.unpaidBills
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Something went wrong.'
    } finally {
      loading.value = false
    }
  }

  // Kept alive across tab switches (see MainLayout's KEEP_ALIVE_PAGES), so the
  // database pushes lease changes here instead of the page re-asking on every
  // return. utils/useLiveData.ts owns the whole policy — first load, the
  // subscription's lifetime, and how stale the data may be on return.
  type DashboardCache = {
    firstName: string
    properties: Property[]
    attention: Task[]
    totalBeds: number
    tenants: number
    rent: Rent
    propRent: Record<string, { paid: number; due: number; dot: boolean }>
    lateAction: LateAction | null
    confirmCount: number
    unpaidBills: { amount: number; sub: string }
    applicants: { count: number; sub: string; route: string }
    docsSentAt: string | null
    profileComplete: boolean
  }

  const { refresh } = useLiveData({
    // -v2: the 2026-10 redesign changed the cached shape (rent, tiles); an old
    // cache restored into it crashed the render on first launch after updating.
    key: 'manager-dashboard-v2',
    load,
    // leases/payments are not in the realtime publication; every payment and
    // lease event notifies this user, so their notifications are the signal.
    watch: (uid) => [
      { table: 'leases', filter: `landlord_id=eq.${uid}` },
      { table: 'notifications', filter: `user_id=eq.${uid}` },
    ],
    cache: {
      get: (): DashboardCache => ({
        firstName: firstName.value,
        properties: properties.value,
        attention: attention.value,
        totalBeds: totalBeds.value,
        tenants: tenants.value,
        rent: rent.value,
        propRent: propRent.value,
        lateAction: lateAction.value,
        confirmCount: confirmCount.value,
        unpaidBills: unpaidBills.value,
        applicants: applicants.value,
        docsSentAt: docsSentAt.value,
        profileComplete: profileComplete.value,
      }),
      set: (d) => {
        const c = d as DashboardCache
        firstName.value = c.firstName
        properties.value = c.properties
        attention.value = c.attention
        totalBeds.value = c.totalBeds
        tenants.value = c.tenants
        rent.value = c.rent
        propRent.value = c.propRent
        lateAction.value = c.lateAction
        confirmCount.value = c.confirmCount
        unpaidBills.value = c.unpaidBills
        applicants.value = c.applicants
        docsSentAt.value = c.docsSentAt
        profileComplete.value = c.profileComplete
        loading.value = false
      },
    },
  })

  // Pull-to-refresh goes through useLiveData's refresh rather than load(): it
  // loads silently (no skeleton behind the spinner) and resets the freshness
  // clock, so returning to the screen does not immediately fetch again.
  function onPull(done: () => void) {
    void refresh().finally(done)
  }

  return {
    router,
    loading,
    error,
    firstName,
    properties,
    attention,
    totalBeds,
    tenants,
    rent,
    propRent,
    lateAction,
    confirmCount,
    unpaidBills,
    applicants,
    docsSentAt,
    profileComplete,
    load,
    refresh,
    onPull,
  }
}
