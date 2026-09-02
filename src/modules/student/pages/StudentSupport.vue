<template>
  <q-page class="osas-hub-page">
    <main class="osas-hub-shell">
      <section class="tab-workspace" aria-label="Student OSAS Workspace">
        <!-- Web-Aligned Folder Tabs Navigation -->
        <q-tabs
          v-model="activeTab"
          dense
          no-caps
          align="left"
          class="folder-tabs"
        >
          <q-tab name="verification" class="folder-tab" no-caps>
            <div class="row items-center no-wrap q-gutter-xs">
              <IconifyIcon icon="lucide:shield-check" width="16" aria-hidden="true" />
              <span>Clearances & Renewals</span>
              <span v-if="!osasVerified || hasExpiringStudentDocs" class="tab-badge-warn">Action</span>
            </div>
          </q-tab>

          <q-tab name="tickets" class="folder-tab" no-caps>
            <div class="row items-center no-wrap q-gutter-xs">
              <IconifyIcon icon="lucide:life-buoy" width="16" aria-hidden="true" />
              <span>Support & Bugs</span>
              <span v-if="tickets.length > 0" class="tab-badge-neutral">{{ tickets.length }}</span>
            </div>
          </q-tab>
        </q-tabs>

        <!-- Main Tab Workspace Card -->
        <div class="tab-card">
          <!-- ==============================================================
               TAB 1: STUDENT VERIFICATION & CLEARANCES MATRIX
               ============================================================== -->
          <div v-if="activeTab === 'verification'" class="tab-content-panel">
            <!-- Student Header Spec Bar -->
            <header class="property-spec-bar">
              <div class="spec-left">
                <span class="spec-label">Enrollment & Clearances</span>
                <strong class="spec-name">{{ studentIdNumber ? `ISU ID: ${studentIdNumber}` : 'Student Verification' }}</strong>
                <span class="spec-location font-mono">Annual Semester Clearances</span>
              </div>
              <div class="spec-right">
                <span class="status-badge" :class="`status-badge--${osasVerified ? 'success' : 'warning'}`">
                  {{ osasVerified ? 'Verified Student' : 'Renewal / Action' }}
                </span>
                <span class="spec-score font-mono">{{ verifiedDocCount }}/3 Valid</span>
              </div>
            </header>

            <!-- Dense Document Clearance Matrix for Student -->
            <div class="clearance-matrix">
              <div
                v-for="(doc, idx) in studentDocItems"
                :key="doc.key"
                class="clearance-row"
                :class="{ 'clearance-row--expanded': expandedDocKey === doc.key }"
              >
                <div class="row-summary" @click="toggleDocExpand(doc.key)">
                  <div class="row-seq font-mono">{{ String(idx + 1).padStart(2, '0') }}</div>
                  
                  <div class="row-main">
                    <div class="row-title-line">
                      <strong class="row-title">{{ doc.label }}</strong>
                      <span class="status-indicator" :class="`indicator--${doc.status}`">
                        {{ doc.statusLabel }}
                      </span>
                    </div>
                    <div class="row-sub-line">
                      <span class="row-authority">{{ doc.desc }}</span>
                      <span v-if="doc.updatedAt" class="row-expiry font-mono">
                        · Updated: {{ formatDate(doc.updatedAt) }}
                      </span>
                    </div>
                  </div>

                  <div class="row-action-side">
                    <IconifyIcon
                      :icon="expandedDocKey === doc.key ? 'lucide:chevron-up' : 'lucide:chevron-down'"
                      width="18"
                      class="text-grey-6"
                    />
                  </div>
                </div>

                <!-- Expanded Action Area with Right-Aligned Upload Document button -->
                <div v-if="expandedDocKey === doc.key" class="row-expanded-details">
                  <div class="expanded-meta-grid font-mono">
                    <div class="meta-cell">
                      <small>CLEARANCE</small>
                      <span>{{ doc.key.toUpperCase() }}</span>
                    </div>
                    <div class="meta-cell">
                      <small>STATUS</small>
                      <span :class="`text-${doc.status}`">{{ doc.statusLabel.toUpperCase() }}</span>
                    </div>
                    <div class="meta-cell">
                      <small>SEMESTER RENEWAL</small>
                      <span>{{ doc.fileUrl ? 'UPLOADED' : 'PENDING' }}</span>
                    </div>
                  </div>

                  <div class="expanded-actions right-align">
                    <a
                      v-if="doc.fileUrl"
                      :href="doc.fileUrl"
                      target="_blank"
                      rel="noopener"
                      class="btn-view-doc"
                    >
                      <IconifyIcon icon="lucide:external-link" width="14" />
                      <span>View File</span>
                    </a>
                    <button
                      type="button"
                      class="btn-upload-action"
                      @click="openUploadModal(doc.key)"
                    >
                      <IconifyIcon icon="lucide:upload" width="14" />
                      <span>Upload Document</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- ==============================================================
               TAB 2: SYSTEM ISSUES & BUG TICKETS
               ============================================================== -->
          <div v-else class="tab-content-panel">
            <div class="tickets-top-bar">
              <span class="tickets-count-label font-mono">{{ tickets.length }} REPORTED TICKETS</span>
              <button type="button" class="create-ticket-btn" @click="openNewTicketModal">
                <IconifyIcon icon="lucide:plus" width="16" />
                <span>Report Issue</span>
              </button>
            </div>

            <div v-if="ticketsLoading" class="loading-wrap">
              <q-spinner-dots color="teal-8" size="32px" />
            </div>

            <EmptyState
              v-else-if="tickets.length === 0"
              icon="lucide:check-circle-2"
              title="No Reported Problems"
              message="If you experience bugs, booking errors, or system issues, report them here."
            />

            <div v-else class="tickets-matrix">
              <article
                v-for="t in tickets"
                :key="t.id"
                class="ticket-matrix-row"
                @click="openTicketDetail(t)"
              >
                <div class="ticket-row-top">
                  <span class="ticket-tag font-mono">TCK-{{ t.id.slice(0, 6).toUpperCase() }}</span>
                  <span class="status-indicator" :class="`indicator--${statusTone(t.status)}`">
                    {{ statusLabel(t.status) }}
                  </span>
                </div>
                <strong class="ticket-row-title">{{ t.title || t.subject }}</strong>
                <p class="ticket-row-desc">{{ t.description || 'No statement provided.' }}</p>
                <div v-if="t.screenshot_url" class="ticket-attachment-pill">
                  <IconifyIcon icon="lucide:image" width="13" />
                  <span>Screenshot Attached</span>
                </div>
                <div class="ticket-row-meta font-mono">
                  <span>{{ formatCategory(t.category) }}</span>
                  <time>{{ formatDate(t.filed_at || t.created_at) }}</time>
                </div>
              </article>
            </div>
          </div>
        </div>
      </section>

      <!-- ==============================================================
           DOCUMENT UPLOAD / RENEWAL MODAL (COR / ID)
           ============================================================== -->
      <q-dialog v-model="uploadDialog" position="bottom" transition-show="slide-up" transition-hide="slide-down">
        <q-card class="modal-sheet">
          <header class="modal-header">
            <div>
              <span class="modal-kicker font-mono">STUDENT ENROLLMENT & RENEWAL</span>
              <h3 class="modal-title">{{ activeDocLabel }}</h3>
            </div>
            <button type="button" class="btn-close" aria-label="Close" @click="uploadDialog = false">
              <IconifyIcon icon="lucide:x" width="18" />
            </button>
          </header>

          <div class="modal-body">
            <div class="field-group">
              <label for="student-id-field" class="input-label font-mono">STUDENT ID NUMBER</label>
              <q-input id="student-id-field" v-model="corForm.studentIdNumber" outlined dense placeholder="e.g. 21-0891" />
            </div>

            <div class="field-group">
              <label class="input-label font-mono">SEMESTER CLEARANCE / COR (PDF / IMAGE)</label>
              <AuthFileDropZone
                v-model="corForm.file"
                label="Attach renewed PDF or document photo"
                accept=".pdf,.jpg,.jpeg,.png,image/*"
              />
              <div v-if="corForm.file" class="file-pill font-mono">
                <IconifyIcon icon="lucide:file-check" width="16" />
                <span>{{ corForm.file.name }}</span>
              </div>
            </div>

            <div class="modal-footer right-align">
              <q-btn flat no-caps label="Cancel" @click="uploadDialog = false" />
              <q-btn
                unelevated
                no-caps
                class="btn-submit"
                :loading="submittingCor"
                :disable="!corForm.file"
                label="Upload Document"
                @click="submitDocument"
              />
            </div>
          </div>
        </q-card>
      </q-dialog>

      <!-- ==============================================================
           SYSTEM PROBLEM / BUG TICKET FORM WITH SCREENSHOT UPLOAD
           ============================================================== -->
      <q-dialog v-model="ticketDialog" position="bottom" transition-show="slide-up" transition-hide="slide-down">
        <q-card class="modal-sheet">
          <header class="modal-header">
            <div>
              <span class="modal-kicker font-mono">SYSTEM & APP SUPPORT</span>
              <h3 class="modal-title">Report a System Problem</h3>
            </div>
            <button type="button" class="btn-close" aria-label="Close" @click="ticketDialog = false">
              <IconifyIcon icon="lucide:x" width="18" />
            </button>
          </header>

          <div class="modal-body">
            <div class="field-group">
              <label for="ticket-sub-box" class="input-label font-mono">ISSUE SUMMARY</label>
              <q-input id="ticket-sub-box" v-model="newTicketForm.title" outlined dense placeholder="e.g. Cannot complete rent proof upload" />
            </div>

            <div class="field-group">
              <label for="ticket-cat-box" class="input-label font-mono">PROBLEM CATEGORY</label>
              <q-select
                id="ticket-cat-box"
                v-model="newTicketForm.category"
                :options="systemCategoryOptions"
                outlined
                dense
                emit-value
                map-options
              />
            </div>

            <div class="field-group">
              <label for="ticket-statement" class="input-label font-mono">EXPLANATION OF PROBLEM / ERROR DETAILS</label>
              <q-input
                id="ticket-statement"
                v-model="newTicketForm.description"
                type="textarea"
                rows="3"
                outlined
                dense
                placeholder="Describe what you were trying to do when the issue happened..."
              />
            </div>

            <div class="field-group">
              <label class="input-label font-mono">SCREENSHOT / ERROR PHOTO (OPTIONAL)</label>
              <AuthFileDropZone
                v-model="newTicketForm.screenshot"
                label="Attach screenshot or photo of the error"
                accept=".jpg,.jpeg,.png,image/*"
              />
              <div v-if="newTicketForm.screenshot" class="file-pill font-mono">
                <IconifyIcon icon="lucide:image" width="16" />
                <span>{{ newTicketForm.screenshot.name }}</span>
              </div>
            </div>

            <div class="modal-footer right-align">
              <q-btn flat no-caps label="Cancel" @click="ticketDialog = false" />
              <q-btn
                unelevated
                no-caps
                class="btn-submit"
                :loading="submittingTicket"
                :disable="!newTicketForm.title.trim()"
                label="Upload Document"
                @click="submitNewTicket"
              />
            </div>
          </div>
        </q-card>
      </q-dialog>
    </main>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from '@/shared/utils/supabase'
