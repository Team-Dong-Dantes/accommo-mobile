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
  let lastRejected = false;

  async function fetchUserRole(session: { user: { id: string; user_metadata?: Record<string, unknown> } }): Promise<string | null> {
    const authStore = useAuthStore();
    if (authStore.cachedRole && lastStatus) return authStore.cachedRole;

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
        lastRejected = data.status === 'rejected';

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
    if ((import.meta.env.VITE_DEMO_MODE as unknown) === 'true') {
      return true;
    }

    const { data: { session } } = await supabase.auth.getSession();
    const isAuthenticated = !!session;

    const publicRoutes = ['/', '/login', '/register', '/register/role', '/register/manager'];
    const isPublicRoute = publicRoutes.includes(to.path);

    if (!isAuthenticated && !isPublicRoute) {
      return '/login';
    }

    if (isAuthenticated) {
      // Suspension has to bite here too, or an already-signed-in user keeps the
      // run of the app for the life of their token.
      if (!to.path.startsWith('/register')) {
        const role = await fetchUserRole(session);
        if (role !== null && lastStatus === 'suspended') {
          await supabase.auth.signOut();
          useAuthStore().clearCachedRole();
          lastStatus = null;
          return '/login?suspended=true';
        }
        // Signed in but never proved they read their e-mail. The session is kept
        // so the login screen can offer them a code instead of a dead end.
        //
        // Must ALLOW /login and /register here rather than redirect: returning a
        // new location unconditionally made this guard redirect on every call,
        // including the call for /login?verifyEmail=true itself, which Vue Router
        // aborts as an infinite redirect and the app never boots.
        if (role !== null && lastEmailVerified === false) {
          if (to.path === '/login' || to.path.startsWith('/register')) return true;
          return '/login?verifyEmail=true';
        }
        // The account exists but its owner never finished registering — the normal
        // state right after "Continue with Google", because signInWithOAuth
        // provisions the user whether they came from login or register. Send them
        // to pick a role rather than dropping them into the app as a student.
        if (role !== null && lastRegistered === false) {
          if (to.path.startsWith('/register') || to.path === '/login') return true;
          return '/register/role';
        }
      }

      if (to.path.startsWith('/register')) {
        // Only a FINISHED account is barred from re-registering. The old check
        // was "has a users row", but the auth trigger always creates one, so a
        // brand-new Google signup was evicted with "account already exists" and
        // could never complete its profile.
        const role = await fetchUserRole(session);
        // A manager OSAS has sent back is registered, but must be allowed onto the
        // register screen to correct the application — otherwise the eviction below
        // would sign them out before the resubmission redirect could ever run.
        const resubmitting = role === 'manager'
          && (lastStatus === 'rejected' || lastStatus === 'reviewing');
        if (role !== null && lastRegistered === true && !resubmitting) {
          await supabase.auth.signOut();
          return '/login?accountExists=true';
        }
        return true;
      }

      if (to.path === '/profile') {
        const role = await fetchUserRole(session);
        if (role === 'manager') return '/manager/profile';
        if (role === 'student') return '/student/profile';
      }

      if (isPublicRoute) {
        const role = await fetchUserRole(session);
        if (role === 'student') return '/student/home';
        if (role === 'manager') return '/manager/dashboard';
        // Admin/OSAS lives in the web client — this app has no admin surface.
        if (role === 'admin') {
          await supabase.auth.signOut();
          return '/login?adminUsesWeb=true';
        }
        // Missing or unrecognized role: invalid account state. Sign out and land
        // on a safe (still public) route instead of returning '/' again, which
        // would re-trigger this guard and loop forever.
        await supabase.auth.signOut();
        return role === null ? '/register?newUser=true' : '/login';
      }

      // Admin/OSAS has no surface in this app. Without this, LoginPage's push to
      // /admin/dashboard fell through to a 404 instead of saying so.
      const adminRole = await fetchUserRole(session);
      if (adminRole === 'admin') {
        await supabase.auth.signOut();
        useAuthStore().clearCachedRole();
        return '/login?adminUsesWeb=true';
      }

      // Role-based authorization: protect student vs manager routes
      const role = await fetchUserRole(session);

      // A manager holds no session at all until OSAS approves the application —
      // not a reduced surface, no session. Enforced here as well as in login()
      // so a session that predates the decision (or one left open while OSAS
      // rejects) is dropped on the next navigation.
      //
      // Students are deliberately NOT treated this way: a pending student may
      // browse while waiting, and the lease policy already stops them acting.
      if (role === 'manager' && lastStatus === 'pending') {
        await supabase.auth.signOut();
        useAuthStore().clearCachedRole();
        lastStatus = null;
        return '/login?awaitingApproval=true';
      }
      // OSAS has replied and wants changes: let them in, but only to the screen
      // where they can act on it.
      if (role === 'manager' && (lastStatus === 'rejected' || lastStatus === 'reviewing')) {
        if (!to.path.startsWith('/register')) return '/register/manager?resubmit=true';
      }
      if (to.path.startsWith('/student') && role !== 'student') {
        return role === 'manager' ? '/manager/dashboard' : '/login';
      }
      if (to.path.startsWith('/manager') && role !== 'manager') {
        return role === 'student' ? '/student/home' : '/login';
      }
    }

    return true;
  });

  return Router;
});
