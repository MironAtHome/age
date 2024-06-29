# -*-perl-*- hey - emacs - this is a perl file

# Copyright (c) 2021, PostgreSQL Global Development Group

# src/tools/msvc/pgbison.pl

use strict;
use warnings;

use File::Basename;


my $input = shift;
# assume we are in the age source root

do ('.\tools\msvc\config.pl') if -e ".\\tools\\msvc\\config.pl";

my ($bisonver) = `bison -V`;    # grab first line
$bisonver = (split(/\s+/, $bisonver))[3];    # grab version number

unless ($bisonver eq '1.875' || $bisonver ge '2.2')
{
	print "WARNING! Bison install not found, or unsupported Bison version.\n";
	print "echo Attempting to build without.\n";
	exit 0;
}

if ($input !~ /\.y$/)
{
	print "Input must be a .y file\n";
	exit 1;
}
elsif (!-e $input)
{
	print "Input file $input not found\n";
	exit 1;
}

my $output = "src\\backend\\parser\\cypher_gram.c";

my $nodep = $bisonver ge '3.0' ? "-Wno-deprecated" : "";

my $headerflag = "--defines=src\\include\\parser\\cypher_gram_def.h";

system("bison $nodep $headerflag $input -o $output");
exit $? >> 8;
