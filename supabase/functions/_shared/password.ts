// One-time passwords OSAS hands out (invite fallback, forgotten passwords).
//
// No look-alikes (0/O, 1/l/I), since they are read out or written down at the
// desk. One of each character class is appended so the result always passes
// the project's password rule (8+, lower, upper, digit, symbol) — the auth
// admin API applies it to these too.

const pick = (set: string, n: number) =>
  [...crypto.getRandomValues(new Uint8Array(n))].map((b) => set[b % set.length]).join('');

const UPPER = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const LOWER = 'abcdefghijkmnpqrstuvwxyz';
const DIGIT = '23456789';
const SYMBOL = '!@#$%&*';

export function generateTempPassword(): string {
  return pick(UPPER + LOWER + DIGIT, 10) + pick(UPPER, 1) + pick(LOWER, 1) + pick(DIGIT, 1) + pick(SYMBOL, 1);
}
