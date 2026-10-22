<template>
  <section class="card">
    <div class="row row--wrap">
      <span class="row-label">To</span>
      <span class="m-chips">
        <button
          v-for="a in props.accommodations"
          :key="a.id"
          type="button"
          class="m-chip"
          :class="{ 'm-chip--on': form.accommodationIds.includes(a.id) }"
          @click="toggleHouse(a.id)"
        >
          <IconifyIcon v-if="form.accommodationIds.includes(a.id)" icon="lucide:check" width="13" />
          {{ a.name }}
        </button>
      </span>
    </div>
    <p class="reach">{{ reachText }}</p>

    <label class="field">
      <span class="field-head">
        <span class="row-label">Title</span>
        <span class="count" :class="{ 'count--near': form.title.length > 100 }">{{ form.title.length }}/120</span>
      </span>
      <input v-model="form.title" type="text" class="row-input" maxlength="120" placeholder="Water interruption Tuesday" />
    </label>

    <label class="field">
      <span class="field-head">
        <span class="row-label">Banner line</span>
        <span class="count" :class="{ 'count--near': form.summary.length > 120 }">{{ form.summary.length }}/140</span>
      </span>
      <input v-model="form.summary" type="text" class="row-input" maxlength="140" placeholder="Optional — the one line boarders see first" />
    </label>

    <textarea v-model="form.body" class="body" placeholder="The full notice: what is happening, when, and what your boarders need to do." />

    <!-- A photo of the posted advisory or schedule says more than the body
         usually can, and the reader already renders it as a poster. -->
    <div v-if="imagePreview || form.imageUrl" class="photo">
      <img :src="imagePreview || resolveAsset(form.imageUrl, CARD)" alt="" class="photo-img" />
      <q-spinner v-if="imagePreview" class="photo-wait" size="28px" />
      <button v-else type="button" class="photo-drop" aria-label="Remove photo" @click="form.imageUrl = ''">
        <IconifyIcon icon="lucide:trash-2" width="15" />
      </button>
    </div>
    <div v-else class="photo-add">
      <button type="button" class="ghost-btn" :disabled="uploading" @click="fromCamera">
        <IconifyIcon icon="lucide:camera" width="15" />
        {{ uploading ? 'Uploading…' : 'Take photo' }}
      </button>
      <button type="button" class="ghost-btn" :disabled="uploading" @click="pickFile">
        <IconifyIcon icon="lucide:image-plus" width="15" />
        Upload
      </button>
      <input ref="fileInput" type="file" accept="image/*" class="hidden-input" @change="onFilePicked" />
    </div>
  </section>
</template>

<script setup lang="ts">
// 1. Write: the houses it goes to, the title, the message and a photo.
import { CARD, resolveAsset } from '@/utils/cloudinaryUrl'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useAnnouncementCompose } from './announcementCompose'

const {
  props,
  form,
  uploading,
  imagePreview,
  fileInput,
  toggleHouse,
  reachText,
  fromCamera,
  pickFile,
  onFilePicked,
} = useAnnouncementCompose()
</script>

<style scoped>
.card {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.row {
  display: flex;
  align-items: center;
  gap: 10px;
}
.row--wrap {
  align-items: flex-start;
}
.row-label {
  flex: 0 0 84px;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
}
.row-input {
  min-width: 0;
  flex: 1 1 auto;
  padding: 8px 10px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-text);
  font: inherit;
  font-size: 13.5px;
}
/* A label with its own counter sits above its input rather than beside it —
   the counter has nowhere to go on a 320px row. */
.field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.field-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
}
.count {
  color: var(--m-muted);
  font-size: 11px;
  font-variant-numeric: tabular-nums;
}
.count--near {
  color: var(--m-danger);
}
.reach {
  margin: 0;
  color: var(--m-muted);
  font-size: 12px;
}
.body {
  min-height: 140px;
  padding: 10px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-text);
  font: inherit;
  font-size: 13.5px;
  line-height: 1.45;
  resize: none;
}
.photo {
  position: relative;
}
.photo-img {
  display: block;
  width: 100%;
  max-height: 180px;
  border-radius: var(--m-radius-sm);
  object-fit: cover;
}
.photo-wait {
  position: absolute;
  inset: 0;
  margin: auto;
  color: #fff;
  filter: drop-shadow(0 0 2px rgba(0, 0, 0, 0.6));
}
.photo-drop {
  position: absolute;
  top: 8px;
  right: 8px;
  display: grid;
  width: 30px;
  height: 30px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.62);
  color: #fff;
  cursor: pointer;
}
.photo-add {
  display: flex;
  gap: 8px;
}
.hidden-input {
  display: none;
}
.ghost-btn,
.danger-btn {
  display: inline-flex;
  min-height: 36px;
  align-items: center;
  gap: 6px;
  padding: 0 14px;
  border-radius: 999px;
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.ghost-btn {
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
}
.ghost-btn:disabled {
  opacity: 0.6;
}
.m-chips {
  flex: 1 1 auto;
}
</style>
