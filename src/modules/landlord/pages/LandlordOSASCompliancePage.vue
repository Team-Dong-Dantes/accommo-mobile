<template>
  <q-page class="osas-page bg-grey-1">
    <div class="page-shell q-pb-xl">
      <div class="header-block q-px-md q-pt-lg q-pb-sm">
        <div class="page-title">OSAS Compliance</div>
        <div class="page-subtitle">Accreditation - Requirements</div>
      </div>

      <div class="q-px-md q-mt-sm">
        <q-tabs
          v-model="activeComplianceTab"
          class="support-tabs"
          active-color="black"
          indicator-color="transparent"
          inline-label
          dense
          switch-indicator
        >
          <q-tab name="accreditation" class="support-tab">
            <span class="tab-label">Accreditation</span>
          </q-tab>
          <q-tab name="requirements" class="support-tab">
            <span class="tab-label">Requirements</span>
          </q-tab>
        </q-tabs>
      </div>

      <q-tab-panels v-model="activeComplianceTab" animated class="bg-transparent">
        <q-tab-panel name="accreditation" class="q-pa-none">
          <div class="q-px-md q-mt-lg">
            <q-list class="accordion-list" bordered separator>
              <q-expansion-item
                v-for="item in complianceItems"
                :key="item.id"
                v-model="item.open"
                expand-separator
                class="accordion-card"
                header-class="accordion-header"
              >
                <template #header>
                  <div class="accordion-header-content">
                    <div class="shield-wrap">
                      <q-icon name="security" color="purple-7" size="22px" />
                    </div>

                    <div class="header-summary">
                      <div class="property-line-row">
                        <span class="property-name">{{ item.propertyName }}</span>
                        <q-badge :color="item.statusColor" class="status-badge">
                          {{ item.status }}
                        </q-badge>
                      </div>

                      <div class="meta-line">
                        <span>{{ item.osasId }}</span>
                        <span class="divider-dot">•</span>
                        <span>{{ item.address }}</span>
                      </div>
                    </div>
                  </div>
                </template>

                <q-card flat class="accordion-body-card">
                  <q-card-section class="q-pb-sm">
                    <div class="details-grid">
                      <div class="info-block">
                        <div class="info-label">Issued On</div>
                        <div class="info-value">{{ item.issuedOn }}</div>
                      </div>
                      <div class="info-block">
                        <div class="info-label">Valid Until</div>
                        <div class="info-value">{{ item.validUntil }}</div>
                      </div>
                    </div>

                    <div class="score-card">
                      <div class="score-header">
                        <div class="score-title">OSAS Property Score</div>
                        <div class="stars-row">
                          <q-icon v-for="star in 5" :key="star" name="star" size="16px" color="amber-6" />
                        </div>
                      </div>
                      <div class="score-value">{{ item.score }}</div>
                    </div>

                    <div class="officer-card">
                      <div class="officer-title">Assigned OSAS Officer</div>
                      <div class="officer-name">{{ item.officer.name }}</div>

                      <div class="officer-actions">
                        <q-btn flat round color="purple-7" icon="mail" />
                        <q-btn flat round color="purple-7" icon="phone" />
                      </div>
                    </div>
                  </q-card-section>
                </q-card>
              </q-expansion-item>
            </q-list>
          </div>
        </q-tab-panel>

        <q-tab-panel name="requirements" class="q-pa-none">
          <div class="q-px-md q-mt-lg">
            <q-card flat bordered class="content-card">
              <q-list separator>
                <q-item v-if="requirementItems.length === 0">
                  <q-item-section>
                    <div class="empty-state">No requirements listed</div>
                  </q-item-section>
                </q-item>

                <q-item v-for="req in requirementItems" :key="req.id" clickable v-ripple class="requirement-item" @click="openRequirement(req)">
                  <q-item-section avatar>
                    <div class="shield-wrap">
                      <q-icon name="description" color="purple-7" size="22px" />
                    </div>
                  </q-item-section>

                  <q-item-section>
                    <div class="property-line-row">
                      <span class="property-name">{{ req.name }}</span>
                      <q-badge :color="req.statusColor" class="status-badge">{{ req.status }}</q-badge>
                    </div>
                    <div class="meta-line">
                      <span>Due {{ req.dueDate }}</span>
                    </div>
                  </q-item-section>

                  <q-item-section side>
                    <q-icon name="chevron_right" color="grey-6" size="22px" />
                  </q-item-section>
                </q-item>
              </q-list>
            </q-card>
          </div>
        </q-tab-panel>
      </q-tab-panels>

      <div class="q-px-md q-mt-xl">
        <div class="section-title contact-header">OSAS OFFICE CONTACT</div>

        <div class="office-grid">
          <q-card v-for="contact in officeContacts" :key="contact.id" flat bordered class="office-card">
            <q-card-section class="column items-center text-center q-pa-md">
              <q-icon :name="contact.icon" size="22px" :color="contact.color" />
              <div class="office-label">{{ contact.label }}</div>
              <div class="office-value">{{ contact.value }}</div>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>
      <q-dialog v-model="requirementDialog" position="bottom">
        <q-card class="req-dialog-card">
          <q-card-section class="q-pt-lg">
            <div class="req-name">{{ selectedRequirement.name }}</div>
            <q-badge :color="selectedRequirement.statusColor" class="req-status-badge q-mt-xs">{{ selectedRequirement.status }}</q-badge>
            <div class="req-due q-mt-sm">Due: {{ selectedRequirement.dueDate }}</div>
            <div class="req-desc q-mt-md">{{ selectedRequirement.description }}</div>
          </q-card-section>

          <q-card-actions align="right" class="q-pa-md q-pt-none">
            <q-btn flat label="Close" color="purple-7" v-close-popup />
          </q-card-actions>
        </q-card>
      </q-dialog>

  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase } from '@/shared/utils/supabase'

