#!/usr/local/bin/perl -w
# $Revision: #4 $$Date: 2002/07/16 $$Author: wsnyder $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package

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
