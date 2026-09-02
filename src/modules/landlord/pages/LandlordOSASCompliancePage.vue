<template>
  <q-page class="osas-hub-page">
    <main class="osas-hub-shell">
      <section class="tab-workspace" aria-label="OSAS Workspace">
        <!-- Web-Aligned Folder Tabs Navigation -->
        <q-tabs
          v-model="activeTab"
          dense
          no-caps
          align="left"
          class="folder-tabs"
        >
          <q-tab name="accreditation" class="folder-tab" no-caps>
            <div class="row items-center no-wrap q-gutter-xs">
              <IconifyIcon icon="lucide:shield-check" width="16" aria-hidden="true" />
              <span>Requirements</span>
              <span class="tab-badge-neutral">{{ pendingClearancesTotal }}</span>
            </div>
          </q-tab>

          <q-tab name="tickets" class="folder-tab" no-caps>
            <div class="row items-center no-wrap q-gutter-xs">
              <IconifyIcon icon="lucide:life-buoy" width="16" aria-hidden="true" />
              <span>Support tickets</span>
              <span v-if="tickets.length > 0" class="tab-badge-warn">{{ tickets.length }}</span>
            </div>
          </q-tab>
        </q-tabs>

        <!-- Main Tab Workspace Card -->
        <div class="tab-card">
          <!-- ==============================================================
               TAB 1: REQUIREMENTS
               ============================================================== -->
          <div v-if="activeTab === 'accreditation'" class="tab-content-panel">
            <!-- No Properties State -->
            <EmptyState
              v-if="!loadingProps && properties.length === 0"
              icon="lucide:building-2"
              title="No Accommodations Added"
              message="Register your accommodation to submit the required statutory documents and annual renewals."
            >
              <q-btn unelevated no-caps to="/landlord/properties/new" label="Upload Document" class="add-prop-btn q-mt-sm" />
            </EmptyState>

            <template v-else>
              <!-- Multi-Property Segment Chips -->
              <div v-if="properties.length > 1" class="property-selector-strip">
                <div class="property-pill-scroll">
                  <button
                    v-for="prop in properties"
                    :key="prop.id"
                    type="button"
                    class="property-pill"
                    :class="{ active: selectedPropertyId === prop.id }"
                    @click="selectedPropertyId = prop.id"
                  >
                    <span class="prop-dot" :class="`prop-dot--${accreditationTone(prop.accreditation_status)}`" />
                    <span class="prop-name">{{ prop.name }}</span>
                    <span class="prop-count">{{ getPropVerifiedCount(prop.id) }}/4</span>
                  </button>
                </div>
              </div>

              <!-- Property Status & Inspection Row -->
              <header v-if="currentProperty" class="property-spec-bar">
                <div class="spec-left">
                  <span class="spec-label">Inspection Target</span>
                  <strong class="spec-name">{{ currentProperty.name }}</strong>
                  <span class="spec-location font-mono">{{ currentProperty.address || 'Address unassigned' }}</span>
                </div>
                <div class="spec-right">
                  <span class="status-badge" :class="`status-badge--${accreditationTone(currentProperty.accreditation_status)}`">
                    {{ accreditationTitle(currentProperty.accreditation_status) }}
                  </span>
                  <span class="spec-score font-mono">{{ currentPropertyVerifiedCount }}/4 Valid</span>
                </div>
              </header>

              <!-- Dense Document Clearance Matrix (Authoritative List with Expiry/Renewal Status) -->
              <div class="clearance-matrix">
                <div
                  v-for="(doc, idx) in statutoryPermits"
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
                        <span class="row-authority">{{ doc.authority }}</span>
                        <span v-if="doc.expiryDate" class="row-expiry font-mono" :class="{ 'text-danger': doc.isExpired, 'text-amber': doc.isExpiringSoon }">
                          · {{ doc.isExpired ? 'Expired: ' : doc.isExpiringSoon ? 'Renewal Due: ' : 'Exp: ' }}{{ formatDate(doc.expiryDate) }}
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

                  <!-- Expanded Details & Direct Action (Right-Aligned Upload Document Button) -->
                  <div v-if="expandedDocKey === doc.key" class="row-expanded-details">
                    <p class="expanded-desc">{{ doc.desc }}</p>
                    
                    <div class="expanded-meta-grid font-mono">
                      <div class="meta-cell">
                        <small>DOC TYPE</small>
                        <span>{{ doc.key }}</span>
                      </div>
                      <div class="meta-cell">
                        <small>STATUS</small>
                        <span :class="`text-${doc.status}`">{{ doc.statusLabel.toUpperCase() }}</span>
                      </div>
                      <div class="meta-cell">
                        <small>ANNUAL RENEWAL</small>
                        <span>{{ doc.expiryDate ? (doc.isExpired ? 'EXPIRED' : doc.isExpiringSoon ? 'DUE SOON' : 'ACTIVE') : 'MISSING' }}</span>
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
                        <span>View Document</span>
                      </a>
                      <button
                        type="button"
                        class="btn-upload-action"
                        @click="openUploadPage(doc.key)"
                      >
                        <IconifyIcon icon="lucide:upload" width="14" />
                        <span>Upload Document</span>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </template>
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
              message="If you experience bugs, payment sync issues, or system errors, report them here."
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
           DOCUMENT CLEARANCE / RENEWAL UPLOAD MODAL
           ============================================================== -->
      <q-dialog v-model="uploadDialog" position="bottom" transition-show="slide-up" transition-hide="slide-down">
        <q-card class="modal-sheet">
          <header class="modal-header">
            <div class="doc-header-info">
              <span class="modal-kicker font-mono">CLEARANCE & ANNUAL RENEWAL</span>
              <h3 class="modal-title">{{ activeDocDef?.label }}</h3>
              <p class="modal-sub">{{ currentProperty?.name }}</p>
            </div>
            <button type="button" class="btn-close" aria-label="Close" @click="uploadDialog = false">
              <IconifyIcon icon="lucide:x" width="18" />
            </button>
          </header>

          <div class="modal-body">
            <div class="field-group">
              <label for="permit-exp" class="input-label font-mono">NEW EXPIRATION / VALIDITY DATE</label>
              <q-input
                id="permit-exp"
                v-model="uploadForm.expiryDate"
                type="date"
                outlined
                dense
              />
            </div>

            <div class="field-group">
              <label class="input-label font-mono">RENEWED CLEARANCE DOCUMENT (PDF / SCAN)</label>
              <AuthFileDropZone
                v-model="uploadForm.file"
                label="Attach renewed PDF or clearance photo"
                accept=".pdf,.jpg,.jpeg,.png,image/*"
              />
              <div v-if="uploadForm.file" class="file-pill font-mono">
                <IconifyIcon icon="lucide:file-check" width="16" />
                <span>{{ uploadForm.file.name }}</span>
              </div>
            </div>

            <div class="modal-footer right-align">
              <q-btn flat no-caps label="Cancel" @click="uploadDialog = false" />
              <q-btn
                unelevated
                no-caps
                class="btn-submit"
                :loading="submittingDoc"
                :disable="!uploadForm.file"
                label="Upload Document"
                @click="submitPermitClearance"
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
              <label for="ticket-sub-input" class="input-label font-mono">ISSUE SUMMARY</label>
              <q-input id="ticket-sub-input" v-model="newTicketForm.title" outlined dense placeholder="e.g. Booking confirmation error on room 2B" />
            </div>

            <div class="field-group">
              <label for="ticket-cat-sel" class="input-label font-mono">PROBLEM CATEGORY</label>
              <q-select
                id="ticket-cat-sel"
                v-model="newTicketForm.category"
                :options="systemCategoryOptions"
                outlined
                dense
                emit-value
                map-options
              />
            </div>

            <div class="field-group">
              <label for="ticket-desc-box" class="input-label font-mono">EXPLANATION OF PROBLEM / STEPS TO REPRODUCE</label>
              <q-input
                id="ticket-desc-box"
                v-model="newTicketForm.description"
                type="textarea"
                rows="3"
                outlined
                dense
                placeholder="Describe what happened, error messages received, or unexpected behavior..."
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
const activeTab = ref<'accreditation' | 'tickets'>('accreditation')
const properties = ref<any[]>([])
const documentsByProperty = ref<Record<string, any[]>>({})
const selectedPropertyId = ref<string>('')
const loadingProps = ref(true)
const tickets = ref<any[]>([])
const ticketsLoading = ref(false)

