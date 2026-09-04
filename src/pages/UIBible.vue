<template>
  <q-page class="bible-page">
    <header class="bible-header">
      <button type="button" class="icon-button" aria-label="Go back" @click="goBack">
        <IconifyIcon icon="lucide:arrow-left" width="21" />
      </button>
      <div class="wordmark">accommo</div>
      <span class="version">Mobile 1.0</span>
    </header>

    <main class="bible-content">
      <section class="intro">
        <span class="eyebrow">Design system</span>
        <h1>UI Bible</h1>
        <p>The source of truth for Accommo’s student and accommodation-manager mobile experience.</p>
        <div class="principles">
          <span>Clear</span><span>Trustworthy</span><span>Mobile-first</span>
        </div>
      </section>

      <section class="bible-section">
        <div class="section-heading">
          <span class="section-number">01</span>
          <div><h2>Color</h2><p>Teal establishes trust. Semantic colors always retain one meaning.</p></div>
        </div>
        <div v-for="group in colorGroups" :key="group.name" class="color-group">
          <h3>{{ group.name }}</h3>
          <div class="swatch-grid">
            <button
              v-for="color in group.colors"
              :key="color.token"
              type="button"
              class="swatch"
              :style="{ background: `var(${color.token})`, color: color.dark ? '#fff' : 'var(--m-ink)' }"
              :aria-label="`Copy ${color.token}`"
              @click="copyToken(color.token)"
            >
              <strong>{{ color.name }}</strong>
              <code>{{ color.token }}</code>
            </button>
          </div>
        </div>
      </section>

      <section class="bible-section">
        <div class="section-heading">
          <span class="section-number">02</span>
          <div><h2>Typography</h2><p>A compact hierarchy optimized for small screens and quick scanning.</p></div>
        </div>
        <div class="type-list">
          <div v-for="type in typeScale" :key="type.label" class="type-row">
            <span class="type-meta">{{ type.label }} · {{ type.size }}</span>
            <span :style="{ fontSize: type.size, fontWeight: type.weight, lineHeight: type.lineHeight }">{{ type.sample }}</span>
          </div>
        </div>
      </section>

      <section class="bible-section">
        <div class="section-heading">
          <span class="section-number">03</span>
          <div><h2>Spacing & shape</h2><p>A 4px base scale with rounded, approachable mobile surfaces.</p></div>
        </div>
        <div class="spacing-list">
          <div v-for="space in spacing" :key="space.token" class="spacing-row">
            <code>{{ space.token }}</code><span class="spacing-track"><i :style="{ width: space.value }" /></span><span>{{ space.value }}</span>
          </div>
        </div>
        <div class="radius-grid">
          <div v-for="radius in radii" :key="radius.token">
            <span class="radius-demo" :style="{ borderRadius: radius.value }" />
            <code>{{ radius.token }}<br>{{ radius.value }}</code>
          </div>
        </div>
      </section>

      <section class="bible-section">
        <div class="section-heading">
          <span class="section-number">04</span>
          <div><h2>App shell</h2><p>Student and manager interfaces share the same header and bottom navigation.</p></div>
        </div>
        <div class="phone-preview">
          <div class="preview-header"><strong>accommo</strong><span class="avatar">MS</span></div>
          <div class="preview-body">
            <span class="skeleton wide" /><span class="skeleton" />
            <div class="preview-card"><span class="skeleton short" /><span class="skeleton wide" /><span class="skeleton" /></div>
          </div>
          <nav class="preview-nav" aria-label="Example bottom navigation">
            <span class="active"><IconifyIcon icon="lucide:house" width="21" />Home</span>
            <span><IconifyIcon icon="lucide:search" width="21" />Discover</span>
            <span><IconifyIcon icon="lucide:message-circle" width="21" />Messages</span>
            <span><IconifyIcon icon="lucide:bell" width="21" />Alerts</span>
          </nav>
        </div>
        <ul class="rules-list">
          <li>Header is white, shadowless, and 56px tall.</li>
          <li>Profile uses an uploaded image or initials fallback.</li>
          <li>Bottom actions have a minimum 44px touch target.</li>
          <li>Focused pages hide app chrome and provide a back button.</li>
        </ul>
      </section>

      <section class="bible-section">
        <div class="section-heading">
          <span class="section-number">05</span>
          <div><h2>Components</h2><p>Core controls shown in their intended hierarchy and states.</p></div>
        </div>

        <h3 class="component-label">Buttons</h3>
        <div class="button-stack">
          <q-btn unelevated no-caps label="Primary action" color="primary" class="demo-button" />
          <q-btn outline no-caps label="Secondary action" color="primary" class="demo-button" />
          <q-btn flat no-caps label="Tertiary action" color="primary" class="demo-button" />
          <q-btn unelevated no-caps label="Unavailable" disable class="demo-button" />
        </div>

        <h3 class="component-label">Form controls</h3>
        <div class="form-stack">
          <q-input v-model="demoName" outlined label="Full name" color="primary">
            <template #prepend><IconifyIcon icon="lucide:user" width="19" /></template>
          </q-input>
          <q-input v-model="demoSearch" outlined label="Search accommodations" color="primary" clearable>
            <template #prepend><IconifyIcon icon="lucide:search" width="19" /></template>
          </q-input>
          <q-toggle v-model="notificationsOn" color="primary" label="Receive payment reminders" />
        </div>

        <h3 class="component-label">Status</h3>
        <div class="status-row">
          <span class="status success"><IconifyIcon icon="lucide:circle-check" />Verified</span>
          <span class="status warning"><IconifyIcon icon="lucide:clock-3" />Pending</span>
          <span class="status danger"><IconifyIcon icon="lucide:circle-alert" />Action needed</span>
          <span class="status info"><IconifyIcon icon="lucide:info" />Information</span>
        </div>

        <h3 class="component-label">Cards & lists</h3>
        <article class="demo-card">
          <span class="card-icon"><IconifyIcon icon="lucide:building-2" width="22" /></span>
          <div><strong>Riverside Boarding House</strong><p>2 rooms available · 850 m away</p></div>
          <IconifyIcon icon="lucide:chevron-right" width="20" class="chevron" />
        </article>
        <div class="demo-list">
          <button v-for="item in listItems" :key="item.label" type="button">
            <span class="list-icon"><IconifyIcon :icon="item.icon" width="20" /></span>
            <span><strong>{{ item.label }}</strong><small>{{ item.caption }}</small></span>
            <IconifyIcon icon="lucide:chevron-right" width="19" />
          </button>
        </div>
      </section>

      <section class="bible-section do-dont">
        <div class="section-heading">
          <span class="section-number">06</span>
          <div><h2>Usage rules</h2><p>Consistency protects clarity across both user roles.</p></div>
        </div>
        <div class="guidance do"><strong><IconifyIcon icon="lucide:check" /> Do</strong><p>Use one primary action, plain language, real data, and recoverable error states.</p></div>
        <div class="guidance dont"><strong><IconifyIcon icon="lucide:x" /> Don’t</strong><p>Mix icon families, overload cards, hide navigation state, or use color as the only status cue.</p></div>
      </section>
    </main>

    <q-banner v-if="copied" dense rounded class="copy-banner">Copied {{ copied }}</q-banner>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';