import { uploadDocument } from '@/shared/utils/upload'
import AuthFileDropZone from '@/modules/auth/components/AuthFileDropZone.vue'
import EmptyState from '@/shared/components/EmptyState.vue'

const $q = useQuasar()
const activeTab = ref<'verification' | 'tickets'>('verification')
const osasVerified = ref(false)
const studentIdNumber = ref('')
const tickets = ref<any[]>([])
const ticketsLoading = ref(false)

const expandedDocKey = ref<string | null>('cor')
const uploadDialog = ref(false)
const activeDocKey = ref('cor')
const submittingCor = ref(false)
const corForm = ref({
  studentIdNumber: '',
  file: null as File | null,
})

const ticketDialog = ref(false)
const submittingTicket = ref(false)
const newTicketForm = ref({
  title: '',
  category: 'technical_bug',
  description: '',
  screenshot: null as File | null,
})

const systemCategoryOptions = [
  { label: 'Technical Bug / UI Error', value: 'technical_bug' },
  { label: 'Payment & Receipt Failure', value: 'payment_issue' },
  { label: 'Account & Login Issue', value: 'account_problem' },
  { label: 'Data Sync / Loading Error', value: 'sync_error' },
  { label: 'Other System Problem', value: 'other_problem' },
]

const studentDocItems = ref<any[]>([
  {
    key: 'cor',
    label: 'Certificate of Registration (COR)',
    desc: 'Official semester registration proving active university enrollment.',
    icon: 'lucide:file-text',
    status: 'missing',
    statusLabel: 'Missing',
    fileUrl: null,
    updatedAt: null,
  },
  {
    key: 'id_card',
    label: 'University Student ID Card',
    desc: 'Front and back photo of your issued ISU student identification card.',
    icon: 'lucide:contact-2',
    status: 'missing',
    statusLabel: 'Missing',
    fileUrl: null,
    updatedAt: null,
  },
  {
    key: 'good_moral',
    label: 'Good Moral Certificate',
    desc: 'University character endorsement for boarding house accreditation.',
    icon: 'lucide:award',
    status: 'missing',
    statusLabel: 'Optional',
    fileUrl: null,
    updatedAt: null,
  },
])

