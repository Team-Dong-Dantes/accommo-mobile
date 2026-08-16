import { defineStore } from 'pinia'
import { supabase } from '@/shared/utils/supabase'
import type { LandlordProfile, ComplianceItem, ScannedStudent, TenancyRecord, ChatMessage, TenantBillingState, PaymentRecord } from '@/shared/types/app-types'

export const useLandlordStore = defineStore('landlord', {
  state: () => ({
    // Dashboard metrics
    activeTenants: 0,
    pendingPayments: 0,
    pendingAmount: 0 as number,
    properties: [] as any[],
    verificationRequests: [] as any[],
    notifications: [] as any[],
    unreadCount: 0,

    // Twelve month revenue chart data
    revenueChartData: {
      labels: [] as string[],
      datasets: [] as any[]
    } as any,

    // Tenants grouped by property and room type
    tenantsByGroup: [] as any[],

    // Recent payments
    recentPayments: [] as any[],

    // Loading states
    isLoading: false,
    loadError: '' as string | null,
  }),

  getters: {
    totalProperties: (state) => state.properties.length,
    accreditedProperties: (state) =>
      state.properties.filter((p: any) => p.status === 'accredited').length,
    occupancyRate: (state) => {
      if (state.properties.length === 0) return 0
      const totalRooms = state.properties.reduce(
        (sum: number, p: any) => sum + (p.totalRooms ?? p.total_rooms ?? 0),
        0,
      )
      const occupiedRooms = state.properties.reduce(
        (sum: number, p: any) => {
          const roomCount = p.totalRooms ?? p.total_rooms ?? 0
          const vacantCount = p.vacantRooms ?? 0
          return sum + Math.max(roomCount - vacantCount, 0)
        },
        0,
      )
      return totalRooms > 0 ? Number(((occupiedRooms / totalRooms) * 100).toFixed(1)) : 0
    },
  },

  actions: {
    async loadDashboard() {
      this.isLoading = true
      this.loadError = ''
      try {
        const {
          data: { user },
          error: userError,
        } = await supabase.auth.getUser()

        if (!user) return

        // Properties
        const { data: props, error: propsError } = await supabase
          .from('properties')
          .select('id, name, address, status, total_rooms, capacity')
          .eq('landlord_id', user.id)
          .order('name')

        if (propsError) throw propsError
        this.properties = (props ?? []).map((property: any) => ({
          ...property,
          totalRooms: property.total_rooms ?? 0,
          vacantRooms: property.capacity ?? 0,
        }))

        // Active leases
        const { data: leases, error: leasesError } = await supabase
          .from('leases')
          .select('id, status, room:rooms(room_number, property:properties(name)), student_id:student_id:users(full_name)')
          .eq('landlord_id', user.id)
          .eq('status', 'active')

        if (leasesError) throw leasesError
        this.activeTenants = leases?.length ?? 0

        // Payments needing attention
        const { data: payments, error: paymentsError } = await supabase
          .from('payments')
          .select(
            'id, amount, status, month, lease:leases(student:users(full_name), room:rooms(room_number, property:properties(name)))',
          )
          .in('status', ['due', 'overdue', 'pending_verification'])
          .eq('lease.landlord_id', user.id)

        if (paymentsError) throw paymentsError
        const typedPayments = (payments ?? []) as any[]
        this.pendingPayments = typedPayments.length
        this.pendingAmount =
          typedPayments.length > 0
            ? typedPayments.reduce((sum: number, p: any) => sum + p.amount, 0)
            : 0
        this.verificationRequests = typedPayments.filter(
          (payment: any) => payment.status === 'pending_verification',
        )

        // Notifications
        const { data: notifData, error: notifError } = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('id', { ascending: false })
          .limit(20)

        if (notifError) throw notifError
        this.notifications = (notifData ?? []).map((n: any) => ({
          id: n.id,
          title: n.title,
          body: n.body,
          type: n.type,
          read_at: n.read_at,
        }))
        this.unreadCount = this.notifications.filter(
          (n: any) => !n.read_at,
        ).length

        // Tenants grouped by property/room
        const grouped: any[] = []
        if (leases) {
          const groupedMap = new Map<string, any>()
          leases.forEach((lease: any) => {
            const propKey = lease.room?.property?.name || 'Unassigned'
            const roomKey = lease.room?.room_number || '—'
            const studentName = lease.student_id?.full_name || 'Unknown Student'

            if (!groupedMap.has(propKey)) {
              groupedMap.set(propKey, { property: propKey, rooms: [] })
            }
            groupedMap.get(propKey)!.rooms!.push({
              room: roomKey,
              student: studentName,
              leaseId: lease.id,
            })
          })
          grouped.push(...groupedMap.values())
        }
        this.tenantsByGroup = grouped

        // Recent payments (last 10)
        const recent = typedPayments
          .sort((a: any, b: any) => (a.created_at ?? '') > (b.created_at ?? '') ? -1 : 1)
          .slice(0, 10)
        this.recentPayments = recent.map((p: any) => ({
          id: p.id,
          student_name: p.lease?.student?.full_name ?? 'Unknown Student',
          amount: p.amount,
          month: p.month ?? '—',
          status: p.status,
          property_name: p.lease?.room?.property?.name ?? '—',
          room_number: p.lease?.room?.room_number ?? '—',
        }))

        // Revenue chart data - 12 months
        const today = new Date()
        const labels = []
        for (let i = 11; i >= 0; i--) {
          const m = new Date(today)
          m.setMonth(today.getMonth() - i)
          labels.push(m.toLocaleString('en-PH', { month: 'short' }))
        }
        this.revenueChartData = {
          labels,
          datasets: [
            {
              label: 'Revenue',
              data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
              backgroundColor: 'rgba(0, 137, 123, 0.2)',
              borderColor: '#00897B',
              tension: 0.4,
            },
          ],
        }

      } catch (e) {
        this.loadError = e instanceof Error ? e.message : 'Failed to load dashboard'
        console.error('loadDashboard error:', e)
      } finally {
        this.isLoading = false
      }
    },

    async loadProperties() {
      const {
        data: { user },
        error: userError,
      } = await supabase.auth.getUser()

      if (!user) return

      const { data: props, error: propsError } = await supabase
        .from('properties')
        .select('id, name, address, status, total_rooms, capacity')
        .eq('landlord_id', user.id)
        .order('name')

      if (propsError) throw propsError
      this.properties = (props ?? []).map((property: any) => ({
        ...property,
        totalRooms: property.total_rooms ?? 0,
        vacantRooms: property.capacity ?? 0,
      }))
    },

    async addProperty(propertyData: any) {
      const {
        data: { user },
        error: userError,
      } = await supabase.auth.getUser()

      if (!user) return false

      const { error: insertError } = await supabase
        .from('properties')
        .insert({
          landlord_id: user.id,
          name: propertyData.name,
          room_type: propertyData.roomType,
          status: 'pending',
          address: propertyData.address || null,
          city: propertyData.city || null,
          description: propertyData.description || null,
          monthly_rent: propertyData.monthlyRent ? Number(propertyData.monthlyRent) : null,
          total_rooms: propertyData.totalRooms ? Number(propertyData.totalRooms) : null,
          total_floors: propertyData.totalFloors ? Number(propertyData.totalFloors) : null,
        })

      if (insertError) throw insertError
      return true
    },

    async fetchComplianceItems() {
      const {
        data: { user },
        error: userError,
      } = await supabase.auth.getUser()

      if (!user) return []

      const { data, error } = await supabase
        .from('verification_documents')
        .select('*')
        .eq('user_id', user.id)

      if (error) throw error
      return (data ?? []).map((item: any): ComplianceItem => ({
        id: item.id,
        documentName: item.filename || item.doc_type || 'Document',
        expiryDate: item.expiry_date || 'N/A',
        status: item.status === 'approved' ? 'Valid' : item.status === 'rejected' ? 'Missing' : 'Expiring',
      }))
    },

    async createVerificationDocument(docData: any) {
      const {
        data: { user },
        error: userError,
      } = await supabase.auth.getUser()

      if (!user) return false

      const { error } = await supabase
        .from('verification_documents')
        .insert({
          user_id: user.id,
          doc_type: docData.docType,
          file_url: docData.fileUrl,
          filename: docData.fileName,
          status: docData.status ?? 'pending',
        })

      if (error) throw error
      return true
    },
  },
})

