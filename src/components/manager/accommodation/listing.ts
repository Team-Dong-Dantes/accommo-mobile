// Everything on the Overview and Settings panels that writes back: one field
// at a time, amenities, house-rule toggles, the map pin, the cover photos, the
// draft's submit/delete, delisting, and the permit sheet.
import { ref } from 'vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { requirePin } from '@/utils/requirePin'
import { to12Hour, to24Hour, splitTimeRange } from '@/utils/format'
import { addPhotosLive } from '@/utils/upload'
import type { Database } from '@/types/database.gen'
import { FIELD_META, isLeaseRestrictError, type AmenityKey, type FieldKey } from './model'
import type { Detail } from './detail'

export function createListing(core: Detail) {
  const { id, acc, rules, rooms, images, notify, router, fieldReview, requestChange } = core
  const savingAmenities = ref(false)
  const delisting = ref(false)
  const amenitiesDialogOpen = ref(false)
  const fieldDialogOpen = ref(false)
  const savingField = ref(false)
  const editingField = ref<FieldKey | null>(null)
  const fieldDraft = ref('')
  // Second half of a time range (quiet hours "until"); unused by other types.
  const fieldDraftTo = ref('')
  const uploadingCover = ref(false)
  const deletingImage = ref('')
  const coverSheetOpen = ref(false)

  const submittingDraft = ref(false)
  async function submitDraft() {
    if (submittingDraft.value) return
    submittingDraft.value = true
    try {
      const { error: submitError } = await supabase.rpc('submit_accommodation', { p_id: id })
      if (submitError) throw submitError
      acc.status = 'pending'
      notify.success('Submitted — it now awaits OSAS review.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not submit this accommodation.'))
    } finally {
      submittingDraft.value = false
    }
  }

  const locationPickerOpen = ref(false)

  // The picker no longer guesses a street address — barangay and city are what
  // it fills. Address stays editable on its own row here.
  async function onLocationConfirmed(payload: { lat: number; lng: number; barangay: string; city: string }) {
    const fields: Database['public']['Tables']['accommodations']['Update'] = { lat: payload.lat, lng: payload.lng }
    if (!acc.barangay && payload.barangay) fields.barangay = payload.barangay
    if (!acc.city && payload.city) fields.city = payload.city
    const review = fieldReview('barangay')
    if (review === 'locked') {
      notify.error('The location can’t change while OSAS is reviewing the listing or it is not accredited.')
      return
    }
    if (review === 'request') {
      await requestChange(fields as Record<string, unknown>)
      return
    }
    try {
      const { error: updateError } = await supabase.from('accommodations').update(fields).eq('id', id)
      if (updateError) throw updateError
      acc.lat = payload.lat
      acc.lng = payload.lng
      if (fields.barangay) acc.barangay = fields.barangay as string
      if (fields.city) acc.city = fields.city as string
      notify.success('Location saved.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not save this location.'))
    }
  }

  /** Cosmetic extension check — good enough to pick "image preview" vs "open file". */

  const docPreviewOpen = ref(false)
  const docPreviewUrl = ref('')
  function viewDoc(url: string) {
    docPreviewUrl.value = url
    docPreviewOpen.value = true
  }

  function toggle(list: string[], value: string) {
    const i = list.indexOf(value)
    if (i === -1) list.push(value)
    else list.splice(i, 1)
  }

  async function saveAmenities() {
    savingAmenities.value = true
    try {
      await supabase.from('accommodation_amenities').delete().eq('accommodation_id', id)
      if (rules.amenities.length) {
        const { error: amenityError } = await supabase
          .from('accommodation_amenities')
          .insert(rules.amenities.map((amenity) => ({ accommodation_id: id, amenity: amenity as AmenityKey })))
        if (amenityError) throw amenityError
      }
      amenitiesDialogOpen.value = false
      notify.success('Saved.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not save your changes.'))
    } finally {
      savingAmenities.value = false
    }
  }

  async function saveToggle(key: 'cooking' | 'laundry' | 'pets') {
    try {
      const payload = { accommodation_id: id, [key]: rules[key] } as Database['public']['Tables']['accommodation_policies']['Insert']
      const { error: updateError } = await supabase
        .from('accommodation_policies')
        .upsert(payload, { onConflict: 'accommodation_id' })
      if (updateError) throw updateError
    } catch (e) {
      notify.error(errorMessage(e, 'Could not save this setting.'))
    }
  }

  const permitSheetOpen = ref(false)
  const permitSheetType = ref('')
  function openPermitSheet(type: string) {
    permitSheetType.value = type
    permitSheetOpen.value = true
  }

  function openFieldDialog(key: FieldKey) {
    editingField.value = key
    const meta = FIELD_META[key]
    const raw = key in acc ? acc[key as keyof typeof acc] : rules[key as keyof typeof rules]
    fieldDraftTo.value = ''
    if (meta.type === 'time') {
      // Seed the picker from whatever's stored, including older hand-typed
      // values like "10PM"; anything unparseable just starts blank.
      fieldDraft.value = to24Hour(String(raw ?? ''))
    } else if (meta.type === 'timerange') {
      const [from, to] = splitTimeRange(String(raw ?? ''))
      fieldDraft.value = from
      fieldDraftTo.value = to
    } else {
      fieldDraft.value = String(raw ?? '')
    }
    fieldDialogOpen.value = true
  }

  async function saveField() {
    const key = editingField.value
    if (!key) return
    const meta = FIELD_META[key]
    savingField.value = true
    try {
      let value: string | null
      if (meta.type === 'select') value = fieldDraft.value || null
      else if (meta.type === 'time') value = to12Hour(fieldDraft.value) || null
      else if (meta.type === 'timerange') {
        value =
          fieldDraft.value && fieldDraftTo.value
            ? `${to12Hour(fieldDraft.value)} – ${to12Hour(fieldDraftTo.value)}`
            : null
      } else value = fieldDraft.value.trim() || null

      const review = fieldReview(key)
      if (review === 'locked') return
      if (review === 'request') {
        if (await requestChange({ [meta.column]: value })) fieldDialogOpen.value = false
        return
      }

      if (meta.table === 'accommodations') {
        const payload = { [meta.column]: value } as Database['public']['Tables']['accommodations']['Update']
        const { error: updateError } = await supabase.from('accommodations').update(payload).eq('id', id)
        if (updateError) throw updateError
      } else {
        const payload = { accommodation_id: id, [meta.column]: value } as Database['public']['Tables']['accommodation_policies']['Insert']
        const { error: updateError } = await supabase
          .from('accommodation_policies')
          .upsert(payload, { onConflict: 'accommodation_id' })
        if (updateError) throw updateError
      }

      switch (key) {
        case 'name': acc.name = String(value ?? ''); break
        case 'accommodationType': acc.accommodationType = String(value ?? ''); break
        case 'genderPolicy': acc.genderPolicy = String(value ?? ''); break
        case 'purok': acc.purok = String(value ?? ''); break
        case 'barangay': acc.barangay = String(value ?? ''); break
        case 'city': acc.city = String(value ?? ''); break
        case 'description': acc.description = String(value ?? ''); break
        case 'curfewTime': rules.curfewTime = String(value ?? ''); break
        case 'quietHours': rules.quietHours = String(value ?? ''); break
        case 'visitorPolicy': rules.visitorPolicy = String(value ?? ''); break
      }

      fieldDialogOpen.value = false
      notify.success('Saved.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not save your changes.'))
    } finally {
      savingField.value = false
    }
  }

  async function delistAccommodation() {
    if (delisting.value) return
    delisting.value = true
    try {
      const { error: updateError } = await supabase.from('accommodations').update({ status: 'delisted' }).eq('id', id)
      if (updateError) throw updateError
      acc.status = 'delisted'
      notify.success('Accommodation delisted.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not delist this accommodation.'))
    } finally {
      delisting.value = false
    }
  }

  async function reactivateAccommodation() {
    if (delisting.value) return
    delisting.value = true
    try {
      const { error: updateError } = await supabase.from('accommodations').update({ status: 'accredited' }).eq('id', id)
      if (updateError) throw updateError
      acc.status = 'accredited'
      notify.success('Accommodation reactivated.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not reactivate this accommodation.'))
    } finally {
      delisting.value = false
    }
  }

  const confirmDeleteAccommodationOpen = ref(false)
  const deletingAccommodation = ref(false)

  async function deleteAccommodation() {
    if (deletingAccommodation.value) return
    if (!(await requirePin({ title: 'Delete this accommodation?' }))) return
    deletingAccommodation.value = true
    try {
      const roomIds = rooms.value.map((r) => r.id)
      if (roomIds.length) {
        const { count, error: countError } = await supabase
          .from('leases')
          .select('id', { count: 'exact', head: true })
          .in('room_id', roomIds)
        if (countError) throw countError
        if (count) {
          notify.error('This accommodation has rooms with lease history and can\'t be deleted.')
          return
        }
      }

      const { data: deleted, error: deleteError } = await supabase
        .from('accommodations')
        .delete()
        .eq('id', id)
        .select('id')
      if (deleteError) throw deleteError
      if (!deleted?.length) {
        notify.error('Could not remove this accommodation.')
        return
      }

      notify.success('Accommodation removed.')
      void router.replace('/manager/properties')
    } catch (e) {
      notify.error(
        isLeaseRestrictError(e)
          ? 'This accommodation has rooms with lease history and can\'t be deleted.'
          : errorMessage(e, 'Could not remove this accommodation.'),
      )
    } finally {
      deletingAccommodation.value = false
      confirmDeleteAccommodationOpen.value = false
    }
  }

  async function onCoverPhotosSelected(event: Event) {
    const input = event.target as HTMLInputElement
    const files = Array.from(input.files ?? [])
    if (!files.length) return
    uploadingCover.value = true
    try {
      const list = images.value
      await addPhotosLive(list, files, async (url) => {
        const { data: created, error: insertError } = await supabase
          .from('accommodation_images')
          .insert({ accommodation_id: id, url, sort_order: list.filter((i) => !i.pending).length })
          .select('id,url')
          .single()
        if (insertError) throw insertError
        return { id: created.id, url: created.url }
      })
    } catch (e) {
      notify.error(errorMessage(e, 'Could not upload one of your photos.'))
    } finally {
      uploadingCover.value = false
      input.value = ''
    }
  }

  async function deleteImage(imageId: string) {
    if (deletingImage.value) return
    deletingImage.value = imageId
    try {
      const { error: deleteError } = await supabase.from('accommodation_images').delete().eq('id', imageId)
      if (deleteError) throw deleteError
      images.value = images.value.filter((i) => i.id !== imageId)
    } catch (e) {
      notify.error(errorMessage(e, 'Could not remove this photo.'))
    } finally {
      deletingImage.value = ''
    }
  }

  return {
    savingAmenities, delisting, amenitiesDialogOpen, fieldDialogOpen, savingField, editingField, fieldDraft, fieldDraftTo,
    uploadingCover, deletingImage, coverSheetOpen, submittingDraft, submitDraft, locationPickerOpen, onLocationConfirmed,
    docPreviewOpen, docPreviewUrl, viewDoc, toggle, saveAmenities, saveToggle, permitSheetOpen, permitSheetType,
    openPermitSheet, openFieldDialog, saveField, delistAccommodation, reactivateAccommodation,
    confirmDeleteAccommodationOpen, deletingAccommodation, deleteAccommodation, onCoverPhotosSelected, deleteImage,
  }
}
