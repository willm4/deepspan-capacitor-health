package com.deepspan.health

import android.content.Intent
import androidx.activity.result.ActivityResult
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import com.getcapacitor.JSArray
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.ActivityCallback
import com.getcapacitor.annotation.CapacitorPlugin
import java.time.Duration
import java.time.Instant
import java.time.format.DateTimeParseException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Android implementation of the Deepspan CapacitorHealthkit plugin using Google Health Connect.
 *
 * Registered under the same "CapacitorHealthkit" name as the iOS implementation so that
 * TypeScript calls are platform-transparent. Both the legacy iOS-style API and the new
 * cross-platform API are supported.
 */
@CapacitorPlugin(name = "CapacitorHealthkit")
class HealthPlugin : Plugin() {

    private val pluginVersion = "1.0.0"
    private val manager = HealthManager()
    private val pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val permissionContract = PermissionController.createRequestPermissionResultContract()

    // Stored across the permission-request activity round-trip
    private var pendingReadTypes: List<HealthDataType> = emptyList()
    private var pendingWriteTypes: List<HealthDataType> = emptyList()
    private var pendingIncludeWorkouts: Boolean = false

    override fun handleOnDestroy() {
        super.handleOnDestroy()
        pluginScope.cancel()
    }

    // ── Availability & version ────────────────────────────────────────────────

    @PluginMethod
    fun isAvailable(call: PluginCall) {
        val status = HealthConnectClient.getSdkStatus(context)
        val payload = JSObject().apply {
            put("platform", "android")
            put("available", status == HealthConnectClient.SDK_AVAILABLE)
            if (status != HealthConnectClient.SDK_AVAILABLE) {
                put("reason", availabilityReason(status))
            }
        }
        call.resolve(payload)
    }

    @PluginMethod
    fun getPluginVersion(call: PluginCall) {
        call.resolve(JSObject().apply { put("version", pluginVersion) })
    }

    // ── Authorization ─────────────────────────────────────────────────────────

    /**
     * requestAuthorization supports two calling conventions:
     *
     * 1. Legacy iOS-style: { all: [...], read: [...], write: [...] }
     *    where values are HealthKit group names like "steps", "heartRate", "activity", etc.
     *
     * 2. New cross-platform style: { read: [...], write: [...] }
     *    where values are HealthDataType identifiers like "steps", "heartRate", "sleep", etc.
     */
    @PluginMethod
    fun requestAuthorization(call: PluginCall) {
        val (readTypes, includeWorkouts) = try {
            parseReadTypesWithWorkouts(call)
        } catch (e: IllegalArgumentException) {
            call.reject(e.message, null, e)
            return
        }

        val writeTypes = try {
            parseWriteTypes(call)
        } catch (e: IllegalArgumentException) {
            call.reject(e.message, null, e)
            return
        }

        pluginScope.launch {
            val client = getClientOrReject(call) ?: return@launch
            val permissions = manager.permissionsFor(readTypes, writeTypes, includeWorkouts)

            if (permissions.isEmpty()) {
                val status = manager.authorizationStatus(client, readTypes, writeTypes, includeWorkouts)
                call.resolve(status)
                return@launch
            }

            val granted = client.permissionController.getGrantedPermissions()
            if (granted.containsAll(permissions)) {
                val status = manager.authorizationStatus(client, readTypes, writeTypes, includeWorkouts)
                call.resolve(status)
                return@launch
            }

            pendingReadTypes = readTypes
            pendingWriteTypes = writeTypes
            pendingIncludeWorkouts = includeWorkouts

            val intent = permissionContract.createIntent(context, permissions)
            try {
                startActivityForResult(call, intent, "handlePermissionResult")
            } catch (e: Exception) {
                pendingReadTypes = emptyList()
                pendingWriteTypes = emptyList()
                call.reject("Failed to launch Health Connect permission request.", null, e)
            }
        }
    }

    @ActivityCallback
    private fun handlePermissionResult(call: PluginCall?, result: ActivityResult) {
        if (call == null) return

        val readTypes = pendingReadTypes
        val writeTypes = pendingWriteTypes
        val includeWorkouts = pendingIncludeWorkouts
        pendingReadTypes = emptyList()
        pendingWriteTypes = emptyList()
        pendingIncludeWorkouts = false

        pluginScope.launch {
            val client = getClientOrReject(call) ?: return@launch
            val status = manager.authorizationStatus(client, readTypes, writeTypes, includeWorkouts)
            call.resolve(status)
        }
    }

