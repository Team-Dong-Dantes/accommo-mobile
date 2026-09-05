// Light/dark appearance preference. Client-only display setting — no backend
// column, no cross-device sync.

import { Dark } from 'quasar';

const STORAGE_KEY = 'accommo:theme';

export type ThemeMode = 'light' | 'dark';

export function getStoredTheme(): ThemeMode {
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY);
    if (stored === 'light' || stored === 'dark') return stored;
  } catch {
    // localStorage unavailable (private mode, blocked site data) — fall through.
  }
  return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export function applyTheme(mode: ThemeMode) {
  document.documentElement.classList.toggle('dark', mode === 'dark');
  // Keeps Quasar's own component chrome (q-dialog, q-menu, q-skeleton, ripples, …)
  // in sync — those follow Quasar's Dark plugin, not our --m-* CSS vars.
  Dark.set(mode === 'dark');
}

export function setStoredTheme(mode: ThemeMode) {
  try {
    window.localStorage.setItem(STORAGE_KEY, mode);
  } catch {
    // Non-fatal — theme just won't persist across reloads.
  }
  applyTheme(mode);
}

export function toggleTheme(): ThemeMode {
  const next: ThemeMode = getStoredTheme() === 'dark' ? 'light' : 'dark';
  setStoredTheme(next);
  return next;
}
