# -*-perl-*- hey - emacs - this is a perl file

# Copyright (c) 2021, PostgreSQL Global Development Group

# tools/msvc/clean.pl


use strict;
use warnings;
use File::Path qw( make_path rmtree ); 
use Cwd;

my $current_dir = `cd`;
$current_dir = _trim($current_dir);

if (-d "msvs32\\x64") {
    rmtree("msvs32\\x64");
}
if (-d "msvs32\\age") {
    rmtree("msvs32\\age");
}
my $file_name = `dir /b ~m4_in_temp_file*`;
$file_name = _trim($file_name);
if (-f $file_name) {
    unlink($file_name);
}
$file_name = `dir /b ~m4_out_temp_file*`;
$file_name = _trim($file_name);
if (-f $file_name) {
    unlink($file_name);
}
chdir("msvs32") if (-d "src");
if (-f "*.vcxproj.user") {
    unlink("*.vcxproj.user");
}
if (-f "*.suo") {
    unlink("*.suo");
}

sub _trim {
    my $data = shift;

    return '' unless defined $data;

    $data =~ s/^\s+//;
    $data =~ s/\s+$//;
    return $data;
}