#import <CoreFoundation/CoreFoundation.h>

// Minimal Foundation stubs for syntax checks

typedef signed long NSInteger;
typedef unsigned long NSUInteger;
typedef signed char BOOL;
#define YES ((BOOL)1)
#define NO  ((BOOL)0)

@class NSString, NSArray, NSDictionary, NSNotificationCenter, NSBundle;

@interface NSObject
- (id)init;
- (void)dealloc;
+ (id)alloc;
@interface NSString : NSObject
- (NSUInteger)length;
@end

@interface NSArray : NSObject
@end

@interface NSDictionary : NSObject
@end

@interface NSNotificationCenter : NSObject
- (void)removeObserver:(id)anObserver;
@end

@interface NSBundle : NSObject
- (NSDictionary *)infoDictionary;
@end