const expandedDocKey = ref<string | null>('sanitary_permit')

const uploadDialog = ref(false)
const uploadStep = ref(1)
const activeDocKey = ref<string>('')
const submittingDoc = ref(false)
const uploadForm = ref({
  expiryDate: '',
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

const STATUTORY_DOC_DEFS: Record<string, { label: string; authority: string; desc: string; icon: string }> = {
  sanitary_permit: {
    label: 'Sanitary Permit',
    authority: 'City Health Office (CHO)',
    desc: 'Annual health and sanitary clearance confirming water potability and hygiene standards.',
    icon: 'lucide:clipboard-check',
  },
  fire_safety: {
    label: 'Fire Safety Inspection (FSIC)',
    authority: 'Bureau of Fire Protection (BFP)',
    desc: 'BFP certificate certifying functional emergency exits, alarms, and fire extinguishers.',
    icon: 'lucide:flame',
  },
  business_permit: {
    label: "Mayor's / Business Permit",
    authority: 'Local Government Unit (LGU)',
    desc: 'Municipal business license authorizing commercial boarding house operations.',
    icon: 'lucide:building-2',
  },
  building_permit: {
    label: 'Building / Occupancy Permit',
    authority: 'City Engineering Office',
    desc: 'Structural integrity and building occupancy clearance for student tenancy.',
    icon: 'lucide:shield-check',
  },
}

const activeDocDef = computed(() => STATUTORY_DOC_DEFS[activeDocKey.value])

const currentProperty = computed(() => {
  return properties.value.find((p) => p.id === selectedPropertyId.value) || properties.value[0] || null
})

const statutoryPermits = computed(() => {
  const prop = currentProperty.value
  const docs = (prop ? documentsByProperty.value[prop.id] : []) || []
  const now = new Date()

  return Object.keys(STATUTORY_DOC_DEFS).map((key) => {
    const def = STATUTORY_DOC_DEFS[key]
    const docRow = docs.find((d: any) => d.doc_type === key)
    const hasFile = Boolean(docRow?.file_url)
    
    // Calculate expiration & renewal status
    let isExpired = false
    let isExpiringSoon = false
    if (docRow?.expires_at) {
      const exp = new Date(docRow.expires_at)
      if (!isNaN(exp.getTime())) {
        if (exp.getTime() < now.getTime()) {
          isExpired = true
        } else if (exp.getTime() - now.getTime() < 30 * 24 * 60 * 60 * 1000) {
          isExpiringSoon = true
        }
      }
    }

    const isApproved = prop?.accreditation_status === 'accredited' && !isExpired
    const isPending = hasFile && !isApproved

    let status = 'missing'
    let statusLabel = 'Missing'
    if (isExpired) {
      status = 'missing'
      statusLabel = 'Expired - Renewal Due'
    } else if (isExpiringSoon) {
      status = 'pending'
      statusLabel = 'Expiring Soon'
    } else if (isApproved) {
      status = 'approved'
      statusLabel = 'Approved'
    } else if (isPending) {
      status = 'pending'
      statusLabel = 'Under Review'
    }

    return {
      key,
      label: def?.label || key,
      authority: def?.authority || 'Accreditation Board',
      desc: def?.desc || '',
      icon: def?.icon || 'lucide:file-text',
      status,
      statusLabel,
      fileUrl: docRow?.file_url || null,
      expiryDate: docRow?.expires_at || null,
      isExpired,
      isExpiringSoon,
    }
  })
})

const currentPropertyVerifiedCount = computed(() => {
  return statutoryPermits.value.filter((d) => d.status === 'approved' && !d.isExpired).length
})

const pendingClearancesTotal = computed(() => {
  let total = 0
  properties.value.forEach((prop) => {
    if (prop.accreditation_status !== 'accredited') total++
  })
  return total
})

function toggleDocExpand(key: string) {
  expandedDocKey.value = expandedDocKey.value === key ? null : key
}

function getPropVerifiedCount(propId: string): number {
  const prop = properties.value.find((p) => p.id === propId)
  if (prop?.accreditation_status === 'accredited') return 4
  const docs = documentsByProperty.value[propId] || []
  return docs.filter((d: any) => Boolean(d.file_url)).length
}

function accreditationTone(status: string | null | undefined): string {
  if (status === 'accredited') return 'success'
  if (status === 'reviewing' || status === 'pending') return 'warning'
  return 'danger'
}
function accreditationTitle(status: string | null | undefined): string {
  if (status === 'accredited') return 'Accredited'
  if (status === 'reviewing') return 'In Review'
  if (status === 'pending') return 'Pending Docs'
  return 'Renewal / Action'
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

function openUploadPage(key: string) {
  activeDocKey.value = key
  const docs = (currentProperty.value ? documentsByProperty.value[currentProperty.value.id] : []) || []
  const docRow = docs.find((d: any) => d.doc_type === key)
  uploadForm.value = {
    expiryDate: docRow?.expires_at ? docRow.expires_at.split('T')[0] : '',
    file: null,
  }
  uploadDialog.value = true
}

async function submitPermitClearance() {
  if (!uploadForm.value.file || !currentProperty.value?.id) return
  submittingDoc.value = true
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error('Not authenticated')

    const fileUrl = await uploadDocument(uploadForm.value.file, user.id, `permit_${activeDocKey.value}`)

    // Upsert into accommodation_documents table
    const { error: docError } = await (supabase as any)
      .from('accommodation_documents')
      .upsert({
        accommodation_id: currentProperty.value.id,
        doc_type: activeDocKey.value,
        file_url: fileUrl,
        expires_at: uploadForm.value.expiryDate || null,
        uploaded_at: new Date().toISOString(),
        version: 1,
      }, { onConflict: 'accommodation_id,doc_type' })

    if (docError) {
      await (supabase as any)
        .from('accommodation_documents')
        .insert({
          accommodation_id: currentProperty.value.id,
          doc_type: activeDocKey.value,
          file_url: fileUrl,
          expires_at: uploadForm.value.expiryDate || null,
          uploaded_at: new Date().toISOString(),
          version: 1,
        })
    }

    await (supabase as any)
      .from('accommodations')
      .update({ accreditation_status: 'reviewing' })
      .eq('id', currentProperty.value.id)

    currentProperty.value.accreditation_status = 'reviewing'
    
    // Local cache update
    const currentDocs = documentsByProperty.value[currentProperty.value.id] || []
    const existingIndex = currentDocs.findIndex((d) => d.doc_type === activeDocKey.value)
    if (existingIndex >= 0) {
      currentDocs[existingIndex] = {
        ...currentDocs[existingIndex],
        file_url: fileUrl,
        expires_at: uploadForm.value.expiryDate || null,
      }
    } else {
      currentDocs.push({
        accommodation_id: currentProperty.value.id,
        doc_type: activeDocKey.value,
        file_url: fileUrl,
        expires_at: uploadForm.value.expiryDate || null,
      })
    }
    documentsByProperty.value[currentProperty.value.id] = [...currentDocs]

    uploadDialog.value = false
    $q.notify({ type: 'positive', message: 'Clearance renewal submitted for review.' })
  } catch (e: any) {
    $q.notify({ type: 'negative', message: e?.message || 'Failed to submit clearance' })
  } finally {
    submittingDoc.value = false
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

    const propId = currentProperty.value?.id || ''
    const { data, error } = await (supabase as any)
      .from('complaints')
      .insert({
        student_id: user.id,
        landlord_id: user.id,
        property_id: propId,
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
  loadingProps.value = true
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return

    const { data: props, error: pErr } = await (supabase as any)
      .from('accommodations')
      .select('id, name, address, business_name, accreditation_status')
      .eq('accommodation_manager_id', user.id)
      .order('name', { ascending: true })

    if (pErr) throw pErr

    const propList = (props || []).map((p: any) => ({
      ...p,
      name: p.business_name || p.name || 'Accommodation',
    }))

    properties.value = propList
    const propIds = propList.map((p: any) => p.id)

    if (propIds.length > 0) {
      if (!selectedPropertyId.value) {
        selectedPropertyId.value = propList[0]?.id || ''
      }

      const { data: docRows } = await (supabase as any)
        .from('accommodation_documents')
        .select('id, accommodation_id, doc_type, file_url, expires_at')
        .in('accommodation_id', propIds)

      const map: Record<string, any[]> = {}
      ;(docRows || []).forEach((row: any) => {
        if (!map[row.accommodation_id]) map[row.accommodation_id] = []
        map[row.accommodation_id]!.push(row)
      })
      documentsByProperty.value = map
    }

    ticketsLoading.value = true
    const { data: compList } = await (supabase as any)
      .from('complaints')
      .select('*')
      .or(`landlord_id.eq.${user.id},student_id.eq.${user.id}`)
      .order('filed_at', { ascending: false, nullsFirst: false })

    tickets.value = compList || []
  } catch (e) {
    console.error('Failed to load OSAS data:', e)
  } finally {
    loadingProps.value = false
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

/* Property Carousel Strip */
.property-selector-strip {
  margin-bottom: 2px;
}
.property-pill-scroll {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding-bottom: 4px;
  scrollbar-width: none;
}
.property-pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  border-radius: 999px;
  border: 1px solid var(--m-border, #e5e7eb);
  background: var(--m-surface-2, #f8fafc);
  cursor: pointer;
  white-space: nowrap;
  font-size: 12px;
  font-weight: 700;
  color: var(--m-text, #374151);
}
.property-pill.active {
  border-color: var(--m-primary-dark, #00695c);
  background: var(--m-primary-soft, #e6f5f3);
  color: var(--m-primary-dark, #00695c);
}
.prop-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
}
.prop-dot--success { background: #15803d; }
.prop-dot--warning { background: #b45309; }
.prop-dot--danger { background: #b91c1c; }
.prop-count {
  font-size: 10.5px;
  padding: 1px 5px;
  border-radius: 4px;
  background: #ffffff;
  color: #4b5563;
}
.property-pill.active .prop-count {
  background: #ffffff;
  color: var(--m-primary-dark, #00695c);
}

/* Property Spec Bar */
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
.status-badge--danger { background: #fef2f2; color: #b91c1c; }
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

/* Expanded Row Details with Right-Aligned Action */
.row-expanded-details {
  padding: 4px 14px 14px 46px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  border-top: 1px dashed var(--m-border, #e5e7eb);
  background: #f8fafc;
}
.expanded-desc {
  margin: 8px 0 0;
  font-size: 12px;
  color: var(--m-muted, #6b7280);
  line-height: 1.4;
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

.add-prop-btn {
  background: var(--m-primary-dark, #00695c);
  color: #ffffff;
  border-radius: 6px;
  font-weight: 750;
}

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
.modal-sub {
  margin: 1px 0 0;
  font-size: 11.5px;
  color: var(--m-muted, #6b7280);
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
