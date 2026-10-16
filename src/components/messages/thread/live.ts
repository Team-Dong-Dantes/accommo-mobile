// The conversation's realtime channel: new and changed messages, typing, and
// the application card's refresh. Opened on mount, closed on unmount.
import { MSG_COLS, type MsgRow, toMsg } from './model'
import { type RealtimeChannel } from '@supabase/supabase-js'
import { type Seed } from './model'
import { isFileRef } from '@/utils/chat'
import { onMounted, onUnmounted } from 'vue'
import { signRef } from '@/utils/upload'
import { supabase } from '@/utils/supabase'
import type { createMessages } from './messages'
import type { createCompose } from './compose'

export function createLive(ctx: Seed & ReturnType<typeof createMessages> & ReturnType<typeof createCompose>) {
  const { props, outgoing, me, otherId, menu, applicationCard, otherTyping, findMsg, toBottom, fillReplies, fillListings, load, upsertMessage } = ctx
  let refreshCardTimer: ReturnType<typeof setTimeout> | null = null

  function refreshCardSoon() {
    if (refreshCardTimer) clearTimeout(refreshCardTimer)
    refreshCardTimer = setTimeout(() => {
      refreshCardTimer = null
      void applicationCard.value?.refresh()
    }, 1500)
  }

  let channel: RealtimeChannel | null = null
  let typingSendAt = 0
  let typingClearTimer: ReturnType<typeof setTimeout> | null = null

  async function postSystemMessage(body: string) {
    const { data, error: sendError } = await supabase
      .from('messages')
      .insert({ conversation_id: props.conversationId, sender_id: me.value, body })
      .select(MSG_COLS)
      .single()
    if (sendError) throw sendError
    upsertMessage(toMsg(data, null, false))
    void toBottom()
  }

  async function listen() {
    if (typeof supabase.channel !== 'function') return

    // supabase-js hands back the EXISTING channel for a topic, and .on() throws
    // once that channel has subscribed. Re-opening the same thread lands exactly
    // there: MessagesPage is kept alive, so this component can remount before the
    // previous instance's removeChannel() has finished. Drop any leftover on this
    // topic and WAIT for it, rather than racing it.
    //
    // The topic cannot be made unique per mount — both participants have to share
    // it for the typing broadcast to reach the other side.
    const topic = `messages:${props.conversationId}`
    if (typeof supabase.getChannels === 'function') {
      await Promise.all(
        supabase
          .getChannels()
          .filter((c) => c.topic === topic || c.topic === `realtime:${topic}`)
          .map((c) => supabase.removeChannel(c)),
      )
    }

    channel = supabase
      .channel(topic)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'messages',
          filter: `conversation_id=eq.${props.conversationId}`,
        },
        async (payload) => {
          if (payload.eventType === 'INSERT') {
            const row = payload.new as MsgRow
            upsertMessage(
              toMsg(row, await signRef('messages', row.id, row.attachment_url), isFileRef(row.attachment_url)),
            )
            void fillReplies()
            void fillListings()
            void toBottom()
            // Their message arrived while the thread is open, so it is read.
            if (row.sender_id !== me.value) {
              void supabase.rpc('mark_conversation_read', {
                p_conversation: props.conversationId,
              }).then(() => undefined, () => undefined)
              // Every step of the tenancy handshake posts a system message, so an
              // incoming one is the cue that the card above may have changed: the
              // form was issued, an application arrived, or it was decided. Without
              // this the other side reads "Sent you an application form" and then
              // has to reopen the thread before the form actually appears.
              refreshCardSoon()
            }
          } else if (payload.eventType === 'UPDATE') {
            // Ticks, edits, unsends and reactions. The signed photo link is kept:
            // the stored value is a ref, and it only ever changes by being removed.
            const row = payload.new as MsgRow
            const found = findMsg(row.id)
            if (!found) return
            Object.assign(found, {
              status: row.status,
              body: row.body,
              editedAt: row.edited_at,
              deletedAt: row.deleted_at,
              reactions: (row.reactions ?? {}) as Record<string, string>,
            })
            if (row.deleted_at) Object.assign(found, { attachmentUrl: undefined, accommodationId: null })
            if (row.deleted_at && menu.value?.msg.id === row.id) menu.value = null
          }
        },
      )
      // Ephemeral typing signal — broadcast, not a DB write, so it never
      // touches `messages` and there's nothing to clean up if it's missed.
      .on('broadcast', { event: 'typing' }, (msg) => {
        const from = (msg.payload as { from?: string } | undefined)?.from
        if (from !== otherId.value) return
        otherTyping.value = true
        if (typingClearTimer) clearTimeout(typingClearTimer)
        typingClearTimer = setTimeout(() => { otherTyping.value = false }, 3000)
      })
      .subscribe()
  }

  // Fires at most once every ~1.5s while the user is actively typing, so a
  // whole sentence doesn't turn into a broadcast per keystroke.
  function notifyTyping() {
    if (!channel || !outgoing.value.trim()) return
    const now = Date.now()
    if (now - typingSendAt < 1500) return
    typingSendAt = now
    void channel.send({ type: 'broadcast', event: 'typing', payload: { from: me.value } })
  }

  onMounted(async () => {
    await load()
    await listen()
  })

  onUnmounted(() => {
    if (channel) {
      void supabase.removeChannel(channel)
      channel = null
    }
    if (typingClearTimer) clearTimeout(typingClearTimer)
    if (refreshCardTimer) clearTimeout(refreshCardTimer)
  })

  return {
    refreshCardTimer,
    refreshCardSoon,
    channel,
    typingSendAt,
    typingClearTimer,
    postSystemMessage,
    listen,
    notifyTyping,
  }
}
