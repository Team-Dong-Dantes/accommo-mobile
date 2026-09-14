import { defineRouter } from '#q-app';
import {
  createMemoryHistory,
  createRouter,
  createWebHashHistory,
  createWebHistory,
} from 'vue-router';
import routes from './routes';
import { supabase } from '@/utils/supabase';
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

  async function fetchUserRole(session: { user: { id: string; user_metadata?: Record<string, unknown> } }): Promise<string | null> {
    const authStore = useAuthStore();
    // No cached short-circuit here. The old `if (cachedRole && lastStatus)`
    // meant `status` was read ONCE per app launch, so a suspension mid-session
    // did not bite until the app was restarted — the opposite of what the
    // comment above promises. The in-flight promise below still collapses one
    // navigation's redirect chain into a single query, which is what that
    // short-circuit was actually earning.
    if (roleFetchInProgress) return roleFetchInProgress;

    roleFetchInProgress = (async () => {
      try {
        const { data, error } = await supabase
          .from('users')
          .select('role, status, email_verified_at, registered_at')
          .eq('id', session.user.id)
          .maybeSingle();

        if (error || !data) return null;

        lastStatus = typeof data.status === 'string' ? data.status : null;
        lastEmailVerified = data.email_verified_at !== null;
        lastRegistered = data.registered_at !== null;

        let role = typeof data.role === 'string' ? data.role.toLowerCase() : null;
        if (role === 'accommodation_manager') role = 'manager';
        if (!role) {
          const metaRole = session.user.user_metadata?.role;
          if (typeof metaRole === 'string' && metaRole) {
            role = metaRole.toLowerCase();
            if (role === 'accommodation_manager') role = 'manager';
          }
        }
        authStore.cachedRole = role;
        return role;
      } catch {
        return null;
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

    // The role fetch also refreshes lastStatus / lastEmailVerified /
    // lastRegistered, so it has to run before they are read.
    const role = session ? await fetchUserRole(session) : null;

    const decision = resolveDestination({
      path: to.path,
      authenticated: !!session,
      role: role as GuardRole,
      status: lastStatus,
      emailVerified: lastEmailVerified,
      registered: lastRegistered,
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
