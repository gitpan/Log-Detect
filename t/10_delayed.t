#!/usr/bin/perl -w
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2009 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License or the Perl Artistic License.

use strict;
use Test;

BEGIN { plan tests => 8 }
BEGIN { require "t/test_utils.pl"; }

use Log::Delayed;
ok(1);

unlink("test_dir/.status");

my $Delayed = new Log::Delayed (filename=>"test_dir/.status");
ok(1);

if ($ENV{HARNESS_ACTIVE}) {
    open(STDERR, '>/dev/null');
}
die_delayed ("First error into .status\n");
die_delayed ("This will get reported later.\n");
die_delayed ("As will this,\n");
die_delayed ("And this,\n");
ok(1);

ok ($Delayed->errors());
if ($Delayed->errors()) {
    print "We got a error\n";
}

$Delayed->write_status();
ok(1);

my $current_status = $Delayed->read_status();
print "Read status: $current_status\n";
ok($current_status =~ /First error/);

# Clear error status
ok(!$Delayed->errors(0));

$Delayed->exit_if_error();
ok(1);
