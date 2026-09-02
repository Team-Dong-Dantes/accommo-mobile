import { defineStore } from 'pinia'
import { supabase } from '@/shared/utils/supabase'
import type { ChatMessage } from '@/shared/types/app-types'

let messageChannel: any = null
let conversationChannel: any = null
let pollTimer: any = null

function stopPolling() {
  if (pollTimer) {
    clearInterval(pollTimer)
    pollTimer = null
  }
}

function startPolling(conversationId: string, store: any) {
  stopPolling()
  pollTimer = setInterval(async () => {
    if (store.activeConversationId !== conversationId) return
    try {
      const { data } = await supabase
        .from('messages')
        .select('id, body, sender_id, sent_at, status')
        .eq('conversation_id', conversationId)
        .order('sent_at', { ascending: true })

      if (data && data.length) {
        const { data: authData } = await supabase.auth.getUser()
        const myId = authData?.user?.id
        const incoming = (data as any[]).map((m: any) => ({
          id: m.id,
          text: m.body,
          senderId: m.sender_id,
          timestamp: m.sent_at,
          isLandlord: m.sender_id === myId,
          status: m.status || 'sent',
        }))

        // Only replace if count changed or last message is different
        if (incoming.length !== store.messages.length || incoming[incoming.length - 1]?.id !== store.messages[store.messages.length - 1]?.id) {
          store.messages = incoming
          if (typeof store.onNewMessage === 'function') {
            store.onNewMessage()
          }
          if (myId) {
            void store.markConversationSeen(conversationId, myId)
          }
        }
      }
    } catch {
      // quiet poll fallback
    }
  }, 1500)
}

function unsubscribeMessages() {
  stopPolling()
  if (messageChannel) {
    void supabase.removeChannel(messageChannel)
    messageChannel = null
  }
}

function unsubscribeConversations() {
  if (conversationChannel) {
    void supabase.removeChannel(conversationChannel)
    conversationChannel = null
  }
}

export interface Conversation {
  id: string
  otherUserId: string
  otherName: string
  otherRole?: string
  lastMessage: string | null
  lastTime: string | null
  unread?: number
}

