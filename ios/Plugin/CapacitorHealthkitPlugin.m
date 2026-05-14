#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

// Define the plugin using the CAP_PLUGIN Macro, and
// each method the plugin supports using the CAP_PLUGIN_METHOD macro.
CAP_PLUGIN(CapacitorHealthkitPlugin, "CapacitorHealthkit",
           // Availability & version
           CAP_PLUGIN_METHOD(isAvailable, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(getPluginVersion, CAPPluginReturnPromise);

           // Authorization
           CAP_PLUGIN_METHOD(requestAuthorization, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(checkAuthorization, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(isEditionAuthorized, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(multipleIsEditionAuthorized, CAPPluginReturnPromise);

           // New unified read API
           CAP_PLUGIN_METHOD(readSamples, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(queryAggregated, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(queryWorkouts, CAPPluginReturnPromise);

           // Legacy iOS-style read API (backward compatible)
           CAP_PLUGIN_METHOD(queryHKitSampleType, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(multipleQueryHKitSampleType, CAPPluginReturnPromise);

           // Write
           CAP_PLUGIN_METHOD(saveSample, CAPPluginReturnPromise);

           // Android no-ops (present so TypeScript can call unconditionally)
           CAP_PLUGIN_METHOD(openHealthConnectSettings, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(showPrivacyPolicy, CAPPluginReturnPromise);
)
