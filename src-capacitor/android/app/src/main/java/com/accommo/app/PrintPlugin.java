package com.accommo.app;

import android.content.Context;
import android.print.PrintAttributes;
import android.print.PrintManager;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/**
 * Prints (or saves as PDF, from the same system dialog) an HTML document the
 * page hands over. The document is loaded into an offscreen WebView, not the
 * app's own: printing the app's WebView would print the screen, and the report
 * has its own page frame and CSS.
 */
@CapacitorPlugin(name = "Print")
public class PrintPlugin extends Plugin {

    // PrintManager reads the adapter after print() returns; a WebView nothing
    // references can be collected before the dialog is done with it.
    private WebView printView;

    @PluginMethod
    public void print(PluginCall call) {
        final String html = call.getString("html");
        final String name = call.getString("name", "Accommo");
        final boolean landscape = "landscape".equals(call.getString("orientation"));
        final boolean longPaper = "long".equals(call.getString("paper"));
        if (html == null) {
            call.reject("No document to print.");
            return;
        }
        getActivity().runOnUiThread(() -> {
            WebView view = new WebView(getActivity());
            printView = view;
            view.setWebViewClient(new WebViewClient() {
                @Override
                public void onPageFinished(WebView v, String url) {
                    PrintManager pm = (PrintManager) getActivity().getSystemService(Context.PRINT_SERVICE);
                    // "Long" is 8.5 x 13 in (Philippine long bond paper).
                    PrintAttributes.MediaSize size = longPaper
                        ? new PrintAttributes.MediaSize("long", "Long", 8500, 13000)
                        : PrintAttributes.MediaSize.ISO_A4;
                    pm.print(name, v.createPrintDocumentAdapter(name), new PrintAttributes.Builder()
                        .setMediaSize(landscape ? size.asLandscape() : size.asPortrait())
                        .build());
                    call.resolve(new JSObject());
                }
            });
            view.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null);
        });
    }
}
