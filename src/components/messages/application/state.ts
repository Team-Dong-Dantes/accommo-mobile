// Where this conversation's application stands, and what follows from it:
// the move-in totals, the student's step, whether another stay blocks it.
import { type RoomBrief, addMonths, todayStr } from './model'
import { type Seed } from './model'
import { UTILITIES, type UtilityKey, type UtilityTerms } from '@/utils/listings'
import { computed, reactive, ref } from 'vue'
import { landlordTitle } from '@/utils/format'
import { tenantMonthlyRent } from '@/utils/payments'
import { useNotify } from '@/utils/notify'
import { useRouter } from 'vue-router'

export function createApplicationState(ctx: Seed) {
  const { props } = ctx
  const notify = useNotify()
  const router = useRouter()

  const application = ref<{
    leaseId: string
    roomLabel: string
    startDate: string
    endDate: string
    monthlyRent: number
    utilities: Record<UtilityKey, UtilityTerms>
  } | null>(null)
  const applyRoom = ref<RoomBrief | null>(null)
  /** The landlord/landlady in this thread, titled by their sex (student side). */
  const otherTitle = ref(landlordTitle(null).toLowerCase())
  const applyUnavailable = ref(false)
  const applyForm = reactive({ startDate: todayStr() })
  const applying = ref(false)
  const deciding = ref(false)
  /** The room this conversation is about — what the landlord/landlady can issue a form for. */
  const inquiryRoom = ref<{ id: string; label: string } | null>(null)
  /** Set once the landlord/landlady has issued a form; the student's apply card reads it. */
  const invitedRoomId = ref<string | null>(null)
  /** The student's current lease when it is NOT this thread's pending application. */
  const otherLease = ref<{ leaseId: string; status: string; roomLabel: string; managerId: string } | null>(null)
  /** The last refused application between these two, so the reason outlives the message. */
  const declined = ref<{ roomLabel: string; reason: string } | null>(null)
  const issuing = ref(false)
  const requesting = ref(false)
  /** Why this student may not apply right now; null when they may. */
  const applyBlocked = ref<string | null>(null)
  /** Blocked by money still owed on an ended stay — the card offers a way to pay. */
  const owesPast = ref(false)
  const reviewOpen = ref(false)
  const declineOpen = ref(false)
  const declineReason = ref('')
  const applicant = ref<{
    studentNo: string | null
    program: string | null
    college: string | null
    yearLevel: number | null
    verified: boolean
  } | null>(null)

  const applyEndDate = computed(() => addMonths(applyForm.startDate || todayStr(), 12))

  /**
   * What this tenant actually pays each month. A "whole room" rate is split evenly
   * across capacity — the same expression the insert uses, kept in one place so the
   * summary can never quote a figure different from the one written to the lease.
   */
  const monthlyDue = computed(() => {
    const room = applyRoom.value
    if (!room) return 0
    return tenantMonthlyRent(room.rent, room.rentBasis, room.capacity)
  })

  // Flat utility fees are paid with each month's rent.
  const monthlyFees = computed(() =>
    applyRoom.value ? UTILITIES.reduce((sum, u) => {
      const t = applyRoom.value!.utilities[u.key]
      return sum + (t.billing === 'flat_fee' ? Number(t.flatFee ?? 0) : 0)
    }, 0) : 0,
  )

  const upfrontTotal = computed(() => {
    const room = applyRoom.value
    if (!room) return 0
    return monthlyDue.value * (room.advanceMonths + room.depositMonths)
  })

  /** The blocking lease is one of this landlord/landlady's own — so it is theirs to open. */
  const isMyTenant = computed(
    () => props.role === 'manager' && otherLease.value?.managerId === props.me,
  )

  // A student can always open their own stay; a landlord/landlady only their own tenancy.
  // RLS would refuse another landlord/landlady's lease anyway, so offering the button would
  // only promise a screen that cannot load.
  const canViewOtherLease = computed(() => props.role === 'student' || isMyTenant.value)

  /** Index into STUDENT_STEPS, mirroring the card chain below; null hides the strip
   *  (landlord/landlady side, a stay elsewhere, a taken room, or a declined form —
   *  that card already says what happened and offers the next step). */
  const studentStep = computed<number | null>(() => {
    if (props.role !== 'student') return null
    if (application.value) return 3
    if (applyRoom.value) return 2
    if (applyUnavailable.value || otherLease.value || declined.value) return null
    // Asked about a room (the inquiry is stamped by "Ask to apply"); the form is next.
    return inquiryRoom.value ? 1 : null
  })

  function viewOtherLease() {
    if (!otherLease.value) return
    void router.push(
      props.role === 'student' ? '/student/stay' : `/manager/tenant/${otherLease.value.leaseId}`,
    )
  }

  return {
    notify,
    router,
    application,
    applyRoom,
    otherTitle,
    applyUnavailable,
    applyForm,
    applying,
    deciding,
    inquiryRoom,
    invitedRoomId,
    otherLease,
    declined,
    issuing,
    requesting,
    applyBlocked,
    owesPast,
    reviewOpen,
    declineOpen,
    declineReason,
    applicant,
    applyEndDate,
    monthlyDue,
    monthlyFees,
    upfrontTotal,
    isMyTenant,
    canViewOtherLease,
    studentStep,
    viewOtherLease,
  }
}
