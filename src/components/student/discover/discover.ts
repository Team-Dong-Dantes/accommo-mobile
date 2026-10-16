// StudentDiscoverPage's state, shared with the map, results and filters it is
// split into. The page creates it (provideDiscover) and registers the
// lifecycle — it is the component KeepAlive caches — and the pieces read the
// same instance (useDiscover).
import { inject, onActivated, onDeactivated, onMounted, onUnmounted, provide, ref, watch, type InjectionKey } from 'vue'
import { useLiveData } from '@/utils/useLiveData'
import { errorMessage } from '@/utils/errors'
import { createDiscoverData, type ManagerRow, type Property, type RoomTile } from './data'
import { createDiscoverMap } from './map'

function createDiscover() {
  const data = createDiscoverData()
  const map = createDiscoverMap(data)
  const { loading, error, properties, rooms, managers, loadProperties, loadManagers, loadMySex } = data
  const { deskMap, mapEl, measureViewport, initMap, syncMarkers, destroyMap } = map

  async function load(silent = false) {
    if (!silent) loading.value = true
    error.value = ''
    try {
      await Promise.all([loadProperties(silent), loadManagers()])
      syncMarkers()
    } catch (e) {
      error.value = errorMessage(e, 'Something went wrong.')
    } finally {
      loading.value = false
    }
  }

  // Kept alive across tab switches (see MainLayout's KEEP_ALIVE_PAGES), so new
  // and updated listings push here instead of the page re-asking on every
  // return. utils/useLiveData.ts owns the whole policy — first load, the
  // subscription's lifetime, and how stale the data may be on return. Public
  // data (accredited listings), so no per-user filter is needed.
  type DiscoverCache = { properties: Property[]; rooms: RoomTile[]; managers: ManagerRow[] }

  useLiveData({
    key: 'student-discover',
    load,
    watch: () => [{ table: 'accommodations' }],
    cache: {
      get: (): DiscoverCache => ({ properties: properties.value, rooms: rooms.value, managers: managers.value }),
      set: (d) => {
        const c = d as DiscoverCache
        properties.value = c.properties
        rooms.value = c.rooms
        managers.value = c.managers
        loading.value = false
      },
    },
  })

  // The map container sits in the `v-else` branch, so it does not exist in the
  // DOM until the first load clears `loading` — mounting is too early to reach
  // it, and initMap() bails on a null ref without ever retrying. Waiting on the
  // template ref itself instead runs it the moment the element is really there,
  // whichever order the load and the render happen to finish in.
  watch(mapEl, (el) => {
    if (el) initMap()
  }, { flush: 'post' })

  onMounted(() => {
    void loadMySex()
    measureViewport()
    window.addEventListener('resize', measureViewport)
  })

  // Desktop keeps this page alive in the shell's list pane, and KeepAlive
  // restores a live Teleport into the page instead of its target (Vue 3.5
  // moveTeleport). So while inactive the map is dropped, and rebuilt in the
  // fresh #desk-map-slot on the way back.
  const active = ref(true)
  onActivated(() => (active.value = true))
  onDeactivated(() => {
    if (!deskMap.value) return
    active.value = false
    destroyMap()
  })

  onUnmounted(() => {
    window.removeEventListener('resize', measureViewport)
    destroyMap()
  })

  return { ...data, ...map, load, active }
}

const KEY: InjectionKey<ReturnType<typeof createDiscover>> = Symbol('student-discover')

export function provideDiscover() {
  const discover = createDiscover()
  provide(KEY, discover)
  return discover
}

export function useDiscover() {
  const discover = inject(KEY)
  if (!discover) throw new Error('useDiscover() outside StudentDiscoverPage')
  return discover
}
