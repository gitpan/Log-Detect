# $Revision: #15 $$Date: 2004/08/26 $$Author: ws150726 $
# DESCRIPTION: Perl ExtUtils: Type 'perl Makefile.PL' to create a Makefile for this package
#
# Copyright 2001-2004 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

require 5.005;
use ExtUtils::MakeMaker;
use Carp;

sub MY::postamble {
"
DIST_DEFAULT += manifest

README: readme.texi
	-rm \$@
	makeinfo \$< --output \$@ --no-headers --no-validate

## Maintainer use:
preexist:
	test ! -r \$(HOME)/src/kits/\$(DISTVNAME).tar.gz

tag:
	c4 label -d     \$(DISTNAME)_\$(VERSION_SYM) || true
	c4 label        \$(DISTNAME)_\$(VERSION_SYM)
	c4 labelsync -l \$(DISTNAME)_\$(VERSION_SYM) ...
#	cvs tag -F      \$(DISTNAME)_\$(VERSION_SYM) .

maintainer-diff:
	c4 diff     ...@\$(DISTNAME)_\$(VERSION_SYM) 

maintainer-dist: preexist dist tag
	cp \$(DISTVNAME).tar.gz \$(HOME)/src/kits
	mv \$(DISTVNAME).tar.gz \$(HOME)/backpack

maintainer-clean: distclean
	-rm README

maintainer-copy: README

clean::
	-rm -rf test_dir
";
}

WriteMakefile(
	      VERSION_FROM => 'lib/Log/Detect.pm',
	      DISTNAME  => 'Log-Detect',
	      NAME      => 'Log::Detect',
	      AUTHOR	=> 'Wilson Snyder <wsnyder@wsnyder.org>',
	      ABSTRACT  => 'Parse logfiles to detect errors',
	      EXE_FILES => [qw(vtrace)],
	      PREREQ_PM => {'IO::Zlib' => 1.01,
			    'Compress::Zlib' => 1.16,	# Needed by IO::Zlib, but I hate deps under deps!
			},
	      'dist'    => {COMPRESS => 'gzip -9f',
			    SUFFIX   => '.gz', 
			    DIST_DEFAULT => 'README all tardist',
			},
	      );

