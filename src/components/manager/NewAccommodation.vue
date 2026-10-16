<template>
  <q-page class="wiz" :class="{ 'page-wide wiz--desk': isDesktop }">
    <!-- Desktop: the way back sits above the card, the steps are the left half
         and the current step's form the right. Elsewhere the .desk-pass
         wrappers are display: contents and the phone wizard is unchanged. -->
    <div v-if="isDesktop" class="desk-back-row">
      <button type="button" class="desk-panel-back" aria-label="Back to properties" @click="router.push('/manager/properties')">
        <IconifyIcon icon="lucide:arrow-left" width="20" />
      </button>
      <span class="desk-panel-title">New accommodation</span>
    </div>

    <div v-else class="steps">
      <span v-for="n in STEP_LABELS.length" :key="n" class="step-dot" :class="{ 'step-dot--on': n <= step }" />
    </div>

    <div :class="isDesktop ? 'desk-card' : 'desk-pass'">
    <nav v-if="isDesktop" class="desk-col wiz-steps" aria-label="Steps">
      <button
        v-for="(label, i) in STEP_LABELS"
        :key="label"
        type="button"
        class="wiz-step"
        :class="{ 'wiz-step--on': i + 1 === step, 'wiz-step--done': i + 1 < step }"
        :disabled="i + 1 >= step"
        :aria-current="i + 1 === step ? 'step' : undefined"
        @click="step = i + 1"
      >
        <span class="wiz-step-num">
          <IconifyIcon v-if="i + 1 < step" icon="lucide:check" width="14" />
          <template v-else>{{ i + 1 }}</template>
        </span>
        {{ label }}
      </button>
    </nav>

    <div :class="isDesktop ? 'desk-col wiz-form' : 'desk-pass'">
    <div class="stack">
      <DetailsSteps />
      <PhotoPermitSteps />
      <ReviewStep />
    </div>

    <!-- The footer group. Pinned to the window on a phone (each piece is
         position: fixed); on desktop it is pinned to the foot of the form half
         instead, as one sticky block. -->
    <div :class="isDesktop ? 'wiz-foot' : 'desk-pass'">
    <!-- Camera / upload sit just above the footer, the way the room photo
         sheet does it, so they stay reachable however far the list scrolls. -->
    <div v-if="step === 4" class="photo-actions photo-actions--pinned">
      <button type="button" class="photo-action-btn" @click="takeExteriorPhoto">
        <IconifyIcon icon="lucide:camera" width="15" />
        Take photo
      </button>
      <label class="photo-action-btn">
        <IconifyIcon icon="lucide:image-plus" width="15" />
        Upload
        <input type="file" accept="image/*" multiple class="file-input-hidden" @change="onPhotosSelected" />
      </label>
    </div>

    <p v-if="blockReason" class="block-hint" :class="{ 'block-hint--above-actions': step === 4 }">
      <IconifyIcon icon="lucide:info" width="13" />
      {{ blockReason }}
    </p>

    <div class="nav">
      <!-- Nothing here has to be finished in one sitting: a draft is private,
           and rooms, photos and permits can be added to it before OSAS sees it. -->
      <button
        v-if="form.name.trim()"
        type="button"
        class="nav-btn nav-btn--ghost"
        :disabled="submitting"
        @click="submit(true)"
      >
        Save draft
      </button>
      <button v-if="step > 1" type="button" class="nav-btn nav-btn--ghost" @click="step--">Back</button>
      <button
        v-if="step < STEP_LABELS.length"
        type="button"
        class="nav-btn"
        :disabled="nextBlocked"
        @click="step++"
      >
        Next
      </button>
      <button v-else type="button" class="nav-btn" :disabled="submitting" @click="submit()">
        {{ submitting ? 'Submitting…' : 'Submit to OSAS' }}
      </button>
    </div>
    </div>
    </div>
    </div>

    <LocationPicker
      v-if="locationPickerOpen"
      v-model="locationPickerOpen"
      :initial-lat="form.lat"
      :initial-lng="form.lng"
      @confirm="onLocationConfirmed"
    />
  </q-page>
</template>

<script setup lang="ts">
import DetailsSteps from './newAccommodation/DetailsSteps.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import PhotoPermitSteps from './newAccommodation/PhotoPermitSteps.vue'
import ReviewStep from './newAccommodation/ReviewStep.vue'
import { defineAsyncComponent } from 'vue'
import { isDesktop } from '@/utils/useTabletMode'
import { provideNewAccommodation } from './newAccommodation/newAccommodation'

