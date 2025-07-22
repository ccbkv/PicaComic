#include <string.h>

#include "bridge.h"
#include "sqlite3.h"

#define DART_FD(file) (((dart_vfs_file *)(file))->dart_fd)

#ifdef SQLITE_ENABLE_VFSTRACE
// When this is enabled, assume that `vfstrace_register` exists
// See https://www.sqlite.org/src/doc/trunk/src/test_vfstrace.c

extern int vfstrace_register(
    const char *zTraceName,             // Name of the newly constructed VFS
    const char *zOldVfsName,            // Name of the underlying VFS
    int (*xOut)(const char *, void *),  // Output routine.  ex: fputs
    void *pOutArg,                      // 2nd argument to xOut.  ex: stderr
    int makeDefault                     // Make the new VFS the default
);
#endif

typedef struct {
  struct sqlite3_io_methods *pMethods;
  int dart_fd;
} dart_vfs_file;

// Interfaces we want to access in Dart
SQLITE_API void *dart_sqlite3_malloc(size_t size) { return malloc(size); }

SQLITE_API void dart_sqlite3_free(void *ptr) { return free(ptr); }

static int dartvfs_trace_log1(const char *msg, void *unused) {
  dartLogError(msg);
  return SQLITE_OK;
}

int dartvfs_close(sqlite3_file *file) { return xClose(DART_FD(file)); }

int dartvfs_read(sqlite3_file *file, void *buf, int iAmt, sqlite3_int64 iOfst) {
  return xRead(DART_FD(file), buf, iAmt, iOfst);
}

int dartvfs_write(sqlite3_file *file, const void *buf, int iAmt,
                  sqlite3_int64 iOfst) {
  return xWrite(DART_FD(file), buf, iAmt, iOfst);
}

int dartvfs_truncate(sqlite3_file *file, sqlite3_int64 size) {
  return xTruncate(DART_FD(file), size);
}

int dartvfs_sync(sqlite3_file *file, int flags) {
  return xSync(DART_FD(file), flags);
}

int dartvfs_fileSize(sqlite3_file *file, sqlite3_int64 *pSize) {
  int size32;
  int rc = xFileSize(DART_FD(file), &size32);
  *pSize = (sqlite3_int64)size32;
  return rc;
}

int dartvfs_lock(sqlite3_file *file, int i) { return xLock(DART_FD(file), i); }

int dartvfs_unlock(sqlite3_file *file, int i) {
  return xUnlock(DART_FD(file), i);
}

int dartvfs_checkReservedLock(sqlite3_file *file, int *pResOut) {
  return xCheckReservedLock(DART_FD(file), pResOut);
}

int dartvfs_fileControl(sqlite3_file *file, int op, void *pArg) {
  // "VFS implementations should return SQLITE_NOTFOUND for file control opcodes
  // that they do not recognize". Well, we don't recognize any.
  return SQLITE_NOTFOUND;
}

int dartvfs_deviceCharacteristics(sqlite3_file *file) {
  return xDeviceCharacteristics(DART_FD(file));
}

int dartvfs_sectorSize(sqlite3_file *file) {
  // This is also the value of SQLITE_DEFAULT_SECTOR_SIZE, which would be picked
  // if this function didn't exist. We need this method because vfstrace does
  // not support null callbacks.
  return 4096;
}

static int dartvfs_open(sqlite3_vfs *vfs, sqlite3_filename zName,
                        sqlite3_file *file, int flags, int *pOutFlags) {
  dart_vfs_file *dartFile = (dart_vfs_file *)file;
  memset(dartFile, 0, sizeof(dart_vfs_file));
  dartFile->dart_fd = -1;

  static sqlite3_io_methods methods = {
      .iVersion = 1,
      .xClose = &dartvfs_close,
      .xRead = &dartvfs_read,
      .xWrite = &dartvfs_write,
      .xTruncate = &dartvfs_truncate,
      .xSync = &dartvfs_sync,
      .xFileSize = &dartvfs_fileSize,
      .xLock = &dartvfs_lock,
      .xUnlock = &dartvfs_unlock,
      .xCheckReservedLock = &dartvfs_checkReservedLock,
      .xFileControl = &dartvfs_fileControl,
      .xDeviceCharacteristics = &dartvfs_deviceCharacteristics,
#ifdef SQLITE_ENABLE_VFSTRACE
      .xSectorSize = &dartvfs_sectorSize
#else
      .xSectorSize = NULL
#endif
  };

  int *dartFileId = &dartFile->dart_fd;

  // The xOpen call will also set the dart_fd field.
  int rc = xOpen((int)vfs->pAppData, zName, dartFileId, flags, pOutFlags);

  if (*dartFileId != -1) {
    // sqlite3 will call xClose() even if this open call returns an error if
    // methods are set. So, we only provide the methods if a file has actually
    // been opened.
    dartFile->pMethods = &methods;
  }

  return rc;
}

