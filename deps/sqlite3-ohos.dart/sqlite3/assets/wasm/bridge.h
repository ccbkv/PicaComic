#include <stdint.h>
#include <stdlib.h>

#include "sqlite3.h"

#define import_dart(name) \
  __attribute__((import_module("dart"), import_name(name)))

// Defines functions implemented in Dart. These functions are imported into
// the wasm module.
import_dart("error_log") extern void dartLogError(const char *msg);
import_dart("xOpen") extern int xOpen(int vfs, sqlite3_filename zName,
                                      int *dartFdPtr, int flags,
                                      int *pOutFlags);
import_dart("xDelete") extern int xDelete(int vfs, const char *zName,
                                          int syncDir);
import_dart("xAccess") extern int xAccess(int vfs, const char *zName, int flags,
                                          int *pResOut);
import_dart("xFullPathname") extern int xFullPathname(int vfs,
                                                      const char *zName,
                                                      int nOut, char *zOut);
import_dart("xRandomness") extern int xRandomness(int vfs, int nByte,
                                                  char *zOut);
import_dart("xSleep") extern int xSleep(int vfs, int microseconds);
import_dart("xCurrentTimeInt64") extern int xCurrentTimeInt64(int vfs,
                                                              int64_t *target);

import_dart("xClose") extern int xClose(int file);
import_dart("xRead") extern int xRead(int, void *, int iAmt,
                                      sqlite3_int64 iOfst);
import_dart("xWrite") extern int xWrite(int, const void *, int iAmt,
                                        sqlite3_int64 iOfst);
import_dart("xTruncate") extern int xTruncate(int, sqlite3_int64 size);
import_dart("xSync") extern int xSync(int, int flags);
import_dart("xFileSize") extern int xFileSize(int, int *pSize);
import_dart("xLock") extern int xLock(int, int);
import_dart("xUnlock") extern int xUnlock(int, int);
import_dart("xCheckReservedLock") extern int xCheckReservedLock(int,
                                                                int *pResOut);
import_dart("xDeviceCharacteristics") extern int xDeviceCharacteristics(int);

import_dart("function_xFunc") extern void dartXFunc(sqlite3_context *ctx,
                                                    int nArgs,
                                                    sqlite3_value **value);
import_dart("function_xStep") extern void dartXStep(sqlite3_context *ctx,
                                                    int nArgs,
                                                    sqlite3_value **value);
import_dart("function_xInverse") extern void dartXInverse(
    sqlite3_context *ctx, int nArgs, sqlite3_value **value);
import_dart("function_xFinal") extern void dartXFinal(sqlite3_context *ctx);
import_dart("function_xValue") extern void dartXValue(sqlite3_context *ctx);
import_dart("function_forget") extern void dartForgetAboutFunction(void *ptr);
import_dart("function_hook") extern void dartUpdateHook(void *id, int kind,
                                                        const char *db,
                                                        const char *table,
                                                        sqlite3_int64 rowid);
import_dart("function_compare") extern int dartXCompare(void *id, int lengthA,
                                                        const void *a,
                                                        int lengthB,
                                                        const void *b);
