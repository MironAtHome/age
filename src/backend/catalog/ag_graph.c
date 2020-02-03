#include "postgres.h"

#include "access/genam.h"
#include "access/heapam.h"
#include "access/htup.h"
#include "access/htup_details.h"
#include "access/skey.h"
#include "access/stratnum.h"
#include "access/sysattr.h"
#include "catalog/indexing.h"
#include "storage/lockdefs.h"
#include "utils/builtins.h"
#include "utils/fmgroids.h"
#include "utils/lsyscache.h"
#include "utils/rel.h"
#include "utils/relcache.h"

#include "catalog/ag_catalog.h"
#include "catalog/ag_graph.h"

#define Anum_ag_graph_name 1
#define Anum_ag_graph_namespace 2

#define Natts_ag_graph 2

#define ag_graph_relation_id() ag_relation_id("ag_graph", "table")
#define ag_graph_name_index_id() ag_relation_id("ag_graph_name_index", "index")

// INSERT INTO ag_catalog.ag_graph VALUES (graph_name, nsp_id)
Oid insert_graph(const Name graph_name, const Oid nsp_id)
{
    Datum values[Natts_ag_graph];
    bool nulls[Natts_ag_graph];
    Relation ag_graph;
    HeapTuple tuple;
    Oid graph_oid;

    values[Anum_ag_graph_name - 1] = NameGetDatum(graph_name);
    nulls[Anum_ag_graph_name - 1] = false;

    values[Anum_ag_graph_namespace - 1] = ObjectIdGetDatum(nsp_id);
    nulls[Anum_ag_graph_namespace - 1] = false;

    ag_graph = heap_open(ag_graph_relation_id(), RowExclusiveLock);

    tuple = heap_form_tuple(RelationGetDescr(ag_graph), values, nulls);

    /*
     * CatalogTupleInsert() is originally for PostgreSQL's catalog. However,
     * it is used at here for convenience.
     */
    graph_oid = CatalogTupleInsert(ag_graph, tuple);

    heap_close(ag_graph, RowExclusiveLock);

    return graph_oid;
}

// DELETE FROM ag_catalog.ag_graph WHERE name = graph_name
void delete_graph(const Name graph_name)
{
    ScanKeyData scan_keys[1];
    Relation ag_graph;
    SysScanDesc scan_desc;
    HeapTuple tuple;

    ScanKeyInit(&scan_keys[0], Anum_ag_graph_name, BTEqualStrategyNumber,
                F_NAMEEQ, NameGetDatum(graph_name));

    ag_graph = heap_open(ag_graph_relation_id(), RowExclusiveLock);
    scan_desc = systable_beginscan(ag_graph, ag_graph_name_index_id(), true,
                                   NULL, 1, scan_keys);

    tuple = systable_getnext(scan_desc);
    if (!HeapTupleIsValid(tuple))
    {
        ereport(ERROR,
                (errcode(ERRCODE_UNDEFINED_SCHEMA),
                 errmsg("graph \"%s\" does not exist", NameStr(*graph_name))));
    }

    CatalogTupleDelete(ag_graph, &tuple->t_self);

    systable_endscan(scan_desc);
    heap_close(ag_graph, RowExclusiveLock);
}

