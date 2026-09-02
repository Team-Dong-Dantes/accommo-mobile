<template>
  <q-page class="profile-page">
    <main class="profile-content">
    <div v-if="loading" class="profile-state" role="status" aria-live="polite">
      <q-spinner color="primary" size="32px" />
      <span>Loading profile…</span>
    </div>
    <div v-else-if="error" class="profile-state profile-state--error" role="alert">
      <IconifyIcon icon="lucide:circle-alert" width="24" />
      <strong>We couldn’t load your profile.</strong>
      <span>{{ error }}</span>
      <q-btn outline no-caps color="primary" label="Try again" class="profile-state-action" @click="loadProfile" />
    </div>
    <template v-else>

    <!-- Unverified Banner -->
    <q-banner v-if="!osasVerified" class="q-mx-md q-mb-md border-radius-24 q-pa-md" style="background: #FFF8E1; border: 1px solid #FFE082;">
      <div class="row items-center no-wrap">
        <q-icon name="error_outline" color="orange-9" size="28px" class="q-mr-md" />
        <div class="col">
          <div class="text-subtitle2 text-weight-bold text-orange-10 line-height-tight">{{ pendingReview ? 'Enrollment under review' : 'Enrollment not verified' }}</div>
          <div class="text-caption text-orange-9 q-mt-xs" style="line-height: 1.2">{{ pendingReview ? 'OSAS is reviewing your documents (1–2 business days).' : 'Submit your documents for OSAS accreditation.' }}</div>
        </div>
        <q-btn unelevated color="orange-9" :label="pendingReview ? 'View Status' : 'Verify Now'" size="sm" no-caps class="border-radius-16 text-weight-bold q-px-sm q-ml-sm" @click="verifyNow" />
      </div>
    </q-banner>

    <!-- Profile Header Card -->
    <q-card flat class="q-mx-md q-mb-lg border-radius-24 overflow-hidden shadow-soft">
      <div class="profile-gradient relative-position" style="height: 110px;">
        <q-btn round flat class="absolute-top-right q-ma-sm text-white bg-white-20 shell-icon-button" aria-label="Edit profile" @click="openEditProfile">
          <IconifyIcon icon="lucide:pencil" width="19" />
        </q-btn>
      </div>

      <div class="q-px-md relative-position bg-white" style="padding-top: 50px; padding-bottom: 24px;">
        <!-- Avatar -->
        <div class="absolute" style="top: -48px; left: 16px;">
          <q-avatar size="96px" class="profile-avatar text-white font-size-32 text-weight-bold" @click="openEditProfile">
            <img v-if="profileImageUrl" :src="profileImageUrl" :alt="`${fullName} profile photo`" />
            <span v-else>{{ initials }}</span>
            <q-badge floating color="dark" class="camera-badge flex flex-center" rounded>
              <IconifyIcon icon="lucide:camera" width="12" />
            </q-badge>
          </q-avatar>
        </div>

        <!-- Badge -->
        <div class="absolute" style="top: 16px; right: 16px;">
          <q-chip dense :color="(verified || osasVerified) ? 'teal-1' : 'amber-1'" :text-color="(verified || osasVerified) ? 'teal-8' : 'orange-9'" class="text-weight-bold q-px-sm" style="font-size: 11px;">
            <q-icon name="circle" size="8px" class="q-mr-xs" />
            {{ (verified || osasVerified) ? 'Verified' : 'Pending Verification' }}
          </q-chip>
        </div>

        <!-- Name + Student ID -->
        <div class="q-mt-sm">
          <div class="text-h5 text-weight-bold line-height-tight">{{ fullName }}</div>
          <div class="text-caption text-grey-6 q-mt-xs">Student ID: {{ studentId }} · {{ campus }}</div>
        </div>

        <!-- 2x2 Detail Grid -->
        <div class="row q-col-gutter-sm q-mt-md">
          <div class="col-6">
            <div class="detail-box q-pa-sm row items-start">
              <q-icon name="school" color="teal-7" size="16px" class="q-mr-sm q-mt-xs" />
              <div class="col overflow-hidden">
                <div class="text-xs text-grey-5 text-weight-bold letter-spacing-1">COURSE</div>
                <div class="text-caption text-weight-bold text-dark ellipsis">{{ course }}</div>
              </div>
            </div>
          </div>
          <div class="col-6">
            <div class="detail-box q-pa-sm row items-start">
              <q-icon name="location_on" color="teal-7" size="16px" class="q-mr-sm q-mt-xs" />
              <div class="col overflow-hidden">
                <div class="text-xs text-grey-5 text-weight-bold letter-spacing-1">CAMPUS</div>
                <div class="text-caption text-weight-bold text-dark ellipsis">{{ campus }}</div>
              </div>
            </div>
          </div>
          <div class="col-6">
            <div class="detail-box q-pa-sm row items-start">
              <q-icon name="mail_outline" color="teal-7" size="16px" class="q-mr-sm q-mt-xs" />
              <div class="col overflow-hidden">
                <div class="text-xs text-grey-5 text-weight-bold letter-spacing-1">EMAIL</div>
                <div class="text-caption text-weight-bold text-dark ellipsis">{{ email }}</div>
              </div>
            </div>
          </div>
          <div class="col-6">
            <div class="detail-box q-pa-sm row items-start">
              <q-icon name="phone" color="teal-7" size="16px" class="q-mr-sm q-mt-xs" />
              <div class="col overflow-hidden">
                <div class="text-xs text-grey-5 text-weight-bold letter-spacing-1">CONTACT</div>
                <div class="text-caption text-weight-bold text-dark ellipsis">{{ contact }}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </q-card>

    <!-- Stats Row -->
    <div class="row q-col-gutter-md q-px-md q-mb-lg">
      <div class="col-4">
        <q-card flat class="stat-card full-height shadow-soft">
          <q-card-section class="q-pa-md column items-center justify-center text-center">
            <div class="icon-circle bg-teal-1 text-teal-8 q-mb-sm"><q-icon name="schedule" size="18px" /></div>
            <div class="text-h6 text-weight-bold line-height-tight">{{ stats.monthsPaid }}</div>
            <div class="text-xs text-grey-6 q-mt-xs">Months Paid</div>
            <div class="text-teal-8 text-weight-bold q-mt-xs" style="font-size: 10px;">10 remaining</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-4">
        <q-card flat class="stat-card full-height shadow-soft">
          <q-card-section class="q-pa-md column items-center justify-center text-center">
            <div class="icon-circle bg-indigo-1 text-indigo-5 q-mb-sm"><q-icon name="domain" size="18px" /></div>
            <div class="text-h6 text-weight-bold line-height-tight">3+mo</div>
            <div class="text-xs text-grey-6 q-mt-xs">Stay</div>
            <div class="text-indigo-5 text-weight-bold q-mt-xs" style="font-size: 10px;">{{ stats.stay }}</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-4">
        <q-card flat class="stat-card full-height shadow-soft">
          <q-card-section class="q-pa-md column items-center justify-center text-center">
            <div class="icon-circle bg-orange-1 text-orange-4 q-mb-sm"><q-icon name="star_outline" size="18px" /></div>
            <div class="text-h6 text-weight-bold line-height-tight">{{ stats.tenantScore }}</div>
            <div class="text-xs text-grey-6 q-mt-xs">Score</div>
            <div class="text-orange-5 text-weight-bold q-mt-xs" style="font-size: 10px;">Tenant score</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Current Accommodation -->
    <q-card flat class="q-mx-md q-mb-lg border-radius-24 q-pa-md shadow-soft">
      <div class="row items-center q-mb-md">
        <div class="icon-circle bg-teal-1 text-teal-8 q-mr-sm"><q-icon name="domain" size="18px" /></div>
        <div class="text-subtitle1 text-weight-bold">Current Accommodation</div>
      </div>
      <q-card flat class="bg-grey-1 border-radius-16 q-pa-md">
        <div class="row justify-between items-start">
          <div class="text-subtitle1 text-weight-bold line-height-tight">{{ accommodation.name }}</div>
          <q-rating :model-value="accommodation.rating" max="5" size="14px" color="amber-7" readonly class="q-mt-xs" />
        </div>
        <div class="text-caption text-grey-6 row items-center q-mt-xs">
          <q-icon name="place" size="14px" class="q-mr-xs" /> {{ accommodation.address }}
        </div>
        <div class="row q-mt-md">
          <div class="col-4">
            <div class="text-grey-5 text-weight-bold text-xs letter-spacing-1">MONTHLY</div>
            <div class="text-subtitle2 text-weight-bold text-dark">{{ accommodation.monthlyRent }}</div>
          </div>
          <div class="col-4">
            <div class="text-grey-5 text-weight-bold text-xs letter-spacing-1">CHECK-IN</div>
            <div class="text-subtitle2 text-weight-bold text-dark">{{ accommodation.checkIn }}</div>
          </div>
          <div class="col-4">
            <div class="text-grey-5 text-weight-bold text-xs letter-spacing-1">ROOM</div>
            <div class="text-subtitle2 text-weight-bold text-dark">{{ accommodation.roomUnit }}</div>
          </div>
        </div>
      </q-card>
    </q-card>

    <!-- Verification QR -->
    <q-card flat class="q-mx-md q-mb-lg border-radius-24 q-pa-md shadow-soft">
      <div class="row items-center q-mb-sm">
        <div class="icon-circle bg-teal-1 text-teal-8 q-mr-sm"><q-icon name="qr_code_scanner" size="18px" /></div>
        <div>
          <div class="text-subtitle1 text-weight-bold line-height-tight">Verification QR</div>
          <div class="text-caption text-grey-6">Show this to landlords to confirm enrollment</div>
        </div>
      </div>
      
      <div class="row justify-center q-mt-lg q-mb-md">
        <template v-if="!osasVerified">
          <div class="qr-placeholder column items-center justify-center">
            <q-icon name="qr_code_2" size="64px" color="grey-4" />
            <div class="text-caption text-grey-5 text-weight-bold q-mt-sm letter-spacing-1">LOCKED</div>
          </div>
        </template>
        <template v-else>
          <div class="qr-active column items-center justify-center q-pa-sm bg-white" style="border: 1px solid #e0e0e0; border-radius: 16px;">
            <q-img v-if="qrDataUrl" :src="qrDataUrl" width="160px" height="160px" />
            <div v-else class="qr-placeholder column items-center justify-center">
              <q-icon name="qr_code_2" size="64px" color="grey-4" />
              <div class="text-caption text-grey-5 text-weight-bold q-mt-sm letter-spacing-1">UNAVAILABLE</div>
            </div>
          </div>
        </template>
      </div>
      
      <div class="text-center text-caption text-grey-6 q-mb-md q-px-md">
        <span v-if="!osasVerified">Verify your ISU enrollment to unlock your unique QR code for landlord scanning.</span>
        <span v-else>Show this QR code to landlords to verify your active student status.</span>
      </div>
      
      <q-btn v-if="!osasVerified" unelevated color="teal-8" icon="verified_user" label="Verify Now" class="border-radius-16 text-weight-bold full-width q-py-sm" no-caps @click="verifyNow" />
    </q-card>

    <!-- Boarding History -->
    <q-card flat class="q-mx-md q-mb-lg border-radius-24 q-pa-md shadow-soft">
      <div class="row items-center q-mb-lg">
        <div class="icon-circle bg-indigo-1 text-indigo-5 q-mr-sm"><q-icon name="schedule" size="18px" /></div>
        <div class="text-subtitle1 text-weight-bold">Boarding History</div>
      </div>

      <div v-if="history.length === 0" class="text-center text-grey-6 q-py-md">
        No boarding history yet.
      </div>
      <div v-else class="timeline">
        <div v-for="entry in history" :key="entry.id" class="timeline-item">
          <div class="timeline-marker">
            <div class="timeline-dot" :style="{ background: entry.dotColor }" />
            <div v-if="!entry.last" class="timeline-line" />
          </div>
          <div class="timeline-content q-pb-lg">
            <div class="row justify-between items-start">
              <div>
                <div class="text-subtitle2 text-weight-bold line-height-tight">{{ entry.name }}</div>
                <div class="text-caption text-grey-6 q-mt-xs">{{ entry.address }}</div>
                <div class="text-xs text-grey-5 row items-center q-mt-xs">
                  <q-icon name="calendar_today" size="12px" class="q-mr-xs" /> {{ entry.dateRange }}
                </div>
                <div class="text-xs text-grey-5 q-mt-xs">"{{ entry.status === 'Current' ? 'Currently staying' : entry.status === 'Evicted' ? 'Evicted — policy violation' : 'Graduated unit' }}"</div>
              </div>
              <q-chip dense :color="entry.badgeColor" :text-color="entry.textColor || 'white'" class="text-weight-bold" style="font-size: 11px;">
                {{ entry.status }}
              </q-chip>
            </div>
          </div>
        </div>
      </div>
    </q-card>

    <!-- Emergency Contact -->
    <q-card flat class="q-mx-md q-mb-lg border-radius-24 q-pa-md shadow-soft">
      <div class="row items-center justify-between q-mb-md">
        <div class="row items-center">
          <div class="icon-circle bg-orange-1 text-orange-8 q-mr-sm"><q-icon name="person_outline" size="18px" /></div>
          <div class="text-subtitle1 text-weight-bold">Emergency Contact</div>
        </div>
        <q-btn flat color="teal-8" label="Edit" no-caps dense class="text-weight-bold text-caption" @click="openEmergency" />
      </div>

      <div class="emergency-box q-pa-md row items-center">
        <q-avatar size="48px" color="orange-9" text-color="white" class="text-weight-bold font-size-18 shadow-2">
          {{ emergency.name.split(' ').map(n => n[0]).join('').substring(0,2) || 'EC' }}
        </q-avatar>
        <div class="q-ml-md col">
          <div class="text-subtitle1 text-weight-bold line-height-tight text-dark">{{ emergency.name }}</div>
          <div class="text-caption text-grey-7">{{ emergency.relation }}</div>
        </div>
        <q-btn unelevated color="orange-9" icon="call" label="Call" no-caps class="border-radius-16 text-weight-bold q-px-md shadow-1" @click="callEmergency" />
      </div>
    </q-card>

    <!-- Actions List -->
    <q-card flat class="q-mx-md q-mb-xl border-radius-24 overflow-hidden shadow-soft">
      <q-list class="bg-white">
        <q-item clickable v-ripple class="q-py-md" @click="openEditProfile">
          <q-item-section avatar>
            <div class="icon-circle bg-teal-1 text-teal-8"><q-icon name="settings_outlined" size="18px" /></div>
          </q-item-section>
          <q-item-section>
            <div class="text-subtitle2 text-weight-bold text-dark">Settings</div>
            <div class="text-caption text-grey-5">Notifications, privacy, security</div>
          </q-item-section>
          <q-item-section side>
            <q-icon name="chevron_right" color="grey-4" />
          </q-item-section>
        </q-item>
        
        <q-separator inset class="bg-grey-2" />
        
        <q-item clickable v-ripple class="q-py-md" @click="goNotifications">
          <q-item-section avatar>
            <div class="icon-circle bg-indigo-1 text-indigo-5"><q-icon name="notifications_none" size="18px" /></div>
          </q-item-section>
          <q-item-section>
            <div class="text-subtitle2 text-weight-bold text-dark">Notifications</div>
            <div class="text-caption text-grey-5">Manage alert preferences</div>
          </q-item-section>
          <q-item-section side>
            <q-icon name="chevron_right" color="grey-4" />
          </q-item-section>
        </q-item>
        
        <q-separator inset class="bg-grey-2" />
        
        <q-item clickable v-ripple @click="handleLogout" class="q-py-md">
          <q-item-section avatar>
            <div class="icon-circle bg-red-1 text-red-5"><q-icon name="logout" size="18px" /></div>
          </q-item-section>
          <q-item-section class="text-red-5 text-weight-bold text-subtitle2">Log Out</q-item-section>
        </q-item>
      </q-list>
    </q-card>
    </template>
    </main>
    
    <!-- OSAS Verification Dialog -->
    <q-dialog v-model="verificationDialog" position="bottom" :persistent="submitting || verifiedSuccess">
      <!-- Loading State -->
      <q-card v-if="submitting" class="full-width border-radius-24-top q-pa-xl pb-safe text-center">
        <q-circular-progress
          indeterminate
          size="56px"
          :thickness="0.15"
          color="teal-7"
          track-color="teal-1"
          class="q-mb-lg"
        />
        <div class="text-subtitle1 text-weight-bold text-dark line-height-tight q-mb-sm">Submitting documents...</div>
        <div class="text-caption text-grey-6 q-mb-md">Please wait a moment</div>
      </q-card>

      <!-- Verified Success State -->
      <q-card v-else-if="verifiedSuccess" class="full-width border-radius-24-top q-pa-xl pb-safe text-center">
        <div class="icon-circle bg-teal-1 text-teal-7 q-mx-auto q-mb-lg shadow-1" style="width: 72px; height: 72px;">
          <q-icon name="check_circle_outline" size="42px" />
        </div>
        <div class="text-h6 text-weight-bold text-dark line-height-tight q-mb-md">Documents Submitted!</div>
        <div class="text-caption text-grey-6 q-px-sm">
          OSAS will review your enrollment within 1–2 business days. You'll be notified once your QR code is active.
        </div>
      </q-card>

      <!-- Upload Form State -->
      <q-card v-else class="full-width border-radius-24-top q-pa-md pb-safe">
        <div class="row items-start justify-between q-mb-md">
          <div>
            <div class="text-h6 text-weight-bold line-height-tight">OSAS Verification</div>
            <div class="text-caption text-grey-6 q-mt-xs">Submit documents to verify your ISU enrollment.</div>
          </div>
          <q-btn flat round dense icon="close" color="grey-6" v-close-popup />
        </div>

        <!-- User Info Card -->
        <q-card flat class="bg-grey-1 border-radius-16 q-pa-md q-mb-md">
          <div class="row items-center">
            <q-avatar size="40px" color="blue-8" text-color="white" class="text-weight-bold text-subtitle2 shadow-1">
              {{ initials }}
            </q-avatar>
            <div class="q-ml-md col">
              <div class="text-subtitle2 text-weight-bold text-dark line-height-tight">
                {{ fullName }} · {{ studentId }}
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                {{ campus }} · {{ course }} · {{ yearLevel }}
              </div>
            </div>
          </div>
        </q-card>

        <!-- Assessment of Fees Upload -->
        <q-card flat bordered class="border-radius-16 q-mb-sm cursor-pointer upload-card" 
                :class="{'border-teal': assessmentFile}" 
                @click="assessmentRef.pickFiles()">
          <q-card-section class="q-pa-md row items-center">
            <div class="icon-circle border-grey q-mr-md" 
                 :class="{'bg-teal-1 text-teal-8 border-teal': assessmentFile}">
              <q-icon :name="assessmentFile ? 'check' : 'file_upload'" size="20px" :color="assessmentFile ? 'teal-8' : 'teal-5'" />
            </div>
            <div class="col">
              <div class="text-subtitle2 text-weight-bold text-dark line-height-tight">Assessment of Fees</div>
              <div class="text-caption text-grey-6 line-height-tight q-mt-xs">
                {{ assessmentFile ? assessmentFile.name : 'Current semester assessment from ISU registrar' }}
              </div>
            </div>
          </q-card-section>
          <q-file ref="assessmentRef" v-model="assessmentFile" style="display: none" accept="image/*,.pdf" />
        </q-card>

        <!-- School ID Upload -->
        <q-card flat bordered class="border-radius-16 q-mb-lg cursor-pointer upload-card" 
                :class="{'border-teal': schoolIdFile}" 
                @click="schoolIdRef.pickFiles()">
          <q-card-section class="q-pa-md row items-center">
            <div class="icon-circle border-grey q-mr-md" 
                 :class="{'bg-teal-1 text-teal-8 border-teal': schoolIdFile}">
              <q-icon :name="schoolIdFile ? 'check' : 'file_upload'" size="20px" :color="schoolIdFile ? 'teal-8' : 'teal-5'" />
            </div>
            <div class="col">
              <div class="text-subtitle2 text-weight-bold text-dark line-height-tight">School ID</div>
              <div class="text-caption text-grey-6 line-height-tight q-mt-xs">
                {{ schoolIdFile ? schoolIdFile.name : 'Valid ISU student ID for the current academic year' }}
              </div>
            </div>
          </q-card-section>
          <q-file ref="schoolIdRef" v-model="schoolIdFile" style="display: none" accept="image/*,.pdf" />
        </q-card>

        <!-- Submit Button -->
        <q-btn 
          unelevated 
          :color="isVerificationReady ? 'teal-4' : 'teal-3'" 
          :text-color="isVerificationReady ? 'white' : 'white'"
          :class="{'bg-teal-8': isVerificationReady}"
          label="Submit for Verification" 
          class="full-width border-radius-16 text-weight-bold q-py-sm q-mb-sm transition-all" 
          size="16px" 
          no-caps 
          :disable="!isVerificationReady"
          @click="submitVerification" 
        />
        <div class="text-center text-caption text-grey-5 q-mb-sm">
          Processing usually takes 1–2 business days.
        </div>
      </q-card>
    </q-dialog>

    <!-- Edit Profile Dialog -->
    <q-dialog v-model="editDialog" position="bottom">
      <q-card class="full-width border-radius-24-top q-pa-md pb-safe">
        <div class="row items-center justify-between q-mb-md">
          <div class="text-h6 text-weight-bold">Edit Profile</div>
          <q-btn flat round dense icon="close" color="grey-6" v-close-popup />
        </div>
        <div class="text-caption text-grey-6 q-mb-xs">Full Name</div>
        <q-input v-model="editFullName" outlined dense class="q-mb-md" placeholder="Your full name" />
        <div class="text-caption text-grey-6 q-mb-xs">Phone</div>
        <q-input v-model="editPhone" outlined dense class="q-mb-md" placeholder="+63..." />
        <div class="text-caption text-grey-6 q-mb-xs">Sex</div>
        <q-select
          v-model="editSex"
          outlined dense class="q-mb-lg"
          :options="[{ label: 'Male', value: 'M' }, { label: 'Female', value: 'F' }]"
          emit-value map-options clearable
        />
        <q-btn unelevated color="teal-8" label="Save Changes" class="full-width border-radius-16 text-weight-bold q-py-sm" no-caps :loading="savingProfile" @click="saveProfile" />
      </q-card>
    </q-dialog>

    <!-- Emergency Contact Dialog -->
    <q-dialog v-model="emergencyDialog" position="bottom">
      <q-card class="full-width border-radius-24-top q-pa-md pb-safe">
        <div class="row items-center justify-between q-mb-md">
          <div class="text-h6 text-weight-bold">Emergency Contact</div>
          <q-btn flat round dense icon="close" color="grey-6" v-close-popup />
        </div>
        <div class="text-caption text-grey-6 q-mb-xs">Full Name</div>
        <q-input v-model="emergencyName" outlined dense class="q-mb-md" placeholder="Contact name" />
        <div class="text-caption text-grey-6 q-mb-xs">Relationship</div>
        <q-input v-model="emergencyRelation" outlined dense class="q-mb-md" placeholder="e.g. Mother, Guardian" />
        <div class="text-caption text-grey-6 q-mb-xs">Phone</div>
        <q-input v-model="emergencyPhone" outlined dense class="q-mb-lg" placeholder="+63..." />
        <q-btn unelevated color="orange-9" label="Save Contact" class="full-width border-radius-16 text-weight-bold q-py-sm" no-caps :loading="savingEmergency" @click="saveEmergency" />
      </q-card>
    </q-dialog>

  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { supabase } from '@/shared/utils/supabase';
