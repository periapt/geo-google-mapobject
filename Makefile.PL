use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Geo::Google::MapObject',
    AUTHOR              => 'Nicholas Bamber <nicholas@periapt.co.uk>',
    VERSION_FROM        => 'lib/Geo/Google/MapObject.pm',
    ABSTRACT_FROM       => 'lib/Geo/Google/MapObject.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
	'Test::JSON' => 0,
	'HTML::Template::Pluggable' => 0,
	'Scalar::Util' => 0,
	'Math::Trig' => 0
    },
    LICENSE		=> 'perl',
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Geo-Google-MapObject-*' },
);
