// The compose form: the draft, who it reaches, what is still missing, the
// photo, and handing the finished draft to the page.
import { type AnnouncementDraft } from './model'
import { type Seed } from './model'
import { capturePhoto } from '@/utils/camera'
import { computed, reactive, ref, watch } from 'vue'
import { errorMessage } from '@/utils/errors'
import { manilaToday } from '@/utils/payments'
import { supabase } from '@/utils/supabase'
import { uploadDocument, whenLoaded } from '@/utils/upload'
import { CARD, resolveAsset } from '@/utils/cloudinaryUrl'
import { useNotify } from '@/utils/notify'

export function createAnnouncementCompose(ctx: Seed) {
  const { props, emit } = ctx
  const notify = useNotify()

  const form = reactive<AnnouncementDraft>({
    accommodationIds: props.accommodations[0]?.id ? [props.accommodations[0].id] : [],
    title: '',
    summary: '',
    body: '',
    eventAt: '',
    eventEnd: '',
    location: '',
    deadlineAt: '',
    imageUrl: '',
    publishAt: '',
    expiresAt: '',
  })

  /** Nothing can be scheduled into the past; the picker greys out earlier days. */
  const today = manilaToday()

  const detailsOpen = ref(false)
  const uploading = ref(false)
  /** The picked photo, shown from the device while it uploads. */
  const imagePreview = ref('')
  const confirmDiscard = ref(false)
  const fileInput = ref<HTMLInputElement | null>(null)
  const tenantCount = ref<number | null>(null)

  function toggleHouse(id: string) {
    const at = form.accommodationIds.indexOf(id)
    if (at === -1) form.accommodationIds.push(id)
    else form.accommodationIds.splice(at, 1)
  }

  /** The honest version of "who am I about to interrupt". */
  async function countTenants() {
    if (!form.accommodationIds.length) {
      tenantCount.value = 0
      return
    }
    tenantCount.value = null
    // head + exact count: the number is all that is wanted, so no rows cross the
    // wire to be counted client-side.
    const { count } = await supabase
      .from('leases')
      .select('id, rooms!inner(accommodation_id)', { count: 'exact', head: true })
      .eq('status', 'active')
      .in('rooms.accommodation_id', form.accommodationIds)
    tenantCount.value = count ?? 0
  }

  watch(() => [...form.accommodationIds], countTenants, { immediate: true })

  const reachText = computed(() => {
    if (!form.accommodationIds.length) return 'Pick at least one house.'
    if (tenantCount.value === null) return 'Counting boarders…'
    const who = `${tenantCount.value} ${tenantCount.value === 1 ? 'boarder' : 'boarders'}`
    return form.accommodationIds.length === 1
      ? `${who} will get this`
      : `${who} across ${form.accommodationIds.length} houses will get this`
  })

  const detailsSummary = computed(() => {
    const set = [
      form.eventAt && 'when',
      form.location && 'where',
      form.deadlineAt && 'respond by',
    ].filter(Boolean)
    return set.length ? set.join(' · ') : 'When, where, respond by'
  })

  function readable(local: string): string {
    const d = new Date(local)
    return Number.isNaN(d.getTime())
      ? ''
      : d.toLocaleString([], { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })
  }

  const factLine = computed(() => {
    const parts: string[] = []
    if (form.eventAt) {
      parts.push(form.eventEnd ? `${readable(form.eventAt)} – ${readable(form.eventEnd)}` : readable(form.eventAt))
    }
    if (form.location.trim()) parts.push(form.location.trim())
    return parts.join(' · ')
  })

  /**
   * Everything the database would accept but nobody meant: an end before its
   * start, a send time in the past (the cron would fire it on its next pass and
   * "scheduled" would be a lie), an expiry before the notice is even out.
   */
  const problems = computed(() => {
    const out: string[] = []
    const at = (v: string) => (v ? new Date(v).getTime() : null)
    const start = at(form.eventAt)
    const end = at(form.eventEnd)
    const send = at(form.publishAt)
    const due = at(form.deadlineAt)
    const now = Date.now()

    if (start && end && end <= start) out.push('“Until” is before it starts.')
    if (send && send <= now) out.push('That send time has already passed.')
    if (due && due <= now) out.push('“Respond by” has already passed.')
    if (form.expiresAt) {
      const hides = new Date(`${form.expiresAt}T23:59:59`).getTime()
      if (hides <= (send ?? now)) out.push('It would be hidden before it is sent.')
      if (due && hides < due) out.push('It hides before the respond-by date.')
    }
    return out
  })

  /** The one thing still missing, so a greyed-out Send is never a mystery. */
  const footNote = computed(() => {
    if (props.submitting) return ""
    if (!form.accommodationIds.length) return "Pick a house"
    if (!form.title.trim()) return "Needs a title"
    if (!form.body.trim()) return "Needs a notice"
    if (problems.value.length) return "Fix the dates above"
    if (form.publishAt) return `Goes out ${readable(form.publishAt)}`
    return tenantCount.value === null ? "" : `Goes out now to ${tenantCount.value}`
  })

  const canSend = computed(
    () =>
      form.accommodationIds.length > 0 &&
      Boolean(form.title.trim()) &&
      Boolean(form.body.trim()) &&
      problems.value.length === 0 &&
      !uploading.value &&
      !props.submitting,
  )

  const dirty = computed(() =>
    Boolean(form.title || form.summary || form.body || form.eventAt || form.location || form.imageUrl),
  )

  function tryClose() {
    if (dirty.value) confirmDiscard.value = true
    else emit('close')
  }

  /** Default a scheduled send to the next whole hour, not to "now". */
  function scheduleSoon() {
    if (form.publishAt) return
    const d = new Date(Date.now() + 60 * 60 * 1000)
    d.setMinutes(0, 0, 0)
    const pad = (n: number) => String(n).padStart(2, '0')
    form.publishAt = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
  }

  async function fromCamera() {
    const { file, error } = await capturePhoto()
    if (error) notify.error(error)
    if (file) await upload(file)
  }

  function pickFile() {
    fileInput.value?.click()
  }

  async function onFilePicked(e: Event) {
    const file = (e.target as HTMLInputElement).files?.[0]
    ;(e.target as HTMLInputElement).value = ''
    if (file) await upload(file)
  }

  async function upload(file: File) {
    uploading.value = true
    const local = URL.createObjectURL(file)
    imagePreview.value = local
    try {
      const url = await uploadDocument(file, '', 'announcement')
      // Swap only once the uploaded copy is loaded, so the photo never goes blank.
      await whenLoaded(resolveAsset(url, CARD))
      form.imageUrl = url
    } catch (e) {
      notify.error(errorMessage(e, 'Could not upload that photo.'))
    } finally {
      uploading.value = false
      imagePreview.value = ''
      URL.revokeObjectURL(local)
    }
  }

  function submit() {
    if (!canSend.value) return
    emit('submit', { ...form, accommodationIds: [...form.accommodationIds] })
  }

  return {
    notify,
    form,
    today,
    detailsOpen,
    uploading,
    imagePreview,
    confirmDiscard,
    fileInput,
    tenantCount,
    toggleHouse,
    countTenants,
    reachText,
    detailsSummary,
    readable,
    factLine,
    problems,
    footNote,
    canSend,
    dirty,
    tryClose,
    scheduleSoon,
    fromCamera,
    pickFile,
    onFilePicked,
    upload,
    submit,
  }
}
