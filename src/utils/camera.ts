import { Camera } from '@capacitor/camera';
import { Capacitor } from '@capacitor/core';

export interface CaptureOutcome {
  /** The captured photo, or null when nothing was taken. */
  file: File | null;
  /** A message worth showing the user. Null for a plain cancel. */
  error: string | null;
}

const INSECURE =
  'The camera needs a secure connection (https, or localhost). Opened over a plain http address, the browser withholds camera access — use Upload instead, or open the app over https.';
const NO_CAMERA_API = "This browser won't give the page camera access. Use Upload instead.";

/**
 * Last-resort capture that goes through the WebView instead of the native
 * camera intent.
 *
 * `<input capture>` hands an image back through the page, so it needs no
 * native plumbing at all. Kept as a last resort for a device where the
 * in-app camera cannot start; note Android may show a chooser rather than
 * going straight to the camera, so it is a fallback, never the first choice.
 */
function captureViaInput(): Promise<File | null> {
  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.setAttribute('capture', 'environment');
    input.style.display = 'none';

    let settled = false;
    const done = (file: File | null) => {
      if (settled) return;
      settled = true;
      input.remove();
      resolve(file);
    };

    input.addEventListener('change', () => done(input.files?.[0] ?? null));
    // A cancelled picker fires no event on Android; the window regaining focus
    // is the only signal, and the delay lets a real 'change' win the race.
    window.addEventListener('focus', () => setTimeout(() => done(null), 900), { once: true });

    document.body.appendChild(input);
    input.click();
  });
}

/**
 * One camera entry point for the whole app.
 *
 * Off-native, the Capacitor plugin falls back to a `<pwa-camera-modal>` that
 * needs `navigator.mediaDevices.getUserMedia`, and browsers only expose that
 * on a secure origin. Serving the app over a LAN IP (`http://192.168.x.x`)
 * therefore leaves `navigator.mediaDevices` undefined and the custom element
 * unregistered, so the camera call throws.
 *
 * Every call site used to swallow that in a bare `catch`, which made a
 * genuinely broken camera look identical to the user tapping cancel: nothing
 * happened, no explanation. So check the environment up front, and only stay
 * silent for an actual cancel.
 */
export async function capturePhoto(): Promise<CaptureOutcome> {
  if (!Capacitor.isNativePlatform()) {
    if (!window.isSecureContext) return { file: null, error: INSECURE };
    if (!navigator.mediaDevices?.getUserMedia) return { file: null, error: NO_CAMERA_API };
  }

  try {
    // takePhoto(), not the deprecated getPhoto(): on Android the old call runs
    // through LegacyCameraFlow, which hands the system camera app a file via
    // the app's FileProvider — the step that fails with "Unable to create photo
    // on disk" when that provider is misconfigured, and which then degrades to
    // a file chooser. takePhoto() uses the plugin's own in-app camera and never
    // touches FileProvider.
    const photo = await Camera.takePhoto({ quality: 80 });
    const path = photo.webPath || photo.uri;
    if (!path) return { file: null, error: null };
    const blob = await (await fetch(path)).blob();
    const ext = blob.type.split('/')[1] || 'jpeg';
    return {
      file: new File([blob], `photo.${ext}`, { type: blob.type || `image/${ext}` }),
      error: null,
    };
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    // Cancelling isn't a failure; anything else is worth surfacing.
    if (/cancel/i.test(message)) return { file: null, error: null };

    // The native intent could not be given a file to write to — the app's
    // FileProvider is misconfigured. The WebView can still reach the camera,
    // so try that before telling the user the camera is broken.
    if (/photo on disk|fileprovider|configured root|unimplemented/i.test(message)) {
      const file = await captureViaInput();
      if (file) return { file, error: null };
      return {
        file: null,
        error:
          'The camera could not save the photo. Use Upload instead — and the app build needs its FileProvider configured.',
      };
    }

    return { file: null, error: message || 'Could not open the camera.' };
  }
}
