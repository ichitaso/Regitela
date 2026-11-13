#ifndef AppNames_h
#define AppNames_h

#import <UIKit/UIKit.h>

NSDictionary<NSString *, NSString *> *copyBundleDisplayNames(void);

NSString * _Nullable copyDisplayNameForBundleID(NSString * _Nonnull bundleID, NSString * _Nullable * _Nullable method);

UIImage * _Nullable copyIconForBundleID(NSString * _Nonnull bundleID);

#endif /* AppNames_h */
