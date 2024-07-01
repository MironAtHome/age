# -*-perl-*- hey - emacs - this is a perl file

# Copyright (c) 2021, PostgreSQL Global Development Group

#
# Script that provides 'make' functionality for msvc builds.
#
# tools/msvc/build.pl
#
use strict;
use warnings;

use FindBin;
use lib $FindBin::RealBin;

use Cwd;

use Mkvcbuild;

sub usage
{
	die(    "Usage: \n"
	      . "Step 1: set environment variable pointing at valid\n"
		  . "Postgres installaiton of matching version, example:\n"
		  . "SET PG_CONFIG=C:\\dev\\app\\pgsql14\n"
		  . "Step 2: invoke per script as per below:\n"
	      . "build.pl [ <configuration> ] \n"
		  . "Options are case-insensitive.\n"
		  . "  configuration: Release | Debug.  This sets the configuration\n"
		  . "    to build.  Default is Release.\n");
}

chdir('..') if (-d '../msvs32' && -d '../src');
die 'Must run from root directory'
  unless (-d 'tools/msvc' && -d 'src');

usage() unless scalar(@ARGV) <= 2;

# buildenv.pl is for specifying the build environment settings
# it should contain lines like:
# $ENV{PATH} = "c:/path/to/bison_&_flex;$ENV{PATH}";

if (-e "tools/msvc/buildenv.pl")
{
	do "./tools/msvc/buildenv.pl";
}
elsif (-e "./buildenv.pl")
{
	do "./buildenv.pl";
}
do "./tools/msvc/config.pl" if (-f "tools/msvc/config.pl");

# set up the project
my $pg_config;

# check what sort of build we are doing
   $pg_config = $ENV{PG_CONFIG} || (print("Please, specify postgres installation folder.\n") && usage());
my $bconf     = $ENV{CONFIG}    || "Release";
my $msbflags  = "";
my $buildwhat = "age";

if (defined($ARGV[0]))
{
	if (uc($ARGV[0]) eq 'DEBUG')
	{
		$bconf = "Debug";
	}
	elsif (uc($ARGV[0]) eq "RELEASE")
	{
		$bconf = "Release";
	}
	else
	{
		die 'Pleae specify release or debug configuration'
	}
}

my $work_dir = cwd();

my $vcver = Mkvcbuild::mkvcbuild($pg_config, $work_dir);

Mkvcbuild::GenerateRegressionSqlFile('age--1.5.0.regress.sql', $work_dir);

Mkvcbuild::GenerateInstallSqlFile('age--1.5.0.sql', $work_dir);

# ... and do it

chdir('msvs32');

if ($buildwhat)
{
	system(
		"msbuild $buildwhat.vcxproj /verbosity:normal $msbflags /property:Platform=x64 /p:Configuration=$bconf"
	);
}
else
{
	system(
		"msbuild age.sln /verbosity:normal $msbflags /property:Platform=x64 /p:Configuration=$bconf"
	);
}

# report status

our $status = $? >> 8;

exit $status;