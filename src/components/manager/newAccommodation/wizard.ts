// The wizard: which step, the form, its photos and permits, what blocks moving
// on, and saving it as a draft or submitting it to OSAS.
import { type AmenityKey, DOC_TYPES } from './model'
import { type UploadedPermit, expiryProblem, uploadPermitFile } from '@/utils/permits'
import { authUser, supabase } from '@/utils/supabase'
import { capturePhoto } from '@/utils/camera'
import { computed, reactive, ref } from 'vue'
import { errorMessage } from '@/utils/errors'
import { manilaToday } from '@/utils/payments'
import { to12Hour } from '@/utils/format'
import { uploadDocument } from '@/utils/upload'
import { useNotify } from '@/utils/notify'
import { useRouter } from 'vue-router'

export function createWizard() {
  const router = useRouter()
  const notify = useNotify()

  const step = ref(1)
  // The desktop step list's names, in order.
  const STEP_LABELS = ['Details', 'Amenities', 'House rules', 'Exterior photos', 'Permits', 'Review'] as const
  const submitting = ref(false)
  const uploadingPhotos = ref(false)
  const photos = ref<{ url: string }[]>([])
  const permits = reactive<Record<string, UploadedPermit>>({})
  const permitExpiry = reactive<Record<string, string>>({})
  const today = manilaToday()
  const uploadingPermit = ref('')

  const attachedPermits = computed(() => DOC_TYPES.filter((d) => permits[d.key]).length)
  const permitsComplete = computed(() => attachedPermits.value === DOC_TYPES.length)

  /** What's still missing on the current step, or '' when it's complete. Every
   * step has to be satisfied before moving on — OSAS can't review a listing
   * that's missing its type, location, photos or permits, so there's no point
   * letting one reach the review step half-filled. Shown to the user rather
   * than only disabling Next, which otherwise gives no clue what's wrong. */
  const blockReason = computed(() => {
    if (step.value === 1) {
      if (!form.name.trim()) return 'Give your accommodation a name.'
      if (!form.accommodationType) return 'Choose what type of place this is.'
      if (!form.genderPolicy) return 'Choose who this place accepts.'
      if (form.lat === null || form.lng === null) return 'Set the location on the map.'
      // Normally filled by the map pick, but a reverse-geocode can come back
      // empty, so they still have to be confirmed rather than silently blank.
      if (!form.barangay.trim()) return 'Add the barangay.'
      if (!form.city.trim()) return 'Add the city or municipality.'
    }
    if (step.value === 3) {
      if (!form.curfewTime) return 'Set a curfew time.'
      if (!form.quietFrom || !form.quietTo) return 'Set both ends of quiet hours.'
      if (!form.visitorPolicy.trim()) return 'Describe your visitor policy.'
    }
    if (step.value === 4 && !photos.value.length) return 'Add at least one exterior photo.'
    if (step.value === 5 && !permitsComplete.value) {
      return `Attach all ${DOC_TYPES.length} permits (${attachedPermits.value} so far).`
    }
    if (step.value === 5) {
      for (const d of DOC_TYPES) {
        const problem = expiryProblem(permitExpiry[d.key] ?? '')
        if (problem) return `${d.label}: ${problem}`
      }
    }
    return ''
  })
  const nextBlocked = computed(() => blockReason.value !== '')

  const form = reactive({
    name: '',
    accommodationType: '',
    genderPolicy: '',
    purok: '',
    barangay: '',
    city: '',
    description: '',
    lat: null as number | null,
    lng: null as number | null,
    amenities: [] as string[],
    // Times come from DateTimeField's time mode, so they're always "HH:MM" (24h)
    // here and get formatted for storage — the columns are free text and the
    // handful of existing rows disagree with each other ("10:00PM" vs
    // "10:00 PM", "10PM - 6AM"), so the picker is what makes them consistent.
    curfewTime: '',
    quietFrom: '',
    quietTo: '',
    visitorPolicy: '',
    cooking: true,
    laundry: true,
    pets: false,
  })

  const quietHoursLabel = computed(() =>
    form.quietFrom && form.quietTo ? `${to12Hour(form.quietFrom)} – ${to12Hour(form.quietTo)}` : '',
  )

  const locationPickerOpen = ref(false)
  const locationSummary = computed(
    () => [form.purok.trim(), form.barangay.trim(), form.city.trim()].filter(Boolean).join(', ') || (form.lat != null ? 'Pinned on map' : '—'),
  )

  // The map is the source of truth here, so a fresh pick overwrites the two
  // fields rather than only filling blanks — otherwise correcting a wrong pin
  // leaves the old barangay/city stranded next to the new coordinates.
  function onLocationConfirmed(payload: { lat: number; lng: number; barangay: string; city: string }) {
    form.lat = payload.lat
    form.lng = payload.lng
    if (payload.barangay) form.barangay = payload.barangay
    if (payload.city) form.city = payload.city
  }

  function toggle(list: string[], value: string) {
    const i = list.indexOf(value)
    if (i === -1) list.push(value)
    else list.splice(i, 1)
  }

  async function addExteriorPhotos(files: File[]) {
    if (!files.length) return
    uploadingPhotos.value = true
    try {
      for (const file of files) {
        const url = await uploadDocument(file, '', 'accommodation_photo')
        photos.value.push({ url })
      }
    } catch (e) {
      notify.error(errorMessage(e, 'Could not upload one of your photos.'))
    } finally {
      uploadingPhotos.value = false
    }
  }

  async function onPhotosSelected(event: Event) {
    const input = event.target as HTMLInputElement
    const files = Array.from(input.files ?? [])
    input.value = ''
    await addExteriorPhotos(files)
  }

  async function takeExteriorPhoto() {
    const { file, error } = await capturePhoto()
    if (error) notify.error(error)
    if (file) await addExteriorPhotos([file])
  }

  async function takePermitPhoto(docType: string) {
    const { file, error } = await capturePhoto()
    if (error) notify.error(error)
    if (file) await uploadPermit(file, docType)
  }

  async function uploadPermit(file: File, docType: string) {
    uploadingPermit.value = docType
    try {
      // Checked for legibility, shrunk, hashed, then uploaded with authenticated
      // delivery (signed on read). See utils/permits.ts.
      permits[docType] = await uploadPermitFile(file)
    } catch (e) {
      notify.error(errorMessage(e, 'Could not upload that permit.'))
    } finally {
      uploadingPermit.value = ''
    }
  }

  async function onPermitSelected(event: Event, docType: string) {
    const input = event.target as HTMLInputElement
    const file = input.files?.[0]
    input.value = ''
    if (file) await uploadPermit(file, docType)
  }

  /**
   * Every listing is created as a draft. Submitting is the same save followed by
   * submit_accommodation(), which re-checks completeness on the server — so a
   * failed submit still leaves the work saved, as a draft, instead of lost.
   */
  async function submit(asDraft = false) {
    if (submitting.value) return
    if (!asDraft) {
      // Walk back to the first incomplete step rather than only checking the
      // last one — the nav gates each step, but this stays correct if that slips.
      for (let s = 1; s < STEP_LABELS.length; s++) {
        step.value = s
        if (blockReason.value) {
          notify.error(blockReason.value)
          return
        }
      }
      step.value = STEP_LABELS.length
    }
    submitting.value = true
    try {
      const { data: authData } = await authUser()
      const user = authData?.user
      if (!user) throw new Error('Not logged in.')

      const { data: accommodation, error: insertError } = await supabase
        .from('accommodations')
        .insert({
          landlord_id: user.id,
          name: form.name.trim(),
          accommodation_type: form.accommodationType || null,
          gender_policy: form.genderPolicy || null,
          // No address field any more — the student side already falls back to
          // "Purok, Barangay, City" when this is null.
          address: null,
          purok: form.purok.trim() || null,
          barangay: form.barangay.trim() || null,
          city: form.city.trim() || null,
          description: form.description.trim() || null,
          lat: form.lat,
          lng: form.lng,
          status: 'draft',
        })
        .select('id')
        .single()
      if (insertError) throw insertError
      const accommodationId = accommodation.id

      if (form.amenities.length) {
        const { error: amenityError } = await supabase
          .from('accommodation_amenities')
          .insert(form.amenities.map((amenity) => ({ accommodation_id: accommodationId, amenity: amenity as AmenityKey })))
        if (amenityError) throw amenityError
      }

      const { error: policyError } = await supabase.from('accommodation_policies').insert({
        accommodation_id: accommodationId,
        curfew_time: to12Hour(form.curfewTime) || null,
        quiet_hours: quietHoursLabel.value || null,
        visitor_policy: form.visitorPolicy.trim() || null,
        cooking: form.cooking,
        laundry: form.laundry,
        pets: form.pets,
      })
      if (policyError) throw policyError

      if (photos.value.length) {
        const { error: imagesError } = await supabase
          .from('accommodation_images')
          .insert(photos.value.map((p, i) => ({ accommodation_id: accommodationId, url: p.url, sort_order: i })))
        if (imagesError) throw imagesError
      }

      const docEntries = Object.entries(permits)
      if (docEntries.length) {
        const { error: docsError } = await supabase
          .from('accommodation_documents')
          .insert(docEntries.map(([doc_type, permit]) => ({
            accommodation_id: accommodationId,
            doc_type,
            file_url: permit.ref,
            file_sha256: permit.sha256,
            expires_at: permitExpiry[doc_type] || null,
          })))
        if (docsError) throw docsError
      }

      if (asDraft) {
        notify.success('Draft saved. Submit it to OSAS when it’s complete — rooms are added once it’s accredited.')
      } else {
        const { error: submitError } = await supabase.rpc('submit_accommodation', { p_id: accommodationId })
        if (submitError) notify.error(`Saved as a draft, but not submitted: ${submitError.message}`)
        else notify.success('Submitted — it now awaits OSAS review.')
      }
      void router.replace(`/manager/properties/${accommodationId}`)
    } catch (e) {
      notify.error(errorMessage(e, 'Could not create this accommodation.'))
    } finally {
      submitting.value = false
    }
  }

  return {
    router,
    notify,
    step,
    STEP_LABELS,
    submitting,
    uploadingPhotos,
    photos,
    permits,
    permitExpiry,
    today,
    uploadingPermit,
    attachedPermits,
    permitsComplete,
    blockReason,
    nextBlocked,
    form,
    quietHoursLabel,
    locationPickerOpen,
    locationSummary,
    onLocationConfirmed,
    toggle,
    addExteriorPhotos,
    onPhotosSelected,
    takeExteriorPhoto,
    takePermitPhoto,
    uploadPermit,
    onPermitSelected,
    submit,
  }
}
