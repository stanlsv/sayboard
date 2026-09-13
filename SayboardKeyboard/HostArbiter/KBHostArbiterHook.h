// KBHostArbiterHook -- captures the host app's bundle ID from inside the keyboard
// extension on iOS 26.4+ by swizzling the private `_UIKeyboardArbiterClient`.
//
// Adapted from KeyboardHostBundleID by Muskupecli (MIT):
// https://github.com/Muskupecli/KeyboardHostBundleID
//
// Installs via `+load` at dyld image-load time -- strictly before the first
// keyboard-arbiter dispatch. Installing any later misses the initial
// destination change that carries the host bundle identifier.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KBHostArbiterHook : NSObject

/// Most recent host bundle ID observed by the swizzle in this process, or nil
/// if it has not fired yet (or iOS < 26.4). Thread-safe.
+ (nullable NSString *)lastCapturedHostBundleId;

/// Pings the keyboard arbiter so it dispatches a destination-changed callback, giving the passive
/// swizzle a chance to fire. Call it when the keyboard appears, so the host is captured before the
/// user taps the mic. No-op < 26.4.
+ (void)activeArbiterCheck;

@end

NS_ASSUME_NONNULL_END
