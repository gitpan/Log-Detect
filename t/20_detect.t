#!/usr/local/bin/perl -w
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package

use strict;
use Test;
use File::Copy;

BEGIN { plan tests => 7 }
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

