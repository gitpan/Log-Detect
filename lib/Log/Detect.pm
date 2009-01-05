# Log::Detect - Detect errors in logfiles
# See copyright, etc in below POD section.
######################################################################

package Log::Detect;
use Carp;
use Class::Struct;
use File::Basename;
use IO::File;
use IO::Zlib;
use Text::Wrap;

use strict;
use vars qw($VERSION %Default_Params);

$VERSION = '1.423';

(my $prog = $0) =~ s/^.*\///;

%Default_Params =
    ( dino => undef,
      simvision => undef,
      program => $prog,
      time_regexp => qr/\[([0-9 ]+)\]/,	# Regexp to extract time in $1
      warn_fatal => 1,
      warn_finish => 0,
      report_limit => 0,
      );

sub add_regexp_defaults {
    my $self = shift;
    #                 Action  => qr/REGEXP/,
    $self->add_regexp(error   => qr!aborted due to compilation errors!);	# Perl
    $self->add_regexp(error   => qr/(?i)%E|\bError ?[:!-\#]|Fatal ?[:!-]|\] Error [0-9]/);
    $self->add_regexp(warning => qr/Stopping due to warnings/i);  # Actually a warning, not error, so first
    $self->add_regexp(warning => qr/\bWarning ?[:!-\#]/i);
    $self->add_regexp(warning => qr/%W/i);
    $self->add_regexp(finish  => qr/\*-\* All Finished \*-\*/);
}

######################################################################
#### Creation

sub new {
    my $class = shift;
    my $self = {_lines => [],
		_regexps => [],
		_compiled_err_regexps => undef,
		_compiled_ign_regexps => undef,
		_parse_filename => "",
		_parse_lineno => 1,
		_parse_remainder => "",
		%Default_Params,
		};  # No @_, that's handled with set(@_) below
    bless $self, $class;
    $self->clear();
    $self->add_regexp_defaults();
    $self->set (@_);
    return $self;
}

sub clear {
    my $self = shift;
    $self->{_lines} = [];
}

sub set {
    my $self = shift;
    while (@_) {
	my $param = shift; my $value = shift;
	(exists $self->{$param}) or confess ("%Error: $param isn't valid Log::Detect member variable, stopped");
	$self->{$param} = $value;
    }
}

######################################################################
#### Regexp handling

sub clear_regexps {
    my $self = shift;
    $self->{_compiled_err_regexps} = undef;
    $self->{_compiled_ign_regexps} = undef;
    $self->{_regexps} = [];
}

sub add_regexp {
    my $self = shift;
    my @regexppairs = @_;
    my $numargs = $#regexppairs + 1;
    return if ($numargs <= 0);
    confess("%Error:  Cannot call add_regexp() with an odd number of arguments ($numargs)!") if ($numargs % 2);

    $self->{_compiled_err_regexps} = undef;
    $self->{_compiled_ign_regexps} = undef;

    my ($pack, $filename, $lineno) = caller(0);

    for (my $i=0; $i<=$#regexppairs; $i+=2) {
	my $action = $regexppairs[$i];
	my $re     = $regexppairs[$i+1];
	my $regexpref = [$re, $action, $filename, $lineno];
	if (!ref $re) { $re = qr/$re/; }   # Precompile it.
	bless $regexpref, 'Log::Detect::Regexp';
	push @{$self->{_regexps}}, $regexpref;
    }
}

sub _compile_regexps {
    my $self = shift;
    # Given the list of regular expressions, split it into two parts,
    # the ignores, which only need to be matched if something else is found
    # and everything else.
    # We only need to do this when the regexps change, so we cache the results.
    return if $self->{_compiled_err_regexps};
    # Sort by category
    my %re_by_action;
    foreach my $reref (@{$self->{_regexps}}) {
	$re_by_action{$reref->action} ||= [];
	push @{$re_by_action{$reref->action}}, $reref;
    }
    # Put categories into specific order
    $self->{_compiled_ign_regexps} = [@{$re_by_action{ignore}||[]}];
    $self->{_compiled_err_regexps} = [@{$re_by_action{error}||[]},
				      @{$re_by_action{warning}||[]},
				      @{$re_by_action{finish}||[]},];
    foreach (qw(ignore error warning finish)) { delete $re_by_action{$_}; }
    # Add any user defined categories
    foreach my $action (keys %re_by_action) {
	push @{$self->{_compiled_err_regexps}}, @{$re_by_action{$action}};
    }
    #use Data::Dumper; print Dumper($self->{_regexps});
    #use Data::Dumper; print Dumper($self->{_compiled_err_regexps});
    #use Data::Dumper; print Dumper($self->{_compiled_ign_regexps});
}

######################################################################
#### Block by block Reading Functions

sub parse_start {
    my $self = shift;
    my %params = (#filename=>,
		  lineno=>1,
		  @_);
    $params{filename} or croak "%Error: parse_start filename not specified,";
    $self->{_parse_filename} = $params{filename};
    $self->{_parse_lineno} = $params{lineno};
    $self->{_parse_remainder} = "";

    $self->_compile_regexps if !$self->{_compiled_err_regexps};
}

sub parse_text {
    my $self = shift;
  text:
    foreach my $text (@_) {
	my $line = $text;
	$line = $self->{_parse_remainder}.$text if length $self->{_parse_remainder};
	my $eol = index $line,"\n";
	if ($eol<0) {
	    # Remember, and keep going until we get our newline
	    $self->{_parse_remainder} = $line;
	} else {
	    # All up to the newline is the line we pass, the rest is the remainder.
	    $self->{_parse_remainder} = substr($line,$eol+1);
	    $self->{_parse_lineno}++;
	    $line = substr($line,0,$eol+1);
	    # Finally a whole line!  Deal with it.
	    next text if ($line =~ /^\s*$/m);	# Short circuit
	    foreach my $reref (@{$self->{_compiled_err_regexps}}) {
		my $re = $reref->[0];
		if ($line =~ /$re/) {
		    # Now we need to see if it's ignored.
		    foreach my $ireref (@{$self->{_compiled_ign_regexps}}) {
			my $ire = $ireref->[0];
			next text if ($line =~ /$ire/);
		    }
		    #print "MATCH: ".$reref->action."  $line\n" if $Debug;
		    my $actref = [$self->{_parse_lineno} - 1,   # We preincremented
				  $self->{_parse_filename},
				  $reref->action, $line, $reref];
		    bless $actref, 'Log::Detect::Action';
		    push @{$self->{_lines}}, $actref;
		    next text;
		}
	    }
	}
    }
}

sub parse_eof {
    my $self = shift;
    $self->parse_text("\n");
}

######################################################################
#### Whole File Reading Functions

sub read {
    my $self = shift;
    my %params = (%{$self},
		  @_);

    my $filename = $params{filename};
    defined $filename or croak "%Error: No filename=> specified, stopped";
    $self->{filename} = $filename;

    $self->parse_start(filename=>$filename, lineno=>1);

    # We're going to reference them a lot, so make them local
    my @err_regexps = @{$self->{_compiled_err_regexps}};
    my @ign_regexps = @{$self->{_compiled_ign_regexps}};

    my $fh;
    if ($filename =~ m/\.gz$/) {
	$fh = IO::Zlib->new();
    } else {
	$fh = IO::File->new();
    }
    $fh->open($filename, "r") or die "%Error: $! $filename\n";
  line:
    while (my $line = $fh->getline()) {
	# We could call $self->parse_text, but it's much faster to inline it.
	next line if ($line =~ /^\s*$/m);	# Short circuit
	foreach my $reref (@err_regexps) {
	    my $re = $reref->[0];
	    if ($line =~ /$re/) {
		# Now we need to see if it's ignored
		foreach my $ireref (@ign_regexps) {
		    my $ire = $ireref->[0];
		    next line if ($line =~ /$ire/);
		}
		#print "MATCH: ".$reref->action."  $line\n" if $Debug;
		my $actref = [$., $filename, $reref->action, $line, $reref];
		bless $actref, 'Log::Detect::Action';
		push @{$self->{_lines}}, $actref;
		next line;
	    }
	}
    }
    $fh->close;
    $self->parse_eof;
    #use Data::Dumper; print Dumper($self);
}

######################################################################
#### Accessors

sub actions {
    my $self = shift;
    return @{$self->{_lines}};
}

sub filename {
    $_[0]->{filename} = $_[1]  if ($#_ > 0);
    return $_[0]->{filename};
}

sub actions_sorted_line {
    my $self = shift;
    #We currently add to the array in sorted order, so...
    return @{$self->{_lines}};
    #return (sort {$a->lineno() <=> $b->lineno()}
    #        @{$self->{_lines}});
}

sub actions_sorted_limited {
    my $self = shift;
    if (!$self->{report_limit} || $#{$self->{_lines}} <= $self->{report_limit}) {
	return $self->actions_sorted_line;
    }
    my @lines;
    foreach my $actref (@{$self->{_lines}}) {
	if ($#lines == $self->{report_limit}) {
	    my $line = $actref->text;
	    $line =~ s/.*($self->{time_regexp}).*/$1/;
	    $line =~ s/[\n\r]*//mg;
	    $line .= " %Error: Additional warnings and errors were suppressed.";
	    my $newref = [$actref->lineno, $actref->filename, $actref->action, $line];
	    bless $newref, 'Log::Detect::Action';
	    push @lines, $newref;
	    last;
	}
	push @lines, $actref;
    }
    return @lines;
}

######################################################################
#### Result Functions

sub write_stderr {
    my $self = shift;
    my ($stat,$sum) = $self->summary();
    if (defined $sum) {
	print STDERR $sum;
    }
}

sub write_append {
    my $self = shift;
    my %params = (%{$self},
		  @_);

    my $filename = $params{filename};
    defined $filename or croak "%Error: No filename=> specified, stopped";

    my ($stat,$sum) = $self->summary();
    if (defined $sum) {
	my $fh = new IO::File;
	$fh->open (">>$filename") or die "%Error: $! $filename\n";
	print $fh $sum;
	$fh->close();
    }
}

sub summary {
    my $self = shift;
    # Return (message, lines with errors).
    # Returns UNDEF if no errors
    my @out = ();
    my $first_error;
    my $first_warn;
    my $first_finish;
    foreach my $actref ($self->actions_sorted_line()) {
	$first_error = $actref if (!$first_error && $actref->action eq 'error');
	$first_warn  = $actref if (!$first_warn && $actref->action eq 'warning');
	$first_finish = $actref if (!$first_finish && $actref->action eq 'finish');
	if ($actref->action eq 'error' || $actref->action eq 'warning') {
	    push @out, $actref->text;
	}
    }

    my $result_message = undef;
    if ($first_error) {
	unshift @out, $self->{program}.": Stopped, Errors detected in $self->{filename}:\n";
	$result_message = $first_error->text();
    } elsif ($first_warn) {
	if ($self->{warn_fatal}) {
	    unshift @out, $self->{program}.": Stopped, Warnings detected in $self->{filename}:\n";
	    $result_message = $first_warn->text();
	} else {
	    unshift @out, $self->{program}.": Warnings detected in $self->{filename}:\n";
	}
    } elsif (!$first_finish && $self->{warn_finish}) {
	unshift @out, $self->{program}.": Stopped, Missing all-finished in $self->{filename}\n";
	$result_message = "Missing all-finished";
    }
    return (undef,undef) if ($#out < 0);

    unshift @out, "\n".("-"x70)."\n";
    return ($result_message, (join '',@out));
}

sub actions_dump {
    my $self = shift;
    my %params = (#basename => undef,	# Take the basename of the filenames
		  @_);
    # Return textual summary of actions, for debugging
    my @out = ();
    foreach my $actref ($self->actions_sorted_line) {
	# The act is here to make it not match the standalone word error
	my $rfn = $actref->regexp->filename;
	$rfn=File::Basename::basename($rfn) if $params{basename};
	push @out, sprintf("Log::Detect match: %s:%d: Causes act%s due to %s:%d\n",
			   $actref->filename, $actref->lineno,
			   $actref->action,
			   $rfn, $actref->regexp->lineno,
			   );
    }
    return (wantarray ? @out : join('',@out));
}

sub write_dino {
    my $self = shift;
    my %passed_params = (@_);
    my %params = (error_color => 2,
		  warning_color => 7,
		  %{$self},
		  @_);
    local $Text::Wrap::columns = 50;

    my $filename = $passed_params{filename} || $params{dino};
    defined $filename or croak "%Error: No filename=> specified, stopped";
    my $fh = IO::File->new (">$filename") or croak "%Error: $! $filename\n";

    print $fh "# Dinotrace\n";
    print $fh "# Created automagically by Log::Detect\n";

    print $fh "\n";
    print $fh "# Error/Warning cursors\n";
    # Add in reverse order so earlier messages overwrite later
    foreach my $actref (reverse ($self->actions_sorted_limited())) {
	my $text = $actref->text;
	chomp $text;
	my $comment = $text;
	$comment =~ /$params{time_regexp}/;
	my $time = $1 || 0;
	my $color = ((  ($actref->action() eq 'error') && $params{error_color})
		     ||(($actref->action() eq 'warning') && $params{warning_color})
		     );
	print $fh "#$text\n";
	if ($time && $color) {
	    $comment =~ s/\s+/ /g;
	    $comment = Text::Wrap::wrap ('','',$comment);
	    $comment =~ s/\n/\\n/g;	# Use \n for newlines
	    $comment =~ s/\"/\\\"/g;	# Quote the quotes
	    print $fh "cursor_add $time $color \"$comment\"\n";
	}
	print $fh "\n";
    }
    print $fh "\n";
    $fh->close();
}

sub write_simvision {
    my $self = shift;
    my %passed_params = (@_);
    my %params = (error_prefix   => "%E:",
		  warning_prefix => "%W:",
		  timescale => "",	# ns, etc to suffix time with
		  %{$self},
		  @_);

    my $filename = $passed_params{filename} || $params{simvision};
    defined $filename or croak "%Error: No filename=> specified, stopped";
    my $fh = IO::File->new (">$filename") or croak "%Error: $! $filename\n";

    print $fh "# Simvision Command Script\n";
    print $fh "# Created automagically by Log::Detect\n";

    print $fh "\n";
    print $fh "# Error/Warning cursors\n";
    # Add in reverse order so earlier messages overwrite later
    my %dup;
    foreach my $actref (reverse ($self->actions_sorted_limited())) {
	my $text = $actref->text;
	chomp $text;
	my $comment = $text;
	$comment =~ /$params{time_regexp}/;
	my $time = $1 || 0;
	# We add a prefix, because simvision doesn't let us change the color.  Yuk.
	my $prefix = ((  ($actref->action() eq 'error') && $params{error_prefix})
		      ||(($actref->action() eq 'warning') && $params{warning_prefix})
		      );
	next if $dup{$time.$text};  $dup{$time.$text} = 1;
	print $fh "#$text\n";
	if ($time && $prefix) {
	    $comment =~ s/[^a-zA-Z---0-9%!@^&*()+|;:,.<>?~]/ /g;	# Quote meta characters
	    $comment =~ s/\s+/ /g;
	    $comment =~ s/^\s+//;
	    $comment =~ s/\s+$//;
	    my $sv_marker = $prefix.$comment;
	    # Always have a leading % sign, so we can recognize all automatic markers
	    $sv_marker = "%".$sv_marker if $sv_marker !~ /^%/;
	    my $sv_time = $time.$params{timescale};
	    print $fh "if {[catch {marker new -name {$sv_marker} -time $sv_time}] != \"\"} {\n";
	    print $fh "    marker set -using {$sv_marker} -time $sv_time\n";
	    print $fh "}\n";

	}
	print $fh "\n";
    }
    print $fh "\n";
    $fh->close();
}

######################################################################
######################################################################
######################################################################
#### Action class

struct('Log::Detect::Action'
       # read() requires this order; for speed it doesn't call new
       =>[lineno     	=> '$', #'	# Line number from
	  filename 	=> '$', #'	# Filename this came from
	  action 	=> '$', #'	# Action decoded
	  text		=> '$', #'	# Text on that line
	  regexp	=> '$', #'	# Matching Log::Detect::Regexp reference
	  ]);

######################################################################
######################################################################
######################################################################
#### Regexp class

# Internal code (only) assumes the regexp is in [0]
struct('Log::Detect::Regexp'
       =>[regexp	=> '$', #'	# Reference to regular expression
	  action 	=> '$', #'	# Action desired
	  filename 	=> '$', #'	# Filename this came from
	  lineno     	=> '$', #'	# Line number from
	  ]);

######################################################################
#### Package return
1;
__END__

=pod

=head1 NAME

Log::Detect - Read logfiles to detect error and warning messages

=head1 SYNOPSIS

use Log::Detect;
my $d = new Log::Detect ();
$d->read(filename=>"test_dir/test.log");
$d->write_stdout();
$d->write_append();

=head1 DESCRIPTION

Log::Detect is used to read logfiles, and apply regexps to determine if the
logfile contains any errors or warning messages.  This is generally useful
for those programs that refuse to return bad exit status when they should.

Log::Detect can also append a summary of all errors and warnings to the
logfile, to a different file, or to the screen.

=head1 VARIABLES

These variables may be specified with the new function, or with the set
function.  Most member functions also accept any of these variables when
they are called.

=over 4

=item dino

The default filename for write_dino.

=item simvision

The default filename for write_simvision.

=item program

The name of the program to prepend to error messages.  Defaults to $0.

=item time_regexp

A regexp where $1 returns the timestamp.  Used by write_dino and
write_simvision only.

=item warn_fatal

If true, warnings are considered fatal errors.  Defaults true.

=item warn_finish

If true, lack of a regexp matching 'finish' is considered fatal.

=back

=head1 FUNCTIONS

=over 4

=item $det->actions

Returns the list of parsed actions.  Each list element is a reference to a
Log::Detect::Action, which has four accessor functions.  lineno is the line
number the message was detected on.  filename is the file the error came
from.  action is the action specified with the regexp.  text is the line
itself.

=item $det->actions_dump

Return string summary of all matching actions.

=item $det->actions_sorted_line

Returns the parsed actions, sorted by line number.

=item $det->actions_sorted_limited

Returns the parsed actions, sorted by line number.  Contains a maximum of
report_limit number of errors.

=item $det->add_regexp

Prepends new rules to the regexp list.

The regexps are matched against the text in order, with the first match
action determining the result.

For example, the default:
      (warning => qr/Stopping due to warnings/i);
      (error   => qr/(?i)%E|\bError ?[:!-]|Fatal ?[:!-]|\] Error [0-9]/);
      (warning => qr/%W/i);
      (warning => qr/\bWarning ?[:!-]/i);
      (finish  => qr/\*-\* All Finished \*-\*/);

Specifies that a line matching "stopping due to warnings" is a warning, as
is any line with %W (VMS's error messages).  A %E on a matching line is
signaled as an error.  As the rules are done in order, if the file has the
line '%E stopping due to warnings', which matches both the "%E" and the
"stopping due to warnings" regexps, the first match wins, and thus the
action indicates a warning, not an error.

=item $det->clear

Clears the list of parsed actions, as if a read had never occurred.

=item $det->clear_regexps

Clears the list of regular expressions.

=item $det->new

Constructs the class.  Any variables described above may be passed to the
constructor.

=item $det->parse_eof

Call when the current parse_text is complete, and any partially completed
messages should be emptied out.

=item $det->parse_text(I<text>...)

Parse_text will check any parameters for error messages.  If complete lines
are not given, the line is buffered until more arrives.

You must call parse_start before the first call to this function, and must
call parse_eof to avoid missing an error that is not newline terminated at
the end of the file.

=item $det->parse_start( filename=>, lineno=> )

Called to indicate future calls will be made to parse_text.

=item $det->read

Read parses the logfile specified with filename=>.  Each line is compared
against the regular expressions in turn, forming a list of actions.

=item $det->set

Set takes a named parameter list and sets those variables.

=item $det->summary

summary returns a two element list.  The first element is a text message
describing if errors or warnings were found.  The second contains the text
lines from the file which had errors or warnings.

=item $det->write_append

write_append appends to a file, by default the same exact logfile, any
errors or warnings that were found.

=item $det->write_dino

write_dino prints to a file Dinotrace annotations for any errors or
warnings that were found in the logfile.

=item $det->write_simvision

write_simvision prints to a file Simvision annotations for any errors or
warnings that were found in the logfile.

=item $det->write_stderr

write_stderr prints to the screen any errors or warnings that
were found in the logfile.

=back

=head1 DISTRIBUTION

Log-Detect is part of the L<http://www.veripool.org/> free EDA software
tool suite.  The latest version is available from CPAN and from
L<http://www.veripool.org/>.

Copyright 2000-2009 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License or the Perl Artistic License.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<Log::Delayed>, L<vtrace>

=cut
