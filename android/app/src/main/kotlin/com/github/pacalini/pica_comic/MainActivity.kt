package com.github.pacalini.pica_comic

import android.app.Activity
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Environment
import android.Manifest
import android.provider.DocumentsContract
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.glance.appwidget.GlanceAppWidgetManager
import com.google.android.gms.common.GoogleApiAvailability
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity: FlutterFragmentActivity() {
    var volumeListen = VolumeListen()
    var listening = false
    private var pendingDirectoryResult: MethodChannel.Result? = null
    private var pendingStorageAccessResult: MethodChannel.Result? = null
    private var widgetChannel: MethodChannel? = null
    private var pendingWidgetAction: String? = null


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        val channel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.github.pacalini.pica_comic/volume")
        channel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    listening = true
                    volumeListen.whenUp = {
                        events.success(1)
                    }
                    volumeListen.whenDown = {
                        events.success(2)
                    }
                }
                override fun onCancel(arguments: Any?) {
                    listening = false
                }
        })
        //拦截屏幕截图
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"com.github.pacalini.pica_comic/screenshot").setMethodCallHandler{
                _, _ ->
            window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"com.github.pacalini.pica_comic/secure").setMethodCallHandler{
                _, _ ->
            window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        }
        //获取cpu架构
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"com.github.pacalini.pica_comic/device").setMethodCallHandler{
                _, res ->
            res.success(getDeviceInfo())
        }
        //获取http代理
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"com.github.pacalini.pica_comic/proxy").setMethodCallHandler{
                _, res ->
            res.success(getProxy())
        }
        //保持屏幕常亮
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"com.github.pacalini.pica_comic/keepScreenOn").setMethodCallHandler{
                call, _ ->
            if(call.method == "set")
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            else
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DOWNLOAD_SERVICE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(applicationContext, DownloadForegroundService::class.java).apply {
                        putExtra(
                            DownloadForegroundService.EXTRA_TITLE,
                            call.argument<String>("title") ?: "下载中",
                        )
                        putExtra(
                            DownloadForegroundService.EXTRA_CONTENT,
                            call.argument<String>("content") ?: "",
                        )
                    }
                    try {
                        ContextCompat.startForegroundService(applicationContext, intent)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("start_failed", error.message, null)
                    }
                }
                "stop" -> {
                    val intent = Intent(applicationContext, DownloadForegroundService::class.java)
                    val stopped = applicationContext.stopService(intent)
                    applicationContext.getSystemService(NotificationManager::class.java)
                        .cancel(DownloadForegroundService.NOTIFICATION_ID)
                    result.success(stopped)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"pica_comic/playServer").setMethodCallHandler{
                _, res ->
            val flag = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(this) == com.google.android.gms.common.ConnectionResult.SUCCESS
            res.success(flag)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"pica_comic/settings").setMethodCallHandler{
                call, res ->
            if(call.method == "link") {
                val intent = Intent(
                    android.provider.Settings.ACTION_APP_OPEN_BY_DEFAULT_SETTINGS,
                    Uri.parse("package:com.github.pacalini.pica_comic"),
                )
                startActivity(intent)
                res.success(null)
            } else if(call.method == "files") {
                val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    Intent(android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                } else {
                    Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                }
                intent.data = Uri.parse("package:com.github.pacalini.pica_comic")
                startActivity(intent)
                res.success(null)
            } else if(call.method == "files_check") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    res.success(Environment.isExternalStorageManager())
                } else {
                    res.success(
                        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                            && ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED)
                }
            }

        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DIRECTORY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureStorageAccess" -> ensureStorageAccess(result)
                    "pickDirectory" -> pickDirectory(result)
                    "openDirectory" -> {
                        val path = call.arguments as? String
                        result.success(path != null && openDirectory(path))
                    }
                    else -> result.notImplemented()
                }
            }

        widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ANDROID_WIDGET_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateHistorySnapshot" -> {
                        val snapshot = call.argument<String>("snapshot")
                        if (snapshot != null) {
                            WidgetDataStore.saveSnapshot(applicationContext, snapshot)
                            refreshWidget()
                        }
                        result.success(null)
                    }
                    "getInitialWidgetAction" -> {
                        val action = pendingWidgetAction
                        pendingWidgetAction = null
                        result.success(if (action.isNullOrEmpty()) null else action)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWidgetIntent(intent)
    }

    private fun handleWidgetIntent(intent: Intent?) {
        val payload = intent?.getStringExtra(WIDGET_ACTION_EXTRA) ?: return
        intent.removeExtra(WIDGET_ACTION_EXTRA)
        val channel = widgetChannel
        if (channel != null) {
            channel.invokeMethod("onWidgetAction", payload, null)
        } else {
            pendingWidgetAction = payload
        }
    }

    private fun refreshWidget() {
        CoroutineScope(Dispatchers.IO).launch {
            val manager = GlanceAppWidgetManager(applicationContext)
            val widget = HistoryWidget()
            manager.getGlanceIds(HistoryWidget::class.java).forEach { glanceId ->
                widget.update(applicationContext, glanceId)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == DIRECTORY_REQUEST_CODE) {
            val result = pendingDirectoryResult
            pendingDirectoryResult = null
            if (result == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }

            if (resultCode != Activity.RESULT_OK) {
                result.success(null)
                return
            }

            val uri = data?.data
            if (uri == null) {
                result.success(null)
                return
            }

            val flags = data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            try {
                contentResolver.takePersistableUriPermission(uri, flags)
            } catch (_: SecurityException) {
            }

            val path = treeUriToPath(uri)
            if (path == null) {
                result.error(
                    "unsupported_directory",
                    "Only primary shared-storage folders can be used as a download directory.",
                    uri.toString(),
                )
            } else {
                result.success(path)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (requestCode == STORAGE_PERMISSION_REQUEST_CODE) {
            val result = pendingStorageAccessResult
            pendingStorageAccessResult = null
            result?.success(hasStorageAccess())
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if(listening){
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    volumeListen.down()
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    volumeListen.up()
                    return true
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun getDeviceInfo(): String{
        //获取cpu架构从而找到应当下载的app版本
        return Build.SUPPORTED_ABIS[0]
    }

    private fun getProxy(): String{
        val host = System.getProperty("http.proxyHost")
        val port = System.getProperty("http.proxyPort")
        return if(host!=null&&port!=null){
            "$host:$port"
        }else{
            "No Proxy"
        }
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        if (pendingDirectoryResult != null) {
            result.error("busy", "A directory picker is already open.", null)
            return
        }
        pendingDirectoryResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        try {
            startActivityForResult(intent, DIRECTORY_REQUEST_CODE)
        } catch (error: ActivityNotFoundException) {
            pendingDirectoryResult = null
            result.error("picker_unavailable", error.message, null)
        }
    }

    private fun ensureStorageAccess(result: MethodChannel.Result) {
        if (hasStorageAccess()) {
            result.success(true)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                startActivity(
                    Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                        data = Uri.parse("package:$packageName")
                    },
                )
            } catch (_: ActivityNotFoundException) {
                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
            }
            result.success(false)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (pendingStorageAccessResult != null) {
                result.error("busy", "A storage permission request is already open.", null)
                return
            }
            pendingStorageAccessResult = result
            val permissions = if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
                arrayOf(
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE,
                )
            } else {
                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
            requestPermissions(permissions, STORAGE_PERMISSION_REQUEST_CODE)
            return
        }
        result.success(true)
    }

    private fun hasStorageAccess(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return Environment.isExternalStorageManager()
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val hasRead = checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
            if (!hasRead) {
                return false
            }
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
                return checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
                    PackageManager.PERMISSION_GRANTED
            }
            return true
        }
        return true
    }

    private fun openDirectory(path: String): Boolean {
        val documentUri = pathToPrimaryDocumentUri(path) ?: return false
        val documentId = DocumentsContract.getDocumentId(documentUri)
        val treeUri = DocumentsContract.buildTreeDocumentUri(
            "com.android.externalstorage.documents",
            documentId,
        )
        val treeDocumentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId)

        val candidates = buildList {
            // 1. 不带 MIME type：部分设备的 DocumentsUI 只注册了纯 content URI 的 VIEW 处理
            add(Intent(Intent.ACTION_VIEW).apply {
                setData(documentUri)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            })
            // 2. 带目录 MIME type 的普通 document URI
            add(Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(documentUri, DocumentsContract.Document.MIME_TYPE_DIR)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            })
            // 3. tree 型 document URI（与 SAF 持久化授权同源，便于授权通过）
            add(Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(treeDocumentUri, DocumentsContract.Document.MIME_TYPE_DIR)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            })
            // 4. 兜底：至少打开系统文件管理器根目录，避免直接提示失败
            add(Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(
                    Uri.parse("content://com.android.externalstorage.documents/root/primary"),
                    "vnd.android.document/root",
                )
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
        }
        for (intent in candidates) {
            try {
                startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
            } catch (_: SecurityException) {
            }
        }
        return false
    }

    private fun pathToPrimaryDocumentUri(path: String): Uri? {
        val root = Environment.getExternalStorageDirectory().absolutePath
        if (path != root && !path.startsWith("$root/")) {
            return null
        }
        val relative = path.removePrefix(root).trimStart('/')
        val documentId = if (relative.isEmpty()) "primary:" else "primary:$relative"
        return DocumentsContract.buildDocumentUri(
            "com.android.externalstorage.documents",
            documentId,
        )
    }

    private fun treeUriToPath(uri: Uri): String? {
        if (!DocumentsContract.isTreeUri(uri)) {
            return null
        }
        val treeDocumentId = DocumentsContract.getTreeDocumentId(uri)
        return documentIdToPath(treeDocumentId)
    }

    private fun documentIdToPath(documentId: String): String? {
        val decoded = Uri.decode(documentId)
        if (decoded.startsWith("/")) {
            return decoded
        }

        val separator = decoded.indexOf(':')
        if (separator < 0) {
            return null
        }

        val volume = decoded.substring(0, separator)
        val remainder = decoded.substring(separator + 1)
        val root = Environment.getExternalStorageDirectory().absolutePath

        return when (volume) {
            "primary", "home" -> {
                if (remainder.isEmpty()) root else "$root/$remainder"
            }
            "raw" -> {
                when {
                    remainder.startsWith("/") -> remainder
                    remainder.startsWith("storage/") -> "/$remainder"
                    remainder.isEmpty() -> null
                    else -> "/$remainder"
                }
            }
            else -> {
                val candidate = if (remainder.isEmpty()) {
                    java.io.File("/storage/$volume")
                } else {
                    java.io.File("/storage/$volume/$remainder")
                }
                if (candidate.exists()) candidate.absolutePath else null
            }
        }
    }

    companion object {
        private const val DIRECTORY_CHANNEL = "ezvenera/directory"
        private const val DOWNLOAD_SERVICE_CHANNEL =
            "com.github.pacalini.pica_comic/download_service"
        private const val DIRECTORY_REQUEST_CODE = 14021
        private const val STORAGE_PERMISSION_REQUEST_CODE = 14022
    }
}

class VolumeListen{
    var whenUp = fun() {}
    var whenDown = fun() {}
    fun up(){
        whenUp()
    }
    fun down(){
        whenDown()
    }
}
