// Re-reading the handshake from the database, one refresh at a time, and the
// checks that decide whether a student may apply.
import { type Seed } from './model'
import { UTILITY_SELECT, utilitiesFromRow } from '@/utils/listings'
import { formatPeso, landlordTitle } from '@/utils/format'
import { roomLabelOf, todayStr } from './model'
import { stampInquiryRoom } from '@/utils/applications'
import { supabase } from '@/utils/supabase'
import type { createApplicationState } from './state'

export function createApplicationRefresh(ctx: Seed & ReturnType<typeof createApplicationState>) {
  const { props, emit, application, applyRoom, otherTitle, applyUnavailable, applyForm, inquiryRoom, invitedRoomId, otherLease, declined, applyBlocked, owesPast } = ctx

  // refresh() runs from three places (mount, every incoming realtime message, and
  // after each action), so several can be in flight at once. Without this they all
  // read the same pre-stamp state, all decide the inquiry has changed, and each
  // posts its own "Asking about Room 3." — which is how four identical system
  // messages ended up in one thread. Collapsing concurrent calls onto one promise
  // is the same trick the router guard uses for its role lookup.
  let refreshing: Promise<void> | null = null
  /** Rooms this instance has already announced; the emit is not idempotent. */
  let announcedRoom: string | null = null

  function refresh(): Promise<void> {
    if (refreshing) return refreshing
    refreshing = runRefresh().finally(() => {
      refreshing = null
    })
    return refreshing
  }

  async function runRefresh() {
    const studentId = props.role === 'student' ? props.me : props.otherId
    const managerId = props.role === 'student' ? props.otherId : props.me
    if (!studentId || !managerId) return

    // At most one of these can exist: leases_one_current_per_student is a UNIQUE
    // index on student_id over ('pending','active','leave_requested'). Reading the
    // student's lease across ALL landlords/landladies, not just this thread's, is what stops a
    // form being offered to someone already housed — that insert can only ever
    // fail on the index, as a raw 409 after they have filled the form in.
    const { data: current } = await supabase
      .from('leases')
      .select(`id,status,start_date,end_date,monthly_rent,landlord_id,${UTILITY_SELECT},rooms(label,room_number)`)
      .eq('student_id', studentId)
      .in('status', ['pending', 'active', 'leave_requested'])
      .maybeSingle()

    const currentLabel = roomLabelOf(current?.rooms as never)

    if (current && current.status === 'pending' && current.landlord_id === managerId) {
      application.value = {
        leaseId: current.id,
        roomLabel: currentLabel,
        startDate: current.start_date,
        endDate: current.end_date,
        monthlyRent: Number(current.monthly_rent ?? 0),
        utilities: utilitiesFromRow(current),
      }
      otherLease.value = null
      declined.value = null
      return
    }

    application.value = null
    // A stay or application that is not this thread's business. Nothing can be
    // offered or submitted here until it ends.
    otherLease.value = current
      ? {
          leaseId: current.id,
          status: current.status,
          roomLabel: currentLabel,
          managerId: current.landlord_id,
        }
      : null

    // Why the last attempt failed. The system message saying so scrolls out of
    // sight, and the notification is long gone by the time they come back.
    // leases has no created_at, so the requested move-in is the best ordering key.
    const { data: refused } = await supabase
      .from('leases')
      .select('decision_reason,rooms(label,room_number)')
      .eq('student_id', studentId)
      .eq('landlord_id', managerId)
      .eq('status', 'rejected')
      .not('decision_reason', 'is', null)
      .order('start_date', { ascending: false })
      .limit(1)
      .maybeSingle()
    declined.value = refused?.decision_reason
      ? { roomLabel: roomLabelOf(refused.rooms as never), reason: refused.decision_reason }
      : null

    if (props.role === 'student') applyBlocked.value = await whyApplyBlocked()

    const { data: convo } = await supabase
      .from('conversations')
      .select('inquiry_room_id,invited_room_id')
      .eq('id', props.conversationId)
      .maybeSingle()

    // Arriving from a room page records what the student is asking about, so the
    // landlord/landlady's side of the thread knows which form to offer — before this the room
    // lived only in the student's URL. Stamped only when it CHANGES, or re-opening
    // the thread would re-post the system message every time.
    let inquiryId = convo?.inquiry_room_id ?? null
    if (
      props.roomId &&
      props.role === 'student' &&
      props.roomId !== inquiryId &&
      props.roomId !== announcedRoom
    ) {
      // Claimed before the first await, so a call that starts while this one is
      // mid-flight cannot reach the emit as well. The lease-closed trigger clears
      // inquiry_room_id, which would otherwise make an open thread re-announce
      // the same room every time it refreshed.
      announcedRoom = props.roomId
      const label = await fetchRoomLabel(props.roomId)
      const changed = await stampInquiryRoom(props.conversationId, props.roomId)
      inquiryId = props.roomId
      inquiryRoom.value = { id: inquiryId, label }
      if (changed) emit('system', `Asking about ${label}.`)
    } else {
      inquiryRoom.value = inquiryId ? { id: inquiryId, label: await fetchRoomLabel(inquiryId) } : null
    }

    // A men's or women's house is said up front, not after the form is asked for.
    if (props.role === 'student' && !applyBlocked.value && inquiryRoom.value) {
      applyBlocked.value = await genderBlock(inquiryRoom.value.id)
    }

    // The apply form opens only for a room the landlord/landlady has actually issued one for,
    // and only on the student's side — the landlord/landlady sees that it is out, not the form.
    invitedRoomId.value = convo?.invited_room_id ?? null
    if (invitedRoomId.value && props.role === 'student' && !otherLease.value) {
      await loadApplyRoom(invitedRoomId.value)
    }
  }

  async function fetchRoomLabel(roomId: string): Promise<string> {
    const { data } = await supabase
      .from('rooms')
      .select('label,room_number')
      .eq('id', roomId)
      .maybeSingle()
    return roomLabelOf(data)
  }

  /** Student nudge. Holds no state beyond the transcript line and the notification. */

  async function loadApplyRoom(roomId: string) {
    const { data } = await supabase
      .from('rooms')
      .select(
        `id,label,room_number,monthly_rent,capacity,rent_basis,status,advance_months,deposit_months,${UTILITY_SELECT},accommodations(name,landlord_id)`,
      )
      .eq('id', roomId)
      .maybeSingle()

    const acc = data?.accommodations as unknown as {
      name: string | null
      landlord_id: string | null
    } | null

    if (!data || !acc || acc.landlord_id !== props.otherId || data.status !== 'available') {
      applyRoom.value = null
      applyUnavailable.value = Boolean(data)
      return
    }

    applyForm.startDate = todayStr()
    const { data: other } = await supabase.from('users').select('sex').eq('id', props.otherId).maybeSingle()
    otherTitle.value = landlordTitle(other?.sex).toLowerCase()
    applyRoom.value = {
      id: data.id,
      label: data.label || (data.room_number ? `Room ${data.room_number}` : 'Room'),
      accommodation: acc.name || 'This accommodation',
      rent: Number(data.monthly_rent ?? 0),
      capacity: data.capacity ?? 1,
      rentBasis: data.rent_basis === 'person' ? 'person' : 'room',
      advanceMonths: Number(data.advance_months ?? 0),
      depositMonths: Number(data.deposit_months ?? 0),
      utilities: utilitiesFromRow(data),
    }
  }

  /**
   * Asks the database the same question the lease insert policy asks, rather than
   * a second reading of it: a client that asks the database its own question
   * cannot drift from it. The one answer covers "turned down or suspended" and
   * "OSAS paused applications"; only the second has a reason worth reading out.
   * Not being verified yet is no longer one of them (migration 20261009020000):
   * that gates the acceptance, not the application.
   */
  async function whyApplyBlocked(): Promise<string | null> {
    // Owing on a past stay blocks a new one (guard_lease_writes); say so before
    // a form is asked for, not after it has been filled in.
    const { data: owed } = await supabase.rpc('past_stay_balance', { p_student: props.me })
    owesPast.value = Number(owed ?? 0) > 0.009
    if (owesPast.value) return `You still owe ${formatPeso(Number(owed))} on a past stay. Pay it first, then you can apply for a room.`
    const { data: mayApply } = await supabase.rpc('student_may_apply', { p_student: props.me })
    if (mayApply === true) return null
    const { data: standing } = await supabase
      .from('account_standing')
      .select('reason, restrictions')
      .eq('user_id', props.me)
      .maybeSingle()
    return standing?.restrictions?.includes('apply')
      ? `OSAS has paused your room applications.${standing.reason ? ` ${standing.reason}` : ''}`
      : 'OSAS has turned down or suspended your account, so you cannot apply for a room. Open OSAS from your profile to sort it out.'
  }

  /**
   * Who the house takes, against the student's sex on record — the same rule
   * assert_gender_fits() holds the invite, the application and the acceptance to.
   */
  async function genderBlock(roomId: string): Promise<string | null> {
    const [{ data: room }, { data: me }] = await Promise.all([
      supabase.from('rooms').select('accommodations(gender_policy)').eq('id', roomId).maybeSingle(),
      supabase.from('users').select('sex').eq('id', props.me).maybeSingle(),
    ])
    const policy = (room?.accommodations as unknown as { gender_policy: string | null } | null)?.gender_policy
    const sex = (me?.sex ?? '').trim().toUpperCase()
    if (policy === 'male' && sex !== 'M') return 'This accommodation only takes male students.'
    if (policy === 'female' && sex !== 'F') return 'This accommodation only takes female students.'
    return null
  }

  return {
    refreshing,
    announcedRoom,
    refresh,
    runRefresh,
    fetchRoomLabel,
    loadApplyRoom,
    whyApplyBlocked,
    genderBlock,
  }
}
