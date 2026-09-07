<template>
  <q-page class="qr-page">
    <div v-if="loading" class="stack">
      <div class="sk-card">
        <q-skeleton type="rect" width="220px" height="220px" class="q-mx-auto" />
      </div>
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card card--pad text-center">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your QR</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <div v-else class="stack">
      <div class="qr-card">
        <template v-if="osasVerified && qrDataUrl">
          <div class="qr-header">
            <IconifyIcon icon="lucide:shield-check" width="24" class="qr-header-icon" />
            <h3 class="qr-title">My student QR</h3>
          </div>
          <p class="qr-sub">
            Show this code at check-in so your manager can confirm you're an active, verified student.
          </p>
          <div class="qr-image-wrapper">
            <img :src="qrDataUrl" alt="Your student QR code" class="qr-image" width="220" height="220" />
          </div>
          <p class="qr-id">ID: {{ studentId }}</p>
          <div class="qr-actions">
            <q-btn flat dense no-caps color="primary" label="Download" class="qr-download" @click="downloadQR" />
          </div>
        </template>
        <template v-else-if="!osasVerified">
          <div class="qr-locked">
            <span class="qr-locked-icon"><IconifyIcon icon="lucide:lock-keyhole" width="26" /></span>
            <p class="qr-locked-title">QR code locked</p>
            <p class="qr-locked-sub">Get verified by OSAS to unlock your student QR code.</p>
            <q-btn unelevated no-caps color="primary" class="qr-locked-cta" label="Verify with OSAS" @click="go('/student/support')" />
          </div>
        </template>
        <template v-else>
          <div class="qr-locked">
            <span class="qr-locked-icon"><IconifyIcon icon="lucide:circle-alert" width="26" /></span>
            <p class="qr-locked-title">Student ID missing</p>
            <p class="qr-locked-sub">Your account doesn't have a student ID on file yet, so a QR code can't be generated. Contact OSAS to have it added.</p>
            <q-btn unelevated no-caps color="primary" class="qr-locked-cta" label="Contact OSAS" @click="go('/student/support')" />
          </div>
        </template>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import QRCode from 'qrcode'
import { supabase } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'

const router = useRouter()
const notify = useNotify()

const loading = ref(true)
const error = ref('')
const studentId = ref('')
const osasVerified = ref(false)
const qrDataUrl = ref('')

function go(path: string) {
  void router.push(path)
}

async function generateQr() {
  if (!studentId.value) {
    qrDataUrl.value = ''
    return
  }
  try {
    qrDataUrl.value = await QRCode.toDataURL(studentId.value, {
      width: 220,
      margin: 1,
      color: { dark: '#111827', light: '#ffffff' },
    })
  } catch {
    qrDataUrl.value = ''
  }
}

function downloadQR() {
  if (!qrDataUrl.value) return
  const link = document.createElement('a')
  link.href = qrDataUrl.value
  link.download = `student-qr-${studentId.value}.png`
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  notify.success('QR code downloaded.')
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data: auth } = await supabase.auth.getUser()
    const user = auth?.user
    if (!user) {
      void router.push('/login')
      return
    }

    const { data: studentProfile, error: profileError } = await supabase
      .from('student_profiles')
      .select('student_id, osas_verified_at')
      .eq('user_id', user.id)
      .maybeSingle()
    if (profileError) throw profileError

    studentId.value = studentProfile?.student_id || ''
    osasVerified.value = !!studentProfile?.osas_verified_at
    qrDataUrl.value = ''
    if (osasVerified.value && studentId.value) {
      await generateQr()
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.qr-page {
  background: var(--m-bg);
  padding-bottom: 24px;
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 12px var(--m-page-gutter) 40px;
}
.sk-card {
  padding: 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.card {
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.card--pad {
  padding: 18px 14px;
}
.err-title {
  margin: 8px 0 0;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.err-sub {
  margin: 2px 0 0;
  color: var(--m-muted);
  font-size: 12px;
}

.qr-card {
  padding: 20px 16px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
}
.qr-locked {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 12px 0 4px;
}
.qr-locked-icon {
  display: grid;
  width: 52px;
  height: 52px;
  margin-bottom: 12px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
}
.qr-locked-title {
  margin: 0;
  font-size: 15px;
  font-weight: 700;
  color: var(--m-ink);
}
.qr-locked-sub {
  margin: 6px 0 16px;
  font-size: 13px;
  color: var(--m-muted);
  line-height: 1.4;
}
.qr-locked-cta {
  width: 100%;
  min-height: 44px;
  border-radius: var(--m-radius-sm);
  font-weight: 700;
}
.qr-header {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  margin-bottom: 4px;
}
.qr-header-icon {
  color: var(--m-primary);
}
.qr-title {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  color: var(--m-ink);
}
.qr-sub {
  margin: 4px 0 16px;
  font-size: 13px;
  color: var(--m-muted);
  line-height: 1.4;
}
.qr-image-wrapper {
  display: flex;
  justify-content: center;
  padding: 8px;
  background: #fff;
  border-radius: var(--m-radius-sm);
  border: 1px solid var(--m-border);
  margin-bottom: 8px;
}
.qr-image {
  display: block;
  width: 220px;
  height: 220px;
  object-fit: contain;
}
.qr-id {
  font-size: 12px;
  font-weight: 500;
  color: var(--m-muted);
  margin: 0 0 16px;
  word-break: break-all;
  background: var(--m-bg);
  padding: 4px 8px;
  border-radius: 4px;
  display: inline-block;
}
.qr-actions {
  display: flex;
  gap: 8px;
  justify-content: center;
}
.qr-download {
  font-weight: 600;
  padding: 6px 18px;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
}
.qr-download:hover {
  background: var(--m-primary-dark);
}
</style>
