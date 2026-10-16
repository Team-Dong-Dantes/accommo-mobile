<template>
  <div class="room-rail">
    <button
      v-for="room in rooms"
      :key="room.id"
      type="button"
      class="room-card"
      @click="router.push(`/student/room/${room.id}`)"
    >
      <span class="room-card-photo">
        <img v-if="room.image" :src="room.image" :alt="altFromType ? room.type : room.label" loading="lazy" />
        <PhotoEmpty v-else :size="22" label />
        <span class="room-card-type">{{ room.label }}</span>
      </span>
      <span class="room-card-name-row">
        <span class="room-card-name">{{ room.type }}</span>
        <span v-if="room.capacity" class="room-card-cap">{{ room.capacity }} left</span>
      </span>
      <span v-if="room.meta" class="room-card-meta">{{ room.meta }}</span>
      <span v-if="room.utilities" class="room-card-meta room-card-utils">{{ room.utilities }}</span>
      <span v-if="room.rent" class="room-card-rent">
        {{ formatPeso(room.rent) }}<span class="room-card-per">/mo{{ room.rentBasis === 'person' ? '/person' : '' }}</span>
      </span>
      <span v-else class="room-card-rent room-card-rent--none">On request</span>
    </button>
  </div>
</template>

<script setup lang="ts">
// A sideways rail of room cards; tapping one opens that room.
import { useRouter } from 'vue-router'
import { formatPeso } from '@/utils/format'
import PhotoEmpty from '@/components/shared/PhotoEmpty.vue'

export interface RailRoom {
  id: string
  image: string
  label: string
  type: string
  capacity: number | null
  rent: number
  rentBasis: string
  meta?: string
  utilities?: string
}

defineProps<{
  rooms: RailRoom[]
  /** The photo's alt text is the room type rather than its name. */
  altFromType?: boolean
}>()

const router = useRouter()
</script>

<style scoped>
/* More rooms at this property — same rail card as the Listing page */
.room-rail {
  display: flex;
  gap: 12px;
  margin: 0 calc(var(--m-page-gutter) * -1);
  padding: 0 var(--m-page-gutter);
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
}
.room-card {
  display: flex;
  width: 148px;
  flex: 0 0 148px;
  flex-direction: column;
  border: 0;
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  scroll-snap-align: start;
  -webkit-tap-highlight-color: transparent;
}
.room-card-photo {
  position: relative;
  display: grid;
  height: 120px;
  place-items: center;
  overflow: hidden;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
}
.room-card-photo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.room-card-type {
  position: absolute;
  left: 6px;
  top: 6px;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 9.5px;
  font-weight: 800;
  background: rgba(15, 23, 42, 0.55);
  color: #fff;
}
.room-card-name-row {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 8px;
}
.room-card-name {
  min-width: 0;
  flex: 1 1 auto;
  overflow: hidden;
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.room-card-cap {
  flex: 0 0 auto;
  margin-left: auto;
  padding: 2px 7px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 10px;
  font-weight: 700;
  white-space: nowrap;
}
.room-card-meta {
  margin-top: 1px;
  color: var(--m-muted);
  font-size: 11px;
}
/* One line, however many utilities differ — the room page has the full terms. */
.room-card-utils {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.room-card-rent {
  margin-top: 4px;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 13.5px;
  font-weight: 700;
}
.room-card-rent--none {
  color: var(--m-muted);
  font-family: var(--m-font-body);
  font-size: 11.5px;
  font-weight: 600;
}
.room-card-per {
  font-size: 10px;
  font-weight: 600;
  opacity: 0.7;
}
</style>
