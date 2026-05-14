import Foundation
import Capacitor
import HealthKit

var healthStore = HKHealthStore()

/**
 * Capacitor HealthKit Plugin — iOS implementation
 *
 * Provides both the legacy iOS-specific API (queryHKitSampleType, requestAuthorization
 * with all/read/write group names, etc.) and the new cross-platform API added to match
 * the @capgo/capacitor-health feature set (readSamples, saveSample, queryWorkouts,
 * queryAggregated, checkAuthorization).
 */
@objc(CapacitorHealthkitPlugin)
public class CapacitorHealthkitPlugin: CAPPlugin {

    private let pluginVersion = "1.0.0"

    // MARK: - ISO formatter (shared)

    private lazy var isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Error Types

    enum HKSampleError: Error {
        case sleepRequestFailed
        case workoutRequestFailed
        case quantityRequestFailed
        case sampleTypeFailed
        case deniedDataAccessFailed

        var outputMessage: String {
            switch self {
            case .sleepRequestFailed:       return "sleepRequestFailed"
            case .workoutRequestFailed:     return "workoutRequestFailed"
            case .quantityRequestFailed:    return "quantityRequestFailed"
            case .sampleTypeFailed:         return "sampleTypeFailed"
            case .deniedDataAccessFailed:   return "deniedDataAccessFailed"
            }
        }
    }

    // MARK: - HealthDataType (new cross-platform API)