import { useAuthStore } from '@/stores/auth';
import { uploadDocument } from '@/shared/utils/upload';
import QRCode from 'qrcode';

interface UserRow {
  full_name: string | null;
  initials: string | null;
  email: string | null;
  phone: string | null;
  status: string | null;
  avatar_color: string | null;
  sex: string | null;
}

interface StudentProfileRow {
  student_id: string | null;
  program: string | null;
  college: string | null;
  year_level: number | null;
  emergency_contact_json: unknown;
  osas_verified_at: string | null;
  school_id_url: string | null;
  assessment_of_fees_url: string | null;
}

interface LeaseRow {
  id: string;
  status: string;
  start_date: string | null;
  end_date: string | null;
  monthly_rent: number | null;
  room: {
    room_number: string | null;
    accommodation: { name: string | null; address: string | null; rating_avg: number | null } | null;
  } | null;
}

const router = useRouter();
const $q = useQuasar();
const authStore = useAuthStore();

const loading = ref(true);
const error = ref<string | null>(null);

// Profile data (from Supabase, empty until loaded)
const initials = ref('U');
const fullName = ref('Student');
const studentId = ref('—');
const course = ref('—');
const campus = ref('ISU Echague');
const email = ref('—');
const contact = ref('—');
const verified = ref(false);
const osasVerified = ref(false);
const pendingReview = ref(false);
const sex = ref<string | null>(null);
const qrDataUrl = ref('');
const profileImageUrl = ref<string | null>(null);
const stayLabel = ref('—');
const yearLevel = ref('3rd Year'); // Default fallback

