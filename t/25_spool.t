#!/usr/bin/perl -w
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2009 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License or the Perl Artistic License.

use strict;
use Test;
use Data::Dumper;

BEGIN { plan tests => 4 }
BEGIN { require "t/test_utils.pl"; }

use Log::Detect;
ok(1);

my $d = new Log::Detect ();
ok($d);

$d->parse_start(filename=>$0, lineno=>1);
$d->parse_text("Warning: The First\n");
$d->parse_text("War");
$d->parse_text("ning: The Sec");
$d->parse_text("ond\n");
$d->parse_eof;
ok(1);

my @act = $d->actions;
print Dumper(\@act);
ok( $act[1] && $act[0]->lineno == 1 && $act[1]->lineno == 2);
