import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@/shared/types/database.gen';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

// Local demo mode: lets you preview every screen without a real Supabase
// project. Enable by adding VITE_DEMO_MODE=true to your (gitignored)
// .env.local — no backend changes required.
const demoMode = (import.meta.env.VITE_DEMO_MODE as unknown) === 'true';

if (demoMode) {
  console.warn(
    '[accommo] DEMO MODE is ON — auth is faked and data queries return "not configured". ' +
      'Set VITE_DEMO_MODE=false (or delete .env.local) to use real Supabase.',
  );
}

const NOT_CONFIGURED = 'Supabase not configured';

// Fake session/user used in demo mode so protected screens render.
const DEMO_SESSION = {
  access_token: 'demo-token',
  user: { id: 'demo-user', email: 'demo@accommo.local', role: 'landlord' },
};

type MockResult = { data: unknown; error: null } | { data: null; error: { message: string } };

interface MockSupabaseClient {
  auth: {
    getSession: () => Promise<{ data: { session: unknown }; error: null }>;
    getUser: () => Promise<{ data: { user: unknown }; error: null }>;
    signInWithPassword: (credentials?: { email?: string }) => Promise<MockResult>;
    signUp: () => Promise<MockResult>;
    signInWithOAuth: () => Promise<MockResult>;
    signOut: () => Promise<{ error: null }>;
    resetPasswordForEmail: () => Promise<{ error: null }>;
  };
  from: (table: string) => unknown;
  rpc: () => Promise<{ data: boolean; error: null }>;
}

let _supabaseInstance: SupabaseClient<Database>;

if (supabaseUrl && supabaseAnonKey) {
  _supabaseInstance = createClient<Database>(supabaseUrl, supabaseAnonKey);
} else {
  console.warn(
    'Supabase environment variables are not set. Please add VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY to .env.local',
  );

  // Demo-mode role, guessed from the email used to sign in: emails
  // containing "student" land on the Student Hub, everything else on the
  // Landlord Dashboard. Reset on every sign-in.
  let demoRole: 'student' | 'landlord' = 'landlord';

  // In-memory demo database: rows written via insert() are kept and returned
  // by later queries, so records added while previewing (e.g. properties)
  // actually show up on the list screens.
  const demoDb: Record<string, unknown[]> = {};
  let demoNextId = 1;

  const auth = {
    getSession: () =>
      Promise.resolve({
        data: { session: demoMode ? DEMO_SESSION : null },
        error: null,
      }),
    getUser: () =>
      Promise.resolve({
        data: { user: demoMode ? DEMO_SESSION.user : null },
        error: null,
      }),
    signInWithPassword: (credentials?: { email?: string }) => {
      if (!demoMode) {
        return Promise.resolve({ data: null, error: { message: NOT_CONFIGURED } });
      }
      demoRole = String(credentials?.email ?? '')
        .toLowerCase()
        .includes('student')
        ? 'student'
        : 'landlord';
      const user = { ...DEMO_SESSION.user, role: demoRole };
      return Promise.resolve({
        data: { user, session: { ...DEMO_SESSION, user } },
        error: null,
      });
    },
    signUp: () =>
      Promise.resolve(
        demoMode
          ? { data: { user: DEMO_SESSION.user, session: DEMO_SESSION }, error: null }
          : { data: null, error: { message: NOT_CONFIGURED } },
      ),
    signInWithOAuth: () =>
      Promise.resolve({ data: null, error: { message: NOT_CONFIGURED } }),
    signOut: () => Promise.resolve({ error: null }),
    resetPasswordForEmail: () => Promise.resolve({ error: null }),
  };

  const notConfiguredError = { message: NOT_CONFIGURED };

  // Permissive query chain: any method/column access returns another chain;
  // awaiting the chain resolves to a mock result so pages render their
  // empty/error UI instead of crashing. insert() writes to the in-memory
  // demoDb so added rows are returned by later queries.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  function chain(table: string): any {
    const usersRoleInDemo = demoMode && table === 'users';
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const fn: any = (..._args: unknown[]) => chain(table);
    fn.then = (resolve: (value: unknown) => void) =>
      resolve(
        demoMode
          ? {
              data: usersRoleInDemo ? { role: demoRole } : (demoDb[table] ?? null),
              error: null,
            }
          : { data: null, error: notConfiguredError },
      );
    return new Proxy(fn, {
      get: (target, prop, receiver) => {
        if (prop === 'then') return Reflect.get(target, prop, receiver);
        if (prop === 'insert') {
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          return (values: any) => {
            const rows = Array.isArray(values) ? values : [values];
            const rowsWithIds = rows.map((row) => {
              // eslint-disable-next-line @typescript-eslint/no-explicit-any
              const next: any = { ...(row as any) };
              if (next.id == null) next.id = `demo-${demoNextId++}`;
              return next;
            });
            demoDb[table] = [...(demoDb[table] ?? []), ...rowsWithIds];
            return chain(table);
          };
        }
        return chain(table);
      },
    });
  }

  _supabaseInstance = {
    auth,
    from: (table: string) => chain(table),
    rpc: () => Promise.resolve({ data: false, error: null }),
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  } as unknown as SupabaseClient<Database>;
}

export const supabase = _supabaseInstance;
export type { MockSupabaseClient };