// OSAS Verification Dialog State
const verificationDialog = ref(false);
const submitting = ref(false);
const verifiedSuccess = ref(false);

const assessmentRef = ref<any>(null);
const schoolIdRef = ref<any>(null);
const assessmentFile = ref<File | null>(null);
const schoolIdFile = ref<File | null>(null);

// Edit Profile Dialog State
const editDialog = ref(false);
const savingProfile = ref(false);
const editFullName = ref('');
const editPhone = ref('');
const editSex = ref('');

// Emergency Contact Dialog State
const emergencyDialog = ref(false);
const savingEmergency = ref(false);
const emergencyName = ref('');
const emergencyRelation = ref('');
const emergencyPhone = ref('');

const isVerificationReady = computed(() => !!assessmentFile.value && !!schoolIdFile.value);

// Accommodation (from active lease)
const accommodation = ref({
  name: 'No active lease',
  address: '—',
  rating: 0,
  monthlyRent: '₱0.00',
  checkIn: '—',
  roomUnit: '—',
});

const stats = ref({ monthsPaid: '0/12', stay: '—', tenantScore: '—' });

// Emergency contact remains static-safe: parse from JSON if present
const emergency = ref({ name: 'Emergency Contact', relation: '—', phone: '—' });

const history = ref<{ id: number; name: string; address: string; dateRange: string; status: string; badgeColor: string; textColor?: string; dotColor: string; last: boolean }[]>([]);

