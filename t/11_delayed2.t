#!/usr/bin/perl -w
# $Revision: #4 $$Date: 2004/06/21 $$Author: ws150726 $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2004 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

use strict;
use Test;

BEGIN { plan tests => 6 }
BEGIN { require "t/test_utils.pl"; }

use Log::Delayed;
ok(1);

unlink("test_dir/.status");

my $Delayed = new Log::Delayed (filename=>"test_dir/.status",
				 status=>undef,
				 overwrite=>0,);
ok($Delayed->status() =~ /Missing/);

$Delayed->die_delayed ("First error into .status\n");
ok($Delayed->status() =~ /First error/);

$Delayed->errors(0);
ok($Delayed->status() =~ /Missing/);

$Delayed->completed();
ok($Delayed->status() =~ /^Completed/);

$Delayed->write_status();
ok(!-r "test_dir/.status");  # Not written because no error and overwrite=>0,