const activeDocLabel = computed(() => {
  const doc = studentDocItems.value.find((d) => d.key === activeDocKey.value)
  return doc?.label || 'Upload Document'
})

const verifiedDocCount = computed(() => {
  return studentDocItems.value.filter((d) => d.status === 'approved' || d.fileUrl).length
})

const hasExpiringStudentDocs = computed(() => {
  return studentDocItems.value.some((d) => d.status === 'missing')
})

function toggleDocExpand(key: string) {
  expandedDocKey.value = expandedDocKey.value === key ? null : key
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return '—'
  const d = new Date(dateStr)
  return isNaN(d.getTime()) ? '—' : d.toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' })
}

function statusTone(status: string): string {
  if (status === 'resolved') return 'success'
  if (status === 'in_progress' || status === 'assigned') return 'warning'
  return 'neutral'
}
function statusLabel(status: string): string {
  if (status === 'resolved') return 'Resolved'
  if (status === 'in_progress') return 'In Progress'
  if (status === 'assigned') return 'Assigned'
  return 'Submitted'
}
function formatCategory(cat: string): string {
  const map: Record<string, string> = {
    technical_bug: 'Bug / UI Error',
    payment_issue: 'Payment Failure',
    account_problem: 'Account Issue',
    sync_error: 'Sync Problem',
    other_problem: 'System Issue',
  }
  return map[cat] || cat || 'System Issue'
}

