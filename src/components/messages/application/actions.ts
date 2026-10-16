// The handshake's moves: ask for the form, send it, review an application,
// apply, accept or decline.
import { type Seed } from './model'
import { confirmAction } from '@/utils/confirmAction'
import { errorMessage } from '@/utils/errors'
import { formatDate } from '@/utils/format'
import { issueApplicationForm, requestApplicationForm, respondToApplication } from '@/utils/applications'
import { supabase } from '@/utils/supabase'
import type { createApplicationState } from './state'
import type { createApplicationRefresh } from './refresh'

export function createApplicationActions(ctx: Seed & ReturnType<typeof createApplicationState> & ReturnType<typeof createApplicationRefresh>) {
  const { props, emit, notify, application, applyRoom, applyForm, applying, deciding, inquiryRoom, invitedRoomId, declined, issuing, requesting, applyBlocked, reviewOpen, declineOpen, declineReason, applicant, applyEndDate, monthlyDue, refresh, whyApplyBlocked, genderBlock } = ctx
  async function requestForm() {
    if (requesting.value || !inquiryRoom.value || applyBlocked.value) return
    requesting.value = true
    try {
      await requestApplicationForm(props.conversationId, props.otherId, inquiryRoom.value.label)
      emit('system', `Requested an application form for ${inquiryRoom.value.label}.`)
      notify.success('Request sent.')
    } catch (e) {
      requesting.value = false
      notify.error(errorMessage(e, 'Could not send that request.'))
    }
  }

  /** The landlord/landlady hands over the form for whichever room the student asked about. */
  async function sendForm() {
    if (issuing.value || !inquiryRoom.value) return
    issuing.value = true
    try {
      const { id, label } = inquiryRoom.value
      await issueApplicationForm(props.conversationId)
      emit('system', `Sent you an application form for ${label}.`)
      invitedRoomId.value = id
      declined.value = null
      notify.success('Application form sent.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not send the application form.'))
    } finally {
      issuing.value = false
    }
  }

  /** The landlord/landlady opens the details. Loaded on demand — most threads never need it. */
  async function openReview() {
    reviewOpen.value = true
    if (applicant.value) return
    const { data } = await supabase
      .from('student_profiles')
      .select('student_id,program,college,year_level,osas_verified_at')
      .eq('user_id', props.otherId)
      .maybeSingle()
    applicant.value = {
      studentNo: data?.student_id ?? null,
      program: data?.program ?? null,
      college: data?.college ?? null,
      yearLevel: data?.year_level ?? null,
      verified: Boolean(data?.osas_verified_at),
    }
  }

  async function submitApplication() {
    if (applying.value || !applyRoom.value) return
    applying.value = true
    try {
      // Re-asked at submit: OSAS may have paused applications since the card
      // loaded. All this buys is saying so in words before RLS says it in an error.
      const blocked = (await whyApplyBlocked()) ?? (await genderBlock(applyRoom.value.id))
      if (blocked) {
        applyBlocked.value = blocked
        notify.warning(blocked)
        return
      }

      const room = applyRoom.value
      const { data: created, error: insertError } = await supabase
        .from('leases')
        .insert({
          room_id: room.id,
          student_id: props.me,
          landlord_id: props.otherId,
          start_date: applyForm.startDate,
          end_date: applyEndDate.value,
          // ponytail: "whole room" rent is split evenly assuming full occupancy;
          // a partially-filled room still charges this rate per tenant rather
          // than rebalancing existing co-tenants' leases as others join/leave.
          monthly_rent: monthlyDue.value,
          status: 'pending',
        })
        .select('id')
        .single()
      if (insertError) throw insertError

      emit('system', `Applied for ${room.label} — move-in ${formatDate(applyForm.startDate)}.`)
      // The form has been used up (tg_lease_uses_invite); a second one has to be issued again.
      invitedRoomId.value = null
      declined.value = null
      application.value = {
        leaseId: created.id,
        roomLabel: room.label,
        startDate: applyForm.startDate,
        endDate: applyEndDate.value,
        monthlyRent: monthlyDue.value,
        utilities: room.utilities,
      }
      applyRoom.value = null
      reviewOpen.value = false
      notify.success('Application submitted.')
    } catch (e) {
      // 23505 = leases_one_current_per_student. Reachable if a stay began in
      // another thread while this form sat open; the raw text is unreadable.
      const code = (e as { code?: string } | null)?.code
      notify.error(
        code === '23505'
          ? 'You already have a current application or stay.'
          : errorMessage(e, 'Could not submit your application.'),
      )
      reviewOpen.value = false
      void refresh()
    } finally {
      applying.value = false
    }
  }

  async function decideApplication(next: 'active' | 'rejected') {
    if (next === 'active' && !(await confirmAction({ title: 'Accept this application?', message: 'They become the boarder of this room.' }))) return
    if (deciding.value || !application.value) return
    deciding.value = true
    try {
      const { leaseId, roomLabel } = application.value
      const reason = declineReason.value.trim()
      await respondToApplication(leaseId, next, reason)
      emit(
        'system',
        next === 'active'
          ? `Accepted your application for ${roomLabel}.`
          : `Declined your application for ${roomLabel}. Reason: ${reason}`,
      )
      application.value = null
      reviewOpen.value = false
      declineOpen.value = false
      declineReason.value = ''
      notify.success(next === 'active' ? 'Application accepted.' : 'Application declined.')
      void refresh()
    } catch (e) {
      notify.error(errorMessage(e, 'Could not update this application.'))
    } finally {
      deciding.value = false
    }
  }

  return {
    requestForm,
    sendForm,
    openReview,
    submitApplication,
    decideApplication,
  }
}
