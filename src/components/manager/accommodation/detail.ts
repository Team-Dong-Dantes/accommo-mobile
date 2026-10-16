// AccommodationDetail's state, shared with the panels and dialogs it is split
// into. The page creates it once (provideAccommodationDetail) and every piece
// below reads the same instance (useAccommodationDetail), so a room saved in
// the room dialog shows on the Rooms panel without a reload — exactly as when
// this was one 2,800-line component.
import { computed, inject, provide, reactive, ref, type InjectionKey } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { since } from '@/utils/notifications'
import { useNotify } from '@/utils/notify'
import { secureDocUrl } from '@/utils/upload'
import { resolveAsset, CARD, COVER } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel, staticMapUrl } from '@/utils/geo'
import { UTILITY_SELECT, utilitiesFromRow, utilitiesProblem, type UtilityColumns, AMENITY_META } from '@/utils/listings'
import type { Database } from '@/types/database.gen'
import { POLICY_RULES } from '@/api/selects'
import { permitDate, permitReplaceOpen } from '@/utils/permits'
import { partitionFacilities, nextFloorNumber as nextFloorNumberOf, nextRoomNumber as nextRoomNumberOf } from '@/utils/roomInventory'
import { manilaToday } from '@/utils/payments'
import type AccreditationCard from '@/components/manager/AccreditationCard.vue'
import { DOC_TYPES, type Facility, type FieldKey, type FloorGroup, type Img, type Room } from './model'
import { createListing } from './listing'
import { createFloors } from './floors'
import { createRooms } from './rooms'
import { createRoomActions } from './roomActions'
import { createFacilities } from './facilities'

