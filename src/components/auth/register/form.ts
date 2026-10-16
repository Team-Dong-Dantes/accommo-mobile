// The form behind every screen: which screens this role sees, the fields and
// their rules, and the draft that survives an app restart.
import { ALLOWED_EMAIL_DOMAINS } from '@/utils/config'
import { NAME_EXT_NONE, STEP_QUESTION, STEP_TITLE, type StepKey } from './model'
import { type QForm } from 'quasar'
import { capitalizeName, dateOfBirthProblem, isPersonName } from '@/utils/format'
import { collegePrograms } from '@/constants/academics'
import { computed, reactive, ref, watch } from 'vue'
import { manilaToday } from '@/utils/payments'
import { useAuthStore } from '@/stores/auth'
import { useNotify } from '@/utils/notify'
import { useRoute, useRouter } from 'vue-router'

export function createRegisterForm() {
  const router = useRouter()
  const route = useRoute()
  const notify = useNotify()
  const authStore = useAuthStore()

  /** The path is the role. Routes are unchanged, so every existing redirect still lands correctly. */
  const isManager = computed(() => route.path.startsWith('/register/manager'))
  const registerPath = computed(() => (isManager.value ? '/register/manager' : '/register'))

  /** "9123456789" → "912 345 6789" for display; form.phoneDigits stays bare digits. */
  const spacedPhone = (d: string) => [d.slice(0, 3), d.slice(3, 6), d.slice(6)].filter(Boolean).join(' ')

  const stepIndex = ref(0)
  const agreedToTerms = ref(false)
  /** Carries "they already consented" across the Google redirect, which wipes local state. */
  const CONSENT_MARKER = 'accommo.register.consent'
  const registerFormRef = ref<QForm | null>(null)
  const stepsEl = ref<HTMLElement | null>(null)
  const isGoogleMode = ref(false)
  const googleUserId = ref('')
  const emailCreated = ref(false)
  const emailVerified = ref(false)
  const creatingAccount = ref(false)
  const showPassword = ref(false)
  const showConfirmPassword = ref(false)
  const loading = ref(false)
  // OSAS sent a landlord/landlady's application back: sign-in is allowed again so it can be
  // corrected, and only the documents step is relevant.
  const isResubmit = ref(false)
  const decisionReason = ref('')

  /** The latest birth date of someone who is 18 today, as yyyy-mm-dd. Only adults may use the app. */
  const today = manilaToday()
  const adultCutoff = `${Number(today.slice(0, 4)) - 18}${today.slice(4)}`

  // The database carries the same bounds (users_date_of_birth_plausible); these
  // exist so the person is told before the request is made, not after it fails.
  const dateOfBirthRules = [(val: string) => dateOfBirthProblem(val, today) ?? true]

  /**
   * Unicode classes rather than A-Z, so Ñoño and Áurea are names rather than
   * errors, and the body allows what Philippine surnames actually contain —
   * "Dela Cruz", "D'Souza", "St. Clair". The messages name the rule, because
   * "Invalid" leaves someone staring at a field with no idea what it wants.
   *
   * Capitalisation is not a rule here: `capitalizeName()` fixes it on blur, so
   * there is nothing to refuse someone over.
   */
  function nameRules(label: string) {
    return [
      (val: string) => !!val?.trim() || `${label} is required`,
      (val: string) => isPersonName(val) || 'Letters, spaces, hyphens and apostrophes only',
    ]
  }

  // Required. Philippine records carry the mother's maiden surname as a middle
  // name almost without exception, and OSAS matches registrations against school
  // records where it is present — so a blank one is far more often a skipped field
  // than a person without one. Case is corrected rather than policed, as with the
  // other name fields.
  const middleInitialRules = [
    (val: string) => !!val || 'Required',
    (val: string) => /^\p{L}$/u.test(val) || 'One letter only',
  ]

  /** Keeps a numeric field numeric while it is being typed into. */
  function digitsOnly(value: string | number | null | undefined, max: number): string {
    return String(value ?? '').replace(/\D/g, '').slice(0, max)
  }

  /** Tidies the case when the field is left, rather than fighting the typing. */
  function tidyName(field: 'firstName' | 'lastName' | 'middleInitial') {
    form[field] = capitalizeName(form[field].trim())
  }
  const emailDomains = [...ALLOWED_EMAIL_DOMAINS]
  const collegeOptions = Object.keys(collegePrograms)

  /**
   * The visible screens, which is all the branching the flow needs. Google already
   * owns the address, so its path skips e-mail and verify — but it still sets a
   * password, so the account can also sign in with e-mail and password. This replaces the old `if (step === 1) step = 4` jumps, and makes the progress
   * count correct for every path without a second rule.
   */
  const steps = computed<StepKey[]>(() => {
    if (isResubmit.value) return ['governmentId', 'businessPermit']
    const head: StepKey[] = isGoogleMode.value
      ? ['name', 'phone', 'password']
      :['name', 'phone', 'email', 'password', 'verify']
    return isManager.value
      ? [...head, 'governmentId', 'businessPermit']
      : [...head, 'studies', 'studentId', 'schoolId', 'assessment']
  })

  const current = computed<StepKey>(() => steps.value[stepIndex.value] ?? 'name')
  const stepTitle = computed(() => STEP_TITLE[current.value])
  const isLastStep = computed(() => stepIndex.value === steps.value.length - 1)

  /** The resubmit screens keep their own wording: a correction, not a sign-up. */
  const question = computed(() => {
    if (isResubmit.value) {
      return {
        title: 'Update your application',
        note: current.value === 'governmentId'
          ? 'Replace your government ID if OSAS asked about it.'
          : 'Replace your permit if OSAS asked about it.',
      }
    }
    if (current.value === 'password' && isGoogleMode.value) {
      return { title: 'Choose a password', note: 'So you can also sign in with your e-mail and password.' }
    }
    return STEP_QUESTION[current.value]
  })

  const nextLabel = computed(() => {
    // The auth account is created on leaving this screen, so the button says so.
    // A Google account already exists; leaving only saves the password onto it.
    if (current.value === 'password') return isGoogleMode.value ? 'Set password' : 'Create account'
    return 'Continue'
  })

  const submitLabel = computed(() => {
    // "Register" overstated it — the auth account already exists by this point
    // (it is created on leaving the Account step); this last press finishes the
    // profile attached to it.
    if (!isGoogleMode.value) return isManager.value ? 'Submit application' : 'Finish signing up'
    return isManager.value ? 'Submit application' : 'Finish profile'
  })

  const form = reactive({
    firstName: '',
    middleInitial: '',
    lastName: '',
    nameExtension: NAME_EXT_NONE,
    fullName: '',
    sex: '',
    dateOfBirth: '',
    phoneDigits: '',
    phone: '',
    emailUser: '',
    emailDomain: ALLOWED_EMAIL_DOMAINS[0] as string,
    email: '',
    password: '',
    confirmPassword: '',
    college: '',
    program: '',
    yearLevel: '',
    studentIdYear: '',
    studentIdNumber: '',
    studentId: '',
    schoolIdFile: null as File | null,
    assessmentFile: null as File | null,
    schoolIdText: null as string | null,
    assessmentText: null as string | null,
    governmentIdFile: null as File | null,
    governmentIdExpiresAt: '',
    businessPermitFile: null as File | null,
    businessPermitExpiresAt: '',
  })

  /**
   * The half-filled registration, kept on the device so a reload, the app being
   * killed, or a dropped connection does not throw it away. One per role, so the
   * student and landlord/landlady forms never fill each other in.
   *
   * Not everything is kept: the password is never written to disk, and the
   * document files cannot be serialised — nor should uploaded IDs sit on the
   * device (see persistCache.ts) — so those two are re-entered. A week-old draft
   * is dropped rather than greeting the next person on a shared phone.
   */
  const DRAFT_TTL_MS = 7 * 24 * 60 * 60 * 1000
  const UNSAVED_FIELDS = [
    'password', 'confirmPassword',
    'schoolIdFile', 'schoolIdText', 'assessmentFile', 'assessmentText',
    'governmentIdFile', 'businessPermitFile',
  ]
  const draftKey = `accommo.register.draft.${isManager.value ? 'manager' : 'student'}`
  type Draft = { savedAt: number; step: StepKey; agreed: boolean; form: Partial<typeof form> };

  function readDraft(): Draft | null {
    try {
      const saved = JSON.parse(localStorage.getItem(draftKey) ?? 'null') as Draft | null
      if (saved && Date.now() - saved.savedAt < DRAFT_TTL_MS) return saved
      localStorage.removeItem(draftKey)
    } catch {
      // Unreadable or blocked storage: start fresh.
    }
    return null
  }

  function saveDraft() {
    // A resubmission edits an existing application, not a sign-up in progress.
    if (isResubmit.value) return
    const fields = Object.fromEntries(Object.entries(form).filter(([key]) => !UNSAVED_FIELDS.includes(key)))
    try {
      localStorage.setItem(draftKey, JSON.stringify({ savedAt: Date.now(), step: current.value, agreed: agreedToTerms.value, form: fields }))
    } catch {
      // Storage full: best effort, the form itself still works.
    }
  }

  function clearDraft() {
    try {
      localStorage.removeItem(draftKey)
    } catch {
      // ignore
    }
  }

  // Fields come back before the first paint; the screen waits for onMounted,
  // which is when it is known whether an account already exists.
  const draft = readDraft()
  if (draft) {
    Object.assign(form, draft.form)
    agreedToTerms.value = draft.agreed
  }
  watch([form, agreedToTerms, current], saveDraft, { deep: true })

  const filteredPrograms = computed(() => {
    if (!form.college) return []
    return collegePrograms[form.college] || []
  })

  function onCollegeChange(_val: string | number | null | undefined) {
    form.program = ''
  }

  // `short` is what the chips show; `label` stays for the rule messages, which
  // still need to read as sentences when validation fails.
  const passwordChecks = computed(() => {
    const pwd = form.password
    return [
      { label: 'At least 8 characters', short: '8+ characters', ok: pwd.length >= 8 },
      { label: 'One lowercase letter', short: 'a–z', ok: /[a-z]/.test(pwd) },
      { label: 'One uppercase letter', short: 'A–Z', ok: /[A-Z]/.test(pwd) },
      { label: 'One number', short: '0–9', ok: /\d/.test(pwd) },
      { label: 'One special character (!@#$%^&*)', short: '!@#$%^&*', ok: /[!@#$%^&*]/.test(pwd) },
    ]
  })

  function splitFullName(name: string) {
    const parts = name.trim().split(/\s+/).filter(Boolean)
    return {
      firstName: parts[0] ?? '',
      lastName: parts.slice(1).join(' '),
    }
  }

  /**
   * The four inputs become the one `full_name` the database actually stores —
   * "Juan D. Dela Cruz Jr." There are no first/middle/last columns anywhere, and
   * the profile screen edits this same string as free text later, so composing
   * here keeps one canonical spelling of a person's name.
   */
  function syncFullName() {
    // Capitalised here as well as on blur: blur is what the person sees happen,
    // but it does not always fire before a submit on a touch screen, and the
    // stored name should not depend on which.
    const first = capitalizeName(form.firstName.trim())
    const last = capitalizeName(form.lastName.trim())
    const middle = form.middleInitial ? `${capitalizeName(form.middleInitial)}.` : ''
    const extension = form.nameExtension === NAME_EXT_NONE ? '' : form.nameExtension
    form.fullName = [first, middle, last, extension].join(' ').trim().replace(/\s+/g, ' ')
  }

  return {
    router,
    route,
    notify,
    authStore,
    isManager,
    registerPath,
    spacedPhone,
    stepIndex,
    agreedToTerms,
    CONSENT_MARKER,
    registerFormRef,
    stepsEl,
    isGoogleMode,
    googleUserId,
    emailCreated,
    emailVerified,
    creatingAccount,
    showPassword,
    showConfirmPassword,
    loading,
    isResubmit,
    decisionReason,
    today,
    adultCutoff,
    dateOfBirthRules,
    nameRules,
    middleInitialRules,
    digitsOnly,
    tidyName,
    emailDomains,
    collegeOptions,
    steps,
    current,
    stepTitle,
    isLastStep,
    question,
    nextLabel,
    submitLabel,
    form,
    DRAFT_TTL_MS,
    UNSAVED_FIELDS,
    draftKey,
    readDraft,
    saveDraft,
    clearDraft,
    draft,
    filteredPrograms,
    onCollegeChange,
    passwordChecks,
    splitFullName,
    syncFullName,
  }
}