// Function updates graph name in ag_graph table.
void update_graph_name(const Name graph_name, const Name new_name)
{
    ScanKeyData scan_keys[1];
    Relation ag_graph;
    SysScanDesc scan_desc;
    HeapTuple cur_tuple;
    Datum repl_values[Natts_ag_graph];
    bool repl_isnull[Natts_ag_graph];
    bool do_replace[Natts_ag_graph];
    HeapTuple new_tuple;

    // open and scan ag_graph for graph name
    ScanKeyInit(&scan_keys[0], Anum_ag_graph_name, BTEqualStrategyNumber,
                F_NAMEEQ, NameGetDatum(graph_name));

    ag_graph = heap_open(ag_graph_relation_id(), RowExclusiveLock);
    scan_desc = systable_beginscan(ag_graph, ag_graph_name_index_id(), true,
                                   NULL, 1, scan_keys);

    cur_tuple = systable_getnext(scan_desc);

    if (!HeapTupleIsValid(cur_tuple))
    {
        ereport(ERROR,
                (errcode(ERRCODE_UNDEFINED_SCHEMA),
                 errmsg("graph \"%s\" does not exist", NameStr(*graph_name))));
    }

    // modify (which creates a new tuple) the current tuple's graph name
    MemSet(repl_values, 0, sizeof(repl_values));
    MemSet(repl_isnull, false, sizeof(repl_isnull));
    MemSet(do_replace, false, sizeof(do_replace));

    repl_values[Anum_ag_graph_name - 1] = NameGetDatum(new_name);
    repl_isnull[Anum_ag_graph_name - 1] = false;
    do_replace[Anum_ag_graph_name - 1] = true;

    new_tuple = heap_modify_tuple(cur_tuple, RelationGetDescr(ag_graph),
                                  repl_values, repl_isnull, do_replace);

    // update the current tuple with the new tuple
    CatalogTupleUpdate(ag_graph, &cur_tuple->t_self, new_tuple);

    // end scan and close ag_graph
    systable_endscan(scan_desc);
    heap_close(ag_graph, RowExclusiveLock);
}

Oid get_graph_oid(const char *graph_name)
{
    NameData graph_name_key;
    ScanKeyData scan_keys[1];
    Relation ag_graph;
    SysScanDesc scan_desc;
    HeapTuple tuple;
    Oid graph_oid;

    AssertArg(graph_name);
    namestrcpy(&graph_name_key, graph_name);
    ScanKeyInit(&scan_keys[0], Anum_ag_graph_name, BTEqualStrategyNumber,
                F_NAMEEQ, NameGetDatum(&graph_name_key));

    ag_graph = heap_open(ag_graph_relation_id(), AccessShareLock);
    scan_desc = systable_beginscan(ag_graph, ag_graph_name_index_id(), true,
                                   NULL, 1, scan_keys);

    tuple = systable_getnext(scan_desc);
    if (HeapTupleIsValid(tuple))
    {
        bool is_null;
        Datum value;

        value = heap_getsysattr(tuple, ObjectIdAttributeNumber,
                                RelationGetDescr(ag_graph), &is_null);
        Assert(!is_null);

        graph_oid = DatumGetObjectId(value);
    }
    else
    {
        graph_oid = InvalidOid;
    }

    systable_endscan(scan_desc);
    heap_close(ag_graph, AccessShareLock);

    return graph_oid;
}

Oid get_graph_namespace(const char *graph_name)
{
    NameData graph_name_key;
    ScanKeyData scan_keys[1];
    Relation ag_graph;
    SysScanDesc scan_desc;
    HeapTuple tuple;
    bool is_null;
    Datum value;

    AssertArg(graph_name);
    namestrcpy(&graph_name_key, graph_name);
    ScanKeyInit(&scan_keys[0], Anum_ag_graph_name, BTEqualStrategyNumber,
                F_NAMEEQ, NameGetDatum(&graph_name_key));

    ag_graph = heap_open(ag_graph_relation_id(), AccessShareLock);
    scan_desc = systable_beginscan(ag_graph, ag_graph_name_index_id(), true,
                                   NULL, 1, scan_keys);

    tuple = systable_getnext(scan_desc);
    if (!HeapTupleIsValid(tuple))
    {
        ereport(ERROR, (errcode(ERRCODE_UNDEFINED_SCHEMA),
                        errmsg("graph \"%s\" does not exist", graph_name)));
    }

    value = fastgetattr(tuple, Anum_ag_graph_namespace,
                        RelationGetDescr(ag_graph), &is_null);
    Assert(!is_null);

    systable_endscan(scan_desc);
    heap_close(ag_graph, AccessShareLock);

    return DatumGetObjectId(value);
}