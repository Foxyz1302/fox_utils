// The pasteboard part is modified from MixinNetwork's pasteboard v0.5.0 (Apache-2.0, Copyright Mixin Network; see LICENSE).
package com.foxyz.fox_utils;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Environment;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * Fox utils Android plugin.
 *
 * <p>Two channels:
 * <ul>
 *   <li>{@code fox_utils/android_files} — permission-free saving to public
 *       directories (see AndroidFiles.save).</li>
 *   <li>{@code pasteboard} — clipboard image/files read/write, ported from
 *       one.mixin.pasteboard (Apache-2.0) with fixes: byte-faithful image
 *       writes (no Bitmap re-encode), correct async executor use, and a
 *       working writeFiles clip assembly.</li>
 * </ul>
 */
public class FoxUtilsPlugin implements FlutterPlugin, MethodCallHandler {
    private static final String FILES_CHANNEL = "fox_utils/android_files";
    private static final String CLIPBOARD_CHANNEL = "pasteboard";
    private static final String CLIPBOARD_X_CHANNEL = "fox_utils/clipboard";

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        new MethodChannel(binding.getBinaryMessenger(), FILES_CHANNEL).setMethodCallHandler(this);
        new MethodChannel(binding.getBinaryMessenger(), CLIPBOARD_CHANNEL).setMethodCallHandler(this);
        new MethodChannel(binding.getBinaryMessenger(), CLIPBOARD_X_CHANNEL).setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            // --- fox_utils/android_files ---
            case "saveFile":
                saveFile(call, result);
                break;
            // --- pasteboard (vendored) ---
            case "image":
                readImage(result);
                break;
            case "files":
                readFiles(result);
                break;
            case "html":
                readHtml(result);
                break;
            case "writeFiles":
                writeFiles(call, result);
                break;
            case "writeImage":
                writeImage(call, result);
                break;
            // --- fox_utils/clipboard ---
            case "readFileBytes":
                readFileBytes(call, result);
                break;
            default:
                result.notImplemented();
        }
    }

    // --- fox_utils/android_files ---

    private void saveFile(MethodCall call, Result result) {
        final byte[] bytes = call.argument("bytes");
        final String fileName = call.argument("fileName");
        final String location = call.argument("location");
        final String subPath = call.argument("subPath");
        final Boolean scan = call.argument("scan");
        if (bytes == null || fileName == null || location == null || subPath == null || scan == null) {
            result.error("INVALID_ARGUMENTS", "saveFile requires bytes, fileName, location, subPath and scan.", null);
            return;
        }
        executor.execute(() -> {
            try {
                result.success(saveFileSync(bytes, fileName, location, subPath, scan));
            } catch (Exception e) {
                result.error("SAVE_FAILED", e.getMessage(), null);
            }
        });
    }

    @SuppressWarnings("deprecation") // Still works permission-free on modern Android.
    private String saveFileSync(byte[] bytes, String fileName, String location, String subPath, boolean scan)
            throws IOException {
        File base = new File(Environment.getExternalStoragePublicDirectory(directoryFor(location)), subPath);
        if (!base.exists() && !base.mkdirs()) {
            throw new IOException("Could not create directory " + base);
        }
        File file = new File(base, fileName);
        try (FileOutputStream out = new FileOutputStream(file)) {
            out.write(bytes);
        }
        if (scan) {
            MediaScannerConnection.scanFile(context, new String[]{file.getAbsolutePath()}, null, null);
        }
        return file.getAbsolutePath();
    }

    private static String directoryFor(String location) {
        switch (location) {
            case "movies":
                return Environment.DIRECTORY_MOVIES;
            case "music":
                return Environment.DIRECTORY_MUSIC;
            case "downloads":
                return Environment.DIRECTORY_DOWNLOADS;
            case "pictures":
            default:
                return Environment.DIRECTORY_PICTURES;
        }
    }

    // --- pasteboard channel (vendored from one.mixin.pasteboard, Apache-2.0) ---

    private ClipboardManager clipboard() {
        return (ClipboardManager) context.getSystemService(Context.CLIPBOARD_SERVICE);
    }

    private void readImage(Result result) {
        executor.execute(() -> {
            try {
                ClipData.Item first = firstClipItem();
                if (first == null || first.getUri() == null) {
                    result.success(null);
                    return;
                }
                Uri uri = first.getUri();
                String mime = context.getContentResolver().getType(uri);
                if (mime == null || !mime.startsWith("image")) {
                    result.success(null);
                    return;
                }
                try (InputStream in = context.getContentResolver().openInputStream(uri)) {
                    if (in == null) {
                        result.success(null);
                        return;
                    }
                    result.success(readAll(in));
                }
            } catch (Exception e) {
                result.error("Error", "Failed to read image", e.getMessage());
            }
        });
    }

    private void readFiles(Result result) {
        ClipData clip = clipboard().getPrimaryClip();
        if (clip == null || clip.getItemCount() == 0) {
            result.success(null);
            return;
        }
        List<String> files = new ArrayList<>();
        for (int i = 0; i < clip.getItemCount(); i++) {
            Uri uri = clip.getItemAt(i).getUri();
            if (uri != null) {
                files.add(uri.toString());
            }
        }
        result.success(files);
    }

    private void readHtml(Result result) {
        ClipData.Item first = firstClipItem();
        result.success(first == null ? null : first.getHtmlText());
    }

    private void writeFiles(MethodCall call, Result result) {
        @SuppressWarnings("unchecked")
        List<String> args = call.arguments();
        if (args == null) {
            result.error("NoArgs", "Missing Arguments", null);
            return;
        }
        ClipboardManager manager = clipboard();
        ClipData clip = null;
        for (String path : args) {
            Uri uri = Uri.parse(path);
            if (clip == null) {
                clip = ClipData.newUri(context.getContentResolver(), "files", uri);
            } else {
                clip.addItem(new ClipData.Item(uri));
            }
        }
        if (clip != null) {
            manager.setPrimaryClip(clip);
        }
        result.success(null);
    }

    private void writeImage(MethodCall call, Result result) {
        byte[] image = call.arguments();
        if (image == null) {
            result.error("NoArgs", "Missing Arguments", null);
            return;
        }
        // Bytes are staged as-is (no re-encode); the extension is sniffed from
        // the magic bytes so receivers get the correct MIME type — animated
        // GIFs and WebP survive copy/paste this way.
        final File file = new File(context.getCacheDir(),
                UUID.randomUUID().toString() + extensionFor(image));
        executor.execute(() -> {
            try {
                try (FileOutputStream out = new FileOutputStream(file)) {
                    out.write(image);
                }
                Uri uri = FileProvider.getUriForFile(context, context.getPackageName() + ".provider", file);
                clipboard().setPrimaryClip(ClipData.newUri(context.getContentResolver(), "image", uri));
                result.success(null);
            } catch (Exception e) {
                result.error("Error", "Failed to write image", e.getMessage());
            }
        });
    }

    private ClipData.Item firstClipItem() {
        ClipData clip = clipboard().getPrimaryClip();
        return clip == null || clip.getItemCount() == 0 ? null : clip.getItemAt(0);
    }

    /** Resolves a content URI (e.g. a file manager's clipboard entry) to bytes. */
    private void readFileBytes(MethodCall call, Result result) {
        String uri = call.arguments();
        if (uri == null) {
            result.error("NoArgs", "Missing Arguments", null);
            return;
        }
        executor.execute(() -> {
            try (InputStream in = context.getContentResolver().openInputStream(Uri.parse(uri))) {
                if (in == null) {
                    result.success(null);
                    return;
                }
                result.success(readAll(in));
            } catch (Exception e) {
                result.error("Error", "Failed to read file", e.getMessage());
            }
        });
    }

    /** Sniffs common image magic bytes so the pasted file carries the right MIME type. */
    private static String extensionFor(byte[] b) {
        if (b.length >= 3 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF) {
            return ".jpg";
        }
        if (b.length >= 8 && (b[0] & 0xFF) == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
            return ".png";
        }
        if (b.length >= 6 && (b[0] & 0xFF) == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) {
            return ".gif";
        }
        if (b.length >= 12 && b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F'
                && b[4] == 'W' && b[5] == 'E' && b[6] == 'B' && b[7] == 'P') {
            return ".webp";
        }
        if (b.length >= 2 && b[0] == 'B' && b[1] == 'M') {
            return ".bmp";
        }
        return ".png";
    }

    private static byte[] readAll(InputStream in) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buf = new byte[8192];
        int n;
        while ((n = in.read(buf)) != -1) {
            out.write(buf, 0, n);
        }
        return out.toByteArray();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        context = null;
        executor.shutdown();
    }
}
