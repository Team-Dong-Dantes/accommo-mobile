// Floors: naming one, adding the next, and deleting one with its rooms.
import { ref } from 'vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { requirePin } from '@/utils/requirePin'
import { MAX_FLOORS, isLeaseRestrictError } from './model'
import type { Detail } from './detail'

export function createFloors(core: Detail) {
  const { id, rooms, facilities, trackedFloors, floorLabels, floorCount, nextFloorNumber, notify } = core
  const floorNameOpen = ref(false)
  const floorNameFor = ref<number | null>(null)
  const floorNameDraft = ref('')
  const savingFloorName = ref(false)
  function openFloorName(floor: number) {
    floorNameFor.value = floor
    floorNameDraft.value = floorLabels.value[floor] || ''
    floorNameOpen.value = true
  }
  async function saveFloorName() {
    const floor = floorNameFor.value
    if (floor === null || savingFloorName.value) return
    const label = floorNameDraft.value.trim() || null
    savingFloorName.value = true
    try {
      // Upsert: a floor that only exists through its rooms has no row yet.
      const { error: saveError } = await supabase
        .from('accommodation_floors')
        .upsert({ accommodation_id: id, floor_number: floor, label }, { onConflict: 'accommodation_id,floor_number' })
      if (saveError) throw saveError
      if (!trackedFloors.value.includes(floor)) trackedFloors.value.push(floor)
      const next = { ...floorLabels.value }
      if (label) next[floor] = label
      else delete next[floor]
      floorLabels.value = next
      floorNameOpen.value = false
    } catch (e) {
      notify.error(errorMessage(e, 'Could not rename this floor.'))
    } finally {
      savingFloorName.value = false
    }
  }

  // Adding a floor doesn't mean adding a room — it just opens up a new,
  // empty floor group to add rooms into (via that floor's own "Add room").
  // Nothing is written to the database until an actual room is saved on it.
  const addingFloor = ref(false)

  async function addFloor() {
    if (addingFloor.value) return
    if (floorCount.value >= MAX_FLOORS) {
      notify.error(`This accommodation already has the maximum of ${MAX_FLOORS} floors.`)
      return
    }
    addingFloor.value = true
    const floor = nextFloorNumber()
    try {
      const { error: insertError } = await supabase
        .from('accommodation_floors')
        .insert({ accommodation_id: id, floor_number: floor })
      if (insertError) throw insertError
      trackedFloors.value.push(floor)
    } catch (e) {
      notify.error(errorMessage(e, 'Could not add this floor.'))
    } finally {
      addingFloor.value = false
    }
  }

  const deletingFloor = ref<number | null>(null)
  const confirmDeleteFloorOpen = ref(false)
  const floorPendingDelete = ref<number | null>(null)

  async function deleteTrackedFloorRow(floor: number) {
    const { error } = await supabase
      .from('accommodation_floors')
      .delete()
      .eq('accommodation_id', id)
      .eq('floor_number', floor)
    if (error) throw error
    trackedFloors.value = trackedFloors.value.filter((f) => f !== floor)
  }

  async function promptDeleteFloor(floor: number) {
    // An empty floor has no rooms to protect — just remove its own row.
    if (!rooms.value.some((r) => r.floor === floor)) {
      if (deletingFloor.value !== null) return
      deletingFloor.value = floor
      try {
        await deleteTrackedFloorRow(floor)
      } catch (e) {
        notify.error(errorMessage(e, 'Could not remove this floor.'))
      } finally {
        deletingFloor.value = null
      }
      return
    }
    floorPendingDelete.value = floor
    confirmDeleteFloorOpen.value = true
  }

  async function confirmDeleteFloor() {
    if (!(await requirePin({ title: 'Delete this floor?' }))) return
    const floor = floorPendingDelete.value
    if (floor === null || deletingFloor.value !== null) return
    const roomIds = rooms.value.filter((r) => r.floor === floor).map((r) => r.id)
    if (!roomIds.length) {
      confirmDeleteFloorOpen.value = false
      return
    }
    deletingFloor.value = floor
    try {
      const { count, error: countError } = await supabase
        .from('leases')
        .select('id', { count: 'exact', head: true })
        .in('room_id', roomIds)
      if (countError) throw countError
      if (count) {
        notify.error('This floor has rooms with lease history and can\'t be deleted.')
        return
      }

      const { data: deleted, error: deleteError } = await supabase
        .from('rooms')
        .delete()
        .in('id', roomIds)
        .select('id')
      if (deleteError) throw deleteError
      if ((deleted ?? []).length !== roomIds.length) {
        notify.error("Some rooms on this floor couldn't be deleted — nothing was removed until this is resolved.")
        return
      }

      rooms.value = rooms.value.filter((r) => r.floor !== floor)
      facilities.value = facilities.value.filter((f) => !f.roomId || !roomIds.includes(f.roomId))
      if (trackedFloors.value.includes(floor)) {
        await deleteTrackedFloorRow(floor)
      }
      notify.success(`Floor ${floor} removed.`)
    } catch (e) {
      notify.error(
        isLeaseRestrictError(e)
          ? 'This floor has rooms with lease history and can\'t be deleted.'
          : errorMessage(e, 'Could not remove this floor.'),
      )
    } finally {
      deletingFloor.value = null
      confirmDeleteFloorOpen.value = false
    }
  }

  return {
    floorNameOpen, floorNameFor, floorNameDraft, savingFloorName, openFloorName, saveFloorName, addingFloor, addFloor,
    deletingFloor, confirmDeleteFloorOpen, floorPendingDelete, promptDeleteFloor, confirmDeleteFloor,
  }
}
