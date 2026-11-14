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

#ifndef SandboxEscape_h
#define SandboxEscape_h

#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stdbool.h>

int64_t worse_query(NSString *path, NSString *group, bool alt_flags, bool create_dir);
int64_t geod_query(NSString *path);
void geod_release(int64_t handle);
NSString * _Nullable geod_last_path(void);
void worse_query_release(int64_t handle);
NSString * _Nullable worse_query_group(void);
NSString * _Nullable worse_query_last_extension_class(void);

#endif /* SandboxEscape_h */
