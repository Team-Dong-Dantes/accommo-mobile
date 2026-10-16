// The landlord/landlady's own profile: loading it, editing and saving the
// fields they may change, and their documents.
import { AVATAR, resolveAsset } from '@/utils/cloudinaryUrl'
import { DOC_LABEL, ago, docPresentation, memberSince, profileGaps, statusPresentation } from '@/utils/profile'
import { type DocRow } from './model'
import { authUser, supabase } from '@/utils/supabase'
import { capitalizeName, initialsOf, isPersonName, isPhMobile, normalizePhPhone } from '@/utils/format'
import { computed, onMounted, onUnmounted, reactive, ref } from 'vue'
import { isDesktop } from '@/utils/useTabletMode'
import { useAuthStore } from '@/stores/auth'
import { useLiveData } from '@/utils/useLiveData'
import { useNotify } from '@/utils/notify'
import { useRouter } from 'vue-router'

export function createManagerProfile() {
  // ----- Router & notifications -----
  const router = useRouter()
  const auth = useAuthStore()
  const notify = useNotify()

  // ----- Reactive State -----
  const loading = ref(true)
  const saving = ref(false)
  const error = ref('')
  const editing = ref(false)

  const userId = ref('')
  const avatarUrl = ref<string | null>(null)
  const coverUrl = ref<string | null>(null)

  // User data – must be defined before render
  const me = reactive({
    fullName: '',
    email: '',
    phone: '',
    initials: '?',
    status: 'unverified',
    // Drives the Landlord / Landlady title on this header. Null is normal — the
    // column is optional — and falls back to the neutral compound.
    sex: null as string | null,
    dob: '',
  })
  const gaps = computed(() => profileGaps({ avatar_url: avatarUrl.value, sex: me.sex, date_of_birth: me.dob }, false))

  // Draft for editing
  const draft = reactive({
    fullName: '',
    phone: '',
    email: '',
  })

  const createdAt = ref<string | null>(null)
  const updatedAt = ref<string | null>(null)
  const responseRate = ref<number | null>(null)
  const accommodationCount = ref(0)
  const tenantCount = ref(0)
  const documents = ref<DocRow[]>([])

  // ----- Computed -----
  const status = computed(() => statusPresentation(me.status))
  const memberSinceLabel = computed(() => memberSince(createdAt.value))
  const pendingDocs = computed(() => documents.value.filter(d => d.tone === 'warn').length)
  // Desktop shows one section at a time, picked from the left-half menu.
  const tab = ref('ps-details')
  const shows = (id: string) => !isDesktop.value || tab.value === id
  const sections = computed(() => [
    { id: 'ps-details', label: 'Personal details', icon: 'lucide:user' },
    { id: 'ps-verification', label: 'Verification', icon: 'lucide:shield-check', badge: pendingDocs.value ? `${pendingDocs.value} pending` : '' },
    { id: 'ps-accommodations', label: 'Accommodations', icon: 'lucide:building-2' },
    { id: 'ps-settings', label: 'Settings', icon: 'lucide:settings' },
  ])

  // ----- Methods -----
  function go(path: string) {
    void router.push(path)
  }

  function startEdit() {
    draft.fullName = me.fullName
    draft.phone = me.phone
    draft.email = me.email
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

    saving.value = true
    try {
      const phone = normalizePhPhone(draft.phone)
      const initials = initialsOf(name)
      const { error: updateError } = await supabase
        .from('users')
        .update({ full_name: name, phone, initials })
        .eq('id', userId.value)
      if (updateError) throw updateError

      me.fullName = name
      me.phone = phone
      me.initials = initials
      updatedAt.value = new Date().toISOString()
      editing.value = false
      notify.success('Profile updated.')
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Could not save.')
    } finally {
      saving.value = false
    }
  }

  // ----- Load Data -----
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

      const [{ data: profile, error: profileError }, { data: managerProfile }] = await Promise.all([
        supabase
          .from('users_full')
          .select('full_name, email, phone, initials, status, sex, date_of_birth, created_at, updated_at, avatar_url, cover_url')
          .eq('id', user.id)
          .maybeSingle(),
        supabase
          .from('landlord_profiles')
          .select('response_rate')
          .eq('user_id', user.id)
          .maybeSingle(),
      ])
      if (profileError) throw profileError

      me.fullName = profile?.full_name || 'Your name'
      me.email = profile?.email || user.email || ''
      me.phone = profile?.phone || ''
      me.initials = profile?.initials || initialsOf(me.fullName)
      me.status = profile?.status || 'unverified'
      me.sex = profile?.sex ?? null
      me.dob = profile?.date_of_birth || ''
      createdAt.value = profile?.created_at ?? null
      updatedAt.value = profile?.updated_at ?? null

      // Avatar from metadata, falling back to the stored column — this
      // session's metadata can be stale or empty (uploaded on another device,
      // or written straight to the database).
      const metadata = user.user_metadata as Record<string, unknown> | undefined
      const picture =
        typeof metadata?.avatar_url === 'string'
          ? metadata.avatar_url
          : typeof metadata?.picture === 'string'
            ? metadata.picture
            : ''
      const storedAvatar = (profile as { avatar_url?: string | null } | null)?.avatar_url || ''
      avatarUrl.value = resolveAsset(picture || storedAvatar, AVATAR) || null
      coverUrl.value = profile?.cover_url ?? null
      responseRate.value = managerProfile?.response_rate ?? null

      // Never clobber an in-progress edit with a silent (realtime-triggered)
      // background refresh — only the real first load seeds the draft.
      if (!silent) Object.assign(draft, { fullName: me.fullName, phone: me.phone, email: me.email })

      // Accommodations count
      const { data: accommodations } = await supabase
        .from('accommodations')
        .select('id')
        .eq('landlord_id', user.id)
      const accommodationIds = (accommodations || []).map((a) => a.id)
      accommodationCount.value = accommodationIds.length

      // Tenant count
      if (accommodationIds.length) {
        const { data: rooms } = await supabase
          .from('rooms')
          .select('id')
          .in('accommodation_id', accommodationIds)
        const roomIds = (rooms || []).map((r) => r.id)
        if (roomIds.length) {
          const { count } = await supabase
            .from('leases')
            .select('*', { count: 'exact', head: true })
            .in('room_id', roomIds)
            .eq('status', 'active')
          tenantCount.value = count ?? 0
        }
      }

      // Verification documents
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
    key: 'manager-profile',
    load,
    watch: (uid) => [{ table: 'verification_documents', filter: `user_id=eq.${uid}` }],
  })

  return {
    router,
    auth,
    notify,
    loading,
    saving,
    error,
    editing,
    userId,
    avatarUrl,
    coverUrl,
    me,
    gaps,
    draft,
    createdAt,
    updatedAt,
    responseRate,
    accommodationCount,
    tenantCount,
    documents,
    status,
    memberSinceLabel,
    pendingDocs,
    tab,
    shows,
    sections,
    go,
    startEdit,
    cancelEdit,
    save,
    load,
    onProfileChange,
  }
}
