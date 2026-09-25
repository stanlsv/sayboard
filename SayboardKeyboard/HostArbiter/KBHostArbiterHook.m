// KBHostArbiterHook -- see header. Adapted from KeyboardHostBundleID by
// Muskupecli (MIT): https://github.com/Muskupecli/KeyboardHostBundleID

#import "KBHostArbiterHook.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <os/lock.h>

// Private UIKit symbols resolved at runtime so they never appear as static refs.
static NSString *const kArbiterClientClassName = @"_UIKeyboardArbiterClient";
static NSString *const kEnabledSelectorName = @"enabled";
static NSString *const kSwizzleSelectorName = @"queue_keyboardChanged:onComplete:";
static NSString *const kSourceBundleIdKey = @"_sourceBundleIdentifier";

// Every class in the arbiter family that implements the destination-changed callback. On a cold
// start the initial dispatch may land on any of these, not only InputDestination.
static NSArray<NSString *> *ArbiterClientClassNames(void) {
  return @[
    @"_UIKeyboardArbiterClientInputDestination",
    @"_UIKeyboardArbiterClient",
    @"_UIKeyboardArbiterClientInputUIHost",
    @"_UIRemoteKeyboards",
    @"UIKeyboardCandidateViewState",
  ];
}

static os_unfair_lock sHookLock = OS_UNFAIR_LOCK_INIT;
static NSString *_Nullable sLastCapturedBundleId = nil;
static CFAbsoluteTime sLastCapturedAt = 0;
static NSMutableDictionary<NSString *, NSValue *> *sOriginalIMPs = nil; // class name -> original IMP
static BOOL sInstalled = NO;

static BOOL IsAcceptableBundleId(NSString *_Nullable bid) {
  if (bid.length == 0) return NO;
  if (![bid containsString:@"."]) return NO;
  if ([bid isEqualToString:@"<null>"] || [bid isEqualToString:@"(null)"]) return NO;
  // Reject our own app and its keyboard, and the Home Screen (not a return target). Real system
  // apps like com.apple.mobilesafari ARE valid hosts, so do NOT blanket-reject com.apple.* --
  // doing so made the cache fall back to the previous third-party host for every system app.
  if ([bid hasPrefix:@"app.sayboard"]) return NO;
  if ([bid isEqualToString:[NSBundle mainBundle].bundleIdentifier]) return NO;
  if ([bid isEqualToString:@"com.apple.springboard"]) return NO;
  return YES;
}

static void CommitHostBundleId(NSString *bid) {
  if (!IsAcceptableBundleId(bid)) return;
  CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
  os_unfair_lock_lock(&sHookLock);
  sLastCapturedBundleId = [bid copy];
  sLastCapturedAt = now;
  os_unfair_lock_unlock(&sHookLock);
}

// The bundle identifier lives on the `change` argument (arg1), not on `self`. Shared across all
// swizzled classes; the original IMP is looked up per receiver class.
static void SwizzledKeyboardChanged(id self, SEL _cmd, id change, id completion) {
  if (change) {
    @try {
      id value = [change valueForKey:kSourceBundleIdKey];
      if ([value isKindOfClass:[NSString class]]) {
        CommitHostBundleId((NSString *)value);
      }
    } @catch (__unused NSException *e) {
      // Swallow KVC failures so the original IMP still runs.
    }
  }

  // Find the original IMP for the receiver's class (walking up to a swizzled ancestor).
  IMP original = NULL;
  os_unfair_lock_lock(&sHookLock);
  for (Class c = object_getClass(self); c != Nil; c = class_getSuperclass(c)) {
    NSValue *v = sOriginalIMPs[NSStringFromClass(c)];
    if (v) { original = [v pointerValue]; break; }
  }
  os_unfair_lock_unlock(&sHookLock);
  if (original) {
    ((void (*)(id, SEL, id, id))original)(self, _cmd, change, completion);
  }
}

// iOS 26.4 gates the destination-changed dispatch on this class method; if it returns NO the
// swizzle above never fires. Force it YES in the keyboard process.
static BOOL AlwaysEnabledIMP(__unused id self, __unused SEL _cmd) {
  return YES;
}

@implementation KBHostArbiterHook

+ (void)load {
  if (@available(iOS 26.4, *)) {
    [self installHooks];
  }
}

+ (void)installHooks {
  os_unfair_lock_lock(&sHookLock);
  if (sInstalled) {
    os_unfair_lock_unlock(&sHookLock);
    return;
  }
  sInstalled = YES;
  sOriginalIMPs = [NSMutableDictionary dictionary];
  os_unfair_lock_unlock(&sHookLock);

  Class clientCls = NSClassFromString(kArbiterClientClassName);
  if (clientCls) {
    Method enabledMethod = class_getClassMethod(clientCls, NSSelectorFromString(kEnabledSelectorName));
    if (enabledMethod) {
      method_setImplementation(enabledMethod, (IMP)&AlwaysEnabledIMP);
    }
  }

  SEL sel = NSSelectorFromString(kSwizzleSelectorName);
  for (NSString *name in ArbiterClientClassNames()) {
    Class cls = NSClassFromString(name);
    if (!cls) continue;
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) continue;
    // Only swizzle a class that defines the method itself, so an inherited method shared with a
    // superclass is not installed twice.
    Method superMethod = class_getInstanceMethod(class_getSuperclass(cls), sel);
    if (superMethod == method) continue;
    IMP original = method_getImplementation(method);
    os_unfair_lock_lock(&sHookLock);
    sOriginalIMPs[name] = [NSValue valueWithPointer:original];
    os_unfair_lock_unlock(&sHookLock);
    method_setImplementation(method, (IMP)&SwizzledKeyboardChanged);
  }
}

+ (nullable NSString *)lastCapturedHostBundleId {
  os_unfair_lock_lock(&sHookLock);
  NSString *bid = [sLastCapturedBundleId copy];
  os_unfair_lock_unlock(&sHookLock);
  return IsAcceptableBundleId(bid) ? bid : nil;
}

+ (NSTimeInterval)lastCapturedAt {
  os_unfair_lock_lock(&sHookLock);
  CFAbsoluteTime at = sLastCapturedAt;
  os_unfair_lock_unlock(&sHookLock);
  return at;
}

+ (void)activeArbiterCheck {
  if (@available(iOS 26.4, *)) {
    // fall through
  } else {
    return;
  }
  Class cls = NSClassFromString(kArbiterClientClassName);
  if (!cls) return;
  SEL getter = NSSelectorFromString(@"automaticSharedArbiterClient");
  if (![cls respondsToSelector:getter]) return;
  id (*getMsg)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
  id client = getMsg(cls, getter);
  if (!client) return; // lazy init not complete yet; a later call will succeed
  SEL ping = NSSelectorFromString(@"checkConnection");
  if ([client respondsToSelector:ping]) {
    void (*pingMsg)(id, SEL) = (void (*)(id, SEL))objc_msgSend;
    pingMsg(client, ping);
  }
}

@end
