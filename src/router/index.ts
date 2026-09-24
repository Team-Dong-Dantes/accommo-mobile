import { defineRouter } from '#q-app';
import {
  createMemoryHistory,
  createRouter,
  createWebHashHistory,
  createWebHistory,
} from 'vue-router';
import routes from './routes';
import { supabase, storedSession, type StoredSession } from '@/utils/supabase';
import { useAuthStore } from '@/stores/auth';
import { resolveDestination, type GuardRole } from './guard';

export default defineRouter(() => {
  const createHistory = import.meta.env.QUASAR_SERVER
    ? createMemoryHistory
    : (import.meta.env.QUASAR_VUE_ROUTER_MODE === 'history' ? createWebHistory : createWebHashHistory);

  const Router = createRouter({
    scrollBehavior: () => ({ left: 0, top: 0 }),
    routes,
    history: createHistory(import.meta.env.QUASAR_VUE_ROUTER_BASE)
  });

  let roleFetchInProgress: Promise<string | null> | null = null;
  // Account status is checked on every navigation, not just at sign-in: a
  // session minted before a suspension would otherwise keep working until it
  // expired. Cached per navigation batch alongside the role lookup.
  let lastStatus: string | null = null;
  let lastEmailVerified: boolean | null = null;
  let lastRegistered: boolean | null = null;
  // True when the users row could not be READ, as opposed to read and found
  // wanting. The two used to be the same `null`, and the guard treats an
  // unreadable role as an invalid account — which signs the session out. On a
  // cold native launch the first query regularly loses that race (the request
  // goes out before the restored JWT is reliably attached, so RLS returns no
  // row), and a transient failure must never be destructive.
  let lastLookupFailed = false;

  async function fetchUserRole(session: StoredSession): Promise<string | null> {
    const authStore = useAuthStore();
    // No cached short-circuit here. The old `if (cachedRole && lastStatus)`
    // meant `status` was read ONCE per app launch, so a suspension mid-session
    // did not bite until the app was restarted — the opposite of what the
    // comment above promises. The in-flight promise below still collapses one
    // navigation's redirect chain into a single query, which is what that
    // short-circuit was actually earning.
    if (roleFetchInProgress) return roleFetchInProgress;

    // The role the JWT itself carries. Local, so it still answers when the
    // network does not — which is the whole point on a cold launch.
    const roleFromToken = () => {
      const metaRole = session.user.user_metadata?.role;
      if (typeof metaRole !== 'string' || !metaRole) return null;
      const role = metaRole.toLowerCase();
      return role === 'landlord' ? 'manager' : role;
    };

    roleFetchInProgress = (async () => {
      try {
        const { data, error } = await supabase
          .from('users')
          .select('role, status, email_verified_at, registered_at')
          .eq('id', session.user.id)
          .maybeSingle();

        if (error || !data) {
          // Unreadable, not invalid. Fall back to the token's own claim and
          // leave status/verified/registered null, so every check that could
          // evict this session sits out the navigation instead of firing on
          // an answer nobody actually got.
          //
          // They have to be CLEARED to be null, which this did not do: they are
          // module-level and kept whatever the last successful read left behind.
          // A landlord/landlady last read as 'pending' who then lost the network was
          // signed out by guard.ts on the next navigation, on the strength of a
          // stale value and a read that never returned.
          lastLookupFailed = true;
          lastStatus = null;
          lastEmailVerified = null;
          lastRegistered = null;
          const role = roleFromToken();
          if (role) authStore.cachedRole = role;
          return role;
        }

        lastLookupFailed = false;
        lastStatus = typeof data.status === 'string' ? data.status : null;
        lastEmailVerified = data.email_verified_at !== null;
        lastRegistered = data.registered_at !== null;

        let role = typeof data.role === 'string' ? data.role.toLowerCase() : null;
        if (role === 'landlord') role = 'manager';
        if (!role) role = roleFromToken();
        authStore.cachedRole = role;
        return role;
      } catch {
        lastLookupFailed = true;
        lastStatus = null;
        lastEmailVerified = null;
        lastRegistered = null;
        return roleFromToken();
      } finally {
        roleFetchInProgress = null;
      }
    })();

    return roleFetchInProgress;
  }

  Router.beforeEach(async (to) => {
    // Local demo mode: skip all auth guards so every screen can be previewed.
    // Gated on DEV as well as the flag — a stray VITE_DEMO_MODE=true in the
    // environment used for `quasar build` would otherwise ship an APK whose
    // every screen is reachable without signing in.
    if (import.meta.env.DEV && (import.meta.env.VITE_DEMO_MODE as unknown) === 'true') {
      return true;
    }

    const { data: { session } } = await supabase.auth.getSession();

    // No live session, but storage still holds one: the token expired while the
    // app was closed and the refresh could not be made yet. Carry on with the
    // stored identity rather than treating this as a sign-out — the row lookup
    // below will fail too, which sets lastLookupFailed and keeps every
    // session-ending branch of the guard out of it.
    const effectiveSession = session ?? storedSession();

    // The role fetch also refreshes lastStatus / lastEmailVerified /
    // lastRegistered / lastLookupFailed, so it has to run before they are read.
    lastLookupFailed = false;
    const role = effectiveSession ? await fetchUserRole(effectiveSession) : null;
    if (!session && effectiveSession) lastLookupFailed = true;

    const decision = resolveDestination({
      path: to.path,
      authenticated: !!effectiveSession,
      role: role as GuardRole,
      status: lastStatus,
      emailVerified: lastEmailVerified,
      registered: lastRegistered,
      lookupFailed: lastLookupFailed,
    });

    if (decision.signOut) {
      await supabase.auth.signOut();
      useAuthStore().clearCachedRole();
      lastStatus = null;
      lastEmailVerified = null;
      lastRegistered = null;
    }

    return decision.to;
  });

  return Router;
});
