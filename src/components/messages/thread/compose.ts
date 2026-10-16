// Writing: attachments, sending (with a reply or a listing), editing, and the
// long-press menu — copy, unsend, react.
import { type ChatMsg, canChange } from '@/utils/chat'
import { MSG_COLS, toMsg } from './model'
import { type MenuAction } from '@/components/messages/MessageMenu.vue'
import { type Seed } from './model'
import { capturePhoto } from '@/utils/camera'
import { computed } from 'vue'
import { confirmAction } from '@/utils/confirmAction'
import { errorMessage } from '@/utils/errors'
import { signRef, uploadSecureDocument } from '@/utils/upload'
import { supabase } from '@/utils/supabase'
import type { createMessages } from './messages'

export function createCompose(ctx: Seed & ReturnType<typeof createMessages>) {
  const { props, notify, error, sending, outgoing, attachMenuOpen, pickerOpen, fileInputRef, pdfInputRef, inputRef, me, messages, replyTo, editing, menu, findMsg, toBottom, fillListings, upsertMessage } = ctx
  function onAttach(e: Event) {
    const input = e.target as HTMLInputElement
    const file = input.files?.[0]
    input.value = ''
    if (file) void send({ file })
  }

  async function takePhoto() {
    const { file, error } = await capturePhoto()
    if (error) notify.error(error)
    if (file) void send({ file })
  }

  function onTakePhotoClick() {
    attachMenuOpen.value = false
    void takePhoto()
  }

  function onUploadClick() {
    attachMenuOpen.value = false
    fileInputRef.value?.click()
  }

  function onFileClick() {
    attachMenuOpen.value = false
    pdfInputRef.value?.click()
  }

  function onListingClick() {
    attachMenuOpen.value = false
    pickerOpen.value = true
  }

  function shareListing(id: string) {
    pickerOpen.value = false
    void send({ accommodationId: id })
  }

  function cancelCompose() {
    if (editing.value) outgoing.value = ''
    editing.value = null
    replyTo.value = null
  }

  function submit() {
    void (editing.value ? saveEdit() : send())
  }

  /**
   * Text, a photo, a PDF or a listing card — whatever is typed goes along with
   * the attachment, as it always has for photos.
   */
  async function send(extra: { file?: File; accommodationId?: string } = {}) {
    const body = outgoing.value.trim()
    const { file, accommodationId } = extra
    if ((!body && !file && !accommodationId) || sending.value || !me.value) return

    sending.value = true
    outgoing.value = ''
    const reply = replyTo.value
    replyTo.value = null
    const isFile = file?.type === 'application/pdf'

    // Optimistic: the bubble appears at once (a local object URL stands in for
    // the attachment until the real Cloudinary URL comes back) and is replaced
    // by the row the insert returns, so a slow network never looks dropped.
    const tempId = `pending-${Date.now()}`
    const localPreview = file && !isFile ? URL.createObjectURL(file) : undefined
    messages.value.push({
      id: tempId,
      body,
      senderId: me.value,
      sentAt: new Date().toISOString(),
      status: 'sent',
      pending: true,
      attachmentUrl: localPreview,
      file: isFile,
      replyToId: reply?.id ?? null,
      accommodationId: accommodationId ?? null,
    })
    void toBottom()
    if (accommodationId) void fillListings()

    try {
      let attachmentUrl: string | null = null
      if (file) {
        // Chat photos are private: the row stores a cld: ref, readable only
        // through a signed link.
        attachmentUrl = await uploadSecureDocument(file)
      }

      const { data, error: sendError } = await supabase
        .from('messages')
        .insert({
          conversation_id: props.conversationId,
          sender_id: me.value,
          body,
          attachment_url: attachmentUrl,
          reply_to_id: reply?.id ?? null,
          accommodation_id: accommodationId ?? null,
        })
        .select(MSG_COLS)
        .single()
      if (sendError) throw sendError

      // Keep showing the local copy of a photo: the stored value is a ref, not a
      // URL. A PDF has no local copy worth opening, so it gets its signed link.
      const shown = isFile ? await signRef('messages', data.id, data.attachment_url) : localPreview
      upsertMessage(toMsg(data, data.attachment_url ? shown : undefined, isFile), tempId)

      // No notification row for a chat message. tg_message_after_insert already
      // bumps conversations.unread_a/unread_b, which is what the Messages tab
      // badge reads — a bell row on top of that is a second unread counter for
      // the same event, on a screen you have to leave the chat to reach.
    } catch (e) {
      messages.value = messages.value.filter((m) => m.id !== tempId)
      if (localPreview) URL.revokeObjectURL(localPreview)
      outgoing.value = body
      replyTo.value = reply
      error.value = errorMessage(e, file ? (isFile ? 'File not sent.' : 'Photo not sent.') : accommodationId ? 'Listing not shared.' : 'Message not sent.')
    } finally {
      sending.value = false
    }
  }

  async function saveEdit() {
    const target = editing.value
    const body = outgoing.value.trim()
    if (!target || !body || sending.value) return
    if (body === target.body) {
      cancelCompose()
      return
    }
    sending.value = true
    try {
      const { data, error: e } = await supabase
        .from('messages')
        .update({ body })
        .eq('id', target.id)
        .select('body, edited_at')
        .single()
      if (e) throw e
      target.body = data.body
      target.editedAt = data.edited_at
      editing.value = null
      outgoing.value = ''
    } catch (e) {
      notify.error(errorMessage(e, 'Could not edit that message.'))
    } finally {
      sending.value = false
    }
  }

  /* ---- Message actions ----------------------------------------------------- */

  function openMenu(id: string, el: HTMLElement) {
    const msg = findMsg(id)
    if (!msg || msg.pending || msg.deletedAt) return
    menu.value = { msg, rect: el.getBoundingClientRect() }
  }

  const menuActions = computed<MenuAction[]>(() => {
    const m = menu.value?.msg
    if (!m) return []
    // Edit and unsend close CHANGE_WINDOW_MS after sending (DB-enforced too).
    const mine = m.senderId === me.value && canChange(m)
    const actions: MenuAction[] = [{ key: 'reply', label: 'Reply', icon: 'lucide:reply' }]
    if (m.body) actions.push({ key: 'copy', label: 'Copy', icon: 'lucide:copy' })
    if (mine && m.body) actions.push({ key: 'edit', label: 'Edit', icon: 'lucide:pencil' })
    if (mine) actions.push({ key: 'unsend', label: 'Unsend', icon: 'lucide:trash-2', danger: true })
    return actions
  })

  function onPick(key: string) {
    const m = menu.value?.msg
    menu.value = null
    if (!m) return
    if (key === 'reply') {
      editing.value = null
      replyTo.value = m
      inputRef.value?.focus()
    } else if (key === 'copy') {
      void copy(m.body)
    } else if (key === 'edit') {
      replyTo.value = null
      editing.value = m
      outgoing.value = m.body
      inputRef.value?.focus()
    } else if (key === 'unsend') {
      void unsend(m)
    }
  }

  function onMenuReact(emoji: string) {
    const m = menu.value?.msg
    menu.value = null
    if (m) void react(m.id, emoji)
  }

  async function copy(text: string) {
    try {
      await navigator.clipboard.writeText(text)
      notify.success('Copied')
    } catch {
      notify.error('Could not copy that message.')
    }
  }

  async function unsend(m: ChatMsg) {
    const ok = await confirmAction({
      title: 'Unsend this message?',
      message: 'It is removed for both of you. This cannot be undone.',
      confirmLabel: 'Unsend',
    })
    if (!ok) return
    // The trigger stamps the real time and clears the content; this just asks.
    const { error: e } = await supabase.from('messages').update({ deleted_at: new Date().toISOString() }).eq('id', m.id)
    if (e) {
      notify.error(errorMessage(e, 'Could not unsend that message.'))
      return
    }
    if (editing.value?.id === m.id) cancelCompose()
    Object.assign(m, { deletedAt: new Date().toISOString(), body: '', attachmentUrl: undefined, accommodationId: null, reactions: {} })
  }

  /** '' takes my reaction off. Optimistic; rolled back if the RPC refuses. */
  async function react(id: string, emoji: string) {
    const m = findMsg(id)
    if (!m || m.pending || m.deletedAt) return
    const before = m.reactions ?? {}
    const next = { ...before }
    if (emoji) next[me.value] = emoji
    else delete next[me.value]
    m.reactions = next
    const { error: e } = await supabase.rpc('react_to_message', { p_message: id, p_emoji: emoji })
    if (e) {
      m.reactions = before
      notify.error(errorMessage(e, 'Could not react to that message.'))
    }
  }

  /* ---- Loading ------------------------------------------------------------- */

  return {
    onAttach,
    takePhoto,
    onTakePhotoClick,
    onUploadClick,
    onFileClick,
    onListingClick,
    shareListing,
    cancelCompose,
    submit,
    send,
    saveEdit,
    openMenu,
    menuActions,
    onPick,
    onMenuReact,
    copy,
    unsend,
    react,
  }
}
