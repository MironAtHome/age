use strict;
use warnings;

use Carp;
use if ($^O eq "MSWin32"), 'Win32';
use Cwd;
use File::Copy;
use File::Spec;
use List::Util qw(first);

sub test_join
{
	my $dir = join("test", "include\\server\\port\\win32_msvc");
	print "$dir \n";
    return;
}

test_join();