const router = useRouter();
const copied = ref('');
const demoName = ref('Maria Santos');
const demoSearch = ref('');
const notificationsOn = ref(true);

const colorGroups = [
  { name: 'Brand', colors: [
    { name: 'Primary', token: '--m-primary', dark: true },
    { name: 'Primary dark', token: '--m-primary-dark', dark: true },
    { name: 'Primary soft', token: '--m-primary-soft', dark: false },
  ]},
  { name: 'Foundation', colors: [
    { name: 'Ink', token: '--m-ink', dark: true },
    { name: 'Text', token: '--m-text', dark: true },
    { name: 'Muted', token: '--m-muted', dark: true },
    { name: 'Background', token: '--m-bg', dark: false },
    { name: 'Surface', token: '--m-surface', dark: false },
    { name: 'Border', token: '--m-border', dark: false },
  ]},
  { name: 'Semantic', colors: [
    { name: 'Success', token: '--m-success', dark: true },
    { name: 'Warning', token: '--m-warning', dark: true },
    { name: 'Danger', token: '--m-danger', dark: true },
    { name: 'Info', token: '--m-info', dark: true },
  ]},
];

const typeScale = [
  { label: 'Display', size: '32px', weight: 750, lineHeight: 1.1, sample: 'Find your place.' },
  { label: 'Page title', size: '24px', weight: 700, lineHeight: 1.2, sample: 'Current accommodation' },
  { label: 'Section', size: '18px', weight: 700, lineHeight: 1.3, sample: 'Payment history' },
  { label: 'Body', size: '15px', weight: 400, lineHeight: 1.55, sample: 'Everything you need, clearly organized.' },
  { label: 'Caption', size: '12px', weight: 600, lineHeight: 1.4, sample: 'UPDATED 10 MINUTES AGO' },
];

