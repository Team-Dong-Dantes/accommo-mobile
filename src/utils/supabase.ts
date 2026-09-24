import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@/types/database.gen';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL ?? import.meta.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY ?? import.meta.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

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
  // A real uuid, not the string 'demo-user': every id in this app is a uuid, and
  // the code that builds PostgREST filters now says so out loud (see
  // requireUuid in stores/messages.ts). Demo mode should exercise the same
  // paths the app really takes rather than being the one caller that cannot.
  user: { id: '00000000-0000-4000-8000-000000000001', email: 'demo@accommo.local', role: 'manager' },
};

let _supabaseInstance: SupabaseClient<Database>;

if (supabaseUrl && supabaseAnonKey) {
  // Left on the default (implicit) flow deliberately. Switching to PKCE looks
  // like the right thing for a mobile app, but nothing here needs it: native
  // sign-in goes through signInWithIdToken() and never rides a redirect at all,
  // and the deep-link handler already refuses everything except a PKCE code (see
  // src/boot/deeplink.ts), so the token-in-the-URL shape has no way in either
  // way. What PKCE *would* change is how Supabase delivers e-mail one-time
  // codes, which is the spine of registration and of the PIN reset — not worth
  // altering on the strength of a change nothing is asking for.
  _supabaseInstance = createClient<Database>(supabaseUrl, supabaseAnonKey);
} else {
  console.warn(
    'Supabase environment variables are not set. Please add VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY to .env.local',
  );

  // Demo-mode role, guessed from the email used to sign in: emails
  // containing "student" land on the Student Hub, everything else on the
  // Manager Dashboard. Reset on every sign-in.
  let demoRole: 'student' | 'manager' = 'manager';

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
        : 'manager';
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

  // Realtime no-op. Callers subscribe on mount, so the stub has to be
  // chainable in the same shape or the layout crashes before it renders.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const demoChannel: any = {
    on: () => demoChannel,
    subscribe: () => demoChannel,
    unsubscribe: () => Promise.resolve('ok'),
  };

  _supabaseInstance = {
    auth,
    from: (table: string) => chain(table),
    rpc: () => Promise.resolve({ data: false, error: null }),
    channel: () => demoChannel,
    removeChannel: () => Promise.resolve('ok'),
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  } as unknown as SupabaseClient<Database>;
}

export const supabase = _supabaseInstance;

/**
 * The failure text from an OAuth round trip that came back without a session, or
 * null when the URL carries none.
 *
 * Supabase reports these in the fragment for the implicit flow and in the query
 * string for PKCE, and which one you get depends on the flow and the platform —
 * so read both rather than betting on one. Called by the two screens
 * `loginWithGoogle()` can return to.
 */
export function readOAuthError(): string | null {
  const sources = [
    new URLSearchParams(window.location.hash.replace(/^#\/?/, '')),
    new URLSearchParams(window.location.search),
  ];
  for (const params of sources) {
    const failure = params.get('error_description') || params.get('error');
    if (failure) return decodeURIComponent(failure).replace(/\+/g, ' ');
  }
  return null;
}

/**
 * True when the failure is Postgres rejecting the signup rather than the user or
 * the provider. Supabase's auth server flattens any trigger exception into this
 * generic wording, so the domain rule enforced in `handle_auth_user_sync()` is
 * indistinguishable here from any other database failure — the screens explain
 * the rule themselves rather than pretending to know which it was.
 */
export function isSignupDatabaseError(text: string): boolean {
  return /database error|saving new user|unexpected_failure/i.test(text);
}

/**
 * The session supabase-js has persisted, read straight out of storage.
 *
 * `getSession()` returns null for two very different situations: signed out,
 * and "the stored access token has expired and the refresh call just failed".
 * The second is the normal state of a cold launch — the app has sat closed past
 * the token's hour, and the refresh goes out before the device's network is
 * back. Treating it as signed out drops a logged-in user on the public
 * GetStarted fork, which never re-checks. Storage still holding a session is
 * what tells the two apart.
 *
 * The stored blob is checked for internal consistency before it is believed:
 * the access token must be a three-part JWT whose payload is JSON and whose
 * `sub` is the same id the envelope claims. Without that, the whole "session"
 * was a JSON object anyone could type into localStorage, and the router would
 * read a `user_metadata.role` out of it and open the landlord/landlady shell.
 *
 * ponytail: consistency only — the signature is not verified, because that needs
 * a key the client does not have and must not ship. This raises the bar from
 * "write a JSON blob" to "forge a matching JWT body", and it is deliberately not
 * a security boundary: the boundary is RLS, which answers a forged token with
 * nothing. Upgrade path, if it ever needs to be one, is asking the server.
 */
export interface StoredSession {
  user: { id: string; user_metadata?: Record<string, unknown> };
}

function jwtSubject(token: unknown): string | null {
  if (typeof token !== 'string') return null;
  const body = token.split('.')[1];
  if (!body || token.split('.').length !== 3) return null;
  try {
    const json = atob(body.replace(/-/g, '+').replace(/_/g, '/'));
    const claims = JSON.parse(json) as { sub?: unknown };
    return typeof claims.sub === 'string' ? claims.sub : null;
  } catch {
    return null;
  }
}

export function storedSession(): StoredSession | null {
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (!key || !/^sb-.+-auth-token$/.test(key)) continue;
      const raw = localStorage.getItem(key);
      if (!raw) continue;
      const parsed = JSON.parse(raw) as Record<string, unknown>;
      // v2 stores the session flat; older shapes nest it under currentSession.
      const candidate = (parsed?.access_token ? parsed : parsed?.currentSession) as
        | { access_token?: unknown; user?: { id?: string; user_metadata?: Record<string, unknown> } }
        | undefined;
      const id = candidate?.user?.id;
      if (typeof id !== 'string') continue;
      if (jwtSubject(candidate?.access_token) !== id) continue;
      return candidate as StoredSession;
    }
  } catch {
    // Unparseable or unavailable storage: fall through to "no session".
  }
  return null;
}

/**
 * The signed-in user's id without awaiting anything, for the handful of places
 * that must decide before the first paint — see utils/persistCache.ts.
 */
export function storedUserId(): string | null {
  return storedSession()?.user.id ?? null;
}

/**
 * The signed-in user, read from the locally stored session rather than the
 * `/auth/v1/user` endpoint.
 *
 * `supabase.auth.getUser()` is a network round trip on every call, and nearly
 * every screen made one before it could issue its first query — a serialized
 * hop in front of each load. `getSession()` reads local storage (refreshing the
 * token only when it has actually expired) and returns the same User object, so
 * `.id`, `.email` and the rest are unchanged.
 *
 * Safe for building queries because the database still enforces RLS against the
 * JWT — the client's copy of the id is never what grants access. Auth flows that
 * must confirm the account server-side (sign-in, registration, email/password
 * changes) deliberately keep calling `supabase.auth.getUser()`.
 */
export async function authUser() {
  const { data } = await supabase.auth.getSession();
  return { data: { user: data?.session?.user ?? null } };
}
