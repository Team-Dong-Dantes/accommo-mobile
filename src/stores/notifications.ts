import { defineStore } from 'pinia';
import type { RealtimeChannel } from '@supabase/supabase-js';
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors';

export interface NotifRow {
  id: string;
  type: string;
  title: string;
  body: string;
  link_url: string | null;
  read_at: string | null;
  created_at: string;
}

/** Newest first — the order the list renders and the order inserts arrive in. */
function byNewest(a: NotifRow, b: NotifRow) {
  return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
}

// Held outside the store: a channel is a live connection, not reactive state,
// and wrapping the class in a Pinia state proxy widens it structurally.
let channel: RealtimeChannel | null = null;

// One store backs both the header bell and the notifications page, off a single
// realtime subscription. Two independent fetches would drift apart the moment
// one of them marked something read.
export const useNotificationsStore = defineStore('notifications', {
  state: () => ({
    items: [] as NotifRow[],
    loading: false,
    error: '',
    userId: '',
    ready: false,
  }),

  getters: {
    unread: (state) => state.items.filter((n) => !n.read_at).length,
  },

  actions: {
    async load(userId: string) {
      this.loading = true;
      this.error = '';
      try {
        const { data, error } = await supabase
          .from('notifications')
          .select('id, type, title, body, link_url, read_at, created_at')
          .eq('user_id', userId)
          .order('created_at', { ascending: false })
          .limit(100);
        if (error) throw error;
        this.items = (data as NotifRow[]) ?? [];
        this.ready = true;
      } catch (e) {
        this.error = errorMessage(e, 'Could not load notifications.');
      } finally {
        this.loading = false;
      }
    },

    /** Load once, then keep the list live. Safe to call again for the same user. */
    async start(userId: string) {
      if (this.userId === userId && channel) return;
      this.stop();
      this.userId = userId;
      await this.load(userId);

      // A client without realtime (the unconfigured/demo stub) still lists
      // notifications; it just will not receive live updates.
      if (typeof supabase.channel !== 'function') return;

      channel = supabase
        .channel(`notifications:${userId}`)
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'notifications', filter: `user_id=eq.${userId}` },
          (payload) => {
            if (payload.eventType === 'INSERT') {
              const row = payload.new as NotifRow;
              if (!this.items.some((n) => n.id === row.id)) {
                this.items = [row, ...this.items].sort(byNewest);
              }
            } else if (payload.eventType === 'UPDATE') {
              const row = payload.new as NotifRow;
              const at = this.items.findIndex((n) => n.id === row.id);
              if (at !== -1) this.items[at] = row;
            } else if (payload.eventType === 'DELETE') {
              const gone = payload.old as { id?: string };
              if (gone.id) this.items = this.items.filter((n) => n.id !== gone.id);
            }
          },
        )
        .subscribe();
    },

    stop() {
      if (channel) {
        void supabase.removeChannel(channel);
        channel = null;
      }
      this.userId = '';
      this.ready = false;
    },

    async markRead(id: string) {
      const row = this.items.find((n) => n.id === id);
      if (!row || row.read_at) return;

      // Optimistic: the row reads as read immediately, and the realtime UPDATE
      // that follows simply confirms it.
      const stamp = new Date().toISOString();
      row.read_at = stamp;

      const { error } = await supabase
        .from('notifications')
        .update({ read_at: stamp })
        .eq('id', id);
      if (error) row.read_at = null;
    },

    async markAllRead() {
      const unreadIds = this.items.filter((n) => !n.read_at).map((n) => n.id);
      if (!unreadIds.length) return;

      const stamp = new Date().toISOString();
      for (const n of this.items) {
        if (!n.read_at) n.read_at = stamp;
      }

      const { error } = await supabase
        .from('notifications')
        .update({ read_at: stamp })
        .in('id', unreadIds);
      if (error) {
        for (const n of this.items) {
          if (unreadIds.includes(n.id)) n.read_at = null;
        }
        this.error = error.message;
      }
    },
  },
});
