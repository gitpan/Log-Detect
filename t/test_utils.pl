#!/usr/local/bin/perl -w
#DESCRIPTION: Perl ExtUtils: Common routines required by package tests

use vars qw($PERL);

$PERL = "$^X -Iblib/arch -Iblib/lib";

mkdir 'test_dir',0777;

if (!$ENV{HARNESS_ACTIVE}) {
    use lib '.';
    use lib '..';
    use lib "blib/lib";
    use lib "blib/arch";
}

sub run_system {
    # Run a system command, check errors
    my $command = shift;
    print "\t$command\n";
    system "$command";
    my $status = $?;
    ($status == 0) or die "%Error: Command Failed $command, $status, stopped";
}

sub wholefile {
    my $file = shift;
    my $fh = IO::File->new ($file) or die "%Error: $! $file";
    my $wholefile = join('',$fh->getlines());
    $fh->close();
    return $wholefile;
}

sub compare_files {
    my $filename1 = shift;
    my $filename2 = shift;
    # Ok, let's make sure the right data went through
    my $f1 = wholefile ($filename1) or die;
    my $f2 = wholefile ($filename2) or die;
    my @l1 = split ("\n", $f1);
    my @l2 = split ("\n", $f2);
    for (my $l=0; $l<($#l1 | $#l2); $l++) {
	next if $l1[$l] =~ /created auto/i;
	if ($l1[$l] ne $l2[$l]) {
	    warn "$filename1 != $filename2: Line $l mismatches\n$l1[$l]\n$l2[$l]\n";
	    return 0;
	}
    }
    return 1;
}

1;