function createDetail() {
  const route = useRoute()
  const router = useRouter()
  const auth = useAuthStore()
  const notify = useNotify()

  const id = String(route.params.id || '')

  const loading = ref(true)
  const error = ref('')
  const acc = reactive({
    name: '',
    accommodationType: '',
    genderPolicy: '',
    address: '',
    purok: '',
    barangay: '',
    city: '',
    description: '',
    status: 'pending',
    lat: null as number | null,
    lng: null as number | null,
    appealUsed: false,
    accreditationExpiresAt: null as string | null,
  })
  const rules = reactive({
    amenities: [] as string[],
    curfewTime: '',
    quietHours: '',
    visitorPolicy: '',
    cooking: true,
    laundry: true,
    pets: false,
  })
  const rooms = ref<Room[]>([])
  const images = ref<Img[]>([])
  const facilities = ref<Facility[]>([])
  const docRows = ref<{ doc_type: string; file_url: string; expires_at: string | null; uploaded_at: string; version: number }[]>([])
  const coverUrl = computed(() => (images.value[0]?.url ? resolveAsset(images.value[0].url, COVER) : ''))
  // Occupancy must come from actual leases, not rooms.status/current_pax —
  // this project's own data notes flag those columns as unreliable.
  const occupiedRoomIds = ref<string[]>([])
  const occupiedRoomCount = computed(() => occupiedRoomIds.value.length)
  const vacantRoomCount = computed(() => Math.max(rooms.value.length - occupiedRoomCount.value, 0))
  // What a draft still needs before submit_accommodation() will take it — the
  // same list the database checks, worded the way its error reads.
  const draftMissing = computed(() => {
    const missing: string[] = []
    if (!acc.accommodationType || !acc.genderPolicy) missing.push('type and who it accepts')
    if (acc.lat === null || acc.lng === null || !acc.barangay || !acc.city) missing.push('location')
    if (rooms.value.some((r) => utilitiesProblem(r.utilities))) missing.push('utilities on every room')
    if (!rules.curfewTime || !rules.quietHours || !rules.visitorPolicy) missing.push('house rules')
    if (!images.value.length) missing.push('an exterior photo')
    const docs = new Set(docRows.value.map((d) => d.doc_type))
    if (!['sanitary_permit', 'fire_safety', 'business_permit', 'building_permit'].every((t) => docs.has(t))) {
      missing.push('all four permits')
    } else {
      if (docRows.value.some((d) => !d.expires_at)) missing.push('an expiry date on every permit')
      const today = manilaToday()
      if (docRows.value.some((d) => d.expires_at && d.expires_at < today)) missing.push('permits that have not expired')
    }
    return missing
  })

  // Rooms, facilities and floors come after accreditation, and only while the
  // listing is live — the database refuses the insert otherwise
  // (20261003000000), as it does for an unverified landlord/landlady.
  const canAddInventory = computed(() => acc.status === 'accredited' && auth.isVerifiedLandlord)
  const inventoryClosedHint = computed(() => {
    if (!auth.isVerifiedLandlord) return 'You can add rooms, facilities and floors once OSAS verifies your account.'
    if (acc.status === 'delisted') return 'This accommodation is delisted — reactivate it to add rooms, facilities, or floors.'
    if (acc.status === 'expired') return 'Accreditation has ended — renew it to add rooms, facilities, or floors.'
    if (acc.status === 'suspended') return 'OSAS suspended this accommodation, so rooms, facilities and floors can’t be added.'
    return 'You can add rooms, facilities and floors once OSAS accredits this accommodation.'
  })
  const distance = computed(() => campusDistanceLabel(acc.lat, acc.lng))
  const mapUrl = computed(() => staticMapUrl(acc.lat, acc.lng))

  const sharedFacilities = computed(() => partitionFacilities(facilities.value, null).shared)
  const roomTitle = (r: Room) => (r.roomNumber ? `Room ${r.roomNumber}` : 'Room')
  const roomOptions = computed(() => rooms.value.map((r) => ({ label: roomTitle(r), value: r.id })))
  // Filtered through the live room list, so a deleted room drops out.
  const roomNames = (ids: string[]) => rooms.value.filter((r) => ids.includes(r.id)).map(roomTitle).join(', ')
  function sharedFacilitySub(f: Facility): string {
    const n = rooms.value.filter((r) => f.roomIds.includes(r.id)).length
    const shared = n ? `Shared by ${n} room${n === 1 ? '' : 's'}` : 'Shared facility'
    return f.status === 'under_repair' ? `${shared} · Under repair` : shared
  }

  const docs = computed(() =>
    DOC_TYPES.map((type) => {
      const row = docRows.value.find((d) => d.doc_type === type)
      if (!row) {
        return { type, statusLabel: 'Not submitted', tone: 'idle', icon: 'lucide:circle-dashed', when: '', fileUrl: '', canReplace: true }
      }
      const flagged = Boolean(accreditationCard.value?.flagged.some((f) => f.type === type && !f.replaced))
      const canReplace = permitReplaceOpen(acc.status, row.expires_at, flagged)
      return { ...docStatus(row, flagged), type, fileUrl: row.file_url, canReplace }
    }),
  )

  function docStatus(row: { expires_at: string | null; uploaded_at: string }, flagged: boolean) {
    // OSAS's verdict outranks the date: a flagged permit is not "Valid" just
    // because it hasn't expired.
    if (flagged) {
      return { statusLabel: 'Needs resubmission', tone: 'danger', icon: 'lucide:file-warning', when: 'OSAS asked for a new file' }
    }
    if (!row.expires_at) {
      // Expiry is required on upload now, so a null one only happens on a
      // legacy row from before that — flag it rather than reading as settled.
      return { statusLabel: 'No expiration set', tone: 'warn', icon: 'lucide:calendar-x', when: `Uploaded ${since(row.uploaded_at)}` }
    }
    const now = Date.now()
    const soon = now + 30 * 24 * 60 * 60 * 1000
    const t = new Date(row.expires_at).getTime()
    if (t < now) return { statusLabel: 'Expired', tone: 'danger', icon: 'lucide:file-warning', when: `Expired ${permitDate(row.expires_at)}` }
    if (t < soon) return { statusLabel: 'Expiring soon', tone: 'warn', icon: 'lucide:calendar-clock', when: `Expires ${permitDate(row.expires_at)}` }
    return { statusLabel: 'Valid', tone: 'good', icon: 'lucide:check', when: `Expires ${permitDate(row.expires_at)}` }
  }

  async function load() {
    loading.value = true
    error.value = ''
    try {
      const { data, error: loadError } = await supabase
        .from('accommodations')
        .select(
          `name,accommodation_type,gender_policy,address,purok,barangay,city,description,status,lat,lng,appeal_used,accreditation_expires_at,accommodation_amenities(amenity),accommodation_policies(${POLICY_RULES}),accommodation_images(id,url,sort_order),accommodation_facilities(id,facility_type,access_scope,label,description,room_id,floor,status,accommodation_facility_rooms(room_id),accommodation_facility_images(id,url,sort_order)),accommodation_floors(floor_number,label),rooms(id,label,room_number,room_type,custom_room_type,floor,capacity,current_pax,monthly_rent,advance_months,deposit_months,rent_basis,status,${UTILITY_SELECT},room_images(id,url,sort_order))`,
        )
        .eq('id', id)
        .maybeSingle()
      if (loadError) throw loadError
      if (!data) {
        error.value = 'This accommodation could not be found.'
        return
      }

      acc.name = data.name || ''
      acc.accommodationType = data.accommodation_type || ''
      acc.genderPolicy = data.gender_policy || ''
      acc.address = data.address || ''
      acc.purok = data.purok || ''
      acc.barangay = data.barangay || ''
      acc.city = data.city || ''
      acc.description = data.description || ''
      acc.status = data.status
      acc.lat = data.lat
      acc.lng = data.lng
      acc.appealUsed = data.appeal_used
      acc.accreditationExpiresAt = data.accreditation_expires_at

      rules.amenities = ((data.accommodation_amenities ?? []) as { amenity: string }[]).map((a) => a.amenity).filter((a) => a in AMENITY_META)

      const policyRows = data.accommodation_policies as unknown
      const policy = (Array.isArray(policyRows) ? policyRows[0] : policyRows) as
        | {
            curfew_time: string | null
            quiet_hours: string | null
            visitor_policy: string | null
            cooking: boolean | null
            laundry: boolean | null
            pets: boolean | null
          }
        | null
      if (policy) {
        rules.curfewTime = policy.curfew_time || ''
        rules.quietHours = policy.quiet_hours || ''
        rules.visitorPolicy = policy.visitor_policy || ''
        rules.cooking = policy.cooking ?? true
        rules.laundry = policy.laundry ?? true
        rules.pets = policy.pets ?? false
      }

      images.value = [...((data.accommodation_images ?? []) as { id: string; url: string; sort_order: number | null }[])]
        .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
        .map((i) => ({ id: i.id, url: i.url }))

      facilities.value = ((data.accommodation_facilities ?? []) as {
        id: string
        facility_type: string
        access_scope: string
        label: string | null
        description: string | null
        room_id: string | null
        floor: number | null
        status: string
        accommodation_facility_rooms: { room_id: string }[] | null
        accommodation_facility_images: { id: string; url: string; sort_order: number | null }[] | null
      }[]).map((f) => ({
        id: f.id,
        facilityType: f.facility_type,
        label: f.label || '',
        description: f.description || '',
        roomId: f.room_id,
        floor: f.floor,
        status: f.status === 'under_repair' ? 'under_repair' : 'available',
        roomIds: (f.accommodation_facility_rooms ?? []).map((l) => l.room_id),
        images: [...(f.accommodation_facility_images ?? [])]
          .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
          .map((i) => ({ id: i.id, url: i.url })),
      }))

      rooms.value = ((data.rooms ?? []) as ({
        id: string
        label: string | null
        room_number: string | null
        room_type: string | null
        custom_room_type: string | null
        floor: number | null
        capacity: number | null
        current_pax: number | null
        monthly_rent: number | null
        advance_months: number | null
        deposit_months: number | null
        rent_basis: string | null
        status: string
        room_images: { id: string; url: string; sort_order: number | null }[] | null
      } & Partial<UtilityColumns>)[]).map((r) => {
        const imgs = [...(r.room_images ?? [])]
          .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
          .map((i) => ({ id: i.id, url: i.url }))
        return {
          id: r.id,
          label: r.label,
          roomNumber: r.room_number,
          roomType: r.room_type,
          customRoomType: r.custom_room_type,
          floor: r.floor,
          capacity: r.capacity,
          currentPax: r.current_pax ?? 0,
          monthlyRent: Number(r.monthly_rent ?? 0),
          advanceMonths: r.advance_months,
          depositMonths: r.deposit_months,
          rentBasis: r.rent_basis === 'person' ? 'person' : 'room',
          utilities: utilitiesFromRow(r),
          status: r.status,
          images: imgs,
          photoUrl: imgs[0]?.url ? resolveAsset(imgs[0].url, CARD) : '',
        }
      })

      const floorRows = (data.accommodation_floors ?? []) as { floor_number: number; label: string | null }[]
      trackedFloors.value = floorRows.map((f) => f.floor_number)
      floorLabels.value = Object.fromEntries(floorRows.filter((f) => f.label).map((f) => [f.floor_number, f.label as string]))

      if (rooms.value.length) {
        const { data: activeLeases, error: leaseError } = await supabase
          .from('leases')
          .select('room_id')
          .in('room_id', rooms.value.map((r) => r.id))
          .in('status', ['active', 'leave_requested'])
        if (leaseError) throw leaseError
        occupiedRoomIds.value = [...new Set((activeLeases ?? []).map((l) => l.room_id))]
      } else {
        occupiedRoomIds.value = []
      }

      await loadDocs()
    } catch (e) {
      error.value = errorMessage(e, 'Something went wrong.')
    } finally {
      loading.value = false
    }
  }

  async function loadDocs() {
    const { data, error: docError } = await supabase
      .from('accommodation_documents')
      .select('id, doc_type, file_url, expires_at, uploaded_at, version')
      .eq('accommodation_id', id)
      .order('version', { ascending: false })
    if (docError) throw docError

    const seen = new Set<string>()
    const latest = (data ?? []).filter((d) => {
      if (seen.has(d.doc_type)) return false
      seen.add(d.doc_type)
      return true
    })
    // Permits use Cloudinary authenticated delivery: file_url holds a ref, so each
    // one is signed for this viewer.
    docRows.value = await Promise.all(
      latest.map(async (d) => ({ ...d, file_url: await secureDocUrl('accommodation_documents', d.id) })),
    )
  }

  /**
   * The location OSAS checked when it reviewed the listing (the map pin and the
   * address it fills). The database locks these once a listing leaves draft
   * (lock_verification_columns): free while it is a draft or sent back for
   * changes, a request to OSAS while it is live, and fixed otherwise. Everything
   * else — name, type, who it accepts, rooms, rent, photos, amenities, house
   * rules, the description — stays the landlord/landlady's to change. Permits go
   * through their own replacement rule (utils/permits.ts).
   */
  const OSAS_CHECKED: ReadonlySet<FieldKey> = new Set(['purok', 'barangay', 'city'])
  function fieldReview(key: FieldKey): 'free' | 'request' | 'locked' {
    if (!OSAS_CHECKED.has(key)) return 'free'
    if (acc.status === 'draft' || acc.status === 'needs_revision') return 'free'
    if (acc.status === 'accredited' || acc.status === 'delisted') return 'request'
    return 'locked'
  }

  const accreditationCard = ref<InstanceType<typeof AccreditationCard> | null>(null)

  /** Sends a change to what OSAS checked; the listing keeps its values meanwhile. */
  async function requestChange(changes: Record<string, unknown>): Promise<boolean> {
    const { error: requestError } = await supabase.rpc('request_details_change', {
      p_id: id,
      p_changes: changes as Database['public']['Functions']['request_details_change']['Args']['p_changes'],
    })
    if (requestError) {
      notify.error(errorMessage(requestError, 'Could not send this change to OSAS.'))
      return false
    }
    notify.success('Sent to OSAS. The listing shows the change once it is approved.')
    void accreditationCard.value?.reload()
    return true
  }

  /** Status and term only, after the card acts — not the whole page. */
  async function refreshAccreditation() {
    const { data } = await supabase
      .from('accommodations')
      .select('status, appeal_used, accreditation_expires_at')
      .eq('id', id)
      .maybeSingle()
    if (!data) return
    acc.status = data.status
    acc.appealUsed = data.appeal_used
    acc.accreditationExpiresAt = data.accreditation_expires_at
  }

  // Floors a landlord/landlady has explicitly added, tracked independently of rooms
  // (accommodation_floors) so an empty floor with no rooms yet still survives
  // a reload instead of only existing while this page happens to be open.
  const trackedFloors = ref<number[]>([])
  /** Names landlords gave their floors ("Ground", "Annex"); the number is still the key. */
  const floorLabels = ref<Record<number, string>>({})
  function floorName(floor: number | null): string {
    if (floor === null) return 'No floor set'
    return floorLabels.value[floor] || `Floor ${floor}`
  }

  const roomsByFloor = computed<FloorGroup[]>(() => {
    const roomMap = new Map<number, Room[]>()
    const facilityMap = new Map<number, Facility[]>()
    for (const floor of trackedFloors.value) {
      if (!roomMap.has(floor)) roomMap.set(floor, [])
      if (!facilityMap.has(floor)) facilityMap.set(floor, [])
    }
    const noFloorRooms: Room[] = []
    for (const r of rooms.value) {
      if (r.floor === null) {
        noFloorRooms.push(r)
        continue
      }
      if (!roomMap.has(r.floor)) roomMap.set(r.floor, [])
      roomMap.get(r.floor)!.push(r)
    }
    const noFloorFacilities: Facility[] = []
    for (const f of sharedFacilities.value) {
      if (f.floor === null) {
        noFloorFacilities.push(f)
        continue
      }
      if (!facilityMap.has(f.floor)) facilityMap.set(f.floor, [])
      facilityMap.get(f.floor)!.push(f)
    }
    const floors = [...new Set([...roomMap.keys(), ...facilityMap.keys()])].sort((a, b) => a - b)
    const groups = floors.map(
      (floor): FloorGroup => ({
        floor,
        label: floorName(floor),
        rooms: roomMap.get(floor) ?? [],
        facilities: facilityMap.get(floor) ?? [],
      }),
    )
    if (noFloorRooms.length || noFloorFacilities.length) {
      groups.push({ floor: null, label: 'No floor set', rooms: noFloorRooms, facilities: noFloorFacilities })
    }
    return groups
  })

  const floorCount = computed(() => roomsByFloor.value.filter((g) => g.floor !== null).length)

  // Room "names" are just their number — assigned once at creation from the
  // floor + how many rooms already sit on it, never hand-typed or renamed.
  function nextRoomNumber(floor: number | null): string {
    return nextRoomNumberOf(rooms.value, floor)
  }
  function nextFloorNumber(): number {
    return nextFloorNumberOf(rooms.value, trackedFloors.value)
  }

  return {
    route, router, auth, notify, id, loading, error, acc, rules, rooms, images, facilities, docRows, coverUrl,
    occupiedRoomIds, occupiedRoomCount, vacantRoomCount, draftMissing, canAddInventory, inventoryClosedHint,
    distance, mapUrl, sharedFacilities, roomTitle, roomOptions, roomNames, sharedFacilitySub, docs, load, loadDocs,
    fieldReview, accreditationCard, requestChange, refreshAccreditation, trackedFloors, floorLabels, floorName,
    roomsByFloor, floorCount, nextRoomNumber, nextFloorNumber,
  }
}

export type Detail = ReturnType<typeof createDetail>

function createAll() {
  const core = createDetail()
  const listing = createListing(core)
  const floors = createFloors(core)
  const rooms = createRooms(core, floors)
  const roomActions = createRoomActions(core, rooms)
  const facilities = createFacilities(core, rooms)
  return { ...core, ...listing, ...floors, ...rooms, ...roomActions, ...facilities }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('accommodation-detail')

export function provideAccommodationDetail() {
  const detail = createAll()
  provide(KEY, detail)
  return detail
}

export function useAccommodationDetail() {
  const detail = inject(KEY)
  if (!detail) throw new Error('useAccommodationDetail() outside AccommodationDetail')
  return detail
}
