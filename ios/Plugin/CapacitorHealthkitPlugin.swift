import Foundation
import Capacitor
import HealthKit

var healthStore = HKHealthStore()

/**
 * Capacitor HealthKit Plugin
 * Reads data from Apple HealthKit including sleep stages (iOS 16+),
 * workouts, and quantity samples.
 */
@objc(CapacitorHealthkitPlugin)
public class CapacitorHealthkitPlugin: CAPPlugin {

    // MARK: - Error Types

    enum HKSampleError: Error {
        case sleepRequestFailed
        case workoutRequestFailed
        case quantityRequestFailed
        case sampleTypeFailed
        case deniedDataAccessFailed

        var outputMessage: String {
            switch self {
            case .sleepRequestFailed:
                return "sleepRequestFailed"
            case .workoutRequestFailed:
                return "workoutRequestFailed"
            case .quantityRequestFailed:
                return "quantityRequestFailed"
            case .sampleTypeFailed:
                return "sampleTypeFailed"
            case .deniedDataAccessFailed:
                return "deniedDataAccessFailed"
            }
        }
    }

    // MARK: - Sample Type Resolution

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
        case "appleWalkingSteadiness":
            if #available(iOS 15.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness)!
            } else {
                return nil
            }
        case "walkingAsymmetryPercentage":
            if #available(iOS 15.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage)!
            } else {
                return nil
            }
        default:
            return nil
        }
    }

    // MARK: - Authorization Type Resolution

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
            case "appleWalkingSteadiness":
                if #available(iOS 15.0, *) {
                    types.insert(HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness)!)
                }
            case "walkingAsymmetryPercentage":
                if #available(iOS 15.0, *) {
                    types.insert(HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage)!)
                }
            default:
                print("no match in case: " + item)
            }
        }
        return types
    }

    // MARK: - Sleep State Mapping (iOS 16+ stages)

    func getSleepStateString(value: Int) -> String {
        switch value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            return "InBed"
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            return "Awake"
        default:
            if #available(iOS 16.0, *) {
                switch value {
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    return "AsleepCore"
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    return "AsleepDeep"
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    return "AsleepREM"
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    return "AsleepUnspecified"
                default:
                    return "Asleep"
                }
            } else {
                // Pre-iOS 16: value 1 was "asleep"
                return "Asleep"
            }
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
        // iOS 10
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
        // iOS 11
        case .taiChi:                       return "Tai Chi"
        case .mixedCardio:                  return "Mixed Cardio"
        case .handCycling:                  return "Hand Cycling"
        // iOS 13
        case .discSports:                   return "Disc Sports"
        case .fitnessGaming:                return "Fitness Gaming"
        default:                            return "Other"
        }
    }

    // MARK: - Helpers

    func getTimeZoneString(sample: HKSample? = nil, shouldReturnDefaultTimeZoneInExceptions _: Bool = true) -> String {
        var timeZone: TimeZone?
        if let metaDataTimeZoneValue = sample?.metadata?[HKMetadataKeyTimeZone] as? String {
            timeZone = TimeZone(identifier: metaDataTimeZoneValue)
        }
        if timeZone == nil {
            timeZone = TimeZone.current
        }
        let seconds: Int = timeZone?.secondsFromGMT() ?? 0
        let hours = seconds / 3600
        let minutes = abs(seconds / 60) % 60
        let timeZoneString = String(format: "%+.2d:%.2d", hours, minutes)
        return timeZoneString
    }

    func getDeviceInformation(device: HKDevice?) -> [String: String?]? {
        guard let device = device else {
            return nil
        }
        return [
            "name": device.name,
            "model": device.model,
            "manufacturer": device.manufacturer,
            "hardwareVersion": device.hardwareVersion,
            "softwareVersion": device.softwareVersion,
        ]
    }

    func getDateFromString(inputDate: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: inputDate)!
    }

    // MARK: - Output Generation

    func generateOutput(sampleName: String, results: [HKSample]?) -> [[String: Any]]? {
        var output: [[String: Any]] = []

        guard let results = results else {
            return output
        }

        for result in results {
            if sampleName == "sleepAnalysis" {
                guard let sample = result as? HKCategorySample else {
                    return nil
                }

                let sleepSD = sample.startDate as NSDate
                let sleepED = sample.endDate as NSDate
                let sleepInterval = sleepED.timeIntervalSince(sleepSD as Date)
                let sleepHoursBetweenDates = sleepInterval / 3600

                // Map sleep stage using iOS 16+ values when available
                let sleepState = getSleepStateString(value: sample.value)

                let constructedSample: [String: Any] = [
                    "uuid": sample.uuid.uuidString,
                    "timeZone": getTimeZoneString(sample: sample) as String,
                    "startDate": ISO8601DateFormatter().string(from: sample.startDate),
                    "endDate": ISO8601DateFormatter().string(from: sample.endDate),
                    "duration": sleepHoursBetweenDates,
                    "sleepState": sleepState,
                    "source": sample.sourceRevision.source.name,
                    "sourceBundleId": sample.sourceRevision.source.bundleIdentifier,
                    "device": getDeviceInformation(device: sample.device) as Any,
                ]
                output.append(constructedSample)

            } else if sampleName == "workoutType" {
                guard let sample = result as? HKWorkout else {
                    return nil
                }

                var TEBData: Double = -1
                var TDData: Double = -1
                var TFCData: Double = -1
                var TSSCData: Double = -1

                if let totalEnergyBurned = sample.totalEnergyBurned,
                   totalEnergyBurned.is(compatibleWith: HKUnit.kilocalorie()) {
                    TEBData = totalEnergyBurned.doubleValue(for: .kilocalorie())
                }

                if let totalDistance = sample.totalDistance,
                   totalDistance.is(compatibleWith: HKUnit.meter()) {
                    TDData = totalDistance.doubleValue(for: .meter())
                }

                if let totalFlightsClimbed = sample.totalFlightsClimbed,
                   totalFlightsClimbed.is(compatibleWith: HKUnit.count()) {
                    TFCData = totalFlightsClimbed.doubleValue(for: .count())
                }

                if let totalSwimmingStrokeCount = sample.totalSwimmingStrokeCount,
                   totalSwimmingStrokeCount.is(compatibleWith: HKUnit.count()) {
                    TSSCData = totalSwimmingStrokeCount.doubleValue(for: .count())
                }

                let workoutSD = sample.startDate as NSDate
                let workoutED = sample.endDate as NSDate
                let workoutInterval = workoutED.timeIntervalSince(workoutSD as Date)
                let workoutHoursBetweenDates = workoutInterval / 3600

                output.append([
                    "uuid": sample.uuid.uuidString,
                    "startDate": ISO8601DateFormatter().string(from: sample.startDate),
                    "endDate": ISO8601DateFormatter().string(from: sample.endDate),
                    "duration": workoutHoursBetweenDates,
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
                // Quantity sample types
                guard let sample = result as? HKQuantitySample else {
                    return nil
                }

                var unit: HKUnit?
                var unitName: String?

                if sampleName == "heartRate" || sampleName == "restingHeartRate" {
                    unit = HKUnit(from: "count/min")
                    unitName = "BPM"
                } else if sampleName == "appleWalkingSteadiness" || sampleName == "walkingAsymmetryPercentage" {
                    unit = HKUnit.percent()
                    unitName = "percent"
                } else if sampleName == "weight" {
                    unit = HKUnit.gramUnit(with: .kilo)
                    unitName = "kilogram"
                } else if sampleName == "respiratoryRate" {
                    unit = HKUnit(from: "count/min")
                    unitName = "BrPM"
                } else if sampleName == "bodyFat" || sampleName == "oxygenSaturation" {
                    unit = HKUnit.percent()
                    unitName = "percent"
                } else if sample.quantityType.is(compatibleWith: HKUnit.meter()) {
                    unit = HKUnit.meter()
                    unitName = "meter"
                } else if sample.quantityType.is(compatibleWith: HKUnit.count()) {
                    unit = HKUnit.count()
                    unitName = "count"
                } else if sample.quantityType.is(compatibleWith: HKUnit.minute()) {
                    unit = HKUnit.minute()
                    unitName = "minute"
                } else if sample.quantityType.is(compatibleWith: HKUnit.kilocalorie()) {
                    unit = HKUnit.kilocalorie()
                    unitName = "kilocalorie"
                } else if sample.quantityType.is(compatibleWith: HKUnit.moleUnit(withMolarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: HKUnit.literUnit(with: .kilo))) {
                    unit = HKUnit.moleUnit(withMolarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: HKUnit.literUnit(with: .kilo))
                    unitName = "mmol/L"
                } else if sample.quantityType.is(compatibleWith: HKUnit.degreeCelsius()) {
                    unit = HKUnit.degreeCelsius()
                    unitName = "celsius"
                } else if sample.quantityType.is(compatibleWith: HKUnit.degreeFahrenheit()) {
                    unit = HKUnit.degreeFahrenheit()
                    unitName = "fahrenheit"
                } else if sample.quantityType.is(compatibleWith: HKUnit.kelvin()) {
                    unit = HKUnit.kelvin()
                    unitName = "kelvin"
                } else if sample.quantityType.is(compatibleWith: HKUnit.millimeterOfMercury()) {
                    unit = HKUnit.millimeterOfMercury()
                    unitName = "mmHg"
                } else {
                    print("Error: unknown unit type for \(sampleName)")
                }

                guard let resolvedUnit = unit, let resolvedUnitName = unitName else {
                    continue
                }

                let quantitySD = sample.startDate as NSDate
                let quantityED = sample.endDate as NSDate
                let quantityInterval = quantityED.timeIntervalSince(quantitySD as Date)
                let quantityHoursBetweenDates = quantityInterval / 3600

                output.append([
                    "uuid": sample.uuid.uuidString,
                    "value": sample.quantity.doubleValue(for: resolvedUnit),
                    "unitName": resolvedUnitName,
                    "startDate": ISO8601DateFormatter().string(from: sample.startDate),
                    "endDate": ISO8601DateFormatter().string(from: sample.endDate),
                    "duration": quantityHoursBetweenDates,
                    "source": sample.sourceRevision.source.name,
                    "sourceBundleId": sample.sourceRevision.source.bundleIdentifier,
                    "device": getDeviceInformation(device: sample.device) as Any,
                ])
            }
        }
        return output
    }

    // MARK: - Plugin Methods

    @objc func requestAuthorization(_ call: CAPPluginCall) {
        if !HKHealthStore.isHealthDataAvailable() {
            return call.reject("Health data not available")
        }
        guard let _all = call.options["all"] as? [String] else {
            return call.reject("Must provide all")
        }
        guard let _read = call.options["read"] as? [String] else {
            return call.reject("Must provide read")
        }
        guard let _write = call.options["write"] as? [String] else {
            return call.reject("Must provide write")
        }

        let writeTypes: Set<HKSampleType> = getTypes(items: _write).union(getTypes(items: _all))
        let readTypes: Set<HKSampleType> = getTypes(items: _read).union(getTypes(items: _all))

        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, _ in
            if !success {
                call.reject("Could not get permission")
                return
            }
            call.resolve()
        }
    }

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

        let _startDate = getDateFromString(inputDate: startDateString)
        let _endDate = getDateFromString(inputDate: endDateString)

        guard let _limit = call.options["limit"] as? Int else {
            return call.reject("Must provide limit")
        }

        let limit: Int = (_limit == 0) ? HKObjectQueryNoLimit : _limit

        let predicate = HKQuery.predicateForSamples(
            withStart: _startDate,
            end: _endDate,
            options: .strictStartDate
        )

        guard let sampleType: HKSampleType = getSampleType(sampleName: _sampleName) else {
            return call.reject("Error in sample name")
        }

        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: limit,
            sortDescriptors: nil
        ) { _, results, _ in
            guard let output: [[String: Any]] = self.generateOutput(
                sampleName: _sampleName,
                results: results
            ) else {
                return call.reject("Error happened while generating outputs")
            }
            call.resolve([
                "countReturn": output.count,
                "resultData": output,
            ])
        }
        healthStore.execute(query)
    }

    @objc func isAvailable(_ call: CAPPluginCall) {
        if HKHealthStore.isHealthDataAvailable() {
            return call.resolve()
        } else {
            return call.reject("Health data not available")
        }
    }

    @objc func isEditionAuthorized(_ call: CAPPluginCall) {
        guard let sampleName = call.options["sampleName"] as? String else {
            return call.reject("Must provide sampleName")
        }

        guard let sampleType: HKSampleType = getSampleType(sampleName: sampleName) else {
            return call.reject("Cannot match sample name")
        }

        if healthStore.authorizationStatus(for: sampleType) == .sharingAuthorized {
            return call.resolve()
        } else {
            return call.reject("Permission Denied to Access data")
        }
    }

    @objc func multipleIsEditionAuthorized(_ call: CAPPluginCall) {
        guard let sampleNames = call.options["sampleNames"] as? [String] else {
            return call.reject("Must provide sampleNames")
        }

        for sampleName in sampleNames {
            guard let sampleType: HKSampleType = getSampleType(sampleName: sampleName) else {
                return call.reject("Cannot match sample name")
            }
            if healthStore.authorizationStatus(for: sampleType) != .sharingAuthorized {
                return call.reject("Permission Denied to Access data")
            }
        }
        return call.resolve()
    }

    @objc func multipleQueryHKitSampleType(_ call: CAPPluginCall) {
        guard let _sampleNames = call.options["sampleNames"] as? [String] else {
            call.reject("Must provide sampleNames")
            return
        }
        guard let _startDate = call.options["startDate"] as? Date else {
            call.reject("Must provide startDate")
            return
        }
        guard let _endDate = call.options["endDate"] as? Date else {
            call.reject("Must provide endDate")
            return
        }
        guard let _limit = call.options["limit"] as? Int else {
            call.reject("Must provide limit")
            return
        }

        let limit: Int = (_limit == 0) ? HKObjectQueryNoLimit : _limit

        var output: [String: [String: Any]] = [:]

        let dispatchGroup = DispatchGroup()

        for _sampleName in _sampleNames {
            dispatchGroup.enter()

            queryHKitSampleTypeSpecial(
                sampleName: _sampleName,
                startDate: _startDate,
                endDate: _endDate,
                limit: limit
            ) { result in
                switch result {
                case let .success(sampleOutput):
                    output[_sampleName] = sampleOutput
                case let .failure(error):
                    var errorMessage = ""
                    if let localError = error as? HKSampleError {
                        errorMessage = localError.outputMessage
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    output[_sampleName] = ["errorDescription": errorMessage]
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            call.resolve(output)
        }
    }

    func queryHKitSampleTypeSpecial(
        sampleName: String,
        startDate: Date,
        endDate: Date,
        limit: Int,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        guard let sampleType: HKSampleType = getSampleType(sampleName: sampleName) else {
            return completion(.failure(HKSampleError.sampleTypeFailed))
        }

        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: limit,
            sortDescriptors: nil
        ) { _, results, _ in
            guard let output: [[String: Any]] = self.generateOutput(
                sampleName: sampleName,
                results: results
            ) else {
                return completion(.failure(HKSampleError.sampleTypeFailed))
            }
            completion(.success([
                "countReturn": output.count,
                "resultData": output,
            ]))
        }
        healthStore.execute(query)
    }
}