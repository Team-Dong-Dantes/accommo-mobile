import { defineStore } from 'pinia'
import { supabase } from '@/shared/utils/supabase'
import type { ChatMessage } from '@/shared/types/app-types'

let messageChannel: any = null

function unsubscribeMessages() {
  if (messageChannel) {
    void supabase.removeChannel(messageChannel)
    messageChannel = null
  }
}

export interface Conversation {
  id: string
  otherUserId: string
  otherName: string
  lastMessage: string | null
  lastTime: string | null
}

export const useChatStore = defineStore('chat', {
  state: () => ({
    conversations: [] as Conversation[],
    messages: [] as ChatMessage[],
    activeConversationId: null as string | null,
    isLoading: false,
    loadError: null as string | null,
  }),

  getters: {
    unreadCount: (state) => state.messages.filter((m) => !m.isLandlord).length,
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
          .select('id, last_message, last_time, user_a_id, user_b_id')
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
          .select('id, full_name')
          .in('id', otherIds)
        if (userErr) throw userErr

        const nameMap: Record<string, string> = {}
        ;(users || []).forEach((u: any) => (nameMap[u.id] = u.full_name || 'User'))

        this.conversations = convos.map((c) => {
          const otherId = c.user_a_id === user.id ? c.user_b_id : c.user_a_id
          return {
            id: c.id,
            otherUserId: otherId,
            otherName: nameMap[otherId] || 'User',
            lastMessage: c.last_message,
            lastTime: c.last_time,
          }
        })
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
        }))

        messageChannel = supabase
          .channel(`messages:${conversationId}`)
          .on(
            'postgres_changes',
            { event: 'INSERT', schema: 'public', table: 'messages', filter: `conversation_id=eq.${conversationId}` },
            (payload: any) => {
              const row = payload.new
              if (this.messages.some((m) => m.id === row.id)) return
              this.messages.push({
                id: row.id,
                text: row.body,
                senderId: row.sender_id,
                timestamp: row.sent_at,
                isLandlord: row.sender_id === user.id,
              })
            },
          )
          .subscribe()
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

      const { error } = await supabase
        .from('messages')
        .insert({
          conversation_id: conversationId,
          sender_id: user.id,
          body: text.trim(),
          status: 'sent',
          sent_at: new Date().toISOString(),
        } as any)
      if (error) throw error

      await supabase
        .from('conversations')
        .update({
          last_message: text.trim(),
          last_time: new Date().toISOString(),
        } as any)
        .eq('id', conversationId)

      await this.loadMessages(conversationId)
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
      unsubscribeMessages()
      this.activeConversationId = null
      this.messages = []
    },
  },
})
