// The OSAS page's upload sheet for the landlord/landlady's own account
// documents (verification_documents, one row per type). Property permits are
// only viewed on the OSAS page; they are uploaded from the listing's Settings.
import { computed, ref, type Ref } from 'vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { uploadSecureDocument } from '@/utils/upload'
import { accountDocItem, isSentBack, latestSignedDocs, resubmitVerification, type AccountDocRow } from '@/utils/profile'
import type { RequirementItem } from '@/components/shared/RequirementCards.vue'
import type { DocUpload } from '@/components/manager/DocUploadModal.vue'

// Fixed set uploaded once at landlord/landlady registration (stores/auth.ts,
// submitManagerVerificationDocuments) — OSAS reviews these per-document via
// doc_status, independent of any accommodation.
export const MY_DOC_TYPES = ['government_id', 'business_permit'] as const

export function useOsasUploads(ctx: { myId: Ref<string>; myStatus: Ref<string>; decidedAt: Ref<string | null> }) {
  const { myId, myStatus, decidedAt } = ctx
  const notify = useNotify()

  // A document already on file is view-only — replacing it goes through this
  // dialog's own blank form, never an inline field on the (read-only) row.
  const uploadDialogOpen = ref(false)
  const uploadDocType = ref('')

  const myDocRows = ref<AccountDocRow[]>([])
  const uploadingMyDoc = ref(false)

  const myDocs = computed<RequirementItem[]>(() =>
    MY_DOC_TYPES.map((type) => accountDocItem(type, myDocRows.value.find((d) => d.doc_type === type), myStatus.value, decidedAt.value)),
  )

  async function loadMyDocs(userId: string) {
    const { data, error: docError } = await supabase
      .from('verification_documents')
      .select('id, doc_type, file_url, filename, status, uploaded_at, verified_at')
      .eq('user_id', userId)
      .order('uploaded_at', { ascending: false })
    if (docError) throw docError
    myDocRows.value = (await latestSignedDocs(data)) as AccountDocRow[]
  }

  function openUploadDialog(type: string) {
    uploadDocType.value = type
    uploadDialogOpen.value = true
  }

  /**
   * An account document — government ID or business permit — goes through the
   * same sheet a property permit does, so it carries an expiry date. It used to be
   * a bare file input that wrote the row immediately, which meant OSAS could see
   * a landlord/landlady's permit had been approved but not that it had since lapsed.
   */
  async function submitDocUpload(uploadForm: DocUpload) {
    const file = uploadForm.file
    if (!file) {
      notify.error('Choose a file.')
      return
    }
    if (!uploadForm.expiresAt) {
      notify.error('Pick an expiration date.')
      return
    }
    if (!myId.value) return
    uploadingMyDoc.value = true
    try {
      const docType = uploadDocType.value
      const url = await uploadSecureDocument(file)

      // Resubmission replaces the same row rather than adding a duplicate —
      // verification_documents has no version column to disambiguate "latest"
      // the way accommodation_documents does, and (user_id, doc_type) is unique.
      // The find-then-update-or-insert this replaced only caught a duplicate the
      // page had already loaded; the constraint catches every case.
      const { error: writeError } = await supabase.from('verification_documents').upsert(
        {
          user_id: myId.value,
          doc_type: docType,
          file_url: url,
          filename: file.name,
          status: 'pending' as const,
          expires_at: uploadForm.expiresAt,
          uploaded_at: new Date().toISOString(),
          verified_at: null,
        },
        { onConflict: 'user_id,doc_type' },
      )
      if (writeError) throw writeError

      // A sent-back account goes back to OSAS only when its owner says so (the
      // Resubmit button, AccountReviewStatus), like a sent-back listing. Any
      // other status: puts a first upload in the queue, or no-ops.
      if (!isSentBack(myStatus.value)) await resubmitVerification()

      await loadMyDocs(myId.value)
      uploadDialogOpen.value = false
      notify.success('Uploaded.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not upload this document.'))
    } finally {
      uploadingMyDoc.value = false
    }
  }

  return {
    uploadDialogOpen, uploadDocType, uploadingMyDoc, myDocRows, myDocs, loadMyDocs, openUploadDialog, submitDocUpload,
  }
}
