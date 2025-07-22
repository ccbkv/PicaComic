#include <stdint.h>

typedef struct sqlite3_char sqlite3_char;
typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;
typedef struct sqlite3_backup sqlite3_backup;
typedef struct sqlite3_api_routines sqlite3_api_routines;

sqlite3_char *sqlite3_temp_directory;

int sqlite3_open_v2(sqlite3_char *filename, sqlite3 **ppDb, int flags,
                    sqlite3_char *zVfs);
int sqlite3_close_v2(sqlite3 *db);
sqlite3_char *sqlite3_db_filename(sqlite3 *db, sqlite3_char *zDbName);
const sqlite3_char *sqlite3_compileoption_get(int N);

// Error handling
int sqlite3_extended_result_codes(sqlite3 *db, int onoff);
int sqlite3_extended_errcode(sqlite3 *db);
sqlite3_char *sqlite3_errmsg(sqlite3 *db);
sqlite3_char *sqlite3_errstr(int code);
void sqlite3_free(void *ptr);

// Versions
sqlite3_char *sqlite3_libversion();
sqlite3_char *sqlite3_sourceid();
int sqlite3_libversion_number();

// Database
int64_t sqlite3_last_insert_rowid(sqlite3 *db);
int sqlite3_changes(sqlite3 *db);
int sqlite3_exec(sqlite3 *db, sqlite3_char *sql, void *callback, void *argToCb,
                 sqlite3_char **errorOut);
void *sqlite3_update_hook(sqlite3 *,
                          void (*)(void *, int, sqlite3_char const *,
                                   sqlite3_char const *, int64_t),
                          void *);
int sqlite3_get_autocommit(sqlite3 *db);

// Statements
int sqlite3_prepare_v2(sqlite3 *db, const sqlite3_char *zSql, int nByte,
                       sqlite3_stmt **ppStmt, const sqlite3_char **pzTail);
int sqlite3_prepare_v3(sqlite3 *db, const sqlite3_char *zSql, int nByte,
                       unsigned int prepFlags, sqlite3_stmt **ppStmt,
                       const sqlite3_char **pzTail);
int sqlite3_finalize(sqlite3_stmt *pStmt);
int sqlite3_step(sqlite3_stmt *pStmt);
int sqlite3_reset(sqlite3_stmt *pStmt);
int sqlite3_stmt_isexplain(sqlite3_stmt *pStmt);
int sqlite3_stmt_readonly(sqlite3_stmt *pStmt);

int sqlite3_column_count(sqlite3_stmt *pStmt);
int sqlite3_bind_parameter_count(sqlite3_stmt *pStmt);
int sqlite3_bind_parameter_index(sqlite3_stmt *, sqlite3_char *zName);
sqlite3_char *sqlite3_column_name(sqlite3_stmt *pStmt, int N);
sqlite3_char *sqlite3_column_table_name(sqlite3_stmt *pStmt, int N);

int sqlite3_bind_blob64(sqlite3_stmt *pStmt, int index, void *data,
                        uint64_t length, void *destructor);
int sqlite3_bind_double(sqlite3_stmt *pStmt, int index, double data);
int sqlite3_bind_int64(sqlite3_stmt *pStmt, int index, int64_t data);
int sqlite3_bind_null(sqlite3_stmt *pStmt, int index);
int sqlite3_bind_text(sqlite3_stmt *pStmt, int index, sqlite3_char *data,
                      int length, void *destructor);

void *sqlite3_column_blob(sqlite3_stmt *pStmt, int iCol);
double sqlite3_column_double(sqlite3_stmt *pStmt, int iCol);
int64_t sqlite3_column_int64(sqlite3_stmt *pStmt, int iCol);
sqlite3_char *sqlite3_column_text(sqlite3_stmt *pStmt, int iCol);
int sqlite3_column_bytes(sqlite3_stmt *pStmt, int iCol);
int sqlite3_column_type(sqlite3_stmt *pStmt, int iCol);

// Values

typedef struct sqlite3_value sqlite3_value;

void *sqlite3_value_blob(sqlite3_value *value);
double sqlite3_value_double(sqlite3_value *value);
int sqlite3_value_type(sqlite3_value *value);
int64_t sqlite3_value_int64(sqlite3_value *value);
sqlite3_char *sqlite3_value_text(sqlite3_value *value);
int sqlite3_value_bytes(sqlite3_value *value);

// Functions

typedef struct sqlite3_context sqlite3_context;

int sqlite3_create_function_v2(
    sqlite3 *db, sqlite3_char *zFunctionName, int nArg, int eTextRep,
    void *pApp, void (*xFunc)(sqlite3_context *, int, sqlite3_value **),
    void (*xStep)(sqlite3_context *, int, sqlite3_value **),
    void (*xFinal)(sqlite3_context *), void (*xDestroy)(void *));
int sqlite3_create_window_function(
    sqlite3 *db, sqlite3_char *zFunctionName, int nArg, int eTextRep,
    void *pApp, void (*xStep)(sqlite3_context *, int, sqlite3_value **),
    void (*xFinal)(sqlite3_context *), void (*xValue)(sqlite3_context *),

    void (*xInverse)(sqlite3_context *, int, sqlite3_value **),
    void (*xDestroy)(void *));

void *sqlite3_aggregate_context(sqlite3_context *ctx, int nBytes);

void *sqlite3_user_data(sqlite3_context *ctx);
void sqlite3_result_blob64(sqlite3_context *ctx, void *data, uint64_t length,
                           void *destructor);
void sqlite3_result_double(sqlite3_context *ctx, double result);
void sqlite3_result_error(sqlite3_context *ctx, sqlite3_char *msg, int length);
void sqlite3_result_int64(sqlite3_context *ctx, int64_t result);
void sqlite3_result_null(sqlite3_context *ctx);
void sqlite3_result_text(sqlite3_context *ctx, sqlite3_char *data, int length,
                         void *destructor);

// Collations
int sqlite3_create_collation_v2(sqlite3 *, sqlite3_char *zName, int eTextRep,
                                void *pArg,
                                int (*xCompare)(void *, int, const void *, int,
                                                const void *),
                                void (*xDestroy)(void *));

// Backup
sqlite3_backup *sqlite3_backup_init(sqlite3 *pDestDb, sqlite3_char *zDestDb,
                                    sqlite3 *pSrcDb, sqlite3_char *zSrcDb);
int sqlite3_backup_step(sqlite3_backup *p, int nPage);
int sqlite3_backup_finish(sqlite3_backup *p);
int sqlite3_backup_remaining(sqlite3_backup *p);
int sqlite3_backup_pagecount(sqlite3_backup *p);

// Extensions
int sqlite3_auto_extension(void *xEntryPoint);

// Database configuration
int sqlite3_db_config(sqlite3 *db, int op, ...);
