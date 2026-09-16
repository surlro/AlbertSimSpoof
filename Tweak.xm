#import <Foundation/Foundation.h>
#import <substrate.h>

// AlbertSimSpoof — companion tweak to AlbertProbe
// Reads device_info.json and substitutes DeviceInfo fields so Apple issues
// an activation ticket for the target identity.

#define CONTROL_DIR @"/private/var/mobile/Library/Logs/mobileactivationd/AlbertProbe"
#define DEVICE_INFO_PATH CONTROL_DIR @"/device_info.json"
#define MODE_PATH        CONTROL_DIR @"/mode.txt"

static NSDictionary *_spoofInfo = nil;
static BOOL _spoofEnabled = NO;

static void reloadConfig(void) {
    NSString *mode = [[NSString stringWithContentsOfFile:MODE_PATH
                                               encoding:NSUTF8StringEncoding
                                                  error:nil]
                      stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![mode isEqualToString:@"mutate"]) {
        _spoofEnabled = NO;
        _spoofInfo = nil;
        return;
    }
    NSData *data = [NSData dataWithContentsOfFile:DEVICE_INFO_PATH];
    if (!data) { _spoofEnabled = NO; _spoofInfo = nil; return; }
    NSDictionary *d = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![d isKindOfClass:[NSDictionary class]]) { _spoofEnabled = NO; _spoofInfo = nil; return; }
    _spoofInfo = d;
    _spoofEnabled = YES;
}

// Hook the lockdown client that DeviceInfo is built from.
// LockdownClient is a CoreTelephony/MobileActivation internal class.
%hook LDClient

- (id)valueForDomain:(NSString *)domain key:(NSString *)key {
    reloadConfig();
    if (_spoofEnabled && key) {
        id v = _spoofInfo[key];
        if (v) {
            if ([key isEqualToString:@"UniqueChipID"] && [v isKindOfClass:[NSString class]])
                return @([v unsignedLongLongValue]);
            return v;
        }
    }
    return %orig;
}

- (id)value:(NSString *)key {
    reloadConfig();
    if (_spoofEnabled && key) {
        id v = _spoofInfo[key];
        if (v) {
            if ([key isEqualToString:@"UniqueChipID"] && [v isKindOfClass:[NSString class]])
                return @([v unsignedLongLongValue]);
            return v;
        }
    }
    return %orig;
}

%end

// Hook MGCopyAnswer (MobileGestalt C function) via MSHookFunction.
static CFTypeRef (*orig_MGCopyAnswer)(CFStringRef question) = NULL;

static CFTypeRef my_MGCopyAnswer(CFStringRef question) {
    reloadConfig();
    if (_spoofEnabled && question) {
        NSString *key = (__bridge NSString *)question;
        id v = _spoofInfo[key];
        if (v) {
            if ([key isEqualToString:@"UniqueChipID"] && [v isKindOfClass:[NSString class]])
                return (__bridge_retained CFTypeRef)@([v unsignedLongLongValue]);
            return (__bridge_retained CFTypeRef)v;
        }
    }
    return orig_MGCopyAnswer(question);
}

%ctor {
    reloadConfig();
    // Hook the MobileGestalt C function directly.
    void *mg = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
    if (mg) {
        void *sym = dlsym(mg, "MGCopyAnswer");
        if (sym) MSHookFunction(sym, (void *)my_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
    }
}
