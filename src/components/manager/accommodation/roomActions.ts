// What can be done to a room that already exists, from its sheet: copy it,
// take it out of (or back into) service, delete it.
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { utilityColumns } from '@/utils/listings'
import { isLeaseRestrictError, type Img } from './model'
import { roomFromPayload, type RoomPayload, type createRooms } from './rooms'
import type { Detail } from './detail'

export function createRoomActions(core: Detail, roomEditor: ReturnType<typeof createRooms>) {
  const { id, rooms, facilities, nextRoomNumber, notify } = core
  const { savingRoom, editingRoomId, activeRoomStatus, togglingRoomStatus, roomOpen, confirmDeleteRoomOpen, currentRoomFacilities, openRoomDialog } = roomEditor
  /** A copy of the open room on the same floor: next free number, same photos. */
  async function duplicateRoom() {
    const source = rooms.value.find((r) => r.id === editingRoomId.value)
    if (!source || savingRoom.value) return
    savingRoom.value = true
    try {
      const payload: RoomPayload = {
        room_number: nextRoomNumber(source.floor),
        room_type: source.roomType || 'solo',
        custom_room_type: source.customRoomType,
        floor: source.floor,
        capacity: source.capacity ?? 1,
        monthly_rent: source.monthlyRent,
        advance_months: source.advanceMonths,
        deposit_months: source.depositMonths,
        rent_basis: source.rentBasis,
        ...utilityColumns(source.utilities),
      }
      const { data: created, error: insertError } = await supabase
        .from('rooms')
        .insert({ ...payload, label: null, accommodation_id: id, status: 'available' })
        .select('id,current_pax,status,room_number')
        .single()
      if (insertError) throw insertError

      let images: Img[] = []
      if (source.images.length) {
        const { data: imageRows, error: imagesError } = await supabase
          .from('room_images')
          .insert(source.images.map((img, i) => ({ room_id: created.id, url: img.url, sort_order: i })))
          .select('id,url')
        if (imagesError) throw imagesError
        images = imageRows ?? []
      }

      // Its private facilities (own bath, air-con) come along, photos included.
      for (const f of currentRoomFacilities.value) {
        const { data: fac, error: facError } = await supabase
          .from('accommodation_facilities')
          .insert({
            accommodation_id: id,
            facility_type: f.facilityType,
            access_scope: 'private',
            label: f.label || null,
            description: f.description || null,
            room_id: created.id,
            floor: null,
            status: f.status,
            sort_order: facilities.value.length,
          })
          .select('id')
          .single()
        if (facError) throw facError
        let facImages: Img[] = []
        if (f.images.length) {
          const { data: imgRows, error: imgError } = await supabase
            .from('accommodation_facility_images')
            .insert(f.images.map((img, i) => ({ facility_id: fac.id, url: img.url, sort_order: i })))
            .select('id,url')
          if (imgError) throw imgError
          facImages = imgRows ?? []
        }
        facilities.value.push({ ...f, id: fac.id, roomId: created.id, roomIds: [], images: facImages })
      }

      const copy = roomFromPayload(payload, created, images)
      rooms.value.push(copy)
      openRoomDialog(copy)
      notify.success(`Room ${copy.roomNumber} added as a copy.`)
    } catch (e) {
      notify.error(errorMessage(e, 'Could not duplicate this room.'))
    } finally {
      savingRoom.value = false
    }
  }

  // Occupied is set elsewhere (when a lease is active) and isn't something a
  // landlord/landlady flips by hand here — this only toggles between the two states
  // that ARE theirs to set: open for applicants, or taken out of service
  // (renovation, damage, etc.) without deleting the room outright.
  async function toggleRoomStatus() {
    if (togglingRoomStatus.value || !editingRoomId.value || activeRoomStatus.value === 'occupied') return
    const next = activeRoomStatus.value === 'maintenance' ? 'available' : 'maintenance'
    togglingRoomStatus.value = true
    try {
      const { error: updateError } = await supabase.from('rooms').update({ status: next }).eq('id', editingRoomId.value)
      if (updateError) throw updateError
      activeRoomStatus.value = next
      const row = rooms.value.find((r) => r.id === editingRoomId.value)
      if (row) row.status = next
      notify.success(next === 'maintenance' ? 'Room marked unavailable.' : 'Room marked available.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not update this room.'))
    } finally {
      togglingRoomStatus.value = false
    }
  }

  async function deleteRoom() {
    if (savingRoom.value || !editingRoomId.value) return
    savingRoom.value = true
    try {
      const { count, error: countError } = await supabase
        .from('leases')
        .select('id', { count: 'exact', head: true })
        .eq('room_id', editingRoomId.value)
      if (countError) throw countError
      if (count) {
        notify.error('This room has lease history and can\'t be deleted. Consider renaming or repurposing it instead.')
        return
      }

      const { data: deleted, error: deleteError } = await supabase
        .from('rooms')
        .delete()
        .eq('id', editingRoomId.value)
        .select('id')
      if (deleteError) throw deleteError
      if (!deleted?.length) {
        notify.error('Could not remove this room.')
        return
      }
      rooms.value = rooms.value.filter((r) => r.id !== editingRoomId.value)
      roomOpen.value = false
      notify.success('Room removed.')
    } catch (e) {
      notify.error(
        isLeaseRestrictError(e)
          ? 'This room has lease history and can\'t be deleted.'
          : errorMessage(e, 'Could not remove this room.'),
      )
    } finally {
      savingRoom.value = false
      confirmDeleteRoomOpen.value = false
    }
  }

  return { duplicateRoom, toggleRoomStatus, deleteRoom }
}
