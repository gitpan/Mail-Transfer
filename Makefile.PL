use 5.008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'NAME'				=> 'Mail::Transfer',
    'VERSION_FROM'		=> 'Transfer.pm', # finds $VERSION
    'PREREQ_PM'			=> {'IO::Socket' => 0,
    						'IO::Socket::INET' => 0,
    						'IO::Socket::SOCKS' => 0,
    						'IO::Socket::SSL' => 0}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      ('ABSTRACT_FROM'	=> 'Transfer.pm', # retrieve abstract from module
       'AUTHOR'			=> 'Sascha Kiefer <sk@intertivity.com>',
       'dist'			=> {'COMPRESS'	 => 'gzip -9f',
       						'SUFFIX'	 => 'gz'
       					   },
      ) : ()
    ),
);
