#import "ObjCExceptionCatcher.h"

@implementation ObjCExceptionCatcher

+ (BOOL)catchExceptionInBlock:(void (NS_NOESCAPE ^)(void))block error:(NSError **)error {
  @try {
    block();
    return YES;
  } @catch (NSException *exception) {
    if (error) {
      *error = [NSError errorWithDomain:@"ObjCExceptionCatcher"
                                   code:1
                               userInfo:@{
                                 NSLocalizedDescriptionKey: exception.reason ?: @"Unknown Objective-C exception",
                                 @"NSExceptionName": exception.name
                               }];
    }
    return NO;
  }
}

@end