interface ComplianceItem {
  id: string
  propertyName: string
  osasId: string
  address: string
  status: string
  statusColor: string
  issuedOn: string
  validUntil: string
  score: string
  officer: {
    name: string
    email: string
    phone: string
  }
  open: boolean
}

interface OfficeContact {
  id: string
  label: string
  value: string
  icon: string
  color: string
}

const activeComplianceTab = ref('accreditation')

const complianceItems = ref<ComplianceItem[]>([])

const officeContacts = ref<OfficeContact[]>([
  {
    id: 'email',
    label: 'Email',
    value: 'support@osas.gov',
    icon: 'mail',
    color: 'purple-7',
  },
  {
    id: 'phone',
    label: 'Phone',
    value: '+63 2 555 0148',
    icon: 'phone',
    color: 'teal-7',
  },
  {
    id: 'hours',
    label: 'Hours',
    value: 'Mon - Fri, 8am - 5pm',
    icon: 'schedule',
    color: 'amber-7',
  },
  {
    id: 'location',
    label: 'Office location',
    value: 'Rizal Park, Manila',
    icon: 'location_on',
    color: 'green-7',
  },
])

interface RequirementItem {
  id: string
  name: string
  description: string
  status: string
  statusColor: string
  dueDate: string
}

const requirementDialog = ref(false)
const selectedRequirement = ref<RequirementItem>({
  id: '',
  name: '',
  description: '',
  status: '',
  statusColor: 'grey-5',
  dueDate: '',
})

const requirementItems = ref<RequirementItem[]>([])

function docTypeLabel(t: string) {
  const map: Record<string, string> = {
    government_id: 'Government ID',
    business_permit: 'Business Permit',
    fire_safety: 'Fire Safety Certificate',
    sanitary: 'Sanitary Permit',
    accreditation: 'OSAS Accreditation Form',
  }
  return map[t] || t.replace(/_/g, ' ')
}

function fmtDate(iso: string | null | undefined) {
  if (!iso) return '—'
  const d = new Date(iso)
  if (isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' })
}

async function loadAccreditation() {
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser()
    if (!user) return
    const { data: accs } = await supabase
      .from('accommodations' as any)
      .select('id, name, address, accreditation_status, accredited_at, accreditation_expires_at, rating_avg')
      .eq('accommodation_manager_id', user.id)
      .order('name')
    const statusMap: Record<string, { label: string; color: string }> = {
      accredited: { label: 'Active', color: 'green-5' },
      reviewing: { label: 'Reviewing', color: 'blue-5' },
      pending: { label: 'Pending', color: 'amber-5' },
      expired: { label: 'Expiring', color: 'amber-5' },
      rejected: { label: 'Rejected', color: 'red-5' },
      delisted: { label: 'Delisted', color: 'grey-5' },
    }
    complianceItems.value = (accs ?? []).map((a: any) => {
      const info = statusMap[a.accreditation_status] || { label: a.accreditation_status || 'Pending', color: 'grey-5' }
      return {
        id: a.id,
        propertyName: a.name || 'Boarding House',
        osasId: 'OSAS-' + String(a.id).slice(0, 6).toUpperCase(),
        address: a.address || '—',
        status: info.label,
        statusColor: info.color,
        issuedOn: fmtDate(a.accredited_at),
        validUntil: fmtDate(a.accreditation_expires_at),
        score: a.rating_avg ? Number(a.rating_avg).toFixed(1) + ' / 5' : '—',
        officer: { name: '—', email: '—', phone: '—' },
        open: false,
      }
    })
  } catch (e) {
    console.error('loadAccreditation error:', e)
  }
}

