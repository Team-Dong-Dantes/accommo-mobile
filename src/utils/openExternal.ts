import { Capacitor } from '@capacitor/core';

/**
 * Open a URL outside the app — a document, a map, the APK download.
 *
 * Not `window.open` on Android. Capacitor's WebView never calls
 * `setSupportMultipleWindows(true)` and `BridgeWebViewClient` overrides no
 * `onCreateWindow`, so `window.open(url, '_blank')` has nowhere to go and is
 * dropped silently — the tap looks like it did nothing. What Capacitor *does*
 * intercept is a navigation: `shouldOverrideUrlLoading` hands the URL to
 * `Bridge.launchIntent`, which fires an `ACTION_VIEW` intent for any host that
 * is neither the app's own origin nor in `server.allowNavigation` (this app
 * sets neither, so every off-origin link qualifies). That reaches the system
 * browser, which can also actually download a file.
 *
 * On the web build there is no such interception and assigning `location.href`
 * would navigate away from the app, so keep the new tab there.
 */
export function openExternal(url: string): void {
  if (!url) return;
  if (Capacitor.isNativePlatform()) {
    window.location.href = url;
    return;
  }
  window.open(url, '_blank', 'noopener');
}
