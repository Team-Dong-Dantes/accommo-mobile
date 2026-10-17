package com.accommo.app;

import android.os.Bundle;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.WebView;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        // Local plugins are registered before super.onCreate builds the bridge.
        registerPlugin(PrintPlugin.class);
        super.onCreate(savedInstanceState);

        // The resume lock covers the app's *reads* — private messages, tenant
        // phone numbers, uploaded school IDs — but Android keeps a snapshot of
        // the last frame for the app switcher, taken as the app goes away and
        // shown from the switcher whether or not the PIN screen is up. Without
        // FLAG_SECURE that thumbnail hands over exactly what the lock exists to
        // hide, and it survives being locked. FLAG_SECURE also blocked every
        // screenshot, which users hit constantly, so on Android 13+ we hide only
        // the switcher snapshot and leave screenshots alone. Older devices have
        // no snapshot-only switch and keep FLAG_SECURE.
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false);
        } else {
            getWindow().setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE
            );
        }

        // Kill Android's elastic edge glow / over-scroll stretching so the app
        // feels native instead of like a browser page bouncing at the scroll ends.
        WebView webView = getBridge().getWebView();
        if (webView != null) {
            webView.setOverScrollMode(WebView.OVER_SCROLL_NEVER);
        }
    }

    @Override
    public void onResume() {
        super.onResume();

        // WebViews commonly render at 60Hz even on 90/120Hz-capable devices
        // unless the hosting window explicitly asks for more. preferredRefreshRate
        // is only a hint — Android clamps it to whatever the display actually
        // supports, so requesting 120 is safe even on lower-refresh-rate devices.
        Window window = getWindow();
        WindowManager.LayoutParams params = window.getAttributes();
        params.preferredRefreshRate = 120f;
        window.setAttributes(params);
    }
}
