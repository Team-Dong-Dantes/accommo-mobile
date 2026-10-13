<template>
  <q-page class="cp">
    <div class="cp-wrap">
      <div v-if="loading" class="cp-card">
        <q-skeleton type="rect" height="4px" />
        <q-skeleton type="circle" size="64px" class="cp-sk-icon" />
        <q-skeleton type="text" width="60%" height="20px" />
        <q-skeleton type="text" width="85%" />
        <q-skeleton type="rect" height="44px" />
      </div>

      <!-- Finished: everything asked for, saved or skipped. -->
      <div v-else-if="!step" class="cp-card cp-done">
        <span class="cp-icon" :class="{ 'cp-icon--good': !skipped }">
          <IconifyIcon :icon="skipped ? 'lucide:list-checks' : 'lucide:party-popper'" width="30" />
        </span>
        <h1 class="cp-title">{{ skipped ? 'Saved for now' : "You're all set" }}</h1>
        <p class="cp-why">
          {{ skipped
            ? `${skipped} ${skipped === 1 ? 'thing is' : 'things are'} left for later. Your dashboard will remind you.`
            : 'Your profile is complete.' }}
        </p>
        <button class="cp-primary" @click="router.replace(profileRoute)">Done</button>
      </div>

      <div v-else class="cp-card">
        <div class="cp-progress">
          <div class="cp-progress-row">
            <q-btn flat dense round class="cp-back" aria-label="Go back" @click="back">
              <IconifyIcon icon="lucide:arrow-left" width="20" />
            </q-btn>
            <span class="cp-step">Step {{ index + 1 }} of {{ gaps.length }}</span>
          </div>
          <div class="cp-track" role="progressbar" :aria-valuenow="index + 1" :aria-valuemin="1" :aria-valuemax="gaps.length">
            <span v-for="(g, i) in gaps" :key="g.key" class="cp-seg" :class="{ done: i < index, current: i === index }" />
          </div>
        </div>

        <span class="cp-icon"><IconifyIcon :icon="STEP[step].icon" width="30" /></span>
        <h1 class="cp-title">{{ STEP[step].title }}</h1>
        <p class="cp-why">{{ STEP[step].why }}</p>

        <div class="cp-body">
          <div v-if="step === 'photo'" class="cp-photo">
            <AvatarUpload v-model="photoUrl" :initials="initials" :user-id="userId" :size="120" />
            <span class="cp-hint">Tap the circle to choose a photo</span>
          </div>

          <div v-else-if="step === 'sex'" class="cp-choices">
            <button
              v-for="opt in SEX"
              :key="opt.value"
              class="cp-choice"
              :class="{ 'is-on': form.sex === opt.value }"
              :aria-pressed="form.sex === opt.value"
              @click="form.sex = opt.value"
            >
              <IconifyIcon :icon="form.sex === opt.value ? 'lucide:circle-check' : 'lucide:circle'" width="20" />
              {{ opt.label }}
            </button>
          </div>

          <input v-else-if="step === 'dob'" v-model="form.dob" class="cp-input" type="date" :max="adultCutoff" min="1900-01-02" aria-label="Date of birth" />

          <input
            v-else-if="step === 'studentId'"
            v-model="form.studentId"
            class="cp-input"
            placeholder="YY-NNNNN, e.g. 25-01234"
            autocomplete="off"
            aria-label="Student ID"
          />

          <template v-else-if="step === 'emergency'">
            <input v-model="form.emergencyName" class="cp-input" placeholder="Full name" aria-label="Name" />
            <input v-model="form.emergencyRelation" class="cp-input" placeholder="Relationship — parent, guardian…" aria-label="Relationship" />
            <input v-model="form.emergencyPhone" class="cp-input" type="tel" inputmode="tel" placeholder="Mobile number, e.g. 0912 345 6789" aria-label="Phone" />
          </template>
        </div>

        <button class="cp-primary" :disabled="saving || !ready" @click="saveAndNext">
          {{ saving ? 'Saving…' : step === 'photo' ? 'Continue' : 'Save & continue' }}
        </button>
        <button class="cp-skip" :disabled="saving" @click="skip">Skip for now</button>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import AvatarUpload from '@/components/shared/AvatarUpload.vue'