function formatPeso(amount: number): string {
  return '\u20B1' + amount.toLocaleString('en-PH', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

function ordinal(n: number): string {
  const mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 13) return 'th';
  switch (n % 10) {
    case 1: return 'st';
    case 2: return 'nd';
    case 3: return 'rd';
    default: return 'th';
  }
}

function yearLevelLabel(y: number): string {
  return `${y}${ordinal(y)} Year`;
}

async function loadProfile() {
  loading.value = true;
  error.value = null;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { void router.push('/login'); return; }
    const metadata = user.user_metadata as Record<string, unknown> | undefined;
    const picture = typeof metadata?.avatar_url === 'string'
      ? metadata.avatar_url
      : (typeof metadata?.picture === 'string' ? metadata.picture : '');
    profileImageUrl.value = picture || null;

    // Fetch user + student profile + active lease in parallel
    const [userResult, profileResult, leaseResult] = await Promise.all([
      supabase.from('users').select('full_name, initials, email, phone, status, avatar_color, sex').eq('id', user.id).maybeSingle(),
      supabase.from('student_profiles').select('student_id, program, college, year_level, emergency_contact_json, osas_verified_at, school_id_url, assessment_of_fees_url').eq('user_id', user.id).maybeSingle(),
      (supabase as any).from('leases')
        .select('id, status, start_date, end_date, monthly_rent, room:rooms(room_number, accommodation:accommodations(name, address, rating_avg))')
        .eq('student_id', user.id).eq('status', 'active').maybeSingle(),
    ]);

    if (userResult.data) {
      const u = userResult.data as unknown as UserRow;
      fullName.value = u.full_name ?? 'Student';
      initials.value = u.initials ?? 'U';
      email.value = u.email ?? '—';
      contact.value = u.phone ?? '—';
      verified.value = u.status === 'verified';
      sex.value = u.sex ?? null;
    }

    let totalMonths = 12;
    if (profileResult.data) {
      const p = profileResult.data as unknown as StudentProfileRow;
      studentId.value = p.student_id ?? '—';
      course.value = p.program ?? '—';
      campus.value = p.college ? p.college.replace(/^.*\((.*)\)$/, '$1') : 'ISU Echague';
      osasVerified.value = !!p.osas_verified_at;
      // "Under review" = documents submitted but OSAS has not approved yet.
      pendingReview.value = !p.osas_verified_at && (!!p.school_id_url || !!p.assessment_of_fees_url);

      if (p.year_level) {
        yearLevel.value = yearLevelLabel(p.year_level);
      }

      if (p.emergency_contact_json) {
        try {
          const ec = p.emergency_contact_json as { name?: string; relation?: string; phone?: string };
          emergency.value = {
            name: ec.name ?? 'Emergency Contact',
            relation: ec.relation ?? '—',
            phone: ec.phone ?? '—',
          };
        } catch { /* ignore malformed JSON */ }
      }
    }

    // Accommodation from active lease
    if (leaseResult.data) {
      const l = leaseResult.data as unknown as LeaseRow;
      accommodation.value = {
        name: l.room?.accommodation?.name ?? 'Active lease',
        address: l.room?.accommodation?.address ?? '—',
        rating: l.room?.accommodation?.rating_avg ?? 0,
        monthlyRent: formatPeso(l.monthly_rent ?? 0),
        checkIn: l.start_date ? new Date(l.start_date).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' }) : '—',
        roomUnit: l.room?.room_number ? `Unit ${l.room.room_number}` : '—',
      };
      if (l.start_date && l.end_date) {
        const s = new Date(l.start_date);
        const e = new Date(l.end_date);
        totalMonths = Math.max(1, (e.getFullYear() - s.getFullYear()) * 12 + (e.getMonth() - s.getMonth()) + 1);
      }
      stayLabel.value = l.start_date
        ? new Date(l.start_date).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' })
        : '—';
    }

    // Derive profile stats from real data
    let paidCount = 0;
    let tenantScore = '—';
    if (leaseResult.data) {
      const leaseId = (leaseResult.data as unknown as LeaseRow).id;

      const { data: payments } = await supabase
        .from('payments')
        .select('id')
        .eq('lease_id', leaseId)
        .eq('status', 'paid');
      paidCount = payments?.length ?? 0;

      const { data: trev } = await supabase
        .from('tenant_reviews')
        .select('rating')
        .eq('lease_id', leaseId);
      const ratings = (trev ?? []).map((r) => (r as { rating: number }).rating);
      if (ratings.length > 0) {
        tenantScore = (ratings.reduce((a, b) => a + b, 0) / ratings.length).toFixed(1);
      }
    }

    stats.value = {
      monthsPaid: `${paidCount}/${totalMonths}`,
      stay: stayLabel.value,
      tenantScore,
    };

    // Boarding history (real)
    const { data: bh } = await (supabase as any)
      .from('boarding_history')
      .select('id, accommodation_name, period_start, period_end, room_type, end_reason')
      .eq('student_id', user.id)
      .order('period_start', { ascending: false });

    const rows = (bh ?? []) as unknown as Array<{
      id: string; accommodation_name: string | null; period_start: string; period_end: string; room_type: string | null; end_reason: string | null;
    }>;

    history.value = rows.map((h, i) => {
      const start = new Date(h.period_start).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' });
      const end = new Date(h.period_end).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' });
      const active = !h.end_reason;
      return {
        id: i + 1,
        name: h.accommodation_name ?? 'Boarding House',
        address: h.room_type ? `${h.room_type} room` : '—',
        dateRange: `${start} – ${end}`,
        status: active ? 'Current' : h.end_reason === 'evicted' ? 'Evicted' : 'Moved Out',
        badgeColor: active ? 'teal-1' : h.end_reason === 'evicted' ? 'red-1' : 'grey-3',
        textColor: active ? 'teal-7' : h.end_reason === 'evicted' ? 'red-5' : 'grey-7',
        dotColor: active ? '#00897B' : h.end_reason === 'evicted' ? '#EF5350' : '#BDBDBD',
        last: false,
      };
    });
    const lastRow = history.value.at(-1);
    if (lastRow) lastRow.last = true;

    // Generate the verification QR locally (no external service)
    if (osasVerified.value) {
      await generateQr();
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load profile';
  } finally {
    loading.value = false;
  }
}

function verifyNow() {
  verificationDialog.value = true;
}

function openEditProfile() {
  editFullName.value = fullName.value === 'Student' ? '' : fullName.value;
  editPhone.value = contact.value === '—' ? '' : contact.value;
  editSex.value = sex.value ?? '';
  editDialog.value = true;
}

async function saveProfile() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) { void router.push('/login'); return; }

  const name = editFullName.value.trim();
  if (!name) {
    $q.notify({ message: 'Full name is required.', color: 'warning', position: 'top', classes: 'custom-notify' });
    return;
  }

  savingProfile.value = true;
  try {
    const { error } = await supabase
      .from('users')
      .update({ full_name: name, phone: editPhone.value.trim() || '+639000000000', sex: editSex.value || null })
      .eq('id', user.id);
    if (error) throw error;
    editDialog.value = false;
    $q.notify({ message: 'Profile updated.', color: 'teal-8', position: 'top', classes: 'custom-notify', icon: 'check_circle' });
    await loadProfile();
  } catch (e) {
    $q.notify({ message: e instanceof Error ? e.message : 'Failed to update profile', color: 'negative', position: 'top', classes: 'custom-notify' });
  } finally {
    savingProfile.value = false;
  }
}

