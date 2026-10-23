// The student home's data: the stay, verification, the to-do list and what
// is owed, loaded and kept fresh (and partly cached) by useLiveData.
import { AVATAR, CARD, resolveAsset } from '@/utils/cloudinaryUrl'
import { LANDLORD_ROLE_LABEL, initialsOf, landlordTitle } from '@/utils/format'
import { type LedgerRow, nextLedgerRent, toLedger } from '@/utils/payments'
import { type Manager, type NextPayment, type Stay } from '@/components/student/dashboard'
import { type Task } from '@/components/shared/dashboard'
import { applicationTasks, billTasks, concernTasks, overdueRentTasks, profileTasks, standingTasks, stayTasks, unreadTasks, verificationTasks } from './tasks'
import { authUser, supabase } from '@/utils/supabase'
import { loadProfileGaps } from '@/utils/profile'
import { ref } from 'vue'
import { useLiveData } from '@/utils/useLiveData'
import { useRouter } from 'vue-router'

export function useStudentHome() {
  const router = useRouter()

  const loading = ref(true)
  const error = ref('')
  const firstName = ref('there')
  const stay = ref<Stay | null>(null)
  const tasks = ref<Task[]>([])
  const nextPayment = ref<NextPayment | null>(null)
  const manager = ref<Manager | null>(null)

  // What the verification hero and the OSAS tile are drawn from. Cached with the
  // rest: it is status and dates only, nothing financial.
  const ver = ref({ status: 'unverified', docsSentAt: null as string | null, profileComplete: true, since: null as string | null })
  const stayLedger = ref<LedgerRow[]>([])
  // Unread messages: from this stay's landlord/landlady when there is one, else from anyone.
  const unread = ref(0)
  const past = ref<{ count: number; unrated: string | null }>({ count: 0, unrated: null })

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

      const { data: profile } = await supabase
        .from('users')
        .select('full_name, status')
        .eq('id', user.id)
        .maybeSingle()
      firstName.value = String(profile?.full_name || 'there').split(' ')[0] || 'there'
      const verification = profile?.status || 'unverified'
      // Why OSAS put the account in this state, and what it is restricted from.
      // Its own table because only the student and OSAS may read it.
      const { data: standing } = await supabase
        .from('account_standing')
        .select('reason, restrictions')
        .eq('user_id', user.id)
        .maybeSingle()

      // Latest upload = "Sent Oct 13" on the verification hero; the pending ones decide
      // the wording of the OSAS task below. osas_verified_at feeds the OSAS tile.
      const [{ data: docs }, { data: sp }] = await Promise.all([
        supabase.from('verification_documents').select('status, uploaded_at').eq('user_id', user.id).order('uploaded_at', { ascending: false }),
        supabase.from('student_profiles').select('osas_verified_at').eq('user_id', user.id).maybeSingle(),
      ])
      const docRows = docs ?? []

      let ledger: LedgerRow[] = []
      // A student holds at most one live lease, so one row is enough.
      const { data: leaseRow, error: leaseError } = await supabase
        .from('leases')
        .select(
          'id, status, start_date, end_date, monthly_rent, room_id, rooms(room_number, label, monthly_rent, accommodations(id, name, landlord_id, lat, lng))',
        )
        .eq('student_id', user.id)
        .in('status', ['active', 'pending', 'leave_requested'])
        .order('start_date', { ascending: false })
        .limit(1)
        .maybeSingle()
      if (leaseError) throw leaseError

      type AccommodationEmbed = {
        id: string
        name: string
        landlord_id: string
        lat: number | null
        lng: number | null
      } | null

      if (leaseRow) {
        const room = leaseRow.rooms as unknown as {
          room_number: string | null
          label: string | null
          monthly_rent: number | null
          accommodations: AccommodationEmbed
        } | null
        const acc = room?.accommodations ?? null

        // Only the cover photo — house rules live on /student/stay, which shows
        // all of them instead of an arbitrary first three.
        let photoUrl = ''
        if (acc?.id) {
          const { data: imageRows } = await supabase
            .from('accommodation_images')
            .select('url, sort_order')
            .eq('accommodation_id', acc.id)
            .order('sort_order', { ascending: true })
            .limit(1)
          photoUrl = imageRows?.[0]?.url ? resolveAsset(imageRows[0].url, CARD) : ''
        }

        stay.value = {
          id: leaseRow.id,
          status: leaseRow.status,
          startDate: leaseRow.start_date,
          endDate: leaseRow.end_date,
          monthlyRent: Number(leaseRow.monthly_rent ?? room?.monthly_rent ?? 0),
          accommodationId: acc?.id ?? '',
          accommodationName: acc?.name || 'Your accommodation',
          roomNumber: room?.room_number ?? null,
          roomLabel: room?.label ?? null,
          lat: acc?.lat ?? null,
          lng: acc?.lng ?? null,
          photoUrl,
          moveIn: null,
        }

        // Read off the ledger. These used to come from leases.advance_paid and
        // deposit_paid, which nothing ever writes, so both read "not yet paid"
        // for every stay forever.
        if (leaseRow.status !== 'pending') {
          const { data: rows } = await supabase.rpc('lease_ledger', { p_lease: leaseRow.id })
          ledger = toLedger(rows)
          const upFront = ledger.filter((r) => r.kind === 'deposit' || (r.kind === 'rent' && r.dueDate === leaseRow.start_date))
          const due = upFront.reduce((s, r) => s + r.due, 0)
          if (due > 0.009) stay.value.moveIn = { due, left: upFront.reduce((s, r) => s + r.balance, 0) }
        }
      } else {
        stay.value = null
        manager.value = null
      }

      if (leaseRow) {
        const room = leaseRow.rooms as unknown as {
          accommodations: { landlord_id: string } | null
        } | null
        const managerId = room?.accommodations?.landlord_id

        // No rating on the landlord/landlady card. It used to average
        // landlord ratings (`reviews`) filtered to this landlord/landlady, but RLS only
        // ever returned the reviews *this student* had written — so the number
        // shown was the student's own score played back at them. Students don't
        // see ratings while browsing either, so there is nothing to replace it
        // with; the card is name, response time and the actions.
        if (managerId) {
          const [{ data: mgr }, { data: mgrProfile }] = await Promise.all([
            supabase.from('users').select('full_name, initials, avatar_url, sex').eq('id', managerId).maybeSingle(),
            supabase
              .from('landlord_profiles')
              .select('avg_response_minutes')
              .eq('user_id', managerId)
              .maybeSingle(),
          ])
          if (mgr) {
            manager.value = {
              id: managerId,
              name: mgr.full_name,
              initials: mgr.initials || initialsOf(mgr.full_name),
              avatarUrl: mgr.avatar_url ? resolveAsset(mgr.avatar_url, AVATAR) : null,
              replyMinutes: mgrProfile?.avg_response_minutes ?? null,
              title: landlordTitle(mgr.sex),
            }
          }
        }
      }

      const list: Task[] = []
      // The student's own landlord or landlady once known, else the neutral compound.
      const who = (manager.value?.title ?? LANDLORD_ROLE_LABEL).toLowerCase()

      list.push(...standingTasks(standing))

      // Verification: whether they must act depends on what they have already
      // submitted, so the pending documents decide the wording and the action.
      list.push(...verificationTasks(verification, docRows, standing))

      // Whatever is still blank on the profile — student ID (freshmen register before
      // ISU issues one), emergency contact, and sex/birth date on older accounts —
      // chased as one row that opens the step-by-step flow.
      const missing = (await loadProfileGaps(user.id, true)).filter((g) => g.needed)
      ver.value = { status: verification, docsSentAt: docRows[0]?.uploaded_at ?? null, profileComplete: missing.length === 0, since: sp?.osas_verified_at ?? null }
      list.push(...profileTasks(missing))

      list.push(...applicationTasks(leaseRow?.status, who))

      list.push(...stayTasks(stay.value, who))

      if (leaseRow) {
        // Concerns the student filed against this stay, and any reply.
        const { data: concernRows } = await supabase
          .from('concerns')
          .select('id, category, status, reported_at, manager_response')
          .eq('lease_id', leaseRow.id)
          .neq('status', 'resolved')
          .order('reported_at', { ascending: false })
          .limit(4)

        list.push(...concernTasks(concernRows, who))

        // A payment that is merely due is shown by the stay card's money strip, which is
        // tappable — only an overdue one is a task. Read off the ledger: this
        // used to look for payments rows with status due/overdue, which nothing
        // has written since record_payments, so it always said "Nothing due".
        const due = nextLedgerRent(ledger)
        nextPayment.value = due?.month
          ? { amount: due.balance, month: due.month, dueDate: due.dueDate, overdue: due.state === 'overdue' }
          : null

        // Utility bills the landlord/landlady posted and nobody has paid yet.
        const { data: billRows } = await supabase
          .from('utility_bills')
          .select('id, utility, month, amount, due_date, payments(status, amount)')
          .eq('lease_id', leaseRow.id)
        list.push(...billTasks(billRows))

        list.push(...overdueRentTasks(due))
      } else {
        nextPayment.value = null
      }
      stayLedger.value = ledger

      // Unread messages from the landlord/landlady.
      const { data: convos } = await supabase
        .from('conversations')
        .select('user_a_id, user_b_id, unread_a, unread_b')
        .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
      const totalUnread = (convos || []).reduce((n, c) => {
        const mine = c.user_a_id === user.id ? c.unread_a : c.unread_b
        return n + Number(mine || 0)
      }, 0)
      unread.value = leaseRow && manager.value
        ? (convos || []).filter((c) => c.user_a_id === manager.value?.id || c.user_b_id === manager.value?.id).reduce((n, c) => n + Number((c.user_a_id === user.id ? c.unread_a : c.unread_b) || 0), 0)
        : totalUnread
      list.push(...unreadTasks(totalUnread, who))

      // Past stays for the History / "Rate X" tile. Ended leases the student has
      // not reviewed yet (accommodation or landlord review) are what "Rate" waits on.
      const [{ data: endedLeases }, { data: written }] = await Promise.all([
        supabase
          .from('leases')
          .select('id, rooms(accommodations(name))')
          .eq('student_id', user.id)
          .in('status', ['ended', 'terminated'])
          .order('end_date', { ascending: false }),
        supabase.from('review_written_leases').select('lease_id').in('kind', ['accommodation', 'manager']),
      ])
      const reviewed = new Set((written ?? []).map((r) => r.lease_id))
      const unrated = (endedLeases ?? []).find((l) => !reviewed.has(l.id))
      past.value = {
        count: endedLeases?.length ?? 0,
        unrated: unrated ? (unrated.rooms as unknown as { accommodations: { name: string } | null } | null)?.accommodations?.name ?? 'your last stay' : null,
      }

      tasks.value = list.sort((a, b) => a.rank - b.rank)
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
  // Only the low-stakes fields are cached to disk — stay/nextPayment carry
  // rent and payment amounts, same bar that keeps StudentStayPage out of this
  // entirely (see persistCache.ts). Those two stay RAM-only and just show
  // their loading state again on a fresh launch.
  type DashboardCache = { firstName: string; tasks: Task[]; manager: Manager | null; ver: typeof ver.value }

  const { refresh } = useLiveData({
    // -v2: the 2026-10 redesign added `ver` to the cached shape.
    key: 'student-dashboard-v2',
    load,
    watch: (uid) => [{ table: 'leases', filter: `student_id=eq.${uid}` }],
    cache: {
      get: (): DashboardCache => ({ firstName: firstName.value, tasks: tasks.value, manager: manager.value, ver: ver.value }),
      set: (d) => {
        const c = d as DashboardCache
        firstName.value = c.firstName
        tasks.value = c.tasks
        manager.value = c.manager
        if (c.ver) ver.value = c.ver
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
    stay,
    tasks,
    nextPayment,
    manager,
    ver,
    stayLedger,
    unread,
    past,
    load,
    refresh,
    onPull,
  }
}
