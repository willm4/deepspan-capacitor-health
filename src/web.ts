import { WebPlugin } from '@capacitor/core';

import type {
  AuthorizationOptions,
  AuthorizationQueryOptions,
  AuthorizationStatus,
  AvailabilityResult,
  CapacitorHealthkitPlugin,
  EditionQuery,
  MultipleEditionQuery,
  MultipleQueryOptions,
  QueryAggregatedOptions,
  QueryAggregatedResult,
  QueryOptions,
  QueryOutput,
  QueryWorkoutsOptions,
  QueryWorkoutsResult,
  ReadSamplesResult,
  SingleQueryOptions,
  WriteSampleOptions,
} from './definitions';

export class CapacitorHealthkitWeb extends WebPlugin implements CapacitorHealthkitPlugin {
  async isAvailable(): Promise<AvailabilityResult> {
    return {
      available: false,
      platform: 'web',
      reason: 'Native health APIs are not accessible in a browser environment.',
    };
  }

  async getPluginVersion(): Promise<{ version: string }> {
    return { version: 'web' };
  }

  async requestAuthorization(
    _authOptions: AuthorizationQueryOptions | AuthorizationOptions,
  ): Promise<AuthorizationStatus> {
    throw this.unimplemented('Health permissions are only available on native platforms.');
  }

  async checkAuthorization(_options: AuthorizationOptions): Promise<AuthorizationStatus> {
    throw this.unimplemented('Health permissions are only available on native platforms.');
  }

  async isEditionAuthorized(_queryOptions: EditionQuery): Promise<void> {
    throw this.unimplemented('Not implemented on web.');
  }

  async multipleIsEditionAuthorized(_queryOptions: MultipleEditionQuery): Promise<void> {
    throw this.unimplemented('Not implemented on web.');
  }

  async readSamples(_options: QueryOptions): Promise<ReadSamplesResult> {
    throw this.unimplemented('Reading health data is only available on native platforms.');
  }

  async queryAggregated(_options: QueryAggregatedOptions): Promise<QueryAggregatedResult> {
    throw this.unimplemented('Querying aggregated data is only available on native platforms.');
  }

  async queryWorkouts(_options: QueryWorkoutsOptions): Promise<QueryWorkoutsResult> {
    throw this.unimplemented('Querying workouts is only available on native platforms.');
  }

  async queryHKitSampleType<T>(_queryOptions: SingleQueryOptions): Promise<QueryOutput<T>> {
    throw this.unimplemented('Not implemented on web.');
  }

  async multipleQueryHKitSampleType(_queryOptions: MultipleQueryOptions): Promise<any> {
    throw this.unimplemented('Not implemented on web.');
  }

  async saveSample(_options: WriteSampleOptions): Promise<void> {
    throw this.unimplemented('Writing health data is only available on native platforms.');
  }

  async openHealthConnectSettings(): Promise<void> {
    // No-op on web
  }

  async showPrivacyPolicy(): Promise<void> {
    // No-op on web
  }
}