// The page is the frame — the step dots (or desktop's step list), the footer
// and its buttons. The steps live in ./newAccommodation/.
const {
  router,
  step,
  STEP_LABELS,
  submitting,
  blockReason,
  nextBlocked,
  form,
  locationPickerOpen,
  onLocationConfirmed,
  onPhotosSelected,
  takeExteriorPhoto,
  submit,
} = provideNewAccommodation()

// Loaded on demand — mapbox-gl (pulled in only by this component) is by far
// the heaviest dependency in the app, and the picker is opened rarely.
const LocationPicker = defineAsyncComponent(() => import('@/components/manager/LocationPicker.vue'))
</script>

<style scoped>
.wiz {
  background: var(--m-bg);
  /* Height of the fixed footer (10 + 46 button + 10 + its border), kept in
     one place so the pinned action bar and the scroll padding can't drift
     out of step with it. */
  --wiz-nav-h: calc(67px + env(safe-area-inset-bottom));
}
.steps {
  display: flex;
  justify-content: center;
  gap: 6px;
  padding: 10px 0 4px;
}
.step-dot {
  width: 8px;
  height: 8px;
  border-radius: 999px;
  background: var(--m-border);
}
.step-dot--on {
  background: var(--m-primary);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 6px var(--m-page-gutter) 100px;
}
/* Camera / upload pair — same shape as the room photo actions. */
.photo-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
/* Says what's still missing, since a disabled Next on its own gives no clue. */
.block-hint {
  position: fixed;
  right: 0;
  bottom: var(--wiz-nav-h);
  left: 0;
  z-index: 5;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin: 0;
  padding: 7px var(--m-page-gutter);
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
  text-align: center;
}
/* On the photos step the camera/upload bar already sits there, so stack above it. */
.block-hint--above-actions {
  bottom: calc(var(--wiz-nav-h) + 59px);
}
.photo-actions--pinned {
  position: fixed;
  right: 0;
  bottom: var(--wiz-nav-h);
  left: 0;
  z-index: 5;
  padding: 10px var(--m-page-gutter);
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.photo-action-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  min-height: 38px;
  padding: 0 14px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.file-input-hidden {
  display: none;
}
.nav {
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 5;
  display: flex;
  gap: 8px;
  padding: 10px var(--m-page-gutter) calc(10px + env(safe-area-inset-bottom));
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.nav-btn {
  flex: 1;
  min-height: 46px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.nav-btn:disabled {
  opacity: 0.5;
}
.nav-btn--ghost {
  flex: 0 0 auto;
  padding: 0 20px;
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
}
/* ---- Desktop: the card (.desk-card / .desk-col, app.scss) ----
   Steps on the left, the current step on the right, the footer pinned to the
   foot of the form half rather than to the window. */
.desk-pass {
  display: contents;
}
.wiz--desk {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 8px var(--m-page-gutter) 0;
}
.wiz--desk .stack {
  padding: 0;
}
.wiz-steps {
  gap: 4px;
}
.wiz-step {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 44px;
  padding: 0 10px;
  border: 0;
  border-radius: var(--m-radius-sm, 8px);
  background: transparent;
  color: var(--m-muted);
  font: inherit;
  font-size: 13.5px;
  font-weight: 600;
  text-align: left;
}
.wiz-step--done {
  color: var(--m-ink);
  cursor: pointer;
}
.wiz-step--done:hover {
  background: var(--m-bg);
}
.wiz-step--on {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-weight: 700;
}
.wiz-step:disabled {
  cursor: default;
}
.wiz-step-num {
  display: grid;
  width: 26px;
  height: 26px;
  flex: 0 0 auto;
  place-items: center;
  border: 1.5px solid currentColor;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 800;
}
.wiz-step--done .wiz-step-num {
  border-color: var(--m-success);
  background: var(--m-success);
  color: #fff;
}
/* margin-top: auto keeps the footer at the bottom of a short step too. */
.wiz-foot {
  position: sticky;
  bottom: 0;
  z-index: 5;
  margin: auto -18px -18px;
  background: var(--m-surface);
}
.wiz-foot .nav,
.wiz-foot .photo-actions--pinned,
.wiz-foot .block-hint {
  position: static;
}
.wiz-foot .nav {
  padding-bottom: 10px;
}
</style>
