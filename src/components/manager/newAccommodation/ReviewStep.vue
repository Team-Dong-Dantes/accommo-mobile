<template>
  <section v-if="step > 5" class="sec">
    <h2 class="sec-title">Review</h2>

    <!-- Leads with what the student will actually see, so mistakes in the
         photo or the name are obvious before this goes to OSAS. -->
    <div class="rv-card">
      <span class="rv-shot">
        <img v-if="photos.length" :src="photos[0]!.url" alt="" />
        <PhotoEmpty v-else :size="20" />
      </span>
      <span class="rv-head">
        <strong class="rv-name">{{ form.name }}</strong>
        <span class="rv-type">
          {{ BUILDING_TYPE_LABEL[form.accommodationType] }} · {{ GENDER_POLICY_LABEL[form.genderPolicy] }}
        </span>
        <span class="rv-where">
          <IconifyIcon icon="lucide:map-pin" width="11" />
          {{ locationSummary }}
        </span>
      </span>
    </div>

    <button type="button" class="rv-block rv-block--tap" @click="step = 2">
      <span class="rv-block-head">
        <IconifyIcon icon="lucide:sparkles" width="14" />
        Amenities
        <span class="rv-count">{{ form.amenities.length }}</span>
        <IconifyIcon icon="lucide:pencil" width="13" class="rv-edit" />
      </span>
      <span class="rv-chips">
        <span v-for="key in form.amenities" :key="key" class="rv-chip">
          {{ AMENITY_META[key]?.label || key }}
        </span>
      </span>
    </button>

    <button type="button" class="rv-block rv-block--tap" @click="step = 3">
      <span class="rv-block-head">
        <IconifyIcon icon="lucide:scroll-text" width="14" />
        House rules
        <IconifyIcon icon="lucide:pencil" width="13" class="rv-edit" />
      </span>
      <span class="rv-line"><span>Curfew</span><strong>{{ to12Hour(form.curfewTime) }}</strong></span>
      <span class="rv-line"><span>Quiet hours</span><strong>{{ quietHoursLabel }}</strong></span>
      <span class="rv-line"><span>Visitors</span><strong>{{ form.visitorPolicy }}</strong></span>
      <span class="rv-chips">
        <span v-for="t in RULE_TOGGLES" :key="t.key" class="rv-chip" :class="{ 'rv-chip--off': !form[t.key] }">
          {{ form[t.key] ? '' : 'No ' }}{{ t.label.replace(' allowed', '') }}
        </span>
      </span>
    </button>

    <button type="button" class="rv-block rv-block--tap" @click="step = 4">
      <span class="rv-block-head">
        <IconifyIcon icon="lucide:images" width="14" />
        Photos
        <span class="rv-count">{{ photos.length }}</span>
        <IconifyIcon icon="lucide:pencil" width="13" class="rv-edit" />
      </span>
      <span class="rv-strip">
        <img v-for="p in photos.slice(0, 6)" :key="p.url" :src="p.url" alt="" class="rv-thumb" />
        <span v-if="photos.length > 6" class="rv-more">+{{ photos.length - 6 }}</span>
      </span>
    </button>

    <button type="button" class="rv-block rv-block--tap" @click="step = 5">
      <span class="rv-block-head">
        <IconifyIcon icon="lucide:shield-check" width="14" />
        Permits
        <span class="rv-count">{{ attachedPermits }}/{{ DOC_TYPES.length }}</span>
        <IconifyIcon icon="lucide:pencil" width="13" class="rv-edit" />
      </span>
      <span v-for="d in DOC_TYPES" :key="d.key" class="rv-line rv-line--check">
        <IconifyIcon icon="lucide:check" width="13" class="rv-check" />
        <span>{{ d.label }}</span>
      </span>
    </button>

    <p class="sec-hint">
      Your listing starts as pending — OSAS reviews it before students can see or apply to it.
    </p>
  </section>
</template>

<script setup lang="ts">
// The last step: everything as the student and OSAS will see it.
import { AMENITY_META, BUILDING_TYPE_LABEL, GENDER_POLICY_LABEL } from '@/utils/listings'
import { DOC_TYPES, RULE_TOGGLES } from './model'
import { Icon as IconifyIcon } from '@iconify/vue'
import PhotoEmpty from '@/components/shared/PhotoEmpty.vue'
import { to12Hour } from '@/utils/format'
import { useNewAccommodation } from './newAccommodation'

const {
  step,
  photos,
  attachedPermits,
  form,
  quietHoursLabel,
  locationSummary,
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
/* Review — a summary of what's actually being submitted, each block tapping
   back to the step that owns it. */
.rv-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.rv-shot {
  position: relative;
  display: grid;
  width: 64px;
  height: 64px;
  flex: 0 0 auto;
  place-items: center;
  overflow: hidden;
  border-radius: var(--m-radius-sm, 10px);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.rv-shot img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.rv-head {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
}
.rv-name {
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.rv-type {
  color: var(--m-primary-dark);
  font-size: 11.5px;
  font-weight: 700;
}
.rv-where {
  display: flex;
  align-items: center;
  gap: 4px;
  color: var(--m-muted);
  font-size: 11.5px;
}
.rv-block {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 6px;
  padding: 11px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  font: inherit;
  text-align: left;
}
.rv-block--tap {
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.rv-block-head {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--m-ink);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.rv-count {
  padding: 1px 7px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 10.5px;
  font-weight: 800;
}
.rv-edit {
  margin-left: auto;
  color: var(--m-muted);
}
.rv-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
}
.rv-chip {
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 11px;
  font-weight: 700;
}
.rv-chip--off {
  background: var(--m-border);
  color: var(--m-muted);
}
.rv-line {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  color: var(--m-muted);
  font-size: 12px;
}
.rv-line strong {
  color: var(--m-ink);
  font-weight: 700;
  text-align: right;
}
.rv-line--check {
  justify-content: flex-start;
  color: var(--m-ink);
}
.rv-check {
  flex: 0 0 auto;
  color: var(--m-success);
}
.rv-strip {
  display: flex;
  align-items: center;
  gap: 6px;
  overflow-x: auto;
}
.rv-thumb {
  width: 52px;
  height: 52px;
  flex: 0 0 auto;
  object-fit: cover;
  border-radius: var(--m-radius-sm, 8px);
}
.rv-more {
  display: grid;
  width: 52px;
  height: 52px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: var(--m-radius-sm, 8px);
  background: var(--m-border);
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 800;
}
</style>
