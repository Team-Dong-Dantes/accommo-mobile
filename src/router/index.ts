import { defineRouter } from '#q-app';
import {
  createMemoryHistory,
  createRouter,
  createWebHashHistory,
  createWebHistory,
} from 'vue-router';
import routes from './routes';
import { supabase } from '@/shared/utils/supabase';
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

  async function fetchUserRole(session: { user: { id: string; user_metadata?: Record<string, unknown> } }): Promise<string | null> {
    const authStore = useAuthStore();
    if (authStore.cachedRole) return authStore.cachedRole;

    if (roleFetchInProgress) return roleFetchInProgress;

    roleFetchInProgress = (async () => {
      try {
        const { data, error } = await supabase
          .from('users')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();

        if (error || !data) return null;

        let role = typeof data.role === 'string' ? data.role.toLowerCase() : null;
        if (role === 'accommodation_manager') role = 'landlord';
        if (!role) {
          const metaRole = session.user.user_metadata?.role;
          if (typeof metaRole === 'string' && metaRole) {
            role = metaRole.toLowerCase();
            if (role === 'accommodation_manager') role = 'landlord';
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

    const publicRoutes = ['/', '/login', '/register', '/register/role', '/register/landlord'];
    const isPublicRoute = publicRoutes.includes(to.path);

    if (!isAuthenticated && !isPublicRoute) {
      return '/login';
    }

    if (isAuthenticated) {
      if (to.path.startsWith('/register')) {
        await supabase.auth.signOut();
        return '/login?accountExists=true';
      }

      if (to.path === '/profile') {
        const role = await fetchUserRole(session);
        if (role === 'landlord') return '/landlord/profile';
        if (role === 'student') return '/student/dashboard';
      }

      if (isPublicRoute) {
        const role = await fetchUserRole(session);
        if (role === 'student') return '/student/home';
        if (role === 'landlord') return '/landlord/dashboard';
        if (role === 'admin') return '/admin/dashboard';
        // Missing or unrecognized role: invalid account state. Sign out and land
        // on a safe (still public) route instead of returning '/' again, which
        // would re-trigger this guard and loop forever.
        await supabase.auth.signOut();
        return role === null ? '/register?newUser=true' : '/login';
      }

      // Role-based authorization: protect student vs landlord routes
      const role = await fetchUserRole(session);
      if (to.path.startsWith('/student') && role !== 'student') {
        return role === 'landlord' ? '/landlord/dashboard' : '/login';
      }
      if (to.path.startsWith('/landlord') && role !== 'landlord') {
        return role === 'student' ? '/student/home' : '/login';
      }
    }

    return true;
  });

  return Router;
});
