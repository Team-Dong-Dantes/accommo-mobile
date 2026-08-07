import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@/shared/types/database.gen';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

interface MockSupabaseClient {
  auth: {
    getSession: () => Promise<{ data: { session: null }; error: null }>;
    signInWithPassword: (credentials: {
      email: string;
      password: string;
    }) => Promise<{ data: null; error: { message: string } }>;
    signOut: () => Promise<{ error: null }>;
  };
  from: (table: string) => {
    select: (columns: string) => {
      eq: (column: string, value: string) => {
        single: () => Promise<{ data: null; error: { message: string } }>;
      };
    };
  };
}

let _supabaseInstance: SupabaseClient<Database>;

if (supabaseUrl && supabaseAnonKey) {
  _supabaseInstance = createClient<Database>(supabaseUrl, supabaseAnonKey);
} else {
  console.warn(
    'Supabase environment variables are not set. Please add VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY to .env.local',
  );

  _supabaseInstance = {
    auth: {
      getSession: () =>
        Promise.resolve({ data: { session: null }, error: null }),
      signInWithPassword: () =>
        Promise.resolve({
          data: null,
          error: { message: 'Supabase not configured' },
        }),
      signOut: () => Promise.resolve({ error: null }),
    },
    from: () => ({
      select: () => ({
        eq: () => ({
          single: () =>
            Promise.resolve({
              data: null,
              error: { message: 'Supabase not configured' },
            }),
        }),
      }),
    }),
  } as unknown as SupabaseClient<Database>;
}

export const supabase = _supabaseInstance;
export type { MockSupabaseClient };
