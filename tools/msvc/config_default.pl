
# Copyright (c) 2021, PostgreSQL Global Development Group

# Configuration arguments for vcbuild.
use strict;
use warnings;

our $config = {
	asserts => 0,    # --enable-cassert

	# blocksize => 8,         # --with-blocksize, 8kB by default
	# wal_blocksize => 8,     # --with-wal-blocksize, 8kB by default
	perl      => 1,    # --with-perl=<path>
};

1;
