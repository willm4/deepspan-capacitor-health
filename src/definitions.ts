// ─── Unified Health Data Types ────────────────────────────────────────────────
// Used by the new readSamples / saveSample / queryAggregated APIs.
// These identifiers are cross-platform (iOS HealthKit + Android Health Connect).
export type HealthDataType =
  | 'steps'
  | 'distance'
  | 'calories'
  | 'heartRate'
  | 'weight'
  | 'sleep'
  | 'respiratoryRate'
  | 'oxygenSaturation'
  | 'restingHeartRate'
  | 'heartRateVariability'
  | 'bloodPressure'
  | 'bloodGlucose'
  | 'bodyTemperature'
  | 'height'
  | 'flightsClimbed'
  | 'exerciseTime'
  | 'distanceCycling'
  | 'bodyFat'
  | 'basalBodyTemperature'
  | 'basalCalories'
  | 'totalCalories'
  | 'mindfulness'
  | 'workouts';

export type HealthUnit =
  | 'count'
  | 'meter'
  | 'kilocalorie'
  | 'bpm'
  | 'kilogram'
  | 'minute'
  | 'percent'
  | 'millisecond'
  | 'mmHg'
  | 'mg/dL'
  | 'celsius'
  | 'fahrenheit'
  | 'centimeter';

// ─── Authorization ────────────────────────────────────────────────────────────

export interface AuthorizationOptions {
  /** Data types that should be readable after authorization. */
  read?: HealthDataType[];
  /** Data types that should be writable after authorization. */
  write?: HealthDataType[];
}

export interface AuthorizationStatus {
  readAuthorized: HealthDataType[];
  readDenied: HealthDataType[];
  writeAuthorized: HealthDataType[];
  writeDenied: HealthDataType[];
}

export interface AvailabilityResult {
  available: boolean;
  platform?: 'ios' | 'android' | 'web';
  reason?: string;
}

// ─── Reading samples ──────────────────────────────────────────────────────────

export interface QueryOptions {
  /** The type of data to retrieve from the health store. */
  dataType: HealthDataType;
  /** Inclusive ISO 8601 start date (defaults to now - 1 day). */
  startDate?: string;
  /** Exclusive ISO 8601 end date (defaults to now). */
  endDate?: string;
  /** Maximum number of samples to return (defaults to 100). */
  limit?: number;
  /** Return results sorted ascending by start date (defaults to false). */
  ascending?: boolean;
}

export type SleepState = 'inBed' | 'asleep' | 'awake' | 'rem' | 'deep' | 'light';

export interface HealthSample {
  dataType: HealthDataType;
  value: number;
  unit: HealthUnit;
  startDate: string;
  endDate: string;
  sourceName?: string;
  sourceId?: string;
  /** Platform-specific unique identifier (HealthKit UUID on iOS, Health Connect metadata ID on Android). */
  platformId?: string;
  /** For sleep data, indicates the sleep state (e.g., 'asleep', 'awake', 'rem', 'deep', 'light'). */
  sleepState?: SleepState;
  /** For blood pressure data, the systolic value in mmHg. */
  systolic?: number;
  /** For blood pressure data, the diastolic value in mmHg. */
  diastolic?: number;
}

export interface ReadSamplesResult {
  samples: HealthSample[];
}

// ─── Writing samples ──────────────────────────────────────────────────────────

export interface WriteSampleOptions {
  dataType: HealthDataType;
  value: number;
  /**
   * Optional unit override. If omitted, the default unit for the data type is used.
   */
  unit?: HealthUnit;
  /** ISO 8601 start date for the sample. Defaults to now. */
  startDate?: string;
  /** ISO 8601 end date for the sample. Defaults to startDate. */
  endDate?: string;
  /** Metadata key-value pairs forwarded to the native APIs where supported. */
  metadata?: Record<string, string>;
  /** For blood pressure data, the systolic value in mmHg. Required when dataType is 'bloodPressure'. */
  systolic?: number;
  /** For blood pressure data, the diastolic value in mmHg. Required when dataType is 'bloodPressure'. */
  diastolic?: number;
}

