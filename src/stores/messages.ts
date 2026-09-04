import { defineStore } from 'pinia';
import type { RealtimeChannel } from '@supabase/supabase-js';
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors';
import { initialsOf } from '@/utils/format';

export interface Thread {
  id: string;
  otherId: string;
  otherName: string;
  otherInitials: string;
  lastMessage: string;
  lastTime: string | null;
  unread: number;
}

interface Person {
  full_name: string | null;
  initials: string | null;
}

// A live connection, not reactive state — see stores/notifications.ts.
let channel: RealtimeChannel | null = null;

function newestFirst(a: Thread, b: Thread) {
  return new Date(b.lastTime ?? 0).getTime() - new Date(a.lastTime ?? 0).getTime();
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
      this.loading = true;
      this.error = '';
      try {
        const { data, error } = await supabase
          .from('conversations')
          // One string literal: postgrest-js parses the select at type level,
          // and a concatenated expression widens to `string` and stops typing.
          // eslint-disable-next-line max-len
          .select('id,user_a_id,user_b_id,last_message,last_time,unread_a,unread_b,a:users!conversations_user_a_id_fkey(full_name,initials),b:users!conversations_user_b_id_fkey(full_name,initials)')
          .or(`user_a_id.eq.${userId},user_b_id.eq.${userId}`);
        if (error) throw error;

        this.threads = (data ?? [])
          .map((row) => {
            const mine = row.user_a_id === userId;
            const other = (mine ? row.b : row.a) as unknown as Person | null;
            const name = other?.full_name || 'Unknown';
            return {
              id: row.id,
              otherId: mine ? row.user_b_id : row.user_a_id,
              otherName: name,
              otherInitials: other?.initials || initialsOf(name),
              lastMessage: row.last_message || '',
              lastTime: row.last_time,
              unread: Number((mine ? row.unread_a : row.unread_b) || 0),
            };
          })
          .sort(newestFirst);
        this.ready = true;
      } catch (e) {
        this.error = errorMessage(e, 'Could not load conversations.');
      } finally {
        this.loading = false;
      }
    },

    async start(userId: string) {
      if (this.userId === userId && channel) return;
      this.stop();
      this.userId = userId;
      await this.load(userId);

      if (typeof supabase.channel !== 'function') return;

      // postgres_changes has no OR, so each side of the pair is its own binding.
      const onChange = (payload: { eventType: string; new: Record<string, unknown> }) => {
        if (payload.eventType === 'INSERT') {
          // A brand new thread needs the counterpart's name, which the payload
          // does not carry, so this is the one case worth a refetch.
          void this.load(userId);
          return;
        }
        const row = payload.new as {
          id: string;
          user_a_id: string;
          last_message: string | null;
          last_time: string | null;
          unread_a: number;
          unread_b: number;
        };
        const thread = this.threads.find((t) => t.id === row.id);
        if (!thread) {
          void this.load(userId);
          return;
        }
        thread.lastMessage = row.last_message || '';
        thread.lastTime = row.last_time;
        thread.unread = Number((row.user_a_id === userId ? row.unread_a : row.unread_b) || 0);
        this.threads.sort(newestFirst);
      };

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

    /** Clears the local badge; the RPC has already zeroed it server-side. */
    clearUnread(conversationId: string) {
      const thread = this.threads.find((t) => t.id === conversationId);
      if (thread) thread.unread = 0;
    },

    /**
     * The id of the thread with `otherId`, creating it if this is a first
     * enquiry. Every existing row puts the student in user_a, so that
     * convention is kept for anything created here.
     */
    async findOrCreate(otherId: string, myRole: 'manager' | 'student'): Promise<string> {
      const me = this.userId;
      const { data: found, error: findError } = await supabase
        .from('conversations')
        .select('id')
        .or(
          `and(user_a_id.eq.${me},user_b_id.eq.${otherId}),` +
            `and(user_a_id.eq.${otherId},user_b_id.eq.${me})`,
        )
        .limit(1)
        .maybeSingle();
      if (findError) throw findError;
      if (found) return found.id;

      const [userA, userB] = myRole === 'student' ? [me, otherId] : [otherId, me];
      const { data: created, error: createError } = await supabase
        .from('conversations')
        .insert({ user_a_id: userA, user_b_id: userB })
        .select('id')
        .single();
      if (createError) throw createError;

      await this.load(me);
      return created.id;
    },
  },
});