    @PluginMethod
    fun checkAuthorization(call: PluginCall) {
        val (readTypes, includeWorkouts) = try {
            parseReadTypesWithWorkouts(call)
        } catch (e: IllegalArgumentException) {
            call.reject(e.message, null, e)
            return
        }

        val writeTypes = try {
            parseWriteTypes(call)
        } catch (e: IllegalArgumentException) {
            call.reject(e.message, null, e)
            return
        }

        pluginScope.launch {
            val client = getClientOrReject(call) ?: return@launch
            val status = manager.authorizationStatus(client, readTypes, writeTypes, includeWorkouts)
            call.resolve(status)
        }
    }

    /** Legacy iOS method — checks write permission for a single sample type. */
    @PluginMethod
    fun isEditionAuthorized(call: PluginCall) {
        val sampleName = call.getString("sampleName")
        if (sampleName.isNullOrBlank()) {
            call.reject("Must provide sampleName")
            return
        }
        val dataType = HealthDataType.fromHKitSampleName(sampleName)
            ?: HealthDataType.from(sampleName)

        pluginScope.launch {
            val client = getClientOrReject(call) ?: return@launch
            val granted = client.permissionController.getGrantedPermissions()
            if (dataType != null && granted.contains(dataType.writePermission)) {
                call.resolve()
            } else {
                call.reject("Permission Denied to Access data")
            }
        }
    }

    /** Legacy iOS method — checks write permissions for multiple sample types. */
    @PluginMethod
    fun multipleIsEditionAuthorized(call: PluginCall) {
        val sampleNames = call.getArray("sampleNames") ?: run {
            call.reject("Must provide sampleNames")
            return
        }

        val types = mutableListOf<HealthDataType>()
        for (i in 0 until sampleNames.length()) {
            val name = sampleNames.optString(i, null) ?: continue
            val dt = HealthDataType.fromHKitSampleName(name) ?: HealthDataType.from(name)
            if (dt != null) types.add(dt)
        }

        pluginScope.launch {
            val client = getClientOrReject(call) ?: return@launch
            val granted = client.permissionController.getGrantedPermissions()
            val allGranted = types.all { granted.contains(it.writePermission) }
            if (allGranted) call.resolve() else call.reject("Permission Denied to Access data")
        }
    }

    // ── Reading data (new unified API) ────────────────────────────────────────

    @PluginMethod
    fun readSamples(call: PluginCall) {
        val identifier = call.getString("dataType")
        if (identifier.isNullOrBlank()) { call.reject("dataType is required"); return }

        val dataType = HealthDataType.from(identifier) ?: run {
            call.reject("Unsupported data type: $identifier"); return
        }
        val limit = (call.getInt("limit") ?: DEFAULT_LIMIT).coerceAtLeast(0)
        val ascending = call.getBoolean("ascending") ?: false

        val startInstant = try {
            manager.parseInstant(call.getString("startDate"), Instant.now().minus(DEFAULT_PAST))
        } catch (e: DateTimeParseException) { call.reject(e.message, null, e); return }

        val endInstant = try {
            manager.parseInstant(call.getString("endDate"), Instant.now())
        } catch (e: DateTimeParseException) { call.reject(e.message, null, e); return }

        if (endInstant.isBefore(startInstant)) {
            call.reject("endDate must be greater than or equal to startDate"); return
        }

        pluginScope.launch {
            val client = getClientOrReject(call) ?: return@launch
            try {
                val samples = manager.readSamples(client, dataType, startInstant, endInstant, limit, ascending)
                call.resolve(JSObject().apply { put("samples", samples) })
            } catch (e: Exception) {
                call.reject(e.message ?: "Failed to read samples.", null, e)
            }
        }
    }

    @PluginMethod
    fun queryAggregated(call: PluginCall) {
        val identifier = call.getString("dataType")
        if (identifier.isNullOrBlank()) { call.reject("dataType is required"); return }

        val dataType = HealthDataType.from(identifier) ?: run {
            call.reject("Unsupported data type: $identifier"); return
        }
        val bucket = call.getString("bucket") ?: "day"
        val aggregation = call.getString("aggregation") ?: "sum"

        val startInstant = try {
            manager.parseInstant(call.getString("startDate"), Instant.now().minus(DEFAULT_PAST))
        } catch (e: DateTimeParseException) { call.reject(e.message, null, e); return }

        val endInstant = try {
            manager.parseInstant(call.getString("endDate"), Instant.now())
        } catch (e: DateTimeParseException) { call.reject(e.message, null, e); return }

        if (endInstant.isBefore(startInstant)) {
            call.reject("endDate must be greater than or equal to startDate"); return
        }

        pluginScope.launch {
            val client = getClientOrReject(call) ?: return@launch
            try {
                val result = manager.queryAggregated(client, dataType, startInstant, endInstant, bucket, aggregation)
                call.resolve(result)
            } catch (e: IllegalArgumentException) {
                call.reject(e.message ?: "Unsupported aggregation.", null, e)
            } catch (e: Exception) {
                call.reject(e.message ?: "Failed to query aggregated data.", null, e)
            }
        }
    }

