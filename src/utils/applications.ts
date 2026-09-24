import { supabase } from '@/utils/supabase'
import { createNotification } from '@/boot/notify'

/**
 * Remembers which room the student is asking about, so the landlord/landlady's side of the
 * thread knows what form to issue. Before this the room lived only in the student's
 * URL (`?room=`), which the landlord/landlady's client never sees.
 *
 * Unvalidated on purpose: this is a hint, not a grant. invite_application() re-checks
 * ownership and availability at the moment a form is issued, and the room is frozen
 * onto the invite there.
 */
export async function stampInquiryRoom(conversationId: string, roomId: string): Promise<void> {
  const { error } = await supabase
    .from('conversations')
    .update({ inquiry_room_id: roomId })
    .eq('id', conversationId)
  if (error) throw error
}

/**
 * Student nudge: "please send me the form". Deliberately holds no database state —
 * a landlord/landlady who ignores it owes nothing, and a student who never taps it loses
 * nothing, since plenty of tenancies are agreed in plain chat.
 */
export async function requestApplicationForm(
  conversationId: string,
  managerId: string,
  roomLabel: string,
): Promise<void> {
  void createNotification(
    managerId,
    'Application form requested',
    `A student asked for an application form for ${roomLabel}.`,
    'application',
    `/manager/messages?c=${conversationId}`,
  )
}

/**
 * The landlord/landlady issues the form. The room comes from the student's inquiry, so there is
 * nothing to pick — invite_application() reads it, checks this caller owns it and it
 * is still available, and copies it onto the invite.
 */
export async function issueApplicationForm(
  conversationId: string,
  studentId: string,
  roomLabel: string,
): Promise<void> {
  const { error } = await supabase.rpc('invite_application', { p_conversation: conversationId })
  if (error) throw new Error(error.message)

  void createNotification(
    studentId,
    'Application form sent',
    `Your landlord/landlady sent you an application form for ${roomLabel}.`,
    'application',
    `/student/messages?c=${conversationId}`,
  )
}

/** Clears the invite once it has been used. */
export async function clearApplicationInvite(conversationId: string): Promise<void> {
  await supabase
    .from('conversations')
    .update({ invited_room_id: null, invited_at: null })
    .eq('id', conversationId)
}

/**
 * Accept or decline a pending room application (a `leases` row with status 'pending').
 *
 * A decline requires a reason. This function has always accepted one and folded it into
 * the student's notification, but no caller ever passed it, so every declined student
 * was told only that they had been declined. The reason lands in `decision_reason` —
 * `ended_reason` means "why the tenancy ended" and is used for 'leave_approved'.
 */
export async function respondToApplication(
  leaseId: string,
  studentId: string,
  roomLabel: string,
  decision: 'active' | 'rejected',
  reason?: string,
): Promise<void> {
  const trimmed = (reason || '').trim()
  if (decision === 'rejected' && !trimmed) {
    throw new Error('Please give a reason for declining.')
  }

  const { error } = await supabase
    .from('leases')
    .update(decision === 'rejected' ? { status: decision, decision_reason: trimmed } : { status: decision })
    .eq('id', leaseId)
  if (error) throw error

  void createNotification(
    studentId,
    decision === 'active' ? 'Application accepted' : 'Application declined',
    decision === 'active'
      ? `You're in! Your application for ${roomLabel} was accepted.`
      : `Your application for ${roomLabel} was declined. Reason: ${trimmed}`,
    'lease',
    decision === 'active' ? '/student/stay' : '/student/profile',
  )
}
