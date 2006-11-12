#!/usr/bin/perl -w
# Build.PL Script for dirvish
# Version 0.7,  Keith Lofstrom,  2006-Nov-11
#
# Last Revision   : $Rev$
# Revision date   : $Date$
# Last Changed by : $Author$
# Stored as       : $HeadURL$
#
# Dirvish is installed with the following three step process:
#
#  perl Build.PL <options>
#  ./Build
#  ./Build install <options>
#
# The default install locations are given in the "install_path" hash.
# You can change these locations with options on the command line of
# Build.PL or Build install, for example:
#
#   perl Build.PL    --install_path share=/usr/local/share
#   ./Build install  --install_path sbin=/usr/local/sbin
#
# other exciting options:
#
#  ./Build fakeinstall <options>  # pretend install (no files moved)
#
#  ./Build realclean        # wipes out all the files made by ./Build.PL and
#                           # ./Build ( _build, blib, and ./Build itself )
#
#  ./Build dist             # produces tar.gz file
#                           # (bug - strips execute permission from Build.PL)
#
# This script will NEVER be run on a non-Unix machine.  It is
# neither complete nor well tested;  it is a placeholder to
# gather comments about my probable misuse of Module::Build . 
# I'm pretty sure I am doing a lot of things the hard way.

use strict                 ;
use Module::Build 0.26     ; # Debian will need to know about dependency

#===========================================================================
# make a subclass with admin features here

my $class = Module::Build->subclass(code => << 'EOF' );  

#--------------------------------------------------------------
# pathdir
#
# process a set of files, changing the path to blib and
# creating any necessary subdirectories, returning a hash
# containing files and targets

sub pathdir {
   my ($self, $ext ) = @_;
   my $files = $self->_find_file_by_type($ext,  'lib');

   use  File::Spec      ;
   use  File::Path      ;
   use  File::Basename  ;

   while (my ($file, $dest) = each %$files) {
      my $to_path = File::Spec->catfile($self->blib, $dest) ;
      File::Path::mkpath(File::Basename::dirname($to_path), 0, 0777);

      $$files{ $file } = $to_path ;   
   }
   return $files ;
}

#--------------------------------------------------------------
# Modify lib files to add configuration