function openEmergency() {
  emergencyName.value = emergency.value.name === 'Emergency Contact' ? '' : emergency.value.name;
  emergencyRelation.value = emergency.value.relation === '—' ? '' : emergency.value.relation;
  emergencyPhone.value = emergency.value.phone === '—' ? '' : emergency.value.phone;
  emergencyDialog.value = true;
}

async function saveEmergency() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) { void router.push('/login'); return; }

  if (!emergencyName.value.trim()) {
    $q.notify({ message: 'Emergency contact name is required.', color: 'warning', position: 'top', classes: 'custom-notify' });
    return;
  }

  savingEmergency.value = true;
  try {
    const { error } = await supabase
      .from('student_profiles')
      .update({
        emergency_contact_json: {
          name: emergencyName.value.trim(),
          relation: emergencyRelation.value.trim() || null,
          phone: emergencyPhone.value.trim() || null,
        },
      })
      .eq('user_id', user.id);
    if (error) throw error;
    emergencyDialog.value = false;
    $q.notify({ message: 'Emergency contact saved.', color: 'teal-8', position: 'top', classes: 'custom-notify', icon: 'check_circle' });
    await loadProfile();
  } catch (e) {
    $q.notify({ message: e instanceof Error ? e.message : 'Failed to save emergency contact', color: 'negative', position: 'top', classes: 'custom-notify' });
  } finally {
    savingEmergency.value = false;
  }
}

