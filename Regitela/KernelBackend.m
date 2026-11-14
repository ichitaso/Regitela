#import "KernelBackend.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <sys/sysctl.h>

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

bool regitela_kernel_available(void) {
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