// ─── Workouts ─────────────────────────────────────────────────────────────────

export type WorkoutType =
  // Common cross-platform types
  | 'americanFootball'
  | 'australianFootball'
  | 'badminton'
  | 'baseball'
  | 'basketball'
  | 'bowling'
  | 'boxing'
  | 'climbing'
  | 'cricket'
  | 'crossTraining'
  | 'curling'
  | 'cycling'
  | 'dance'
  | 'elliptical'
  | 'fencing'
  | 'functionalStrengthTraining'
  | 'golf'
  | 'gymnastics'
  | 'handball'
  | 'hiking'
  | 'hockey'
  | 'jumpRope'
  | 'kickboxing'
  | 'lacrosse'
  | 'martialArts'
  | 'pilates'
  | 'racquetball'
  | 'rowing'
  | 'rugby'
  | 'running'
  | 'sailing'
  | 'skatingSports'
  | 'skiing'
  | 'snowboarding'
  | 'soccer'
  | 'softball'
  | 'squash'
  | 'stairClimbing'
  | 'strengthTraining'
  | 'surfing'
  | 'swimming'
  | 'swimmingPool'
  | 'swimmingOpenWater'
  | 'tableTennis'
  | 'tennis'
  | 'trackAndField'
  | 'traditionalStrengthTraining'
  | 'volleyball'
  | 'walking'
  | 'waterFitness'
  | 'waterPolo'
  | 'waterSports'
  | 'weightlifting'
  | 'wheelchair'
  | 'yoga'
  // iOS-specific types
  | 'archery'
  | 'barre'
  | 'cooldown'
  | 'coreTraining'
  | 'crossCountrySkiing'
  | 'discSports'
  | 'downhillSkiing'
  | 'equestrianSports'
  | 'fishing'
  | 'fitnessGaming'
  | 'flexibility'
  | 'handCycling'
  | 'highIntensityIntervalTraining'
  | 'hunting'
  | 'mindAndBody'
  | 'mixedCardio'
  | 'paddleSports'
  | 'pickleball'
  | 'play'
  | 'preparationAndRecovery'
  | 'snowSports'
  | 'stairs'
  | 'stepTraining'
  | 'surfingSports'
  | 'taiChi'
  | 'transition'
  | 'underwaterDiving'
  | 'wheelchairRunPace'
  | 'wheelchairWalkPace'
  | 'wrestling'
  | 'cardioDance'
  | 'socialDance'
  // Android-specific types
  | 'backExtension'
  | 'barbellShoulderPress'
  | 'benchPress'
  | 'benchSitUp'
  | 'bikingStationary'
  | 'bootCamp'
  | 'burpee'
  | 'calisthenics'
  | 'crunch'
  | 'dancing'
  | 'deadlift'
  | 'dumbbellCurlLeftArm'
  | 'dumbbellCurlRightArm'
  | 'dumbbellFrontRaise'
  | 'dumbbellLateralRaise'
  | 'dumbbellTricepsExtensionLeftArm'
  | 'dumbbellTricepsExtensionRightArm'
  | 'dumbbellTricepsExtensionTwoArm'
  | 'exerciseClass'
  | 'forwardTwist'
  | 'frisbeedisc'
  | 'guidedBreathing'
  | 'iceHockey'
  | 'iceSkating'
  | 'jumpingJack'
  | 'latPullDown'
  | 'lunge'
  | 'meditation'
  | 'paddling'
  | 'paraGliding'
  | 'plank'
  | 'rockClimbing'
  | 'rollerHockey'
  | 'rowingMachine'
  | 'runningTreadmill'
  | 'scubaDiving'
  | 'skating'
  | 'snowshoeing'
  | 'stairClimbingMachine'
  | 'stretching'
  | 'upperTwist'
  | 'other';

