#ifndef Archive_h
#define Archive_h

#import <Foundation/Foundation.h>

// Both return nil on success, or an error message.
NSString * _Nullable createZip(NSString * _Nonnull sourcePath, NSString * _Nonnull zipPath);

NSString * _Nullable extractArchive(NSString * _Nonnull archivePath, NSString * _Nonnull destinationPath);

#endif /* Archive_h */
