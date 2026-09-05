<template>
  <button v-if="variant === 'carousel'" type="button" class="car" @click="emit('open', id)">
    <span class="car-shot" :class="{ 'car-shot--empty': !image }">
      <img v-if="image" :src="image" :alt="name" loading="lazy" />
      <span v-else class="shot-empty">
        <IconifyIcon icon="lucide:image-off" width="24" />
        <span class="shot-empty-label">No photo</span>
      </span>
      <span class="car-flag" :class="vacancies ? 'car-flag--ok' : 'car-flag--none'">
        {{ vacancies ? `${vacancies} free` : 'Full' }}
      </span>
    </span>
    <span class="car-body">
      <span class="car-name">{{ name }}</span>
      <span class="car-where">{{ distance || address }}</span>
    </span>
  </button>

  <button v-else type="button" class="tile" @click="emit('open', id)">
    <span class="tile-shot" :class="{ 'tile-shot--empty': !image }">
      <img v-if="image" :src="image" :alt="name" loading="lazy" />
      <span v-else class="shot-empty">
        <IconifyIcon icon="lucide:image-off" width="22" />
        <span class="shot-empty-label">No photo</span>
      </span>
      <span class="tile-flag" :class="vacancies ? 'tile-flag--ok' : 'tile-flag--none'">
        {{ vacancies ? `${vacancies} free` : 'Full' }}
      </span>
    </span>
    <span class="tile-body">
      <span class="tile-name">{{ name }}</span>
      <span class="tile-where">{{ distance || address }}</span>
    </span>
  </button>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    id: string
    name: string
    address: string
    image: string
    monogram: string
    distance: string
    vacancies: number
    variant?: 'carousel' | 'grid'
  }>(),
  { variant: 'grid' },
)

const emit = defineEmits<{ open: [id: string] }>()
</script>

<style scoped>
/* Grid tile — square, matches the room cards */
.tile {
  display: flex;
  flex-direction: column;
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  padding: 0;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.tile-shot {
  position: relative;
  display: grid;
  width: 100%;
  aspect-ratio: 1 / 1;
  place-items: center;
  overflow: hidden;
  background: var(--m-primary-soft);
}
.tile-shot img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.tile-shot--empty {
  background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%);
}
.tile-flag {
  position: absolute;
  top: 7px;
  left: 7px;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 800;
}
.tile-flag--ok {
  background: var(--m-success);
  color: #fff;
}
.tile-flag--none {
  background: rgba(23, 32, 42, 0.7);
  color: #fff;
}
.tile-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
  padding: 8px 9px 10px;
}
.tile-name {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
  line-height: 1.25;
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}
.tile-where {
  color: var(--m-muted);
  font-size: 11px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Carousel card — landscape, visually distinct from the room grid */
.car {
  display: flex;
  flex-direction: column;
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-lg, var(--m-radius));
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  padding: 0;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.car-shot {
  position: relative;
  display: grid;
  width: 100%;
  aspect-ratio: 16 / 10;
  place-items: center;
  overflow: hidden;
  background: var(--m-primary-soft);
}
.car-shot img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.car-shot--empty {
  background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%);
}
.car-flag {
  position: absolute;
  top: 8px;
  left: 8px;
  padding: 2px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 800;
}
.car-flag--ok {
  background: var(--m-success);
  color: #fff;
}
.car-flag--none {
  background: rgba(23, 32, 42, 0.7);
  color: #fff;
}
.car-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
  padding: 9px 11px 11px;
}
.car-name {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
  line-height: 1.25;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.car-where {
  color: var(--m-muted);
  font-size: 11.5px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Shared "no photo" placeholder for both variants */
.shot-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  color: var(--m-muted);
}
.shot-empty-label { font-size: 10.5px; font-weight: 700; letter-spacing: 0.02em; }
</style>
