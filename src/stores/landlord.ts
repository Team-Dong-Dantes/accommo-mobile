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
          .select('id, status, rooms!room_id(room_number, properties(name)), users!student_id(full_name)')
          .eq('landlord_id', user.id)
          .eq('status', 'active')

        if (leasesError) throw leasesError
        this.activeTenants = leases?.length ?? 0

        // Payments needing attention
        const { data: payments, error: paymentsError } = await supabase
          .from('payments')
          .select(
            'id, amount, status, month, leases!lease_id(users!student_id(full_name), rooms!room_id(room_number, properties(name)))',
          )
          .in('status', ['due', 'overdue', 'pending_verification'])
          .eq('leases.landlord_id', user.id)

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

      // 1) Base property row — uses ONLY existing columns (no invented ones).
      const { data: inserted, error: insertError } = await supabase
        .from('properties')
        .insert({
          landlord_id: user.id,
          name: propertyData.name,
          property_type: propertyData.propertyType || null, // free-text category
          room_type: propertyData.roomType, // enum: solo|duo|triple|bedspace|studio
          status: 'pending',
          address: propertyData.address || null,
          city: propertyData.city || null,
          description: propertyData.description || null,
          total_rooms: propertyData.totalRooms ? Number(propertyData.totalRooms) : null,
          total_floors: propertyData.totalFloors ? Number(propertyData.totalFloors) : null,
          capacity: propertyData.capacity ? Number(propertyData.capacity) : null,
          barangay: propertyData.barangay || null,
          lat: propertyData.latitude ?? null,
          lng: propertyData.longitude ?? null,
        } as any)
        .select('id')
        .single()

      if (insertError) throw insertError
      const propertyId = inserted?.id
      if (!propertyId) throw new Error('Failed to create property')

      // Persist the "who can stay" policy in a separate step so that adding a
      // boarding house still works before the gender_policy migration is applied.
      const genderPolicy = propertyData.genderPolicy || null
      if (genderPolicy) {
        try {
          await supabase
            .from('properties')
            .update({ gender_policy: genderPolicy } as any)
            .eq('id', propertyId)
        } catch (e) {
          console.warn('gender_policy not saved (column may be missing):', e)
        }
      }

      // 2) Amenities -> property_amenities (one row per amenity, enum column).
      const amenities = (propertyData.amenities || []).filter(Boolean)
      if (amenities.length) {
        const { error: amenError } = await supabase
          .from('property_amenities')
          .insert(
            amenities.map((a: string) => ({ property_id: propertyId, amenity: a })) as any,
          )
        if (amenError) throw amenError
      }

      // 3) House rules -> property_policies.house_rules_json (jsonb).
      const rules = (propertyData.rules || []).filter(Boolean)
      const { error: polError } = await supabase
        .from('property_policies')
        .insert({ property_id: propertyId, house_rules_json: rules } as any)
      if (polError) throw polError



      // 5) Photos -> property_images. Images are kept as data URLs in `url`,
      //    so this needs no storage bucket or schema change. Inserted one-by-one
      //    to keep each request small. The owner-scoped RLS policy allows it.
      const photos = ((propertyData.images as any[]) || []).filter(
        (img) => img && img.dataUrl,
      )
      for (let i = 0; i < photos.length; i++) {
        const { error: imgErr } = await supabase
          .from('property_images')
          .insert({ property_id: propertyId, url: photos[i].dataUrl, sort_order: i } as any)
        if (imgErr) throw imgErr
      }

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
