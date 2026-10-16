import { defineStore } from 'pinia'
import type { RealtimeChannel } from '@supabase/supabase-js'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { initialsOf, parseServerTime } from '@/utils/format'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { showNotice } from '@/utils/inAppNotice'

export interface Thread {
  id: string;
  otherId: string;
  otherName: string;
  otherInitials: string;
  otherColor: string | null;
  otherAvatarUrl: string | null;
  lastMessage: string;
  /** Who sent it — null when the thread has no messages at all. */
  lastSenderId: string | null;
  lastTime: string | null;
  unread: number;
  /** This person's own view of the thread — conversation_prefs. */
  pinned: boolean;
  muted: boolean;
  /** Archived until something newer than this arrives. */
  archivedAt: string | null;
}

export type ThreadPref = Partial<Pick<Thread, 'pinned' | 'muted' | 'archivedAt'>>;

/** An archived thread comes back on its own when a newer message lands. */
export function isArchived(t: Thread): boolean {
  return !!t.archivedAt && new Date(t.archivedAt).getTime() >= toMs(t.lastTime)
}

interface Person {
  full_name: string | null;
  initials: string | null;
  avatar_color: string | null;
  avatar_url: string | null;
}

// Live connections, not reactive state — see stores/notifications.ts.
let channel: RealtimeChannel | null = null
let deliveryChannel: RealtimeChannel | null = null

/**
 * The reactions last seen on each of my messages, to tell a new one from an
 * update that only moved a read tick. Realtime cannot say: with RLS on, an
 * UPDATE's `old` row carries the primary key and nothing else.
 *
 * ponytail: seeded when the message is sent or first updated this session, so a
 * reaction that is itself the first update seen for an older message is taken
 * as the baseline and not announced. In practice the read tick lands first.
 * Exact would need the server to broadcast the reaction (realtime.send).
 */
const seenReactions = new Map<string, string[]>()

/**
 * A user id that is safe to paste into a PostgREST filter string.
 *
 * `.or()` takes a filter expression, not bound parameters, so an id carrying a
 * comma or a bracket rewrites the expression around it rather than being
 * compared to anything. `otherId` arrives from a route parameter, which the user
 * picks. RLS still decides what any resulting query may see, so this was never a
 * way to read someone else's mail — but a filter is no place for unchecked text,
 * and every id in this file is a uuid with nothing to lose by saying so.
 */
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

function requireUuid(value: string, what: string): string {
  if (!UUID_RE.test(value)) throw new Error(`Invalid ${what}.`)
  return value
}

function toMs(lastTime: string | null): number {
  return lastTime ? parseServerTime(lastTime).getTime() : 0
}

/** Pinned threads first, then by latest message. */
function newestFirst(a: Thread, b: Thread) {
  return Number(b.pinned) - Number(a.pinned) || toMs(b.lastTime) - toMs(a.lastTime)
}

