#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include "bridge.h"
#include "sqlite3.h"

int sqlite3_os_init(void) { return SQLITE_OK; }

int sqlite3_os_end(void) { return SQLITE_OK; }