sub process_lib_files {
   my ($self)      = @_;
   my $files       = $self->pathdir( 'lib' );
   my $conf        = $self->{properties}{install_path}{conf}   ;
   
   while ( my ( $sourcefile, $targetfile ) = each  %$files ) {
      open( SOURCEFILE, "<$sourcefile" )
         or die "$0: cannot open $sourcefile for reading, $!";
      open( TARGETFILE, ">$targetfile" )
         or die "$0: cannot open $targetfile for writing, $!";
      while( <SOURCEFILE> ) {
         s(##CONFDIR##)($conf);
         print TARGETFILE ;  # copy rest of file
      }
      close( SOURCEFILE ) or die "$0 cannot close $sourcefile, $!";
      close( TARGETFILE ) or die "$0 cannot close $targetfile, $!";
      $self->make_executable($targetfile);
   }
   $self->add_to_cleanup( values %$files );
}

#--------------------------------------------------------------
# make man pages out of pod files

sub process_adminman_files {
   my ($self)      = @_;
   my $files       = $self->pathdir( 'adminman' );
   my $sect        = 1 ;
   use  Pod::Man ;


   while ( my ( $sourcefile, $targetfile ) = each  %$files ) {
      if(    $targetfile =~ /8$/ ) {
         $sect = 8 ;
      }
      elsif( $targetfile =~ /5$/ ) { 
         $sect = 5 ;
      }
      else {
         $sect = "man" ;
      }
      
      my $parser      = Pod::Man->new(  release=> $VERSION, section => $sect );

      print "$sourcefile ---> $targetfile\n";
      $parser->parse_from_file( $sourcefile, $targetfile );
   }
   $self->add_to_cleanup( values %$files );
}

#---------------------------------------------------------------
# make html pages out of pod files

sub process_adminhtml_files {
   my ($self)      = @_;
   my $files       = $self->pathdir( 'adminhtml' );
   use  Pod::Html ;

   while ( my ( $sourcefile, $targetfile ) = each  %$files ) {
      print "$sourcefile ---> $targetfile\n";
      Pod::Html::pod2html(
         "--title=dirvish",
         "--infile=$sourcefile",
         "--outfile=$targetfile",
      )
   }
   $self->add_to_cleanup( values %$files );

   # for some reason there are left over files called
   # pod2htm*, delete them
   # FIXME
   unlink <pod2htm*> ;
}

EOF

# end of the "class" subclass
#===========================================================================
# instance of the build

my $build = $class->new (

   module_name        => 'dirvish',
   dist_version       => '1.3.1',
   license            => 'open_source',
   create_makefile_pl => 'traditional',

   requires => {
      'perl'                => '>= 5.6.0',
   #  'File::chmod'         => '>= 0.31',
      'File::Find'          => 0,
      'Getopt::Long'        => 0,
      'Time::ParseDate'     => 0,
      'Time::Period'        => 0,
   },

   install_path => { 
      conf                  => '/etc/dirvish',
      share                 => '/usr/share',
      sharedoc              => '/usr/share/doc',
      man5dir               => '/usr/share/man/man5',
      man8dir               => '/usr/share/man/man8',
      sbin                  => '/usr/sbin',
   },

   #lib files with CONFIG location processing
   lib_files => {
     'DirvishHack.pm'      => 'lib/DirvishHack.pm',
   },

   # app files with no processing
   sbin_files => {
      'dirvish'             => 'sbin/dirvish',
      'dirvish-locate'      => 'sbin/dirvish-locate',
      'dirvish-expire'      => 'sbin/dirvish-expire',
      'dirvish-runall'      => 'sbin/dirvish-runall',
   },

   #pod files converted to man
   adminman_files => {
      'dirvish.pod'         => 'man8dir/dirvish.8',
      'dirvish-locate.pod'  => 'man8dir/dirvish-locate.8',
      'dirvish-expire.pod'  => 'man8dir/dirvish-expire.8',
      'dirvish-runall.pod'  => 'man8dir/dirvish-runall.8',
      'dirvish.conf.pod'    => 'man5dir/dirvish.conf.5',
      'RELEASE.pod'         => 'sharedoc/dirvish/RELEASE.man',
      'INSTALL.pod'         => 'sharedoc/dirvish/INSTALL.man',
      'FAQ.pod'             => 'sharedoc/dirvish/FAQ.man',
      'TODO.pod'            => 'sharedoc/dirvish/TODO.man',
      'debian.howto.pod'    => 'sharedoc/dirvish/debian.howto.man',
   },

   #pod files converted to html (redundant, but more options for users)
   adminhtml_files => {
      'INSTALL.pod'         => 'sharedoc/dirvish/INSTALL.html',
      'dirvish-runall.pod'  => 'sharedoc/dirvish/dirvish-runall.html',
      'dirvish.conf.pod'    => 'sharedoc/dirvish/dirvish.conf.html',
      'dirvish.pod'         => 'sharedoc/dirvish/dirvish.html',
      'dirvish-expire.pod'  => 'sharedoc/dirvish/dirvish-expire.html',
      'dirvish-locate.pod'  => 'sharedoc/dirvish/dirvish-locate.html',
      'debian.howto.pod'    => 'sharedoc/dirvish/debian.howto.html',
      'RELEASE.pod'         => 'sharedoc/dirvish/RELEASE.html',
      'TODO.pod'            => 'sharedoc/dirvish/TODO.html',
      'FAQ.pod'             => 'sharedoc/dirvish/FAQ.html',
   },

   #admin files with no processing
   admin_files => {
     'CHANGELOG'           => 'sharedoc/dirvish/CHANGELOG',
     'COPYING'             => 'sharedoc/dirvish/COPYING',
     'README'              => 'sharedoc/dirvish/README',
   }
);

#--------------------------------------------------------------------
# move the files into appropriate places in blib

$build->add_build_element('sbin');
$build->add_build_element('adminman');
$build->add_build_element('adminhtml');
$build->add_build_element('admin');
$build->add_build_element('lib');

#-----------------------------------------------
# make the Build script

$build->create_build_script;