    /// Maps new-style HealthDataType identifier strings to HKSampleType.
    func getHealthDataType(identifier: String) throws -> HKSampleType {
        switch identifier {
        case "steps":
            return HKQuantityType.quantityType(forIdentifier: .stepCount)!
        case "distance":
            return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        case "calories":
            return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        case "heartRate":
            return HKQuantityType.quantityType(forIdentifier: .heartRate)!
        case "weight":
            return HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        case "sleep":
            return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        case "respiratoryRate":
            return HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!
        case "oxygenSaturation":
            return HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        case "restingHeartRate":
            return HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        case "heartRateVariability":
            return HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        case "bloodPressure":
            return HKObjectType.correlationType(forIdentifier: .bloodPressure)!
        case "bloodGlucose":
            return HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
        case "bodyTemperature":
            return HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!
        case "height":
            return HKQuantityType.quantityType(forIdentifier: .height)!
        case "flightsClimbed":
            return HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!
        case "exerciseTime":
            return HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!
        case "distanceCycling":
            return HKQuantityType.quantityType(forIdentifier: .distanceCycling)!
        case "bodyFat":
            return HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
        case "basalBodyTemperature":
            return HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature)!
        case "basalCalories":
            return HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!
        case "totalCalories":
            return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        case "mindfulness":
            return HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        default:
            throw HKSampleError.sampleTypeFailed
        }
    }

    /// Default HKUnit for a new-style HealthDataType identifier.
    func defaultUnit(for identifier: String) -> HKUnit? {
        switch identifier {
        case "steps", "flightsClimbed":
            return HKUnit.count()
        case "distance", "height", "distanceCycling":
            return HKUnit.meter()
        case "calories", "basalCalories", "totalCalories":
            return HKUnit.kilocalorie()
        case "heartRate", "restingHeartRate", "respiratoryRate":
            return HKUnit(from: "count/min")
        case "weight":
            return HKUnit.gramUnit(with: .kilo)
        case "oxygenSaturation", "bodyFat":
            return HKUnit.percent()
        case "heartRateVariability":
            return HKUnit.secondUnit(with: .milli)
        case "bloodGlucose":
            return HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.literUnit(with: .deci))
        case "bodyTemperature", "basalBodyTemperature":
            return HKUnit.degreeCelsius()
        case "bloodPressure":
            return HKUnit.millimeterOfMercury()
        case "exerciseTime", "sleep", "mindfulness":
            return HKUnit.minute()
        default:
            return nil
        }
    }

    func unitIdentifier(for identifier: String) -> String {
        switch identifier {
        case "steps", "flightsClimbed":            return "count"
        case "distance", "distanceCycling":        return "meter"
        case "height":                             return "centimeter"
        case "calories", "basalCalories", "totalCalories": return "kilocalorie"
        case "heartRate", "restingHeartRate", "respiratoryRate": return "bpm"
        case "weight":                             return "kilogram"
        case "oxygenSaturation", "bodyFat":        return "percent"
        case "heartRateVariability":               return "millisecond"
        case "bloodGlucose":                       return "mg/dL"
        case "bodyTemperature", "basalBodyTemperature": return "celsius"
        case "bloodPressure":                      return "mmHg"
        case "exerciseTime", "sleep", "mindfulness": return "minute"
        default:                                   return ""
        }
    }

    // MARK: - Legacy Sample Type Resolution (queryHKitSampleType API)

    func getSampleType(sampleName: String) -> HKSampleType? {
        switch sampleName {
        case "stepCount":
            return HKQuantityType.quantityType(forIdentifier: .stepCount)!
        case "flightsClimbed":
            return HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!
        case "appleExerciseTime":
            return HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!
        case "activeEnergyBurned":
            return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        case "basalEnergyBurned":
            return HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!
        case "distanceWalkingRunning":
            return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        case "distanceCycling":
            return HKQuantityType.quantityType(forIdentifier: .distanceCycling)!
        case "bloodGlucose":
            return HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
        case "sleepAnalysis":
            return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        case "workoutType":
            return HKWorkoutType.workoutType()
        case "weight":
            return HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        case "heartRate":
            return HKQuantityType.quantityType(forIdentifier: .heartRate)!
        case "restingHeartRate":
            return HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        case "respiratoryRate":
            return HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!
        case "bodyFat":
            return HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
        case "oxygenSaturation":
            return HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        case "basalBodyTemperature":
            return HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature)!
        case "bodyTemperature":
            return HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!
        case "bloodPressureSystolic":
            return HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!
        case "bloodPressureDiastolic":
            return HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!
        case "heartRateVariability":
            return HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        case "height":
            return HKQuantityType.quantityType(forIdentifier: .height)!
        case "totalCalories":
            return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        case "mindfulness":
            return HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        case "appleWalkingSteadiness":
            if #available(iOS 15.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness)!
            } else { return nil }
        case "walkingAsymmetryPercentage":
            if #available(iOS 15.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage)!
            } else { return nil }
        default:
            return nil
        }
    }

    // MARK: - Legacy Authorization Type Resolution

    func getTypes(items: [String]) -> Set<HKSampleType> {
        var types: Set<HKSampleType> = []
        for item in items {
            switch item {
            case "steps":
                types.insert(HKQuantityType.quantityType(forIdentifier: .stepCount)!)
            case "stairs":
                types.insert(HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!)
            case "duration":
                types.insert(HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!)
            case "activity":
                types.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
                types.insert(HKWorkoutType.workoutType())
            case "calories":
                types.insert(HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)
                types.insert(HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!)
            case "distance":
                types.insert(HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!)
                types.insert(HKQuantityType.quantityType(forIdentifier: .distanceCycling)!)
            case "bloodGlucose":
                types.insert(HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!)
            case "weight":
                types.insert(HKQuantityType.quantityType(forIdentifier: .bodyMass)!)
            case "heartRate":
                types.insert(HKQuantityType.quantityType(forIdentifier: .heartRate)!)
            case "restingHeartRate":
                types.insert(HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!)
            case "respiratoryRate":
                types.insert(HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!)
            case "bodyFat":
                types.insert(HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!)
            case "oxygenSaturation":
                types.insert(HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!)
            case "basalBodyTemperature":
                types.insert(HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature)!)
            case "bodyTemperature":
                types.insert(HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!)
            case "bloodPressureSystolic":
                types.insert(HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!)
            case "bloodPressureDiastolic":
                types.insert(HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!)
            case "heartRateVariability":
                types.insert(HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!)
            case "height":
                types.insert(HKQuantityType.quantityType(forIdentifier: .height)!)
            case "totalCalories":
                types.insert(HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)
            case "mindfulness":
                types.insert(HKObjectType.categoryType(forIdentifier: .mindfulSession)!)
            // New-style identifiers used in the unified API
            case "sleep":
                types.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
            case "workouts":
                types.insert(HKWorkoutType.workoutType())
            case "distanceCycling":
                types.insert(HKQuantityType.quantityType(forIdentifier: .distanceCycling)!)
            case "basalCalories":
                types.insert(HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!)
            case "exerciseTime":
                types.insert(HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!)
            case "appleWalkingSteadiness":
                if #available(iOS 15.0, *) {
                    types.insert(HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness)!)
                }
            case "walkingAsymmetryPercentage":
                if #available(iOS 15.0, *) {
                    types.insert(HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage)!)
                }
            default:
                print("no match in getTypes case: " + item)
            }
        }
        return types
    }

    // MARK: - Sleep State Mapping

    func getSleepStateString(value: Int) -> String {
        switch value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            return "InBed"
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            return "Awake"
        default:
            if #available(iOS 16.0, *) {
                switch value {
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:      return "AsleepCore"
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:      return "AsleepDeep"
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:       return "AsleepREM"
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: return "AsleepUnspecified"
                default: return "Asleep"
                }
            } else {
                return "Asleep"
            }
        }
    }

    /// Maps sleep category values to the new cross-platform sleep state strings.
    func sleepStateFromValue(_ value: Int) -> String? {
        switch value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:   return "inBed"
        case HKCategoryValueSleepAnalysis.asleep.rawValue:  return "asleep"
        case HKCategoryValueSleepAnalysis.awake.rawValue:   return "awake"
        default:
            if #available(iOS 16.0, *) {
                switch value {
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: return "asleep"
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:        return "light"
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:        return "deep"
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:         return "rem"
                default: return nil
                }
            }
            return nil
        }
    }

    // MARK: - Workout Activity Type Names

    func returnWorkoutActivityTypeValueDictionnary(activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .americanFootball:             return "American Football"
        case .archery:                      return "Archery"
        case .australianFootball:           return "Australian Football"
        case .badminton:                    return "Badminton"
        case .baseball:                     return "Baseball"
        case .basketball:                   return "Basketball"
        case .bowling:                      return "Bowling"
        case .boxing:                       return "Boxing"
        case .climbing:                     return "Climbing"
        case .crossTraining:                return "Cross Training"
        case .curling:                      return "Curling"
        case .cycling:                      return "Cycling"
        case .dance:                        return "Dance"
        case .danceInspiredTraining:        return "Dance Inspired Training"
        case .elliptical:                   return "Elliptical"
        case .equestrianSports:             return "Equestrian Sports"
        case .fencing:                      return "Fencing"
        case .fishing:                      return "Fishing"
        case .functionalStrengthTraining:   return "Functional Strength Training"
        case .golf:                         return "Golf"
        case .gymnastics:                   return "Gymnastics"
        case .handball:                     return "Handball"
        case .hiking:                       return "Hiking"
        case .hockey:                       return "Hockey"
        case .hunting:                      return "Hunting"
        case .lacrosse:                     return "Lacrosse"
        case .martialArts:                  return "Martial Arts"
        case .mindAndBody:                  return "Mind and Body"
        case .mixedMetabolicCardioTraining: return "Mixed Metabolic Cardio Training"
        case .paddleSports:                 return "Paddle Sports"
        case .play:                         return "Play"
        case .preparationAndRecovery:       return "Preparation and Recovery"
        case .racquetball:                  return "Racquetball"
        case .rowing:                       return "Rowing"
        case .rugby:                        return "Rugby"
        case .running:                      return "Running"
        case .sailing:                      return "Sailing"
        case .skatingSports:                return "Skating Sports"
        case .snowSports:                   return "Snow Sports"
        case .soccer:                       return "Soccer"
        case .softball:                     return "Softball"
        case .squash:                       return "Squash"
        case .stairClimbing:                return "Stair Climbing"
        case .surfingSports:                return "Surfing Sports"
        case .swimming:                     return "Swimming"
        case .tableTennis:                  return "Table Tennis"
        case .tennis:                       return "Tennis"
        case .trackAndField:                return "Track and Field"
        case .traditionalStrengthTraining:  return "Traditional Strength Training"
        case .volleyball:                   return "Volleyball"
        case .walking:                      return "Walking"
        case .waterFitness:                 return "Water Fitness"
        case .waterPolo:                    return "Water Polo"
        case .waterSports:                  return "Water Sports"
        case .wrestling:                    return "Wrestling"
        case .yoga:                         return "Yoga"
        case .barre:                        return "Barre"
        case .coreTraining:                 return "Core Training"
        case .crossCountrySkiing:           return "Cross Country Skiing"
        case .downhillSkiing:               return "Downhill Skiing"
        case .flexibility:                  return "Flexibility"
        case .highIntensityIntervalTraining: return "High Intensity Interval Training"
        case .jumpRope:                     return "Jump Rope"
        case .kickboxing:                   return "Kickboxing"
        case .pilates:                      return "Pilates"
        case .snowboarding:                 return "Snowboarding"
        case .stairs:                       return "Stairs"
        case .stepTraining:                 return "Step Training"
        case .wheelchairWalkPace:           return "Wheelchair Walk Pace"
        case .wheelchairRunPace:            return "Wheelchair Run Pace"
        case .taiChi:                       return "Tai Chi"
        case .mixedCardio:                  return "Mixed Cardio"
        case .handCycling:                  return "Hand Cycling"
        case .discSports:                   return "Disc Sports"
        case .fitnessGaming:                return "Fitness Gaming"
        default:                            return "Other"
        }
    }

    // MARK: - Helpers

    func getTimeZoneString(sample: HKSample? = nil) -> String {
        var timeZone: TimeZone?
        if let metaDataTimeZoneValue = sample?.metadata?[HKMetadataKeyTimeZone] as? String {
            timeZone = TimeZone(identifier: metaDataTimeZoneValue)
        }
        if timeZone == nil { timeZone = TimeZone.current }
        let seconds = timeZone?.secondsFromGMT() ?? 0
        let hours = seconds / 3600
        let minutes = abs(seconds / 60) % 60
        return String(format: "%+.2d:%.2d", hours, minutes)
    }

    func getDeviceInformation(device: HKDevice?) -> [String: String?]? {
        guard let device = device else { return nil }
        return [
            "name": device.name,
            "model": device.model,
            "manufacturer": device.manufacturer,
            "hardwareVersion": device.hardwareVersion,
            "softwareVersion": device.softwareVersion,
        ]
    }

    func getDateFromString(inputDate: String) -> Date {
        if let date = isoFormatter.date(from: inputDate) { return date }
        // Fallback to basic formatter without fractional seconds
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: inputDate) ?? Date()
    }

    // MARK: - Legacy Output Generation (queryHKitSampleType)

    func generateOutput(sampleName: String, results: [HKSample]?) -> [[String: Any]]? {
        var output: [[String: Any]] = []
        guard let results = results else { return output }

        for result in results {
            if sampleName == "sleepAnalysis" || sampleName == "mindfulness" {
                guard let sample = result as? HKCategorySample else { return nil }

                let sleepSD = sample.startDate as NSDate
                let sleepED = sample.endDate as NSDate
                let sleepInterval = sleepED.timeIntervalSince(sleepSD as Date)
                let sleepHours = sleepInterval / 3600

                var constructed: [String: Any] = [
                    "uuid": sample.uuid.uuidString,
                    "timeZone": getTimeZoneString(sample: sample),
                    "startDate": isoFormatter.string(from: sample.startDate),
                    "endDate": isoFormatter.string(from: sample.endDate),
                    "duration": sleepHours,
                    "source": sample.sourceRevision.source.name,
                    "sourceBundleId": sample.sourceRevision.source.bundleIdentifier,
                    "device": getDeviceInformation(device: sample.device) as Any,
                ]
                if sampleName == "sleepAnalysis" {
                    constructed["sleepState"] = getSleepStateString(value: sample.value)
                }
                output.append(constructed)

            } else if sampleName == "workoutType" {
                guard let sample = result as? HKWorkout else { return nil }

                var TEBData: Double = -1
                var TDData: Double = -1
                var TFCData: Double = -1
                var TSSCData: Double = -1

                if let teb = sample.totalEnergyBurned, teb.is(compatibleWith: HKUnit.kilocalorie()) {
                    TEBData = teb.doubleValue(for: .kilocalorie())
                }
                if let td = sample.totalDistance, td.is(compatibleWith: HKUnit.meter()) {
                    TDData = td.doubleValue(for: .meter())
                }
                if let tfc = sample.totalFlightsClimbed, tfc.is(compatibleWith: HKUnit.count()) {
                    TFCData = tfc.doubleValue(for: .count())
                }
                if let tssc = sample.totalSwimmingStrokeCount, tssc.is(compatibleWith: HKUnit.count()) {
                    TSSCData = tssc.doubleValue(for: .count())
                }

                let workoutSD = sample.startDate as NSDate
                let workoutED = sample.endDate as NSDate
                let workoutHours = workoutED.timeIntervalSince(workoutSD as Date) / 3600

                output.append([
                    "uuid": sample.uuid.uuidString,
                    "startDate": isoFormatter.string(from: sample.startDate),
                    "endDate": isoFormatter.string(from: sample.endDate),
                    "duration": workoutHours,
                    "source": sample.sourceRevision.source.name,
                    "sourceBundleId": sample.sourceRevision.source.bundleIdentifier,
                    "device": getDeviceInformation(device: sample.device) as Any,
                    "workoutActivityId": sample.workoutActivityType.rawValue,
                    "workoutActivityName": returnWorkoutActivityTypeValueDictionnary(activityType: sample.workoutActivityType),
                    "totalEnergyBurned": TEBData,
                    "totalDistance": TDData,
                    "totalFlightsClimbed": TFCData,
                    "totalSwimmingStrokeCount": TSSCData,
                ])

            } else {
                guard let sample = result as? HKQuantitySample else { return nil }

                var unit: HKUnit?
                var unitName: String?

                if sampleName == "heartRate" || sampleName == "restingHeartRate" {
                    unit = HKUnit(from: "count/min"); unitName = "BPM"
                } else if sampleName == "heartRateVariability" {
                    unit = HKUnit.secondUnit(with: .milli); unitName = "ms"
                } else if ["appleWalkingSteadiness", "walkingAsymmetryPercentage",
                            "oxygenSaturation", "bodyFat"].contains(sampleName) {
                    unit = HKUnit.percent(); unitName = "percent"
                } else if sampleName == "weight" {
                    unit = HKUnit.gramUnit(with: .kilo); unitName = "kilogram"
                } else if sampleName == "respiratoryRate" {
                    unit = HKUnit(from: "count/min"); unitName = "BrPM"
                } else if sampleName == "height" {
                    unit = HKUnit.meterUnit(with: .centi); unitName = "centimeter"
                } else if sample.quantityType.is(compatibleWith: HKUnit.meter()) {
                    unit = HKUnit.meter(); unitName = "meter"
                } else if sample.quantityType.is(compatibleWith: HKUnit.count()) {
                    unit = HKUnit.count(); unitName = "count"
                } else if sample.quantityType.is(compatibleWith: HKUnit.minute()) {
                    unit = HKUnit.minute(); unitName = "minute"
                } else if sample.quantityType.is(compatibleWith: HKUnit.kilocalorie()) {
                    unit = HKUnit.kilocalorie(); unitName = "kilocalorie"
                } else if sample.quantityType.is(compatibleWith:
                    HKUnit.moleUnit(withMolarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: HKUnit.literUnit(with: .kilo))) {
                    unit = HKUnit.moleUnit(withMolarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: HKUnit.literUnit(with: .kilo))
                    unitName = "mmol/L"
                } else if sample.quantityType.is(compatibleWith: HKUnit.degreeCelsius()) {
                    unit = HKUnit.degreeCelsius(); unitName = "celsius"
                } else if sample.quantityType.is(compatibleWith: HKUnit.millimeterOfMercury()) {
                    unit = HKUnit.millimeterOfMercury(); unitName = "mmHg"
                } else {
                    print("Error: unknown unit type for \(sampleName)")
                }

                guard let resolvedUnit = unit, let resolvedUnitName = unitName else { continue }

                let quantitySD = sample.startDate as NSDate
                let quantityED = sample.endDate as NSDate
                let quantityHours = quantityED.timeIntervalSince(quantitySD as Date) / 3600

                output.append([
                    "uuid": sample.uuid.uuidString,
                    "value": sample.quantity.doubleValue(for: resolvedUnit),
                    "unitName": resolvedUnitName,
                    "startDate": isoFormatter.string(from: sample.startDate),
                    "endDate": isoFormatter.string(from: sample.endDate),
                    "duration": quantityHours,
                    "source": sample.sourceRevision.source.name,
                    "sourceBundleId": sample.sourceRevision.source.bundleIdentifier,
                    "device": getDeviceInformation(device: sample.device) as Any,
                ])
            }
        }
        return output
    }

    // MARK: - Plugin Methods: Availability & Version

    @objc func isAvailable(_ call: CAPPluginCall) {
        if HKHealthStore.isHealthDataAvailable() {
            // Resolve with platform info (new API), but also compatible with old code that
            // simply awaited isAvailable() and caught rejections for unavailability.
            call.resolve(["available": true, "platform": "ios"])
        } else {
            // Preserve original behavior: reject so try/catch patterns still work.
            call.reject("Health data not available")
        }
    }

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve(["version": pluginVersion])
    }

    // MARK: - Plugin Methods: Authorization

    @objc func requestAuthorization(_ call: CAPPluginCall) {
        if !HKHealthStore.isHealthDataAvailable() {
            return call.reject("Health data not available")
        }

        // Accept both legacy (all/read/write) and new-style (read/write only) formats
        let allItems = (call.options["all"] as? [String]) ?? []
        let readItems = (call.options["read"] as? [String]) ?? []
        let writeItems = (call.options["write"] as? [String]) ?? []

        let writeTypes = getTypes(items: writeItems).union(getTypes(items: allItems))
        let readTypes = getTypes(items: readItems).union(getTypes(items: allItems))

        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { [weak self] success, error in
            guard let self = self else { return }
            if !success {
                call.reject(error?.localizedDescription ?? "Could not get permission")
                return
            }
            // Return authorization status in the new cross-platform format
            self.buildAuthorizationStatus(
                readIdentifiers: Array(readItems + allItems),
                writeIdentifiers: Array(writeItems + allItems)
            ) { statusPayload in
                call.resolve(statusPayload)
            }
        }
    }

    @objc func checkAuthorization(_ call: CAPPluginCall) {
        let readIdentifiers = (call.options["read"] as? [String]) ?? []
        let writeIdentifiers = (call.options["write"] as? [String]) ?? []

        buildAuthorizationStatus(readIdentifiers: readIdentifiers, writeIdentifiers: writeIdentifiers) { payload in
            call.resolve(payload)
        }
    }

    private func buildAuthorizationStatus(
        readIdentifiers: [String],
        writeIdentifiers: [String],
        completion: @escaping ([String: Any]) -> Void
    ) {
        var readAuthorized: [String] = []
        var readDenied: [String] = []
        var writeAuthorized: [String] = []
        var writeDenied: [String] = []

        let group = DispatchGroup()

        // Check read status using getRequestStatusForAuthorization
        let readObjectTypes = readIdentifiers.compactMap { id -> HKObjectType? in
            if id == "bloodPressure" {
                return nil // handled separately below as two types
            }
            if id == "workouts" { return HKObjectType.workoutType() }
            if let t = try? getHealthDataType(identifier: id) { return t }
            // Legacy group name fallback
            if let t = getSampleType(sampleName: id) { return t }
            return nil
        }

        let emptyShare: Set<HKSampleType> = []
        for identifier in readIdentifiers {
            var objectTypeSet: Set<HKObjectType> = []
            if identifier == "bloodPressure" {
                objectTypeSet.insert(HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!)
                objectTypeSet.insert(HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!)
            } else if identifier == "workouts" {
                objectTypeSet.insert(HKObjectType.workoutType())
            } else if let t = (try? getHealthDataType(identifier: identifier)) ?? getSampleType(sampleName: identifier) {
                objectTypeSet.insert(t)
            } else {
                readDenied.append(identifier)
                continue
            }

            group.enter()
            healthStore.getRequestStatusForAuthorization(toShare: emptyShare, read: objectTypeSet) { status, _ in
                defer { group.leave() }
                if status == .unnecessary {
                    readAuthorized.append(identifier)
                } else {
                    readDenied.append(identifier)
                }
            }
        }

        // Write status is synchronous via authorizationStatus
        for identifier in writeIdentifiers {
            let sampleType: HKSampleType?
            if identifier == "bloodPressure" {
                // Check systolic as proxy
                sampleType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)
            } else {
                sampleType = (try? getHealthDataType(identifier: identifier) as? HKSampleType) ?? getSampleType(sampleName: identifier)
            }
            if let t = sampleType {
                if healthStore.authorizationStatus(for: t) == .sharingAuthorized {
                    writeAuthorized.append(identifier)
                } else {
                    writeDenied.append(identifier)
                }
            } else {
                writeDenied.append(identifier)
            }
        }

        group.notify(queue: .main) {
            completion([
                "readAuthorized": readAuthorized,
                "readDenied": readDenied,
                "writeAuthorized": writeAuthorized,
                "writeDenied": writeDenied,
            ])
        }
    }

    @objc func isEditionAuthorized(_ call: CAPPluginCall) {
        guard let sampleName = call.options["sampleName"] as? String else {
            return call.reject("Must provide sampleName")
        }
        guard let sampleType = getSampleType(sampleName: sampleName) else {
            return call.reject("Cannot match sample name")
        }
        if healthStore.authorizationStatus(for: sampleType) == .sharingAuthorized {
            call.resolve()
        } else {
            call.reject("Permission Denied to Access data")
        }
    }

    @objc func multipleIsEditionAuthorized(_ call: CAPPluginCall) {
        guard let sampleNames = call.options["sampleNames"] as? [String] else {
            return call.reject("Must provide sampleNames")
        }
        for sampleName in sampleNames {
            guard let sampleType = getSampleType(sampleName: sampleName) else {
                return call.reject("Cannot match sample name")
            }
            if healthStore.authorizationStatus(for: sampleType) != .sharingAuthorized {
                return call.reject("Permission Denied to Access data")
            }
        }
        call.resolve()
    }

    // MARK: - Plugin Methods: New Unified Read API

    @objc func readSamples(_ call: CAPPluginCall) {
        guard let dataTypeIdentifier = call.getString("dataType") else {
            return call.reject("dataType is required")
        }

        guard let sampleType = try? getHealthDataType(identifier: dataTypeIdentifier) else {
            return call.reject("Unsupported data type: \(dataTypeIdentifier)")
        }

        let startDate: Date
        if let startStr = call.getString("startDate") {
            startDate = getDateFromString(inputDate: startStr)
        } else {
            startDate = Date().addingTimeInterval(-86400)
        }

        let endDate: Date
        if let endStr = call.getString("endDate") {
            endDate = getDateFromString(inputDate: endStr)
        } else {
            endDate = Date()
        }

        guard endDate >= startDate else {
            return call.reject("endDate must be greater than or equal to startDate")
        }

        let limit = call.getInt("limit") ?? 100
        let ascending = call.getBool("ascending") ?? false
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: ascending)

        // ── Sleep ──────────────────────────────────────────────────────────────
        if dataTypeIdentifier == "sleep" {
            let query = HKSampleQuery(sampleType: sampleType, predicate: predicate,
                                      limit: limit, sortDescriptors: [sortDesc]) { [weak self] _, samples, error in
                guard let self = self else { return }
                if let error = error { call.reject(error.localizedDescription); return }
                let results = (samples as? [HKCategorySample] ?? []).map { sample -> [String: Any] in
                    let durationMinutes = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                    var payload: [String: Any] = [
                        "dataType": dataTypeIdentifier,
                        "value": durationMinutes,
                        "unit": self.unitIdentifier(for: dataTypeIdentifier),
                        "startDate": self.isoFormatter.string(from: sample.startDate),
                        "endDate": self.isoFormatter.string(from: sample.endDate),
                        "sourceName": sample.sourceRevision.source.name,
                        "sourceId": sample.sourceRevision.source.bundleIdentifier,
                        "platformId": sample.uuid.uuidString,
                    ]
                    if let state = self.sleepStateFromValue(sample.value) {
                        payload["sleepState"] = state
                    }
                    return payload
                }
                call.resolve(["samples": results])
            }
            healthStore.execute(query)
            return
        }

        // ── Mindfulness ────────────────────────────────────────────────────────
        if dataTypeIdentifier == "mindfulness" {
            let query = HKSampleQuery(sampleType: sampleType, predicate: predicate,
                                      limit: limit, sortDescriptors: [sortDesc]) { [weak self] _, samples, error in
                guard let self = self else { return }
                if let error = error { call.reject(error.localizedDescription); return }
                let results = (samples as? [HKCategorySample] ?? []).map { sample -> [String: Any] in
                    return [
                        "dataType": dataTypeIdentifier,
                        "value": sample.endDate.timeIntervalSince(sample.startDate) / 60.0,
                        "unit": self.unitIdentifier(for: dataTypeIdentifier),
                        "startDate": self.isoFormatter.string(from: sample.startDate),
                        "endDate": self.isoFormatter.string(from: sample.endDate),
                        "sourceName": sample.sourceRevision.source.name,
                        "sourceId": sample.sourceRevision.source.bundleIdentifier,
                        "platformId": sample.uuid.uuidString,
                    ]
                }
                call.resolve(["samples": results])
            }
            healthStore.execute(query)
            return
        }

        // ── Blood Pressure (correlation) ──────────────────────────────────────
        if dataTypeIdentifier == "bloodPressure" {
            guard let bpType = HKObjectType.correlationType(forIdentifier: .bloodPressure) else {
                return call.reject("Blood pressure type unavailable")
            }
            let query = HKSampleQuery(sampleType: bpType, predicate: predicate,
                                      limit: limit, sortDescriptors: [sortDesc]) { [weak self] _, samples, error in
                guard let self = self else { return }
                if let error = error { call.reject(error.localizedDescription); return }
                let results: [[String: Any]] = (samples as? [HKCorrelation] ?? []).compactMap { correlation in
                    guard let systolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
                          let diastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic),
                          let systolicSample = correlation.objects(for: systolicType).first as? HKQuantitySample,
                          let diastolicSample = correlation.objects(for: diastolicType).first as? HKQuantitySample else {
                        return nil
                    }
                    let systolicVal = systolicSample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                    let diastolicVal = diastolicSample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                    return [
                        "dataType": dataTypeIdentifier,
                        "value": systolicVal,
                        "unit": self.unitIdentifier(for: dataTypeIdentifier),
                        "startDate": self.isoFormatter.string(from: correlation.startDate),
                        "endDate": self.isoFormatter.string(from: correlation.endDate),
                        "systolic": systolicVal,
                        "diastolic": diastolicVal,
                        "sourceName": correlation.sourceRevision.source.name,
                        "sourceId": correlation.sourceRevision.source.bundleIdentifier,
                        "platformId": correlation.uuid.uuidString,
                    ]
                }
                call.resolve(["samples": results])
            }
            healthStore.execute(query)
            return
        }

        // ── Quantity samples (general) ─────────────────────────────────────────
        guard let unit = defaultUnit(for: dataTypeIdentifier) else {
            return call.reject("Cannot determine unit for \(dataTypeIdentifier)")
        }

        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate,
                                  limit: limit, sortDescriptors: [sortDesc]) { [weak self] _, samples, error in
            guard let self = self else { return }
            if let error = error { call.reject(error.localizedDescription); return }
            let results = (samples as? [HKQuantitySample] ?? []).map { sample -> [String: Any] in
                // height: convert meters to centimeters
                let rawValue = sample.quantity.doubleValue(for: unit)
                let value = (dataTypeIdentifier == "height") ? rawValue * 100.0 : rawValue
                return [
                    "dataType": dataTypeIdentifier,
                    "value": value,
                    "unit": self.unitIdentifier(for: dataTypeIdentifier),
                    "startDate": self.isoFormatter.string(from: sample.startDate),
                    "endDate": self.isoFormatter.string(from: sample.endDate),
                    "sourceName": sample.sourceRevision.source.name,
                    "sourceId": sample.sourceRevision.source.bundleIdentifier,
                    "platformId": sample.uuid.uuidString,
                ]
            }
            call.resolve(["samples": results])
        }
        healthStore.execute(query)
    }

    // MARK: - Plugin Methods: Write

    @objc func saveSample(_ call: CAPPluginCall) {
        guard let dataTypeIdentifier = call.getString("dataType") else {
            return call.reject("dataType is required")
        }
        guard let value = call.getDouble("value") else {
            return call.reject("value is required")
        }

        let startDate: Date
        if let startStr = call.getString("startDate") {
            startDate = getDateFromString(inputDate: startStr)
        } else {
            startDate = Date()
        }
        let endDate: Date
        if let endStr = call.getString("endDate") {
            endDate = getDateFromString(inputDate: endStr)
        } else {
            endDate = startDate
        }

        guard endDate >= startDate else {
            return call.reject("endDate must be greater than or equal to startDate")
        }

        var metadataDictionary: [String: Any]?
        if let metadata = call.options["metadata"] as? [String: String], !metadata.isEmpty {
            metadataDictionary = metadata
        }

        // ── Sleep ──────────────────────────────────────────────────────────────
        if dataTypeIdentifier == "sleep" {
            guard let categoryType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
                return call.reject("Sleep type unavailable")
            }
            let sleepValue = Int(value) == 0 ? HKCategoryValueSleepAnalysis.asleep.rawValue : Int(value)
            let sample = HKCategorySample(type: categoryType, value: sleepValue,
                                          start: startDate, end: endDate, metadata: metadataDictionary)
            healthStore.save(sample) { success, error in
                if let error = error { call.reject(error.localizedDescription); return }
                if success { call.resolve() } else { call.reject("Failed to save sleep sample.") }
            }
            return
        }

        // ── Mindfulness ────────────────────────────────────────────────────────
        if dataTypeIdentifier == "mindfulness" {
            guard let categoryType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
                return call.reject("Mindfulness type unavailable")
            }
            let sample = HKCategorySample(type: categoryType, value: 0,
                                          start: startDate, end: endDate, metadata: metadataDictionary)
            healthStore.save(sample) { success, error in
                if let error = error { call.reject(error.localizedDescription); return }
                if success { call.resolve() } else { call.reject("Failed to save mindfulness sample.") }
            }
            return
        }

        // ── Blood Pressure (correlation) ──────────────────────────────────────
        if dataTypeIdentifier == "bloodPressure" {
            guard let systolicVal = call.getDouble("systolic"),
                  let diastolicVal = call.getDouble("diastolic") else {
                return call.reject("Blood pressure requires both systolic and diastolic values")
            }
            guard let systolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
                  let diastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic),
                  let correlationType = HKObjectType.correlationType(forIdentifier: .bloodPressure) else {
                return call.reject("Blood pressure types unavailable")
            }
            let mmHg = HKUnit.millimeterOfMercury()
            let systolicSample = HKQuantitySample(type: systolicType,
                quantity: HKQuantity(unit: mmHg, doubleValue: systolicVal),
                start: startDate, end: endDate)
            let diastolicSample = HKQuantitySample(type: diastolicType,
                quantity: HKQuantity(unit: mmHg, doubleValue: diastolicVal),
                start: startDate, end: endDate)
            let correlation = HKCorrelation(type: correlationType, start: startDate, end: endDate,
                                            objects: [systolicSample, diastolicSample], metadata: metadataDictionary)
            healthStore.save(correlation) { success, error in
                if let error = error { call.reject(error.localizedDescription); return }
                if success { call.resolve() } else { call.reject("Failed to save blood pressure.") }
            }
            return
        }

        // ── Quantity samples ───────────────────────────────────────────────────
        guard let sampleType = (try? getHealthDataType(identifier: dataTypeIdentifier)) as? HKQuantityType else {
            return call.reject("Unsupported data type: \(dataTypeIdentifier)")
        }
        guard let unit = defaultUnit(for: dataTypeIdentifier) else {
            return call.reject("Cannot determine unit for \(dataTypeIdentifier)")
        }

        // height: caller passes centimeters, HealthKit expects meters
        let hkValue = (dataTypeIdentifier == "height") ? value / 100.0 : value
        let quantity = HKQuantity(unit: unit, doubleValue: hkValue)
        let sample = HKQuantitySample(type: sampleType, quantity: quantity,
                                      start: startDate, end: endDate, metadata: metadataDictionary)
        healthStore.save(sample) { success, error in
            if let error = error { call.reject(error.localizedDescription); return }
            if success { call.resolve() } else { call.reject("Failed to save sample.") }
        }
    }

    // MARK: - Plugin Methods: Workouts

    @objc func queryWorkouts(_ call: CAPPluginCall) {
        let workoutTypeStr = call.getString("workoutType")
        let startDate: Date = {
            if let s = call.getString("startDate") { return getDateFromString(inputDate: s) }
            return Date().addingTimeInterval(-86400)
        }()
        let endDate: Date = {
            if let s = call.getString("endDate") { return getDateFromString(inputDate: s) }
            return Date()
        }()

        guard endDate >= startDate else {
            return call.reject("endDate must be greater than or equal to startDate")
        }

        let limit = call.getInt("limit") ?? 100
        let ascending = call.getBool("ascending") ?? false
        let anchorStr = call.getString("anchor")

        var effectiveStart = startDate
        var effectiveEnd = endDate
        if let anchor = anchorStr {
            let anchorDate = getDateFromString(inputDate: anchor)
            if ascending { effectiveStart = anchorDate } else { effectiveEnd = anchorDate }
        }

        var predicate = HKQuery.predicateForSamples(withStart: effectiveStart, end: effectiveEnd, options: [])

        if let typeStr = workoutTypeStr, let workoutActivityType = hkWorkoutType(from: typeStr) {
            let typePredicate = HKQuery.predicateForWorkouts(with: workoutActivityType)
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, typePredicate])
        }

        let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: ascending)
        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(),
                                  predicate: predicate,
                                  limit: limit,
                                  sortDescriptors: [sortDesc]) { [weak self] _, samples, error in
            guard let self = self else { return }
            if let error = error { call.reject(error.localizedDescription); return }

            let workouts = (samples as? [HKWorkout] ?? []).map { workout -> [String: Any] in
                var payload: [String: Any] = [
                    "workoutType": self.workoutTypeString(from: workout.workoutActivityType),
                    "duration": Int(workout.duration),
                    "startDate": self.isoFormatter.string(from: workout.startDate),
                    "endDate": self.isoFormatter.string(from: workout.endDate),
                    "sourceName": workout.sourceRevision.source.name,
                    "sourceId": workout.sourceRevision.source.bundleIdentifier,
                    "platformId": workout.uuid.uuidString,
                ]
                if let energy = workout.totalEnergyBurned {
                    payload["totalEnergyBurned"] = energy.doubleValue(for: .kilocalorie())
                }
                if let distance = workout.totalDistance {
                    payload["totalDistance"] = distance.doubleValue(for: .meter())
                }
                if let metadata = workout.metadata, !metadata.isEmpty {
                    var meta: [String: String] = [:]
                    for (key, val) in metadata {
                        if let sv = val as? String { meta[key] = sv }
                        else if let nv = val as? NSNumber { meta[key] = nv.stringValue }
                    }
                    if !meta.isEmpty { payload["metadata"] = meta }
                }
                return payload
            }

            var response: [String: Any] = ["workouts": workouts]
            if !workouts.isEmpty && workouts.count >= limit {
                let lastWorkout = (samples as? [HKWorkout])!.last!
                let nextAnchorDate = ascending
                    ? lastWorkout.endDate.addingTimeInterval(0.001)
                    : lastWorkout.startDate.addingTimeInterval(-0.001)
                response["anchor"] = self.isoFormatter.string(from: nextAnchorDate)
            }
            call.resolve(response)
        }
        healthStore.execute(query)
    }

    // MARK: - Plugin Methods: Aggregated Queries

    @objc func queryAggregated(_ call: CAPPluginCall) {
        guard let dataTypeIdentifier = call.getString("dataType") else {
            return call.reject("dataType is required")
        }

        guard !["sleep", "mindfulness", "respiratoryRate", "oxygenSaturation",
                "heartRateVariability", "bloodPressure"].contains(dataTypeIdentifier) else {
            return call.reject("Aggregated queries are not supported for \(dataTypeIdentifier). Use readSamples instead.")
        }

        guard let quantityType = try? getHealthDataType(identifier: dataTypeIdentifier) as? HKQuantityType else {
            return call.reject("Unsupported data type for aggregation: \(dataTypeIdentifier)")
        }

        let startDate: Date = {
            if let s = call.getString("startDate") { return getDateFromString(inputDate: s) }
            return Date().addingTimeInterval(-86400)
        }()
        let endDate: Date = {
            if let s = call.getString("endDate") { return getDateFromString(inputDate: s) }
            return Date()
        }()

        guard endDate >= startDate else {
            return call.reject("endDate must be greater than or equal to startDate")
        }

        let bucket = call.getString("bucket") ?? "day"
        let aggregation = call.getString("aggregation") ?? "sum"

        var anchorComponents = Calendar.current.dateComponents([.year, .month, .day], from: startDate)
        var intervalComponents = DateComponents()

        switch bucket {
        case "hour":  anchorComponents.hour = 0; intervalComponents.hour = 1
        case "day":   intervalComponents.day = 1
        case "week":  intervalComponents.day = 7
        case "month": intervalComponents.day = 30
        default:      intervalComponents.day = 1
        }

        guard let anchor = Calendar.current.date(from: anchorComponents) else {
            return call.reject("Failed to create anchor date")
        }

        var options: HKStatisticsOptions = []
        switch aggregation {
        case "sum":     options = .cumulativeSum
        case "average": options = .discreteAverage
        case "min":     options = .discreteMin
        case "max":     options = .discreteMax
        default:        options = .cumulativeSum
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: options,
            anchorDate: anchor,
            intervalComponents: intervalComponents
        )

        query.initialResultsHandler = { [weak self] _, collection, error in
            guard let self = self else { return }
            if let error = error { call.reject(error.localizedDescription); return }
            guard let collection = collection else {
                call.resolve(["samples": []]); return
            }

            guard let unit = self.defaultUnit(for: dataTypeIdentifier) else {
                call.reject("Cannot determine unit for \(dataTypeIdentifier)"); return
            }

            var samples: [[String: Any]] = []
            collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                var value: Double?
                switch aggregation {
                case "sum":     value = statistics.sumQuantity()?.doubleValue(for: unit)
                case "average": value = statistics.averageQuantity()?.doubleValue(for: unit)
                case "min":     value = statistics.minimumQuantity()?.doubleValue(for: unit)
                case "max":     value = statistics.maximumQuantity()?.doubleValue(for: unit)
                default:        value = statistics.sumQuantity()?.doubleValue(for: unit)
                }
                if let v = value {
                    samples.append([
                        "startDate": self.isoFormatter.string(from: statistics.startDate),
                        "endDate": self.isoFormatter.string(from: statistics.endDate),
                        "value": v,
                        "unit": self.unitIdentifier(for: dataTypeIdentifier),
                    ])
                }
            }
            call.resolve(["samples": samples])
        }
        healthStore.execute(query)
    }

    // MARK: - Plugin Methods: Legacy iOS API

    @objc func queryHKitSampleType(_ call: CAPPluginCall) {
        guard let _sampleName = call.options["sampleName"] as? String else {
            return call.reject("Must provide sampleName")
        }
        guard let startDateString = call.options["startDate"] as? String else {
            return call.reject("Must provide startDate")
        }
        guard let endDateString = call.options["endDate"] as? String else {
            return call.reject("Must provide endDate")
        }
        guard let _limit = call.options["limit"] as? Int else {
            return call.reject("Must provide limit")
        }

        let _startDate = getDateFromString(inputDate: startDateString)
        let _endDate = getDateFromString(inputDate: endDateString)
        let limit: Int = (_limit == 0) ? HKObjectQueryNoLimit : _limit
        let predicate = HKQuery.predicateForSamples(withStart: _startDate, end: _endDate, options: .strictStartDate)

        guard let sampleType: HKSampleType = getSampleType(sampleName: _sampleName) else {
            return call.reject("Error in sample name")
        }

        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate,
                                  limit: limit, sortDescriptors: nil) { [weak self] _, results, _ in
            guard let self = self else { return }
            guard let output = self.generateOutput(sampleName: _sampleName, results: results) else {
                return call.reject("Error happened while generating outputs")
            }
            call.resolve(["countReturn": output.count, "resultData": output])
        }
        healthStore.execute(query)
    }

    @objc func multipleQueryHKitSampleType(_ call: CAPPluginCall) {
        guard let _sampleNames = call.options["sampleNames"] as? [String] else {
            call.reject("Must provide sampleNames"); return
        }
        guard let startDateString = call.options["startDate"] as? String else {
            call.reject("Must provide startDate"); return
        }
        guard let endDateString = call.options["endDate"] as? String else {
            call.reject("Must provide endDate"); return
        }
        let _startDate = getDateFromString(inputDate: startDateString)
        let _endDate = getDateFromString(inputDate: endDateString)
        guard let _limit = call.options["limit"] as? Int else {
            call.reject("Must provide limit"); return
        }

        let limit = (_limit == 0) ? HKObjectQueryNoLimit : _limit
        var output: [String: [String: Any]] = [:]
        let dispatchGroup = DispatchGroup()

        for _sampleName in _sampleNames {
            dispatchGroup.enter()
            queryHKitSampleTypeSpecial(sampleName: _sampleName, startDate: _startDate,
                                       endDate: _endDate, limit: limit) { result in
                switch result {
                case let .success(sampleOutput):
                    output[_sampleName] = sampleOutput
                case let .failure(error):
                    let msg = (error as? HKSampleError)?.outputMessage ?? error.localizedDescription
                    output[_sampleName] = ["errorDescription": msg]
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            call.resolve(output)
        }
    }

    private func queryHKitSampleTypeSpecial(
        sampleName: String,
        startDate: Date,
        endDate: Date,
        limit: Int,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        guard let sampleType = getSampleType(sampleName: sampleName) else {
            return completion(.failure(HKSampleError.sampleTypeFailed))
        }
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate,
                                  limit: limit, sortDescriptors: nil) { [weak self] _, results, _ in
            guard let self = self else { return }
            guard let output = self.generateOutput(sampleName: sampleName, results: results) else {
                return completion(.failure(HKSampleError.sampleTypeFailed))
            }
            completion(.success(["countReturn": output.count, "resultData": output]))
        }
        healthStore.execute(query)
    }

    // MARK: - Plugin Methods: Android no-ops

    @objc func openHealthConnectSettings(_ call: CAPPluginCall) {
        // No-op on iOS — Health Connect is Android only
        call.resolve()
    }

    @objc func showPrivacyPolicy(_ call: CAPPluginCall) {
        // No-op on iOS — Health Connect is Android only
        call.resolve()
    }

    // MARK: - Workout Type Mapping (new API)

    private func workoutTypeString(from activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running:                      return "running"
        case .cycling:                      return "cycling"
        case .walking:                      return "walking"
        case .swimming:                     return "swimming"
        case .yoga:                         return "yoga"
        case .traditionalStrengthTraining:  return "strengthTraining"
        case .hiking:                       return "hiking"
        case .tennis:                       return "tennis"
        case .basketball:                   return "basketball"
        case .soccer:                       return "soccer"
        case .americanFootball:             return "americanFootball"
        case .archery:                      return "archery"
        case .australianFootball:           return "australianFootball"
        case .badminton:                    return "badminton"
        case .barre:                        return "barre"
        case .baseball:                     return "baseball"
        case .bowling:                      return "bowling"
        case .boxing:                       return "boxing"
        case .climbing:                     return "climbing"
        case .cooldown:                     return "cooldown"
        case .coreTraining:                 return "coreTraining"
        case .cricket:                      return "cricket"
        case .crossCountrySkiing:           return "crossCountrySkiing"
        case .crossTraining:                return "crossTraining"
        case .curling:                      return "curling"
        case .dance:                        return "dance"
        case .discSports:                   return "discSports"
        case .downhillSkiing:               return "downhillSkiing"
        case .elliptical:                   return "elliptical"
        case .equestrianSports:             return "equestrianSports"
        case .fencing:                      return "fencing"
        case .fishing:                      return "fishing"
        case .fitnessGaming:                return "fitnessGaming"
        case .flexibility:                  return "flexibility"
        case .functionalStrengthTraining:   return "functionalStrengthTraining"
        case .golf:                         return "golf"
        case .gymnastics:                   return "gymnastics"
        case .handball:                     return "handball"
        case .handCycling:                  return "handCycling"
        case .highIntensityIntervalTraining: return "highIntensityIntervalTraining"
        case .hockey:                       return "hockey"
        case .hunting:                      return "hunting"
        case .jumpRope:                     return "jumpRope"
        case .kickboxing:                   return "kickboxing"
        case .lacrosse:                     return "lacrosse"
        case .martialArts:                  return "martialArts"
        case .mindAndBody:                  return "mindAndBody"
        case .mixedCardio:                  return "mixedCardio"
        case .paddleSports:                 return "paddleSports"
        case .pickleball:                   return "pickleball"
        case .pilates:                      return "pilates"
        case .play:                         return "play"
        case .preparationAndRecovery:       return "preparationAndRecovery"
        case .racquetball:                  return "racquetball"
        case .rowing:                       return "rowing"
        case .rugby:                        return "rugby"
        case .sailing:                      return "sailing"
        case .skatingSports:                return "skatingSports"
        case .snowboarding:                 return "snowboarding"
        case .snowSports:                   return "snowSports"
        case .softball:                     return "softball"
        case .squash:                       return "squash"
        case .stairClimbing:                return "stairClimbing"
        case .stairs:                       return "stairs"
        case .stepTraining:                 return "stepTraining"
        case .surfingSports:                return "surfing"
        case .tableTennis:                  return "tableTennis"
        case .taiChi:                       return "taiChi"
        case .trackAndField:                return "trackAndField"
        case .volleyball:                   return "volleyball"
        case .waterFitness:                 return "waterFitness"
        case .waterPolo:                    return "waterPolo"
        case .waterSports:                  return "waterSports"
        case .wheelchairRunPace:            return "wheelchairRunPace"
        case .wheelchairWalkPace:           return "wheelchairWalkPace"
        case .wrestling:                    return "wrestling"
        default:
            if #available(iOS 14.0, *) {
                if activityType == .cardioDance { return "cardioDance" }
                if activityType == .socialDance { return "socialDance" }
            }
            if #available(iOS 16.0, *) {
                if activityType == .transition { return "transition" }
            }
            if #available(iOS 17.0, *) {
                if activityType == .underwaterDiving { return "underwaterDiving" }
            }
            return "other"
        }
    }

    private func hkWorkoutType(from typeString: String) -> HKWorkoutActivityType? {
        switch typeString {
        case "running":                     return .running
        case "cycling":                     return .cycling
        case "walking":                     return .walking
        case "swimming", "swimmingPool":    return .swimming
        case "swimmingOpenWater":           return .waterSports
        case "yoga":                        return .yoga
        case "strengthTraining", "traditionalStrengthTraining": return .traditionalStrengthTraining
        case "functionalStrengthTraining":  return .functionalStrengthTraining
        case "hiking":                      return .hiking
        case "tennis":                      return .tennis
        case "basketball":                  return .basketball
        case "soccer":                      return .soccer
        case "americanFootball":            return .americanFootball
        case "archery":                     return .archery
        case "australianFootball":          return .australianFootball
        case "badminton":                   return .badminton
        case "barre":                       return .barre
        case "baseball":                    return .baseball
        case "bowling":                     return .bowling
        case "boxing":                      return .boxing
        case "climbing", "rockClimbing":    return .climbing
        case "cooldown":                    return .cooldown
        case "coreTraining":                return .coreTraining
        case "cricket":                     return .cricket
        case "crossCountrySkiing":          return .crossCountrySkiing
        case "crossTraining":               return .crossTraining
        case "curling":                     return .curling
        case "dance", "dancing":            return .dance
        case "discSports", "frisbeedisc":   return .discSports
        case "downhillSkiing", "skiing":    return .downhillSkiing
        case "elliptical":                  return .elliptical
        case "equestrianSports":            return .equestrianSports
        case "fencing":                     return .fencing
        case "fishing":                     return .fishing
        case "fitnessGaming":               return .fitnessGaming
        case "flexibility", "stretching":   return .flexibility
        case "golf":                        return .golf
        case "gymnastics":                  return .gymnastics
        case "handball":                    return .handball
        case "handCycling":                 return .handCycling
        case "highIntensityIntervalTraining": return .highIntensityIntervalTraining
        case "hockey", "iceHockey":         return .hockey
        case "hunting":                     return .hunting
        case "jumpRope":                    return .jumpRope
        case "kickboxing":                  return .kickboxing
        case "lacrosse":                    return .lacrosse
        case "martialArts", "taiChi", "wrestling": return .martialArts
        case "mindAndBody", "meditation":   return .mindAndBody
        case "mixedCardio":                 return .mixedCardio
        case "paddleSports", "paddling":    return .paddleSports
        case "pilates":                     return .pilates
        case "play":                        return .play
        case "preparationAndRecovery":      return .preparationAndRecovery
        case "racquetball":                 return .racquetball
        case "rowing":                      return .rowing
        case "rugby":                       return .rugby
        case "sailing":                     return .sailing
        case "skatingSports", "skating":    return .skatingSports
        case "snowboarding":                return .snowboarding
        case "snowSports", "snowshoeing":   return .snowSports
        case "softball":                    return .softball
        case "squash":                      return .squash
        case "stairClimbing", "stairs":     return .stairClimbing
        case "stepTraining", "stairClimbingMachine": return .stepTraining
        case "surfing", "surfingSports":    return .surfingSports
        case "tableTennis":                 return .tableTennis
        case "trackAndField":               return .trackAndField
        case "volleyball":                  return .volleyball
        case "waterFitness":                return .waterFitness
        case "waterPolo":                   return .waterPolo
        case "waterSports":                 return .waterSports
        case "weightlifting":               return .traditionalStrengthTraining
        case "wheelchair":                  return .wheelchairWalkPace
        case "wheelchairRunPace":           return .wheelchairRunPace
        case "wheelchairWalkPace":          return .wheelchairWalkPace
        case "pickleball":                  return .pickleball
        default:
            if #available(iOS 14.0, *) {
                if typeString == "cardioDance" { return .cardioDance }
                if typeString == "socialDance" { return .socialDance }
            }
            if #available(iOS 16.0, *) {
                if typeString == "transition" { return .transition }
            }
            if #available(iOS 17.0, *) {
                if typeString == "underwaterDiving" || typeString == "scubaDiving" { return .underwaterDiving }
            }
            return nil
        }
    }
}
