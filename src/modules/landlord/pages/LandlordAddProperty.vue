<template>
  <q-page class="dashboard-page bg-grey-1">
    <div class="header-section text-white">
      <div class="row justify-between items-center q-pa-md">
        <div>
          <h4 class="q-my-none text-weight-bold">Add Property</h4>
          <p class="text-subtitle1 text-white-7 q-mb-none">
            Register a new property for accreditation
          </p>
        </div>
        <q-btn flat round dense icon="close" @click="handleCancel" />
      </div>
    </div>

    <div class="content-section q-pa-md">
      <q-card flat bordered class="custom-card">
        <q-form ref="propertyFormRef" @submit.prevent="handleSubmit" class="q-pa-md">
          <div class="row q-col-gutter-md">
            <div class="col-12">
              <q-input
                v-model="form.name"
                outlined
                label="Property name"
                placeholder="e.g. Dong's Dormitory"
                :rules="[(val: string) => !!val?.trim() || 'Property name is required']"
              />
            </div>

            <div class="col-12 col-md-6">
              <q-input
                v-model="form.address"
                outlined
                label="Address"
                placeholder="Street, Barangay"
              />
            </div>

            <div class="col-12 col-md-6">
              <q-input v-model="form.city" outlined label="City" />
            </div>

            <div class="col-12 col-md-4">
              <q-input
                v-model="form.monthlyRent"
                outlined
                label="Monthly rent (₱)"
                type="number"
                min="0"
              />
            </div>

            <div class="col-12 col-md-4">
              <q-select
                v-model="form.roomType"
                outlined
                label="Room type"
                :options="roomTypeOptions"
                :rules="[(val: string | null) => !!val || 'Room type is required']"
              />
            </div>

            <div class="col-6 col-md-4">
              <q-input
                v-model="form.totalRooms"
                outlined
                label="Total rooms"
                type="number"
                min="0"
              />
            </div>

            <div class="col-6 col-md-4">
              <q-input
                v-model="form.totalFloors"
                outlined
                label="Total floors"
                type="number"
                min="1"
              />
            </div>

            <div class="col-12">
              <q-input
                v-model="form.description"
                outlined
                label="Description"
                type="textarea"
                rows="3"
              />
            </div>
          </div>

          <div class="row q-mt-lg justify-end q-gutter-sm">
            <q-btn flat color="grey-8" label="Cancel" @click="handleCancel" />
            <q-btn
              unelevated
              color="teal-9"
              class="action-btn"
              label="Add Property"
              type="submit"
              :loading="submitting"
            />
          </div>
        </q-form>
      </q-card>

      <div v-if="error" class="text-negative q-mt-md">{{ error }}</div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar, type QForm } from 'quasar'
import { supabase } from '@/shared/utils/supabase'

interface PropertyForm {
  name: string;
  address: string;
  city: string;
  monthlyRent: string;
  roomType: string | null;
  totalRooms: string;
  totalFloors: string;
  description: string;
}

const router = useRouter()
const $q = useQuasar()

const roomTypeOptions = ['solo', 'duo', 'triple', 'bedspace', 'studio']

const propertyFormRef = ref<QForm | null>(null)
const submitting = ref(false)
const error = ref<string | null>(null)

const form = ref<PropertyForm>({
  name: '',
  address: '',
  city: '',
  monthlyRent: '',
  roomType: null,
  totalRooms: '',
  totalFloors: '',
  description: '',
})

function notify(kind: 'success' | 'error', message: string) {
  $q.notify({
    message,
    position: 'top',
    color: kind === 'success' ? 'teal-8' : 'red-6',
    textColor: 'white',
    icon: kind === 'success' ? 'check_circle' : 'error_outline',
    iconColor: 'white',
    classes: 'custom-notify',
  })
}

function handleCancel() {
  void router.push('/landlord/properties')
}

async function handleSubmit() {
  error.value = null

  const isValid = await propertyFormRef.value?.validate()
  if (!isValid) return

  submitting.value = true
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser()

    if (!user) {
      notify('error', 'Please sign in to add a property.')
      void router.push('/login')
      return
    }

    const { error: insertError } = await supabase
      .from('properties')
      .insert({
        landlord_id: user.id,
        name: form.value.name.trim(),
        room_type: form.value.roomType as 'solo' | 'duo' | 'triple' | 'bedspace' | 'studio',
        status: 'pending',
        address: form.value.address.trim() || null,
        city: form.value.city.trim() || null,
        description: form.value.description.trim() || null,
        monthly_rent: form.value.monthlyRent ? Number(form.value.monthlyRent) : null,
        total_rooms: form.value.totalRooms ? Number(form.value.totalRooms) : null,
        total_floors: form.value.totalFloors ? Number(form.value.totalFloors) : null,
      })

    if (insertError) throw insertError

    notify('success', `"${form.value.name.trim()}" added for review.`)
    void router.push('/landlord/properties')
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to add property'
    notify('error', error.value)
  } finally {
    submitting.value = false
  }
}
</script>

<style scoped>
.header-section {
  background: #004d40;
  border-radius: 0 0 28px 28px;
  margin-bottom: -40px;
}
.text-white-7 {
  color: rgba(255, 255, 255, 0.7);
}
.content-section {
  position: relative;
  z-index: 1;
}
.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}
.action-btn {
  border-radius: 12px;
  font-weight: 600;
  padding: 8px 24px;
}
</style>