async function loadRequirements() {
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser()
    if (!user) return
    const { data: docs } = await supabase
      .from('verification_documents')
      .select('id, doc_type, filename, status')
      .eq('user_id', user.id)
    const statusMap: Record<string, { label: string; color: string }> = {
      approved: { label: 'Approved', color: 'green-5' },
      pending: { label: 'Pending', color: 'amber-5' },
      submitted: { label: 'Submitted', color: 'blue-5' },
      rejected: { label: 'Rejected', color: 'red-5' },
    }
    requirementItems.value = (docs ?? []).map((d: any) => {
      const info = statusMap[d.status] || { label: d.status || 'Required', color: 'grey-5' }
      return {
        id: d.id,
        name: docTypeLabel(d.doc_type),
        description: d.filename || 'Uploaded document',
        status: info.label,
        statusColor: info.color,
        dueDate: '—',
      }
    })
  } catch (e) {
    console.error('loadRequirements error:', e)
  }
}

onMounted(() => {
  void loadAccreditation()
  void loadRequirements()
})

function openRequirement(req: RequirementItem) {
  selectedRequirement.value = req
  requirementDialog.value = true
}

</script>

<style scoped>
.osas-page {
  background: #f4f5f7;
}

.page-shell {
  padding-bottom: 110px;
}

.header-block {
  background: #f4f5f7;
}

.page-title {
  color: #111827;
  font-size: 30px;
  font-weight: 800;
  letter-spacing: -0.05em;
}

.page-subtitle {
  margin-top: 4px;
  color: #6b7280;
  font-size: 13px;
  font-weight: 600;
}

.support-tabs {
  background: #edf2f2;
  border-radius: 999px;
  padding: 4px;
}

.support-tab {
  min-height: 42px;
  font-size: 12px;
  font-weight: 700;
  color: #374151;
}

.support-tab :deep(.q-tab__content) {
  gap: 6px;
}

.support-tab[aria-selected='true'] {
  background: white;
  color: #111827;
  border-radius: 999px;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.15);
}

.tab-label {
  position: relative;
  z-index: 1;
}

.accordion-list {
  border-radius: 22px;
  overflow: hidden;
}

.accordion-card {
  background: white;
}

.accordion-header {
  padding: 0;
}

.accordion-header-content {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px 16px;
}

.shield-wrap {
  width: 42px;
  height: 42px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
  background: rgba(124, 58, 237, 0.06);
}

.header-summary {
  flex: 1;
  min-width: 0;
}

.property-line-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.property-name {
  color: #111827;
  font-size: 15px;
  font-weight: 800;
}

.status-badge {
  border-radius: 999px;
  font-size: 9px;
  font-weight: 700;
  padding: 4px 8px;
}

.meta-line {
  margin-top: 4px;
  display: flex;
  align-items: center;
  gap: 6px;
  color: #6b7280;
  font-size: 11px;
  font-weight: 600;
  flex-wrap: wrap;
}

.divider-dot {
  opacity: 0.7;
}

.accordion-body-card {
  background: #fafafa;
}

.details-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.info-block {
  background: white;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 14px;
  padding: 12px;
}

.info-label {
  color: #6b7280;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.info-value {
  margin-top: 6px;
  color: #111827;
  font-size: 14px;
  font-weight: 700;
}

.score-card {
  margin-top: 16px;
  background: #fff7d6;
  border: 1px solid rgba(245, 158, 11, 0.2);
  border-radius: 16px;
  padding: 14px 16px;
}

.score-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.score-title {
  color: #7c2d12;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.stars-row {
  display: flex;
  gap: 2px;
}

.score-value {
  margin-top: 10px;
  color: #111827;
  font-size: 24px;
  font-weight: 800;
}

.officer-card {
  margin-top: 16px;
  background: rgba(124, 58, 237, 0.06);
  border: 1px solid rgba(124, 58, 237, 0.15);
  border-radius: 16px;
  padding: 14px 16px;
}

.officer-title {
  color: #4c1d95;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.officer-name {
  margin-top: 8px;
  color: #111827;
  font-size: 18px;
  font-weight: 800;
}

.officer-actions {
  margin-top: 12px;
  display: flex;
  gap: 8px;
}

.contact-header {
  margin-bottom: 12px;
}

.office-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.office-card {
  border-radius: 18px;
  background: white;
  border: 1px solid rgba(15, 23, 42, 0.06);
}

.office-label {
  margin-top: 14px;
  color: #6b7280;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.office-value {
  margin-top: 6px;
  color: #111827;
  font-size: 12px;
  font-weight: 700;
  line-height: 1.5;
}

.requirement-item {
  padding: 14px 16px;
}

.req-dialog-card {
  width: 100%;
  max-width: 460px;
  border-radius: 20px 20px 0 0;
}

.req-name {
  color: #111827;
  font-size: 20px;
  font-weight: 800;
}

.req-status-badge {
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
  padding: 4px 10px;
}

.req-due {
  color: #6b7280;
  font-size: 12px;
  font-weight: 700;
}

.req-desc {
  color: #374151;
  font-size: 14px;
  line-height: 1.6;
}
</style>
