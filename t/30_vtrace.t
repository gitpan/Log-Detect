#!/usr/bin/perl -w
# $Revision: #7 $$Date: 2004/06/21 $$Author: ws150726 $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2004 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

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
ok(compare_files "example/vtrace.log_out", "test_dir/vtrace.log");