function openUploadModal(key: string) {
  activeDocKey.value = key
  corForm.value = { studentIdNumber: studentIdNumber.value || '', file: null }
  uploadDialog.value = true
}

async function submitDocument() {
  if (!corForm.value.file) return
  submittingCor.value = true
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error('Not authenticated')

    const fileUrl = await uploadDocument(corForm.value.file, user.id, `student_${activeDocKey.value}`)
    
    // Save to user metadata
    await supabase.auth.updateUser({
      data: {
        [`${activeDocKey.value}_url`]: fileUrl,
        student_id_number: corForm.value.studentIdNumber || undefined,
        osas_verified: false,
      },
    })

    if (corForm.value.studentIdNumber) {
      studentIdNumber.value = corForm.value.studentIdNumber
    }

    const target = studentDocItems.value.find((d) => d.key === activeDocKey.value)
    if (target) {
      target.fileUrl = fileUrl
      target.status = 'pending'
      target.statusLabel = 'Under Review'
      target.updatedAt = new Date().toISOString()
    }

    uploadDialog.value = false
    $q.notify({ type: 'positive', message: 'Clearance submitted to OSAS.' })
  } catch (e: any) {
    $q.notify({ type: 'negative', message: e?.message || 'Failed to upload document' })
  } finally {
    submittingCor.value = false
  }
}

