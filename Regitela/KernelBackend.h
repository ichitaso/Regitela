#ifndef KernelBackend_h
#define KernelBackend_h

#include <stdbool.h>

// C bridge to the vendored darksword kernel r/w backend (used with permission);
// both calls stub to false when the exploit isn't compiled in.

// True when the exploit is compiled in and the device/OS is supported.
bool regitela_kernel_available(void);

// Unlock /private/var r/w for the process lifetime; idempotent, cached.
bool regitela_kernel_unlock(void);

#endif /* KernelBackend_h */