export const useChatStore = defineStore('chat', {
  state: () => ({
    conversations: [] as Conversation[],
    messages: [] as ChatMessage[],
    activeConversationId: null as string | null,
    isLoading: false,
    loadError: null as string | null,
    onNewMessage: null as (() => void) | null,
  }),

  getters: {
    unreadCount: (state) => state.conversations.reduce((total, conversation: any) => total + (conversation.unread ?? 0), 0),
  },

  actions: {
    async loadConversations() {
      this.isLoading = true
      this.loadError = null
      try {
        const {
          data: { user },
        } = await supabase.auth.getUser()
        if (!user) return

        const { data, error } = await supabase
          .from('conversations')
          .select('id, last_message, last_time, user_a_id, user_b_id, unread_a, unread_b')
          .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
          .order('last_time', { ascending: false, nullsFirst: false })

        if (error) throw error

        const convos = (data || []) as any[]
        if (!convos.length) {
          this.conversations = []
          return
        }

        const otherIds = convos.map((c) =>
          c.user_a_id === user.id ? c.user_b_id : c.user_a_id,
        )
        const { data: users, error: userErr } = await supabase
          .from('users')
          .select('id, full_name, role')
          .in('id', otherIds)
        if (userErr) throw userErr

        const userMap: Record<string, { name: string; role: string }> = {}
        ;(users || []).forEach((u: any) => {
          userMap[u.id] = {
            name: u.full_name || 'Tenant',
            role: u.role === 'student' ? 'Tenant' : u.role === 'accommodation_manager' || u.role === 'landlord' ? 'Manager' : 'User',
          }
        })

        this.conversations = convos.map((c) => {
          const otherId = c.user_a_id === user.id ? c.user_b_id : c.user_a_id
          const p = userMap[otherId]
          return {
            id: c.id,
            otherUserId: otherId,
            otherName: p?.name || 'Tenant',
            otherRole: p?.role || 'Tenant',
            lastMessage: c.last_message,
            lastTime: c.last_time,
            unread: c.user_a_id === user.id ? (c.unread_a ?? 0) : (c.unread_b ?? 0),
          }
        })

        unsubscribeConversations()
        conversationChannel = supabase
          .channel(`chat-conversations:${user.id}`)
          .on('postgres_changes', { event: '*', schema: 'public', table: 'conversations', filter: `user_a_id=eq.${user.id}` }, () => {
            void this.loadConversations()
          })
          .on('postgres_changes', { event: '*', schema: 'public', table: 'conversations', filter: `user_b_id=eq.${user.id}` }, () => {
            void this.loadConversations()
          })
          .subscribe()
      } catch (e: any) {
        this.loadError = e?.message || 'Failed to load conversations'
      } finally {
        this.isLoading = false
      }
    },

    async loadMessages(conversationId: string) {
      unsubscribeMessages()
      this.activeConversationId = conversationId
      this.isLoading = true
      this.loadError = null
      try {
        const {
          data: { user },
        } = await supabase.auth.getUser()
        if (!user) return

        const { data, error } = await supabase
          .from('messages')
          .select('id, body, sender_id, sent_at, status')
          .eq('conversation_id', conversationId)
          .order('sent_at', { ascending: true })

        if (error) throw error

        this.messages = (data || []).map((m: any) => ({
          id: m.id,
          text: m.body,
          senderId: m.sender_id,
          timestamp: m.sent_at,
          isLandlord: m.sender_id === user.id,
          status: m.status || 'sent',
        }))

        await this.markConversationSeen(conversationId, user.id)

        startPolling(conversationId, this)

        unsubscribeMessages()
        const channelName = `conversation-${conversationId}`
        messageChannel = supabase
          .channel(channelName, {
            config: {
              broadcast: { self: false, ack: false },
            },
          })
          .on(
            'broadcast',
            { event: 'new_message' },
            (payload: any) => {
              const msg = payload?.payload || payload
              if (!msg || msg.conversationId !== conversationId) return
              if (this.messages.some((m) => m.id === msg.id)) return
              this.messages.push({
                id: msg.id,
                text: msg.text,
                senderId: msg.senderId,
                timestamp: msg.timestamp,
                isLandlord: msg.senderId === user.id,
                status: 'read',
              })
              if (msg.senderId !== user.id) {
                void this.markConversationSeen(conversationId, user.id)
              }
            },
          )
          .on(
            'postgres_changes',
            { event: 'INSERT', schema: 'public', table: 'messages' },
            (payload: any) => {
              const row = payload.new
              if (row.conversation_id !== conversationId) return
              if (this.messages.some((m) => m.id === row.id)) return
              this.messages.push({
                id: row.id,
                text: row.body,
                senderId: row.sender_id,
                timestamp: row.sent_at,
                isLandlord: row.sender_id === user.id,
                status: row.status || 'sent',
              })
              if (row.sender_id !== user.id) {
                void this.markConversationSeen(conversationId, user.id)
              }
            },
          )
          .on(
            'postgres_changes',
            { event: 'UPDATE', schema: 'public', table: 'messages' },
            (payload: any) => {
              const row = payload.new
              if (row.conversation_id !== conversationId) return
              const target = this.messages.find((message) => message.id === row.id)
              if (target) {
                target.status = row.status || target.status
              }
            },
          )
          .subscribe((status) => {
            console.log(`[realtime] chat subscription status:`, status)
          })
      } catch (e: any) {
        this.loadError = e?.message || 'Failed to load messages'
      } finally {
        this.isLoading = false
      }
    },

    async sendMessage(text: string) {
      const conversationId = this.activeConversationId
      if (!conversationId || !text.trim()) return

      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) return

      const nowIso = new Date().toISOString()
      const messageId = crypto.randomUUID()
      const { error } = await supabase
        .from('messages')
        .insert({
          id: messageId,
          conversation_id: conversationId,
          sender_id: user.id,
          body: text.trim(),
          status: 'sent',
          sent_at: nowIso,
        } as any)
      if (error) throw error

      if (messageChannel) {
        void messageChannel.send({
          type: 'broadcast',
          event: 'new_message',
          payload: {
            id: messageId,
            conversationId,
            senderId: user.id,
            text: text.trim(),
            timestamp: nowIso,
          },
        })
      }

      const { data: conversation, error: conversationError } = await supabase
        .from('conversations')
        .select('user_a_id, user_b_id, unread_a, unread_b')
        .eq('id', conversationId)
        .maybeSingle()
      if (conversationError) throw conversationError

      let otherId: string | null = null
      if (conversation) {
        const row = conversation as any
        otherId = row.user_a_id === user.id ? row.user_b_id : row.user_a_id
        const updatePayload = row.user_b_id === user.id
          ? {
            last_message: text.trim(),
            last_time: nowIso,
            unread_a: (row.unread_a ?? 0) + 1,
            unread_b: 0,
          }
          : {
            last_message: text.trim(),
            last_time: nowIso,
            unread_b: (row.unread_b ?? 0) + 1,
            unread_a: 0,
          }
        await supabase.from('conversations').update(updatePayload as any).eq('id', conversationId)
      }

      // Direct notification inserts can be restricted by RLS on clients.
      // Conversation update above already drives unread indicators and realtime updates.

      await this.loadMessages(conversationId)
    },

    async markConversationSeen(conversationId: string, currentUserId?: string) {
      const userId = currentUserId || (await supabase.auth.getUser()).data.user?.id
      if (!userId) return
      try {
        const { data: conversation, error: conversationError } = await supabase
          .from('conversations')
          .select('user_a_id, user_b_id')
          .eq('id', conversationId)
          .maybeSingle()
        if (conversationError || !conversation) return
        const row = conversation as any
        const isUserA = row.user_a_id === userId
        await supabase
          .from('conversations')
          .update(isUserA ? { unread_a: 0 } : { unread_b: 0 })
          .eq('id', conversationId)

        const local = this.conversations.find((c: any) => c.id === conversationId) as any
        if (local) local.unread = 0
      } catch (e) {
        console.warn('Could not reset unread status:', (e as any)?.message || e)
      }
    },

    // Returns an existing conversation id between the current user and otherUserId,
    // creating one if it does not exist yet.
    async ensureConversation(otherUserId: string): Promise<string | null> {
      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) return null

      const { data: existing, error } = await supabase
        .from('conversations')
        .select('id')
        .or(
          `and(user_a_id.eq.${user.id},user_b_id.eq.${otherUserId}),and(user_a_id.eq.${otherUserId},user_b_id.eq.${user.id})`,
        )
        .maybeSingle()
      if (error) throw error
      if (existing) return (existing as any).id

      const { data: created, error: createErr } = await supabase
        .from('conversations')
        .insert({ user_a_id: user.id, user_b_id: otherUserId } as any)
        .select('id')
        .single()
      if (createErr) throw createErr
      return (created as any)?.id ?? null
    },

    // Students currently renting from this landlord (active leases) — used to
    // start a new conversation.
    async loadTenantsForNewChat(): Promise<{ id: string; name: string }[]> {
      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) return []

      // leases have no landlord_id; resolve via accommodations -> rooms -> leases.
      const { data: accs } = await supabase
        .from('accommodations' as any)
        .select('id')
        .eq('accommodation_manager_id', user.id)
      const accIds = (accs ?? []).map((a: any) => a.id)

      let leaseRows: any[] = []
      if (accIds.length) {
        const { data: rooms } = await supabase.from('rooms').select('id').in('accommodation_id', accIds)
        const roomIds = (rooms ?? []).map((r: any) => r.id)
        if (roomIds.length) {
          const { data: leases } = await supabase
            .from('leases')
            .select('student_id')
            .in('room_id', roomIds)
            .eq('status', 'active')
          leaseRows = leases ?? []
        }
      }

      const studentIds = Array.from(new Set(leaseRows.map((l: any) => l.student_id)))
      const userMap = new Map<string, string>()
      if (studentIds.length) {
        const { data: users } = await supabase
          .from('users')
          .select('id, full_name')
          .in('id', studentIds)
        ;(users ?? []).forEach((u: any) => userMap.set(u.id, u.full_name || 'Student'))
      }

      return studentIds.map((id) => ({ id, name: userMap.get(id) || 'Student' }))
    },

    // Landlord messaging is tenant-only; OSAS concerns are filed via the Support page.

    clearActive() {
      stopPolling()
      unsubscribeMessages()
      this.activeConversationId = null
      this.messages = []
      this.onNewMessage = null
    },
  },
})
