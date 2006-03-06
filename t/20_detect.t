#!/usr/bin/perl -w
# $Id: 20_detect.t 15289 2006-03-06 15:45:36Z wsnyder $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2006 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License or the Perl Artistic License.

use strict;
use Test;
use File::Copy;

BEGIN { plan tests => 9 }
BEGIN { require "t/test_utils.pl"; }

copy ("example/test.log","test_dir");

use Log::Detect;
ok(1);

my $d = new Log::Detect ();
ok($d);

$d->add_regexp(ignore=>qr/Ignore/i);	# Ignore messages with 'ignore' in them
ok(1);

$d->read(filename=>"test_dir/test.log");
ok(1);

print "write_append()\n";
$d->write_append(filename=>"test_dir/test_append.log");
ok(-r "test_dir/test_append.log");

print "write_dino()\n";
$d->write_dino(dino=>"test_dir/test.dino");
ok(-r "test_dir/test.dino");
ok(compare_files "example/test.dino", "test_dir/test.dino");

print "write_simvision()\n";
$d->write_simvision(simvision=>"test_dir/test.simvision");
ok(-r "test_dir/test.simvision");
ok(compare_files "example/test.simvision", "test_dir/test.simvision");

