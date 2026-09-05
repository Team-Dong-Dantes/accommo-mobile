import { supabase } from '@/utils/supabase'
import { createNotification } from '@/boot/notify'

/** Accept or decline a pending room application (a `leases` row with status 'pending'). */
export async function respondToApplication(
  leaseId: string,
  studentId: string,
  roomLabel: string,
  decision: 'active' | 'rejected',
): Promise<void> {
  const { error } = await supabase.from('leases').update({ status: decision }).eq('id', leaseId)
  if (error) throw error

  void createNotification(
    studentId,
    decision === 'active' ? 'Application accepted' : 'Application declined',
    decision === 'active'
      ? `You're in! Your application for ${roomLabel} was accepted.`
      : `Your application for ${roomLabel} was declined.`,
    'lease',
    decision === 'active' ? '/student/stay' : '/student/profile',
  )
}
