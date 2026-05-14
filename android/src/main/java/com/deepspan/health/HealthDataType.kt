package com.deepspan.health

import androidx.health.connect.client.feature.ExperimentalMindfulnessSessionApi
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.BasalBodyTemperatureRecord
import androidx.health.connect.client.records.BasalMetabolicRateRecord
import androidx.health.connect.client.records.BloodGlucoseRecord
import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.BodyTemperatureRecord
import androidx.health.connect.client.records.DistanceRecord
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
import kotlin.reflect.KClass

/**
 * Maps cross-platform HealthDataType string identifiers (matching the TypeScript API) to
 * their corresponding Android Health Connect record classes and units.
 */
@OptIn(ExperimentalMindfulnessSessionApi::class)
enum class HealthDataType(
    val identifier: String,
    val recordClass: KClass<out Record>,
    val unit: String
) {
    STEPS("steps", StepsRecord::class, "count"),
    DISTANCE("distance", DistanceRecord::class, "meter"),
    CALORIES("calories", ActiveCaloriesBurnedRecord::class, "kilocalorie"),
    HEART_RATE("heartRate", HeartRateRecord::class, "bpm"),
    WEIGHT("weight", WeightRecord::class, "kilogram"),
    SLEEP("sleep", SleepSessionRecord::class, "minute"),
    RESPIRATORY_RATE("respiratoryRate", RespiratoryRateRecord::class, "bpm"),
    OXYGEN_SATURATION("oxygenSaturation", OxygenSaturationRecord::class, "percent"),
    RESTING_HEART_RATE("restingHeartRate", RestingHeartRateRecord::class, "bpm"),
    HEART_RATE_VARIABILITY("heartRateVariability", HeartRateVariabilityRmssdRecord::class, "millisecond"),
    BLOOD_PRESSURE("bloodPressure", BloodPressureRecord::class, "mmHg"),
    BLOOD_GLUCOSE("bloodGlucose", BloodGlucoseRecord::class, "mg/dL"),
    BODY_TEMPERATURE("bodyTemperature", BodyTemperatureRecord::class, "celsius"),
    HEIGHT("height", HeightRecord::class, "centimeter"),
    FLIGHTS_CLIMBED("flightsClimbed", FloorsClimbedRecord::class, "count"),
    EXERCISE_TIME("exerciseTime", DistanceRecord::class, "minute"),  // approximated via active periods
    DISTANCE_CYCLING("distanceCycling", DistanceRecord::class, "meter"),
    BODY_FAT("bodyFat", BodyFatRecord::class, "percent"),
    BASAL_BODY_TEMPERATURE("basalBodyTemperature", BasalBodyTemperatureRecord::class, "celsius"),
    BASAL_CALORIES("basalCalories", BasalMetabolicRateRecord::class, "kilocalorie"),
    TOTAL_CALORIES("totalCalories", TotalCaloriesBurnedRecord::class, "kilocalorie"),
    MINDFULNESS("mindfulness", MindfulnessSessionRecord::class, "minute");

    val readPermission: String
        get() = HealthPermission.getReadPermission(recordClass)

    val writePermission: String
        get() = HealthPermission.getWritePermission(recordClass)

    companion object {
        fun from(identifier: String): HealthDataType? {
            return entries.firstOrNull { it.identifier == identifier }
        }

        /**
         * Maps legacy iOS-style authorization group names (used by requestAuthorization
         * with the all/read/write arrays) to Health Connect HealthDataTypes.
         */
        fun fromLegacyAuthGroup(groupName: String): List<HealthDataType> {
            return when (groupName) {
                "steps" -> listOf(STEPS)
                "stairs" -> listOf(FLIGHTS_CLIMBED)
                "duration", "exerciseTime" -> listOf(EXERCISE_TIME)
                "activity" -> listOf(SLEEP)
                "calories" -> listOf(CALORIES, BASAL_CALORIES)
                "distance" -> listOf(DISTANCE, DISTANCE_CYCLING)
                "bloodGlucose" -> listOf(BLOOD_GLUCOSE)
                "weight" -> listOf(WEIGHT)
                "heartRate" -> listOf(HEART_RATE)
                "restingHeartRate" -> listOf(RESTING_HEART_RATE)
                "respiratoryRate" -> listOf(RESPIRATORY_RATE)
                "bodyFat" -> listOf(BODY_FAT)
                "oxygenSaturation" -> listOf(OXYGEN_SATURATION)
                "basalBodyTemperature" -> listOf(BASAL_BODY_TEMPERATURE)
                "bodyTemperature" -> listOf(BODY_TEMPERATURE)
                "bloodPressureSystolic", "bloodPressureDiastolic", "bloodPressure" -> listOf(BLOOD_PRESSURE)
                "heartRateVariability" -> listOf(HEART_RATE_VARIABILITY)
                "height" -> listOf(HEIGHT)
                "totalCalories" -> listOf(TOTAL_CALORIES)
                "mindfulness" -> listOf(MINDFULNESS)
                // New-style identifiers passed directly
                else -> from(groupName)?.let { listOf(it) } ?: emptyList()
            }
        }

        /**
         * Maps iOS HealthKit sampleName strings (used by queryHKitSampleType) to
         * Android HealthDataType values.
         */
        fun fromHKitSampleName(sampleName: String): HealthDataType? {
            return when (sampleName) {
                "stepCount" -> STEPS
                "flightsClimbed" -> FLIGHTS_CLIMBED
                "appleExerciseTime", "exerciseTime" -> EXERCISE_TIME
                "activeEnergyBurned", "calories" -> CALORIES
                "basalEnergyBurned", "basalCalories" -> BASAL_CALORIES
                "distanceWalkingRunning", "distance" -> DISTANCE
                "distanceCycling" -> DISTANCE_CYCLING
                "bloodGlucose" -> BLOOD_GLUCOSE
                "sleepAnalysis", "sleep" -> SLEEP
                "weight" -> WEIGHT
                "heartRate" -> HEART_RATE
                "restingHeartRate" -> RESTING_HEART_RATE
                "respiratoryRate" -> RESPIRATORY_RATE
                "bodyFat" -> BODY_FAT
                "oxygenSaturation" -> OXYGEN_SATURATION
                "basalBodyTemperature" -> BASAL_BODY_TEMPERATURE
                "bodyTemperature" -> BODY_TEMPERATURE
                "bloodPressureSystolic", "bloodPressureDiastolic" -> BLOOD_PRESSURE
                "heartRateVariability" -> HEART_RATE_VARIABILITY
                "height" -> HEIGHT
                "totalCalories" -> TOTAL_CALORIES
                "mindfulness" -> MINDFULNESS
                else -> null
            }
        }
    }
}
