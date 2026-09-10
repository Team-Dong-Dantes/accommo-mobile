import { defineStore } from 'pinia'
import { supabase } from '@/utils/supabase'
import { resolveAsset } from '@/utils/cloudinaryUrl'

export interface ScannedStudent {
  userId: string
  studentId: string | null
  name: string
  initials: string
  avatarUrl: string | null
  program: string | null
  college: string | null
  yearLevel: number | null
  osasVerified: boolean
  verifiedAt: string | null
  accountStatus: string | null
  isMyTenant: boolean
  method: string
  scannedAt: string
}

// The lookup runs entirely in verify_student_qr(): a SECURITY DEFINER function,
// because the point of scanning is to check someone who is NOT yet your tenant,
// and student_profiles RLS only ever exposes people you already lease to. The
// function also writes the qr_scans row and enforces the rate limit, so there
// is no client-side path that skips either.
export const useQrStore = defineStore('qr', {
  state: () => ({
    isScanning: false,
    scannedStudent: null as ScannedStudent | null,
    scanHistory: [] as ScannedStudent[],
  }),

  getters: {
    recentlyScanned: (state) => state.scanHistory[0] || null,
  },

  actions: {
    async scanStudent(code: string): Promise<ScannedStudent> {
      const trimmed = code.trim()
      if (!trimmed) throw new Error('Empty QR code.')

      this.isScanning = true
      try {
        const { data, error } = await supabase.rpc('verify_student_qr', { p_code: trimmed })
        if (error) throw new Error(error.message)

        const payload = data as Record<string, unknown> | null
        if (!payload?.found) {
          // An expired code is a different problem from a wrong one: the
          // student is real, their screen just needs a look.
          throw new Error(
            payload?.reason === 'expired'
              ? 'This code has expired. Ask the student to open their QR screen for a fresh one.'
              : 'No student matches this code. It may not be an Accommo student.',
          )
        }

        const student: ScannedStudent = {
          userId: String(payload.user_id ?? ''),
          studentId: (payload.student_id as string) ?? null,
          name: (payload.full_name as string) || 'Unknown student',
          initials: (payload.initials as string) || '?',
          avatarUrl: payload.avatar_url ? resolveAsset(String(payload.avatar_url)) : null,
          program: (payload.program as string) ?? null,
          college: (payload.college as string) ?? null,
          yearLevel: (payload.year_level as number) ?? null,
          osasVerified: Boolean(payload.osas_verified),
          verifiedAt: (payload.verified_at as string) ?? null,
          accountStatus: (payload.account_status as string) ?? null,
          isMyTenant: Boolean(payload.is_my_tenant),
          method: (payload.method as string) ?? 'qr',
          scannedAt: new Date().toISOString(),
        }

        this.scannedStudent = student
        this.scanHistory = [student, ...this.scanHistory.filter((s) => s.userId !== student.userId)].slice(0, 10)
        return student
      } finally {
        this.isScanning = false
      }
    },

    clearScan() {
      this.scannedStudent = null
    },
  },
})
