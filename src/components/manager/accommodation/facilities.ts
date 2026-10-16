// Facilities: the shared ones on a floor and the private ones in a room, each
// added through the same two-step sheet as a room, plus the floor's
// "Add room or facility" choice.
import { computed, reactive, ref } from 'vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { uploadDocument } from '@/utils/upload'
import { FACILITY_META, PRIVATE_ONLY_FACILITY_TYPES, RETIRED_FACILITY_TYPES } from '@/utils/listings'
import { capturePhoto } from '@/utils/camera'
import type { Facility, FacilityStatus } from './model'
import type { Detail } from './detail'
import type { createRooms } from './rooms'

export function createFacilities(core: Detail, roomEditor: ReturnType<typeof createRooms>) {
  const { id, facilities, notify } = core
  const { openRoomDialog } = roomEditor
  // Adding a facility follows the same shape as adding a room: a paged sheet
  // (Basics → Photos) that creates the row after step 1, then a Photos step
  // that operates on the now-real facility — kept as its own dialog since a
  // facility isn't a room, but built to look and behave the same way.
  const facilityOpen = ref(false)
  const facilityDialogMode = ref<'create' | 'edit'>('create')
  const facilityViewMode = ref<'view' | 'edit'>('view')
  const facilityStep = ref(1)
  const savingFacility = ref(false)
  const facilityScope = ref<'shared' | 'private'>('shared')
  const facilityRoomId = ref('')
  const facilityFloor = ref<number | null>(null)
  const activeFacilityId = ref('')
  const facilityForm = reactive({
    facilityType: 'bathroom',
    label: '',
    description: '',
    status: 'available' as FacilityStatus,
    roomIds: [] as string[],
  })

  // Air-con and the like belong to a room; the shared picker leaves them out.
  // Retired types (parking, now an amenity) are offered by neither.
  const facilityTypeOptions = computed(() =>
    Object.fromEntries(
      Object.entries(FACILITY_META)
        .filter(([k]) => !RETIRED_FACILITY_TYPES.includes(k) && (facilityScope.value !== 'shared' || !PRIVATE_ONLY_FACILITY_TYPES.includes(k)))
        .map(([k, meta]) => [k, meta.label]),
    ),
  )
  /** Replaces a facility's room links with `after`, touching only what changed. */
  async function syncFacilityRooms(facilityId: string, before: string[], after: string[]) {
    const removed = before.filter((r) => !after.includes(r))
    const added = after.filter((r) => !before.includes(r))
    if (removed.length) {
      const { error: e } = await supabase.from('accommodation_facility_rooms').delete().eq('facility_id', facilityId).in('room_id', removed)
      if (e) throw e
    }
    if (added.length) {
      const { error: e } = await supabase.from('accommodation_facility_rooms').insert(added.map((room_id) => ({ facility_id: facilityId, room_id })))
      if (e) throw e
    }
  }
  const activeFacilityImages = computed(() => facilities.value.find((f) => f.id === activeFacilityId.value)?.images ?? [])

  const addChoiceOpen = ref(false)
  const addChoiceFloor = ref<number | null>(null)

  function openAddChoice(floor: number) {
    addChoiceFloor.value = floor
    addChoiceOpen.value = true
  }
  function chooseAddRoom() {
    addChoiceOpen.value = false
    if (addChoiceFloor.value !== null) openRoomDialog(null, addChoiceFloor.value)
  }
  function chooseAddFacility() {
    addChoiceOpen.value = false
    if (addChoiceFloor.value !== null) openFacilityAddDialog('shared', '', addChoiceFloor.value)
  }

  function openFacilityAddDialog(scope: 'shared' | 'private', roomId: string, floor: number | null = null) {
    facilityDialogMode.value = 'create'
    facilityStep.value = 1
    facilityScope.value = scope
    facilityRoomId.value = roomId
    facilityFloor.value = floor
    activeFacilityId.value = ''
    facilityForm.facilityType = 'bathroom'
    facilityForm.label = ''
    facilityForm.description = ''
    facilityForm.status = 'available'
    facilityForm.roomIds = []
    facilityOpen.value = true
  }

  function openFacilityDetails(f: Facility) {
    facilityDialogMode.value = 'edit'
    facilityViewMode.value = 'view'
    facilityScope.value = f.roomId ? 'private' : 'shared'
    facilityRoomId.value = f.roomId || ''
    facilityFloor.value = f.floor
    activeFacilityId.value = f.id
    facilityForm.facilityType = f.facilityType
    facilityForm.label = f.label
    facilityForm.description = f.description
    facilityForm.status = f.status
    facilityForm.roomIds = [...f.roomIds]
    facilityOpen.value = true
  }

  async function saveFacilityEdits() {
    if (savingFacility.value || !activeFacilityId.value) return
    savingFacility.value = true
    try {
      const payload = {
        facility_type: facilityForm.facilityType,
        label: facilityForm.label.trim() || null,
        description: facilityForm.description.trim() || null,
        status: facilityForm.status,
      }
      const { error: updateError } = await supabase
        .from('accommodation_facilities')
        .update(payload)
        .eq('id', activeFacilityId.value)
      if (updateError) throw updateError
      const row = facilities.value.find((f) => f.id === activeFacilityId.value)
      if (row && !row.roomId) await syncFacilityRooms(row.id, row.roomIds, facilityForm.roomIds)
      if (row) Object.assign(row, { facilityType: payload.facility_type, label: payload.label || '', description: payload.description || '', status: payload.status, roomIds: row.roomId ? [] : [...facilityForm.roomIds] })
      facilityOpen.value = false
      notify.success('Facility saved.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not save this facility.'))
    } finally {
      savingFacility.value = false
    }
  }

  async function deleteFacilityDirect() {
    if (savingFacility.value || !activeFacilityId.value) return
    savingFacility.value = true
    try {
      const { error: deleteError } = await supabase.from('accommodation_facilities').delete().eq('id', activeFacilityId.value)
      if (deleteError) throw deleteError
      facilities.value = facilities.value.filter((f) => f.id !== activeFacilityId.value)
      facilityOpen.value = false
      notify.success('Facility removed.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not remove this facility.'))
    } finally {
      savingFacility.value = false
    }
  }

  async function confirmFacilityBasics() {
    if (savingFacility.value) return
    savingFacility.value = true
    try {
      const payload = {
        facility_type: facilityForm.facilityType,
        access_scope: facilityScope.value,
        label: facilityForm.label.trim() || null,
        description: facilityForm.description.trim() || null,
        room_id: facilityScope.value === 'private' ? facilityRoomId.value : null,
        floor: facilityScope.value === 'shared' ? facilityFloor.value : null,
        status: facilityForm.status,
      }
      const { data: created, error: insertError } = await supabase
        .from('accommodation_facilities')
        .insert({ ...payload, accommodation_id: id, sort_order: facilities.value.length })
        .select('id')
        .single()
      if (insertError) throw insertError
      const roomIds = facilityScope.value === 'shared' ? [...facilityForm.roomIds] : []
      await syncFacilityRooms(created.id, [], roomIds)
      facilities.value.push({
        id: created.id,
        facilityType: payload.facility_type,
        label: payload.label || '',
        description: payload.description || '',
        roomId: payload.room_id,
        floor: payload.floor,
        status: payload.status,
        roomIds,
        images: [],
      })
      activeFacilityId.value = created.id
      facilityStep.value = 2
    } catch (e) {
      notify.error(errorMessage(e, 'Could not save this facility.'))
    } finally {
      savingFacility.value = false
    }
  }

  const deletingFacilityImageId = ref('')

  async function deleteFacilityPhotoInDialog(imageId: string) {
    if (deletingFacilityImageId.value) return
    deletingFacilityImageId.value = imageId
    try {
      const { error: deleteError } = await supabase.from('accommodation_facility_images').delete().eq('id', imageId)
      if (deleteError) throw deleteError
      const row = facilities.value.find((f) => f.id === activeFacilityId.value)
      if (row) row.images = row.images.filter((i) => i.id !== imageId)
    } catch (e) {
      notify.error(errorMessage(e, 'Could not remove this photo.'))
    } finally {
      deletingFacilityImageId.value = ''
    }
  }

  const uploadingFacilityId = ref('')

  async function addFacilityPhotos(files: File[], facilityId: string) {
    if (!files.length) return
    uploadingFacilityId.value = facilityId
    try {
      const row = facilities.value.find((f) => f.id === facilityId)
      for (const file of files) {
        const url = await uploadDocument(file, '', 'facility_photo')
        const { data: created, error: insertError } = await supabase
          .from('accommodation_facility_images')
          .insert({ facility_id: facilityId, url, sort_order: row?.images.length ?? 0 })
          .select('id,url')
          .single()
        if (insertError) throw insertError
        row?.images.push({ id: created.id, url: created.url })
      }
    } catch (e) {
      notify.error(errorMessage(e, "Could not upload this facility's photo."))
    } finally {
      uploadingFacilityId.value = ''
    }
  }

  async function uploadFacilityPhoto(event: Event, facilityId: string) {
    const input = event.target as HTMLInputElement
    const files = Array.from(input.files ?? [])
    await addFacilityPhotos(files, facilityId)
    input.value = ''
  }

  async function takeFacilityPhoto(facilityId: string) {
    const { file, error } = await capturePhoto()
    if (error) notify.error(error)
    if (file) await addFacilityPhotos([file], facilityId)
  }

  return {
    facilityOpen, facilityDialogMode, facilityViewMode, facilityStep, savingFacility, facilityScope, facilityForm,
    activeFacilityId, facilityTypeOptions, activeFacilityImages, addChoiceOpen, addChoiceFloor, openAddChoice,
    chooseAddRoom, chooseAddFacility, openFacilityAddDialog, openFacilityDetails, saveFacilityEdits,
    deleteFacilityDirect, confirmFacilityBasics, deletingFacilityImageId, deleteFacilityPhotoInDialog,
    uploadingFacilityId, uploadFacilityPhoto, takeFacilityPhoto,
  }
}
