#!/usr/bin/perl -w
# Build.PL Script for dirvish
# Version 0.5,  Keith Lofstrom,  2005-June-06
#
# Dirvish is installed with the following three step process:
#
#  ./Build.PL <options>
#  ./Build
#  ./Build install <options>
#
# The default install locations are given in the "install_path" hash.
# You can change these locations with options on the command line of
# Build.PL or Build install, for example:
#
#       --install_path share=/usr/local/share
#       --install_path sbin=/usr/local/sbin
#
# other exciting options:
#
#  ./Build fakeinstall <options>  # pretend install (no files moved)
#
#  ./Build realclean        # wipes out all the files made by ./Build.PL and
#                           # ./Build ( _build, blib, and ./Build itself )
#
# This script will NEVER be run on a non-Unix machine.  It is not
# well tested, and could use some scrutiny from someone who understands
# Module::Build better than I do.
#
# There is a directory of contributed scripts included.  These are
# not installed, but you may find them useful.

use strict                 ;
use Module::Build 0.26     ; # Debian will need to know about dependency

#===========================================================================
# make a subclass with admin features here

my $class = Module::Build->subclass(code => <<'EOF');

#--------------------------------------------------------------
# pathdir
#
# process a set of files, changing the path to blib and
# creating any necessary subdirectories, returning a hash
# containing files and targets
#
# EXTREME KLUDGE WARNING!!!!
# I do NOT know the right way to do this!!!

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
# Modify the app files
#
# We need to add the location of the /config file/ and of
# the /library/ to each application.  

sub process_sbin_files {
   my ($self)      = @_;

   # make the header ----

   my $conf        = $self->{properties}{install_path}{conf}   ;
   my $share       = $self->{properties}{install_path}{share}  ;
   my $library     = 'dirvish.pl' ;
   my $dat         = localtime ;
 
   my @apps_header = (
      "#!/usr/bin/perl              \n", #FIXME should this be config'ed?
      "#----------------------------\n",
      "#Configured by Module::Build \n",
      "#on $dat                     \n",
      "# these lines prepended by $0\n",
      "                             \n",
      "\$CONFDIR = $conf;           \n",
      "use        $share/$library;  \n",
      "#----------------------------\n"
   );

   # modify the files ----

   my $files = $self->pathdir( 'sbin' );

   while ( my ( $sourcefile, $targetfile ) = each  %$files ) {
      open( SOURCEFILE, "<$sourcefile" )
         or die "$0: cannot open $sourcefile for reading, $!";
      open( TARGETFILE, ">$targetfile" )
         or die "$0: cannot open $targetfile for writing, $!";
      print TARGETFILE @apps_header ;  # copy header
      print TARGETFILE <SOURCEFILE> ;  # copy rest of file
      close( SOURCEFILE ) or die "$0 cannot close $sourcefile, $!";
      close( TARGETFILE ) or die "$0 cannot close $targetfile, $!";
      $self->make_executable($targetfile);
   }

   $self->add_to_cleanup( values %$files );
};

#--------------------------------------------------------------
# make man pages out of pod files

sub process_adminman_files {
   my ($self)      = @_;
   my $files       = $self->pathdir( 'adminman' );
   use  Pod::Man ;

   my $parser      = Pod::Man->new( section => 1 );

   while ( my ( $sourcefile, $targetfile ) = each  %$files ) {
      # print "$sourcefile ---> $targetfile\n";
      $parser->parse_from_file( $sourcefile, $targetfile );
   };

   $self->add_to_cleanup( values %$files );
};

#---------------------------------------------------------------
# make html pages out of pod files

sub process_adminhtml_files {
   my ($self)      = @_;
   my $files       = $self->pathdir( 'adminhtml' );
   use  Pod::Html ;

   while ( my ( $sourcefile, $targetfile ) = each  %$files ) {
      # print "$sourcefile ---> $targetfile\n";
      Pod::Html::pod2html(
         "--title=dirvish",
         "--infile=$sourcefile",
         "--outfile=$targetfile",
      );
   };
   $self->add_to_cleanup( values %$files );

   # for some reason there are left over files called
   # pod2htm*, delete them
   # FIXME
   unlink <pod2htm*> ;
};

EOF

# end of the "class" subclass
#===========================================================================
# instance of the build

my $build = $class->new (

   module_name  => 'dirvish',
   dist_version => '1.3.1',
   license      => 'open_source',
   create_makefile_pl => 'traditional',

   requires => {
      'perl'                => '>= 5.6.0',
   #  'File::chmod'         => '>= 0.31',
      'File::Find'          => 0,
      'Getopt::Long'        => 0,
      'Time::ParseDate'     => 0,
      'Time::Period'        => 0
   },

   install_path => { 
      conf                  => '/etc/dirvish',
      share                 => '/usr/share',
      sharedoc              => '/usr/share/doc',
      man5dir               => '/usr/share/man/man5',
      man8dir               => '/usr/share/man/man8',
      sbin                  => '/usr/sbin' 
   },

   #precursor app files with prepended variables
   sbin_files => {
      'dirvish.PL'          => 'sbin/dirvish',
      'dirvish-locate.PL'   => 'sbin/dirvish-locate',
      'dirvish-expire.PL'   => 'sbin/dirvish-expire',
      'dirvish-runall.PL'   => 'sbin/dirvish-runall'
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
      'debian.howto.pod'    => 'sharedoc/dirvish/debian.howto.man'
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
      'FAQ.pod'             => 'sharedoc/dirvish/FAQ.html'
   },

   #admin files with no processing
   admin_files => {
     'CHANGELOG'           => 'sharedoc/dirvish/CHANGELOG',
     'CREDITS'             => 'sharedoc/dirvish/CREDITS',
     'COPYING'             => 'sharedoc/dirvish/COPYING',
     'README'              => 'sharedoc/dirvish/README',
     'dirvishlib.pl'       => 'share/dirvish/dirvishlib.pl'
   }
);

#--------------------------------------------------------------------
# move the files into appropriate places in blib

$build->add_build_element('sbin');
$build->add_build_element('adminman');
$build->add_build_element('adminhtml');
$build->add_build_element('admin');

#-----------------------------------------------
# make the Build script

$build->create_build_script;
