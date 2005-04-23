#!/usr/bin/perl -w
# Build.PL Script for dirvish
# Version 0.5,  Keith Lofstrom,  2005-Apr-20
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
#       --install_path share=/usr/local/share
#       --install_path sbin=/usr/local/sbin
#
# other exciting options:
#
#  ./Build fakeinstall <options>  # pretend install (no files moved)
#
#  ./Build realclean  # wipes out all the files made by ./Build.PL and
#                     # ./Build ( _build, blib, and ./Build itself )
#
#  ./Build manifest   # makes Manifest file
#
#  ./Build dist    # after "manifest", makes a dirvish-XX.tar.gz file
#                  # caveat:  requires YAML.pm to be installed, and this:
#                  #
#                  # use Module::Build::ConfigData ;
#                  # Module::Build::ConfigData->set_feature(YAML_support => 1);
#                  # Module::Build::ConfigData->write();
#
#
# Someday, there will be a "./Build test" option, which will run tests
# on both installation and basic usage of dirvish.  I do not know how
# to write those tests yet.
#
# This script will NEVER be run on a non-Unix machine.  It is neither
# complete nor well tested;  it is a placeholder to gather comments
# about my probable misuse of Module::Build . 
# I'm pretty sure I am doing a lot of things the hard way.

use strict                 ;
use Module::Build 0.26     ; # Debian will need to know about dependency

#===========================================================================
# make a subclass with admin features here

my $class = Module::Build->subclass(code => <<'EOF');

#--------------------------------------------------------------
# dirvish_pathdir
#
# process a set of files, changing the path to blib and
# creating any necessary subdirectories, returning a hash
# containing files and targets
#
# EXTREME KLUDGE WARNING!!!!
# I do NOT know the right way to do this!!!

sub dirvish_pathdir {
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

sub process_dirvish_sbin_files {
   my ($self)      = @_;

   # make the header ----

   my $conf        = $self->{properties}{install_path}{conf}   ;
   my $share       = $self->{properties}{install_path}{share}  ;
   my $library     = 'dirvishlib' ;
   my $dat         = localtime ;
 
   my @apps_header = (
      "#!/usr/bin/perl\n",                    # FIXME should this be config'ed?
      "#--------------------------------------\n",
      "#Configured by Module::Build on $dat\n",
      "# these lines prepended by $0\n",
      "\n",
      "\$CONFDIR = \"$conf\";\n",
      "use lib \"$share\";\n",
      "use      $library;\n",
      "#--------------------------------------\n"
   );

   # modify the files ----

   my $files = $self->dirvish_pathdir( 'dirvish_sbin' );

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

sub process_dirvish_manify_files {
   my ($self)      = @_;
   my $files       = $self->dirvish_pathdir( 'dirvish_manify' );
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

sub process_dirvish_htmlify_files {
   my ($self)      = @_;
   my $files       = $self->dirvish_pathdir( 'dirvish_htmlify' );
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
      share                 => '/usr/share/dirvish',
      sharedoc              => '/usr/share/doc/dirvish-1.3.1',
      man5dir               => '/usr/share/man/man5',
      man8dir               => '/usr/share/man/man8',
      sbin                  => '/usr/sbin' 
   },

   #precursor app files with prepended variables
   dirvish_sbin_files => {
      'dirvish.PL'          => 'sbin/dirvish',
      'dirvish-locate.PL'   => 'sbin/dirvish-locate',
      'dirvish-expire.PL'   => 'sbin/dirvish-expire',
      'dirvish-runall.PL'   => 'sbin/dirvish-runall'
   },

   #pod files converted to man
   dirvish_manify_files => {
      'dirvish.pod'         => 'man8dir/dirvish.8',
      'dirvish-locate.pod'  => 'man8dir/dirvish-locate.8',
      'dirvish-expire.pod'  => 'man8dir/dirvish-expire.8',
      'dirvish-runall.pod'  => 'man8dir/dirvish-runall.8',
      'dirvish.conf.pod'    => 'man5dir/dirvish.conf.5',
      'RELEASE.pod'         => 'sharedoc/RELEASE.man',
      'INSTALL.pod'         => 'sharedoc/INSTALL.man',
      'FAQ.pod'             => 'sharedoc/FAQ.man',
      'TODO.pod'            => 'sharedoc/TODO.man',
      'debian.howto.pod'    => 'sharedoc/debian.howto.man'
   },

   #pod files converted to html (redundant, but more options for users)
   dirvish_htmlify_files => {
      'INSTALL.pod'         => 'sharedoc/INSTALL.html',
      'dirvish-runall.pod'  => 'sharedoc/dirvish-runall.html',
      'dirvish.conf.pod'    => 'sharedoc/dirvish.conf.html',
      'dirvish.pod'         => 'sharedoc/dirvish.html',
      'dirvish-expire.pod'  => 'sharedoc/dirvish-expire.html',
      'dirvish-locate.pod'  => 'sharedoc/dirvish-locate.html',
      'debian.howto.pod'    => 'sharedoc/debian.howto.html',
      'RELEASE.pod'         => 'sharedoc/RELEASE.html',
      'TODO.pod'            => 'sharedoc/TODO.html',
      'FAQ.pod'             => 'sharedoc/FAQ.html'
   },

   #admin files with no processing
   dirvish_files => {
      'INSTALL.pod'         => 'sharedoc/INSTALL.pod',
      'dirvish-runall.pod'  => 'sharedoc/dirvish-runall.pod',
      'dirvish.conf.pod'    => 'sharedoc/dirvish.conf.pod',
      'dirvish.pod'         => 'sharedoc/dirvish.pod',
      'dirvish-expire.pod'  => 'sharedoc/dirvish-expire.pod',
      'dirvish-locate.pod'  => 'sharedoc/dirvish-locate.pod',
      'debian.howto.pod'    => 'sharedoc/debian.howto.pod',
      'RELEASE.pod'         => 'sharedoc/RELEASE.pod',
      'TODO.pod'            => 'sharedoc/TODO.pod',
      'FAQ.pod'             => 'sharedoc/FAQ.pod',
      'CHANGELOG'           => 'sharedoc/CHANGELOG',
      'COPYING'             => 'sharedoc/COPYING',
      'README'              => 'sharedoc/README',
      'dirvishlib.pm'       => 'share/dirvishlib.pm'
   }
);

#--------------------------------------------------------------------
# move the files into appropriate places in blib

$build->add_build_element('dirvish_sbin');
$build->add_build_element('dirvish_manify');
$build->add_build_element('dirvish_htmlify');
$build->add_build_element('dirvish');

#-----------------------------------------------
# make the Build script

$build->create_build_script;
