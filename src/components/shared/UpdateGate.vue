<template>
  <!-- A screen, not a dialog. There is no backdrop to tap, no Escape, no Later
       and no close button, because there is no longer any such thing as running
       this app on an old build. The shape is PinGate's resume lock — hero photo
       above, sheet below — for the same reason that screen uses it: it is a
       stop, and it should look like the app's other stop. -->
  <div v-if="open" class="wall">
    <div class="wall-hero" :style="{ '--hero-bg': `url(${EXTERNAL_URLS.ISU_BACKGROUND})` }">
      <div class="wall-hero-overlay">
        <div class="wall-hero-content">
          <div class="wall-logo">accommo</div>
          <div class="wall-tagline">Verified boarding houses · ISU Echague</div>
        </div>
      </div>
    </div>

    <div class="wall-card">
      <span class="wall-icon"><IconifyIcon icon="lucide:download" width="20" /></span>

      <h1 class="wall-title">A new version is ready</h1>
      <p class="wall-sub">
        accommo has been updated. Download
        <strong v-if="release?.latest_version_name">version {{ release.latest_version_name }}</strong>
        <strong v-else>the latest version</strong>
        to carry on — this build can no longer be used.
      </p>

      <p v-if="release?.release_notes" class="wall-notes">{{ release.release_notes }}</p>

      <q-btn
        unelevated
        rounded
        no-caps
        color="primary"
        label="Download now"
        class="wall-btn"
        @click="openDownload"
      />

      <p class="wall-foot">
        The download opens in your browser. Install it, then reopen accommo.
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Capacitor } from '@capacitor/core'
import { App } from '@capacitor/app'
import { supabase } from '@/utils/supabase'
import { openExternal } from '@/utils/openExternal'
import { EXTERNAL_URLS } from '@/utils/config'

// The APK is sideloaded from GitHub Releases, so nothing pushes updates to an
// install the way a store would. On launch (and on resume, since a phone may
// keep the app alive for weeks) this asks the single `app_release` row what the
// current build is and compares it against our own Android versionCode.
//
// One outcome now, not two. This used to nudge for a new build and only wall the
// app off below `min_supported_version_code`; being behind at all is now the
// wall. That is a deliberate product decision and it has teeth — an old build is
// unusable from the moment a new row lands, so publishing a release reaches for
// every install at once. `min_supported_version_code` is left in the row and
// unread rather than dropped: it is a column the web app and the backend also
// know about, and this file is not the place to retire it.
//
// Everything here still fails open. A network error, a missing row, an
// unreadable version, a release with no APK to point at: render nothing. A
// broken check must never be able to lock the app, and with no Later button
// left there is nothing a locked-out user could do about it.

// Same demo-mode check as src/utils/supabase.ts — demo builds have no backend
// to ask and no APK to update to.
const isDemoMode = (import.meta.env.VITE_DEMO_MODE as unknown) === 'true'

type Release = {
  latest_version_code: number
  latest_version_name: string
  min_supported_version_code: number
  apk_url: string
  release_notes: string | null
}

const open = ref(false)
const release = ref<Release | null>(null)

async function check() {
  if (!Capacitor.isNativePlatform() || isDemoMode) return
  if (open.value) return // already walled off; nothing to re-evaluate

  try {
    // `build` is the Android versionCode, which CI sets to the workflow run
    // number — an integer that only ever increases, so no version parsing.
    const current = Number((await App.getInfo()).build)
    if (!Number.isFinite(current)) return

    const { data, error } = await supabase
      .from('app_release')
      .select('latest_version_code, latest_version_name, min_supported_version_code, apk_url, release_notes')
      .eq('id', 1)
      .maybeSingle()
    if (error || !data) return

    // The one guard that has to stay. With no way out of this screen, walling
    // the app off while pointing at nothing downloadable would brick every
    // install until someone fixed a database row.
    if (!data.apk_url?.trim()) return

    release.value = data
    if (current < data.latest_version_code) open.value = true
  } catch {
    // Fail open, deliberately silent.
  }
}

