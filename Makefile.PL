# $Id: Makefile.PL,v 1.5 2001/05/21 13:51:39 wsnyder Exp $
# DESCRIPTION: Perl ExtUtils: Type 'perl Makefile.PL' to create a Makefile for this package

require 5.005;
use ExtUtils::MakeMaker;
use Carp;

sub MY::postamble {
"
DIST_DEFAULT += manifest

README: readme.texi
	-rm \$@
	makeinfo \$< --output \$@ --no-headers --no-validate

maintainer-dist: dist tag
	cp \$(DISTVNAME).tar.gz \$(HOME)/src/kits
	mv \$(DISTVNAME).tar.gz \$(HOME)/backpack

maintainer-clean: distclean
	-rm README Makefile.PL vtrace

maintainer-copy: README

tag:
	cvs tag -F \$(DISTNAME)_\$(VERSION_SYM) .
";
}

WriteMakefile(
	      VERSION_FROM => 'Log/Detect.pm',
	      DISTNAME  => 'Log-Detect',
	      NAME      => 'Log::Detect',
	      AUTHOR	=> 'Wilson Snyder <wsnyder@wsnyder.org>',
	      ABSTRACT  => 'Parse logfiles to detect errors',
	      EXE_FILES => [qw(vtrace)],
	      'dist'    => {COMPRESS => 'gzip -9f',
			    SUFFIX   => '.gz', 
			    DIST_DEFAULT => 'README all tardist',
			},
	      );

