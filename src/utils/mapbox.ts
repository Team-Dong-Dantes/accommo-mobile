import mapboxgl from 'mapbox-gl'
import 'mapbox-gl/dist/mapbox-gl.css'

// Every map in the app loads Mapbox through here, so the telemetry opt-out is
// written once.
//
// Mapbox reports usage to events.mapbox.com on every map load and frame
// batch. Ad blockers block that host, so the browser console filled with
// ERR_BLOCKED_BY_CLIENT errors, and the requests do nothing for the app
// either way. postEvent() short-circuits when EVENTS_URL is falsy, so no
// request is made; API_URL is untouched, so tiles and styles still load. Same
// opt-out as accommo-web's MapView.
try {
  Object.defineProperty(mapboxgl.config, 'EVENTS_URL', { get: () => null, configurable: true })
} catch {
  // Best-effort: a mapbox-gl build without EVENTS_URL has nothing to disable.
}

export default mapboxgl
