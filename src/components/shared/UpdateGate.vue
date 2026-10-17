<template>
  <!-- A screen, not a dialog. There is no backdrop to tap, no Escape, no Later
       and no close button, because there is no longer any such thing as running
       this app on an old build. The shape is the login page's — hero photo
       above, sheet below — because it is a stop, and it should look like the
       app's other stop. -->
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
        Update to
        <strong v-if="release?.latest_version_name">version {{ release.latest_version_name }}</strong>
        <strong v-else>the latest version</strong>
        to carry on.
        {{ mode === 'bundle'
          ? 'It’s a small download, and accommo restarts on its own when it’s done.'
          : 'This one replaces the app itself; Android will ask you to confirm the install.' }}
      </p>

      <p v-if="release?.release_notes" class="wall-notes">{{ release.release_notes }}</p>

      <!-- Downloading: how far along, in place of the button. -->
      <div v-if="phase === 'downloading'" class="wall-progress" role="progressbar" :aria-valuenow="percent" aria-valuemin="0" aria-valuemax="100">
        <div class="wall-bar"><span :style="{ width: `${percent}%` }" /></div>
        <p class="wall-foot">Downloading… {{ percent }}%</p>
      </div>

      <template v-else>
        <p v-if="phase === 'error'" class="wall-error">{{ errorText }}</p>
        <p v-else-if="phase === 'permission'" class="wall-step">
          Switch on <strong>Allow from this source</strong> for accommo, then come back and tap Install.
        </p>
        <p v-else-if="phase === 'installer'" class="wall-step">
          Finish in Android’s installer, then open accommo again. Closed it by mistake? Tap Install.
        </p>

        <q-btn
          unelevated
          rounded
          no-caps
          color="primary"
          :label="buttonLabel"
          class="wall-btn"
          @click="primary"
        />
        <q-btn
          v-if="mode === 'bundle' && phase === 'error' && release && hasApk(release)"
          flat
          rounded
          no-caps
          color="primary"
          label="Download the full app instead"
          class="wall-alt"
          @click="switchToApk"
        />
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, onMounted } from 'vue'
import { Capacitor } from '@capacitor/core'
import { App } from '@capacitor/app'
import { CapacitorUpdater } from '@capgo/capacitor-updater'
import {
  BrokenBundleError,
  canInstallInApp,
  downloadApk,
  hasApk,
  installApk,
  installBundle,
  removeDownloadedApk,
  runningVersion,
  updateAction,
  type Release,
} from '@/utils/liveUpdate'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { openExternal } from '@/utils/openExternal'
import { EXTERNAL_URLS } from '@/utils/config'

// The APK is sideloaded from GitHub Releases, so nothing pushes updates to an
// install the way a store would. On launch (and on resume, since a phone may
// keep the app alive for weeks) this asks the single `app_release` row what the
// current build is and compares it against our own Android versionCode.
//
// Every release is required: an install that is behind gets this screen and
// nothing else until it updates, inside the app (src/utils/liveUpdate.ts). A
// web-only release downloads its small bundle and restarts into it; a native
// one downloads the APK and hands it to Android's installer. Every failure is
// shown with a way to try again — the quiet background update this replaced
// failed silently, so nobody could tell why updates never arrived.
//
// The check itself still fails open. A network error, a missing row, an
// unreadable version, a release with no APK to point at: render nothing. A
// broken check must never be able to lock the app, and with no Later button
// left there is nothing a locked-out user could do about it.

// Same demo-mode check as src/utils/supabase.ts — demo builds have no backend
// to ask and no APK to update to.
const isDemoMode = (import.meta.env.VITE_DEMO_MODE as unknown) === 'true'

// `quasar dev -m capacitor` (live-reload) and any locally-run `quasar build`
// fall back to versionCode 1 (see README) — never a real CI run number — so
// they always read as infinitely behind the real app_release row and get
// walled off with no way out. import.meta.env.DEV is Vite's own flag, true
// only for the dev server, never a real build: a local *build* still gets
// gated, same as today, since it can genuinely ship stale code.
const isDevBuild = import.meta.env.DEV

const open = ref(false)
const release = ref<Release | null>(null)
const mode = ref<'bundle' | 'apk'>('bundle')
/**
 * ready: nothing started. downloading: progress shown. permission: sent to the
 * "Install unknown apps" switch. installer: handed to Android's installer.
 */
