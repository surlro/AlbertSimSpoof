#import <Foundation/Foundation.h>
#import <substrate.h>

// AlbertSimSpoof — companion tweak to AlbertProbe
// Reads device_info.json from the AlbertProbe control directory and
// substitutes UniqueChipID, UniqueDeviceID, ProductType, ModelNumber,
// RegionInfo, RegulatoryModelNumber, DeviceVariant in DeviceInfo so
// Apple issues an activation ticket for the target identity.

#define CONTROL_DIR @"/private/var/mobile/Library/Logs/mobileactivationd/AlbertProbe"
#define DEVICE_INFO_PATH CONTROL_DIR @"/device_info.json"
#define MODE_PATH CONTROL_DIR @"/mode.txt"

static NSDictionary *spoofedDeviceInfo = nil;
static BOOL spoofEnabled = NO;

static void loadSpoofConfig(void) {
    NSString *mode = [[NSString stringWithContentsOfFile:MODE_PATH
                                               encoding:NSUTF8StringEncoding
                                                  error:nil]
                      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![mode isEqualToString:@"mutate"]) {
        spoofEnabled = NO;
        spoofedDeviceInfo = nil;
        return;
    }
    NSData *data = [NSData dataWithContentsOfFile:DEVICE_INFO_PATH];
    if (!data) {
        spoofEnabled = NO;
        spoofedDeviceInfo = nil;
        return;
    }
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![info isKindOfClass:[NSDictionary class]]) {
        spoofEnabled = NO;
        spoofedDeviceInfo = nil;
        return;
    }
    spoofedDeviceInfo = info;
    spoofEnabled = YES;
}

// Hook: MobileActivation framework — the method that returns device info
// to the activation request builder.
%hook MADevice

- (id)copyValueForKey:(NSString *)key {
    loadSpoofConfig();
    if (spoofEnabled && spoofedDeviceInfo[key]) {
        id spoofed = spoofedDeviceInfo[key];
        // UniqueChipID must come back as NSNumber (uint64)
        if ([key isEqualToString:@"UniqueChipID"] && [spoofed isKindOfClass:[NSString class]]) {
            return @([spoofed unsignedLongLongValue]);
        }
        return spoofed;
    }
    return %orig;
}

%end

// Also hook the lockdown/gestalt layer in case DeviceInfo is built from there
%hook MGCopyAnswer

%new
+ (id)copyAnswerForQuestion:(NSString *)question {
    loadSpoofConfig();
    if (spoofEnabled && spoofedDeviceInfo[question]) {
        id spoofed = spoofedDeviceInfo[question];
        if ([question isEqualToString:@"UniqueChipID"] && [spoofed isKindOfClass:[NSString class]]) {
            return @([spoofed unsignedLongLongValue]);
        }
        return spoofed;
    }
    return %orig(question);
}

%end

%ctor {
    loadSpoofConfig();
}
