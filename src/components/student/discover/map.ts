// Discover's map: the Mapbox instance, a price pin per accommodation, the
// card rail synced with the pins, the walking route to campus for the picked
// place, and "where am I".
import { computed, nextTick, reactive, ref, watch } from 'vue'
import { Dark } from 'quasar'
import mapboxgl from '@/utils/mapbox'
import { isDesktop } from '@/utils/useTabletMode'
import { campusDistanceLabel, kmBetween, geolocationErrorMessage, CAMPUS } from '@/utils/geo'
import { useNotify } from '@/utils/notify'
import { pinLabel, walkMinutesGuess, pricePinElement, campusBadgeElement } from '@/utils/mapPins'
import type { createDiscoverData, Property } from './data'

export function createDiscoverMap(data: ReturnType<typeof createDiscoverData>) {
  const { properties, mapProperties, fitsMe, mySex } = data
  const notify = useNotify()

  // Map preview + full-screen toggle — the map's height is a plain vh slice of
  // the page, so it lives in normal document flow above the list and the
  // existing page scroll (see MainLayout's .q-page-container) keeps working
  // unchanged; no special fixed-height layout is needed for "expand it to fill
  // the page". Two states, switched by pressing a button rather than dragging
  // a handle — a plain height transition (CSS) between them.
  const MAPBOX_TOKEN = import.meta.env.VITE_MAPBOX_TOKEN as string | undefined
  const hasMapToken = Boolean(MAPBOX_TOKEN)
  const deskMap = computed(() => hasMapToken && isDesktop.value)
  const MAP_PREVIEW_VH = 32
  const mapEl = ref<HTMLElement | null>(null)
  const mapExpanded = ref(false)

  // The floating header reserves this much space via padding-top on
  // .q-page-container rather than pushing it down in normal flow (it's
  // `position: fixed`). Reused to pull the map's own top edge up by the same
  // amount, so it runs behind the header instead of starting below it.
  const headerReservedPx = ref(0)

  function measureViewport() {
    const container = document.querySelector('.q-page-container') as HTMLElement | null
    if (!container) return
    headerReservedPx.value = parseFloat(getComputedStyle(container).paddingTop) || 0
  }

  /** The height applied to the map. The negative margin above puts the map's
   * top edge at the top of the window, so expanded is simply the window's own
   * height — `dvh` rather than `vh` so a mobile browser showing/hiding its URL
   * bar doesn't leave the map overhanging the screen. This used to be measured
   * off `.q-page-container`'s rendered box, but that box is as tall as the
   * page's whole content (map + every listing below it), so the expanded map
   * came out around twice the height of the screen: the map rendered for a
   * viewport far taller than the visible one, which is why it looked stretched
   * and why pins sat off-screen and slid around when zooming. */
  const mapFillHeight = computed(() =>
    deskMap.value ? '100%' : mapExpanded.value ? '100dvh' : `${MAP_PREVIEW_VH}vh`,
  )

  // In preview it's a plain in-flow block that scrolls away with the rest of the
  // page, pulled up by the header's reserved padding so it fills that space
  // (running behind the floating header) instead of leaving a blank gap above
  // it. Expanded, `.map-region--full` lifts it out of flow entirely — see there
  // for why. The negative margin has to go with it, or the fixed box would sit
  // that far above the viewport.
  // On desktop the page is the list half of a card, below the header rather than
  // behind it, so the map starts at the card's top edge like everything else.
  const mapUnderHeaderPx = computed(() => (isDesktop.value ? 0 : headerReservedPx.value))

  const mapRegionStyle = computed(() => ({
    height: mapFillHeight.value,
    marginTop: mapExpanded.value ? '0px' : `-${mapUnderHeaderPx.value}px`,
  }))

  // The place picked on the map, by pin or by swiping to its card.
  const selectedId = ref<string | null>(null)
  const selected = computed(() => properties.value.find((p) => p.id === selectedId.value) ?? null)
  /** Real walking minutes from Directions, per place, once a route is fetched. */
  const routeMinutes = reactive<Record<string, number>>({})

  function walkText(p: Property) {
    const min = routeMinutes[p.id] ?? walkMinutesGuess(p.lat, p.lng)
    return min === null ? '' : `${routeMinutes[p.id] ? '' : '~'}${min} min walk to campus`
  }

  let map: mapboxgl.Map | null = null
  let markers: mapboxgl.Marker[] = []
  const pinEls = new Map<string, HTMLElement>()
  let mapResizeObserver: ResizeObserver | null = null
  let campusLinkLabel: mapboxgl.Marker | null = null

  /** The map's cards: every place on the map, or on desktop (list beside it)
   * just the picked one. */
  const railItems = computed(() => (deskMap.value ? (selected.value ? [selected.value] : []) : mapProperties.value))

  function toggleMapExpanded(expanded: boolean) {
    // The expanded height fills the whole window on the assumption the map
    // sits at the very top of the scroll container. It's no longer sticky, so
    // if the page was scrolled down at all when "Map view" is tapped, that
    // assumption breaks and the tall box overshoots past the bottom of the
    // screen — snap back to the top first so it always holds.
    if (expanded) document.querySelector('.q-page-container')?.scrollTo({ top: 0 })
    mapExpanded.value = expanded
  }

  let locateCtl: mapboxgl.GeolocateControl | null = null
  const locating = ref(false)
  const located = ref(false)
  function locateMe() {
    locating.value = Boolean(locateCtl?.trigger())
  }

  function initMap() {
    if (!mapEl.value || map || !hasMapToken) return
    mapboxgl.accessToken = MAPBOX_TOKEN!
    map = new mapboxgl.Map({
      container: mapEl.value,
      style: mapStyle(),
      center: [CAMPUS.lng, CAMPUS.lat],
      zoom: 13,
    })
    // "Where am I?" — Mapbox's own control, so the user dot, accuracy ring and
    // permission prompt come for free. Its button is hidden (see the CSS) and
    // our own beside "List view" calls trigger(). One-shot rather than
    // trackUserLocation, which would keep re-centring on the student and fight
    // the framing below.
    locateCtl = new mapboxgl.GeolocateControl({
      positionOptions: { enableHighAccuracy: true, timeout: 20000 },
      trackUserLocation: false,
      showUserLocation: true,
    })
    map.addControl(locateCtl)
    // Centring on the student alone would push the listings off screen, and the
    // point is seeing yourself *and* the places at once.
    locateCtl.on('geolocate', (position) => {
      const p = position as GeolocationPosition
      locating.value = false
      located.value = true
      frameAround([p.coords.longitude, p.coords.latitude])
    })
    locateCtl.on('error', (err) => {
      locating.value = false
      notify.error(geolocationErrorMessage(err as GeolocationPositionError))
    })

    // style.load, not load: a theme switch swaps the style, which drops the
    // route layer, and this puts it back (with the route, if one is showing).
    map.on('style.load', () => {
      addCampusLinkLayer()
      if (selected.value) void showCampusLink(selected.value)
    })
    map.on('load', () => syncMarkers(!mapExpanded.value))
    // Mapbox has no built-in tracking of its own container's size (only a
    // window-resize listener) — its canvas keeps whatever pixel size it was
    // last told, so if that ever drifts from the container's real rendered
    // size (a CSS transition settling a frame later than expected, a
    // heuristic timer firing early, ...) the map renders visibly stretched.
    // A ResizeObserver reports the container's actual settled size on every
    // change, so resizing from it can't go stale the way a one-shot guess can.
    mapResizeObserver = new ResizeObserver(() => map?.resize())
    mapResizeObserver.observe(mapEl.value)
    addCampusMarker()
  }

  /** A muted base map, so the price pins are what stands out; dark in dark mode. */
  function mapStyle() {
    return Dark.isActive ? 'mapbox://styles/mapbox/dark-v11' : 'mapbox://styles/mapbox/light-v11'
  }
  watch(() => Dark.isActive, () => map?.setStyle(mapStyle()))

  /** Every distance on this page reads "N m from campus", so the campus itself
   * has to be on the map for that to mean anything. A badge rather than a pin,
   * so it never reads as a listing. Added once (it never moves) and kept out of
   * `markers`, which syncMarkers() clears on every refresh. */
  function addCampusMarker() {
    if (!map) return
    new mapboxgl.Marker({ element: campusBadgeElement(CAMPUS.label) }).setLngLat([CAMPUS.lng, CAMPUS.lat]).addTo(map)
  }

  const CAMPUS_LINK = 'campus-link'

  /** Empty line source + layer, created once the style is ready; selecting a
   * place just swaps the source's data rather than adding/removing layers. */
  function addCampusLinkLayer() {
    if (!map || map.getSource(CAMPUS_LINK)) return
    map.addSource(CAMPUS_LINK, {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
    })
    map.addLayer({
      id: CAMPUS_LINK,
      type: 'line',
      source: CAMPUS_LINK,
      layout: { 'line-cap': 'round' },
      paint: {
        'line-color': getComputedStyle(document.documentElement).getPropertyValue('--m-primary-dark').trim() || '#0f766e',
        'line-width': 3,
        // Dashed, so it reads as "distance to campus" rather than as a road.
        'line-dasharray': [1.6, 1.4],
      },
    })
  }

  type Coord = [number, number]

  /** Bumped on every selection so a slow response for a place you've already
   * navigated away from can't overwrite the current route. */
  let campusLinkRequest = 0

  /** The walking route along actual roads, from Mapbox Directions. */
  async function fetchWalkingRoute(from: Coord, to: Coord) {
    const url =
      `https://api.mapbox.com/directions/v5/mapbox/walking/` +
      `${from[0]},${from[1]};${to[0]},${to[1]}` +
      `?geometries=geojson&overview=full&access_token=${MAPBOX_TOKEN}`
    try {
      const res = await fetch(url)
      if (!res.ok) return null
      const route = (await res.json())?.routes?.[0]
      const coordinates = route?.geometry?.coordinates
      if (!Array.isArray(coordinates) || coordinates.length < 2) return null
      return { coordinates: coordinates as Coord[], distance: Number(route.distance), duration: Number(route.duration) }
    } catch {
      return null
    }
  }

  /** The point half way *along* the route, so the label sits mid-walk. Using
   * the middle array index instead would drag it toward whichever end has the
   * most turns, since that's where the vertices bunch up. */
  function midpointAlong(coords: Coord[]): Coord {
    const legs = coords.slice(1).map((c, i) => kmBetween(coords[i]![1], coords[i]![0], c[1], c[0]))
    const half = legs.reduce((a, b) => a + b, 0) / 2
    let walked = 0
    for (let i = 0; i < legs.length; i++) {
      walked += legs[i]!
      if (walked >= half) return coords[i + 1]!
    }
    return coords[coords.length - 1]!
  }

  function walkLabel(metres: number, seconds: number) {
    const dist = metres < 1000 ? `${Math.round(metres)} m` : `${(metres / 1000).toFixed(1)} km`
    return `${dist} · ${Math.max(1, Math.round(seconds / 60))} min walk`
  }

  function setCampusLink(coordinates: Coord[], labelAt: Coord, text: string) {
    const source = map?.getSource(CAMPUS_LINK) as mapboxgl.GeoJSONSource | undefined
    if (!map || !source) return
    source.setData({ type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates } })
    const el = document.createElement('div')
    el.className = 'campus-link-label'
    el.textContent = text
    campusLinkLabel?.remove()
    campusLinkLabel = new mapboxgl.Marker({ element: el }).setLngLat(labelAt).addTo(map)
  }

  /** Traces the walk from the selected place to campus along the roads, with
   * the walking distance and time at the halfway point. Falls back to a plain
   * straight line (and the page's usual as-the-crow-flies distance) if
   * Directions can't be reached, so the link never just silently vanishes. */
  async function showCampusLink(pin: Property) {
    if (!map || pin.lat === null || pin.lng === null) return clearCampusLink()
    const from: Coord = [pin.lng, pin.lat]
    const to: Coord = [CAMPUS.lng, CAMPUS.lat]

    const token = ++campusLinkRequest
    const route = await fetchWalkingRoute(from, to)
    if (route) routeMinutes[pin.id] = Math.max(1, Math.round(route.duration / 60))
    if (token !== campusLinkRequest || !selectedId.value) return

    if (route) {
      setCampusLink(route.coordinates, midpointAlong(route.coordinates), walkLabel(route.distance, route.duration))
    } else {
      const straight: Coord[] = [from, to]
      setCampusLink(straight, [(from[0] + to[0]) / 2, (from[1] + to[1]) / 2], pin.distance || campusDistanceLabel(pin.lat, pin.lng))
    }
  }

  function clearCampusLink() {
    // Invalidates any in-flight route so a late response can't draw itself
    // back on after the card has been closed.
    campusLinkRequest++
    const source = map?.getSource(CAMPUS_LINK) as mapboxgl.GeoJSONSource | undefined
    source?.setData({ type: 'FeatureCollection', features: [] })
    campusLinkLabel?.remove()
    campusLinkLabel = null
  }

  /** Frames the student's own position together with the listings and campus,
   * so "where am I" and "where are the places" are answered in one view. */
  function frameAround(me: [number, number]) {
    if (!map) return
    const bounds = new mapboxgl.LngLatBounds().extend(me).extend([CAMPUS.lng, CAMPUS.lat])
    for (const p of mapProperties.value) {
      if (p.lat !== null && p.lng !== null) bounds.extend([p.lng, p.lat])
    }
    map.fitBounds(bounds, {
      padding: { top: 110, right: 80, bottom: mapExpanded.value ? 300 : 60, left: 80 },
      maxZoom: 16,
    })
  }

  /** Re-places one pin per accommodation that has coordinates; called after
   * every load (including silent realtime refreshes) once the map exists.
   * `reframe` defaults to off in full-map mode so a background refresh can't
   * yank the camera out from under someone browsing — but a search or filter
   * change passes it explicitly, since that's the user asking to be shown
   * something and leaving the matches off-screen just looks broken. */
  function syncMarkers(reframe = !mapExpanded.value && !deskMap.value) {
    if (!map) return
    for (const marker of markers) marker.remove()
    markers = []
    pinEls.clear()

    const located = mapProperties.value.filter(
      (p): p is Property & { lat: number; lng: number } => p.lat !== null && p.lng !== null,
    )
    for (const property of located) {
      const { anchor, pin: el } = pricePinElement(property.name, pinLabel(property), { full: !property.vacancies, dim: !fitsMe(property) })
      if (property.id === selectedId.value) el.classList.add('price-pin--on')
      // Tapping a pin selects it and scrolls its card into view instead of
      // leaving the map. On the preview strip it opens the full map first.
      el.addEventListener('click', (e) => {
        e.stopPropagation()
        if (mapExpanded.value || deskMap.value) return selectPin(property, true)
        toggleMapExpanded(true)
        // Wait for the rail to render and the map to take its new size, so the
        // card can be scrolled to and the framing fits the full screen.
        void nextTick(() => {
          map?.resize()
          selectPin(property, true)
        })
      })
      markers.push(new mapboxgl.Marker({ element: anchor, anchor: 'bottom', offset: [0, -5] }).setLngLat([property.lng, property.lat]).addTo(map))
      pinEls.set(property.id, el)
    }

    // The default view keeps campus dead centre — it's the reference point
    // every distance on this page is measured from. Mirroring each listing
    // across campus makes the bounding box symmetric about it, so fitting that
    // box centres campus and still frames every pin.
    if (located.length && reframe) {
      const bounds = new mapboxgl.LngLatBounds()
      for (const p of located) {
        bounds.extend([p.lng, p.lat])
        bounds.extend([2 * CAMPUS.lng - p.lng, 2 * CAMPUS.lat - p.lat])
      }
      map.fitBounds(bounds, { padding: 60, maxZoom: 15, duration: 0 })
    }
  }

  /** Picks a place: highlights its pin (the others hide, see
   * .map-region--picked), draws its walk to campus and frames both.
   * `scrollCard` brings its card into view — wanted when the pin was tapped,
   * not when the card was swiped to (it's already there). */
  function selectPin(property: Property, scrollCard = false) {
    pinEls.get(selectedId.value ?? '')?.classList.remove('price-pin--on')
    selectedId.value = property.id
    pinEls.get(property.id)?.classList.add('price-pin--on')
    if (scrollCard) {
      mapRailEl.value
        ?.querySelector<HTMLElement>(`[data-id="${property.id}"]`)
        ?.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' })
    }
    // Not every accommodation has a pinned location — the card still works
    // without one, it just can't draw a line or move the camera.
    if (map && property.lat !== null && property.lng !== null) {
      void showCampusLink(property)
      // Frame both ends rather than zooming into the place alone — the whole
      // point of the line is seeing how far it sits from campus, which you
      // can't judge with campus off-screen.
      const bounds = new mapboxgl.LngLatBounds()
        .extend([property.lng, property.lat])
        .extend([CAMPUS.lng, CAMPUS.lat])
      // Generous side padding: the campus pill is ~110px wide and centred on
      // its coordinate, so a tighter inset leaves it hugging the screen edge.
      map.fitBounds(bounds, { padding: { top: 120, right: 90, bottom: 300, left: 90 }, maxZoom: 16 })
    } else {
      clearCampusLink()
    }
  }

  const mapRailEl = ref<HTMLElement | null>(null)

  /** A swipe came to rest: the card nearest the rail's centre is the pick. A
   * pin tap's own smooth scroll lands here too, on the card already picked,
   * so that one is skipped rather than re-framed. */
  function onRailSettled() {
    const rail = mapRailEl.value
    if (!rail || deskMap.value) return
    const mid = rail.getBoundingClientRect().left + rail.clientWidth / 2
    let best: HTMLElement | null = null
    let bestGap = Infinity
    for (const card of rail.querySelectorAll<HTMLElement>('[data-id]')) {
      const r = card.getBoundingClientRect()
      const gap = Math.abs(r.left + r.width / 2 - mid)
      if (gap < bestGap) [best, bestGap] = [card, gap]
    }
    const id = best?.dataset.id
    if (!id || id === selectedId.value) return
    const property = properties.value.find((p) => p.id === id)
    if (property) selectPin(property)
  }

  function clearSelectedPin() {
    pinEls.get(selectedId.value ?? '')?.classList.remove('price-pin--on')
    selectedId.value = null
    clearCampusLink()
  }

  // Leaving the expanded map shouldn't leave a stale selection waiting behind
  // the rail next time it's re-opened.
  watch(mapExpanded, (expanded) => {
    if (!expanded) clearSelectedPin()
  })

  // A chip or search that hides the picked place drops the pick with it.
  watch(mapProperties, (list) => {
    if (selectedId.value && !list.some((p) => p.id === selectedId.value)) clearSelectedPin()
  })

  // The map used to read the raw property list, so searching and filtering only
  // ever changed the list below it. Re-pinning on every change to the matched
  // set is what actually makes them work in map mode.
  watch(mapProperties, () => syncMarkers(true))
  // Knowing the student's sex (it loads after the pins) changes which pins fade.
  watch(mySex, () => syncMarkers(false))

  function destroyMap() {
    mapResizeObserver?.disconnect()
    mapResizeObserver = null
    campusLinkLabel?.remove()
    campusLinkLabel = null
    for (const marker of markers) marker.remove()
    markers = []
    map?.remove()
    map = null
    locateCtl = null
    locating.value = located.value = false
    pinEls.clear()
    selectedId.value = null
  }

  return {
    hasMapToken, deskMap, mapEl, mapExpanded, headerReservedPx, measureViewport, mapRegionStyle, selectedId, selected,
    walkText, railItems, toggleMapExpanded, locating, located, locateMe, initMap, syncMarkers, mapRailEl,
    onRailSettled, clearSelectedPin, destroyMap,
  }
}
