#ifndef WIN32POSTGRES_H
#define WIN32POSTGRES_H

#include "postgres.h"

/// per https://stackoverflow.com/questions/3694723/error-c3861-strcasecmp-identifier-not-found-in-visual-studio-2008
#ifdef _MSC_VER

//not #if defined(_WIN32) || defined(_WIN64) because we have strncasecmp in mingw

/*--------------- BEGIN REDEFINITION OF PG MACROS -------------------
 *
 * These rewritten versions of PG_MODULE_MAGIC and PG_FUNCTION_INFO_V1
 * declare the module functions as __declspec(dllexport) when building
 * a module. They also provide PGMODULEEXPORT for exporting functions
 * in user DLLs.
 */

#ifdef DECIMAL
#undef DECIMAL
#endif

#ifdef DELETE
#undef DELETE
#endif

#ifdef IN
#undef IN
#endif

#ifdef OPTIONAL
#undef OPTIONAL
#endif


#ifndef getpid
#define getpid _getpid
#endif

#ifndef strncasecmp
#define strncasecmp _strnicmp
#endif

#ifndef strcasecmp
#define strcasecmp _stricmp
#endif

#ifndef strtol
#define strtoint strtol
#endif

/*--------------- END REDEFINITION OF PG MACROS -------------------*/

#endif

#endif //WIN32POSTGRES_H
