<template>
  <!-- A walk-in tenant: find the student by ID, pick the room, add. The stay
       stays pending until the student's QR is scanned (Tenants → Scan to accept),
       which only the app can do — adding itself works on the web too. -->
  <BottomSheet
    :model-value="modelValue"
    title="Add a student"
    clear-label=""
    done-label=""
    @update:model-value="emit('update:modelValue', $event)"
  >
    <div class="sheet-block">
      <span class="sheet-label">Student ID</span>
      <div class="find-row">
        <input
          v-model="studentNo"
          class="add-input"
          inputmode="text"
          autocomplete="off"
          placeholder="e.g. 21-12345"
          @keyup.enter="find"
        />
        <button type="button" class="add-btn add-btn--ghost" :disabled="!studentNo.trim() || finding" @click="find">
          {{ finding ? 'Finding…' : 'Find' }}
        </button>
      </div>
    </div>

    <div v-if="student" class="found" :class="{ 'found--no': !student.osasVerified }">
      <IconifyIcon :icon="student.osasVerified ? 'lucide:shield-check' : 'lucide:shield-alert'" width="18" />
      <span class="found-body">
        <strong>{{ student.name }}</strong>
        <span>{{ student.osasVerified ? [student.program, student.yearLevel ? `Year ${student.yearLevel}` : ''].filter(Boolean).join(' · ') || 'Verified ISU student' : 'Not verified by OSAS — they can’t be added yet.' }}</span>
      </span>
    </div>

    <template v-if="student?.osasVerified">
      <div class="sheet-block">
        <span class="sheet-label">Room</span>
        <p v-if="!rooms.length" class="add-none">You have no available rooms.</p>
        <div v-else class="m-chips">
          <button
            v-for="r in rooms"
            :key="r.id"
            type="button"
            class="m-chip"
            :class="{ 'm-chip--on': roomId === r.id }"
            @click="roomId = r.id"
          >
            {{ r.label }} · {{ r.accommodation }}
          </button>
        </div>
      </div>

      <div class="sheet-block">
        <span class="sheet-label">Move-in date</span>
        <DateTimeField v-model="startDate" mode="date" :min="today" placeholder="Pick a move-in date" />
      </div>

      <p class="add-note">
        They join this room once you scan their student QR in person.
      </p>
      <button type="button" class="add-btn" :disabled="!roomId || !startDate || adding" @click="add">
        {{ adding ? 'Adding…' : 'Add student' }}
      </button>
    </template>
  </BottomSheet>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useQrStore, type ScannedStudent } from '@/stores/qr'
import { addStudentToRoom } from '@/utils/applications'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import BottomSheet from '@/components/shared/BottomSheet.vue'
import DateTimeField from '@/components/shared/DateTimeField.vue'
import { manilaToday } from '@/utils/payments'

const props = defineProps<{ modelValue: boolean }>()
const emit = defineEmits<{ 'update:modelValue': [value: boolean]; added: [] }>()

const qrStore = useQrStore()
const notify = useNotify()

const today = manilaToday()
const studentNo = ref('')
const student = ref<ScannedStudent | null>(null)
const finding = ref(false)
const rooms = ref<{ id: string; label: string; accommodation: string }[]>([])
const roomId = ref('')
const startDate = ref(today)
const adding = ref(false)

// Fresh every time it opens: a half-filled sheet from last time would add the
// wrong student to the wrong room with one tap.
watch(
  () => props.modelValue,
  (open) => {
    if (!open) return
    studentNo.value = ''
    student.value = null
    roomId.value = ''
    startDate.value = today
    void loadRooms()
  },
)

async function loadRooms() {
  const { data: authData } = await authUser()
  const uid = authData.user?.id
  if (!uid) return
  const { data } = await supabase
    .from('rooms')
    .select('id,label,room_number,accommodations!inner(name,landlord_id)')
    .eq('accommodations.landlord_id', uid)
    .eq('status', 'available')
  rooms.value = (data ?? []).map((r) => ({
    id: r.id,
    label: r.label || (r.room_number ? `Room ${r.room_number}` : 'Room'),
    accommodation: (r.accommodations as unknown as { name: string | null } | null)?.name || 'Accommodation',
  }))
}

// The same lookup the scanner's typed-code path uses, so the landlord/landlady
// sees who they are adding before anything is written.
async function find() {
  if (!studentNo.value.trim() || finding.value) return
  finding.value = true
  student.value = null
  try {
    student.value = await qrStore.scanStudent(studentNo.value)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not find that student.'))
  } finally {
    finding.value = false
  }
}

async function add() {
  const s = student.value
  const room = rooms.value.find((r) => r.id === roomId.value)
  if (!s || !room || adding.value) return
  adding.value = true
  try {
    await addStudentToRoom(room.id, s.studentId ?? studentNo.value.trim(), startDate.value)
    notify.success(`${s.name} added. Scan their QR to accept.`)
    emit('added')
    emit('update:modelValue', false)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not add this student.'))
  } finally {
    adding.value = false
  }
}
</script>

<style scoped>
.find-row {
  display: flex;
  gap: 8px;
}
.add-input {
  min-width: 0;
  flex: 1;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
  color: var(--m-text);
  font: inherit;
  font-size: 14px;
}
.found {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-radius: var(--m-radius);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.found--no {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.found-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 1px;
  font-size: 12.5px;
}
.found-body strong {
  color: var(--m-ink);
  font-size: 14px;
}
.add-none,
.add-note {
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
}
.add-btn {
  min-height: 44px;
  padding: 0 16px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
}
.add-btn:disabled {
  opacity: 0.6;
}
.add-btn--ghost {
  min-height: 0;
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
}
</style>
