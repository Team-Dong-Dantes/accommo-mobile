// One listing's accreditation: its rounds with OSAS, what was flagged, and
// resubmitting, appealing, renewing or withdrawing a change.
import { BUILDING_TYPE_LABEL, GENDER_POLICY_LABEL } from '@/utils/listings'
import { CHANGE_LABEL, type Round } from './model'
import { type Seed } from './model'
import { computed, onMounted, ref, watch } from 'vue'
import { errorMessage } from '@/utils/errors'
import { parseServerTime } from '@/utils/format'
import { supabase } from '@/utils/supabase'
import { useNotify } from '@/utils/notify'
import { useRouter } from 'vue-router'

export function createAccreditation(ctx: Seed) {
  const { props, emit } = ctx
  const router = useRouter()
  const notify = useNotify()
  const rounds = ref<Round[]>([])
  const waitDays = ref<number | null>(null)
  const message = ref('')
  const busy = ref(false)
  const replaceOpen = ref(false)
  const replaceType = ref('')

  const expiresAt = computed(() => props.accreditationExpiresAt)
  const daysLeft = computed(() => {
    if (!expiresAt.value) return null
    return Math.ceil((new Date(expiresAt.value).getTime() - Date.now()) / 86_400_000)
  })
  const openRound = computed(() => rounds.value.find((r) => !r.decided_at) ?? null)
  const history = computed(() => rounds.value.filter((r) => r.decided_at))
  const lastDecided = computed(() => history.value[0] ?? null)
  const lastReturned = computed(() => history.value.find((r) => r.decision === 'returned') ?? null)
  const canAppeal = computed(() => !props.appealUsed && lastDecided.value?.kind !== 'appeal')

  const flagged = computed(() => {
    const r = lastReturned.value
    if (!r?.decided_at) return []
    const decidedAt = parseServerTime(r.decided_at).getTime()
    return (r.flagged_docs ?? []).map((type) => {
      const doc = props.docs.find((d) => d.doc_type === type)
      return { type, replaced: Boolean(doc && parseServerTime(doc.uploaded_at).getTime() > decidedAt) }
    })
  })
  const unreplacedCount = computed(() => flagged.value.filter((f) => !f.replaced).length)
  const allReplaced = computed(() => unreplacedCount.value === 0)

  const waitLine = computed(() =>
    waitDays.value === null ? '' : `OSAS usually replies within ${Math.max(1, Math.ceil(waitDays.value))} day${Math.ceil(waitDays.value) <= 1 ? '' : 's'}.`,
  )

  const changeRows = computed(() => {
    const changes = openRound.value?.proposed_changes ?? {}
    const rows: { label: string; to: string }[] = []
    for (const [key, value] of Object.entries(changes)) {
      if (key === 'lng' && 'lat' in changes) continue
      const to =
        key === 'accommodation_type' ? BUILDING_TYPE_LABEL[String(value) as keyof typeof BUILDING_TYPE_LABEL] ?? String(value)
          : key === 'gender_policy' ? GENDER_POLICY_LABEL[String(value) as keyof typeof GENDER_POLICY_LABEL] ?? String(value)
            : key === 'lat' || key === 'lng' ? 'Moved'
              : String(value)
      rows.push({ label: CHANGE_LABEL[key] ?? key, to })
    }
    return rows
  })

  function longDate(iso: string) {
    return parseServerTime(iso).toLocaleDateString('en-PH', { month: 'long', day: 'numeric', year: 'numeric' })
  }

  async function load() {
    const [{ data, error }, { data: wait }] = await Promise.all([
      supabase
        .from('accreditation_rounds')
        .select('id, round, kind, submitted_at, message, proposed_changes, decided_at, decision, flagged_docs, tags, note')
        .eq('accommodation_id', props.accommodationId)
        .order('round', { ascending: false }),
      supabase.rpc('accreditation_wait_estimate'),
    ])
    if (error) {
      notify.error(errorMessage(error, 'Could not load the review history.'))
      return
    }
    rounds.value = (data ?? []) as Round[]
    waitDays.value = typeof wait === 'number' ? wait : null
  }

  /** Runs one of the database's accreditation functions, then reloads. */
  async function run(fn: () => PromiseLike<{ error: unknown }>, done: string): Promise<boolean> {
    if (busy.value) return false
    busy.value = true
    try {
      const { error } = await fn()
      if (error) throw error
      message.value = ''
      notify.success(done)
      await load()
      emit('changed')
      return true
    } catch (e) {
      notify.error(errorMessage(e, 'That did not go through.'))
      return false
    } finally {
      busy.value = false
    }
  }

  function resubmit() {
    return run(
      () => supabase.rpc('resubmit_accommodation', {
        p_id: props.accommodationId,
        ...(message.value.trim() ? { p_message: message.value.trim() } : {}),
      }),
      'Resubmitted — OSAS will review it again.',
    )
  }
  function appeal() {
    return run(
      () => supabase.rpc('appeal_accommodation', { p_id: props.accommodationId, p_message: message.value.trim() }),
      'Appeal sent to OSAS.',
    )
  }
  function renew() {
    return run(
      () => supabase.rpc('request_renewal', { p_id: props.accommodationId }),
      'Renewal sent to OSAS.',
    )
  }
  function withdrawChange() {
    return run(
      () => supabase.rpc('withdraw_details_change', { p_id: props.accommodationId }),
      'Change withdrawn.',
    )
  }

  function openReplace(type: string) {
    replaceType.value = type
    replaceOpen.value = true
  }
  function onPermitSaved() {
    permitReplaced()
    emit('docs-changed')
  }

  // A permit saved while sent back — from this card or the parent's Permits list.
  // `docs` only catches up once the parent reloads them, so the check waits for that.
  const resubmitPromptOpen = ref(false)
  let checkAfterDocs = false
  function permitReplaced() {
    if (props.status === 'needs_revision') checkAfterDocs = true
  }
  watch(() => props.docs, () => {
    if (!checkAfterDocs) return
    checkAfterDocs = false
    if (props.status === 'needs_revision' && allReplaced.value) resubmitPromptOpen.value = true
  })
  async function resubmitFromPrompt() {
    if (await resubmit()) resubmitPromptOpen.value = false
  }

  onMounted(load)
  // The status moves under this card (resubmit, renew, OSAS deciding), and with
  // it the rounds; a change request is submitted from the parent's editor.
  watch(() => props.status, () => void load())

  return {
    router,
    notify,
    rounds,
    waitDays,
    message,
    busy,
    replaceOpen,
    replaceType,
    expiresAt,
    daysLeft,
    openRound,
    history,
    lastDecided,
    lastReturned,
    canAppeal,
    flagged,
    unreplacedCount,
    allReplaced,
    waitLine,
    changeRows,
    longDate,
    load,
    run,
    resubmit,
    appeal,
    renew,
    withdrawChange,
    openReplace,
    onPermitSaved,
    resubmitPromptOpen,
    checkAfterDocs,
    permitReplaced,
    resubmitFromPrompt,
  }
}
