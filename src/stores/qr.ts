import { defineStore } from 'pinia'

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

      await new Promise((resolve) => setTimeout(resolve, 1500))

      const mockStudents: any[] = [
        {
          studentId: '2023-001',
          name: 'Juan Dela Cruz',
          course: 'BS Computer Science',
          yearLevel: '3rd Year',
          osasVerified: true,
          currentBoarding: {
            propertyName: 'Rose Dormitory',
            unit: '2B',
            monthlyRate: 5000,
          },
          tenancyHistory: [
            {
              propertyName: 'Rose Dormitory',
              address: '123 Quezon St., Brgy. Tibang',
              period: 'June 2023 - Present',
              status: 'Current',
              remarks: 'Good tenant',
            },
            {
              propertyName: 'St. John Boarding House',
              address: '456 Rizal Ave., Brgy. Maasin',
              period: 'June 2022 - May 2023',
              status: 'Moved Out',
              remarks: 'Paid on time',
            },
          ],
        },
        {
          studentId: '2023-002',
          name: 'Maria Santos',
          course: 'BS Business Administration',
          yearLevel: '2nd Year',
          osasVerified: false,
          currentBoarding: {
            propertyName: 'Rose Dormitory',
            unit: '3A',
            monthlyRate: 5500,
          },
          tenancyHistory: [
            {
              propertyName: 'St. John Boarding House',
              address: '456 Rizal Ave., Brgy. Maasin',
              period: 'June 2022 - May 2023',
              status: 'Moved Out',
              remarks: 'Late payments',
            },
          ],
        },
      ]

      const student = mockStudents.find((s: any) => s.studentId === studentId) || mockStudents[0]

      this.scannedStudent = student
      this.lastScannedAt = new Date().toISOString()

      if (!this.scanHistory.some((s: any) => s.studentId === studentId)) {
        this.scanHistory.unshift(student)
        if (this.scanHistory.length > 10) {
          this.scanHistory.pop()
        }
      }

      this.isScanning = false
    },

    clearScan() {
      this.scannedStudent = null
      this.lastScannedAt = ''
    },
  },
})