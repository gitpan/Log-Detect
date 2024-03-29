#!/usr/bin/perl -w
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2009 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License Version 3 or the Perl Artistic License Version 2.0.

use strict;
use Test;
use File::Copy;

BEGIN { plan tests => 4 }
BEGIN { require "t/test_utils.pl"; }

copy ("example/test.log","test_dir/vtrace.log");
run_system ("${PERL} ./vtrace --append --warnfinish"
	    ." --dino=test_dir/vtrace.dino"
	    ." --result=test_dir/vtrace.status"
	    ." test_dir/vtrace.log"
	    ." || true"  # else run_system won't like exit status
	    );

ok(1);
ok(-r "test_dir/vtrace.dino");
ok(-r "test_dir/vtrace.status");
ok(files_identical "example/vtrace.log_out", "test_dir/vtrace.log");