const phase = ref<'ready' | 'downloading' | 'permission' | 'installer' | 'error'>('ready')
const percent = ref(0)
const errorText = ref('')
/** The APK is on the device; Install hands it over again without re-downloading. */
const apkReady = ref(false)

const buttonLabel = computed(() => {
  if (phase.value === 'error') return 'Try again'
  if (mode.value === 'apk' && apkReady.value) return 'Install'
  return 'Update now'
})

async function check() {
  if (!Capacitor.isNativePlatform() || isDemoMode || isDevBuild) return
  if (open.value) return // already walled off; nothing to re-evaluate

  try {
    // `build` is the Android versionCode, which CI sets to the workflow run
    // number — an integer that only ever increases, so no version parsing.
    const current = Number((await App.getInfo()).build)
    if (!Number.isFinite(current)) return

    const { data, error } = await supabase
      .from('app_release')
      .select('latest_version_code, latest_version_name, min_supported_version_code, apk_url, release_notes, bundle_version, bundle_url, bundle_checksum')
      .eq('id', 1)
      .maybeSingle()
    if (error || !data) return

    const { bundle } = await CapacitorUpdater.current()
    // updateAction also holds the one guard that has to stay: it never walls
    // the app off while pointing at nothing downloadable, which would brick
    // every install until someone fixed a database row.
    const action = updateAction(data, current, runningVersion(current, bundle))
    release.value = data
    if (action === 'none') {
      // Up to date — an APK update that just installed leaves its file behind.
      void removeDownloadedApk()
      return
    }
    mode.value = action
    open.value = true
  } catch {
    // Fail open, deliberately silent.
  }
}

async function primary() {
  if (!release.value) return
  errorText.value = ''
  if (mode.value === 'bundle') await updateBundle(release.value)
  else await updateApk(release.value)
}

async function updateBundle(r: Release) {
  phase.value = 'downloading'
  percent.value = 0
  try {
    // Reloads the app into the new version on success.
    await installBundle(r, (p) => (percent.value = p))
  } catch (e) {
    if (e instanceof BrokenBundleError && hasApk(r)) {
      // It was tried and rolled back: the same files would fail the same way.
      mode.value = 'apk'
      phase.value = 'error'
      errorText.value = 'The quick update didn’t start on your phone, so get the full app instead.'
      return
    }
    phase.value = 'error'
    errorText.value = errorMessage(e, 'The update didn’t download. Check your connection and try again.')
  }
}

async function updateApk(r: Release) {
  // An APK from before the in-app installer can only use the browser. Its own
  // bundle never has this code, so this is only a guard.
  if (!canInstallInApp()) {
    openExternal(r.apk_url)
    return
  }
  try {
    if (!apkReady.value) {
      phase.value = 'downloading'
      percent.value = 0
      await downloadApk(r, (p) => (percent.value = p))
      apkReady.value = true
    }
    phase.value = (await installApk()) === 'settings' ? 'permission' : 'installer'
  } catch (e) {
    phase.value = 'error'
    errorText.value = errorMessage(e, 'The update didn’t download. Check your connection and try again.')
  }
}

function switchToApk() {
  mode.value = 'apk'
  phase.value = 'ready'
  errorText.value = ''
  void primary()
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
/* Above ConfirmGate (8000): there is no point confirming an action in an app
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

/* Copied from AuthLayout's hero in its login state. The two are meant to be
   the same picture. */
.wall-hero {
  position: fixed;
  top: -80px;
  left: 0;
  z-index: 1;
  width: 100%;
  height: 400px;
  /* Brand ground under the photo: a screen with no way out is the worst place
     for a blank frame. */
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
.wall-alt {
  width: 100%;
  margin-top: 6px;
  font-weight: 700;
}
.wall-foot {
  margin: 12px 0 0;
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.5;
  text-align: center;
}
/* Where the button was, so the eye stays in one place while it downloads. */
.wall-progress {
  margin-top: 22px;
}
.wall-bar {
  height: 10px;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-primary-soft);
}
.wall-bar span {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: var(--m-primary);
  transition: width 0.2s ease;
}
.wall-step,
.wall-error {
  margin: 18px 0 0;
  padding: 12px 14px;
  border-radius: var(--m-radius-sm);
  font-size: 13px;
  line-height: 1.5;
}
.wall-step {
  background: var(--m-primary-soft);
  color: var(--m-text);
}
.wall-error {
  background: var(--m-danger-soft);
  color: var(--m-danger);
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
