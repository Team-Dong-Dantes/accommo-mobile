// The student's own profile: loading it, editing and saving the fields they
// may change, their documents and current stay.
import { DOC_LABEL, ago, docPresentation, memberSince, profileGaps, statusPresentation } from '@/utils/profile'
import { type DocRow, type Stay } from './model'
import { authUser, supabase } from '@/utils/supabase'
import { capitalizeName, initialsOf, isPersonName, isPhMobile, isStudentId, normalizePhPhone } from '@/utils/format'
import { collegePrograms, yearLevelFromLabel, yearLevelToLabel } from '@/constants/academics'
import { computed, onMounted, onUnmounted, reactive, ref } from 'vue'
import { fetchCurrentLease } from '@/api/leases'
import { isDesktop } from '@/utils/useTabletMode'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { useLiveData } from '@/utils/useLiveData'
import { useMyLandlordTitle } from '@/utils/myLandlordTitle'
import { useNotify } from '@/utils/notify'
import { useRouter } from 'vue-router'

export function createStudentProfile() {
  const router = useRouter()
  const notify = useNotify()

  const loading = ref(true)
  const saving = ref(false)
  const error = ref('')
  const editing = ref(false)

  const userId = ref('')
  const avatarUrl = ref<string | null>(null)
  const coverUrl = ref<string | null>(null)

  const me = reactive({
    fullName: '',
    email: '',
    phone: '',
    initials: '?',
    status: 'unverified',
    sex: '',
    dob: '',
  })
  const academics = reactive({
    studentId: '',
    college: '',
    program: '',
    yearLevel: '',
  })
  const emergency = reactive({
    name: '',
    relation: '',
    phone: '',
  })

  const draft = reactive({
    fullName: '',
    phone: '',
    email: '',
    studentId: '',
    college: '',
    program: '',
    yearLevel: '',
    emergencyName: '',
    emergencyRelation: '',
    emergencyPhone: '',
  })

  const createdAt = ref<string | null>(null)
  const updatedAt = ref<string | null>(null)
  const stay = ref<Stay | null>(null)
  const myLandlord = useMyLandlordTitle()
  const documents = ref<DocRow[]>([])

  const status = computed(() => statusPresentation(me.status))
  const gaps = computed(() =>
    profileGaps(
      {
        avatar_url: avatarUrl.value,
        sex: me.sex,
        date_of_birth: me.dob,
        student_id: academics.studentId,
        emergency_contact_json: { name: emergency.name, phone: emergency.phone },
      },
      true,
    ),
  )
  const stayStatusNote = computed(() => {
    if (stay.value?.status === 'pending') return `Application pending — awaiting your ${myLandlord.value}'s decision`
    if (stay.value?.status === 'leave_requested') return `Leave requested — awaiting your ${myLandlord.value}'s decision`
    return ''
  })
  const memberSinceLabel = computed(() => memberSince(createdAt.value))
  const pendingDocs = computed(() => documents.value.filter(d => d.tone === 'warn').length)
  // Desktop shows one section at a time, picked from the left-half menu.
  const tab = ref('ps-details')
  const shows = (id: string) => !isDesktop.value || tab.value === id
  const sections = computed(() => [
    { id: 'ps-details', label: 'Your details', icon: 'lucide:user' },
    { id: 'ps-academics', label: 'Academics', icon: 'lucide:graduation-cap' },
    { id: 'ps-emergency', label: 'Emergency contact', icon: 'lucide:phone-forwarded' },
    { id: 'ps-verification', label: 'Verification', icon: 'lucide:shield-check', badge: pendingDocs.value ? `${pendingDocs.value} pending` : '' },
    { id: 'ps-settings', label: 'Settings', icon: 'lucide:settings' },
  ])

  const courseLine = computed(() => {
    const parts = [academics.program, yearLevelToLabel(Number(academics.yearLevel) || null)].filter(Boolean)
    return parts.length ? parts.join(' · ') : 'Student'
  })

  const programOptions = computed(() => collegePrograms[draft.college] ?? [])

  function onCollegeChange(next: string) {
    draft.college = next
    if (!(collegePrograms[next] ?? []).includes(draft.program)) draft.program = ''
  }

  function go(path: string) {
    void router.push(path)
  }

  function startEdit() {
    Object.assign(draft, {
      fullName: me.fullName,
      phone: me.phone,
      email: me.email,
      studentId: academics.studentId,
      college: academics.college,
      program: academics.program,
      yearLevel: academics.yearLevel,
      emergencyName: emergency.name,
      emergencyRelation: emergency.relation,
      emergencyPhone: emergency.phone,
    })
    editing.value = true
  }

  function cancelEdit() {
    editing.value = false
  }

  async function save() {
    // Held to the register screen's rule, and its case fixed the same way, so
    // a name refused at sign-up cannot come back in from here.
    const name = capitalizeName(draft.fullName.trim().replace(/\s+/g, ' '))
    if (!name) {
      notify.error('Your name cannot be empty.')
      return
    }
    if (!isPersonName(name)) {
      notify.error('Use letters, spaces, hyphens and apostrophes only in your name.')
      return
    }
    if (!name.includes(' ')) {
      notify.error('Enter your first and last name.')
      return
    }
    // Checked here as well as at registration: normalizePhPhone turns an empty
    // field into the string "+63" and the column is NOT NULL, so without this the
    // register screen's validation was undone by one visit to this page.
    if (!isPhMobile(draft.phone)) {
      notify.error('Enter a valid mobile number, e.g. 0912 345 6789.')
      return
    }
    // The emergency contact is optional, so it is only judged once filled in.
    if (draft.emergencyPhone.trim() && !isPhMobile(draft.emergencyPhone)) {
      notify.error('That emergency contact number is not a valid mobile number.')
      return
    }
    // Only sent when it is being filled in for the first time, so an ordinary
    // save never touches a column the DB may have locked after verification.
    const newStudentId = academics.studentId ? '' : draft.studentId.trim()
    if (newStudentId && !isStudentId(newStudentId)) {
      notify.error('Enter your student ID as YY-NNNN, e.g. 25-01234.')
      return
    }

    saving.value = true
    try {
      const phone = normalizePhPhone(draft.phone)
      const initials = initialsOf(name)

      const { error: userError } = await supabase
        .from('users')
        .update({ full_name: name, phone, initials })
        .eq('id', userId.value)
      if (userError) throw userError

      const contact = {
        name: draft.emergencyName.trim(),
        relationship: draft.emergencyRelation.trim(),
        phone: draft.emergencyPhone.trim() ? normalizePhPhone(draft.emergencyPhone) : '',
      }
      const hasContact = Boolean(contact.name || contact.relationship || contact.phone)

      const { error: profileError } = await supabase.from('student_profiles').upsert(
        {
          user_id: userId.value,
          college: draft.college || null,
          program: draft.program || null,
          year_level: draft.yearLevel ? yearLevelFromLabel(draft.yearLevel) : null,
          emergency_contact_json: hasContact ? contact : null,
          ...(newStudentId ? { student_id: newStudentId } : {}),
        },
        { onConflict: 'user_id' },
      )
      // student_profiles_student_id_key: someone else already registered it.
      if (profileError?.code === '23505') throw new Error('That student ID is already registered to another account.')
      if (profileError) throw profileError

      me.fullName = name
      me.phone = phone
      me.initials = initials
      if (newStudentId) academics.studentId = newStudentId
      academics.college = draft.college
      academics.program = draft.program
      academics.yearLevel = draft.yearLevel
      emergency.name = contact.name
      emergency.relation = contact.relationship
      emergency.phone = contact.phone
      updatedAt.value = new Date().toISOString()

      editing.value = false
      notify.success('Profile updated.')
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Could not save.')
    } finally {
      saving.value = false
    }
  }

  async function load(silent = false) {
    if (!silent) loading.value = true
    error.value = ''
    try {
      const { data: auth } = await authUser()
      const user = auth?.user
      if (!user) {
        void router.push('/login')
        return
      }
      userId.value = user.id

      const [{ data: profile, error: profileError }, { data: studentProfile }] = await Promise.all([
        supabase
          .from('users_full')
          .select('full_name, email, phone, initials, status, sex, date_of_birth, created_at, updated_at, avatar_url, cover_url')
          .eq('id', user.id)
          .maybeSingle(),
        supabase
          .from('student_profiles')
          .select('student_id, college, program, year_level, emergency_contact_json')
          .eq('user_id', user.id)
          .maybeSingle(),
      ])
      if (profileError) throw profileError

      me.fullName = profile?.full_name || 'Your name'
      me.email = profile?.email || user.email || ''
      me.phone = profile?.phone || ''
      me.initials = profile?.initials || initialsOf(me.fullName)
      me.status = profile?.status || 'unverified'
      me.sex = profile?.sex || ''
      me.dob = profile?.date_of_birth || ''
      createdAt.value = profile?.created_at ?? null
      updatedAt.value = profile?.updated_at ?? null

      const metadata = user.user_metadata as Record<string, unknown> | undefined
      const picture =
        typeof metadata?.avatar_url === 'string'
          ? metadata.avatar_url
          : typeof metadata?.picture === 'string'
            ? metadata.picture
            : ''
      // users.avatar_url is the fallback, not just a mirror: this session's
      // cached metadata can be stale or empty (an avatar uploaded on another
      // device, or set straight in the database), and reading metadata alone
      // left the profile stuck on initials even though a photo existed.
      const storedAvatar = (profile as { avatar_url?: string | null } | null)?.avatar_url || ''
      avatarUrl.value = resolveAsset(picture || storedAvatar) || null
      coverUrl.value = profile?.cover_url ?? null

      academics.studentId = studentProfile?.student_id || ''
      academics.college = studentProfile?.college || ''
      academics.program = studentProfile?.program || ''
      academics.yearLevel = yearLevelToLabel(studentProfile?.year_level)

      const contact = (studentProfile?.emergency_contact_json ?? null) as {
        name?: string
        relationship?: string
        phone?: string
      } | null
      emergency.name = contact?.name || ''
      emergency.relation = contact?.relationship || ''
      emergency.phone = contact?.phone || ''

      // Never clobber an in-progress edit with a silent (realtime-triggered)
      // background refresh — only the real first load seeds the draft.
      if (!silent) {
        Object.assign(draft, {
          fullName: me.fullName,
          phone: me.phone,
          email: me.email,
          studentId: academics.studentId,
          college: academics.college,
          program: academics.program,
          yearLevel: academics.yearLevel,
          emergencyName: emergency.name,
          emergencyRelation: emergency.relation,
          emergencyPhone: emergency.phone,
        })
      }

      // includePending: this screen shows the student where they stand, so an
      // undecided application counts as their current placement.
      const leaseRow = await fetchCurrentLease(user.id, true)

      if (leaseRow) {
        const room = leaseRow.rooms as unknown as {
          room_number: string | null
          accommodations: { name: string } | null
        } | null
        stay.value = {
          leaseId: leaseRow.id,
          managerId: leaseRow.landlord_id,
          accommodationName: room?.accommodations?.name || 'Your accommodation',
          roomNumber: room?.room_number ?? null,
          status: leaseRow.status as Stay['status'],
        }
      }

      const { data: docs } = await supabase
        .from('verification_documents')
        .select('id, doc_type, status, uploaded_at, verified_at')
        .eq('user_id', user.id)
        .order('uploaded_at', { ascending: false })

      documents.value = (docs || []).map((d) => {
        const presentation = docPresentation(d.status)
        return {
          id: d.id,
          label: DOC_LABEL[d.doc_type || ''] || 'Document',
          statusLabel: presentation.label,
          tone: presentation.tone,
          icon: presentation.icon,
          when: d.verified_at ? `Reviewed ${ago(d.verified_at)}` : `Sent ${ago(d.uploaded_at)}`,
        }
      })
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Something went wrong.'
    } finally {
      loading.value = false
    }
  }

  // Kept alive across tab switches (see MainLayout's KEEP_ALIVE_PAGES), so an
  // OSAS verification decision pushes here instead of the page re-asking on
  // return. utils/useLiveData.ts owns the whole policy — first load, the
  // subscription's lifetime, and how stale the data may be on return.
  // Kept alive, so a step saved in Complete your profile has to tell this page.
  const onProfileChange = () => void load(true)
  onMounted(() => window.addEventListener('accommo:profile-change', onProfileChange))
  onUnmounted(() => window.removeEventListener('accommo:profile-change', onProfileChange))

  useLiveData({
    key: 'student-profile',
    load,
    watch: (uid) => [{ table: 'verification_documents', filter: `user_id=eq.${uid}` }],
  })

  return {
    router,
    notify,
    loading,
    saving,
    error,
    editing,
    userId,
    avatarUrl,
    coverUrl,
    me,
    academics,
    emergency,
    draft,
    createdAt,
    updatedAt,
    stay,
    myLandlord,
    documents,
    status,
    gaps,
    stayStatusNote,
    memberSinceLabel,
    pendingDocs,
    tab,
    shows,
    sections,
    courseLine,
    programOptions,
    onCollegeChange,
    go,
    startEdit,
    cancelEdit,
    save,
    load,
    onProfileChange,
  }
}
