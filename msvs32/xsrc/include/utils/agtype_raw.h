/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

/*
 * This module provides functions for directly building agtype
 * without using agtype_value.
 */

#ifndef AG_AGTYPE_RAW_H
#define AG_AGTYPE_RAW_H

#include "port/win32postgres.h"
#include "utils/agtype.h"
#include "utils/agtype_ext.h"
#include "utils/agtype_parser.h"

/*
 * We declare the agtype_build_state here, and in this way, so that it may be
 * used elsewhere. However, we keep the contents private by defining it in
 * agtype_raw.c
 */
typedef struct agtype_build_state agtype_build_state;

agtype_build_state *init_agtype_build_state(uint32 size, uint32 header_flag);
agtype *build_agtype(agtype_build_state *bstate);
void pfree_agtype_build_state(agtype_build_state *bstate);

void write_string(agtype_build_state *bstate, char *str);
void write_graphid(agtype_build_state *bstate, graphid graphid);
void write_container(agtype_build_state *bstate, agtype *agtype);
void write_extended(agtype_build_state *bstate, agtype *val, uint32 header);
static int clock_gettime(int, struct timespec* tv);
static inline Datum agtype_from_cstring(char* str, int len);
static inline agtype_value* agtype_value_from_cstring(char* str, int len);
static void agtype_in_agtype_annotation(void* pstate, char* annotation);
static void agtype_in_object_start(void* pstate);
static void agtype_in_object_end(void* pstate);
static void agtype_in_array_start(void* pstate);
static void agtype_in_array_end(void* pstate);
static void agtype_in_object_field_start(void* pstate, char* fname,
    bool isnull);
static void agtype_put_escaped_value(StringInfo out, agtype_value* scalar_val);
static void escape_agtype(StringInfo buf, const char* str);
static void agtype_in_scalar(void* pstate, char* token,
    agtype_token_type tokentype,
    char* annotation);
static void agtype_categorize_type(Oid typoid, agt_type_category* tcategory,
    Oid* outfuncoid);
static void composite_to_agtype(Datum composite, agtype_in_state* result);
static void array_dim_to_agtype(agtype_in_state* result, int dim, int ndims,
    int* dims, Datum* vals, bool* nulls,
    int* valcount, agt_type_category tcategory,
    Oid outfuncoid);
static void array_to_agtype_internal(Datum array, agtype_in_state* result);
static void datum_to_agtype(Datum val, bool is_null, agtype_in_state* result,
    agt_type_category tcategory, Oid outfuncoid,
    bool key_scalar);
static char* agtype_to_cstring_worker(StringInfo out, agtype_container* in,
    int estimated_len, bool indent);
static text* agtype_value_to_text(agtype_value* scalar_val,
    bool err_not_scalar);
static void add_indent(StringInfo out, bool indent, int level);
static void cannot_cast_agtype_value(enum agtype_value_type type,
    const char* sqltype);
static bool agtype_extract_scalar(agtype_container* agtc, agtype_value* res);
static agtype_value* execute_array_access_operator(agtype* array,
    agtype_value* array_value,
    agtype* array_index);
static agtype_value* execute_array_access_operator_internal(agtype* array,
    agtype_value* array_value,
    int64 array_index);
static agtype_value* execute_map_access_operator(agtype* map,
    agtype_value* map_value,
    agtype* key);
static agtype_value* execute_map_access_operator_internal(agtype* map,
    agtype_value* map_value,
    char* key,
    int key_len);
static Datum agtype_object_field_impl(FunctionCallInfo fcinfo,
    agtype* agtype_in,
    char* key, int key_len, bool as_text);
static Datum agtype_array_element_impl(FunctionCallInfo fcinfo,
    agtype* agtype_in, int element,
    bool as_text);
static Datum process_access_operator_result(FunctionCallInfo fcinfo,
    agtype_value* agtv,
    bool as_text);
/* typecast functions */
static void agtype_typecast_object(agtype_in_state* state, char* annotation);
static void agtype_typecast_array(agtype_in_state* state, char* annotation);
/* validation functions */
static bool is_object_vertex(agtype_value* agtv);
static bool is_object_edge(agtype_value* agtv);
static bool is_array_path(agtype_value* agtv);
/* graph entity retrieval */
static Datum get_vertex(const char* graph, const char* vertex_label,
    int64 graphid);
static char* get_label_name(const char* graph_name, graphid element_graphid);
static float8 get_float_compatible_arg(Datum arg, Oid type, char* funcname,
    bool* is_null);
static Numeric get_numeric_compatible_arg(Datum arg, Oid type, char* funcname,
    bool* is_null,
    enum agtype_value_type* ag_type);
static int64 get_int64_from_int_datums(Datum d, Oid type, char* funcname,
    bool* is_agnull);
static agtype_iterator* get_next_object_key(agtype_iterator* it,
    agtype_container* agtc,
    agtype_value* key);
static int extract_variadic_args_min(FunctionCallInfo fcinfo,
    int variadic_start, bool convert_unknown,
    Datum** args, Oid** types, bool** nulls,
    int min_num_args);
static agtype_value* agtype_build_map_as_agtype_value(FunctionCallInfo fcinfo);

#endif
