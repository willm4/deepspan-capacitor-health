package com.deepspan.health

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.feature.ExperimentalMindfulnessSessionApi
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.BasalBodyTemperatureRecord
import androidx.health.connect.client.records.BasalMetabolicRateRecord
import androidx.health.connect.client.records.BloodGlucoseRecord
import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.BodyTemperatureRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.FloorsClimbedRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.MindfulnessSessionRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.RespiratoryRateRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.BloodGlucose
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.Percentage
import androidx.health.connect.client.units.Power
import androidx.health.connect.client.units.Pressure
import androidx.health.connect.client.units.Temperature
import com.getcapacitor.JSArray
import com.getcapacitor.JSObject
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import kotlin.math.min
import kotlinx.coroutines.CancellationException

@OptIn(ExperimentalMindfulnessSessionApi::class)
class HealthManager {

    private val formatter: DateTimeFormatter = DateTimeFormatter.ISO_INSTANT

    // ── Permissions ──────────────────────────────────────────────────────────

    fun permissionsFor(
        readTypes: Collection<HealthDataType>,
        writeTypes: Collection<HealthDataType>,
        includeWorkouts: Boolean = false
    ): Set<String> = buildSet {
        readTypes.forEach { add(it.readPermission) }
        writeTypes.forEach { add(it.writePermission) }
        if (includeWorkouts) {
            add(HealthPermission.getReadPermission(ExerciseSessionRecord::class))
        }
    }

    suspend fun authorizationStatus(
        client: HealthConnectClient,
        readTypes: Collection<HealthDataType>,
        writeTypes: Collection<HealthDataType>,
        includeWorkouts: Boolean = false
    ): JSObject {
        val granted = client.permissionController.getGrantedPermissions()

        val readAuthorized = JSArray()
        val readDenied = JSArray()
        readTypes.forEach { type ->
            if (granted.contains(type.readPermission)) readAuthorized.put(type.identifier)
            else readDenied.put(type.identifier)
        }

        if (includeWorkouts) {
            val workoutPermission = HealthPermission.getReadPermission(ExerciseSessionRecord::class)
            if (granted.contains(workoutPermission)) readAuthorized.put("workouts")
            else readDenied.put("workouts")
        }

        val writeAuthorized = JSArray()
        val writeDenied = JSArray()
        writeTypes.forEach { type ->
            if (granted.contains(type.writePermission)) writeAuthorized.put(type.identifier)
            else writeDenied.put(type.identifier)
        }

        return JSObject().apply {
            put("readAuthorized", readAuthorized)
            put("readDenied", readDenied)
            put("writeAuthorized", writeAuthorized)
            put("writeDenied", writeDenied)
        }
    }

    // ── Read samples (new unified API) ────────────────────────────────────────

