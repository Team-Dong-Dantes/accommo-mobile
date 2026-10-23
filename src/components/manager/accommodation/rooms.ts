// The room dialog: the four-step add wizard, the view/edit sheet of an
// existing room, its photos, duplicating, and deleting.
import { computed, reactive, ref } from 'vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { formatPeso } from '@/utils/format'
import { addPhotosLive } from '@/utils/upload'
import { resolveAsset, CARD } from '@/utils/cloudinaryUrl'
import { emptyUtilities, utilitiesFromRow, utilityColumns, utilitiesProblem, type UtilityColumns, ROOM_TYPE_DEFAULT_CAPACITY } from '@/utils/listings'
import { capturePhoto } from '@/utils/camera'
import { requirePin } from '@/utils/requirePin'
import {
  CAPACITY_MAX, MONTHS_MAX, RENT_MAX,
  clampNum, clampOptional, partitionFacilities,
  nextRoomNumber as nextRoomNumberOf, sameRoomNumber,
} from '@/utils/roomInventory'
import type { Img, Room } from './model'
import type { Detail } from './detail'
import type { createFloors } from './floors'

// Rooms added in one go. Ceiling keeps a typo (60 for 6) from flooding a floor.
export const BULK_MAX = 20

export type RoomPayload = UtilityColumns & {
  room_number: string
  room_type: string
  custom_room_type: string | null
  floor: number | null
  capacity: number
  monthly_rent: number
  advance_months: number | null
  deposit_months: number | null
  rent_basis: 'room' | 'person'
}

export function roomFromPayload(
  payload: RoomPayload,
  created: { id: string; current_pax: number | null; status: string; room_number: string | null },
  images: Img[] = [],
): Room {
  return {
    id: created.id,
    label: null,
    roomNumber: created.room_number ?? payload.room_number,
    roomType: payload.room_type,
    customRoomType: payload.custom_room_type,
    floor: payload.floor,
    capacity: payload.capacity,
    currentPax: created.current_pax ?? 0,
    monthlyRent: payload.monthly_rent,
    advanceMonths: payload.advance_months,
    depositMonths: payload.deposit_months,
    rentBasis: payload.rent_basis,
    utilities: utilitiesFromRow(payload),
    status: created.status,
    images,
    photoUrl: images[0]?.url ? resolveAsset(images[0].url, CARD) : '',
  }
}

