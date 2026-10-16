<template>
  <section class="preview">
    <span class="preview-cap">What your boarders will see</span>
    <div class="pv-banner">
      <IconifyIcon icon="lucide:megaphone" width="14" />
      <span class="pv-banner-text">{{ form.summary.trim() || form.title.trim() || 'Your announcement' }}</span>
    </div>
    <article class="pv-card">
      <img v-if="form.imageUrl" :src="resolveAsset(form.imageUrl, CARD)" alt="" class="pv-poster" />
      <h4 class="pv-title">{{ form.title.trim() || 'Untitled notice' }}</h4>
      <p v-if="factLine" class="pv-facts">{{ factLine }}</p>
      <p class="pv-body">{{ form.body.trim() || 'The body of your notice appears here.' }}</p>
      <p v-if="form.deadlineAt" class="pv-deadline">Respond by {{ readable(form.deadlineAt) }}</p>
    </article>
  </section>
</template>

<script setup lang="ts">
// 4. PREVIEW — the notice as a tenant meets it, so the banner line is written
// for the banner rather than guessed at.
import { CARD, resolveAsset } from '@/utils/cloudinaryUrl'
import { Icon as IconifyIcon } from '@iconify/vue'
import { useAnnouncementCompose } from './announcementCompose'

const {
  form,
  readable,
  factLine,
} = useAnnouncementCompose()
</script>

<style scoped>
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
.preview {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 12px;
  border: 1px dashed var(--m-border);
  border-radius: var(--m-radius);
  background: transparent;
}
.preview-cap {
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.pv-banner {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.pv-banner-text {
  overflow: hidden;
  font-size: 12.5px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pv-card {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
}
.pv-poster {
  display: block;
  width: 100%;
  max-height: 140px;
  border-radius: var(--m-radius-sm);
  object-fit: cover;
}
.pv-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 14px;
  font-weight: 700;
}
.pv-facts {
  margin: 0;
  color: var(--m-primary-dark);
  font-size: 12px;
  font-weight: 600;
}
.pv-body {
  margin: 0;
  color: var(--m-text);
  font-size: 12.5px;
  line-height: 1.45;
  white-space: pre-wrap;
}
.pv-deadline {
  margin: 0;
  color: var(--m-danger);
  font-size: 12px;
  font-weight: 600;
}
</style>