export interface QueryWorkoutsOptions {
  /** Optional workout type filter. If omitted, all workout types are returned. */
  workoutType?: WorkoutType;
  /** Inclusive ISO 8601 start date (defaults to now - 1 day). */
  startDate?: string;
  /** Exclusive ISO 8601 end date (defaults to now). */
  endDate?: string;
  /** Maximum number of workouts to return (defaults to 100). */
  limit?: number;
  /** Return results sorted ascending by start date (defaults to false). */
  ascending?: boolean;
  /**
   * Anchor for pagination. Pass the anchor returned from a previous query to continue from that point.
   * On iOS, this is the ISO 8601 cursor. On Android, this is Health Connect's pageToken.
   */
  anchor?: string;
}

export interface Workout {
  workoutType: WorkoutType;
  /** Duration in seconds. */
  duration: number;
  totalEnergyBurned?: number;
  totalDistance?: number;
  startDate: string;
  endDate: string;
  sourceName?: string;
  sourceId?: string;
  platformId?: string;
  metadata?: Record<string, string>;
}

export interface QueryWorkoutsResult {
  workouts: Workout[];
  /** Anchor for next page of results. Undefined when no more results exist. */
  anchor?: string;
}

// ─── Aggregated queries ───────────────────────────────────────────────────────

export type BucketType = 'hour' | 'day' | 'week' | 'month';
export type AggregationType = 'sum' | 'average' | 'min' | 'max';

export interface QueryAggregatedOptions {
  dataType: HealthDataType;
  startDate?: string;
  endDate?: string;
  bucket?: BucketType;
  aggregation?: AggregationType;
}

export interface AggregatedSample {
  startDate: string;
  endDate: string;
  value: number;
  unit: HealthUnit;
}

export interface QueryAggregatedResult {
  samples: AggregatedSample[];
}

// ─── Legacy iOS-style API (kept for backward compatibility) ───────────────────

/**
 * @deprecated Use HealthDataType with the readSamples / requestAuthorization APIs instead.
 */
export enum SampleNames {
  STEP_COUNT = 'stepCount',
  FLIGHTS_CLIMBED = 'flightsClimbed',
  APPLE_EXERCISE_TIME = 'appleExerciseTime',
  ACTIVE_ENERGY_BURNED = 'activeEnergyBurned',
  BASAL_ENERGY_BURNED = 'basalEnergyBurned',
  DISTANCE_WALKING_RUNNING = 'distanceWalkingRunning',
  DISTANCE_CYCLING = 'distanceCycling',
  BLOOD_GLUCOSE = 'bloodGlucose',
  SLEEP_ANALYSIS = 'sleepAnalysis',
  WORKOUT_TYPE = 'workoutType',
  WEIGHT = 'weight',
  HEART_RATE = 'heartRate',
  RESTING_HEART_RATE = 'restingHeartRate',
  RESPIRATORY_RATE = 'respiratoryRate',
  BODY_FAT = 'bodyFat',
  OXYGEN_SATURATION = 'oxygenSaturation',
  BASAL_BODY_TEMPERATURE = 'basalBodyTemperature',
  BODY_TEMPERATURE = 'bodyTemperature',
  BLOOD_PRESSURE_SYSTOLIC = 'bloodPressureSystolic',
  BLOOD_PRESSURE_DIASTOLIC = 'bloodPressureDiastolic',
  APPLE_WALKING_STEADINESS = 'appleWalkingSteadiness',
  WALKING_ASYMMETRY_PERCENTAGE = 'walkingAsymmetryPercentage',
}

export interface DeviceInformation {
  name: string | null;
  manufacturer: string | null;
  model: string | null;
  hardwareVersion: string | null;
  softwareVersion: string | null;
}

export interface BaseData {
  startDate: string;
  endDate: string;
  source: string;
  uuid: string;
  sourceBundleId: string;
  device: DeviceInformation | null;
  duration: number;
}

export interface SleepData extends BaseData {
  sleepState: string;
  timeZone: string;
}

export interface ActivityData extends BaseData {
  totalFlightsClimbed: number;
  totalSwimmingStrokeCount: number;
  totalEnergyBurned: number;
  totalDistance: number;
  workoutActivityId: number;
  workoutActivityName: string;
}

export interface OtherData extends BaseData {
  unitName: string;
  value: number;
}