import { supabase, authUser } from '@/utils/supabase'
import { dateOfBirthProblem, isPhMobile, isStudentId, normalizePhPhone } from '@/utils/format'
import { manilaToday } from '@/utils/payments'
import { loadProfileGaps, type ProfileGap, type ProfileGapKey } from '@/utils/profile'
import { useNotify } from '@/utils/notify'

const STEP: Record<ProfileGapKey, { icon: string; title: string; why: string }> = {
  photo: { icon: 'lucide:camera', title: 'Add a profile photo', why: 'Helps people recognise you in messages and applications.' },
  sex: { icon: 'lucide:user-round', title: 'What is your sex?', why: 'Used for how you are addressed in the app, and kept with your OSAS record.' },
  dob: { icon: 'lucide:cake', title: 'When were you born?', why: 'Accommo is for adults only. Only you and OSAS can see this.' },
  studentId: { icon: 'lucide:id-card', title: 'Add your student ID', why: 'The ID ISU issued you. OSAS checks it when verifying your account.' },
  emergency: { icon: 'lucide:phone-forwarded', title: 'Emergency contact', why: 'Someone OSAS or your landlord/landlady can call if something happens.' },
}
const SEX = [
  { value: 'M', label: 'Male' },
  { value: 'F', label: 'Female' },
]

const route = useRoute()
const router = useRouter()
const notify = useNotify()

const isStudent = route.path.startsWith('/student')
const profileRoute = isStudent ? '/student/profile' : '/manager/profile'
const today = manilaToday()
const adultCutoff = `${Number(today.slice(0, 4)) - 18}${today.slice(4)}`

const loading = ref(true)
const saving = ref(false)
const userId = ref('')
const initials = ref('?')
const photoUrl = ref<string | null>(null)
const gaps = ref<ProfileGap[]>([])
const index = ref(0)
// Keyed, so stepping back and skipping the same thing twice still counts it once.
const skippedKeys = ref(new Set<ProfileGapKey>())
const skipped = computed(() => skippedKeys.value.size)
const form = reactive({ sex: '', dob: '', studentId: '', emergencyName: '', emergencyRelation: '', emergencyPhone: '' })

const step = computed<ProfileGapKey | null>(() => gaps.value[index.value]?.key ?? null)
const ready = computed(() => {
  switch (step.value) {
    case 'photo': return !!photoUrl.value
    case 'sex': return !!form.sex
    case 'dob': return !!form.dob
    case 'studentId': return !!form.studentId.trim()
    case 'emergency': return !!form.emergencyName.trim() && !!form.emergencyPhone.trim()
    default: return false
  }
})

onMounted(async () => {
  const { data } = await authUser()
  const user = data?.user
  if (!user) {
    void router.replace('/login')
    return
  }
  userId.value = user.id
  const [list, { data: row }] = await Promise.all([
    loadProfileGaps(user.id, isStudent),
    supabase.from('users').select('initials').eq('id', user.id).maybeSingle(),
  ])
  gaps.value = list
  initials.value = row?.initials || '?'
  loading.value = false
})

/** Returns an error message, or '' once the step is saved. */
async function save(key: ProfileGapKey): Promise<string> {
  if (key === 'photo') return '' // AvatarUpload saved it the moment it was picked.
  if (key === 'sex' || key === 'dob') {
    if (key === 'dob') {
      const problem = dateOfBirthProblem(form.dob, today)
      if (problem) return problem
    }
    const patch = key === 'sex' ? { sex: form.sex } : { date_of_birth: form.dob }
    const { error } = await supabase.from('users').update(patch).eq('id', userId.value)
    return error ? error.message : ''
  }
  if (key === 'studentId') {
    const id = form.studentId.trim()
    if (!isStudentId(id)) return 'Enter your student ID as YY-NNNN, e.g. 25-01234.'
    const { error } = await supabase.from('student_profiles').upsert({ user_id: userId.value, student_id: id }, { onConflict: 'user_id' })
    // student_profiles_student_id_key: someone else already registered it.
    if (error?.code === '23505') return 'That student ID is already registered to another account.'
    return error ? error.message : ''
  }
  if (!isPhMobile(form.emergencyPhone)) return 'That emergency contact number is not a valid mobile number.'
  // Same shape StudentProfilePage writes.
  const contact = {
    name: form.emergencyName.trim(),
    relationship: form.emergencyRelation.trim(),
    phone: normalizePhPhone(form.emergencyPhone),
  }
  const { error } = await supabase
    .from('student_profiles')
    .upsert({ user_id: userId.value, emergency_contact_json: contact }, { onConflict: 'user_id' })
  return error ? error.message : ''
}

