# -*-perl-*- hey - emacs - this is a perl file

# Copyright (c) 2021, PostgreSQL Global Development Group

# tools/msvc/pgflex.pl

use strict;
use warnings;
use File::Basename;

# assume we are in the postgres source root
my $input = shift;
    
do ('.\tools\msvc\config.pl') if -e ".\\tools\\msvc\\config.pl";

my ($flexver) = `flex.exe -V`;    # grab first line
$flexver = (split(/\s+/, $flexver))[1];
$flexver =~ s/[^0-9.]//g;
my @verparts = split(/\./, $flexver);
unless ($verparts[0] == 2
	&& ($verparts[1] > 5 || ($verparts[1] == 5 && $verparts[2] >= 31)))
{
	print "WARNING! Flex install not found, or unsupported Flex version.\n";
	print "echo Attempting to build without.\n";
	exit 0;
}


if ($input !~ /\.l$/)
{
	print "Input must be a .l file\n";
	exit 1;
}
elsif (!-e $input)
{
	print "Input file $input not found\n";
	exit 1;
}

(my $output = $input) =~ s/\.l$/.c/;

my $ProcessObj;
unlink($output) if (-f $output);
my $result = 0;
system("flex --wincompat --outfile=$output $input");

# Check for "%option reentrant" in .l file.
my $lfile;
open($lfile, '<', $input) || die "opening $input for reading: $!";
my $lcode = <$lfile>;
close($lfile);
if ($lcode =~ /\%option\sreentrant/)
{

	# Reentrant scanners usually need a fix to prevent
	# "unused variable" warnings with older flex versions.
	#system("perl tools\\msvc\\fix-old-flex-code.pl $output");
	print ("wanted to fix-old-flex-code");
}
else
{

	# For non-reentrant scanners we need to fix up the yywrap
	# macro definition to keep the MS compiler happy.
	# For reentrant scanners (like the core scanner) we do not
	# need to (and must not) change the yywrap definition.
	my $cfile;
	my @lines = ();
	open($cfile, '<', $output) || die "opening $output for reading: $!";
	foreach my $line (<$cfile>) {
		push(@lines, $line);
	}
	close($cfile);
	for(my $x=0; $x < (scalar @lines); $x++) {
		 $lines[$x] =~ s/\byywrap\(n\)/yywrap()/g;
	}
	open($cfile, '>', $output) || die "opening $output for writing: $!";
	foreach my $line (@lines) {
	    print ($cfile $line);
	}
	close($cfile);
}

my $lexback = "lex.backup";

if (-f $lexback) {
	unlink ($lexback);
}

exit 0;

#sub ErrorReport{
#    print Win32::FormatMessage( Win32::GetLastError() );
#}