#ifndef Gestalt_h
#define Gestalt_h

#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>

// libMobileGestalt (linked with -lMobileGestalt). Takes the plain or the hashed key name.
bool MGGetBoolAnswer(CFStringRef property);

#endif /* Gestalt_h */