    @PluginMethod
    fun queryWorkouts(call: PluginCall) {
        val workoutType = call.getString("workoutType")
        val limit = (call.getInt("limit") ?: DEFAULT_LIMIT).coerceAtLeast(0)
        val ascending = call.getBoolean("ascending") ?: false
        val anchor = call.getString("anchor")

        val startInstant = try {
            manager.parseInstant(call.getString("startDate"), Instant.now().minus(DEFAULT_PAST))
        } catch (e: DateTimeParseException) { call.reject(e.message, null, e); return }

        val endInstant = try {
            manager.parseInstant(call.getString("endDate"), Instant.now())
        } catch (e: DateTimeParseException) { call.reject(e.message, null, e); return }

        if (endInstant.isBefore(startInstant)) {
            call.reject("endDate must be greater than or equal to startDate"); return
        }

        pluginScope.launch {
            val client = getClientOrReject(call) ?: return@launch
            try {
                val result = manager.queryWorkouts(client, workoutType, startInstant, endInstant, limit, ascending, anchor)
                call.resolve(result)
            } catch (e: Exception) {
                call.reject(e.message ?: "Failed to query workouts.", null, e)
            }
        }
    }

    // ── Reading data (legacy iOS-style API) ───────────────────────────────────

    /** Legacy method: maps iOS HealthKit sample names and returns iOS-compatible output format. */
    @PluginMethod
    fun queryHKitSampleType(call: PluginCall) {
        val sampleName = call.getString("sampleName")
        if (sampleName.isNullOrBlank()) { call.reject("Must provide sampleName"); return }

        val limit = (call.getInt("limit") ?: DEFAULT_LIMIT).coerceAtLeast(0)

        val startInstant = try {
            manager.parseInstant(call.getString("startDate"), Instant.now().minus(DEFAULT_PAST))
        } catch (e: DateTimeParseException) { call.reject(e.message, null, e); return }

        val endInstant = try {
            manager.parseInstant(call.getString("endDate"), Instant.now())
        } catch (e: DateTimeParseException) { call.reject(e.message, null, e); return }

        pluginScope.launch {
            val client = getClientOrReject(call) ?: return@launch
            try {
                val result = manager.readHKitSamples(client, sampleName, startInstant, endInstant, limit)
                call.resolve(result)
            } catch (e: Exception) {
                call.reject(e.message ?: "Failed to query sample type.", null, e)
            }
        }
    }

    /** Legacy method: queries multiple iOS HealthKit sample types concurrently. */
    @PluginMethod
    fun multipleQueryHKitSampleType(call: PluginCall) {
        val sampleNamesArr = call.getArray("sampleNames") ?: run {
            call.reject("Must provide sampleNames"); return
        }
        val limit = (call.getInt("limit") ?: DEFAULT_LIMIT).coerceAtLeast(0)

        val startInstant = try {
            manager.parseInstant(call.getString("startDate"), Instant.now().minus(DEFAULT_PAST))
        } catch (e: DateTimeParseException) { call.reject(e.message, null, e); return }

        val endInstant = try {
            manager.parseInstant(call.getString("endDate"), Instant.now())
        } catch (e: DateTimeParseException) { call.reject(e.message, null, e); return }

        val sampleNames = mutableListOf<String>()
        for (i in 0 until sampleNamesArr.length()) {
            sampleNamesArr.optString(i, null)?.let { sampleNames.add(it) }
        }

        pluginScope.launch {
            val client = getClientOrReject(call) ?: return@launch
            val combined = JSObject()
            for (name in sampleNames) {
                try {
                    val result = manager.readHKitSamples(client, name, startInstant, endInstant, limit)
                    combined.put(name, result)
                } catch (e: Exception) {
                    combined.put(name, JSObject().apply { put("errorDescription", e.message) })
                }
            }
            call.resolve(combined)
        }
    }

    // ── Writing data ──────────────────────────────────────────────────────────

