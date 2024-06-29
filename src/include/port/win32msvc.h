#ifndef WIN32MSVC_H
#define WIN32MSVC_H

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
#ifdef PGMODULEEXPORT
#undef PGMODULEEXPORT
#endif
#ifdef PG_MODULE_MAGIC
#undef PG_MODULE_MAGIC
#endif
#ifdef PG_FUNCTION_INFO_V1
#undef PG_FUNCTION_INFO_V1
#endif

#define PGMODULEEXPORT __declspec (dllexport)

#define PG_MODULE_MAGIC \
PGMODULEEXPORT const Pg_magic_struct * \
PG_MAGIC_FUNCTION_NAME(void) \
{ \
	static const Pg_magic_struct Pg_magic_data = PG_MODULE_MAGIC_DATA; \
	return &Pg_magic_data; \
} \
extern int no_such_variable

#define PG_FUNCTION_INFO_V1(funcname) \
PGMODULEEXPORT const Pg_finfo_record *  \
CppConcat(pg_finfo_,funcname) (void) \
{ \
	static const Pg_finfo_record my_finfo = { 1 }; \
	return &my_finfo; \
} \
extern int no_such_variable

 /*--------------- END REDEFINITION OF PG MACROS -------------------*/

#endif

#endif //WIN32MSVC_H