function openDownload() {
  // openExternal navigates rather than calling window.open, which Capacitor's
  // WebView silently drops — see src/utils/openExternal.ts. The system browser
  // downloads the APK and Android's installer takes it from there.
  openExternal(release.value?.apk_url ?? '')
}

onMounted(() => {
  void check()
  // Not removed on unmount: this component is mounted once in App.vue and lives
  // as long as the app does. Re-checking on resume is what catches someone who
  // left the app open across a release.
  void App.addListener('resume', () => void check())
})
</script>

<style scoped>
/* Above PinGate (8000): there is no point asking for a PIN to get into an app
   that cannot be used. Still below Notify (9500), so a failed-to-open-browser
   toast lands on top of this rather than behind it. */
.wall {
  position: fixed;
  inset: 0;
  z-index: 8500;
  padding: 150px 0 0;
  overflow-x: hidden;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
  overscroll-behavior-y: contain;
  background: var(--m-bg);
}

/* Copied from PinGate's `.lock-hero`, which copies AuthLayout's in its login
   state. The three are meant to be the same picture. */
.wall-hero {
  position: fixed;
  top: -80px;
  left: 0;
  z-index: 1;
  width: 100%;
  height: 400px;
  /* Brand ground under the photo: it is fetched from isu.edu.ph, and a screen
     with no way out is the worst place for a blank frame. */
  background-color: var(--m-primary-dark);
  background-image: var(--hero-bg);
  background-position: 46% center;
  background-size: cover;
  pointer-events: none;
}
.wall-hero-overlay {
  position: relative;
  height: 100%;
  background:
    linear-gradient(
      180deg,
      rgba(0, 44, 37, 0.74) 0%,
      rgba(0, 44, 37, 0.52) 34%,
      rgba(0, 44, 37, 0.34) 62%,
      rgba(0, 44, 37, 0.26) 100%
    ),
    linear-gradient(135deg, rgba(0, 150, 136, 0.52), rgba(0, 121, 107, 0.4));
}
.wall-hero-content {
  position: absolute;
  top: 120px;
  left: 0;
  width: 100%;
  padding: 0 24px;
  color: #fff;
}
.wall-logo {
  /* No display font: the wordmark is a div everywhere else, so it rides the
     body face. Setting one here would make this the odd screen out. */
  font-size: 38px;
  font-weight: 700;
  line-height: 1;
}
.wall-tagline {
  font-size: 14px;
  opacity: 0.95;
}

.wall-card {
  position: relative;
  z-index: 2;
  min-height: calc(100dvh - 150px);
  padding: 24px;
  border-radius: 28px 28px 0 0;
  background: var(--m-surface);
}
.wall-icon {
  display: grid;
  width: 44px;
  height: 44px;
  margin-bottom: 14px;
  place-items: center;
  border-radius: 14px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.wall-title {
  margin: 0;
  color: var(--m-ink);
  font-size: 26px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.15;
}
.wall-sub {
  margin: 10px 0 0;
  color: var(--m-muted);
  font-size: 14px;
  line-height: 1.5;
}
.wall-sub strong {
  color: var(--m-text);
  font-weight: 700;
}
.wall-notes {
  margin: 16px 0 0;
  padding: 12px 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-text);
  font-size: 12.5px;
  line-height: 1.55;
  white-space: pre-line;
}
.wall-btn {
  width: 100%;
  height: 50px;
  margin-top: 22px;
  font-size: 15px;
  font-weight: 700;
}
.wall-foot {
  margin: 12px 0 0;
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.5;
  text-align: center;
}

/* Tablet landscape: the sheet holds a readable measure instead of running the
   full width of the screen, the same as every other single-column screen does
   in that mode. */
@media (min-width: 900px) and (orientation: landscape) {
  .wall-card {
    max-width: 560px;
    margin-inline: auto;
    border-radius: 28px;
  }
}
</style>
