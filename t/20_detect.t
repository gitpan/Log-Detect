#!/usr/bin/perl -w
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2009 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License Version 3 or the Perl Artistic License Version 2.0.

use strict;
use Test;
use File::Copy;
use IO::File;

BEGIN { plan tests => 10 }
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
ok(files_identical "example/test.dino", "test_dir/test.dino");

print "write_simvision()\n";
$d->write_simvision(simvision=>"test_dir/test.simvision");
ok(-r "test_dir/test.simvision");
ok(files_identical "example/test.simvision", "test_dir/test.simvision");

my $fh=IO::File->new(">test_dir/test.act_dump");
$fh->print($d->actions_dump); $fh->close;
ok(files_identical "t/20_act_dump.out", "test_dir/test.act_dump");