function goNotifications() {
  void router.push('/student/notifications');
}

async function generateQr() {
  const id = studentId.value;
  if (!id || id === '—') {
    qrDataUrl.value = '';
    return;
  }
  try {
    qrDataUrl.value = await QRCode.toDataURL(id, {
      width: 160,
      margin: 1,
      color: { dark: '#111827', light: '#ffffff' },
    });
  } catch {
    qrDataUrl.value = '';
  }
}

async function submitVerification() {
  if (!assessmentFile.value || !schoolIdFile.value) {
    $q.notify({
      message: 'Please attach both your Assessment of Fees and School ID.',
      color: 'warning',
      position: 'top',
      classes: 'custom-notify',
      icon: 'error',
    });
    return;
  }

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) { void router.push('/login'); return; }

  submitting.value = true;
  try {
    // Upload both documents to the 'documents' storage bucket in parallel.
    const [assessmentUrl, schoolIdUrl] = await Promise.all([
      uploadDocument(assessmentFile.value, user.id, 'assessment'),
      uploadDocument(schoolIdFile.value, user.id, 'school_id'),
    ]);

    // Persist the document URLs on the student profile for OSAS review.
    const { error: profileError } = await supabase
      .from('student_profiles')
      .update({
        assessment_of_fees_url: assessmentUrl,
        school_id_url: schoolIdUrl,
      })
      .eq('user_id', user.id);

    if (profileError) throw profileError;

    // Add entries to the verification queue for OSAS admins. Best-effort: a
    // failure here must not fail the submission, since the profile URLs are
    // already persisted (and drive the "under review" state on reload).
    try {
      const { error: docError } = await supabase.from('verification_documents').insert([
        { user_id: user.id, doc_type: 'assessment_of_fees', file_url: assessmentUrl, filename: assessmentFile.value.name, status: 'pending' },
        { user_id: user.id, doc_type: 'school_id', file_url: schoolIdUrl, filename: schoolIdFile.value.name, status: 'pending' },
      ]);
      if (docError) console.warn('[profile] verification_documents insert skipped:', docError.message);
    } catch (e) {
      console.warn('[profile] verification_documents insert skipped:', e);
    }

    pendingReview.value = true;
    verifiedSuccess.value = true;

    // Give the user a moment to read the success message before closing.
    setTimeout(() => {
      verificationDialog.value = false;
      assessmentFile.value = null;
      schoolIdFile.value = null;
      verifiedSuccess.value = false;
      void loadProfile();
    }, 2500);
  } catch (e) {
    $q.notify({
      message: e instanceof Error ? e.message : 'Failed to submit documents',
      color: 'negative',
      position: 'top',
      classes: 'custom-notify',
      icon: 'error',
    });
  } finally {
    submitting.value = false;
  }
}

