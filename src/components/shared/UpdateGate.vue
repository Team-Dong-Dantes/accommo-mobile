<template>
  <q-dialog v-model="open" :persistent="blocking">
    <q-card class="gate-card">
      <div class="gate-head">
        <span class="gate-title">{{ blocking ? 'Update required' : 'Update available' }}</span>
        <span class="gate-sub">
          {{ blocking
            ? 'This version of accommo is too old to keep working with our servers. Install the latest one to continue.'
            : `Version ${release?.latest_version_name ?? ''} is ready to install.` }}
        </span>
      </div>

      <p v-if="release?.release_notes" class="gate-notes">{{ release.release_notes }}</p>

      <div class="gate-actions">
        <button v-if="!blocking" type="button" class="gate-out" @click="dismiss">Later</button>
        <span v-else class="gate-note">You can't continue on this version</span>
        <q-btn
          unelevated
          rounded
          no-caps
          color="primary"
          label="Update"
          class="q-px-lg"
          @click="openDownload"
        />
      </div>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Capacitor } from '@capacitor/core'
import { App } from '@capacitor/app'
import { supabase } from '@/utils/supabase'
import { openExternal } from '@/utils/openExternal'

// The APK is sideloaded from GitHub Releases, so nothing pushes updates to an
// install the way a store would. On launch (and on resume, since a phone may
// keep the app alive for weeks) this asks the single `app_release` row what the
// current build is and compares it against our own Android versionCode.
//
// Two outcomes: a dismissible nudge when a newer build exists, and a blocking
// wall when this build is below `min_supported_version_code` — the lever for the
// day a migration breaks old clients, given mobile and web share one backend.
//
// Everything here fails open. A network error, a missing row, an unreadable
// version: render nothing. A broken check must never be able to lock the app.

// Same demo-mode check as src/utils/supabase.ts — demo builds have no backend
// to ask and no APK to update to.
const isDemoMode = (import.meta.env.VITE_DEMO_MODE as unknown) === 'true'

const DISMISS_PREFIX = 'accommo:update-dismissed:'

type Release = {
  latest_version_code: number
  latest_version_name: string
  min_supported_version_code: number
  apk_url: string
  release_notes: string | null
}

const open = ref(false)
const blocking = ref(false)
const release = ref<Release | null>(null)

async function check() {
  if (!Capacitor.isNativePlatform() || isDemoMode) return
  if (blocking.value) return // already walled off; nothing to re-evaluate

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

    release.value = data

    if (current < data.min_supported_version_code) {
      blocking.value = true
      open.value = true
      return
    }

    // Nudge once per release, not once per launch.
    if (current < data.latest_version_code && !localStorage.getItem(DISMISS_PREFIX + data.latest_version_code)) {
      blocking.value = false
      open.value = true
    }
  } catch {
    // Fail open, deliberately silent.
  }
}

function dismiss() {
  const code = release.value?.latest_version_code
  try {
    if (code != null) localStorage.setItem(DISMISS_PREFIX + code, '1')
  } catch {
    // Private-mode storage failure just means we ask again next launch.
  }
  open.value = false
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
  // as long as the app does.
  void App.addListener('resume', () => void check())
})
</script>

<style scoped>
.gate-card {
  display: flex;
  width: min(420px, 92vw);
  flex-direction: column;
  border-radius: 16px;
}
.gate-head { padding: 16px 16px 10px; }
.gate-title { display: block; color: var(--m-ink); font-size: 15.5px; font-weight: 700; }
.gate-sub { display: block; margin-top: 3px; color: var(--m-muted); font-size: 12px; line-height: 1.4; }
.gate-notes {
  margin: 0;
  padding: 0 16px 6px;
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.5;
  white-space: pre-line;
}
.gate-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 10px 14px 14px;
  border-top: 1px solid var(--m-border);
}
.gate-note { color: var(--m-muted); font-size: 11.5px; font-weight: 600; }
.gate-out {
  padding: 6px 4px;
  border: 0;
  background: none;
  color: var(--m-muted);
  font: inherit;
  font-size: 12.5px;
  font-weight: 600;
  cursor: pointer;
}
</style>
