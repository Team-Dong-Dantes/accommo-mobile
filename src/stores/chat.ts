import { defineStore } from 'pinia'

export const useChatStore = defineStore('chat', {
  state: () => ({
    messages: [] as ChatMessage[],
    pendingInquiry: null as { id: string; text: string; senderId: string } | null,
    quickReplies: [] as string[],
    isTyping: false,
  }),

  getters: {
    unreadCount: (state) =>
      state.messages.filter((m: ChatMessage) => !m.isLandlord).length,
  },

  actions: {
    async loadMessages() {
      this.messages = [
        {
          id: 'msg-1',
          text: 'Hi, I\'m interested in your room for this month.',
          senderId: 'student-1',
          timestamp: '2024-01-15T10:30:00',
          isLandlord: false,
        },
        {
          id: 'msg-2',
          text: 'Hello! Yes, we have a room available. What is your course and year level?',
          senderId: 'landlord-1',
          timestamp: '2024-01-15T10:31:00',
          isLandlord: true,
        },
        {
          id: 'msg-3',
          text: 'I\'m taking BS Computer Science, 3rd year.',
          senderId: 'student-1',
          timestamp: '2024-01-15T10:32:00',
          isLandlord: false,
        },
      ]
    },

    async sendMessage(text: string, isLandlord: boolean = false) {
      const message: ChatMessage = {
        id: Math.random().toString(36).substr(2, 9),
        text,
        senderId: isLandlord ? 'landlord-1' : 'student-' + Math.floor(Math.random() * 10),
        timestamp: new Date().toISOString(),
        isLandlord,
      }

      this.messages.unshift(message)
    },

    async acceptInquiry(inquiryId: string) {
      this.pendingInquiry = null
      await this.sendMessage(`Accepted your inquiry.`, true)
    },

    async declineInquiry(inquiryId: string) {
      this.pendingInquiry = null
      await this.sendMessage(`Declined your inquiry.`, true)
    },

    setQuickReplies(replies: string[]) {
      this.quickReplies = replies
    },
  },
})