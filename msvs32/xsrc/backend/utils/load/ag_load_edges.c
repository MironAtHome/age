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

#include "port/win32postgres.h"

#include "utils/load/ag_load_edges.h"
#include "utils/load/age_load.h"
#include "utils/load/csv.h"

void edge_field_cb(void *field, size_t field_len, void *data)
{

    csv_edge_reader *cr = (csv_edge_reader*)data;
    if (cr->error)
    {
        cr->error = 1;
        ereport(NOTICE,(errmsg("There is some unknown error")));
    }

    // check for space to store this field
    if (cr->cur_field == cr->alloc)
    {
        cr->alloc += 2;
        cr->fields = (char **)repalloc(cr->fields, sizeof(char *) * cr->alloc);
        if (cr->fields == NULL)
        {
            cr->error = 1;
            ereport(ERROR,
                    (errmsg("field_cb: failed to reallocate %zu bytes\n",
                            sizeof(char *) * cr->alloc)));
        }
        cr->fields_len = repalloc(cr->fields_len, sizeof(size_t) * cr->alloc);
        if (cr->fields_len == NULL)
        {
            cr->error = 1;
            ereport(ERROR,
                (errmsg("field_cb: failed to reallocate %zu bytes\n",
                    sizeof(size_t) * cr->alloc)));
        }
    }
    cr->fields_len[cr->cur_field] = field_len;
    cr->curr_row_length += field_len;
    cr->fields[cr->cur_field] = pnstrdup((char*)field, field_len);
    cr->cur_field += 1;
}

// Parser calls this function when it detects end of a row
void edge_row_cb(int delim, void *data)
{

    csv_edge_reader *cr = (csv_edge_reader*)data;

    size_t i, n_fields;
    int64 start_id_int;
    graphid start_vertex_graph_id;
    int start_vertex_type_id;

    int64 end_id_int;
    graphid end_vertex_graph_id;
    int end_vertex_type_id;

    graphid object_graph_id;

    agtype* props = NULL;

    n_fields = cr->cur_field;

    if (cr->row == 0)
    {
        cr->header_num = cr->cur_field;
        cr->header_row_length = cr->curr_row_length;
        cr->header_len = (size_t* )palloc0(sizeof(size_t) * cr->header_num);
        cr->header = palloc0((sizeof (char*) * cr->header_num));

        for (i = 0; i<cr->header_num; i++)
        {
            cr->header_len[i] = cr->fields_len[i];
            cr->header[i] = pnstrdup(cr->fields[i], cr->header_len[i]);
        }
    }
    else
    {
        object_graph_id = make_graphid(cr->object_id, (int64)cr->row);

        start_id_int = strtol(cr->fields[0], NULL, 10);
        start_vertex_type_id = get_label_id(cr->fields[1], cr->graph_oid);
        end_id_int = strtol(cr->fields[2], NULL, 10);
        end_vertex_type_id = get_label_id(cr->fields[3], cr->graph_oid);

        start_vertex_graph_id = make_graphid(start_vertex_type_id, start_id_int);
        end_vertex_graph_id = make_graphid(end_vertex_type_id, end_id_int);

        props = create_agtype_from_list_i(cr->header, cr->fields,
                                          n_fields, 3);

        insert_edge_simple(cr->graph_oid, cr->object_name,
                           object_graph_id, start_vertex_graph_id,
                           end_vertex_graph_id, props);

        pfree(props);
    }

    for (i = 0; i < n_fields; ++i)
    {
        free(cr->fields[i]);
    }

    if (cr->error)
    {
        ereport(NOTICE,(errmsg("THere is some error")));
    }


    cr->cur_field = 0;
    cr->curr_row_length = 0;
    cr->row += 1;
}

static int is_space(unsigned char c)
{
    if (c == CSV_SPACE || c == CSV_TAB)
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

static int is_term(unsigned char c)
{
    if (c == CSV_CR || c == CSV_LF)
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

int create_edges_from_csv_file(text* file_path,
                               char *graph_name,
                               Oid graph_oid,
                               char *object_name,
                               int object_id )
{
    struct csv_parser p;
    bytea* buf;
    size_t bytes_read = 0;
    int64 seek_offset = 0;
    unsigned char options = 0;
    csv_edge_reader cr;

    if (csv_init(&p, options) != 0)
    {
        ereport(ERROR,
                (errmsg("Failed to initialize csv parser\n")));
    }

    csv_set_space_func(&p, is_space);
    csv_set_term_func(&p, is_term);
    csv_set_blk_size(&p, 1024);

    memset((void*)&cr, 0, sizeof(csv_edge_reader));
    cr.alloc = 128;
    cr.fields = (char **)p.malloc_func(sizeof(char *) * cr.alloc);
    cr.fields_len = (size_t *)p.malloc_func(sizeof(size_t) * cr.alloc);
    cr.header_row_length = 0;
    cr.curr_row_length = 0;
    cr.graph_name = graph_name;
    cr.graph_oid = graph_oid;
    cr.object_name = object_name;
    cr.object_id = object_id;

    while (true)
    {
        buf = DatumGetByteaPP(
            DirectFunctionCall4(pg_read_binary_file_all
                , PointerGetDatum(file_path)
                , Int64GetDatum(seek_offset)
                , Int64GetDatum(1024)
                , BoolGetDatum(false)));
        if (NULL == buf)
        {
            break;
        }

        bytes_read = VARSIZE_ANY_EXHDR(buf);
        if (0 == bytes_read)
        {
            break;
        }

        if (csv_parse(&p, buf->vl_dat, bytes_read, edge_field_cb,
                      edge_row_cb, &cr) != bytes_read)
        {
            ereport(ERROR, (errmsg("Error while parsing file: %s\n",
                                   csv_strerror(csv_error(&p)))));
        }

        seek_offset += bytes_read;
    }

    csv_fini(&p, edge_field_cb, edge_row_cb, &cr);

    p.free_func(cr.fields);
    p.free_func(cr.fields_len);
    p.free_func(cr.header);
    p.free_func(cr.header_len);

    csv_free(&p);
    return EXIT_SUCCESS;
}

int create_edges_from_table(text* qualified_table_name,
    char* graph_name,
    Oid graph_oid,
    char* object_name,
    int object_id)
{
    // get table using 
    
    while (true)
    {
        break;
    }
    return EXIT_SUCCESS;
}
