#ifndef AppNames_h
#define AppNames_h

#import <Foundation/Foundation.h>

NSDictionary<NSString *, NSString *> *copyBundleDisplayNames(void);

NSString * _Nullable copyDisplayNameForBundleID(NSString * _Nonnull bundleID, NSString * _Nullable * _Nullable method);

#endif /* AppNames_h */
