# Copyright (c) 2021, PostgreSQL Global Development Group

#
# Script that parses Unix style build environment and generates build files
# for building with Visual Studio.
#
# src/tools/msvc/mkvcbuild.pl
#
use strict;
use warnings;

use FindBin;
use lib $FindBin::RealBin;

use Mkvcbuild;

chdir('../..') if (-d '../msvc' && -d '../../src');
die 'Must run from root or msvc directory'
  unless (-d 'tools\\msvc' && -d 'src');

die 'Could not find config_default.pl'
  unless (-f ".\\tools\\msvc\\config_default.pl");
print "Warning: no config.pl found, using default.\n"
  unless (-f ".\\tools\\msvc\\config.pl");

our $config;
do ('.\tools\msvc\config_default.pl') if -e ".\\tools\\msvc\\config_default.pl";
do ('.\tools\msvc\config.pl') if -e ".\\tools\\msvc\\config.pl";

my $pg_config = $ARGV[0];

my $work_dir = `cd`;
$work_dir = _trim($work_dir);
Mkvcbuild::mkvcbuild($pg_config, $work_dir);
Mkvcbuild::GenerateInstallSqlFile("age--1.5.0.sql", $work_dir);
Mkvcbuild::GenerateRegressionSqlFile("age--1.5.0.regress.sql", $work_dir);

sub _trim {
    my $data = shift;

    return '' unless defined $data;

    $data =~ s/^\s+//;
    $data =~ s/\s+$//;
    return $data;
}