const spacing = [
  { token: '--m-space-1', value: '4px' }, { token: '--m-space-2', value: '8px' },
  { token: '--m-space-3', value: '12px' }, { token: '--m-space-4', value: '16px' },
  { token: '--m-space-5', value: '20px' }, { token: '--m-space-6', value: '24px' },
  { token: '--m-space-8', value: '32px' },
];

const radii = [
  { token: '--m-radius-sm', value: '12px' },
  { token: '--m-radius', value: '16px' },
  { token: '--m-radius-lg', value: '24px' },
];

const listItems = [
  { icon: 'lucide:receipt-text', label: 'Payments', caption: 'Review rent and payment history' },
  { icon: 'lucide:shield-check', label: 'Verification', caption: 'Documents and account status' },
  { icon: 'lucide:life-buoy', label: 'Support', caption: 'Get help from the Accommo team' },
];

function goBack() {
  if (window.history.length > 1) router.back();
  else void router.push('/');
}

async function copyToken(token: string) {
  await navigator.clipboard?.writeText(`var(${token})`);
  copied.value = token;
  window.setTimeout(() => { copied.value = ''; }, 1400);
}
</script>

<style scoped>
.bible-page { min-height: 100vh; background: var(--m-bg); color: var(--m-text); }
.bible-header { position: sticky; top: 0; z-index: 10; display: grid; grid-template-columns: 44px 1fr auto; min-height: 56px; align-items: center; gap: 8px; padding: 0 16px; border-bottom: 1px solid var(--m-border); background: rgba(255,255,255,.96); backdrop-filter: blur(12px); }
.icon-button { display: grid; width: 44px; height: 44px; padding: 0; place-items: center; border: 0; border-radius: 50%; background: transparent; color: var(--m-ink); }
.wordmark { font-size: 23px; font-weight: 750; letter-spacing: -.04em; }
.version { color: var(--m-muted); font-size: 11px; font-weight: 700; }
.bible-content { width: min(100%, 720px); margin: 0 auto; padding: 24px 16px 64px; }
.intro { padding: 24px 4px 32px; }
.eyebrow, .section-number { color: var(--m-primary); font-size: 11px; font-weight: 800; letter-spacing: .12em; text-transform: uppercase; }
.intro h1 { margin: 7px 0 10px; color: var(--m-ink); font-size: clamp(36px, 12vw, 52px); line-height: 1; letter-spacing: -.055em; }
.intro p { max-width: 560px; margin: 0; color: var(--m-muted); font-size: 15px; line-height: 1.55; }
.principles { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 20px; }
.principles span { padding: 7px 10px; border: 1px solid var(--m-border); border-radius: 999px; background: var(--m-surface); color: var(--m-ink); font-size: 11px; font-weight: 700; }
.bible-section { margin-bottom: 16px; padding: 20px; border: 1px solid var(--m-border); border-radius: var(--m-radius-lg); background: var(--m-surface); }
.section-heading { display: grid; grid-template-columns: 28px 1fr; gap: 8px; margin-bottom: 22px; }
.section-heading h2 { margin: 0 0 4px; color: var(--m-ink); font-size: 22px; line-height: 1.2; }
.section-heading p { margin: 0; color: var(--m-muted); font-size: 13px; line-height: 1.45; }
.color-group + .color-group { margin-top: 18px; }
.color-group h3, .component-label { margin: 0 0 10px; color: var(--m-muted); font-size: 11px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; }
.swatch-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; }
.swatch { display: flex; min-height: 90px; flex-direction: column; align-items: flex-start; justify-content: flex-end; padding: 10px; border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); text-align: left; }
.swatch strong { font-size: 12px; }.swatch code { font-size: 9px; opacity: .78; }
.type-list { display: grid; gap: 4px; }.type-row { display: flex; min-height: 92px; flex-direction: column; justify-content: center; gap: 8px; padding: 12px 0; border-bottom: 1px solid var(--m-border); color: var(--m-ink); }.type-row:last-child { border: 0; }.type-meta { color: var(--m-muted); font-size: 10px; font-weight: 700; text-transform: uppercase; }
.spacing-list { display: grid; gap: 12px; }.spacing-row { display: grid; grid-template-columns: 105px 1fr 32px; align-items: center; gap: 8px; color: var(--m-muted); font-size: 10px; }.spacing-track { height: 8px; border-radius: 4px; background: var(--m-bg); }.spacing-track i { display: block; height: 100%; border-radius: 4px; background: var(--m-primary); }
.radius-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-top: 24px; }.radius-grid > div { min-width: 0; }.radius-demo { display: block; aspect-ratio: 1.3; margin-bottom: 7px; border: 1px solid #8cd5ce; background: var(--m-primary-soft); }.radius-grid code { color: var(--m-muted); font-size: 9px; overflow-wrap: anywhere; }
.phone-preview { overflow: hidden; max-width: 360px; margin: 0 auto; border: 1px solid var(--m-border); border-radius: 28px; background: var(--m-bg); box-shadow: var(--m-shadow); }.preview-header { display: flex; height: 56px; align-items: center; justify-content: space-between; padding: 0 16px; border-bottom: 1px solid var(--m-border); background: #fff; }.preview-header strong { color: var(--m-ink); font-size: 22px; letter-spacing: -.04em; }.avatar { display: grid; width: 34px; height: 34px; place-items: center; border-radius: 50%; background: var(--m-primary-soft); color: var(--m-primary-dark); font-size: 11px; font-weight: 800; }.preview-body { min-height: 225px; padding: 24px 16px; }.skeleton { display: block; width: 60%; height: 10px; margin-bottom: 9px; border-radius: 5px; background: #e2e5e8; }.skeleton.wide { width: 84%; }.skeleton.short { width: 38%; }.preview-card { margin-top: 28px; padding: 18px; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: #fff; }.preview-nav { display: grid; height: 64px; grid-template-columns: repeat(4, 1fr); border-top: 1px solid var(--m-border); background: #fff; }.preview-nav span { display: flex; align-items: center; justify-content: center; flex-direction: column; gap: 3px; color: #9ca3af; font-size: 9px; font-weight: 600; }.preview-nav .active { color: var(--m-primary); }.rules-list { margin: 20px 0 0; padding-left: 20px; color: var(--m-muted); font-size: 12px; line-height: 1.7; }
.component-label { margin-top: 26px; }.button-stack, .form-stack { display: grid; gap: 10px; }.demo-button { min-height: 48px; border-radius: var(--m-radius-sm); font-weight: 700; }.form-stack :deep(.q-field__control) { border-radius: var(--m-radius-sm); }.status-row { display: flex; flex-wrap: wrap; gap: 8px; }.status { display: inline-flex; min-height: 30px; align-items: center; gap: 5px; padding: 0 9px; border-radius: 999px; font-size: 11px; font-weight: 700; }.status.success { background: var(--m-success-soft); color: var(--m-success); }.status.warning { background: var(--m-warning-soft); color: var(--m-warning); }.status.danger { background: var(--m-danger-soft); color: var(--m-danger); }.status.info { background: var(--m-info-soft); color: var(--m-info); }
.demo-card { display: grid; grid-template-columns: 42px 1fr auto; align-items: center; gap: 12px; padding: 16px; border: 1px solid var(--m-border); border-radius: var(--m-radius); box-shadow: var(--m-shadow); }.card-icon, .list-icon { display: grid; width: 42px; height: 42px; place-items: center; border-radius: 12px; background: var(--m-primary-soft); color: var(--m-primary-dark); }.demo-card strong, .demo-list strong { display: block; color: var(--m-ink); font-size: 13px; }.demo-card p { margin: 4px 0 0; color: var(--m-muted); font-size: 11px; }.chevron { color: var(--m-muted); }.demo-list { overflow: hidden; margin-top: 12px; border: 1px solid var(--m-border); border-radius: var(--m-radius); }.demo-list button { display: grid; width: 100%; min-height: 70px; grid-template-columns: 42px 1fr auto; align-items: center; gap: 12px; padding: 12px; border: 0; border-bottom: 1px solid var(--m-border); background: #fff; color: var(--m-muted); text-align: left; }.demo-list button:last-child { border-bottom: 0; }.demo-list small { display: block; margin-top: 3px; color: var(--m-muted); font-size: 10px; }
.guidance { padding: 14px; border-radius: var(--m-radius-sm); }.guidance + .guidance { margin-top: 10px; }.guidance strong { display: flex; align-items: center; gap: 6px; font-size: 12px; }.guidance p { margin: 6px 0 0; font-size: 12px; line-height: 1.5; }.guidance.do { background: var(--m-success-soft); color: var(--m-success); }.guidance.dont { background: var(--m-danger-soft); color: var(--m-danger); }.copy-banner { position: fixed; right: 16px; bottom: 16px; z-index: 20; background: var(--m-ink); color: #fff; font-size: 11px; }
@media (min-width: 600px) { .bible-content { padding: 32px 24px 80px; }.bible-section { padding: 28px; }.swatch-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
@media (prefers-reduced-motion: reduce) { * { scroll-behavior: auto !important; transition: none !important; } }
</style>