function callEmergency() {
  const phone = emergency.value.phone;
  if (!phone || phone === '—') {
    $q.notify({
      message: 'No phone number saved for this contact.',
      color: 'warning',
      position: 'top',
      classes: 'custom-notify',
      icon: 'call',
    });
    return;
  }
  window.location.href = 'tel:' + phone.replace(/[^+0-9]/g, '');
}

async function handleLogout() {
  authStore.clearCachedRole();
  await supabase.auth.signOut();
  void router.push('/login');
}

onMounted(loadProfile);
</script>

<style scoped>
.profile-page {
  min-height: 100vh;
  background: var(--m-bg);
  color: var(--m-text);
}

.profile-content {
  width: min(100%, 760px);
  margin: 0 auto;
  padding: var(--m-space-3) 0 var(--m-space-8);
}

.profile-gradient {
  background: linear-gradient(135deg, var(--m-primary-dark), var(--m-primary));
}

.profile-avatar {
  border: 4px solid var(--m-surface);
  background: var(--m-primary-dark);
  box-shadow: var(--m-shadow);
  cursor: pointer;
}

.camera-badge {
  bottom: 0px !important;
  right: 0px !important;
  top: auto !important;
  border: 2px solid var(--m-surface);
  width: 24px;
  height: 24px;
  border-radius: 50%;
}

