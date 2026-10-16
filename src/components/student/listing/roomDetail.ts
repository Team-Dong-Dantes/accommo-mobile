// Loads one room with everything its page shows, and the student's own
// stays (to know whether they can ask to apply).
import { AMENITY_META, UTILITIES, roomTypeLabel, utilitiesFromRow, utilityTermsLabel } from '@/utils/listings'
import { POLICY_TERMS, ROOM_DETAIL } from '@/api/selects'
import { authUser, supabase } from '@/utils/supabase'
import { campusDistanceLabel } from '@/utils/geo'
import { computed, reactive, ref } from 'vue'
import { errorMessage } from '@/utils/errors'
import { formatPeso, initialsOf, landlordTitle } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { tenantMonthlyRent } from '@/utils/payments'
import { useRoute, useRouter } from 'vue-router'

export function useRoomDetail() {
  const route = useRoute()
  const router = useRouter()

  const loading = ref(true)
  const error = ref('')
  // Unspecified (rooms from before utilities existed) is left out, not shown blank.
  const utilities = ref<{ label: string; value: string }[]>([])
  const room = reactive({
    label: '',
    propertyId: '',
    propertyName: '',
    type: null as string | null,
    capacity: null as number | null,
    floor: null as number | null,
    floorName: '',
    rent: 0,
    rentBasis: 'room' as 'room' | 'person',
    free: false,
    lat: null as number | null,
    lng: null as number | null,
  })
  const images = ref<string[]>([])
  const amenities = ref<string[]>([])
  const facilities = ref<{ type: string; label: string | null }[]>([])
  const policy = reactive({ advanceMonths: 0, depositMonths: 0, contractType: '' })
  const manager = reactive({ id: '', name: '', title: landlordTitle(null), initials: '?', avatarUrl: null as string | null, replyMinutes: null as number | null })
  const myLease = reactive({ hasAny: false, onThisRoom: false })
  const listingDescription = ref('')
  interface SiblingRoom {
    id: string
    label: string
    capacity: number
    type: string
    rent: number
    rentBasis: 'room' | 'person'
    free: boolean
    image: string
  }
  const siblingRooms = ref<SiblingRoom[]>([])
  const visibleSiblingRooms = computed(() => siblingRooms.value.filter((r) => r.free))

  const id = computed(() => String(route.params.id || ''))
  const typeLabel = computed(() => (room.type ? roomTypeLabel(room.type) : ''))
  const distance = computed(() => campusDistanceLabel(room.lat, room.lng))
  const shared = computed(() => (room.capacity ?? 0) > 1)
  const perPersonSuffix = computed(() => (!shared.value ? '' : room.rentBasis === 'person' ? ' per person' : ' for the room'))
  /** What one tenant pays: a whole-room rate is split across its beds, as the lease will be. */
  const share = computed(() => tenantMonthlyRent(room.rent, room.rentBasis, room.capacity))
  const moveIn = computed(() => {
    if (!room.rent || (!policy.advanceMonths && !policy.depositMonths)) return null
    const advance = policy.advanceMonths * share.value
    const deposit = policy.depositMonths * share.value
    return {
      advanceMonths: policy.advanceMonths,
      depositMonths: policy.depositMonths,
      advance,
      deposit,
      total: advance + deposit,
    }
  })

  /** What moving in costs, as rows under "Move-in cost". */
  const moveInRows = computed(() => [
    ...(moveIn.value && shared.value && room.rentBasis !== 'person' ? [{ label: 'Your share of the rent', value: `${formatPeso(share.value)}/mo` }] : []),
    ...(moveIn.value?.advance ? [{ label: `Advance (${moveIn.value.advanceMonths} mo)`, value: formatPeso(moveIn.value.advance) }] : []),
    ...(moveIn.value?.deposit ? [{ label: `Deposit (${moveIn.value.depositMonths} mo)`, value: formatPeso(moveIn.value.deposit) }] : []),
    ...(policy.contractType ? [{ label: 'Contract type', value: policy.contractType }] : []),
  ])

  async function load() {
    loading.value = true
    error.value = ''
    try {
      const { data, error: loadError } = await supabase
        .from('rooms')
        .select(
          // Named foreign key: rooms and accommodation_facilities are also joined
          // through accommodation_facility_rooms, so an unnamed embed is ambiguous
          // (PGRST201) and fails the whole query. This page wants the room's own
          // private facilities — the ones pointing at it by room_id.
          `${ROOM_DETAIL},room_images(url,sort_order),accommodation_facilities!accommodation_facilities_room_id_fkey(facility_type,label),accommodations(id,name,address,city,barangay,lat,lng,landlord_id,status,description,accommodation_floors(floor_number,label),accommodation_amenities(amenity),accommodation_images(url,sort_order),accommodation_policies(${POLICY_TERMS}))`,
        )
        .eq('id', id.value)
        .maybeSingle()
      if (loadError) throw loadError

      const property = data?.accommodations as
        | {
            id: string
            name: string | null
            landlord_id: string | null
            status: string
            lat: number | null
            lng: number | null
            description: string | null
            accommodation_floors: { floor_number: number; label: string | null }[] | null
            accommodation_amenities: { amenity: string }[] | null
            accommodation_images: { url: string; sort_order: number | null }[] | null
            accommodation_policies: {
              advance_months: number | null
              deposit_months: number | null
              contract_type: string | null
            } | null
          }
        | null
      if (!data || !property || property.status !== 'accredited') {
        error.value = 'This room is no longer available.'
        return
      }

      room.label = data.label || (data.room_number ? `Room ${data.room_number}` : 'Room')
      room.propertyId = property.id
      room.propertyName = property.name?.trim() || 'Unnamed accommodation'
      room.type = data.custom_room_type || data.room_type
      room.capacity = data.capacity
      room.floor = data.floor
      // The landlord/landlady's name for the floor ("Ground floor"), if any.
      room.floorName = property.accommodation_floors?.find((f) => f.floor_number === data.floor)?.label || ''
      room.rent = Number(data.monthly_rent ?? 0)
      room.rentBasis = data.rent_basis === 'person' ? 'person' : 'room'
      room.free = data.status === 'available'
      const terms = utilitiesFromRow(data)
      utilities.value = UTILITIES.filter((u) => terms[u.key].billing).map((u) => ({ label: u.label, value: utilityTermsLabel(terms[u.key]) }))
      room.lat = property.lat
      room.lng = property.lng

      amenities.value = (property.accommodation_amenities ?? []).map((a) => a.amenity).filter((a) => a in AMENITY_META)
      listingDescription.value = property.description || ''

      facilities.value = ((data.accommodation_facilities ?? []) as { facility_type: string; label: string | null }[])
        .map((f) => ({ type: f.facility_type, label: f.label }))

      // So a student can browse other rooms in the same property without
      // backing out to the listing and finding the Rooms section again.
      const { data: siblingRows, error: siblingError } = await supabase
        .from('rooms')
        .select('id,label,room_number,room_type,custom_room_type,capacity,monthly_rent,rent_basis,status,room_images(url,sort_order)')
        .eq('accommodation_id', property.id)
        .neq('id', id.value)
      if (siblingError) throw siblingError
      siblingRooms.value = ((siblingRows ?? []) as {
        id: string
        label: string | null
        room_number: string | null
        room_type: string | null
        custom_room_type: string | null
        capacity: number | null
        monthly_rent: number | null
        rent_basis: string | null
        status: string
        room_images: { url: string; sort_order: number | null }[] | null
      }[])
        .map((r) => {
          const roomImgs = [...(r.room_images ?? [])].sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
          return {
            id: r.id,
            label: r.label || (r.room_number ? `Room ${r.room_number}` : 'Room'),
            capacity: Number(r.capacity ?? 0),
            type: roomTypeLabel(r.custom_room_type || r.room_type),
            rent: Number(r.monthly_rent ?? 0),
            rentBasis: (r.rent_basis === 'person' && (r.capacity ?? 0) > 1 ? 'person' : 'room') as 'room' | 'person',
            free: r.status === 'available',
            image: roomImgs[0]?.url ? resolveAsset(roomImgs[0].url) : '',
          }
        })
        .sort((a, b) => Number(b.free) - Number(a.free) || a.rent - b.rent)

      // A room's own advance/deposit terms override the property's default —
      // fall back to the accommodation-level policy only when this room hasn't
      // set its own (most rooms don't; without this fallback the whole
      // "Move-in cost" section silently disappeared for them).
      const accPolicy = property.accommodation_policies
      policy.advanceMonths = data.advance_months ?? accPolicy?.advance_months ?? 0
      policy.depositMonths = data.deposit_months ?? accPolicy?.deposit_months ?? 0
      // Contract terms are set at the property level only (no
      // per-room override exists in the schema), so no fallback chain needed.
      policy.contractType = accPolicy?.contract_type ?? ''

      // Most rooms have no photos of their own yet — fall back to the
      // property's photos rather than showing a bare monogram.
      const roomImages = [...((data.room_images ?? []) as { url: string; sort_order: number | null }[])].sort(
        (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0),
      )
      const sourceImages = roomImages.length
        ? roomImages
        : [...(property.accommodation_images ?? [])].sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
      images.value = sourceImages.map((i) => resolveAsset(i.url)).filter(Boolean)

      if (property.landlord_id) {
        const [{ data: person }, { data: profile }] = await Promise.all([
          supabase
            .from('users')
            .select('full_name,initials,avatar_url,sex')
            .eq('id', property.landlord_id)
            .maybeSingle(),
          supabase
            .from('landlord_profiles')
            .select('avg_response_minutes')
            .eq('user_id', property.landlord_id)
            .maybeSingle(),
        ])
        manager.id = property.landlord_id
        manager.name = person?.full_name || landlordTitle(person?.sex)
        manager.title = landlordTitle(person?.sex)
        manager.initials = person?.initials || initialsOf(manager.name)
        manager.avatarUrl = person?.avatar_url ? resolveAsset(person.avatar_url) : null
        manager.replyMinutes = profile?.avg_response_minutes ?? null
      }

      const { data: authData } = await authUser()
      const uid = authData?.user?.id
      if (uid) {
        const { data: mine } = await supabase
          .from('leases')
          .select('room_id,status')
          .eq('student_id', uid)
          .in('status', ['pending', 'active', 'leave_requested'])
        const list = mine ?? []
        myLease.hasAny = list.length > 0
        myLease.onThisRoom = list.some((l) => l.room_id === id.value)
      }
    } catch (e) {
      error.value = errorMessage(e, 'Something went wrong.')
    } finally {
      loading.value = false
    }
  }

  // Opens the thread. When the room is actually open to apply for, it travels as the
  // inquiry (`?room=`) — that is what the landlord/landlady's "Send application form" button
  // reads. A taken room, or a student who already has a stay, just opens the chat:
  // stamping an inquiry there would only produce a form invite_application() refuses.

  return {
    route,
    router,
    loading,
    error,
    utilities,
    room,
    images,
    amenities,
    facilities,
    policy,
    manager,
    myLease,
    listingDescription,
    siblingRooms,
    visibleSiblingRooms,
    id,
    typeLabel,
    distance,
    shared,
    perPersonSuffix,
    share,
    moveIn,
    moveInRows,
    load,
  }
}