async function saveAndNext() {
  if (!step.value) return
  saving.value = true
  try {
    const problem = await save(step.value)
    if (problem) {
      notify.error(problem)
      return
    }
    window.dispatchEvent(new Event('accommo:profile-change'))
    skippedKeys.value.delete(step.value)
    index.value++
  } catch (e) {
    notify.error(e instanceof Error ? e.message : 'Could not save.')
  } finally {
    saving.value = false
  }
}

function skip() {
  if (step.value) skippedKeys.value.add(step.value)
  index.value++
}

function back() {
  if (index.value === 0) void router.replace(profileRoute)
  else index.value--
}
</script>

<style scoped>
.cp {
  padding: 16px var(--m-page-gutter, 16px) 32px;
  background: var(--m-bg);
}
.cp-wrap {
  max-width: 460px;
  margin: 0 auto;
}
.cp-card {
  display: flex;
  flex-direction: column;
  align-items: stretch;
  gap: 12px;
  padding: 18px 18px 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.cp-sk-icon { align-self: center; }
.cp-done { align-items: center; text-align: center; padding-top: 28px; }

.cp-progress { margin-bottom: 6px; }
.cp-progress-row { display: flex; align-items: center; gap: 8px; margin-bottom: 7px; }
.cp-back { width: 44px; height: 44px; margin: -10px 0 -10px -12px; color: var(--m-ink); }
.cp-step { color: var(--m-ink); font-size: 14px; font-weight: 700; }
.cp-track { display: flex; gap: 4px; }
.cp-seg {
  height: 4px;
  flex: 1;
  border-radius: 999px;
  background: var(--m-border);
  transition: flex-grow 0.3s ease, background-color 0.3s ease;
}
.cp-seg.done { background: color-mix(in srgb, var(--m-primary) 55%, transparent); }
.cp-seg.current { flex-grow: 1.6; background: var(--m-primary); }

.cp-icon {
  display: inline-flex;
  align-self: center;
  align-items: center;
  justify-content: center;
  width: 64px;
  height: 64px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.cp-icon--good { background: var(--m-success-soft); color: var(--m-success); }
.cp-title {
  margin: 0;
  font-family: var(--m-font-display);
  font-size: 20px;
  line-height: 1.25;
  font-weight: 700;
  color: var(--m-ink);
  text-align: center;
}
.cp-why { margin: -4px 0 4px; color: var(--m-muted); font-size: 13.5px; line-height: 1.45; text-align: center; }

.cp-body { display: flex; flex-direction: column; gap: 10px; margin-bottom: 4px; }
.cp-photo { display: flex; flex-direction: column; align-items: center; gap: 10px; }
.cp-hint { color: var(--m-muted); font-size: 12.5px; }
.cp-choices { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.cp-choice {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  min-height: 52px;
  border: 1.5px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14.5px;
  font-weight: 700;
  cursor: pointer;
}
.cp-choice.is-on { border-color: var(--m-primary); background: var(--m-primary-soft); color: var(--m-primary-dark); }
.cp-input {
  width: 100%;
  min-height: 46px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background-color: var(--m-bg);
  color: var(--m-ink);
  font: inherit;
  font-size: 15px;
  font-weight: 600;
}
.cp-input:focus { border-color: var(--m-primary); outline: none; }

.cp-primary,
.cp-skip {
  width: 100%;
  min-height: 46px;
  border: 0;
  border-radius: 999px;
  font: inherit;
  font-size: 14.5px;
  font-weight: 700;
  cursor: pointer;
}
.cp-primary { background: var(--m-primary); color: #fff; }
.cp-primary:disabled { opacity: 0.5; cursor: default; }
.cp-skip { min-height: 40px; background: transparent; color: var(--m-muted); }
</style>