.detail-box {
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  height: 100%;
}

.stat-card {
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}

.border-radius-24 { border-radius: var(--m-radius-lg); }
.border-radius-24-top { border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0; }
.border-radius-16 { border-radius: var(--m-radius); }

.shadow-soft {
  border: 1px solid var(--m-border);
  box-shadow: var(--m-shadow);
}

.icon-circle {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.qr-placeholder {
  width: 140px;
  height: 140px;
  border: 2px dashed var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
}

.emergency-box {
  border: 1px solid var(--m-border);
  background: var(--m-warning-soft);
  border-radius: var(--m-radius);
}

.bg-white-20 {
  background: rgba(255, 255, 255, 0.2);
}

.line-height-tight { line-height: 1.2; }
.letter-spacing-1 { letter-spacing: 0.5px; }
.text-xs { font-size: 11px; }
.font-size-32 { font-size: 32px; }
.font-size-18 { font-size: 18px; }

/* Timeline */
.timeline-item {
  display: flex;
}

.timeline-marker {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-right: 16px;
}

.timeline-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  flex-shrink: 0;
  margin-top: 4px;
}

.timeline-line {
  width: 1px;
  flex: 1;
  background: var(--m-border);
  margin: 4px 0;
}

.timeline-content {
  flex: 1;
  min-width: 0;
}

/* Upload Cards in Dialog */
.upload-card {
  transition: all 0.2s ease-in-out;
}
.upload-card:hover {
  background-color: #fcfcfc;
}
.border-grey {
  border: 1px solid var(--m-border);
}
.border-teal {
  border-color: var(--m-primary) !important;
}
.transition-all {
  transition: all 0.2s ease-in-out;
}

.profile-state {
  display: grid;
  min-height: 260px;
  place-items: center;
  align-content: center;
  gap: var(--m-space-3);
  padding: var(--m-space-6);
  color: var(--m-muted);
  text-align: center;
}
.profile-state--error { color: var(--m-danger); }
.profile-state-action { min-height: 44px; border-radius: var(--m-radius-sm); }
.shell-icon-button { min-width: 44px; min-height: 44px; }

:deep(.q-card) { color: var(--m-text); }
:deep(.q-item) { min-height: 60px; }
:deep(.q-btn:not(.q-btn--dense)) { min-height: 44px; }

@media (max-width: 420px) {
  .profile-content { padding-top: var(--m-space-3); }
  .stat-card :deep(.q-card__section) { padding: var(--m-space-3); }
  .emergency-box { align-items: flex-start; flex-wrap: wrap; gap: var(--m-space-3); }
  .emergency-box .q-btn { width: 100%; }
}

@media (prefers-reduced-motion: reduce) {
  .upload-card, .transition-all { transition: none; }
}
</style>
