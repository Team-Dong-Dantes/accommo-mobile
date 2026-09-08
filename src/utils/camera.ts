import { Camera, CameraResultType, CameraSource } from '@capacitor/camera';
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
 * One camera entry point for the whole app.
 *
 * Off-native, the Capacitor plugin falls back to a `<pwa-camera-modal>` that
 * needs `navigator.mediaDevices.getUserMedia`, and browsers only expose that
 * on a secure origin. Serving the app over a LAN IP (`http://192.168.x.x`)
 * therefore leaves `navigator.mediaDevices` undefined and the custom element
 * unregistered, so getPhoto() throws.
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
    const photo = await Camera.getPhoto({
      source: CameraSource.Camera,
      resultType: CameraResultType.Uri,
      quality: 80,
    });
    if (!photo.webPath) return { file: null, error: null };
    const blob = await (await fetch(photo.webPath)).blob();
    const ext = photo.format || 'jpeg';
    return {
      file: new File([blob], `photo.${ext}`, { type: blob.type || `image/${ext}` }),
      error: null,
    };
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    // Cancelling isn't a failure; anything else is worth surfacing.
    if (/cancel/i.test(message)) return { file: null, error: null };
    return { file: null, error: message || 'Could not open the camera.' };
  }
}
