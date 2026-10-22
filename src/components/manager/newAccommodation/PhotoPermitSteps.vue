<template>
  <section v-if="step === 4" class="sec sec--pinned-actions">
    <h2 class="sec-title">Exterior photos <span class="req">*</span></h2>
    <p class="sec-hint">Students see these first. At least one is required — you can add more later.</p>


    <div v-if="photos.length" class="thumbs">
      <div v-for="(p, i) in photos" :key="p.id" class="thumb">
        <img :src="p.url" alt="" />
        <q-spinner v-if="p.pending" class="thumb-wait" size="20px" />
        <button v-else type="button" class="thumb-x" @click="photos.splice(i, 1)">
          <IconifyIcon icon="lucide:x" width="12" />
        </button>
      </div>
    </div>
    <span v-if="uploadingPhotos" class="sec-hint">Uploading…</span>
    <p v-else-if="photos.length" class="sec-hint">{{ photos.length }} photo{{ photos.length === 1 ? '' : 's' }} added.</p>
  </section>

  <section v-else-if="step === 5" class="sec">
    <h2 class="sec-title">Permits <span class="req">*</span></h2>
    <p class="sec-hint">
      OSAS reviews these before your listing goes live. All four are required to submit.
    </p>

    <div class="permit-progress">
      <span class="permit-progress-bar"><span :style="{ width: `${(attachedPermits / DOC_TYPES.length) * 100}%` }" /></span>
      <span class="permit-progress-text">{{ attachedPermits }} of {{ DOC_TYPES.length }} attached</span>
    </div>

    <div class="permits">
      <div v-for="d in DOC_TYPES" :key="d.key" class="permit-row" :class="{ 'permit-row--done': permits[d.key] }">
        <span class="permit-icon">
          <IconifyIcon :icon="permits[d.key] ? 'lucide:check' : 'lucide:paperclip'" width="15" />
        </span>
        <span class="permit-body">
          <span class="permit-label">{{ d.label }}</span>
          <span class="permit-status" :class="{ 'permit-status--muted': !permits[d.key] }">
            {{ permits[d.key] ? (permitExpiry[d.key] ? 'Attached' : 'Attached · add its expiry date') : 'Required' }}
          </span>
          <!-- The date printed on the permit. OSAS checks it against the
               file, and the nightly sweep hides the listing when it passes. -->
          <label v-if="permits[d.key]" class="permit-date">
            <span>Expires</span>
            <DateTimeField :model-value="permitExpiry[d.key] ?? ''" mode="date" @update:model-value="permitExpiry[d.key] = $event" :min="today" placeholder="Pick the date" class="permit-date-input" />
          </label>
        </span>
        <IconifyIcon v-if="uploadingPermit === d.key" icon="lucide:loader" width="15" class="permit-spin" />
        <template v-else>
          <button
            type="button"
            class="permit-act"
            :aria-label="`Take a photo of your ${d.label}`"
            @click="takePermitPhoto(d.key)"
          >
            <IconifyIcon icon="lucide:camera" width="15" />
          </button>
          <label class="permit-act" :aria-label="`Upload your ${d.label}`">
            <IconifyIcon icon="lucide:upload" width="15" />
            <input type="file" accept="image/*,application/pdf" class="file-input-hidden" @change="onPermitSelected($event, d.key)" />
          </label>
        </template>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
// Steps 4–5: exterior photos and the four permits.
import { DOC_TYPES } from './model'
import DateTimeField from '@/components/shared/DateTimeField.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useNewAccommodation } from './newAccommodation'

const {
  step,
  uploadingPhotos,
  photos,
  permits,
  permitExpiry,
  today,
  uploadingPermit,
  attachedPermits,
  takePermitPhoto,
  onPermitSelected,
} = useNewAccommodation()
</script>

<style scoped>
.sec {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.sec-title {
  margin: 4px 0 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.sec-title:first-child {
  margin-top: 0;
}
.sec-hint {
  margin: -4px 0 0;
  padding: 0 2px;
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.5;
}
.thumbs {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.thumb {
  position: relative;
  width: 72px;
  height: 72px;
  overflow: hidden;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
}
.thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.thumb-wait {
  position: absolute;
  inset: 0;
  margin: auto;
  color: #fff;
  filter: drop-shadow(0 0 2px rgba(0, 0, 0, 0.6));
}
.thumb-x {
  position: absolute;
  top: 3px;
  right: 3px;
  display: grid;
  width: 18px;
  height: 18px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: rgba(23, 32, 42, 0.7);
  color: #fff;
  cursor: pointer;
}
.permits {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.permit-row {
  position: relative;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  border-top: 1px solid var(--m-border);
  cursor: pointer;
}
.permits > .permit-row:first-child {
  border-top: 0;
}
.permit-icon {
  display: grid;
  width: 28px;
  height: 28px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: 999px;
  background: var(--m-border);
  color: var(--m-muted);
}
.permit-row--done .permit-icon {
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.permit-body {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 1px;
}
.permit-label {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
}
.permit-status {
  color: var(--m-success);
  font-size: 11.5px;
  font-weight: 700;
}
.permit-status--muted {
  color: var(--m-muted);
  font-weight: 600;
}
.permit-date {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 4px;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
}
.permit-date-input {
  width: auto;
  min-height: 34px;
  padding: 0 8px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 13px;
}
.permit-spin {
  flex: 0 0 auto;
  color: var(--m-muted);
  animation: permit-spin 0.9s linear infinite;
}
/* Attach progress — the step can't be passed until this fills. */
.permit-progress {
  display: flex;
  align-items: center;
  gap: 8px;
}
.permit-progress-bar {
  position: relative;
  display: block;
  height: 6px;
  flex: 1 1 auto;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-border);
}
.permit-progress-bar > span {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: var(--m-primary);
  transition: width 200ms ease;
}
.permit-progress-text {
  flex: 0 0 auto;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
}
.req {
  color: var(--m-negative, #c62828);
  font-weight: 800;
}
/* Clears the pinned action bar so the last thumbnail isn't hidden behind it. */
.sec--pinned-actions {
  padding-bottom: 58px;
}
.file-input-hidden {
  display: none;
}
/* Compact per-permit versions of the same two actions. */
.permit-act {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 auto;
  place-items: center;
  padding: 0;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.permit-status--muted {
  color: var(--m-muted);
  font-weight: 600;
}
.wiz--desk .sec--pinned-actions {
  padding-bottom: 0;
}
@keyframes permit-spin {
  to { transform: rotate(360deg); }
}
</style>
