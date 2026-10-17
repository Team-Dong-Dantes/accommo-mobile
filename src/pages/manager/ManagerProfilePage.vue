<template>
  <q-page class="profile-page" :class="{ 'page-wide': isDesktop }">
    <!-- Loading -->
    <!-- Desktop: the loaded card's two halves, hero left and details right. -->
    <div v-if="loading" :class="isDesktop ? 'desk-card desk-card--profile' : 'loading-stack'">
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
        <div class="quick-stats">
          <div class="stat-block">
            <q-skeleton type="circle" size="32px" />
            <div>
              <q-skeleton type="text" width="24px" height="18px" />
              <q-skeleton type="text" width="48px" height="10px" />
            </div>
          </div>
          <div class="stat-divider" />
          <div class="stat-block">
            <q-skeleton type="circle" size="32px" />
            <div>
              <q-skeleton type="text" width="24px" height="18px" />
              <q-skeleton type="text" width="40px" height="10px" />
            </div>
          </div>
          <div class="stat-divider" />
          <div class="stat-block">
            <q-skeleton type="circle" size="32px" />
            <div>
              <q-skeleton type="text" width="30px" height="18px" />
              <q-skeleton type="text" width="52px" height="10px" />
            </div>
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
    <div v-else-if="error" class="error-state">
      <q-card flat bordered class="error-card">
        <div class="error-icon">
          <IconifyIcon icon="lucide:cloud-off" width="28" />
        </div>
        <p class="error-title">Couldn't load your profile</p>
        <p class="error-message">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" @click="load()" />
      </q-card>
    </div>

    <!-- Profile Content -->
    <!-- Desktop: the two halves of a card — the hero and a section menu in a
         narrow left half, every detail in the wide right one. Elsewhere the
         .desk-pass wrappers are display: contents. -->
    <div v-else :class="isDesktop ? 'desk-card desk-card--profile' : 'content-stack'">
      <div :class="isDesktop ? 'desk-col' : 'desk-pass'">
      <!-- ===== HEADER ===== -->
      <ProfileHero
        v-model:avatar-url="avatarUrl"
        v-model:cover-url="coverUrl"
        :initials="me.initials"
        :user-id="userId"
        avatar-background="linear-gradient(135deg, #2563eb, #7c3aed)"
        :name="me.fullName || 'Your name'"
        :subtitle="landlordTitle(me.sex)"
        :status-tone="status.tone || 'warn'"
        :status-label="status.label || 'Unverified'"
        :status-icon-name="status.icon"
        :action-icon="auth.isVerifiedLandlord ? 'lucide:scan' : ''"
        action-label="Scan QR"
        @action="go('/manager/profile/qr-scanner')"
      >
        <div class="quick-stats">
          <div class="stat-block">
            <span class="stat-badge">
              <IconifyIcon icon="lucide:building-2" width="16" />
            </span>
            <div>
              <span class="stat-number">{{ accommodationCount }}</span>
              <span class="stat-label">Properties</span>
            </div>
          </div>
          <div class="stat-divider" />
          <div class="stat-block">
            <span class="stat-badge">
              <IconifyIcon icon="lucide:users" width="16" />
            </span>
            <div>
              <span class="stat-number">{{ tenantCount }}</span>
              <span class="stat-label">Boarders</span>
            </div>
          </div>
          <div class="stat-divider" />
          <div class="stat-block">
            <span class="stat-badge">
              <IconifyIcon icon="lucide:message-square" width="16" />
            </span>
            <div>
              <span class="stat-number">{{ responseRate !== null ? responseRate + '%' : '—' }}</span>
              <span class="stat-label">Reply rate</span>
            </div>
          </div>
        </div>
      </ProfileHero>
      <ProfileSectionNav v-if="isDesktop" v-model="tab" :sections="sections" />
      </div>

      <!-- ===== PROFILE ===== -->
      <ManagerProfileDetails />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'
import ManagerProfileDetails from '@/components/manager/profile/ManagerProfileDetails.vue'
import ProfileHero from '@/components/shared/ProfileHero.vue'
import ProfileSectionNav from '@/components/shared/ProfileSectionNav.vue'
import { isDesktop } from '@/utils/useTabletMode'
import { landlordTitle } from '@/utils/format'
import { provideManagerProfile } from '@/components/manager/profile/managerProfile'

// The page is the shell — loading, the hero and the section menu. The details
// half lives in components/manager/profile/.
const {
  auth,
  loading,
  error,
  userId,
  avatarUrl,
  coverUrl,
  me,
  responseRate,
  accommodationCount,
  tenantCount,
  status,
  tab,
  sections,
  go,
  load,
} = provideManagerProfile()
</script>

<style scoped>
/* ===== BASE ===== */
.profile-page {
  /* Manager's blue brand accent — deliberately distinct from the student
     app's teal --m-primary, kept as a page-scoped var to avoid repeating
     the hex across every accent usage below. */
  --mp-accent: #2563eb;
  --mp-accent-dark: #1d4ed8;
  background: var(--m-bg);
  padding-bottom: 24px;
  min-height: 100vh;
}
.loading-stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 12px 16px 80px;
}
.sk-card {
  display: flex;
  flex-direction: column;
  gap: 14px;
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
.sk-hero-top {
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
.error-state {
  display: flex;
  justify-content: center;
  padding: 40px 16px;
}
.error-card {
  max-width: 340px;
  width: 100%;
  padding: 24px 20px;
  border-radius: 16px;
  background: white;
  text-align: center;
}
.error-icon {
  color: var(--m-muted);
  margin-bottom: 8px;
}
.error-title {
  margin: 0 0 4px;
  font-size: 17px;
  font-weight: 700;
  color: var(--m-ink);
}
.error-message {
  margin: 0 0 16px;
  font-size: 14px;
  color: var(--m-muted);
}
/* ===== CONTENT ===== */
/* Desktop: the card fills the page below a gutter, like every halves page. */
.profile-page.page-wide {
  display: flex;
  flex-direction: column;
  padding: 8px var(--m-page-gutter) 0;
}
.content-stack {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 12px 16px 40px;
}
/* Quick Stats */
.quick-stats {
  display: flex;
  flex: 1;
  align-items: center;
  justify-content: space-around;
}
.stat-block {
  display: flex;
  align-items: center;
  gap: 8px;
}
.stat-badge {
  display: flex;
  flex: 0 0 32px;
  width: 32px;
  height: 32px;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.stat-number {
  font-size: 18px;
  font-weight: 700;
  color: var(--m-ink);
  display: block;
  line-height: 1.2;
}
.stat-label {
  font-size: 11px;
  font-weight: 600;
  color: var(--m-muted);
  text-transform: uppercase;
  letter-spacing: 0.03em;
  display: block;
}
.stat-divider {
  width: 1px;
  height: 30px;
  background: var(--m-border);
}
/* Desktop: the stats share the narrow left half, too tight for three
   badge-and-label pairs side by side, so they drop the badges. */
.page-wide .stat-badge {
  display: none;
}
.page-wide .stat-block {
  text-align: center;
}
</style>