export interface QueryOutput<T = SleepData | ActivityData | OtherData> {
  countReturn: number;
  resultData: T[];
}

export interface BaseQueryOptions {
  startDate: string;
  endDate: string;
  limit: number;
}

export interface SingleQueryOptions extends BaseQueryOptions {
  sampleName: string;
}

export interface MultipleQueryOptions extends BaseQueryOptions {
  sampleNames: string[];
}

export interface AuthorizationQueryOptions {
  read: string[];
  write: string[];
  all: string[];
}

export interface EditionQuery {
  sampleName: string;
}

export interface MultipleEditionQuery {
  sampleNames: string[];
}

// ─── Unified Plugin Interface ─────────────────────────────────────────────────

export interface CapacitorHealthkitPlugin {
  // ── Availability & version ─────────────────────────────────────────────────

  /**
   * Returns whether the native health SDK is available on this device.
   * On iOS resolves if HealthKit is available, rejects otherwise (legacy).
   * On Android returns an AvailabilityResult object with platform details.
   */
  isAvailable(): Promise<AvailabilityResult | void>;

  /** Returns the native plugin version string. */
  getPluginVersion(): Promise<{ version: string }>;

  // ── Authorization ──────────────────────────────────────────────────────────

  /**
   * Requests read/write access to health data.
   *
   * Accepts both the legacy iOS-style format (all/read/write with HealthKit
   * group names) and the new cross-platform format (read/write with HealthDataType values).
   */
  requestAuthorization(
    authOptions: AuthorizationQueryOptions | AuthorizationOptions,
  ): Promise<AuthorizationStatus | void>;

  /**
   * Checks current authorization status without prompting the user.
   * Returns lists of authorized and denied data types.
   */
  checkAuthorization(options: AuthorizationOptions): Promise<AuthorizationStatus>;

  /**
   * Checks write (edition) permission for a single sample type.
   * @deprecated Use checkAuthorization instead.
   */
  isEditionAuthorized(queryOptions: EditionQuery): Promise<void>;

  /**
   * Checks write (edition) permissions for multiple sample types.
   * @deprecated Use checkAuthorization instead.
   */
  multipleIsEditionAuthorized(queryOptions: MultipleEditionQuery): Promise<void>;

  // ── Reading data (new unified API) ────────────────────────────────────────

  /**
   * Reads samples for the given data type within the specified time frame.
   * Works on both iOS (HealthKit) and Android (Health Connect).
   */
  readSamples(options: QueryOptions): Promise<ReadSamplesResult>;

  /**
   * Reads aggregated health data bucketed by time interval.
   * More efficient than readSamples for large date ranges.
   */
  queryAggregated(options: QueryAggregatedOptions): Promise<QueryAggregatedResult>;

  /**
   * Queries workout / exercise sessions.
   * Supports pagination via the anchor parameter.
   */
  queryWorkouts(options: QueryWorkoutsOptions): Promise<QueryWorkoutsResult>;

  // ── Reading data (legacy iOS-style API) ───────────────────────────────────

  /**
   * Queries a single HealthKit sample type.
   * @deprecated Use readSamples instead.
   */
  queryHKitSampleType<T>(queryOptions: SingleQueryOptions): Promise<QueryOutput<T>>;

  /**
   * Queries multiple HealthKit sample types in one call.
   * @deprecated Use readSamples in a loop or queryAggregated instead.
   */
  multipleQueryHKitSampleType(queryOptions: MultipleQueryOptions): Promise<any>;

  // ── Writing data ──────────────────────────────────────────────────────────

  /** Writes a single sample to the native health store. */
  saveSample(options: WriteSampleOptions): Promise<void>;

  // ── Android-specific utilities ────────────────────────────────────────────

  /**
   * Opens the Health Connect settings screen on Android.
   * No-op on iOS.
   */
  openHealthConnectSettings(): Promise<void>;

  /**
   * Shows the app's privacy policy page required by Health Connect.
   * No-op on iOS.
   */
  showPrivacyPolicy(): Promise<void>;
}
