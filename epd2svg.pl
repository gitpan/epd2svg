#!/usr/bin/perl
# Require Perl5
#
# epd2svg -- EPD to SVG
#
# by SANFACE Software <sanface@sanface.com> 10 July 2000
#
# This is version 0.9
#
use strict;
use Getopt::Long;
use File::Basename;
use File::Find;
use File::DosGlob 'glob';

my $version="0.9";
my $producer="epd2svg";
my $companyname="SANFACE Software";
my $epd2svgHome="http://EPD.sourceforge.net/";
my $SANFACEmail="mailto:sanface\@sanface.com";
my $help=0; my $verbose=0; my $recursive=""; my $match="";
my $input=""; my $output=""; my $stdin=0;
my $bboxX1=0; my $bboxY1=0; my $bboxX2=0; my $bboxY2=0; my $bboxW=0; my $bboxH=0;
my $colorstroke="none"; my $colorfill="none";
my $col1=0; my $col2=0; my $col3=0;
my $path=0; my $pathstring="";

&GetOptions("help"         => \$help,
            "recursive=s"  => \$recursive,
            "match=s"      => \$match,
            "verbose"      => \$verbose) || printusage();

$help and printusage();

sub wanted {
  if ($File::Find::name=~/$match/) {
    push @ARGV,$File::Find::name;
    }
  }

if ($match && !$recursive) {
   print "You can use -match option only with -recursive option\n";
   exit;
   }

if ($recursive) {
  $match=~s/\./\\./g;
  $match=~s/\*/.*/g;
  $match=~s/\?/./g;
  $match=~s/$/\$/;
  find (\&wanted,"$recursive");
  }

if (@ARGV) {
  my @files;
  if ($^O =~ /^MSWin32$/i && !$recursive) {@files = glob($ARGV[0])}
  else {@files = @ARGV}
  foreach $input (@files) {
    $verbose and print "Processing $input file\n";
    if ($stdin) {open (OUT, ">-") || die "$producer: couldn't open standard output\n"}
    else {
      $output=$input;
      my $out=basename($output,"");
      if ($out=~/(.*)\..*/) {$out=~s/(.*)\..*/$1\.svg/;}
        else {$out.=".svg";}
      $output=dirname($output,"");
  
      if ($^O =~ /VMS/ ) {
# On OpenVMS: Also don't add '/' if dir ends in ']' or ':'
#    e.g. VMS filepecs look like
        $output.="/" if ($output !~ /(\/|\\|]|:)$/ );
      } elsif ($^O eq 'MacOS') {
        $output.=":" if ($output !~ /:$/ ); # macs are a bit different...
      } else {
# concat '/' only if dir doesn't already end in a '/' or '\\'
        $output.="/" if ($output !~ /(\/|\\)$/ );
      }
      $output.=$out;
      open (OUT, ">$output") || die "$producer: couldn't open output file $output\n";
    }
    binmode OUT;
    &Match($input);

    close(OUT);
    # a simple user-interface enhancement
    # make a MacOS double-clickable file
    if ($^O eq 'MacOS') {MacPerl::SetFileInfo('CARO','SVG ', $output)}
    $verbose and print "Writing $output file\n";
    }
  } else {printusage();}

