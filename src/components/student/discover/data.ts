// Discover's listings: loading accredited accommodations, their rooms and the
// landlords/landladies behind them, and the search and filters over all three.
import { computed, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/utils/supabase'
import { landlordTitle } from '@/utils/format'
import { resolveAsset, AVATAR, CARD } from '@/utils/cloudinaryUrl'
import { campusDistanceLabel } from '@/utils/geo'
import { isUtilityAvailable, roomTypeLabel, buildingTypeLabel, genderPolicyLabel, listingMonogram } from '@/utils/listings'
import { takesSex } from '@/utils/mapPins'

export interface Property {
  id: string
  name: string
  address: string
  image: string
  monogram: string
  distance: string
  vacancies: number
  minRent: number | null
  minVacantRent: number | null
  buildingType: string
  buildingKind: string | null
  genderPolicy: string
  genderKind: string | null
  lat: number | null
  lng: number | null
  haystack: string
}

export interface RoomTile {
  id: string
  propertyId: string
  label: string
  image: string
  monogram: string
  propertyName: string
  meta: string
  typeLabel: string
  rent: number
  rentBasis: 'room' | 'person'
  free: boolean
  roomType: string
  amenities: string[]
  lat: number | null
  lng: number | null
  haystack: string
}

export interface ManagerRow {
  id: string
  name: string
  initials: string
  avatarUrl: string | null
  propertyCount: number
  haystack: string
}

export function createDiscoverData() {
  const router = useRouter()

  const loading = ref(true)
  const error = ref('')
  const query = ref('')
  const properties = ref<Property[]>([])
  const rooms = ref<RoomTile[]>([])
  const managers = ref<ManagerRow[]>([])

  // users.sex (M | F | U) of the signed-in student, so places that don't take
  // them fade on the map. Null signed-out, which fades nothing.
  const mySex = ref<string | null>(null)
  async function loadMySex() {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) return
    const { data } = await supabase.from('users').select('sex').eq('id', session.user.id).maybeSingle()
    mySex.value = data?.sex ?? null
  }
  function fitsMe(p: Property) {
    return takesSex(p.genderKind, mySex.value)
  }

  const filtersOpen = ref(false)
  const DEFAULT_MAX = 10000
  const rentBounds = reactive({ min: 0, max: DEFAULT_MAX })
  const filters = reactive({
    vacantOnly: true,
    maxRent: DEFAULT_MAX,
    roomTypes: [] as string[],
    amenities: [] as string[],
  })

  const roomTypeOptions = computed(() => {
    const seen = new Set<string>()
    for (const r of rooms.value) if (r.roomType) seen.add(r.roomType)
    return [...seen].sort()
  })

  const activeFilterCount = computed(
    () =>
      (filters.vacantOnly ? 0 : 1) +
      (filters.maxRent < rentBounds.max ? 1 : 0) +
      filters.roomTypes.length +
      filters.amenities.length,
  )

  const filteredProperties = computed(() => filterByHaystack(properties.value))
  const filteredManagers = computed(() => filterByHaystack(managers.value))
  const filteredRooms = computed(() => {
    return filterByHaystack(rooms.value).filter((r) => {
      if (filters.vacantOnly && !r.free) return false
      // A room with no listed rent can't be excluded on price without hiding
      // it from every search, so it only drops out below the ceiling.
      if (filters.maxRent < rentBounds.max && r.rent > 0 && r.rent > filters.maxRent) return false
      if (filters.roomTypes.length && !filters.roomTypes.includes(r.roomType)) return false
      if (filters.amenities.length && !filters.amenities.every((a) => r.amenities.includes(a))) return false
      return true
    })
  })

  /** What the map shows — the pins and the full-map rail both read this, so
   * searching and filtering reach the map, not just the list below it. A place
   * survives an active filter when it still has at least one room that passes,
   * reusing filteredRooms rather than restating the rules, so the map can't
   * drift away from the room grid. Filters only bite once one is actually
   * set (activeFilterCount treats the default "vacant only" as unset), which
   * keeps the untouched default view showing everything, full places included. */
  const mapProperties = computed(() => {
    const matching = filterByHaystack(properties.value)
    if (activeFilterCount.value === 0) return matching
    const withMatchingRooms = new Set(filteredRooms.value.map((r) => r.propertyId))
    return matching.filter((p) => withMatchingRooms.has(p.id))
  })

  function filterByHaystack<T extends { haystack: string }>(list: T[]): T[] {
    const needle = query.value.trim().toLowerCase()
    return needle ? list.filter((item) => item.haystack.includes(needle)) : list
  }

  function toggle(list: string[], value: string) {
    const at = list.indexOf(value)
    if (at === -1) list.push(value)
    else list.splice(at, 1)
  }

  function resetFilters() {
    filters.vacantOnly = true
    filters.maxRent = rentBounds.max
    filters.roomTypes = []
    filters.amenities = []
  }

  function open(id: string) {
    void router.push(`/student/listing/${id}`)
  }

  const railEl = ref<HTMLElement | null>(null)
  function slideRail(dir: 1 | -1) {
    railEl.value?.scrollBy({ left: dir * railEl.value.clientWidth * 0.9, behavior: 'smooth' })
  }

  function openRoom(id: string) {
    void router.push(`/student/room/${id}`)
  }

  function openManager(id: string) {
    void router.push(`/student/manager/${id}`)
  }

  async function loadProperties(silent = false) {
    // Only accredited listings are readable, and the policy grants the public
    // role, so this works signed-out too — keep this select clear of the
    // `users` table, which anon cannot read at all.
    const { data, error: loadError } = await supabase
      .from('accommodations')
      .select(
        'id,name,address,city,barangay,purok,lat,lng,accommodation_type,gender_policy,rooms(id,label,room_number,room_type,custom_room_type,capacity,monthly_rent,rent_basis,status,wifi_billing,room_images(url,sort_order)),accommodation_amenities(amenity),accommodation_facilities(facility_type),accommodation_images(url,sort_order)',
      )
      .eq('status', 'accredited').eq('hidden_from_listings', false)
    if (loadError) throw loadError

    const propertyList: Property[] = []
    const roomList: RoomTile[] = []
    let rentCeiling = 0

    for (const row of data ?? []) {
      const rows = (row.rooms ?? []) as {
        id: string
        label: string | null
        room_number: string | null
        room_type: string | null
        custom_room_type: string | null
        capacity: number | null
        monthly_rent: number | null
        rent_basis: string | null
        status: string
        wifi_billing: string | null
        room_images: { url: string; sort_order: number | null }[] | null
      }[]
      const priced = rows.map((r) => Number(r.monthly_rent)).filter((n) => n > 0)
      const minRent = priced.length ? Math.min(...priced) : null
      const vacantPriced = rows.filter((r) => r.status === 'available').map((r) => Number(r.monthly_rent)).filter((n) => n > 0)
      const minVacantRent = vacantPriced.length ? Math.min(...vacantPriced) : null

      const images = [...((row.accommodation_images ?? []) as { url: string; sort_order: number | null }[])]
        .sort((x, y) => (x.sort_order ?? 0) - (y.sort_order ?? 0))
      // Amenities plus facility types, so one filter covers both (see SEARCH_FEATURES).
      const amenities = [
        ...((row.accommodation_amenities ?? []) as { amenity: string }[]).map((a) => a.amenity),
        ...((row.accommodation_facilities ?? []) as { facility_type: string }[]).map((f) => f.facility_type),
        // Wi-Fi is per room; the listing offers it when any room has it.
        ...(rows.some((r) => isUtilityAvailable({ billing: r.wifi_billing, flatFee: null })) ? ['wifi'] : []),
      ]
      const address = row.address || [row.purok, row.barangay, row.city].filter(Boolean).join(', ') || 'Address not given'
      const name = row.name?.trim() || 'Unnamed accommodation'
      const monogram = listingMonogram(name)

      propertyList.push({
        id: row.id,
        name,
        address,
        image: images[0]?.url ? resolveAsset(images[0].url, CARD) : '',
        monogram,
        distance: campusDistanceLabel(row.lat, row.lng),
        vacancies: rows.filter((r) => r.status === 'available').length,
        minRent,
        minVacantRent,
        buildingType: buildingTypeLabel(row.accommodation_type),
        buildingKind: row.accommodation_type ?? null,
        genderPolicy: genderPolicyLabel(row.gender_policy),
        genderKind: row.gender_policy ?? null,
        lat: typeof row.lat === 'number' ? row.lat : null,
        lng: typeof row.lng === 'number' ? row.lng : null,
        haystack: `${name} ${address}`.toLowerCase(),
      })

      for (const r of rows) {
        const roomImages = [...(r.room_images ?? [])].sort((x, y) => (x.sort_order ?? 0) - (y.sort_order ?? 0))
        const label = r.label || (r.room_number ? `Room ${r.room_number}` : 'Room')
        const roomType = r.custom_room_type || r.room_type || ''
        const typeLabel = roomTypeLabel(roomType)
        const rent = Number(r.monthly_rent ?? 0)
        if (rent > 0) rentCeiling = Math.max(rentCeiling, rent)
        roomList.push({
          id: r.id,
          propertyId: row.id,
          label,
          image: roomImages[0]?.url ? resolveAsset(roomImages[0].url, CARD) : '',
          monogram,
          propertyName: name,
          meta: r.capacity ? `${r.capacity} left` : '',
          typeLabel,
          rent,
          rentBasis: r.rent_basis === 'person' && (r.capacity ?? 0) > 1 ? 'person' : 'room',
          free: r.status === 'available',
          roomType,
          amenities,
          // A room has no coordinates of its own — it's wherever its building is.
          lat: typeof row.lat === 'number' ? row.lat : null,
          lng: typeof row.lng === 'number' ? row.lng : null,
          haystack: `${name} ${address} ${label} ${typeLabel}`.toLowerCase(),
        })
      }
    }

    // Somewhere to move beats somewhere full, then cheapest first.
    propertyList.sort((a, b) => {
      if ((b.vacancies > 0 ? 1 : 0) !== (a.vacancies > 0 ? 1 : 0)) {
        return (b.vacancies > 0 ? 1 : 0) - (a.vacancies > 0 ? 1 : 0)
      }
      return (a.minRent ?? Number.MAX_SAFE_INTEGER) - (b.minRent ?? Number.MAX_SAFE_INTEGER)
    })
    roomList.sort((a, b) => Number(b.free) - Number(a.free) || a.rent - b.rent)

    properties.value = propertyList
    rooms.value = roomList
    rentBounds.max = Math.max(DEFAULT_MAX, Math.ceil(rentCeiling / 500) * 500)
    // A silent (realtime-triggered) refresh must not reset a filter the
    // student has actively narrowed — only the real first load defaults it.
    if (!silent) filters.maxRent = rentBounds.max
  }

  async function loadManagers() {
    // Anon (fully signed-out) sessions have no grant on `users` at all, so this
    // is expected to come back empty rather than throw for a signed-out demo
    // session — a real authenticated student can read it. Kept separate from
    // loadProperties() so that failure never blocks the rest of the page.
    try {
      const { data, error: loadError } = await supabase
        .from('users')
        // The FK must be named: `accommodations` points at `users` twice (the
        // landlord/landlady who owns it, and the admin reviewing it), and PostgREST refuses
        // an ambiguous embed outright — so this query threw on every load and the
        // Landlords/Landladies tab was permanently empty.
        .select(
          'id,full_name,avatar_url,sex,accommodations!accommodations_landlord_id_fkey(id,name,status)',
        )
        .eq('role', 'landlord')
      if (loadError) throw loadError

      managers.value = (data ?? [])
        .map((row) => {
          const accredited = ((row.accommodations ?? []) as { id: string; name: string; status: string }[]).filter(
            (a) => a.status === 'accredited',
          )
          const name = row.full_name?.trim() || landlordTitle(row.sex)
          return {
            id: row.id,
            name,
            initials: name
              .split(/\s+/)
              .filter(Boolean)
              .slice(0, 2)
              .map((w) => w[0]?.toUpperCase())
              .join(''),
            avatarUrl: row.avatar_url ? resolveAsset(row.avatar_url, AVATAR) : null,
            propertyCount: accredited.length,
            haystack: `${name} ${accredited.map((a) => a.name).join(' ')}`.toLowerCase(),
          }
        })
        // Landlords and landladies actively hosting listings surface first.
        .sort((a, b) => b.propertyCount - a.propertyCount || a.name.localeCompare(b.name))
    } catch {
      managers.value = []
    }
  }

  return {
    router, loading, error, query, properties, rooms, managers, mySex, loadMySex, fitsMe, filtersOpen, rentBounds,
    filters, roomTypeOptions, activeFilterCount, filteredProperties, filteredManagers, filteredRooms, mapProperties,
    toggle, resetFilters, open, railEl, slideRail, openRoom, openManager, loadProperties, loadManagers,
  }
}
