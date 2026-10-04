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
import { markActive } from '@/utils/activity';
import { type GuardRole } from './guard';
import { createNavGuard, type Account } from './navGuard';
import { timeoutSignal } from '@/utils/fetchTimeout';

export default defineRouter(() => {
  const createHistory = import.meta.env.QUASAR_SERVER
    ? createMemoryHistory
    : (import.meta.env.QUASAR_VUE_ROUTER_MODE === 'history' ? createWebHistory : createWebHashHistory);

  const Router = createRouter({
    scrollBehavior: () => ({ left: 0, top: 0 }),
    routes,
    history: createHistory(import.meta.env.QUASAR_VUE_ROUTER_BASE)
  });

  // How long the guard waits for the users row when it has to wait (a cold
  // launch, or before redirecting). Shorter than the app-wide read deadline:
  // a failed read only means falling back to the token's claim, which beats
  // holding the first screen.
  const GUARD_LOOKUP_TIMEOUT_MS = 6_000;

  // Reads the users row. Never throws and never evicts on its own: a row that
  // could not be READ, as opposed to read and found wanting, comes back with
  // lookupFailed. On a cold native launch the first query regularly loses that
  // race (the request goes out before the restored JWT is reliably attached, so
  // RLS returns no row), and a transient failure must never be destructive.
  async function lookupAccount(session: StoredSession): Promise<Account> {
    const authStore = useAuthStore();

    // The role the JWT itself carries. Local, so it still answers when the
    // network does not — which is the whole point on a cold launch.
    const roleFromToken = (): GuardRole => {
      const metaRole = session.user.user_metadata?.role;
      if (typeof metaRole !== 'string' || !metaRole) return null;
      const role = metaRole.toLowerCase();
      return (role === 'landlord' ? 'manager' : role) as GuardRole;
    };

    // Unreadable, not invalid. Fall back to the token's own claim and leave
    // status/verified/registered null, so every check that could evict this
    // session sits out the navigation instead of firing on an answer nobody
    // actually got. (A landlord/landlady last read as 'pending' who then lost
    // the network was once signed out on the strength of a stale value.)
    const unread = (): Account => {
      const role = roleFromToken();
      if (role) authStore.cachedRole = role;
      return { role, status: null, emailVerified: null, registered: null, lookupFailed: true };
    };

    try {
      const { data, error } = await supabase
        .from('users')
        .select('role, status, email_verified_at, registered_at')
        .eq('id', session.user.id)
        .abortSignal(timeoutSignal(GUARD_LOOKUP_TIMEOUT_MS))
        .maybeSingle();
      if (error || !data) return unread();

      const status = typeof data.status === 'string' ? data.status : null;
      // Screens gate "add accommodation" on this (isVerifiedLandlord), so an
      // OSAS decision shows up on the next navigation. A failed read (above)
      // leaves the store alone rather than flashing a verified account locked.
      authStore.accountStatus = status;

      let role = typeof data.role === 'string' ? data.role.toLowerCase() : null;
      if (role === 'landlord') role = 'manager';
      if (!role) role = roleFromToken();
      authStore.cachedRole = role;
      return {
        role: role as GuardRole,
        status,
        emailVerified: data.email_verified_at !== null,
        registered: data.registered_at !== null,
        lookupFailed: false,
      };
    } catch {
      return unread();
    }
  }

  const navGuard = createNavGuard<StoredSession>({
    async session() {
      const { data: { session } } = await supabase.auth.getSession();
      // No live session, but storage still holds one: the token expired while
      // the app was closed and the refresh could not be made yet. Carry on with
      // the stored identity rather than treating this as a sign-out.
      const effective = session ?? storedSession();
      return effective ? { userId: effective.user.id, live: !!session, raw: effective } : null;
    },
    lookup: lookupAccount,
    async signOut() {
      await supabase.auth.signOut();
      useAuthStore().clearCachedRole();
    },
    // Opening the app counts as being active ("Last active" for OSAS).
    markActive,
    currentPath: () => Router.currentRoute.value.path,
    replace: (to) => Router.replace(to),
  });

  Router.beforeEach(async (to) => {
    // Local demo mode: skip all auth guards so every screen can be previewed.
    // Gated on DEV as well as the flag — a stray VITE_DEMO_MODE=true in the
    // environment used for `quasar build` would otherwise ship an APK whose
    // every screen is reachable without signing in.
    if (import.meta.env.DEV && (import.meta.env.VITE_DEMO_MODE as unknown) === 'true') {
      return true;
    }
    return (await navGuard.guard(to.path)).to;
  });

  // Once the new screen is up, check the answer it was let through on.
  Router.afterEach(() => {
    void navGuard.revalidate();
  });

  return Router;
});
