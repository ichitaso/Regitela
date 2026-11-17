#import "KernelBackend.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>

// Forward-declare to avoid pulling in the exploit's logging printf macro.
#if __has_include("kexploit/offsets.h")
#define REGITELA_HAVE_KERNEL 1
int kexploit_opa334(void);
int patch_sandbox_ext(void); // 0 = ok
#else
#define REGITELA_HAVE_KERNEL 0
#endif

// A18 / A18 Pro / M4: unstable (possible panic), so decline them.
#ifndef CPUFAMILY_ARM_TUPAI
#define CPUFAMILY_ARM_TUPAI  0x204526d0 // A18
#endif
#ifndef CPUFAMILY_ARM_TAHITI
#define CPUFAMILY_ARM_TAHITI 0x75d4acb9 // A18 Pro
#endif
#ifndef CPUFAMILY_ARM_DONAN
#define CPUFAMILY_ARM_DONAN  0x6f5129ac // M4
#endif

// /var/jb outlives a reboot, so look for the jailbreak's injected libraries
static bool regitela_jailbroken(void) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && (strstr(name, "systemhook.dylib") || strstr(name, "/var/jb/") || strstr(name, "/procursus/"))) return true;
    }
    return false;
}

static bool kernel_supported(void) {
#if !REGITELA_HAVE_KERNEL
    return false;
#else
    // iOS 17.0 up to (not including) 26.1.
    NSString *v = [[UIDevice currentDevice] systemVersion];
    if ([v compare:@"17.0" options:NSNumericSearch] == NSOrderedAscending) return false;
    if ([v compare:@"26.1" options:NSNumericSearch] != NSOrderedAscending) return false;

    cpu_subtype_t fam = 0;
    size_t sz = sizeof(fam);
    sysctlbyname("hw.cpufamily", &fam, &sz, NULL, 0);
    if (fam == CPUFAMILY_ARM_TUPAI || fam == CPUFAMILY_ARM_TAHITI || fam == CPUFAMILY_ARM_DONAN) {
        return false;
    }
    return true;
#endif
}

// Running the exploit on top of a jailbreak can panic or hang the device.
bool regitela_kernel_available(void) {
    return kernel_supported() && !regitela_jailbroken();
}

bool regitela_kernel_blocked_by_jailbreak(void) {
    return kernel_supported() && regitela_jailbroken();
}

#if REGITELA_HAVE_KERNEL
static bool g_attempted = false;
static bool g_unlocked = false;
#endif

bool regitela_kernel_unlock(void) {
#if !REGITELA_HAVE_KERNEL
    return false;
#else
    if (g_attempted) return g_unlocked;
    g_attempted = true;

    // kexploit_opa334() runs offsets_init(), which exits on an unsupported version.
    if (!regitela_kernel_available()) return false;

    kexploit_opa334();
    g_unlocked = (patch_sandbox_ext() == 0);
    return g_unlocked;
#endif
}

bool regitela_kernel_is_unlocked(void) {
#if !REGITELA_HAVE_KERNEL
    return false;
#else
    return g_unlocked;
#endif
}