function openNewTicketModal() {
  newTicketForm.value = { title: '', category: 'technical_bug', description: '', screenshot: null }
  ticketDialog.value = true
}

async function submitNewTicket() {
  if (!newTicketForm.value.title.trim()) return
  submittingTicket.value = true
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error('Not authenticated')

    let screenshotUrl: string | null = null
    if (newTicketForm.value.screenshot) {
      screenshotUrl = await uploadDocument(newTicketForm.value.screenshot, user.id, 'ticket_screenshot')
    }

    const { data, error } = await (supabase as any)
      .from('complaints')
      .insert({
        student_id: user.id,
        landlord_id: user.id,
        property_id: '',
        subject: newTicketForm.value.title.trim(),
        title: newTicketForm.value.title.trim(),
        category: newTicketForm.value.category,
        description: newTicketForm.value.description.trim() + (screenshotUrl ? `\n[Screenshot]: ${screenshotUrl}` : ''),
        status: 'pending',
        priority: 'medium',
      })
      .select('*')
      .single()

    if (error) throw error
    if (data) {
      tickets.value.unshift({ ...data, screenshot_url: screenshotUrl })
    }
    ticketDialog.value = false
    $q.notify({ type: 'positive', message: 'Support ticket submitted to system admin.' })
  } catch (e: any) {
    $q.notify({ type: 'negative', message: e?.message || 'Failed to submit ticket' })
  } finally {
    submittingTicket.value = false
  }
}

function openTicketDetail(t: any) {
  $q.dialog({
    title: t.title || t.subject,
    message: `${t.description || 'No statement provided.'}\n\nStatus: ${statusLabel(t.status)}\nClassification: ${formatCategory(t.category)}`,
    ok: 'Close',
  })
}

async function loadData() {
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return

    const meta = user.user_metadata as any
    osasVerified.value = meta?.osas_verified === true
    studentIdNumber.value = meta?.student_id_number || ''

    studentDocItems.value.forEach((doc) => {
      const url = meta?.[`${doc.key}_url`]
      if (url) {
        doc.fileUrl = url
        doc.status = osasVerified.value ? 'approved' : 'pending'
        doc.statusLabel = osasVerified.value ? 'Verified' : 'Under Review'
      }
    })

    // Load Student's Tickets
    ticketsLoading.value = true
    const { data: compList } = await (supabase as any)
      .from('complaints')
      .select('*')
      .eq('student_id', user.id)
      .order('filed_at', { ascending: false, nullsFirst: false })

    tickets.value = compList || []
  } catch (e) {
    console.error('Failed to load student OSAS data:', e)
  } finally {
    ticketsLoading.value = false
  }
}

onMounted(() => {
  void loadData()
})
</script>