export function createRooms(core: Detail, floors: ReturnType<typeof createFloors>) {
  const { id, rooms, facilities, trackedFloors, roomsByFloor, nextRoomNumber, nextFloorNumber, notify } = core
  const { addFloor } = floors
  const currentRoomFacilities = computed(() => partitionFacilities(facilities.value, editingRoomId.value).privateToRoom)

  const roomOpen = ref(false)
  const confirmDeleteRoomOpen = ref(false)
  const roomDialogMode = ref<'create' | 'edit'>('create')
  const roomViewMode = ref<'view' | 'edit'>('view')
  const roomStep = ref(1)
  const savingRoom = ref(false)
  const editingRoomId = ref('')
  const activeRoomNumber = ref('')
  const activeRoomStatus = ref<'available' | 'occupied' | 'maintenance'>('available')
  const togglingRoomStatus = ref(false)
  const roomImages = ref<Img[]>([])
  const uploadingRoomPhoto = ref(false)
  const deletingRoomImage = ref('')
  const roomForm = reactive({
    roomNumber: '',
    /** Create only: how many identical rooms to add at once. */
    count: 1,
    roomType: 'solo',
    customRoomType: '',
    floor: null as number | null,
    capacity: 1,
    monthlyRent: 0,
    advanceMonths: null as number | null,
    depositMonths: null as number | null,
    rentBasis: 'room' as 'room' | 'person',
    utilities: emptyUtilities(),
  })

  // Bounds for the room form. A boarding-house room is not ₱1,000,000/month and
  // does not sleep 400 people — an extra keystroke used to save either without a
  // word, and the absurd figure then showed up in discovery and on the student's
  // application summary.

  /**
   * `max` on <input type="number"> is only a spinner and validity hint — a typed
   * or pasted value ignores it completely — so the ceiling has to be applied in
   * script. Done on blur (so the correction is visible while editing) and again in
   * the save payload, which is the path every write actually takes.
   */

  const rentBasisHint = computed(() => {
    const rent = roomForm.monthlyRent || 0
    const cap = roomForm.capacity || 1
    if (cap <= 1) return ''
    return roomForm.rentBasis === 'person'
      ? `≈ ${formatPeso(rent * cap)}/mo total for the room`
      : `≈ ${formatPeso(rent / cap)}/mo per person`
  })

  const previewRoomNumber = computed(() => nextRoomNumber(roomForm.floor))
  const activeRoomTenants = computed(() => rooms.value.find((r) => r.id === editingRoomId.value)?.currentPax ?? 0)

  /** The floors a room can go on: every floor shown on the Rooms tab. */
  const floorOptions = computed(() => {
    const floors = roomsByFloor.value.map((g) => g.floor).filter((f): f is number => f !== null)
    if (roomForm.floor !== null && !floors.includes(roomForm.floor)) floors.push(roomForm.floor)
    return floors.sort((a, b) => a - b)
  })

  /**
   * The numbers a bulk add will use: the one in the form first, then the next
   * free ones on that floor, each counted as taken before the next is picked.
   */
  const bulkNumbers = computed(() => {
    const count = clampNum(roomForm.count, 1, BULK_MAX)
    const taken: { floor: number | null; roomNumber: string | null }[] = [...rooms.value]
    const numbers: string[] = []
    for (let i = 0; i < count; i++) {
      const n = i === 0 && roomForm.roomNumber.trim() ? roomForm.roomNumber.trim() : nextRoomNumberOf(taken, roomForm.floor)
      numbers.push(n)
      taken.push({ floor: roomForm.floor, roomNumber: n })
    }
    return numbers
  })

  // A room's number follows its floor while it is still the auto kind ("204"):
  // moving 104 to floor 2 makes it the next free 2xx, and moving it back
  // restores 104. A hand-typed name ("A", "Annex 1") is left alone.
  let numberBeforeEdit = ''
  let floorBeforeEdit: number | null = null
  let rentBeforeEdit = 0
  function onRoomFloorChange() {
    if (roomDialogMode.value === 'edit' && roomForm.floor === floorBeforeEdit) {
      roomForm.roomNumber = numberBeforeEdit
      return
    }
    const others = rooms.value.filter((r) => r.id !== editingRoomId.value)
    if (!roomForm.roomNumber.trim() || /^\d{3,}$/.test(roomForm.roomNumber.trim())) {
      roomForm.roomNumber = nextRoomNumberOf(others, roomForm.floor)
    }
  }

  /** What stops this room being saved, or ''. */
  function roomProblem(): string {
    const number = roomForm.roomNumber.trim()
    if (!number) return 'Give the room a number or name.'
    const clash = rooms.value.find((r) => r.id !== editingRoomId.value && sameRoomNumber(r.roomNumber, number))
    if (clash) return `Room ${number} already exists in this accommodation.`
    if (roomForm.roomType === 'custom' && !roomForm.customRoomType.trim()) return 'Name the custom room type.'
    if (!(Number(roomForm.monthlyRent) > 0)) return 'Enter the monthly rent.'
    return utilitiesProblem(roomForm.utilities)
  }

  // Fires only on an actual pick in the dropdown — never during openRoomDialog's
  // programmatic population — so an existing room's saved capacity is never
  // silently overwritten just because its type happens to be Solo/Duo/Triple.
  function onRoomTypeChange() {
    const fixed = ROOM_TYPE_DEFAULT_CAPACITY[roomForm.roomType]
    if (fixed !== undefined) roomForm.capacity = fixed
  }

  function openRoomDialog(room: Room | null, floor?: number) {
    roomStep.value = 1
    roomViewMode.value = 'view'
    if (room) {
      roomDialogMode.value = 'edit'
      editingRoomId.value = room.id
      activeRoomNumber.value = room.roomNumber || ''
      activeRoomStatus.value = room.status === 'occupied' || room.status === 'maintenance' ? room.status : 'available'
      roomForm.roomNumber = room.roomNumber || ''
      numberBeforeEdit = roomForm.roomNumber
      floorBeforeEdit = room.floor
      roomForm.count = 1
      roomForm.roomType = room.roomType || 'solo'
      roomForm.customRoomType = room.customRoomType || ''
      roomForm.floor = room.floor
      roomForm.capacity = room.capacity ?? 1
      roomForm.monthlyRent = room.monthlyRent
      rentBeforeEdit = room.monthlyRent
      roomForm.advanceMonths = room.advanceMonths
      roomForm.depositMonths = room.depositMonths
      roomForm.rentBasis = room.rentBasis
      roomForm.utilities = utilitiesFromRow(utilityColumns(room.utilities))
      roomImages.value = [...room.images]
    } else {
      roomDialogMode.value = 'create'
      editingRoomId.value = ''
      activeRoomNumber.value = ''
      roomForm.roomType = 'solo'
      roomForm.customRoomType = ''
      roomForm.floor = floor ?? nextFloorNumber()
      roomForm.roomNumber = nextRoomNumber(roomForm.floor)
      roomForm.count = 1
      roomForm.capacity = 1
      roomForm.monthlyRent = 0
      roomForm.advanceMonths = null
      roomForm.depositMonths = null
      roomForm.rentBasis = 'room'
      roomForm.utilities = emptyUtilities()
      roomImages.value = []
    }
    roomOpen.value = true
  }

  async function addRoomPhotos(files: File[]) {
    if (!files.length || !editingRoomId.value) return
    const roomId = editingRoomId.value
    const list = roomImages.value
    uploadingRoomPhoto.value = true
    try {
      await addPhotosLive(list, files, async (url) => {
        const { data: created, error: insertError } = await supabase
          .from('room_images')
          .insert({ room_id: roomId, url, sort_order: list.filter((i) => !i.pending).length })
          .select('id,url')
          .single()
        if (insertError) throw insertError
        return { id: created.id, url: created.url }
      })
    } catch (e) {
      notify.error(errorMessage(e, "Could not upload one of this room's photos."))
    } finally {
      uploadingRoomPhoto.value = false
      const row = rooms.value.find((r) => r.id === roomId)
      if (row) {
        row.images = list.filter((i) => !i.pending)
        row.photoUrl = row.images[0]?.url ? resolveAsset(row.images[0].url, CARD) : ''
      }
    }
  }

  async function onRoomPhotosSelected(event: Event) {
    const input = event.target as HTMLInputElement
    const files = Array.from(input.files ?? [])
    await addRoomPhotos(files)
    input.value = ''
  }

  async function takeRoomPhoto() {
    const { file, error } = await capturePhoto()
    if (error) notify.error(error)
    if (file) await addRoomPhotos([file])
  }

  async function deleteRoomImage(imageId: string) {
    if (deletingRoomImage.value) return
    deletingRoomImage.value = imageId
    try {
      const { error: deleteError } = await supabase.from('room_images').delete().eq('id', imageId)
      if (deleteError) throw deleteError
      roomImages.value = roomImages.value.filter((i) => i.id !== imageId)
      const row = rooms.value.find((r) => r.id === editingRoomId.value)
      if (row) {
        row.images = [...roomImages.value]
        row.photoUrl = roomImages.value[0]?.url ? resolveAsset(roomImages.value[0].url, CARD) : ''
      }
    } catch (e) {
      notify.error(errorMessage(e, 'Could not remove this photo.'))
    } finally {
      deletingRoomImage.value = ''
    }
  }

  async function confirmRoomBasics() {
    if (savingRoom.value) return
    const problem = roomProblem()
    if (problem) {
      notify.error(problem)
      return
    }
    // Only an actual re-price of an existing room asks: adding rooms during
    // setup is frequent and harmless, while quietly changing what a room costs
    // flows into every future application quote and nobody is notified.
    if (editingRoomId.value && roomForm.monthlyRent !== rentBeforeEdit) {
      if (!(await requirePin({ title: 'Change this room’s rent?' }))) return
    }
    savingRoom.value = true
    try {
      // Clamped here as well as on blur: a paste, an autofill, or a value typed
      // and submitted without the field ever losing focus all reach this line
      // without having passed the blur handler.
      const capacity = clampNum(roomForm.capacity, 1, CAPACITY_MAX)
      const payload = {
        label: null,
        room_number: roomForm.roomNumber.trim(),
        room_type: roomForm.roomType,
        custom_room_type: roomForm.roomType === 'custom' ? roomForm.customRoomType.trim() || null : null,
        floor: roomForm.floor,
        capacity,
        monthly_rent: clampNum(roomForm.monthlyRent, 0, RENT_MAX),
        advance_months: clampOptional(roomForm.advanceMonths, 0, MONTHS_MAX),
        deposit_months: clampOptional(roomForm.depositMonths, 0, MONTHS_MAX),
        rent_basis: capacity > 1 ? roomForm.rentBasis : ('room' as const),
        ...utilityColumns(roomForm.utilities),
      }

      if (editingRoomId.value) {
        const { error: updateError } = await supabase.from('rooms').update(payload).eq('id', editingRoomId.value)
        if (updateError) throw updateError
        const row = rooms.value.find((r) => r.id === editingRoomId.value)
        if (row) Object.assign(row, {
          roomNumber: payload.room_number,
          roomType: payload.room_type,
          customRoomType: payload.custom_room_type,
          floor: payload.floor,
          capacity: payload.capacity,
          monthlyRent: payload.monthly_rent,
          advanceMonths: payload.advance_months,
          depositMonths: payload.deposit_months,
          rentBasis: payload.rent_basis,
          utilities: utilitiesFromRow(payload),
        })
        activeRoomNumber.value = payload.room_number
        if (roomDialogMode.value === 'edit') {
          roomOpen.value = false
          notify.success('Room saved.')
        } else {
          roomStep.value = 2
        }
        return
      }

      // Several identical rooms: all created at once and open straight away —
      // there is no per-room photo step to finish first.
      const numbers = bulkNumbers.value
      if (numbers.length > 1) {
        const { data: created, error: insertError } = await supabase
          .from('rooms')
          .insert(numbers.map((n) => ({ ...payload, room_number: n, accommodation_id: id, status: 'available' as const })))
          .select('id,current_pax,status,room_number')
        if (insertError) throw insertError
        for (const c of created ?? []) rooms.value.push(roomFromPayload(payload, c))
        roomOpen.value = false
        notify.success(`${numbers.length} rooms added. Open each one to add its photos.`)
        return
      }

      // One room walks on through photos and facilities. It is saved now, so
      // photos have something to attach to, but stays unavailable — hidden from
      // students — until Done, rather than going live half-described.
      const { data: created, error: insertError } = await supabase
        .from('rooms')
        .insert({ ...payload, accommodation_id: id, status: 'maintenance' })
        .select('id,current_pax,status,room_number')
        .single()
      if (insertError) throw insertError
      rooms.value.push(roomFromPayload(payload, created))
      editingRoomId.value = created.id
      activeRoomNumber.value = created.room_number ?? payload.room_number
      activeRoomStatus.value = 'maintenance'
      roomImages.value = []
      roomStep.value = 2
    } catch (e) {
      const code = (e as { code?: string } | null)?.code
      notify.error(code === '23505' ? 'That room number is already used in this accommodation.' : errorMessage(e, 'Could not save this room.'))
    } finally {
      savingRoom.value = false
    }
  }

  /** Done on a new room: it goes live now that it has been described. */
  async function finishNewRoom() {
    if (editingRoomId.value && activeRoomStatus.value === 'maintenance') {
      togglingRoomStatus.value = true
      try {
        const { error: updateError } = await supabase.from('rooms').update({ status: 'available' }).eq('id', editingRoomId.value)
        if (updateError) throw updateError
        activeRoomStatus.value = 'available'
        const row = rooms.value.find((r) => r.id === editingRoomId.value)
        if (row) row.status = 'available'
      } catch (e) {
        notify.error(errorMessage(e, 'Could not open this room to students.'))
        return
      } finally {
        togglingRoomStatus.value = false
      }
    }
    roomOpen.value = false
    notify.success('Room added.')
  }

  // A new room closed before Done is kept, just not live — say so, or it looks
  // like it vanished from Discover for no reason.
  function onRoomDialogHide() {
    if (roomDialogMode.value === 'create' && editingRoomId.value && activeRoomStatus.value === 'maintenance') {
      notify.warning(`Room ${activeRoomNumber.value} was saved as unavailable. Open it and mark it available when it's ready.`)
    }
  }

  /** First room on an empty accommodation: make Floor 1, then open the form on it. */
  async function addFirstRoom() {
    await addFloor()
    const floor = trackedFloors.value[trackedFloors.value.length - 1]
    if (floor !== undefined) openRoomDialog(null, floor)
  }

  return {
    currentRoomFacilities, roomOpen, confirmDeleteRoomOpen, roomDialogMode, roomViewMode, roomStep, savingRoom,
    editingRoomId, activeRoomNumber, activeRoomStatus, togglingRoomStatus, roomImages, uploadingRoomPhoto,
    deletingRoomImage, roomForm, rentBasisHint, previewRoomNumber, activeRoomTenants, floorOptions, bulkNumbers,
    onRoomFloorChange, onRoomTypeChange, openRoomDialog, onRoomPhotosSelected, takeRoomPhoto, deleteRoomImage,
    confirmRoomBasics, finishNewRoom, onRoomDialogHide, addFirstRoom,
  }
}
