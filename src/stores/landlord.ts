import { defineStore } from 'pinia'
import { supabase } from '@/shared/utils/supabase'
import { uploadDocument } from '@/shared/utils/upload'
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
        } = await supabase.auth.getUser()

        if (!user) return

        // 1) Accommodations managed by this landlord (accommodation_manager_id)
        const { data: accs, error: accError } = await supabase
          .from('accommodations' as any)
          .select('id, name, address, status, total_rooms, capacity, business_name')
          .eq('accommodation_manager_id', user.id)
          .order('name')

        if (accError) throw accError
        this.properties = (accs ?? []).map((a: any) => ({
          ...a,
          totalRooms: a.total_rooms ?? 0,
          vacantRooms: a.capacity ?? 0,
        }))
        const accIds = (accs ?? []).map((a: any) => a.id)
        const accNameById = new Map((accs ?? []).map((a: any) => [a.id, a.business_name || a.name]))

        // 2) Rooms under those accommodations
        let roomRows: any[] = []
        if (accIds.length) {
          const { data: rooms, error: roomError } = await supabase
            .from('rooms')
            .select('id, accommodation_id, label, room_number, capacity, current_pax')
            .in('accommodation_id', accIds)
          if (roomError) throw roomError
          roomRows = rooms ?? []
        }
        const roomIds = roomRows.map((r: any) => r.id)
        const roomById = new Map(roomRows.map((r: any) => [r.id, r]))

        // 3) Leases for those rooms (leases link via room_id, not landlord_id)
        let leaseRows: any[] = []
        if (roomIds.length) {
          const { data: leases, error: leaseError } = await supabase
            .from('leases')
            .select('id, student_id, room_id, status')
            .in('room_id', roomIds)
          if (leaseError) throw leaseError
          leaseRows = leases ?? []
        }
        this.activeTenants = leaseRows.filter((l: any) => l.status === 'active').length
        const leaseIds = leaseRows.map((l: any) => l.id)
        const leaseById = new Map(leaseRows.map((l: any) => [l.id, l]))

        // 4) Payments needing attention (link via lease_id)
        let paymentRows: any[] = []
        if (leaseIds.length) {
          const { data: pays, error: payError } = await supabase
            .from('payments')
            .select('id, lease_id, amount, status, month')
            .in('lease_id', leaseIds)
            .in('status', ['due', 'overdue', 'pending_verification'])
          if (payError) throw payError
          paymentRows = pays ?? []
        }
        this.pendingPayments = paymentRows.length
        this.pendingAmount = paymentRows.reduce((sum: number, p: any) => sum + Number(p.amount ?? 0), 0)
        this.verificationRequests = paymentRows.filter((p: any) => p.status === 'pending_verification')

        // 5) Notifications
        const { data: notifData, error: notifError } = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', { ascending: false })
          .limit(20)

        if (notifError) throw notifError
        this.notifications = (notifData ?? []).map((n: any) => ({
          id: n.id,
          title: n.title,
          body: n.body,
          type: n.type,
          read_at: n.read_at,
        }))
        this.unreadCount = this.notifications.filter((n: any) => !n.read_at).length

        // 6) Student display names for grouping + recent payments
        const studentIds = Array.from(new Set(leaseRows.map((l: any) => l.student_id)))
        const userMap = new Map<string, any>()
        if (studentIds.length) {
          const { data: users } = await supabase
            .from('users')
            .select('id, full_name, initials, avatar_color')
            .in('id', studentIds)
          ;(users ?? []).forEach((u: any) => userMap.set(u.id, u))
        }

        // Tenants grouped by accommodation -> room
        const groupedMap = new Map<string, any>()
        leaseRows.forEach((l: any) => {
          if (l.status !== 'active') return
          const room = roomById.get(l.room_id)
          const accName = room ? accNameById.get(room.accommodation_id) || 'Unassigned' : 'Unassigned'
          const roomNum = room?.room_number || '—'
          const student = userMap.get(l.student_id)
          const studentName = student?.full_name || 'Unknown Student'
          if (!groupedMap.has(accName)) groupedMap.set(accName, { property: accName, rooms: [] })
          groupedMap.get(accName)!.rooms.push({ room: roomNum, student: studentName, leaseId: l.id })
        })
        this.tenantsByGroup = Array.from(groupedMap.values())

        // Recent payments
        this.recentPayments = paymentRows.slice(0, 10).map((p: any) => {
          const lease = leaseById.get(p.lease_id)
          const room = lease ? roomById.get(lease.room_id) : undefined
          const student = lease ? userMap.get(lease.student_id) : undefined
          return {
            id: p.id,
            student_name: student?.full_name ?? 'Unknown Student',
            amount: p.amount,
            month: p.month ?? '—',
            status: p.status,
            property_name: room ? accNameById.get(room.accommodation_id) ?? '—' : '—',
            room_number: room?.room_number ?? '—',
          }
        })

        // Revenue chart data - 12 months (no revenue aggregation table; placeholder zeros)
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
      } = await supabase.auth.getUser()

      if (!user) return

      const { data: props, error: propsError } = await supabase
        .from('accommodations' as any)
        .select('id, name, address, status, total_rooms, capacity, business_name')
        .eq('accommodation_manager_id', user.id)
        .order('name')

      if (propsError) throw propsError
      this.properties = (props ?? []).map((a: any) => ({
        ...a,
        totalRooms: a.total_rooms ?? 0,
        vacantRooms: a.capacity ?? 0,
      }))
    },

    async addProperty(propertyData: any) {
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) return false

      const roomTypeCapacities: Record<string, number> = {
        solo: 1,
        duo: 2,
        triple: 3,
      }
      const rooms = (propertyData.rooms || [])
        .filter((room: any) => room?.label?.trim())
        .map((room: any) => ({
          ...room,
          // Only named occupancy types have a fixed capacity; others remain manager-defined.
          capacity: roomTypeCapacities[room.roomType] ?? Number(room.capacity),
        }))
      const requiredPermitTypes = ['sanitary_permit', 'fire_safety', 'business_permit', 'building_permit']
      const permits = (propertyData.permits || []).filter((permit: any) =>
        requiredPermitTypes.includes(permit?.type) && permit.file instanceof File,
      )
      if (permits.length !== requiredPermitTypes.length) {
        throw new Error('Submit the sanitary, fire safety, business, and building permits before requesting accreditation.')
      }

      const totalCapacity = rooms.reduce(
        (sum: number, room: any) => sum + Math.max(Number(room.capacity) || 0, 0),
        0,
      )

      // 1) The accommodation holds building information. Rent, capacity, and
      // room type belong to individual rooms, so totals are derived below.
      const { data: inserted, error: insertError } = await supabase
        .from('accommodations' as any)
        .insert({
          accommodation_manager_id: user.id,
          name: propertyData.name,
          accommodation_type: propertyData.accommodationType || null,
          room_type: null,
          status: 'pending',
          address: propertyData.address || null,
          city: propertyData.city || null,
          description: propertyData.description || null,
          total_rooms: rooms.length,
          total_floors: propertyData.totalFloors ? Number(propertyData.totalFloors) : null,
          capacity: totalCapacity || null,
          barangay: propertyData.barangay || null,
          lat: propertyData.latitude ?? null,
          lng: propertyData.longitude ?? null,
        } as any)
        .select('id')
        .single()

      if (insertError) throw insertError
      const accommodationId = (inserted as any)?.id
      if (!accommodationId) throw new Error('Failed to create accommodation')

      // 2) Amenities -> accommodation_amenities (one row per amenity).
      const amenities = (propertyData.amenities || []).filter(Boolean)
      if (amenities.length) {
        const { error: amenError } = await supabase
          .from('accommodation_amenities' as any)
          .insert(amenities.map((a: string) => ({ accommodation_id: accommodationId, amenity: a })) as any)
        if (amenError) throw amenError
      }

      // 3) House rules + "who can stay" -> accommodation_policies.house_rules_json (jsonb).
      const rules = (propertyData.rules || []).filter(Boolean)
      const policyJson: any = { rules }
      const genderPolicy = propertyData.genderPolicy || null
      if (genderPolicy) policyJson.gender_policy = genderPolicy
      const { error: polError } = await supabase
          .from('accommodation_policies' as any)
        .insert({ accommodation_id: accommodationId, house_rules_json: policyJson } as any)
      if (polError) throw polError

      // 4) Exterior photos belong to the accommodation.
      const photos: File[] = ((propertyData.exteriorImages as unknown[]) || []).filter(
        (file): file is File => file instanceof File,
      )
      for (let i = 0; i < photos.length; i++) {
        const photo = photos[i]
        if (!photo) continue
        const url = await uploadDocument(photo, user.id, `accommodation_exterior_${i + 1}`)
        const { error: imgErr } = await supabase
          .from('accommodation_images' as any)
          .insert({ accommodation_id: accommodationId, url, sort_order: i } as any)
        if (imgErr) throw imgErr
      }

      // 5) Accommodation permits are required before OSAS can accredit the
      // listing. Rooms are intentionally not created until that approval.
      for (const permit of permits) {
        const url = await uploadDocument(permit.file, user.id, permit.type)
        const { error: permitError } = await (supabase as any)
          .from('accommodation_documents')
          .insert({
            accommodation_id: accommodationId,
            doc_type: permit.type,
            file_url: url,
            version: 1,
          })
        if (permitError) throw permitError
      }

      // 6) Retain room persistence for approved accommodations edited through
      // trusted flows. The initial accreditation submission supplies no rooms.
      for (let i = 0; i < rooms.length; i++) {
        const room = rooms[i]
        const { data: roomRow, error: roomError } = await (supabase as any)
          .from('rooms')
          .insert({
            accommodation_id: accommodationId,
            label: room.label.trim(),
            room_number: room.label.trim(),
            floor: room.floor ? Number(room.floor) : null,
            capacity: Number(room.capacity),
            current_pax: 0,
            monthly_rent: Number(room.monthlyRent),
            status: room.status,
            room_type: room.roomType,
            custom_room_type: room.roomType === 'custom' ? room.customRoomType?.trim() || null : null,
          })
          .select('id')
          .single()
        if (roomError) throw roomError
        const roomId = roomRow?.id
        if (!roomId) throw new Error('Failed to create a room.')

        const roomPhotos: File[] = (room.images || []).filter(
          (file: unknown): file is File => file instanceof File,
        )
        for (let photoIndex = 0; photoIndex < roomPhotos.length; photoIndex++) {
          const photo = roomPhotos[photoIndex]
          if (!photo) continue
          const url = await uploadDocument(photo, user.id, `room_${i + 1}_${photoIndex + 1}`)
          const { error: imageError } = await (supabase as any)
            .from('room_images')
            .insert({ room_id: roomId, url, sort_order: photoIndex })
          if (imageError) throw imageError
        }

        await this.createAccommodationFacilities(
          accommodationId,
          room.privateFacilities || [],
          user.id,
          roomId,
          'private',
        )
      }

      // 7) Shared facilities describe accommodation-wide areas, such as a
      // shared kitchen or bathroom. Private facilities are written per room.
      await this.createAccommodationFacilities(
        accommodationId,
        propertyData.sharedFacilities || [],
        user.id,
        null,
        'shared',
      )

      return true
    },

    async createAccommodationFacilities(
      accommodationId: string,
      facilities: any[],
      userId: string,
      roomId: string | null,
      accessScope: 'shared' | 'private',
    ) {
      for (let index = 0; index < facilities.length; index++) {
        const facility = facilities[index]
        if (!facility?.type) continue
        const { data: facilityRow, error: facilityError } = await (supabase as any)
          .from('accommodation_facilities')
          .insert({
            accommodation_id: accommodationId,
            room_id: roomId,
            facility_type: facility.type,
            access_scope: accessScope,
            label: facility.label?.trim() || null,
            description: facility.description?.trim() || null,
            sort_order: index,
          })
          .select('id')
          .single()
        if (facilityError) throw facilityError

        const photos: File[] = (facility.images || []).filter(
          (file: unknown): file is File => file instanceof File,
        )
        for (let photoIndex = 0; photoIndex < photos.length; photoIndex++) {
          const photo = photos[photoIndex]
          if (!photo) continue
          const url = await uploadDocument(
            photo,
            userId,
            `${accessScope}_facility_${index + 1}_${photoIndex + 1}`,
          )
          const { error: imageError } = await (supabase as any)
            .from('accommodation_facility_images')
            .insert({ facility_id: facilityRow.id, url, sort_order: photoIndex })
          if (imageError) throw imageError
        }
      }
    },

    async fetchComplianceItems() {
      const {
        data: { user },
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