static int dartvfs_delete(sqlite3_vfs *vfs, const char *zName, int syncDir) {
  return xDelete((int)vfs->pAppData, zName, syncDir);
}

static int dartvfs_access(sqlite3_vfs *vfs, const char *zName, int flags,
                          int *pResOut) {
  return xAccess((int)vfs->pAppData, zName, flags, pResOut);
}

static int dartvfs_fullPathname(sqlite3_vfs *vfs, const char *zName, int nOut,
                                char *zOut) {
  return xFullPathname((int)vfs->pAppData, zName, nOut, zOut);
}

static int dartvfs_randomness(sqlite3_vfs *vfs, int nByte, char *zOut) {
  return xRandomness((int)vfs->pAppData, nByte, zOut);
}

static int dartvfs_sleep(sqlite3_vfs *vfs, int microseconds) {
  return xSleep((int)vfs->pAppData, microseconds);
}

static int dartvfs_currentTimeInt64(sqlite3_vfs *vfs, sqlite3_int64 *timeOut) {
  int64_t milliseconds;
  int rc = xCurrentTimeInt64((int)vfs->pAppData, &milliseconds);

  // https://github.com/sqlite/sqlite/blob/8ee75f7c3ac1456b8d941781857be27bfddb57d6/src/os_unix.c#L6757
  static const int64_t unixEpoch = 24405875 * (int64_t)8640000;
  *timeOut = unixEpoch + milliseconds;
  return SQLITE_OK;
}

SQLITE_API sqlite3_vfs *dart_sqlite3_register_vfs(const char *name, int dartId,
                                                  int makeDefault) {
  sqlite3_vfs *vfs = calloc(1, sizeof(sqlite3_vfs));
  vfs->iVersion = 2;
  vfs->szOsFile = sizeof(dart_vfs_file);
  vfs->mxPathname = 1024;
  vfs->zName = name;
  vfs->pAppData = (void *)dartId;
  vfs->xOpen = &dartvfs_open;
  vfs->xDelete = &dartvfs_delete;
  vfs->xAccess = &dartvfs_access;
  vfs->xFullPathname = &dartvfs_fullPathname;
  vfs->xRandomness = &dartvfs_randomness;
  vfs->xSleep = &dartvfs_sleep;
  vfs->xCurrentTimeInt64 = &dartvfs_currentTimeInt64;

#ifdef SQLITE_ENABLE_VFSTRACE
  sqlite3_vfs_register(vfs, 0);

  static const char *prefix = "trace_";
  static const int prefixLength = 6;
  char *traceName = malloc(strlen(name) + prefixLength);
  strcpy(traceName, prefix);
  strcpy(&traceName[prefixLength], name);

  vfstrace_register(traceName, name, &dartvfs_trace_log1, NULL, makeDefault);
#else
  // Just register the VFS as is.
  sqlite3_vfs_register(vfs, makeDefault);
#endif
  return vfs;
}

SQLITE_API int dart_sqlite3_create_scalar_function(sqlite3 *db,
                                                   const char *zFunctionName,
                                                   int nArg, int eTextRep,
                                                   int id) {
  return sqlite3_create_function_v2(db, zFunctionName, nArg, eTextRep,
                                    (void *)id, &dartXFunc, NULL, NULL,
                                    &dartForgetAboutFunction);
}

SQLITE_API int dart_sqlite3_create_aggregate_function(sqlite3 *db,
                                                      const char *zFunctionName,
                                                      int nArg, int eTextRep,
                                                      int id) {
  return sqlite3_create_function_v2(db, zFunctionName, nArg, eTextRep,
                                    (void *)id, NULL, &dartXStep, &dartXFinal,
                                    &dartForgetAboutFunction);
}

SQLITE_API int dart_sqlite3_create_window_function(sqlite3 *db,
                                                   const char *zFunctionName,
                                                   int nArg, int eTextRep,
                                                   int id) {
  return sqlite3_create_window_function(
      db, zFunctionName, nArg, eTextRep, (void *)id, &dartXStep, &dartXFinal,
      &dartXValue, &dartXInverse, &dartForgetAboutFunction);
}

SQLITE_API void dart_sqlite3_updates(sqlite3 *db, int id) {
  sqlite3_update_hook(db, id >= 0 ? &dartUpdateHook : NULL, (void *)id);
}

SQLITE_API int dart_sqlite3_create_collation(sqlite3 *db, const char *zName,
                                             int eTextRep, int id) {
  return sqlite3_create_collation_v2(db, zName, eTextRep, (void *)id,
                                     &dartXCompare, &dartForgetAboutFunction);
}

SQLITE_API int dart_sqlite3_db_config_int(sqlite3 *db, int op, int arg) {
  return sqlite3_db_config(db, op, arg);
}
