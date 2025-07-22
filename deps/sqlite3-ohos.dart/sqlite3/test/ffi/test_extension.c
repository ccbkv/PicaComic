#include <sqlite3ext.h>
SQLITE_EXTENSION_INIT1

static void my_function(sqlite3_context *context, int argc,
                        sqlite3_value **argv) {
  sqlite3_result_text(context, "my custom extension", -1, SQLITE_STATIC);
}

#ifdef _WIN32
__declspec(dllexport)
#endif
    int sqlite3_myextension_init(sqlite3 *db, char **pzErrMsg,
                                 const sqlite3_api_routines *pApi) {
  int rc = SQLITE_OK;
  SQLITE_EXTENSION_INIT2(pApi);

  rc = sqlite3_create_function(
      db, "my_function", 0,
      SQLITE_UTF8 | SQLITE_INNOCUOUS | SQLITE_DETERMINISTIC, 0, my_function, 0,
      0);

  return rc;
}