    suspend fun readSamples(
        client: HealthConnectClient,
        dataType: HealthDataType,
        startTime: Instant,
        endTime: Instant,
        limit: Int,
        ascending: Boolean
    ): JSArray {
        val samples = mutableListOf<Pair<Instant, JSObject>>()

        when (dataType) {
            HealthDataType.STEPS -> readRecords(client, StepsRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.startTime to createSamplePayload(dataType, r.startTime, r.endTime, r.count.toDouble(), r.metadata))
            }
            HealthDataType.DISTANCE -> readRecords(client, DistanceRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.startTime to createSamplePayload(dataType, r.startTime, r.endTime, r.distance.inMeters, r.metadata))
            }
            HealthDataType.CALORIES -> readRecords(client, ActiveCaloriesBurnedRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.startTime to createSamplePayload(dataType, r.startTime, r.endTime, r.energy.inKilocalories, r.metadata))
            }
            HealthDataType.HEART_RATE -> readRecords(client, HeartRateRecord::class, startTime, endTime, limit) { r ->
                r.samples.forEach { s ->
                    samples.add(s.time to createSamplePayload(dataType, s.time, s.time, s.beatsPerMinute.toDouble(), r.metadata))
                }
            }
            HealthDataType.WEIGHT -> readRecords(client, WeightRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.time to createSamplePayload(dataType, r.time, r.time, r.weight.inKilograms, r.metadata))
            }
            HealthDataType.SLEEP -> readRecords(client, SleepSessionRecord::class, startTime, endTime, limit) { r ->
                val durationMinutes = Duration.between(r.startTime, r.endTime).toMinutes().toDouble()
                val payload = createSamplePayload(dataType, r.startTime, r.endTime, durationMinutes, r.metadata)
                // Attach top-level sleep stages if present
                if (r.stages.isNotEmpty()) {
                    val stagesArr = JSArray()
                    r.stages.forEach { stage ->
                        val stageObj = JSObject().apply {
                            put("startDate", formatter.format(stage.startTime))
                            put("endDate", formatter.format(stage.endTime))
                            put("sleepState", sleepStageToString(stage.stage))
                        }
                        stagesArr.put(stageObj)
                    }
                    payload.put("stages", stagesArr)
                    // Convenience: include the dominant (longest) stage as sleepState
                    val dominant = r.stages.maxByOrNull {
                        Duration.between(it.startTime, it.endTime).toMillis()
                    }
                    if (dominant != null) {
                        payload.put("sleepState", sleepStageToString(dominant.stage))
                    }
                }
                samples.add(r.startTime to payload)
            }
            HealthDataType.RESPIRATORY_RATE -> readRecords(client, RespiratoryRateRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.time to createSamplePayload(dataType, r.time, r.time, r.rate, r.metadata))
            }
            HealthDataType.OXYGEN_SATURATION -> readRecords(client, OxygenSaturationRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.time to createSamplePayload(dataType, r.time, r.time, r.percentage.value, r.metadata))
            }
            HealthDataType.RESTING_HEART_RATE -> readRecords(client, RestingHeartRateRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.time to createSamplePayload(dataType, r.time, r.time, r.beatsPerMinute.toDouble(), r.metadata))
            }
            HealthDataType.HEART_RATE_VARIABILITY -> readRecords(client, HeartRateVariabilityRmssdRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.time to createSamplePayload(dataType, r.time, r.time, r.heartRateVariabilityMillis, r.metadata))
            }
            HealthDataType.BLOOD_PRESSURE -> readRecords(client, BloodPressureRecord::class, startTime, endTime, limit) { r ->
                val payload = createSamplePayload(dataType, r.time, r.time, r.systolic.inMillimetersOfMercury, r.metadata)
                payload.put("systolic", r.systolic.inMillimetersOfMercury)
                payload.put("diastolic", r.diastolic.inMillimetersOfMercury)
                samples.add(r.time to payload)
            }
            HealthDataType.BLOOD_GLUCOSE -> readRecords(client, BloodGlucoseRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.time to createSamplePayload(dataType, r.time, r.time, r.level.inMilligramsPerDeciliter, r.metadata))
            }
            HealthDataType.BODY_TEMPERATURE -> readRecords(client, BodyTemperatureRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.time to createSamplePayload(dataType, r.time, r.time, r.temperature.inCelsius, r.metadata))
            }
            HealthDataType.HEIGHT -> readRecords(client, HeightRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.time to createSamplePayload(dataType, r.time, r.time, r.height.inMeters * 100.0, r.metadata))
            }
            HealthDataType.FLIGHTS_CLIMBED -> readRecords(client, FloorsClimbedRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.startTime to createSamplePayload(dataType, r.startTime, r.endTime, r.floors, r.metadata))
            }
            HealthDataType.EXERCISE_TIME -> readRecords(client, ExerciseSessionRecord::class, startTime, endTime, limit) { r ->
                val durationMinutes = Duration.between(r.startTime, r.endTime).toMinutes().toDouble()
                samples.add(r.startTime to createSamplePayload(dataType, r.startTime, r.endTime, durationMinutes, r.metadata))
            }
            HealthDataType.DISTANCE_CYCLING -> readRecords(client, DistanceRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.startTime to createSamplePayload(dataType, r.startTime, r.endTime, r.distance.inMeters, r.metadata))
            }
            HealthDataType.BODY_FAT -> readRecords(client, BodyFatRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.time to createSamplePayload(dataType, r.time, r.time, r.percentage.value, r.metadata))
            }
            HealthDataType.BASAL_BODY_TEMPERATURE -> readRecords(client, BasalBodyTemperatureRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.time to createSamplePayload(dataType, r.time, r.time, r.temperature.inCelsius, r.metadata))
            }
            HealthDataType.BASAL_CALORIES -> readRecords(client, BasalMetabolicRateRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.time to createSamplePayload(dataType, r.time, r.time, r.basalMetabolicRate.inKilocaloriesPerDay, r.metadata))
            }
            HealthDataType.TOTAL_CALORIES -> readRecords(client, TotalCaloriesBurnedRecord::class, startTime, endTime, limit) { r ->
                samples.add(r.startTime to createSamplePayload(dataType, r.startTime, r.endTime, r.energy.inKilocalories, r.metadata))
            }
            HealthDataType.MINDFULNESS -> readRecords(client, MindfulnessSessionRecord::class, startTime, endTime, limit) { r ->
                val durationMinutes = Duration.between(r.startTime, r.endTime).toMinutes().toDouble()
                samples.add(r.startTime to createSamplePayload(dataType, r.startTime, r.endTime, durationMinutes, r.metadata))
            }
        }

        val sorted = samples.sortedBy { it.first }
        val ordered = if (ascending) sorted else sorted.asReversed()
        val limited = if (limit > 0) ordered.take(limit) else ordered

        return JSArray().also { arr -> limited.forEach { arr.put(it.second) } }
    }

    // ── Read samples (legacy iOS-style format) ────────────────────────────────

    /**
     * Reads samples for the given sampleName (iOS HealthKit naming) and returns results
     * in the legacy iOS-compatible format { countReturn, resultData }.
     */
    suspend fun readHKitSamples(
        client: HealthConnectClient,
        sampleName: String,
        startTime: Instant,
        endTime: Instant,
        limit: Int
    ): JSObject {
        val resultData = JSArray()

        if (sampleName == "workoutType") {
            readRecords(client, ExerciseSessionRecord::class, startTime, endTime, limit) { r ->
                val durationSecs = Duration.between(r.startTime, r.endTime).seconds.toInt()
                val obj = JSObject().apply {
                    put("uuid", r.metadata.id)
                    put("startDate", formatter.format(r.startTime))
                    put("endDate", formatter.format(r.endTime))
                    put("duration", durationSecs.toDouble() / 3600.0)
                    put("source", r.metadata.dataOrigin.packageName)
                    put("sourceBundleId", r.metadata.dataOrigin.packageName)
                    put("workoutActivityId", r.exerciseType)
                    put("workoutActivityName", WorkoutType.toWorkoutTypeString(r.exerciseType))
                    put("totalEnergyBurned", -1.0)
                    put("totalDistance", -1.0)
                    put("totalFlightsClimbed", -1.0)
                    put("totalSwimmingStrokeCount", -1.0)
                    put("device", JSObject.NULL)
                }
                resultData.put(obj)
            }
            return JSObject().apply {
                put("countReturn", resultData.length())
                put("resultData", resultData)
            }
        }

        if (sampleName == "sleepAnalysis") {
            readRecords(client, SleepSessionRecord::class, startTime, endTime, limit) { r ->
                val durationHours = Duration.between(r.startTime, r.endTime).toMinutes() / 60.0
                val sleepState = if (r.stages.isNotEmpty()) {
                    val dominant = r.stages.maxByOrNull { Duration.between(it.startTime, it.endTime).toMillis() }
                    if (dominant != null) hkitSleepStateFromStage(dominant.stage) else "Asleep"
                } else "Asleep"
                val obj = JSObject().apply {
                    put("uuid", r.metadata.id)
                    put("startDate", formatter.format(r.startTime))
                    put("endDate", formatter.format(r.endTime))
                    put("duration", durationHours)
                    put("sleepState", sleepState)
                    put("source", r.metadata.dataOrigin.packageName)
                    put("sourceBundleId", r.metadata.dataOrigin.packageName)
                    put("timeZone", "+00:00")
                    put("device", JSObject.NULL)
                }
                resultData.put(obj)
            }
            return JSObject().apply {
                put("countReturn", resultData.length())
                put("resultData", resultData)
            }
        }

        // Blood pressure — return as systolic samples (for both bloodPressureSystolic and bloodPressureDiastolic)
        if (sampleName == "bloodPressureSystolic" || sampleName == "bloodPressureDiastolic") {
            readRecords(client, BloodPressureRecord::class, startTime, endTime, limit) { r ->
                val value = if (sampleName == "bloodPressureSystolic")
                    r.systolic.inMillimetersOfMercury else r.diastolic.inMillimetersOfMercury
                val obj = legacyQuantityPayload(r.metadata.id, r.time, r.time, value, "mmHg", r.metadata)
                resultData.put(obj)
            }
            return JSObject().apply {
                put("countReturn", resultData.length())
                put("resultData", resultData)
            }
        }

        // Generic quantity types
        val dataType = HealthDataType.fromHKitSampleName(sampleName)
            ?: return JSObject().apply {
                put("countReturn", 0)
                put("resultData", resultData)
            }

        val newStyleSamples = readSamples(client, dataType, startTime, endTime, limit, false)
        for (i in 0 until newStyleSamples.length()) {
            val s = newStyleSamples.getJSONObject(i)
            val startInstant = Instant.parse(s.getString("startDate"))
            val endInstant = Instant.parse(s.getString("endDate"))
            val durationHours = Duration.between(startInstant, endInstant).toMillis() / 3_600_000.0
            val obj = JSObject().apply {
                put("uuid", s.optString("platformId", ""))
                put("startDate", s.getString("startDate"))
                put("endDate", s.getString("endDate"))
                put("duration", durationHours)
                put("value", s.getDouble("value"))
                put("unitName", s.getString("unit"))
                put("source", s.optString("sourceName", ""))
                put("sourceBundleId", s.optString("sourceId", ""))
                put("device", JSObject.NULL)
            }
            resultData.put(obj)
        }

        return JSObject().apply {
            put("countReturn", resultData.length())
            put("resultData", resultData)
        }
    }

    // ── Save sample ───────────────────────────────────────────────────────────

    @Suppress("UNUSED_PARAMETER")
    suspend fun saveSample(
        client: HealthConnectClient,
        dataType: HealthDataType,
        value: Double,
        startTime: Instant,
        endTime: Instant,
        metadata: Map<String, String>?,
        systolic: Double?,
        diastolic: Double?
    ) {
        val meta = Metadata.manualEntry()

        when (dataType) {
            HealthDataType.STEPS -> client.insertRecords(listOf(
                StepsRecord(startTime, zoneOffset(startTime), endTime, zoneOffset(endTime),
                    value.toLong().coerceAtLeast(0), meta)
            ))
            HealthDataType.DISTANCE, HealthDataType.DISTANCE_CYCLING -> client.insertRecords(listOf(
                DistanceRecord(startTime, zoneOffset(startTime), endTime, zoneOffset(endTime),
                    Length.meters(value), meta)
            ))
            HealthDataType.CALORIES -> client.insertRecords(listOf(
                ActiveCaloriesBurnedRecord(startTime, zoneOffset(startTime), endTime, zoneOffset(endTime),
                    Energy.kilocalories(value), meta)
            ))
            HealthDataType.HEART_RATE -> client.insertRecords(listOf(
                HeartRateRecord(startTime, zoneOffset(startTime), endTime, zoneOffset(endTime),
                    listOf(HeartRateRecord.Sample(startTime, value.toBpmLong())), meta)
            ))
            HealthDataType.WEIGHT -> client.insertRecords(listOf(
                WeightRecord(startTime, zoneOffset(startTime), Mass.kilograms(value), meta)
            ))
            HealthDataType.SLEEP -> client.insertRecords(listOf(
                SleepSessionRecord(startTime, zoneOffset(startTime), endTime, zoneOffset(endTime),
                    metadata = meta)
            ))
            HealthDataType.RESPIRATORY_RATE -> client.insertRecords(listOf(
                RespiratoryRateRecord(startTime, zoneOffset(startTime), value, meta)
            ))
            HealthDataType.OXYGEN_SATURATION -> client.insertRecords(listOf(
                OxygenSaturationRecord(startTime, zoneOffset(startTime), Percentage(value), meta)
            ))
            HealthDataType.RESTING_HEART_RATE -> client.insertRecords(listOf(
                RestingHeartRateRecord(startTime, zoneOffset(startTime), value.toBpmLong(), meta)
            ))
            HealthDataType.HEART_RATE_VARIABILITY -> client.insertRecords(listOf(
                HeartRateVariabilityRmssdRecord(startTime, zoneOffset(startTime), value, meta)
            ))
            HealthDataType.BLOOD_PRESSURE -> {
                requireNotNull(systolic) { "Blood pressure requires a systolic value" }
                requireNotNull(diastolic) { "Blood pressure requires a diastolic value" }
                client.insertRecords(listOf(
                    BloodPressureRecord(startTime, zoneOffset(startTime),
                        Pressure.millimetersOfMercury(systolic),
                        Pressure.millimetersOfMercury(diastolic), meta)
                ))
            }
            HealthDataType.BLOOD_GLUCOSE -> client.insertRecords(listOf(
                BloodGlucoseRecord(startTime, zoneOffset(startTime),
                    BloodGlucose.milligramsPerDeciliter(value), meta)
            ))
            HealthDataType.BODY_TEMPERATURE -> client.insertRecords(listOf(
                BodyTemperatureRecord(startTime, zoneOffset(startTime),
                    Temperature.celsius(value), meta)
            ))
            HealthDataType.HEIGHT -> client.insertRecords(listOf(
                HeightRecord(startTime, zoneOffset(startTime),
                    Length.meters(value / 100.0), meta)
            ))
            HealthDataType.FLIGHTS_CLIMBED -> client.insertRecords(listOf(
                FloorsClimbedRecord(startTime, zoneOffset(startTime), endTime, zoneOffset(endTime),
                    value, meta)
            ))
            HealthDataType.EXERCISE_TIME -> client.insertRecords(listOf(
                ExerciseSessionRecord(startTime, zoneOffset(startTime), endTime, zoneOffset(endTime),
                    ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT, meta)
            ))
            HealthDataType.BODY_FAT -> client.insertRecords(listOf(
                BodyFatRecord(startTime, zoneOffset(startTime), Percentage(value), meta)
            ))
            HealthDataType.BASAL_BODY_TEMPERATURE -> client.insertRecords(listOf(
                BasalBodyTemperatureRecord(startTime, zoneOffset(startTime),
                    Temperature.celsius(value), meta)
            ))
            HealthDataType.BASAL_CALORIES -> client.insertRecords(listOf(
                BasalMetabolicRateRecord(startTime, zoneOffset(startTime),
                    Power.kilocaloriesPerDay(value), meta)
            ))
            HealthDataType.TOTAL_CALORIES -> client.insertRecords(listOf(
                TotalCaloriesBurnedRecord(startTime, zoneOffset(startTime), endTime, zoneOffset(endTime),
                    Energy.kilocalories(value), meta)
            ))
            HealthDataType.MINDFULNESS -> client.insertRecords(listOf(
                MindfulnessSessionRecord(startTime, zoneOffset(startTime), endTime, zoneOffset(endTime),
                    metadata = meta,
                    mindfulnessSessionType = MindfulnessSessionRecord.MINDFULNESS_SESSION_TYPE_UNKNOWN)
            ))
        }
    }

    // ── Workouts ──────────────────────────────────────────────────────────────

    suspend fun queryWorkouts(
        client: HealthConnectClient,
        workoutType: String?,
        startTime: Instant,
        endTime: Instant,
        limit: Int,
        ascending: Boolean,
        anchor: String?
    ): JSObject {
        val workouts = mutableListOf<Pair<Instant, JSObject>>()
        var pageToken: String? = anchor
        val pageSize = if (limit > 0) min(limit, MAX_PAGE_SIZE) else DEFAULT_PAGE_SIZE
        var fetched = 0
        val exerciseTypeFilter = WorkoutType.fromString(workoutType)

        do {
            val request = ReadRecordsRequest(
                recordType = ExerciseSessionRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                pageSize = pageSize,
                pageToken = pageToken
            )
            val response = client.readRecords(request)

            response.records.forEach { record ->
                val session = record as ExerciseSessionRecord
                if (exerciseTypeFilter != null && session.exerciseType != exerciseTypeFilter) return@forEach

                val aggregatedData = aggregateWorkoutData(client, session)
                workouts.add(session.startTime to createWorkoutPayload(session, aggregatedData))
            }

            fetched += response.records.size
            pageToken = response.pageToken
        } while (pageToken != null && (limit <= 0 || fetched < limit))

        val sorted = workouts.sortedBy { it.first }
        val ordered = if (ascending) sorted else sorted.asReversed()
        val limited = if (limit > 0) ordered.take(limit) else ordered

        val arr = JSArray().also { a -> limited.forEach { a.put(it.second) } }

        return JSObject().apply {
            put("workouts", arr)
            if (pageToken != null) put("anchor", pageToken)
        }
    }

    private suspend fun aggregateWorkoutData(
        client: HealthConnectClient,
        session: ExerciseSessionRecord
    ): WorkoutAggregatedData {
        val timeRange = TimeRangeFilter.between(session.startTime, session.endTime)
        var distanceM: Double? = null
        var caloriesKcal: Double? = null

        try {
            val result = client.aggregate(AggregateRequest(
                metrics = setOf(DistanceRecord.DISTANCE_TOTAL, ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL),
                timeRangeFilter = timeRange
            ))
            distanceM = result[DistanceRecord.DISTANCE_TOTAL]?.inMeters
            caloriesKcal = result[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            android.util.Log.d("HealthManager", "Workout aggregation failed: ${e.message}")
        }

        if (caloriesKcal == null) {
            try {
                val result = client.aggregate(AggregateRequest(
                    metrics = setOf(TotalCaloriesBurnedRecord.ENERGY_TOTAL),
                    timeRangeFilter = timeRange
                ))
                caloriesKcal = result[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                android.util.Log.d("HealthManager", "Workout total calories fallback failed: ${e.message}")
            }
        }

        return WorkoutAggregatedData(distanceM, caloriesKcal)
    }

    private data class WorkoutAggregatedData(val totalDistance: Double?, val totalEnergyBurned: Double?)

    private fun createWorkoutPayload(session: ExerciseSessionRecord, data: WorkoutAggregatedData): JSObject {
        return JSObject().apply {
            put("workoutType", WorkoutType.toWorkoutTypeString(session.exerciseType))
            put("duration", Duration.between(session.startTime, session.endTime).seconds.toInt())
            put("startDate", formatter.format(session.startTime))
            put("endDate", formatter.format(session.endTime))
            data.totalDistance?.let { put("totalDistance", it) }
            data.totalEnergyBurned?.let { put("totalEnergyBurned", it) }
            val origin = session.metadata.dataOrigin
            put("sourceId", origin.packageName)
            put("sourceName", resolveSourceName(session.metadata, origin.packageName))
            put("platformId", session.metadata.id)
        }
    }

    // ── Aggregated queries ────────────────────────────────────────────────────

    suspend fun queryAggregated(
        client: HealthConnectClient,
        dataType: HealthDataType,
        startTime: Instant,
        endTime: Instant,
        bucket: String,
        aggregation: String
    ): JSObject {
        if (dataType == HealthDataType.SLEEP) {
            throw IllegalArgumentException("Aggregated queries are not supported for sleep data. Use readSamples instead.")
        }
        if (dataType == HealthDataType.RESPIRATORY_RATE ||
            dataType == HealthDataType.OXYGEN_SATURATION ||
            dataType == HealthDataType.HEART_RATE_VARIABILITY) {
            throw IllegalArgumentException("Aggregated queries are not supported for ${dataType.identifier}. Use readSamples instead.")
        }

        val bucketDuration = when (bucket) {
            "hour"  -> Duration.ofHours(1)
            "day"   -> Duration.ofDays(1)
            "week"  -> Duration.ofDays(7)
            "month" -> Duration.ofDays(30)
            else    -> Duration.ofDays(1)
        }

        val samples = JSArray()
        var currentStart = startTime

        while (currentStart.isBefore(endTime)) {
            val currentEnd = currentStart.plus(bucketDuration).let { if (it.isAfter(endTime)) endTime else it }

            try {
                val metrics = when (dataType) {
                    HealthDataType.STEPS -> setOf(StepsRecord.COUNT_TOTAL)
                    HealthDataType.DISTANCE, HealthDataType.DISTANCE_CYCLING -> setOf(DistanceRecord.DISTANCE_TOTAL)
                    HealthDataType.CALORIES -> setOf(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)
                    HealthDataType.HEART_RATE -> setOf(HeartRateRecord.BPM_AVG, HeartRateRecord.BPM_MAX, HeartRateRecord.BPM_MIN)
                    HealthDataType.WEIGHT -> setOf(WeightRecord.WEIGHT_AVG, WeightRecord.WEIGHT_MAX, WeightRecord.WEIGHT_MIN)
                    HealthDataType.RESTING_HEART_RATE -> setOf(RestingHeartRateRecord.BPM_AVG, RestingHeartRateRecord.BPM_MAX, RestingHeartRateRecord.BPM_MIN)
                    HealthDataType.TOTAL_CALORIES -> setOf(TotalCaloriesBurnedRecord.ENERGY_TOTAL)
                    HealthDataType.FLIGHTS_CLIMBED -> setOf(FloorsClimbedRecord.FLOORS_CLIMBED_TOTAL)
                    else -> throw IllegalArgumentException("Aggregated queries are not supported for ${dataType.identifier}")
                }

                val result = client.aggregate(AggregateRequest(metrics, TimeRangeFilter.between(currentStart, currentEnd)))

                val value: Double? = when (dataType) {
                    HealthDataType.STEPS -> result[StepsRecord.COUNT_TOTAL]?.toDouble()
                    HealthDataType.DISTANCE, HealthDataType.DISTANCE_CYCLING -> result[DistanceRecord.DISTANCE_TOTAL]?.inMeters
                    HealthDataType.CALORIES -> result[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories
                    HealthDataType.HEART_RATE -> when (aggregation) {
                        "average" -> result[HeartRateRecord.BPM_AVG]?.toDouble()
                        "max" -> result[HeartRateRecord.BPM_MAX]?.toDouble()
                        "min" -> result[HeartRateRecord.BPM_MIN]?.toDouble()
                        else -> result[HeartRateRecord.BPM_AVG]?.toDouble()
                    }
                    HealthDataType.WEIGHT -> when (aggregation) {
                        "average" -> result[WeightRecord.WEIGHT_AVG]?.inKilograms
                        "max" -> result[WeightRecord.WEIGHT_MAX]?.inKilograms
                        "min" -> result[WeightRecord.WEIGHT_MIN]?.inKilograms
                        else -> result[WeightRecord.WEIGHT_AVG]?.inKilograms
                    }
                    HealthDataType.RESTING_HEART_RATE -> when (aggregation) {
                        "average" -> result[RestingHeartRateRecord.BPM_AVG]?.toDouble()
                        "max" -> result[RestingHeartRateRecord.BPM_MAX]?.toDouble()
                        "min" -> result[RestingHeartRateRecord.BPM_MIN]?.toDouble()
                        else -> result[RestingHeartRateRecord.BPM_AVG]?.toDouble()
                    }
                    HealthDataType.TOTAL_CALORIES -> result[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories
                    HealthDataType.FLIGHTS_CLIMBED -> result[FloorsClimbedRecord.FLOORS_CLIMBED_TOTAL]
                    else -> null
                }

                if (value != null) {
                    samples.put(JSObject().apply {
                        put("startDate", formatter.format(currentStart))
                        put("endDate", formatter.format(currentEnd))
                        put("value", value)
                        put("unit", dataType.unit)
                    })
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: SecurityException) {
                android.util.Log.d("HealthManager", "Permission denied for aggregation bucket: ${e.message}")
            } catch (e: Exception) {
                android.util.Log.d("HealthManager", "Aggregation bucket failed: ${e.message}")
            }

            currentStart = currentEnd
        }

        return JSObject().apply { put("samples", samples) }
    }

    // ── Utilities ─────────────────────────────────────────────────────────────

    fun parseInstant(value: String?, defaultInstant: Instant): Instant {
        if (value.isNullOrBlank()) return defaultInstant
        return Instant.parse(value)
    }

    private suspend fun <T : Record> readRecords(
        client: HealthConnectClient,
        recordClass: kotlin.reflect.KClass<T>,
        startTime: Instant,
        endTime: Instant,
        limit: Int,
        consumer: (record: T) -> Unit
    ) {
        var pageToken: String? = null
        val pageSize = if (limit > 0) min(limit, MAX_PAGE_SIZE) else DEFAULT_PAGE_SIZE
        var fetched = 0

        do {
            val request = ReadRecordsRequest(
                recordType = recordClass,
                timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                pageSize = pageSize,
                pageToken = pageToken
            )
            val response = client.readRecords(request)
            response.records.forEach { consumer(it) }
            fetched += response.records.size
            pageToken = response.pageToken
        } while (pageToken != null && (limit <= 0 || fetched < limit))
    }

    private fun createSamplePayload(
        dataType: HealthDataType,
        startTime: Instant,
        endTime: Instant,
        value: Double,
        metadata: Metadata
    ): JSObject = JSObject().apply {
        put("dataType", dataType.identifier)
        put("value", value)
        put("unit", dataType.unit)
        put("startDate", formatter.format(startTime))
        put("endDate", formatter.format(endTime))
        val origin = metadata.dataOrigin
        put("sourceId", origin.packageName)
        put("sourceName", resolveSourceName(metadata, origin.packageName))
        put("platformId", metadata.id)
    }

    private fun legacyQuantityPayload(
        uuid: String,
        startTime: Instant,
        endTime: Instant,
        value: Double,
        unitName: String,
        metadata: Metadata
    ): JSObject = JSObject().apply {
        put("uuid", uuid)
        put("startDate", formatter.format(startTime))
        put("endDate", formatter.format(endTime))
        val durationHours = Duration.between(startTime, endTime).toMillis() / 3_600_000.0
        put("duration", durationHours)
        put("value", value)
        put("unitName", unitName)
        put("source", resolveSourceName(metadata, metadata.dataOrigin.packageName))
        put("sourceBundleId", metadata.dataOrigin.packageName)
        put("device", JSObject.NULL)
    }

    private fun resolveSourceName(metadata: Metadata, fallback: String): String {
        val device = metadata.device ?: return fallback
        val label = listOfNotNull(
            device.manufacturer?.takeIf { it.isNotBlank() },
            device.model?.takeIf { it.isNotBlank() }
        ).joinToString(" ").trim()
        return label.ifEmpty { fallback }
    }

    private fun zoneOffset(instant: Instant): ZoneOffset? =
        ZoneId.systemDefault().rules.getOffset(instant)

    private fun Double.toBpmLong(): Long =
        java.lang.Math.round(this.coerceAtLeast(0.0))

    /** Maps Health Connect sleep stage integers to cross-platform string values. */
    private fun sleepStageToString(stage: Int): String = when (stage) {
        SleepSessionRecord.STAGE_TYPE_AWAKE, SleepSessionRecord.STAGE_TYPE_AWAKE_IN_BED -> "awake"
        SleepSessionRecord.STAGE_TYPE_SLEEPING -> "asleep"
        SleepSessionRecord.STAGE_TYPE_OUT_OF_BED -> "awake"
        SleepSessionRecord.STAGE_TYPE_LIGHT -> "light"
        SleepSessionRecord.STAGE_TYPE_DEEP -> "deep"
        SleepSessionRecord.STAGE_TYPE_REM -> "rem"
        else -> "asleep"
    }

    /** Maps Health Connect sleep stage integers to iOS-compatible capitalized strings for the legacy API. */
    private fun hkitSleepStateFromStage(stage: Int): String = when (stage) {
        SleepSessionRecord.STAGE_TYPE_AWAKE, SleepSessionRecord.STAGE_TYPE_AWAKE_IN_BED,
        SleepSessionRecord.STAGE_TYPE_OUT_OF_BED -> "Awake"
        SleepSessionRecord.STAGE_TYPE_SLEEPING -> "Asleep"
        SleepSessionRecord.STAGE_TYPE_LIGHT -> "AsleepCore"
        SleepSessionRecord.STAGE_TYPE_DEEP -> "AsleepDeep"
        SleepSessionRecord.STAGE_TYPE_REM -> "AsleepREM"
        else -> "Asleep"
    }

    companion object {
        private const val DEFAULT_PAGE_SIZE = 100
        private const val MAX_PAGE_SIZE = 500
    }
}
