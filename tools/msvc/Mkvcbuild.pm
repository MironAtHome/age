# Copyright (c) 2021, PostgreSQL Global Development Group

package Mkvcbuild;

#
# Package that generates build files for msvc build
#
# tools/msvc/Mkvcbuild.pm
#
use strict;
use warnings;

use Carp;
use if ($^O eq "MSWin32"), 'Win32';
use Project;
use Solution;
use Cwd;
use File::Copy;
use File::Spec;
use Config;
use VSObjectFactory;
use List::Util qw(first);
use Exporter;
our (@ISA, @EXPORT_OK);
@ISA       = qw(Exporter);
@EXPORT_OK = qw(Mkvcbuild);

my @unlink_on_exit;

sub mkvcbuild
{
	my ($pg_config_dir, $work_dir) = @_;

	chdir('..') if (-d '../msvs32' && -d '../src');
	die 'Must run from root directory'
	  unless (-d 'tools/msvc' && -d 'src');
    
	system("perl -I .\\tools .\\tools\\gen_keywordlist.pl --extern --varname CypherKeyword --output src/include/parser src/include/parser/cypher_kwlist.h");

	my $vsVersion = DetermineVisualStudioVersion();
	my $postgresinc;
	my $incpath;
	my $postgreslib = "postgres.lib";
	
	my $source_file_path = join("\\", $work_dir, "msvs32\\age.vcxproj");
	my $vc_project = Project::read_file($source_file_path);
	$vc_project =~ s/###pg_config_dir###/$pg_config_dir/ig;
	Project::write_file($source_file_path, $vc_project);

	## Perform replacements as File
	$source_file_path = join("\\", $work_dir, "src\\backend\\age.c");
	my $c_file_content = Project::read_file($source_file_path);
	my $file_modified = 0;

	if (index($c_file_content, "port/win32msvc.h") ==  -1) {
        $c_file_content =~ s/[\"]postgres[\.]h[\"]/\"port\/win32postgres.h\"/ig;
        my $last_include_pos = rindex($c_file_content,"#include");
    	my $last_include_line_end_pos = index($c_file_content,"\n", $last_include_pos) + 1;
    	substr($c_file_content,$last_include_line_end_pos,0) = "#include \"port\/win32msvc.h\"\r\n";
	    $c_file_content =~ s/void [\_]PG[\_]init[\(]void[\)]/PGMODULEEXPORT void _PG_init(void)/ig;
        $c_file_content =~ s/void [\_]PG[\_]fini[\(]void[\)]/PGMODULEEXPORT void _PG_fini(void)/ig;
	}
	Project::write_file($source_file_path, $c_file_content);

    #region src/backend/catalog
    opendir(my $dh, 'src/backend/catalog/')
        || die "Can't opendir src/backend/catalog/ $!";
    my @c_files = grep { /^.+\.c$/ } readdir($dh);
    closedir $dh;
    foreach my $c_file (@c_files)
    {
        $c_file_content = Project::read_file(
    	    "src/backend/catalog/$c_file");
    
    	if (($c_file eq "ag_catalog.c")
    	   or ($c_file eq "ag_graph.c")
    	   or ($c_file eq "ag_label.c")
    	   or ($c_file eq "ag_namespace.c")
    	) {
    		if (index($c_file_content, "port/win32postgres.h") ==  -1) {
                $c_file_content =~ s/[\"]postgres[\.]h[\"]/\"port\/win32postgres.h\"/ig;
    	        my $last_include_pos = rindex($c_file_content,"#include");
    	        my $last_include_line_end_pos = index($c_file_content,"\n", $last_include_pos) + 1;
    	        substr($c_file_content,$last_include_line_end_pos,0) = "#include \"port\/win32msvc.h\"\r\n";
    		}
    	}
    	if ($c_file eq "ag_label.c"){
    		if (index($c_file_content, "PGMODULEEXPORT Datum _label_name(PG_FUNCTION_ARGS)") ==  -1) {
                $c_file_content =~ s/Datum \_label\_name\(PG_FUNCTION_ARGS\)/PGMODULEEXPORT Datum _label_name(PG_FUNCTION_ARGS)/ig;
    		    $c_file_content =~ s/Datum \_label\_id\(PG_FUNCTION_ARGS\)/PGMODULEEXPORT Datum _label_id(PG_FUNCTION_ARGS)/ig;
    		    $c_file_content =~ s/Datum \_extract\_label\_id\(PG_FUNCTION_ARGS\)/PGMODULEEXPORT Datum _extract_label_id(PG_FUNCTION_ARGS)/ig;
    		}
    	}
    	Project::write_file("src/backend/catalog/$c_file"
    	                  , $c_file_content);
    }
    #endregion src/backend/catalog

	#region src/backend/commands
	opendir($dh, 'src/backend/commands/')
	    || die "Can't opendir src/backend/commands/ $!";
	@c_files = grep { /^.+\.c$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
	
        $c_file_content = Project::read_file(
            "src/backend/commands/$c_file");
		
		$file_modified = 0;
		
		if ($c_file eq "label_commands.c")
		{
			if (index($c_file_content, "port/win32postgres.h") ==  -1) {
                $c_file_content =~ s/[\"]postgres[\.]h[\"]/\"port\/win32postgres.h\"/ig;
		        my $last_include_pos = rindex($c_file_content,"#include");
		        my $last_include_line_end_pos = index($c_file_content,"\n", $last_include_pos) + 1;
				substr($c_file_content,$last_include_line_end_pos,0) = "#include \"port\/win32msvc.h\"\r\n";
				$file_modified = 1;
			}
			if (index($c_file_content, "PGMODULEEXPORT Datum create_vlabel(PG_FUNCTION_ARGS)") ==  -1) {
                $c_file_content =~ s/Datum create\_vlabel\(PG_FUNCTION_ARGS\)/PGMODULEEXPORT Datum create_vlabel(PG_FUNCTION_ARGS)/ig;
			    $c_file_content =~ s/Datum create\_elabel\(PG_FUNCTION_ARGS\)/PGMODULEEXPORT Datum create_elabel(PG_FUNCTION_ARGS)/ig;
			    $c_file_content =~ s/Datum drop\_label\(PG_FUNCTION_ARGS\)/PGMODULEEXPORT Datum drop_label(PG_FUNCTION_ARGS)/ig;
				$file_modified = 1;
			}
			if (index($c_file_content, "PGMODULEEXPORT Datum age_is_valid_label_name(PG_FUNCTION_ARGS)") ==  -1) {
                $c_file_content =~ s/Datum age\_is\_valid\_label\_name\(PG_FUNCTION_ARGS\)/PGMODULEEXPORT Datum age_is_valid_label_name(PG_FUNCTION_ARGS)/ig;
				$file_modified = 1;
			}
			if (index($c_file_content, "PGMODULEEXPORT Datum age_vertex_exists(PG_FUNCTION_ARGS)") ==  -1) {
                $c_file_content =~ s/Datum age\_vertex\_exists\(PG_FUNCTION_ARGS\)/PGMODULEEXPORT Datum age_vertex_exists(PG_FUNCTION_ARGS)/ig;
				$c_file_content =~ s/Datum age\_edge\_exists\(PG_FUNCTION_ARGS\)/PGMODULEEXPORT Datum age_edge_exists(PG_FUNCTION_ARGS)/ig;
				$file_modified = 1;
			}	
		}

		if ($c_file eq "graph_commands.c") {
		    if(index($c_file_content, "PGMODULEEXPORT Datum age_graph_exists(PG_FUNCTION_ARGS)") ==  -1) {
                $c_file_content = Project::read_file("msvs32/xsrc/backend/commands/$c_file");
                $file_modified = 1;
			}
        }

        if($file_modified) {
            Project::write_file("src/backend/commands/$c_file"
                , $c_file_content);
        }
    }
	#endregion src/backend/commands

	#region src/backend/executor
	opendir($dh, 'src/backend/executor/')
	    || die "Can't opendir src/backend/executor/ $!";
	@c_files = grep { /^.+\.c$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
		$c_file_content = Project::read_file(
		    "src/backend/executor/$c_file");

		if (($c_file eq "cypher_create.c")
		   || ($c_file eq "cypher_delete.c")
		   || ($c_file eq "cypher_merge.c")
		   || ($c_file eq "cypher_set.c")
		   || ($c_file eq "cypher_utils.c")
		)
		{
			if (index($c_file_content, "port/win32postgres.h") ==  -1) {
                $c_file_content =~ s/[\"]postgres[\.]h[\"]/\"port\/win32postgres.h\"/ig;
		        my $last_include_pos = rindex($c_file_content,"#include");
		        my $last_include_line_end_pos = index($c_file_content,"\n", $last_include_pos) + 1;
		        substr($c_file_content,$last_include_line_end_pos,0) = "#include \"port\/win32msvc.h\"\r\n";
			}
		}
		if (($c_file eq "cypher_set.c")
		 || ($c_file eq "cypher_utils.c")
		){
			if (index($c_file_content, "palloc(") >  -1) {
                $c_file_content =~ s/\bpalloc\(/palloc0(/ig;
			}
		}
	    Project::write_file("src/backend/executor/$c_file"
            , $c_file_content);
    }
    #endregion src/backend/executor
	
    #region src/backend/nodes
	opendir($dh, 'src/backend/nodes/')
	    || die "Can't opendir src/backend/nodes/ $!";
	@c_files = grep { /^.+\.c$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
		$c_file_content = Project::read_file(
		    "src/backend/nodes/$c_file");

		if (($c_file eq "ag_nodes.c")
		 || ($c_file eq "cypher_copyfuncs.c")
		 || ($c_file eq "cypher_outfuncs.c")
		 || ($c_file eq "cypher_readfuncs.c")
		)
		{
			if (index($c_file_content, "port/win32postgres.h") == -1) {
                $c_file_content =~ s/[\"]postgres[\.]h[\"]/\"port\/win32postgres.h\"/ig;
		        my $last_include_pos = rindex($c_file_content,"#include");
		        my $last_include_line_end_pos = index($c_file_content,"\n", $last_include_pos) + 1;
		        substr($c_file_content,$last_include_line_end_pos,0) = "#include \"port\/win32msvc.h\"\r\n";
			}
		}
	    Project::write_file("src/backend/nodes/$c_file"
            , $c_file_content);
    }
    #endregion src/backend/nodes
	
    #region src/backend/optimizer
	opendir($dh, 'src/backend/optimizer/')
	    || die "Can't opendir src/backend/optimizer/ $!";
	@c_files = grep { /^.+\.c$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
		if (($c_file eq "cypher_createplan.c")
		 || ($c_file eq "cypher_pathnode.c")
		 || ($c_file eq "cypher_paths.c")
		)
		{
			
		    $c_file_content = Project::read_file(
		        "src/backend/optimizer/$c_file");

			if (index($c_file_content, "port/win32postgres.h") == -1) {
                $c_file_content =~ s/[\"]postgres[\.]h[\"]/\"port\/win32postgres.h\"/ig;
		        my $last_include_pos = rindex($c_file_content,"#include");
		        my $last_include_line_end_pos = index($c_file_content,"\n", $last_include_pos) + 1;
		        substr($c_file_content,$last_include_line_end_pos,0) = "#include \"port\/win32msvc.h\"\r\n";
			}

			
	        Project::write_file("src/backend/optimizer/$c_file"
                , $c_file_content);
		}
    }
    #endregion src/backend/optimizer

   #region src/backend/parser
opendir($dh, 'src/backend/parser/')
    || die "Can't opendir src/backend/parser/ $!";
@c_files = grep { /^.+\.[cly]$/ } readdir($dh);
closedir $dh;
foreach my $c_file (@c_files)
{
	$c_file_content = Project::read_file(
	    "src/backend/parser/$c_file");

	if (($c_file eq "ag_scanner.l")
	 || ($c_file eq "cypher_analyze.c")
	 || ($c_file eq "cypher_clause.c")
	 || ($c_file eq "cypher_expr.c")
	 || ($c_file eq "cypher_gram.c")
	 || ($c_file eq "cypher_gram.y")
	 || ($c_file eq "cypher_item.c")
	 || ($c_file eq "cypher_parse_agg.c")
	 || ($c_file eq "cypher_parse_node.c")
	 || ($c_file eq "cypher_parser.c")
	 || ($c_file eq "cypher_transform_entity.c")
	)
	{
		if (index($c_file_content, "port/win32postgres.h") == -1) {
               $c_file_content =~ s/[\"]postgres[\.]h[\"]/\"port\/win32postgres.h\"/ig;
		}
	}
	if (($c_file eq "cypher_analyze.c")
	 || ($c_file eq "cypher_clause.c")
	 || ($c_file eq "cypher_expr.c")
	 || ($c_file eq "cypher_item.c")
	 || ($c_file eq "cypher_parse_agg.c")
	 || ($c_file eq "cypher_parse_node.c")
	 || ($c_file eq "cypher_parser.c")
	 || ($c_file eq "cypher_transform_entity.c")
	){
		if (index($c_file_content, "port/win32msvc.h") == -1) {
	        my $last_include_pos = rindex($c_file_content,"#include");
	        my $last_include_line_end_pos = index($c_file_content,"\n", $last_include_pos) + 1;
	        substr($c_file_content,$last_include_line_end_pos,0) = "#include \"port\/win32msvc.h\"\r\n";
		}
	}
	if (($c_file eq "ag_scanner.l")
	 || ($c_file eq "cypher_clause.c")
	 || ($c_file eq "cypher_expr.c")
	 || ($c_file eq "cypher_parse_agg.c")
	 || ($c_file eq "cypher_transform_entity.c")
	 || ($c_file eq "cypher_analyze.c")
	){
		if (index($c_file_content, "palloc(") > -1) {
               $c_file_content =~ s/\bpalloc\(/palloc0(/ig;
		}
	}
	if ($c_file eq "cypher_clause.c"){
		if (index($c_file_content, "Query *result = NULL;") == -1) {
		    $c_file_content =~ s/Query \*result\;/Query *result = NULL\;/ig;
		    $c_file_content =~ s/cypher_return \*cmp\;/cypher_return *cmp = NULL\;/ig;
		    $c_file_content =~ s/ParseNamespaceItem \*pnsi\;/ParseNamespaceItem *pnsi = NULL\;/ig;
		    $c_file_content =~ s/char \*left_dir\;/char *left_dir = NULL\;/ig;
		    $c_file_content =~ s/char \*right_dir\;/char *right_dir = NULL\;/ig;
		    $c_file_content =~ s/char \*entity_name\;/char *entity_name = NULL\;/ig;
		    $c_file_content =~ s/Expr \*properties\;/Expr *properties = NULL\;/ig;
		    $c_file_content =~ s/Expr \*properties\;/Expr *properties = NULL\;/ig;
		}
	}
	if ($c_file eq "cypher_expr.c"){
		if (index($c_file_content, "Oid func_access_oid = 0;") == -1) {
		    $c_file_content =~ s/Query \*result\;/Node* expr = NULL\;/ig;
		    $c_file_content =~ s/FuncExpr \*func_expr\;/FuncExpr* func_expr = NULL\;/ig;
		    $c_file_content =~ s/Oid func_access_oid\;/Oid func_access_oid = 0\;/ig;
		    $c_file_content =~ s/const char \*func_name\;/const char *func_name = NULL\;/ig;
		}
	}
	if ($c_file eq "cypher_expr.c") {
		if (index($c_file_content, "strncpy(") > -1) {
		    $c_file_content =~ s/strncpy\(ag_name, \"age\_\", 4\)\;/strncpy_s(ag_name, (pnlen + 5), \"age_\", 4)\;/ig;
		}
	}
	if ($c_file eq "cypher_gram.y") {
		if (index($c_file_content, "#define YYMALLOC palloc0") == -1) {
		    $c_file_content =~ s/\#define YYMALLOC palloc/#define YYMALLOC palloc0/g;
			$c_file_content =~ s/uint nlen \= 0\;/unsigned int nlen = 0;/g;
		}
	}
	if ($c_file eq "cypher_keywords.c") {
		$c_file_content = Project::read_file("msvs32/xsrc/backend/parser/$c_file");
	}
    Project::write_file("src/backend/parser/$c_file"
           , $c_file_content);
   }
   #endregion src/backend/parser

    #region src/backend/utils
	opendir($dh, 'src/backend/utils/')
	    || die "Can't opendir src/backend/utils/ $!";
	@c_files = grep { /^.+\.c$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
		$c_file_content = Project::read_file(
		    "src/backend/utils/$c_file");

		if (($c_file eq "ag_func.c")
		 || ($c_file eq "ag_guc.c")
		 || ($c_file eq "graph_generation.c")
		 || ($c_file eq "name_validation.c")
		)
		{
			if (index($c_file_content, "port/win32postgres.h") == -1) {
                $c_file_content =~ s/[\"]postgres[\.]h[\"]/\"port\/win32postgres.h\"/ig;
			}
		}
		if ($c_file eq "graph_generation.c")
		{
			if (index($c_file_content, "#include \"port/win32msvc.h\"") == -1) {
		        my $last_include_pos = rindex($c_file_content,"#include");
		        my $last_include_line_end_pos = index($c_file_content,"\n", $last_include_pos) + 1;
		        substr($c_file_content,$last_include_line_end_pos,0) = "#include \"port\/win32msvc.h\"\r\n";
			}
		}
		if ($c_file eq "graph_generation.c")
		{
			if (index($c_file_content, "PGMODULEEXPORT Datum create_complete_graph(PG_FUNCTION_ARGS)") == -1) {
		        $c_file_content =~ s/Datum create\_complete\_graph\(PG_FUNCTION_ARGS\)/PGMODULEEXPORT Datum create_complete_graph(PG_FUNCTION_ARGS)/g;
		        $c_file_content =~ s/Datum age_create\_barbell\_graph\(PG_FUNCTION_ARGS\)/PGMODULEEXPORT Datum age_create_barbell_graph(PG_FUNCTION_ARGS)/g;
			}
		}
	    Project::write_file("src/backend/utils/$c_file"
            , $c_file_content);
    }
    #endregion src/backend/utils

    #region src/backend/utils/adt
	opendir($dh, 'src/backend/utils/adt/')
	    || die "Can't opendir src/backend/utils/adt/ $!";
	@c_files = grep { /^.+\.c$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
		$c_file_content = Project::read_file(
		    "src/backend/utils/adt/$c_file");

		if (($c_file eq "ag_float8_supp.c")
		 || ($c_file eq "age_graphid_ds.c")
		 || ($c_file eq "age_session_info.c")
		 || ($c_file eq "agtype_gin.c")
		 || ($c_file eq "agtype_parser.c")
		 || ($c_file eq "agtype_raw.c")
		 || ($c_file eq "agtype_util.c")
		 || ($c_file eq "cypher_funcs.c")
		 || ($c_file eq "graphid.c")
		) {
			if (index($c_file_content, "port/win32postgres.h") == -1) {
                $c_file_content =~ s/[\"]postgres[\.]h[\"]/\"port\/win32postgres.h\"/ig;
			}
		}
		if (($c_file eq "age_session_info.c")
		 || ($c_file eq "agtype_gin.c")
		 || ($c_file eq "cypher_funcs.c")
		 || ($c_file eq "graphid.c")
		){
			if (index($c_file_content, "port/win32msvc.h") == -1) {
		        my $last_include_pos = rindex($c_file_content,"#include");
		        my $last_include_line_end_pos = index($c_file_content,"\n", $last_include_pos) + 1;
		        substr($c_file_content,$last_include_line_end_pos,0) = "#include \"port\/win32msvc.h\"\r\n";
			}
		}
		if ($c_file eq "age_session_info.c")
		{
			if (index($c_file_content, "PGMODULEEXPORT Datum age_prepare_cypher(PG_FUNCTION_ARGS)") == -1) {
			    $c_file_content =~ s/getpid\(\)/_getpid()/g;
		        $c_file_content =~ s/Datum age\_prepare\_cypher\(PG_FUNCTION_ARGS\)/PGMODULEEXPORT Datum age\_prepare\_cypher\(PG_FUNCTION_ARGS\)/g;
			}
		}
		if (($c_file eq "ag_scanner.l")
		 || ($c_file eq "cypher_clause.c")
		 || ($c_file eq "cypher_expr.c")
		 || ($c_file eq "cypher_parse_agg.c")
		 || ($c_file eq "cypher_transform_entity.c")
		 || ($c_file eq "agtype_parser.c")
		){
			if (index($c_file_content, "palloc(") > -1) {
                $c_file_content =~ s/\bpalloc\(/palloc0(/ig;
			}
		}
        if (($c_file eq "agtype_ext.c") 
		 || ($c_file eq "agtype_gin.c")
		 || ($c_file eq "agtype_util.c")
		){
			if (index($c_file_content, "palloc(") > -1) {
                $c_file_content =~ s/\bpalloc\(/palloc0(/ig;
			}
		}
		if ($c_file eq "agtype_gin.c") {
			if (index($c_file_content, "PGMODULEEXPORT Datum gin_compare_agtype(PG_FUNCTION_ARGS)") == -1) {
		        $c_file_content =~ s/Datum gin\_compare\_agtype\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum gin_compare_agtype(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum gin\_extract\_agtype\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum gin_extract_agtype(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum gin\_extract\_agtype\_query\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum gin_extract_agtype_query(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum gin\_consistent\_agtype\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum gin_consistent_agtype(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum gin\_triconsistent\_agtype\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum gin_triconsistent_agtype(PG_FUNCTION_ARGS)/g;
			}
		}
		if ($c_file eq "cypher_funcs.c") {
			if (index($c_file_content, "PGMODULEEXPORT Datum cypher(PG_FUNCTION_ARGS)") == -1) {
		        $c_file_content =~ s/Datum cypher\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum cypher(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum \_cypher\_create\_clause\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum _cypher_create_clause(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum \_cypher\_set\_clause\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum _cypher_set_clause(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum \_cypher\_delete\_clause\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum _cypher_delete_clause(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum \_cypher\_merge\_clause\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum _cypher_merge_clause(PG_FUNCTION_ARGS)/g;
			}
		}
		if ($c_file eq "graphid.c") {
			if (index($c_file_content, "PGMODULEEXPORT Datum graphid_in(PG_FUNCTION_ARGS)") == -1) {
		        $c_file_content =~ s/Datum graphid\_in\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum graphid_in(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum graphid\_out\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum graphid_out(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum graphid\_eq\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum graphid_eq(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum graphid\_ne\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum graphid_ne(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum graphid\_gt\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum graphid_gt(PG_FUNCTION_ARGS)/g;
				$c_file_content =~ s/Datum graphid\_lt\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum graphid_lt(PG_FUNCTION_ARGS)/g;
                $c_file_content =~ s/Datum graphid\_le\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum graphid_le(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum graphid\_ge\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum graphid_ge(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum graphid\_btree\_cmp\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum graphid_btree_cmp(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum graphid\_btree\_sort\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum graphid_btree_sort(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum \_graphid\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum _graphid(PG_FUNCTION_ARGS)/g;
			    $c_file_content =~ s/Datum graphid\_hash\_cmp\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum graphid_hash_cmp(PG_FUNCTION_ARGS)/g;
			}
		}
	    Project::write_file("src/backend/utils/adt/$c_file"
            , $c_file_content);
    }
	opendir($dh, 'msvs32/xsrc/backend/utils/adt/')
	    || die "Can't opendir msvs32/xsrc/backend/utils/adt/ $!";
	@c_files = grep { /^.+\.c$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
	    $c_file_content = Project::read_file(
		    "src/backend/utils/adt/$c_file");
		if ((($c_file eq "age_global_graph.c")
		     ||($c_file eq "age_vle.c")
		     ||($c_file eq "agtype.c")
		     ||($c_file eq "agtype_ops.c"))
		     && index($c_file_content, "port/win32postgres.h") == -1
	    ) {
		    $c_file_content = Project::read_file(
		        "msvs32/xsrc/backend/utils/adt/$c_file");
	        Project::write_file("src/backend/utils/adt/$c_file"
                , $c_file_content);
		}
    }
    #endregion src/backend/utils/adt
	
    #region src/backend/utils/cache
    opendir($dh, 'src/backend/utils/cache/')
        || die "Can't opendir src/backend/utils/cache/ $!";
    @c_files = grep { /^.+\.c$/ } readdir($dh);
    closedir $dh;
    foreach my $c_file (@c_files)
    {
    	$c_file_content = Project::read_file(
    	    "src/backend/utils/cache/$c_file");
    
    	if ($c_file eq "ag_cache.c")
    	{
    		if (index($c_file_content, "port/win32postgres.h") == -1) {
                $c_file_content =~ s/[\"]postgres[\.]h[\"]/\"port\/win32postgres.h\"/ig;
    		}
    	}
        Project::write_file("src/backend/utils/cache/$c_file"
            , $c_file_content);
    }
    #endregion src/backend/utils/cache

	#region src/backend/utils/load
	opendir($dh, 'msvs32/xsrc/backend/utils/load/')
	    || die "Can't opendir msvs32/xsrc/backend/utils/load/ $!";
	@c_files = grep { /^.+\.c$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
		
		$c_file_content = Project::read_file(
		    "src/backend/utils/load/$c_file");
				
		if (index($c_file_content, "port/win32postgres.h") == -1) {
		    $c_file_content = Project::read_file(
		        "msvs32/xsrc/backend/utils/load/$c_file");
	        Project::write_file("src/backend/utils/load/$c_file"
                , $c_file_content);
		}
    }
    #endregion src/backend/utils/load
	
	#region src/include/catalog
	opendir($dh, 'src/include/catalog/')
	    || die "Can't opendir src/include/catalog/ $!";
	@c_files = grep { /^.+\.h$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
		$c_file_content = Project::read_file(
		    "src/include/catalog/$c_file");

		if (index($c_file_content, "port/win32postgres.h") == -1) {
		    $c_file_content =~ s/[\"]postgres[\.]h[\"]/\"port\/win32postgres.h\"/ig;
		}

	    Project::write_file("src/include/catalog/$c_file"
            , $c_file_content);
    }
    #endregion src/include/catalog
	
	#region src/include/commands
	opendir($dh, 'src/include/commands/')
	    || die "Can't opendir src/include/commands/ $!";
	@c_files = grep { /^.+\.h$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
		$c_file_content = Project::read_file(
		    "src/include/commands/$c_file");

		if (index($c_file_content, "port/win32postgres.h") == -1) {
		    $c_file_content =~ s/[\"]postgres[\.]h[\"]/\"port\/win32postgres.h\"/ig;
		}

		if ($c_file eq "label_commands.h") {
			if (index($c_file_content, "port/win32msvc.h") == -1) {
		        my $first_function_pos = rindex($c_file_content,"void create_label");
				while (substr($c_file_content, $first_function_pos, 1) ne "\n")
				{
					$first_function_pos = ($first_function_pos - 1);
				}
				$first_function_pos = ($first_function_pos + 1);
				if (substr($c_file_content, $first_function_pos, 1) eq "\r")
				{
			        $first_function_pos = ($first_function_pos + 1);
				}
		        substr($c_file_content,$first_function_pos,0) = "#include \"port\/win32postgres.h\"\r\n";
				substr($c_file_content,$first_function_pos,0) = "#include \"port\/win32msvc.h\"\r\n";
			}
		}
		if ($c_file eq "label_commands.h") {
			if (index($c_file_content, "PGMODULEEXPORT Datum create_vlabel(PG_FUNCTION_ARGS)") == -1) {
		        $c_file_content =~ s/Datum create\_vlabel\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum create_vlabel(PG_FUNCTION_ARGS)/g;
				$c_file_content =~ s/Datum create\_elabel\(PG\_FUNCTION\_ARGS\)/PGMODULEEXPORT Datum create_elabel(PG_FUNCTION_ARGS)/g;
			}
		}

	    Project::write_file("src/include/commands/$c_file"
            , $c_file_content);
    }
    #endregion src/include/commands
	
	#region src/include/nodes
	opendir($dh, 'src/include/nodes/')
	    || die "Can't opendir src/include/nodes/ $!";
	@c_files = grep { /^.+\.h$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
		$c_file_content = Project::read_file(
		    "src/include/nodes/$c_file");

		if (index($c_file_content, "port/win32postgres.h") == -1) {
		    $c_file_content =~ s/[\"]postgres[\.]h[\"]/\"port\/win32postgres.h\"/ig;
		}

	    Project::write_file("src/include/nodes/$c_file"
            , $c_file_content);
    }
    #endregion src/include/nodes
	
	#region src/include/parser
	opendir($dh, 'src/include/parser/')
	    || die "Can't opendir src/include/parser/ $!";
	@c_files = grep { /^.+\.h$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
		if ($c_file eq "cypher_item.h") {

			$c_file_content = Project::read_file(
				"src/include/parser/$c_file");

			if (index($c_file_content, "port/win32postgres.h") == -1) {
		        $c_file_content =~ s/[\"]postgres[\.]h[\"]/\"port\/win32postgres.h\"/ig;

			    Project::write_file("src/include/parser/$c_file"
				    , $c_file_content);
			}
		}
    }
    #endregion src/include/parser
	
	#region src/include/port
	if (! -d 'src/include/port/') {
		mkdir('./src/include/port') || die "Could not create directory ./src/include/port/";
	}
	opendir($dh, 'msvs32/xsrc/include/port/')
	    || die "Can't msvs32/xsrc/include/port/ $!";
	@c_files = grep { /^.+\.h$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
		if(! -f "src/include/port/$c_file") {
		    $c_file_content = Project::read_file(
                "msvs32/xsrc/include/port/$c_file");
		    
            ##Project::write_file will create file if not exists
		    Project::write_file("src/include/port/$c_file"
		        , $c_file_content);
		}
    }
    #endregion src/include/port
	
	#region src/include/utils
	opendir($dh, 'src/include/utils/')
	    || die "Can't opendir src/include/utils/ $!";
	@c_files = grep { /^.+\.h$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
		if (($c_file eq "ag_cache.h") 
		 || ($c_file eq "ag_float8_supp.h")
		 || ($c_file eq "ag_func.h")
		 || ($c_file eq "ag_load.h")
		 || ($c_file eq "agtype_ext.h")
		 || ($c_file eq "graphid.h")
		){

			$c_file_content = Project::read_file(
				"src/include/utils/$c_file");

			if (($c_file eq "ag_cache.h")
			 || ($c_file eq "ag_float8_supp.h")
			 || ($c_file eq "ag_func.h")
		     || ($c_file eq "ag_load.h")
		     || ($c_file eq "agtype_ext.h")
			 || ($c_file eq "graphid.h")
			){
				if (index($c_file_content, "port/win32postgres.h") == -1) {
			        $c_file_content =~ s/[\"]postgres[\.]h[\"]/\"port\/win32postgres.h\"/ig;
				}
			}
			if ($c_file eq "cypher_kwlist.h") {
				if (index($c_file_content, "DELETE_SYM") == -1) {
			        $c_file_content =~ s/\bDELETE\b/DELETE_SYM/g;
				    $c_file_content =~ s/\bIN\b/IN_SYM/g;
				    $c_file_content =~ s/\bOPTIONAL\b/OPTIONAL_SYM/g;
				}
			}
			Project::write_file("src/include/utils/$c_file"
				, $c_file_content);
		}
    }
	opendir($dh, 'msvs32/xsrc/include/utils/')
	    || die "Can't opendir msvs32/xsrc/include/utils/ $!";
	@c_files = grep { /^.+\.h$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
		$c_file_content = Project::read_file(
            "src/include/utils/$c_file");
		if ($c_file eq "agtype.h") {
			if (index($c_file_content, "typedef struct PercentileGroupAggState") == -1) {
		        $c_file_content = Project::read_file(
		               "msvs32/xsrc/include/utils/$c_file");
		        Project::write_file("src/include/utils/$c_file"
			        , $c_file_content);
		    }
		}
		if ($c_file eq "agtype_raw.h") {
			if (index($c_file_content, "port/win32postgres.h") == -1) {
		        $c_file_content = Project::read_file(
		               "msvs32/xsrc/include/utils/$c_file");
		        Project::write_file("src/include/utils/$c_file"
			        , $c_file_content);
		    }
		}
		
	}
    #endregion src/include/utils
	
	#region src/include/utils/load
	opendir($dh, 'msvs32/xsrc/include/utils/load')
	    || die "Can't opendir msvs32/xsrc/include/utils/load $!";
	@c_files = grep { /^.+\.h$/ } readdir($dh);
	closedir $dh;
	foreach my $c_file (@c_files)
	{
		$c_file_content = Project::read_file(
            "src/include/utils/load/$c_file");
		if (index($c_file_content, "port/win32postgres.h") == -1) {
		       $c_file_content = Project::read_file(
		              "msvs32/xsrc/include/utils/load/$c_file");
		       Project::write_file("src/include/utils/load/$c_file"
		        , $c_file_content);
		}
    }
    #endregion src/include/utils/load
	
	system("perl .\\tools\\msvc\\pgflex.pl src\\backend\\parser\\ag_scanner.l");
	system("perl .\\tools\\msvc\\pgbison.pl src\\backend\\parser\\cypher_gram.y");
	
	opendir($dh, 'src/include/parser/')
        || die "Can't opendir src/include/parser/ $!";
    @c_files = grep { /^.+\.h$/ } readdir($dh);
    closedir $dh;
    foreach my $c_file (@c_files)
    {
    	if ($c_file eq "cypher_gram_def.h") {
			
			$c_file_content = Project::read_file(
			    "src/include/parser/$c_file");
    		
			if (index($c_file_content, "#undef STRING") == -1) {

		        my $include_pos = index($c_file_content,"# define YY_CYPHER_YY_SRC_INCLUDE_PARSER_CYPHER_GRAM_DEF_H_INCLUDED");
		        my $include_line_end_pos = index($c_file_content, "\n", $include_pos) + 1;
		        substr($c_file_content,$include_line_end_pos,0) = "#ifdef STRING\r\n#undef STRING\r\n#endif\r\n";

		        Project::write_file("src/include/parser/$c_file"
		            , $c_file_content);
    		}			    
    	}
    }

    opendir($dh, 'src/backend/parser/')
        || die "Can't opendir src/backend/parser/ $!";
    @c_files = grep { /^.+\.c$/ } readdir($dh);
    closedir $dh;
    foreach my $c_file (@c_files)
    {
    	if ($c_file eq "cypher_gram.c") {
			
			$c_file_content = Project::read_file(
			    "src/backend/parser/$c_file");
    		
			if (index($c_file_content, "parser/cypher_gram_def.h") == -1) {

    		    $c_file_content =~ s/cypher_gram_def.h/parser\/cypher_gram_def.h/g;
		        Project::write_file("src/backend/parser/$c_file"
		            , $c_file_content);
    		}			    
    	}
    }
}

#####################
# Utility functions #
#####################

sub GenerateRegressionSqlFile
{
	my ($destination_file_name, $work_dir) = @_;
	my $source_dir = join("\\", $work_dir, "regress\\sql");
	my $destination_file_path = join("\\", $work_dir, $destination_file_name);
	if (-f $destination_file_path) {
		unlink($destination_file_path);
	}
	my @file_array = (
	 'scan.sql'
   , 'graphid.sql'
   , 'agtype.sql'
   , 'agtype_hash_cmp.sql'
   , 'catalog.sql'
   , 'cypher.sql'
   , 'expr.sql'
   , 'cypher_create.sql'
   , 'cypher_match.sql'
   , 'cypher_unwind.sql'
   , 'cypher_set.sql'
   , 'cypher_remove.sql'
   , 'cypher_delete.sql'
   , 'cypher_with.sql'
   , 'cypher_vle.sql'
   , 'cypher_union.sql'
   , 'cypher_call.sql'
   , 'cypher_merge.sql'
   , 'cypher_subquery.sql'
   , 'age_global_graph.sql'
   , 'age_load.sql'
   , 'index.sql'
   , 'analyze.sql'
   , 'graph_generation.sql'
   , 'name_validation.sql'
   , 'jsonb_operators.sql'
   , 'list_comprehension.sql'
   , 'map_projection.sql'
   , 'drop.sql');

	my $copy_index = 0;

	foreach my $file (@file_array)
	{
		my $source_file_path = join("\\", $source_dir, $file);

		if ($copy_index eq 0) {
			copy($source_file_path, $destination_file_path) or die "Copy failed: $!";
		} else {
			CombineFiles($source_file_path, $destination_file_path);
		}
		$copy_index = ($copy_index + 1);
	}

	return;
}

sub GenerateInstallSqlFile
{
	my ($destination_file_name, $work_dir) = @_;
    my $source_dir = join("\\", $work_dir, "sql");
	my $destination_file_path = join("\\", $work_dir, $destination_file_name);
	if (-f $destination_file_path) {
		unlink($destination_file_path)  or die "Delete failed for file $destination_file_path: $!";
	}
	my @file_array = (
	  'age_main.sql'
    , 'age_agtype.sql'
    , 'agtype_comparison.sql'
    , 'agtype_access.sql'
    , 'agtype_operators.sql'
    , 'agtype_exists.sql'
    , 'agtype_gin.sql'
    , 'agtype_graphid.sql'
    , 'agtype_coercions.sql'
    , 'agtype_string.sql'
    , 'age_query.sql'
    , 'age_scalar.sql'
    , 'age_string.sql'
    , 'age_trig.sql'
    , 'age_aggregate.sql'
    , 'agtype_typecast.sql');

	my $copy_index = 0;

	foreach my $file (@file_array)
	{
		my $source_file_path = join("\\", $source_dir, $file);

		if ($copy_index eq 0) {
			copy($source_file_path, $destination_file_path) or die "Copy failed for file $source_file_path: $!";
		} else {
			CombineFiles($source_file_path, $destination_file_path);
		}
		$copy_index = ($copy_index + 1);
	}

	return;
}

sub CombineFiles
{
	my ($sourcefile, $targetfile) = @_;

	my $sourcestream;
	my $appendstream;
	open $sourcestream, '<', $sourcefile
	    || confess "Could not open $sourcefile for reading $!";

	if (-f $targetfile) {
	    open $appendstream, '>>', $targetfile 
	        || confess "Could not open $targetfile for write $!";
	}
	else {
	    open $appendstream, '>', $targetfile 
	        || confess "Could not open $targetfile for append $!";
	}

	print $appendstream "\n";

    while (my $line = <$sourcestream>) {
        print $appendstream $line;
    }

	close $appendstream;
	close $sourcestream;

	return;
}

END
{
	unlink @unlink_on_exit;
}

1;