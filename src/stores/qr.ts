import { defineStore } from 'pinia'
import { supabase } from '@/utils/supabase'

export const useQrStore = defineStore('qr', {
  state: () => ({
    isScanning: false,
    scannedStudent: null as any | null,
    scanHistory: [] as any[],
    lastScannedAt: '' as string,
  }),

  getters: {
    recentlyScanned: (state) => state.scanHistory[0] || null,
  },

  actions: {
    async scanStudent(studentId: string) {
      this.isScanning = true
      this.scannedStudent = null
      try {
        if (!studentId) {
          throw new Error('Empty QR code.')
        }

        // Look up the student profile by school student_id. RLS
        // (accommodation_managers_read_lease_student_profiles) only returns a row
        // when this manager actually has a lease with the student, so a null
        // result means the scanned student is not this manager's tenant.
        const { data: profile, error: profileError } = await supabase
          .from('student_profiles')
          .select('user_id, program, college, year_level, osas_verified_at')
          .eq('student_id', studentId)
          .maybeSingle()

        if (profileError) throw profileError
        if (!profile) {
          throw new Error('No tenant matches this QR code. The student may not board at your property.')
        }

        const userId = profile.user_id as string

        // User record (RLS: only when linked by a lease to this manager).
        const { data: userRow } = await supabase
          .from('users')
          .select('full_name, initials')
          .eq('id', userId)
          .maybeSingle()

        // Leases between this manager and the student (RLS enforces accommodation_manager_id).
        const { data: leases } = await (supabase as any)
          .from('leases')
          .select(
            'id, status, start_date, end_date, monthly_rent, room:rooms(room_number, accommodation:accommodations(name, address))',
          )
          .eq('student_id', userId)
          .order('start_date', { ascending: false })

        const leaseRows = (leases ?? []) as Array<{
          status: string
          start_date: string | null
          end_date: string | null
          monthly_rent: number | null
          room: { room_number: string | null; accommodation: { name: string | null; address: string | null } | null } | null
        }>

        const active = leaseRows.find((l) => l.status === 'active')
        const currentBoarding = active
          ? {
              propertyName: active.room?.accommodation?.name ?? 'Your property',
              unit: active.room?.room_number ?? '—',
              monthlyRate: active.monthly_rent ?? 0,
            }
          : null

        const tenancyHistory = leaseRows.map((l) => ({
          propertyName: l.room?.accommodation?.name ?? 'Boarding House',
          address: l.room?.accommodation?.address ?? '—',
          period: `${l.start_date ? new Date(l.start_date).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' }) : ''} - ${l.end_date ? new Date(l.end_date).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' }) : 'Present'}`,
          status: l.status === 'active' ? 'Current' : 'Past',
          remarks: '',
        }))

        const student = {
          studentId,
          name: (userRow?.full_name as string) ?? 'Unknown student',
          course: (profile.program as string) ?? '—',
          yearLevel: profile.year_level ? `${profile.year_level}` : '—',
          osasVerified: !!profile.osas_verified_at,
          currentBoarding,
          tenancyHistory,
        }

        this.scannedStudent = student
        this.lastScannedAt = new Date().toISOString()

        if (!this.scanHistory.some((s: any) => s.studentId === studentId)) {
          this.scanHistory.unshift(student)
          if (this.scanHistory.length > 10) {
            this.scanHistory.pop()
          }
        }

        return student
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : 'Failed to look up student.'
        throw new Error(message)
      } finally {
        this.isScanning = false
      }
    },

    clearScan() {
      this.scannedStudent = null
      this.lastScannedAt = ''
    },
  },
})
