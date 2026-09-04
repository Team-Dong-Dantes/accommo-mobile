package com.accommo.app;

import android.os.Bundle;
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
}
