// The OSAS page's upload sheet, which serves both document sets: a property
// permit (accommodation_documents, versioned) and the landlord/landlady's own
// account documents (verification_documents, one row per type).
import { computed, ref, type Ref } from 'vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { uploadSecureDocument } from '@/utils/upload'
import { expiryProblem, savePermitVersion, uploadPermitFile } from '@/utils/permits'
import { accountDocItem, latestSignedDocs, type AccountDocRow } from '@/utils/profile'
import type { RequirementItem } from '@/components/shared/RequirementCards.vue'
import type { DocUpload } from '@/components/manager/DocUploadModal.vue'

// Fixed set uploaded once at landlord/landlady registration (stores/auth.ts,
// submitManagerVerificationDocuments) — OSAS reviews these per-document via
// doc_status, independent of any accommodation.
const MY_DOC_TYPES = ['government_id', 'business_permit'] as const

export function useOsasUploads(ctx: {
  myId: Ref<string>
  myStatus: Ref<string>
  selectedId: Ref<string>
  loadPermits: () => Promise<void>
  signPermits: (accommodationId: string) => Promise<void>
}) {
  const { myId, myStatus, selectedId, loadPermits, signPermits } = ctx
  const notify = useNotify()
  const uploadingDoc = ref(false)

  // A permit already on file is view-only — replacing it goes through this
  // dialog's own blank form, never an inline field on the (read-only) row.
  const uploadDialogOpen = ref(false)
  const uploadDocType = ref('')
  /**
   * The upload sheet serves both document sets. A property permit goes to
   * `accommodation_documents` against the selected accommodation; an account
   * document goes to `verification_documents` against this landlord/landlady. They differ
   * in where the row lands, not in what is collected, so they share one form.
   */
  type UploadTarget = 'property' | 'account'
  const uploadTarget = ref<UploadTarget>('property')

  const myDocRows = ref<AccountDocRow[]>([])
  const uploadingMyDoc = ref(false)

  const myDocs = computed<RequirementItem[]>(() =>
    MY_DOC_TYPES.map((type) => accountDocItem(type, myDocRows.value.find((d) => d.doc_type === type), myStatus.value)),
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

  function openUploadDialog(type: string, target: UploadTarget = 'property') {
    uploadDocType.value = type
    uploadTarget.value = target
    uploadDialogOpen.value = true
  }

  async function submitDocUpload(uploadForm: DocUpload) {
    if (!uploadForm.file) {
      notify.error('Choose a file.')
      return
    }
    if (!uploadForm.expiresAt) {
      notify.error('Pick an expiration date.')
      return
    }
    if (uploadTarget.value === 'account') {
      await submitMyDocUpload(uploadForm)
      return
    }
    if (!selectedId.value) return
    const expiryError = expiryProblem(uploadForm.expiresAt)
    if (expiryError) {
      notify.error(expiryError)
      return
    }

    uploadingDoc.value = true
    try {
      // The same path as the wizard and the listing's Replace button: checked
      // for legibility, shrunk, hashed, saved as the next version (utils/permits).
      const uploaded = await uploadPermitFile(uploadForm.file)
      await savePermitVersion(selectedId.value, uploadDocType.value, uploaded, uploadForm.expiresAt)

      await loadPermits()
      await signPermits(selectedId.value)
      uploadDialogOpen.value = false
      notify.success('Uploaded.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not upload this document.'))
    } finally {
      uploadingDoc.value = false
    }
  }

  /**
   * An account document — government ID or business permit — now goes through the
   * same sheet as a property permit, so it carries an expiry date. It used to be
   * a bare file input that wrote the row immediately, which meant OSAS could see
   * a landlord/landlady's permit had been approved but not that it had since lapsed.
   */
  async function submitMyDocUpload(uploadForm: DocUpload) {
    const file = uploadForm.file
    if (!file || !myId.value) return
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

      // A rejected account has to be put back in the queue, or the re-upload is
      // never looked at. No-ops for any other status.
      const { error: resubmitError } = await supabase.rpc('resubmit_verification')
      if (resubmitError) throw resubmitError
      if (myStatus.value === 'rejected' || myStatus.value === 'needs_resubmission') myStatus.value = 'pending'

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
    uploadingDoc, uploadDialogOpen, uploadDocType, uploadTarget, uploadingMyDoc, myDocs, loadMyDocs,
    openUploadDialog, submitDocUpload,
  }
}
