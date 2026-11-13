#import "AppNames.h"

@interface NSObject (Regitela_LSPrivate)
+ (id)defaultWorkspace;
- (NSArray *)allApplications;
- (NSArray *)allInstalledApplications;
- (NSString *)applicationIdentifier;
- (NSString *)bundleIdentifier;
- (NSString *)localizedName;
+ (id)applicationProxyForIdentifier:(NSString *)identifier;
- (NSURL *)bundleURL;
- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier allowPlaceholder:(BOOL)allowPlaceholder error:(NSError **)error;
- (NSURL *)URL;
@end

@interface UIImage (Regitela_Private)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end

static NSString *nameFromBundleURL(NSURL *bundleURL) {
    if (!bundleURL) return nil;
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfURL:[bundleURL URLByAppendingPathComponent:@"Info.plist"]];
    NSString *name = info[@"CFBundleDisplayName"];
    if (name.length == 0) name = info[@"CFBundleName"];
    return name.length > 0 ? name : nil;
}

NSString *copyDisplayNameForBundleID(NSString *bundleID, NSString **method) {
    if (bundleID.length == 0) return nil;

    Class recordClass = NSClassFromString(@"LSApplicationRecord");
    if ([recordClass instancesRespondToSelector:@selector(initWithBundleIdentifier:allowPlaceholder:error:)]) {
        NSError *error = nil;
        id record = [[recordClass alloc] initWithBundleIdentifier:bundleID allowPlaceholder:NO error:&error];
        if (record) {
            NSString *name = [record respondsToSelector:@selector(localizedName)] ? [record localizedName] : nil;
            if (name.length > 0) {
                if (method) *method = @"LSApplicationRecord";
                return name;
            }
            NSURL *url = [record respondsToSelector:@selector(URL)] ? [record URL] : nil;
            name = nameFromBundleURL(url);
            if (name) {
                if (method) *method = @"LSApplicationRecord+Info.plist";
                return name;
            }
        }
    }

    Class proxyClass = NSClassFromString(@"LSApplicationProxy");
    if ([proxyClass respondsToSelector:@selector(applicationProxyForIdentifier:)]) {
        id proxy = [proxyClass applicationProxyForIdentifier:bundleID];
        if (proxy) {
            NSString *name = [proxy respondsToSelector:@selector(localizedName)] ? [proxy localizedName] : nil;
            if (name.length > 0) {
                if (method) *method = @"LSApplicationProxy";
                return name;
            }
            NSURL *url = [proxy respondsToSelector:@selector(bundleURL)] ? [proxy bundleURL] : nil;
            name = nameFromBundleURL(url);
            if (name) {
                if (method) *method = @"LSApplicationProxy+Info.plist";
                return name;
            }
        }
    }

    return nil;
}

NSDictionary<NSString *, NSString *> *copyBundleDisplayNames(void) {
    NSMutableDictionary<NSString *, NSString *> *map = [NSMutableDictionary dictionary];

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (![workspaceClass respondsToSelector:@selector(defaultWorkspace)]) return map;
    id workspace = [workspaceClass defaultWorkspace];
    if (!workspace) return map;

    NSArray *apps = nil;
    if ([workspace respondsToSelector:@selector(allApplications)]) {
        apps = [workspace allApplications];
    }
    if (apps.count == 0 && [workspace respondsToSelector:@selector(allInstalledApplications)]) {
        apps = [workspace allInstalledApplications];
    }

    for (id proxy in apps) {
        NSString *bundleID = nil;
        if ([proxy respondsToSelector:@selector(applicationIdentifier)]) {
            bundleID = [proxy applicationIdentifier];
        } else if ([proxy respondsToSelector:@selector(bundleIdentifier)]) {
            bundleID = [proxy bundleIdentifier];
        }
        NSString *name = [proxy respondsToSelector:@selector(localizedName)] ? [proxy localizedName] : nil;
        if (bundleID.length > 0 && name.length > 0) map[bundleID] = name;
    }
    return map;
}

UIImage *copyIconForBundleID(NSString *bundleID) {
    if (bundleID.length == 0) return nil;
    if (![UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) return nil;
    return [UIImage _applicationIconImageForBundleIdentifier:bundleID format:2 scale:UITraitCollection.currentTraitCollection.displayScale];
}
