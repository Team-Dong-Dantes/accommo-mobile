import { supabase } from '@/utils/supabase'
import { createNotification } from '@/boot/notify'

/**
 * Accept or decline a pending room application (a `leases` row with status
 * 'pending'). A decline reason is stored on `ended_reason` — there's no
 * dedicated column for it, but that field is otherwise only ever set on a
 * terminal status change (this one included), and it's unconstrained text.
 */
export async function respondToApplication(
  leaseId: string,
  studentId: string,
  roomLabel: string,
  decision: 'active' | 'rejected',
  reason?: string,
): Promise<void> {
  const { error } = await supabase
    .from('leases')
    .update(decision === 'rejected' ? { status: decision, ended_reason: reason || null } : { status: decision })
    .eq('id', leaseId)
  if (error) throw error

  void createNotification(
    studentId,
    decision === 'active' ? 'Application accepted' : 'Application declined',
    decision === 'active'
      ? `You're in! Your application for ${roomLabel} was accepted.`
      : `Your application for ${roomLabel} was declined.${reason ? ` Reason: ${reason}` : ''}`,
    'lease',
    decision === 'active' ? '/student/stay' : '/student/profile',
  )
}
