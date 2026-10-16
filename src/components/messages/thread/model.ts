// A conversation's message rows, as read from the database and as shown.
import { type ChatMsg } from '@/utils/chat'

/** Newest page first; older pages on request. */
export const PAGE = 50
// One literal, so postgrest-js can type the rows.
export const MSG_COLS = 'id, body, sender_id, sent_at, status, attachment_url, edited_at, deleted_at, reply_to_id, reactions, accommodation_id'

export interface MsgRow {
  id: string
  body: string
  sender_id: string
  sent_at: string
  status: string
  attachment_url: string | null
  edited_at: string | null
  deleted_at: string | null
  reply_to_id: string | null
  reactions: unknown
  accommodation_id: string | null
}

/** `file` is passed in because signing replaces the ref that says so. */
export function toMsg(r: MsgRow, attachmentUrl: string | null | undefined, file: boolean): ChatMsg {
  return {
    id: r.id,
    body: r.body,
    senderId: r.sender_id,
    sentAt: r.sent_at,
    status: r.status,
    attachmentUrl: attachmentUrl || undefined,
    file,
    editedAt: r.edited_at,
    deletedAt: r.deleted_at,
    replyToId: r.reply_to_id,
    reactions: (r.reactions ?? {}) as Record<string, string>,
    accommodationId: r.accommodation_id,
  }
}

/** What the component hands its state: its props and emit. */
export interface Seed {
  props: { conversationId: string; role: 'manager' | 'student'; roomId?: string | undefined }
  emit: { (e: 'close'): void; (e: 'profile', userId: string): void }
}
