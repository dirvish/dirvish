use Module::Build;
use Data::Dumper;

my $class = Module::Build->subclass
  (
   class => 'Dirvish::Build',
   code => q{
       sub ACTION_build {
	 my $self = shift;
	 $self->SUPER::ACTION_build;

	 my $destdir = $self->{properties}{destdir};
	 $destdir = '' unless defined $destdir;

	 my $installdirs = $self->{properties}{installdirs};
	 my $installprefix = $self->{config}{$installdirs . 'prefix'};
	 #print Data::Dumper->Dump([$self->{config}]);

	 $self->do_system('./configure', ("--prefix=$destdir$installprefix"));
       }

       sub ACTION_install {
	 my $self = shift;
	 $self->SUPER::ACTION_install;

	 $self->do_system('make', ("install"));
       }
     }
  );

my $build = $class->new
  (
   module_name => 'Dirvish',
   dist_version => '1.3.0-esm',
   license => 'open_source',
   requires => {
		'perl'             => '>= 5.6.0',
		'File::chmod'      => '>= 0.31',
		'File::Find'       => 0,
		'Getopt::Long'     => 0,
		'Time::ParseDate'  => 0,
		'Time::Period'     => 0
	       },
   pm_files => {
		'loadconfig.pl' => 'lib/Dirvish/loadconfig.pm'
	       },
   script_files => [
		    'dirvish-runall',
		    'dirvish',
		    'dirvish-locate',
		    'dirvish-expire'
		   ]
  );

$build->create_build_script;
