import { WebPlugin } from '@capacitor/core';
import type { EditionQuery, AuthorizationQueryOptions, CapacitorHealthkitPlugin, MultipleQueryOptions, SingleQueryOptions } from './definitions';
export declare class CapacitorHealthkitWeb extends WebPlugin implements CapacitorHealthkitPlugin {
    requestAuthorization(_authOptions: AuthorizationQueryOptions): Promise<void>;
    queryHKitSampleType(_queryOptions: SingleQueryOptions): Promise<any>;
    queryWalkingAsymmetryPercentage(_queryOptions: SingleQueryOptions): Promise<any>;
    isAvailable(): Promise<void>;
    multipleQueryHKitSampleType(_queryOptions: MultipleQueryOptions): Promise<any>;
    isEditionAuthorized(_queryOptions: EditionQuery): Promise<void>;
    multipleIsEditionAuthorized(): Promise<void>;
}