    @PluginMethod
    fun saveSample(call: PluginCall) {
        val identifier = call.getString("dataType")
        if (identifier.isNullOrBlank()) { call.reject("dataType is required"); return }

        val dataType = HealthDataType.from(identifier) ?: run {
            call.reject("Unsupported data type: $identifier"); return
        }
        val value = call.getDouble("value") ?: run { call.reject("value is required"); return }
        val unit = call.getString("unit")
        if (unit != null && unit != dataType.unit) {
            call.reject("Unsupported unit $unit for ${dataType.identifier}. Expected ${dataType.unit}.")
            return
        }

        val startInstant = try {
            manager.parseInstant(call.getString("startDate"), Instant.now())
        } catch (e: DateTimeParseException) { call.reject(e.message, null, e); return }

        val endInstant = try {
            manager.parseInstant(call.getString("endDate"), startInstant)
        } catch (e: DateTimeParseException) { call.reject(e.message, null, e); return }

        if (endInstant.isBefore(startInstant)) {
            call.reject("endDate must be greater than or equal to startDate"); return
        }

        val metadataObj = call.getObject("metadata")
        val metadata = metadataObj?.let { obj ->
            val map = mutableMapOf<String, String>()
            obj.keys().forEach { key ->
                val v = obj.opt(key)
                if (v is String) map[key] = v
            }
            map.takeIf { it.isNotEmpty() }
        }

        val systolic = call.getDouble("systolic")
        val diastolic = call.getDouble("diastolic")

        pluginScope.launch {
            val client = getClientOrReject(call) ?: return@launch
            try {
                manager.saveSample(client, dataType, value, startInstant, endInstant, metadata, systolic, diastolic)
                call.resolve()
            } catch (e: IllegalArgumentException) {
                call.reject(e.message ?: "Invalid arguments.", null, e)
            } catch (e: Exception) {
                call.reject(e.message ?: "Failed to save sample.", null, e)
            }
        }
    }

    // ── Android-specific utilities ────────────────────────────────────────────

    @PluginMethod
    fun openHealthConnectSettings(call: PluginCall) {
        try {
            val intent = Intent(HEALTH_CONNECT_SETTINGS_ACTION).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            call.resolve()
        } catch (e: Exception) {
            call.reject("Failed to open Health Connect settings", null, e)
        }
    }

    @PluginMethod
    fun showPrivacyPolicy(call: PluginCall) {
        try {
            val intent = Intent(context, PermissionsRationaleActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            call.resolve()
        } catch (e: Exception) {
            call.reject("Failed to show privacy policy", null, e)
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private fun getClientOrReject(call: PluginCall): HealthConnectClient? {
        val status = HealthConnectClient.getSdkStatus(context)
        if (status != HealthConnectClient.SDK_AVAILABLE) {
            call.reject(availabilityReason(status))
            return null
        }
        return HealthConnectClient.getOrCreate(context)
    }

    private fun availabilityReason(status: Int): String = when (status) {
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "Health Connect needs an update."
        HealthConnectClient.SDK_UNAVAILABLE -> "Health Connect is unavailable on this device."
        else -> "Health Connect availability unknown."
    }

    /**
     * Parses the "read" array from the call, supporting both legacy group names (e.g. "activity",
     * "calories") and new-style HealthDataType identifiers (e.g. "sleep", "calories").
     * Also detects "workouts" / "activity" entries and returns includeWorkouts=true.
     */
    private fun parseReadTypesWithWorkouts(call: PluginCall): Pair<List<HealthDataType>, Boolean> {
        val arr = call.getArray("read") ?: JSArray()
        val allArr = call.getArray("all") ?: JSArray()  // legacy iOS "all" field

        val types = mutableSetOf<HealthDataType>()
        var includeWorkouts = false

        fun processIdentifier(identifier: String) {
            when {
                identifier == "workouts" || identifier == "activity" -> {
                    includeWorkouts = true
                    // "activity" on iOS also means sleep
                    types.addAll(HealthDataType.fromLegacyAuthGroup("activity"))
                }
                else -> types.addAll(HealthDataType.fromLegacyAuthGroup(identifier))
            }
        }

        for (i in 0 until arr.length()) arr.optString(i, null)?.let { processIdentifier(it) }
        for (i in 0 until allArr.length()) allArr.optString(i, null)?.let { processIdentifier(it) }

        return Pair(types.toList(), includeWorkouts)
    }

    private fun parseWriteTypes(call: PluginCall): List<HealthDataType> {
        val arr = call.getArray("write") ?: JSArray()
        val allArr = call.getArray("all") ?: JSArray()

        val types = mutableSetOf<HealthDataType>()
        fun processIdentifier(identifier: String) {
            if (identifier != "workouts" && identifier != "activity") {
                types.addAll(HealthDataType.fromLegacyAuthGroup(identifier))
            }
        }
        for (i in 0 until arr.length()) arr.optString(i, null)?.let { processIdentifier(it) }
        for (i in 0 until allArr.length()) allArr.optString(i, null)?.let { processIdentifier(it) }
        return types.toList()
    }

    companion object {
        private const val DEFAULT_LIMIT = 100
        private val DEFAULT_PAST: Duration = Duration.ofDays(1)
        private const val HEALTH_CONNECT_SETTINGS_ACTION = "androidx.health.ACTION_HEALTH_CONNECT_SETTINGS"
    }
}