// --- QR SCANNER STORE ---
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

// --- CHAT STORE ---
export const useChatStore = defineStore('chat', {
  state: () => ({
    messages: [] as ChatMessage[],
    pendingInquiry: null as { id: string; text: string; senderId: string } | null,
    quickReplies: [] as string[],
    isTyping: false,
  }),

  getters: {
    unreadCount: (state) =>
      state.messages.filter((m: ChatMessage) => !m.isLandlord).length,
  },

  actions: {
    async loadMessages() {
      this.messages = [
        {
          id: 'msg-1',
          text: 'Hi, I\'m interested in your room for this month.',
          senderId: 'student-1',
          timestamp: '2024-01-15T10:30:00',
          isLandlord: false,
        },
        {
          id: 'msg-2',
          text: 'Hello! Yes, we have a room available. What is your course and year level?',
          senderId: 'landlord-1',
          timestamp: '2024-01-15T10:31:00',
          isLandlord: true,
        },
        {
          id: 'msg-3',
          text: 'I\'m taking BS Computer Science, 3rd year.',
          senderId: 'student-1',
          timestamp: '2024-01-15T10:32:00',
          isLandlord: false,
        },
      ]
    },

    async sendMessage(text: string, isLandlord: boolean = false) {
      const message: ChatMessage = {
        id: Math.random().toString(36).substr(2, 9),
        text,
        senderId: isLandlord ? 'landlord-1' : 'student-' + Math.floor(Math.random() * 10),
        timestamp: new Date().toISOString(),
        isLandlord,
      }

      this.messages.unshift(message)
    },

    async acceptInquiry(inquiryId: string) {
      this.pendingInquiry = null
      await this.sendMessage(`Accepted your inquiry.`, true)
    },

    async declineInquiry(inquiryId: string) {
      this.pendingInquiry = null
      await this.sendMessage(`Declined your inquiry.`, true)
    },

    setQuickReplies(replies: string[]) {
      this.quickReplies = replies
    },
  },
})

