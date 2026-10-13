// Cloudflare Turnstile: proof that a person, not a script, is behind a sign-in,
// sign-up, e-mail code or password reset. Without it a bot could guess
// passwords from many addresses, or burn the project's hourly e-mail allowance
// with fake sign-ups so real users never get their codes.
//
// Supabase Auth checks the token itself (Auth → Bot and Abuse Protection);
// request-admin-reset checks its own. Google sign-in needs none: Supabase
// exempts id_token sign-ins, and Google has already vetted the person.
//
// Invisible unless Cloudflare wants a click, in which case its checkbox shows in
// the middle of the screen. Fails soft: if Cloudflare can't be reached the
// request goes out without a token, which only matters while Supabase enforces
// CAPTCHA, and then Supabase refuses it with a clear error.
//
// Kept identical to accommo-web/src/utils/captcha.ts.

const SITE_KEY = '0x4AAAAAAFVxPRSnuuM7ToBS';
const SCRIPT = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';

interface Turnstile {
  render(el: HTMLElement, options: Record<string, unknown>): string;
  remove(widgetId: string): void;
}

declare global {
  interface Window {
    turnstile?: Turnstile;
  }
}

let loading: Promise<Turnstile> | null = null;

function load(): Promise<Turnstile> {
  return (loading ??= new Promise<Turnstile>((resolve, reject) => {
    const script = document.createElement('script');
    script.src = SCRIPT;
    script.async = true;
    script.onload = () => (window.turnstile ? resolve(window.turnstile) : reject(new Error('Turnstile missing')));
    script.onerror = () => {
      loading = null;
      reject(new Error('Turnstile blocked'));
    };
    document.head.appendChild(script);
  }));
}

/** A one-time token for the next auth request, or undefined when Cloudflare can't be reached. */
async function captchaToken(timeoutMs = 15000): Promise<string | undefined> {
  let turnstile: Turnstile;
  try {
    turnstile = await load();
  } catch {
    return undefined;
  }

  const box = document.createElement('div');
  box.style.cssText = 'position:fixed;left:50%;top:50%;transform:translate(-50%,-50%);z-index:10000';
  document.body.appendChild(box);

  return new Promise((resolve) => {
    let widgetId = '';
    let settled = false;
    const done = (token?: string) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (widgetId) turnstile.remove(widgetId);
      box.remove();
      resolve(token);
    };
    // Only for a silent check that never answers; once Cloudflare asks for a
    // click, the person gets as long as they need.
    const timer = setTimeout(() => done(undefined), timeoutMs);
    try {
      widgetId = turnstile.render(box, {
        sitekey: SITE_KEY,
        appearance: 'interaction-only',
        callback: (token: string) => done(token),
        'error-callback': () => done(undefined),
        'before-interactive-callback': () => clearTimeout(timer),
      });
    } catch {
      done(undefined);
    }
  });
}

/** Options to spread into an auth call: `{ captchaToken }`, or nothing when no token could be had. */
export async function captcha(): Promise<{ captchaToken?: string }> {
  const token = await captchaToken();
  return token ? { captchaToken: token } : {};
}