export const useMessagesStore = defineStore('messages', {
  state: () => ({
    threads: [] as Thread[],
    loading: false,
    error: '',
    userId: '',
    ready: false,
  }),

  getters: {
    totalUnread: (state) => state.threads.reduce((n, t) => n + t.unread, 0),
  },

  actions: {
    async load(userId: string) {
      this.loading = true
      this.error = ''
      try {
        requireUuid(userId, 'account')
        // Whatever arrived while this device was offline counts as delivered now.
        void supabase.rpc('mark_messages_delivered').then(() => undefined, () => undefined)
        const [{ data, error }, { data: prefRows }] = await Promise.all([
          supabase
            .from('conversations')
            // One string literal: postgrest-js parses the select at type level,
            // and a concatenated expression widens to `string` and stops typing.
            .select('id,user_a_id,user_b_id,last_message,last_sender_id,last_time,unread_a,unread_b,a:users!conversations_user_a_id_fkey(full_name,initials,avatar_color,avatar_url),b:users!conversations_user_b_id_fkey(full_name,initials,avatar_color,avatar_url)')
            .or(`user_a_id.eq.${userId},user_b_id.eq.${userId}`),
          // Prefs are a nicety: if they fail the inbox still loads, unpinned.
          supabase.from('conversation_prefs').select('conversation_id,pinned,muted,archived_at'),
        ])
        if (error) throw error
        const prefs = new Map((prefRows ?? []).map((p) => [p.conversation_id, p]))

        this.threads = (data ?? [])
          .map((row) => {
            const mine = row.user_a_id === userId
            const other = (mine ? row.b : row.a) as unknown as Person | null
            const name = other?.full_name || 'Unknown'
            return {
              id: row.id,
              otherId: mine ? row.user_b_id : row.user_a_id,
              otherName: name,
              otherInitials: other?.initials || initialsOf(name),
              otherColor: other?.avatar_color ?? null,
              otherAvatarUrl: other?.avatar_url ? resolveAsset(other.avatar_url) : null,
              lastMessage: row.last_message || '',
              lastSenderId: row.last_sender_id ?? null,
              lastTime: row.last_time,
              unread: Number((mine ? row.unread_a : row.unread_b) || 0),
              pinned: prefs.get(row.id)?.pinned ?? false,
              muted: prefs.get(row.id)?.muted ?? false,
              archivedAt: prefs.get(row.id)?.archived_at ?? null,
            }
          })
          .sort(newestFirst)
        this.ready = true
      } catch (e) {
        this.error = errorMessage(e, 'Could not load conversations.')
      } finally {
        this.loading = false
      }
    },

    async start(userId: string) {
      if (this.userId === userId && channel) return
      this.stop()
      this.userId = userId
      await this.load(userId)

      if (typeof supabase.channel !== 'function') return

      // postgres_changes has no OR, so each side of the pair is its own binding.
      const onChange = (payload: { eventType: string; new: Record<string, unknown> }) => {
        if (payload.eventType === 'INSERT') {
          // A brand new thread needs the counterpart's name, which the payload
          // does not carry, so this is the one case worth a refetch.
          void this.load(userId)
          return
        }
        const row = payload.new as {
          id: string;
          user_a_id: string;
          last_message: string | null;
          last_sender_id: string | null;
          last_time: string | null;
          unread_a: number;
          unread_b: number;
        }
        const unread = Number((row.user_a_id === userId ? row.unread_a : row.unread_b) || 0)
        // Something new from them: the unread count went up on a message I did
        // not send. A muted thread stays quiet here as it does on the phone.
        const announce = (t: Thread, before: number) => {
          if (row.last_sender_id && row.last_sender_id !== userId && unread > before && !t.muted) {
            showNotice({
              key: `thread:${t.id}`,
              type: 'message',
              title: t.otherName,
              body: row.last_message || 'Sent an attachment',
              threadId: t.id,
            })
          }
        }
        const thread = this.threads.find((t) => t.id === row.id)
        if (!thread) {
          // A first message from someone new: the thread has to be loaded for
          // their name before there is anything to show.
          void this.load(userId).then(() => {
            const t = this.threads.find((x) => x.id === row.id)
            if (t) announce(t, 0)
          })
          return
        }
        announce(thread, thread.unread)
        thread.lastMessage = row.last_message || ''
        thread.lastSenderId = row.last_sender_id ?? null
        thread.lastTime = row.last_time
        thread.unread = unread
        this.threads.sort(newestFirst)
      }

      channel = supabase
        .channel(`conversations:${userId}`)
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'conversations', filter: `user_a_id=eq.${userId}` },
          onChange,
        )
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'conversations', filter: `user_b_id=eq.${userId}` },
          onChange,
        )
        .subscribe()

      // Marks an incoming message 'delivered' the moment this device receives
      // it, even outside the thread it belongs to (ChatThread's own listener
      // already marks 'read' when that specific thread is open — the
      // status='sent' guard in the RPC means this can never clobber that).
      //
      // This was a plain update, which messages_update_own (sender only)
      // refused without an error, so the double tick only ever showed on read.
      deliveryChannel = supabase
        .channel(`deliveries:${userId}`)
        .on(
          'postgres_changes',
          { event: 'INSERT', schema: 'public', table: 'messages' },
          (payload) => {
            const row = payload.new as { id: string; conversation_id: string; sender_id: string }
            if (row.sender_id === userId) {
              seenReactions.set(row.id, [])
              return
            }
            if (!this.threads.some((t) => t.id === row.conversation_id)) return
            void supabase.rpc('mark_messages_delivered').then(() => undefined, () => undefined)
          },
        )
        // A reaction to one of my messages: someone appears in its reactions
        // who was not there last time (see seenReactions).
        .on(
          'postgres_changes',
          { event: 'UPDATE', schema: 'public', table: 'messages', filter: `sender_id=eq.${userId}` },
          (payload) => {
            const row = payload.new as { id: string; conversation_id: string; reactions: Record<string, string> | null }
            const now = Object.keys(row.reactions ?? {}).filter((uid) => uid !== userId)
            const before = seenReactions.get(row.id)
            seenReactions.set(row.id, now)
            const added = before && now.find((uid) => !before.includes(uid))
            if (!added) return
            const thread = this.threads.find((t) => t.id === row.conversation_id)
            if (!thread || thread.muted) return
            showNotice({
              key: `react:${row.id}`,
              type: 'message',
              title: thread.otherName,
              body: `Reacted ${row.reactions![added]} to your message`,
              threadId: thread.id,
            })
          },
        )
        .subscribe()
    },

    stop() {
      if (channel) {
        void supabase.removeChannel(channel)
        channel = null
      }
      if (deliveryChannel) {
        void supabase.removeChannel(deliveryChannel)
        deliveryChannel = null
      }
      seenReactions.clear()
      this.userId = ''
      this.ready = false
    },

    /** Pin, mute or archive — mine only; optimistic, reverted if the write fails. */
    async setPref(conversationId: string, patch: ThreadPref) {
      const thread = this.threads.find((t) => t.id === conversationId)
      if (!thread) return
      const before = { pinned: thread.pinned, muted: thread.muted, archivedAt: thread.archivedAt }
      Object.assign(thread, patch)
      this.threads.sort(newestFirst)
      const { error } = await supabase.from('conversation_prefs').upsert({
        conversation_id: conversationId,
        user_id: requireUuid(this.userId, 'account'),
        pinned: thread.pinned,
        muted: thread.muted,
        archived_at: thread.archivedAt,
      })
      if (error) {
        Object.assign(thread, before)
        this.threads.sort(newestFirst)
        throw error
      }
    },

    /** Clears the local badge; the RPC has already zeroed it server-side. */
    clearUnread(conversationId: string) {
      const thread = this.threads.find((t) => t.id === conversationId)
      if (thread) thread.unread = 0
    },

    /**
     * The id of the thread with `otherId`, creating it if this is a first
     * enquiry. Every existing row puts the student in user_a, so that
     * convention is kept for anything created here.
     */
    /**
     * Read-then-insert, which is a race: two entry points opening the same
     * thread at once (a listing's "Ask" and the messages tab, or simply a double
     * tap) both find nothing and both insert, leaving two conversations for one
     * pair — each holding half the history. Three such pairs reached production.
     *
     * `conversations_unique_pair`, a unique index on the normalised pair, is what
     * actually prevents it; the loser of the race lands here as a 23505 and is
     * resolved by re-reading the row the winner just created.
     */
    async findOrCreate(otherId: string, myRole: 'manager' | 'student'): Promise<string> {
      const me = requireUuid(this.userId, 'account')
      requireUuid(otherId, 'recipient')

      const existing = async () => {
        const { data, error } = await supabase
          .from('conversations')
          .select('id')
          .or(
            `and(user_a_id.eq.${me},user_b_id.eq.${otherId}),` +
              `and(user_a_id.eq.${otherId},user_b_id.eq.${me})`,
          )
          .limit(1)
          .maybeSingle()
        if (error) throw error
        return data?.id ?? null
      }

      const found = await existing()
      if (found) return found

      const [userA, userB] = myRole === 'student' ? [me, otherId] : [otherId, me]
      const { data: created, error: createError } = await supabase
        .from('conversations')
        .insert({ user_a_id: userA, user_b_id: userB })
        .select('id')
        .single()

      if (createError) {
        if ((createError as { code?: string }).code !== '23505') throw createError
        const raced = await existing()
        if (!raced) throw createError
        await this.load(me)
        return raced
      }

      await this.load(me)
      return created.id
    },
  },
})