// --- TENANT BILLING STORE ---
export const useTenantBillingStore = defineStore('tenant-billing', {
  state: () => ({
    currentTenant: null as any,
    billingState: {
      monthlyRent: 0,
      payStreak: 0,
      pendingAmount: 0,
      paymentHistory: [] as PaymentRecord[],
    } as TenantBillingState,
    isLoggingPayment: false,
  }),

  getters: {
    hasPendingPayments: (state) => state.billingState.paymentHistory.some(
      (ph: PaymentRecord) => ph.status === 'Pending',
    ),
    overdueCount: (state) => state.billingState.paymentHistory.filter(
      (ph: PaymentRecord) => ph.status === 'Overdue' || ph.status === 'Pending',
    ).length,
  },

  actions: {
    async setCurrentTenant(tenantData: any) {
      this.currentTenant = tenantData
      this.billingState = {
        monthlyRent: tenantData.monthlyRate || 0,
        payStreak: tenantData.payStreak || 0,
        pendingAmount: 0,
        paymentHistory: tenantData.paymentHistory || [],
      }
    },

    async logCashPayment(amount: number, month: string, onSuccess?: (msg: string) => void) {
      this.isLoggingPayment = true

      const newRecord: PaymentRecord = {
        month,
        dueDate: new Date().toISOString().split('T')[0] ?? '',
        amount,
        status: 'Pending',
        paymentMethod: 'Cash',
      }

      this.billingState.paymentHistory.unshift(newRecord)
      this.billingState.pendingAmount += amount

      const lastStatus = this.billingState.paymentHistory
        .slice(1)
        .find((ph: PaymentRecord) => ph.status === 'Paid')

      if (lastStatus) {
        this.billingState.payStreak =
          this.billingState.payStreak + 1
      }

      this.isLoggingPayment = false

      const msg = `Cash payment of ₱${amount} logged for ${month}.`
      if (onSuccess) onSuccess(msg)
      else console.log(msg)
    },

    async markPaymentPaid(month: string, onSuccess?: (msg: string) => void) {
      const record = this.billingState.paymentHistory.find(
        (ph) => ph.month === month,
      )

      if (record) {
        record.status = 'Paid'
        record.paymentMethod = 'Cash'

        this.billingState.pendingAmount -= record.amount

        const allPaid = this.billingState.paymentHistory.every(
          (ph) => ph.status === 'Paid',
        )
        if (allPaid) {
          this.billingState.payStreak += 1
        }

        const msg = `Payment for ${month} marked as Paid.`
        if (onSuccess) onSuccess(msg)
        else console.log(msg)
      }
    },
  },
})