sub Match {
  my $file=shift(@_);

  my $i;
  my $temporary;
  print OUT qq!<?xml version="1.0" standalone="yes"?>\n!;
  print OUT <<EPD2SVGmark;
<!-- ====================================================================== -->
<!-- Filename: $output                                                      -->
<!-- Producer: $producer $version                                           -->
<!-- Author: SANFACE Software                                               -->
<!-- http://www.sanface.com/                                                -->
<!-- $epd2svgHome                                                           -->
<!-- Date: September 19, 2000                                               -->
<!-- ====================================================================== -->

EPD2SVGmark

# INSERISCI la data corrente

  open (IN, "$file") || die "$producer: couldn't open input file $file\n";
  while (<IN>) {
    if (/ *#(.*)/) {print OUT "<!-- $1 -->\n";next;}
    if (/BBox\((.*),(.*),(.*),(.*)\)/)
      {
      $bboxX1=$1;
      $bboxY1=$2;
      $bboxX2=$3;
      $bboxY2=$4;
      $bboxW=int($bboxX2-$bboxX1);
      $bboxH=int($bboxY2-$bboxY1);
      print OUT qq!<svg width="$bboxW" height="$bboxH"\n  xmlns = 'http://www.w3.org/2000/svg-20000303-stylable'>\n!;
      next;
      }
    if (/^ *h *$/ || /^ *f\* *$/) {$pathstring.="z\"/>\n";$path=0;print OUT "$pathstring\n";next;}
# CERCA di vedere meglio FILL and STROKE!!!!
# S stroke
# s e' uguale a h S
# F e f : fill
# B fill and stroke
# b e' uguale a h B
# b*            h B*

    if (/ *(.*) +g/) {$col1=int($1*255);$colorfill="rgb($col1,$col1,$col1)";next;}
    if (/ *(.*) +G/) {$col1=int($1*255);$colorstroke="rgb($col1,$col1,$col1)";next;}
    if (/ *([^ ]*) *([^ ]*) *([^ ]*) +rg/) {$col1=int($1*255);$col2=int($2*255);$col3=int($3*255);$colorfill="rgb($col1,$col2,$col3)";next;}
    if (/ *([^ ]*) *([^ ]*) *([^ ]*) +RG/) {$col1=int($1*255);$col2=int($2*255);$col3=int($3*255);$colorstroke="rgb($col1,$col2,$col3)";next;}
    if (/ *([^ ]*) +([^ ]*) +l/) {&checkpath; $pathstring.="L $1 $2\n";next;}
    if (/ *([^ ]*) +([^ ]*) +m/) {&checkpath; $pathstring.="M $1 $2\n";next;}
    if (/ *([^ ]*) +([^ ]*) +([^ ]*) +([^ ]*) +([^ ]*) +([^ ]*) +c/) {&checkpath; $pathstring.="C $1 $2 $3 $4 $5 $6\n";next;}
#    if (/ *([^ ]*) +([^ ]*) +([^ ]*) +([^ ]*) +re/) {&checkpath; $pathstring.="M $1 $2\nL $1+$3 $2\nL $1+$3 $2+$4\nL $1 $2+$4";next;}
# Ricorda v e y
    }
  close(IN);
  print OUT "</svg>\n";
  }

sub checkpath {
  if ($path eq 0) {
#   transform="matrix(1 0 0 -1 0 height)" da EDF a SVG
    $pathstring=sprintf "<path style=\"stroke:$colorstroke;fill:$colorfill\"\ntransform=\"matrix(1 0 0 -1 %d %d)\"\nd=\"",-$bboxX1,$bboxY1+$bboxH;
    $path=1;
    return;
    }
  }

sub printusage {
    print <<USAGEDESC;

usage:
        $producer [-options ...] list

where options include:
    -help                        print out this message
    -recursive directory         scan recursively the directory
    -match     files             match different files ex. *.epd, a?.*
                                 (require -recursive option)
    -verbose                     verbose
    -                            use STDIN and STDOUT

list:

   with list you can use metacharacters and relative and absolute path 
   name

example:
  $producer -m "a*.epd" -r my_directory

If you want to know more about this tool, you might want
to read the docs. They came together with $producer!

Home: $epd2svgHome

USAGEDESC
    exit(1);
}

=head1 NAME

EPD2SVG - Version 0.9 10th July 2000

=head1 SYNOPSIS

Syntax : epd2svg [-options] files

=head1 DESCRIPTION

EPD2SVG is a very flexible and powerful PERL5 program.
It's a converter from EPD files to SVG format files.  

=head1 Features

EPD2SVG ...

=head1 Options

where options include:
    -help                        print out this message
    -recursive directory         scan recursively the directory
    -match     files             match different files ex. *.epd, a?.*
                                 (require -recursive option)
    -verbose                     verbose
    -                            use STDIN and STDOUT

list:

   with list you can use metacharacters and relative and absolute path 
   name

example:
  epd2svg -m "a*.epd" -r my_directory

-match files -recursive directory: with  these option  you can convert 
all the files in the directory and in every its subdirectories
e.g
epd2svg -m "a*.epd" -r .
to convert  every file  beginning with a and with epd extension to SVG
inside the . directory and in every its subdirectories 

Every file of the list is converted in a SVG file.  If the file has an
extension the extension is changed with .svg extension,  if  the  file
doesn't have an extension the .svg extension is added.

=cut
