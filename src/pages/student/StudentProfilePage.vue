<template>
  <q-page class="prof" :class="{ 'page-wide': isDesktop }">
    <!-- Loading -->
    <!-- Desktop: the loaded card's two halves, hero left and details right. -->
    <div v-if="loading" :class="isDesktop ? 'desk-card desk-card--profile' : 'stack'">
      <div :class="isDesktop ? 'desk-col' : 'desk-pass'">
      <div class="sk-card">
        <q-skeleton type="rect" height="110px" class="sk-cover" />
        <div class="sk-hero-top">
          <q-skeleton type="circle" size="56px" />
          <div class="sk-hero-meta">
            <q-skeleton type="text" width="55%" height="17px" />
            <q-skeleton type="text" width="40%" height="12px" />
          </div>
        </div>
        <div class="sk-hero-row">
          <q-skeleton type="circle" size="36px" />
          <div class="sk-hero-meta">
            <q-skeleton type="text" width="60%" height="14px" />
            <q-skeleton type="text" width="30%" height="11px" />
          </div>
        </div>
      </div>
      </div>
      <div :class="isDesktop ? 'desk-col' : 'desk-pass'">
      <div class="sk-card sk-fields">
        <q-skeleton type="text" width="45%" height="13px" />
        <q-skeleton type="text" width="90%" height="15px" />
        <q-skeleton type="text" width="90%" height="15px" />
        <q-skeleton type="text" width="90%" height="15px" />
      </div>
      </div>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="stack">
      <ErrorCard title="Couldn't load your profile" :detail="error" :retry="load" />
    </div>

    <!-- Profile Content -->
    <!-- Desktop: the two halves of a card — the hero and a section menu in a
         narrow left half, every detail in the wide right one. Elsewhere the
         .desk-pass wrappers are display: contents. -->
    <div v-else :class="isDesktop ? 'desk-card desk-card--profile' : 'stack'">
      <div :class="isDesktop ? 'desk-col' : 'desk-pass'">
      <!-- Hero Header -->
      <ProfileHero
        v-model:avatar-url="avatarUrl"
        v-model:cover-url="coverUrl"
        :initials="me.initials"
        :user-id="userId"
        :name="me.fullName || 'Your name'"
        :subtitle="courseLine || 'Student'"
        :status-tone="status.tone || 'warn'"
        :status-label="status.label || 'Unverified'"
        :status-icon-name="status.icon"
        action-icon="lucide:qr-code"
        action-label="My QR"
        @action="go('/student/profile/qr')"
      >
        <component :is="stay ? 'button' : 'div'" class="stay-info" v-bind="stay ? { type: 'button' } : {}" @click="stay && go('/student/stay')">
          <span class="stay-badge">
            <IconifyIcon icon="lucide:home" width="18" />
          </span>
          <div class="stay-text">
            <span class="stay-name">{{ stay ? stay.accommodationName : 'No active stay' }}</span>
            <span v-if="stay && stay.roomNumber" class="stay-room">Room {{ stay.roomNumber }}</span>
            <span v-if="stayStatusNote" class="stay-note">{{ stayStatusNote }}</span>
          </div>
          <IconifyIcon v-if="stay" icon="lucide:chevron-right" width="16" class="stay-chevron" />
        </component>
      </ProfileHero>
      <ProfileSectionNav v-if="isDesktop" v-model="tab" :sections="sections" />
      </div>

      <StudentProfileDetails />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import ErrorCard from '@/components/shared/ErrorCard.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import ProfileHero from '@/components/shared/ProfileHero.vue'
import ProfileSectionNav from '@/components/shared/ProfileSectionNav.vue'
import StudentProfileDetails from '@/components/student/profile/StudentProfileDetails.vue'
import { isDesktop } from '@/utils/useTabletMode'
import { provideStudentProfile } from '@/components/student/profile/studentProfile'

// The page is the shell — loading, the hero and the section menu. The details
// half lives in components/student/profile/.
const {
  loading,
  error,
  userId,
  avatarUrl,
  coverUrl,
  me,
  stay,
  status,
  stayStatusNote,
  tab,
  sections,
  courseLine,
  go,
  load,
} = provideStudentProfile()
</script>

<style scoped>
.prof {
  background: var(--m-bg);
  padding-bottom: 20px;
}
/* Desktop: the card fills the page below a gutter, like every halves page. */
.prof.page-wide {
  display: flex;
  flex-direction: column;
  padding: 8px var(--m-page-gutter) 0;
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 12px var(--m-page-gutter) 80px;
}
.sk-card {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
/* Desktop: a half is the card already (as .profile-card is, app.scss). */
.desk-col > .sk-card {
  border: 0;
  background: transparent;
}
/* ProfileHero's cover strip, bled to the card's edges. */
.sk-cover {
  margin: -14px -14px 0;
  border-radius: var(--m-radius) var(--m-radius) 0 0;
}
.sk-hero-top,
.sk-hero-row {
  display: flex;
  align-items: center;
  gap: 12px;
}
.sk-hero-meta {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 6px;
}
.sk-fields {
  gap: 10px;
}
.stay-info {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 10px;
  padding: 0;
  border: 0;
  background: transparent;
  font: inherit;
  text-align: left;
  color: inherit;
}
.stay-badge {
  display: flex;
  flex: 0 0 36px;
  width: 36px;
  height: 36px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.stay-text {
  display: flex;
  flex: 1;
  min-width: 0;
  flex-direction: column;
  gap: 1px;
}
.stay-name {
  font-weight: 600;
  color: var(--m-ink);
}
.stay-room {
  color: var(--m-muted);
  font-size: 13px;
}
.stay-note {
  color: var(--m-warning);
  font-size: 12px;
  font-weight: 600;
}
.stay-chevron {
  flex: 0 0 auto;
  color: var(--m-muted);
}
button.stay-info {
  cursor: pointer;
}
</style>
