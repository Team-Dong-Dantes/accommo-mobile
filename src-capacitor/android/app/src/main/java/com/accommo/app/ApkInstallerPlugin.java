package com.accommo.app;

import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import androidx.core.content.FileProvider;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.io.File;

/**
 * Hands an APK the app downloaded itself (UpdateGate.vue, into the cache's
 * Accommo/cache/ folder — the file provider's accommo_cache path) to Android's
 * package installer, so an update never goes through the browser.
 *
 * Android still has the last word: the first time, the user must allow accommo
 * to install apps ("Install unknown apps"), and every install shows the
 * system's own confirmation. Only an app store can skip those. The installer
 * also refuses an APK not signed with the same key as the installed app.
 */
@CapacitorPlugin(name = "ApkInstaller")
public class ApkInstallerPlugin extends Plugin {

    @PluginMethod
    public void install(PluginCall call) {
        String path = call.getString("path");
        if (path == null) {
            call.reject("No update file.");
            return;
        }
        File apk = new File(getContext().getCacheDir(), path);
        if (!apk.isFile()) {
            call.reject("The update file is missing. Download it again.");
            return;
        }

        JSObject result = new JSObject();
        // Android 8+: installing needs a per-app switch the user flips once.
        // Without it the installer would only show an error, so open that
        // switch's screen instead and let the page ask them to come back.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            && !getContext().getPackageManager().canRequestPackageInstalls()) {
            Intent settings = new Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:" + getContext().getPackageName())
            );
            settings.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(settings);
            result.put("opened", "settings");
            call.resolve(result);
            return;
        }

        Uri uri = FileProvider.getUriForFile(getContext(), getContext().getPackageName() + ".fileprovider", apk);
        Intent install = new Intent(Intent.ACTION_VIEW);
        install.setDataAndType(uri, "application/vnd.android.package-archive");
        install.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            getContext().startActivity(install);
        } catch (Exception e) {
            call.reject("Android's installer could not be opened.");
            return;
        }
        result.put("opened", "installer");
        call.resolve(result);
    }
}
