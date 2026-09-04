// Supabase/PostgREST failures arrive as PLAIN OBJECTS carrying `message`,
// `code`, `details` and `hint` — they are not Error instances. The common
// `e instanceof Error ? e.message : 'Something went wrong.'` therefore throws
// away the only useful part and shows a generic string, which hides real
// faults (a missing grant, a bad column) behind "Something went wrong."

export function errorMessage(error: unknown, fallback = 'Something went wrong.'): string {
  if (!error) return fallback;
  if (error instanceof Error) return error.message || fallback;

  if (typeof error === 'object') {
    const e = error as { message?: unknown; details?: unknown; hint?: unknown; code?: unknown };
    const message = typeof e.message === 'string' ? e.message : '';
    const details = typeof e.details === 'string' ? e.details : '';
    const hint = typeof e.hint === 'string' ? e.hint : '';
    const text = message || details || hint;
    if (text) return e.code ? `${text} (${String(e.code)})` : text;
  }

  if (typeof error === 'string' && error) return error;
  return fallback;
}