<style scoped>
.osas-hub-page {
  min-height: 100vh;
  background: var(--m-bg, #f6f7f8);
  color: var(--m-text, #374151);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

.osas-hub-shell {
  max-width: 680px;
  margin: 0 auto;
  padding: 0 0 calc(90px + env(safe-area-inset-bottom));
}

/* Tab Workspace & Folder Tabs */
.tab-workspace {
  position: relative;
  z-index: 0;
}

.folder-tabs {
  position: relative;
  z-index: 1;
  min-height: 42px;
  padding: 0 8px;
  overflow: visible;
  background: transparent;
}

.folder-tabs :deep(.q-tabs__content) {
  justify-content: flex-start;
  flex-wrap: nowrap;
  overflow: visible;
}

.folder-tabs :deep(.folder-tab) {
  min-width: max-content;
  min-height: 42px;
  margin-right: 4px;
  padding: 0 16px;
  border: 1px solid var(--m-border, #e5e7eb);
  border-bottom: 0;
  border-radius: 11px 11px 0 0;
  background: var(--m-surface-2, #f8fafc);
  color: var(--m-muted, #6b7280);
  font-size: 12.5px;
  font-weight: 750;
  transition: background-color 0.15s ease, color 0.15s ease;
}

.folder-tabs :deep(.folder-tab.q-tab--active) {
  z-index: 2;
  margin-bottom: -1px;
  border-bottom: 1px solid var(--m-surface, #ffffff);
  position: relative;
  background: var(--m-surface, #ffffff);
  color: var(--m-primary-dark, #00695c);
}

.folder-tabs :deep(.folder-tab.q-tab--active)::after {
  position: absolute;
  right: 0;
  bottom: -1px;
  left: 0;
  height: 2px;
  content: '';
  background: var(--m-surface, #ffffff);
}

.folder-tabs :deep(.q-tab__indicator) {
  display: none;
}

.tab-card {
  overflow: hidden;
  border: 1px solid var(--m-border, #e5e7eb);
  border-radius: 16px;
  background: var(--m-surface, #ffffff);
  padding: 14px;
}

.tab-content-panel {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.tab-badge-warn {
  padding: 1px 6px;
  border-radius: 10px;
  background: #fef3c7;
  color: #b45309;
  font-size: 10px;
  font-weight: 800;
}
.tab-badge-neutral {
  padding: 1px 6px;
  border-radius: 10px;
  background: #f3f4f6;
  color: #374151;
  font-size: 10px;
  font-weight: 800;
}

/* Header Spec Bar */
.property-spec-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  border-radius: 10px;
  background: #f8fafc;
  border: 1px solid var(--m-border, #e5e7eb);
}
.spec-left {
  display: flex;
  flex-direction: column;
}
.spec-label {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--m-muted, #6b7280);
}
.spec-name {
  font-size: 14.5px;
  font-weight: 850;
  color: var(--m-ink, #17202a);
}
.spec-location {
  font-size: 11px;
  color: var(--m-muted, #6b7280);
}
.spec-right {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 4px;
}
.status-badge {
  padding: 3px 8px;
  border-radius: 6px;
  font-size: 10.5px;
  font-weight: 800;
}
.status-badge--success { background: #ecfdf3; color: #15803d; }
.status-badge--warning { background: #fff7ed; color: #b45309; }
.spec-score {
  font-size: 11px;
  font-weight: 700;
  color: var(--m-muted, #6b7280);
}

/* Dense Clearance Matrix */
.clearance-matrix {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border, #e5e7eb);
  border-radius: 12px;
  overflow: hidden;
  background: #ffffff;
}
.clearance-row {
  border-bottom: 1px solid var(--m-border, #e5e7eb);
  transition: background 0.15s ease;
}
.clearance-row:last-child {
  border-bottom: 0;
}
.clearance-row--expanded {
  background: #fafbfc;
}
.row-summary {
  display: flex;
  align-items: center;
  padding: 12px 14px;
  gap: 12px;
  cursor: pointer;
}
.row-seq {
  font-size: 12px;
  font-weight: 800;
  color: var(--m-muted, #6b7280);
  width: 20px;
}
.row-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.row-title-line {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}
.row-title {
  font-size: 13.5px;
  font-weight: 800;
  color: var(--m-ink, #17202a);
}
.status-indicator {
  font-size: 10.5px;
  font-weight: 800;
  padding: 2px 7px;
  border-radius: 4px;
}
.indicator--approved { background: #ecfdf3; color: #15803d; }
.indicator--pending { background: #fff7ed; color: #b45309; }
.indicator--missing { background: #fef2f2; color: #b91c1c; }

.row-sub-line {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 11.5px;
  color: var(--m-muted, #6b7280);
}
.row-expiry {
  color: #00695c;
  font-weight: 600;
}

/* Expanded Details */
.row-expanded-details {
  padding: 4px 14px 14px 46px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  border-top: 1px dashed var(--m-border, #e5e7eb);
  background: #f8fafc;
}
.expanded-meta-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
  padding: 8px 10px;
  border-radius: 8px;
  background: #ffffff;
  border: 1px solid #e5e7eb;
}
.meta-cell {
  display: flex;
  flex-direction: column;
}
.meta-cell small {
  font-size: 9px;
  color: #94a3b8;
}
.meta-cell span {
  font-size: 11px;
  font-weight: 750;
  color: var(--m-ink, #17202a);
}
.text-approved { color: #15803d !important; }
.text-pending { color: #b45309 !important; }
.text-missing { color: #b91c1c !important; }

.expanded-actions {
  display: flex;
  gap: 8px;
}
.right-align {
  justify-content: flex-end;
}
.btn-view-doc, .btn-upload-action {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  height: 36px;
  padding: 0 14px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 750;
  cursor: pointer;
  text-decoration: none;
}
.btn-view-doc {
  background: #ffffff;
  border: 1px solid var(--m-border, #e5e7eb);
  color: var(--m-ink, #17202a);
}
.btn-upload-action {
  background: var(--m-primary-dark, #00695c);
  border: 0;
  color: #ffffff;
}

/* Tickets Tab */
.tickets-top-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}
.tickets-count-label {
  font-size: 11.5px;
  font-weight: 800;
  letter-spacing: 0.04em;
  color: var(--m-muted, #6b7280);
}
.create-ticket-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 34px;
  padding: 0 12px;
  border-radius: 6px;
  border: 0;
  background: var(--m-primary-dark, #00695c);
  color: #ffffff;
  font-size: 12px;
  font-weight: 750;
  cursor: pointer;
}

.tickets-matrix {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border, #e5e7eb);
  border-radius: 12px;
  overflow: hidden;
  background: #ffffff;
}
.ticket-matrix-row {
  padding: 12px 14px;
  border-bottom: 1px solid var(--m-border, #e5e7eb);
  cursor: pointer;
  display: flex;
  flex-direction: column;
  gap: 4px;
  transition: background 0.15s ease;
}
.ticket-matrix-row:hover {
  background: #f8fafc;
}
.ticket-matrix-row:last-child {
  border-bottom: 0;
}
.ticket-row-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.ticket-tag {
  font-size: 10.5px;
  font-weight: 750;
  color: var(--m-muted, #6b7280);
}
.ticket-row-title {
  font-size: 13.5px;
  color: var(--m-ink, #17202a);
}
.ticket-row-desc {
  margin: 0;
  font-size: 11.5px;
  color: var(--m-muted, #6b7280);
  line-height: 1.35;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.ticket-attachment-pill {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11px;
  font-weight: 600;
  color: #00695c;
  background: #e6f5f3;
  padding: 2px 6px;
  border-radius: 4px;
  width: fit-content;
}
.ticket-row-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 10.5px;
  color: var(--m-muted, #6b7280);
  margin-top: 2px;
}

.indicator--success { background: #ecfdf3; color: #15803d; }
.indicator--warning { background: #fff7ed; color: #b45309; }
.indicator--neutral { background: #f3f4f6; color: #4b5563; }

/* Modals */
.modal-sheet {
  border-radius: 18px 18px 0 0;
  background: #ffffff;
  padding-bottom: env(safe-area-inset-bottom);
}
.modal-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  padding: 14px 16px;
  border-bottom: 1px solid #f3f4f6;
}
.modal-kicker {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.08em;
  color: var(--m-primary-dark, #00695c);
}
.modal-title {
  margin: 2px 0 0;
  font-size: 16px;
  font-weight: 850;
  color: var(--m-ink, #17202a);
}
.btn-close {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  border: 0;
  background: #f3f4f6;
  display: grid;
  place-items: center;
  cursor: pointer;
}
.modal-body {
  padding: 14px 16px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.field-group {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.input-label {
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.04em;
  color: var(--m-ink, #17202a);
}
.file-pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  border-radius: 6px;
  background: var(--m-primary-soft, #e6f5f3);
  color: var(--m-primary-dark, #00695c);
  font-size: 11.5px;
  font-weight: 700;
  margin-top: 4px;
}
.modal-footer {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 8px;
}
.btn-submit {
  background: var(--m-primary-dark, #00695c);
  color: #ffffff;
  border-radius: 6px;
  font-weight: 750;
  padding: 0 16px;
}

.font-mono { font-family: var(--m-font-mono, monospace); }
.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0,0,0,0); border: 0; }
</style>
