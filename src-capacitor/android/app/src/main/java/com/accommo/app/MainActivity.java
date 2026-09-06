package com.accommo.app;

import android.os.Bundle;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.WebView;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

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
