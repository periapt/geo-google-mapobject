package Geo::Google::MapObject;

use warnings;
use strict;
use Carp;

=head1 NAME

Geo::Google::MapObject - Code to help with managing the server side of the Google Maps API

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use HTML::Template::Pluggable;
    use HTML::Template::Plugin::Dot;
    use Geo::Google::MapObject;
    my $map = Geo::Google::MapObject->new(
        key => 'ABQFbHAATHwok56Qe3MBtg0s7lgkHBS9HKneet7v0OIFhIwnBhTEGCHLTRRRBa_lUOCy1fDamS5PQt8qULYfYQ',
        zoom => 13,
        size => '512x400',
        maptype => 'terrain',
        markers=>
        [
                {location=>'46.818285,14.587601',color=>'green',label=>'M',title=>'Gasthaus Mesner',icon=>'/img/favicon.png'},
                {location=>'46.818917,14.572672',color=>'red',label=>'S',title=>'Gasthof Sereinig',href=>'http://www.gasthof-sereinig.at/'},
        ]
    );
    my $template = HTML::Template::Pluggable->new(file=>'map.tmpl');
    $template->param(map->$map);
    return $template->output;
  
=head1 DESCRIPTION

This module is intended to provide a server side solution to working with the Google Maps API.
In particular an object of this class encapsulates a "map" object that provides support
for the static maps API, the javascript maps API, AJAX calls and non-javascript fallback data;
but without making any assumptions about the surrounding framework.
As such it does not concern itself with persistent storage of the map data as to do 
would commit the code to a particular storage implementation. In any case implementing
such storage in a derived class ought to work well. 
The one assumption about the surrounding environment is that a template framework
with support for a "dot" notation is being used, for example L<HTML::Template::Pluggable>.
An important commitment of the module is support for graceful fallback to a functional non-javascript web page.

=head1 INTERFACE 

=head2 new

Supported arguments are

=over

=item center

=item zoom

This represents the zoom level (http://code.google.com/apis/maps/documentation/staticmaps/#Zoomlevels), which
is a number between 0 and 21 inclusive. This parameter is mandatory.

=item size

The size (http://code.google.com/apis/maps/documentation/staticmaps/#Imagesizes) must either be a string
consisting of two numbers joined by the symbol C<x>, or a hash ref with width and height parameters. In either
case the first number is the width and the second the height. If absent the Google API will be allowed to set
the size as it sees fit.

=item format

The format (http://code.google.com/apis/maps/documentation/staticmaps/#ImageFormats) must be one of 
png8,  png, png32, gif, jpg, jpg-baseline or absent. If absent the Google API will be allowed to set
the format as it sees fit.

=item maptype

This must be one of the following: roadmap, satellite, terrain, hybrid.

=item mobile

Defaults to false.

=item key

The mandatory API key.

=item sensor

Defaults to false.

=item markers

If present the markers should be an array ref so that it can be used in a TMPL_LOOP.
Each member of the array should be a hash ref and may contain whatever keys are required
by the javascript client side code. These might include for example: id, title, href, icon.
However the only members of a marker object that have a fixed meaning are those described by the static maps API
(http://code.google.com/apis/maps/documentation/staticmaps/#MarkerStyles).

=over

=item color

=item size

=item label

=item location

=back

=item hl

This parameter specifies the language to be used. If absent the API will select the language.

=back

=cut

use Readonly;
Readonly my %MAPTYPE => (
        roadmap=>0,
        satellite=>1,
        terrain=>2,
        hybrid=>3,
);

sub new {
    my $class = shift;
    my %args = @_;
    $args{mobile} = 'false' unless exists $args{mobile} && $args{mobile} eq 'true';
    $args{sensor} = 'false' unless exists $args{sensor} && $args{sensor} eq 'true';
    if (exists $args{markers}) {
        croak "markers should be an ARRAY" unless ref($args{markers}) eq "ARRAY";
    }
    croak "no API key" unless exists $args{key};
    croak "no center" unless exists $args{center} || exists $args{markers};
    croak "no zoom" unless exists $args{zoom} || exists $args{markers};
    if (exists $args{zoom}) {
        croak "zoom not a number: $args{zoom}" unless ($args{zoom} =~ /^\d{1,2}$/) && $args{zoom} < 22;
    }
    if (exists $args{maptype}) {
	croak "maptype $args{maptype} not recognized" unless exists $MAPTYPE{$args{maptype}};
    }
    if (exists $args{size}) {
	my ($width, $height) = _parse_size($args{size});
	$args{size} = {width=>$width,height=>$height};
    }
    return bless \%args, $class;
}

sub _parse_size {
    my $size = shift;
    my ($width, $height);
    if (ref($size) eq "HASH") {
        $width = $size->{width} || croak "no width";
        $height = $size->{height} || croak "no height";
    }
    elsif($size =~ /^(\d{1,3})x(\d{1,3})$/) {
        $width = $1;
        $height = $2;
    }
    else {
        croak "cannot recognize size";
    }
    croak "width should positive and be no more than 640" unless ($width > 0 && $width <= 640);
    croak "height should positive and be no more than 640" unless ($height > 0 && $height <= 640);
    return ($width, $height);
}

=head2 static_map_url

Returns a URL suitable for use as a fallback inside a noscript element.

=cut

sub static_map_url {
    my $self = shift;
    my $url = "http://maps.google.com/maps/api/staticmap?";
    my @params;

    # First the easy parameters
    foreach my $i (qw(center zoom format mobile key sensor hl)) {
        push @params, "$i=$self->{$i}" if exists $self->{$i};
    }
    push @params, "size=$self->{size}->{width}x$self->{size}->{height}" if exists $self->{size};

    if (exists $self->{markers}) {
        # Now sort the markers
        my %markers;
        foreach my $m (@{$self->{markers}}) {
                my @style;
                push @style, "color:$m->{color}" if exists $m->{color} && $m->{color} =~
				/^0x[A-F0-9]{6}|black|brown|green|purple|yellow|blue|gray|orange|red|white$/;
                push @style, "size:$m->{size}" if exists $m->{size} && $m->{size} =~ /^tiny|mid|small$/;
                push @style, "label:$m->{label}" if exists $m->{label} && $m->{label} =~ /^[A-Z0-9]$/;
                my $style = join "|", @style;
                push @{$markers{$style}},  $m->{location} || croak "no location for $style";
        }
        foreach my $m (sort keys %markers) {
                my $param = "markers=";
                $param .= "$m|" if $m;
                $param .= join '|', @{$markers{$m}};
                push @params, $param;
        }
    }

    $url .= join "&amp;", @params;
    return $url;
}

=head2 javascript_url

Returns a URL suitable for use in loading the dynamic map API.

=cut

sub javascript_url {
   my $self = shift;
   my $url = "http://maps.google.com/maps?file=api&amp;v=2&amp;key=$self->{key}&amp;sensor=$self->{sensor}";
   $url .= "&amp;hl=$self->{hl}" if exists $self->{hl};
   return $url;
}

=head2 markers

This returns the marker array.

=cut

sub markers {
    my $self = shift;
    return $self->{markers} || [];
}

=head2 json

This function uses the L<JSON> module to return a JSON representation of the object.
It removes the API key as that should not be required by any javascript client side code.
If any marker object has a title attribute, then that attribute is encoded so it will display
correctly.

=cut

sub json {
    my $self = shift;
    use JSON;
    my %args = %$self;
    delete $args{key};
    use HTML::Entities;
    $args{maptype} = $MAPTYPE{$args{maptype}} if exists $args{maptype};
    foreach my $i (0..$#{$args{markers}}) {
        $args{markers}[$i]->{title} = decode_entities($args{markers}[$i]->{title}) if exists $args{markers}[$i]->{title};
    }
    return to_json(\%args, {utf8 => 1, allow_blessed => 1});
}

=head2 width

This returns the width of the image or undef if none has been set.

=cut

sub width {
    my $self = shift;
    return undef unless exists $self->{size};
    return $self->{size}->{width};
}

=head2 height

This returns the height of the image or undef if none has been set.

=cut

sub height {
    my $self = shift;
    return undef unless exists $self->{size};
    return $self->{size}->{height};
}

=head1 DIAGNOSTICS

=over

=item C<< markers should be an ARRAY >>

The markers parameter of the constructor must be an ARRAY ref of marker configuration data.

=item C<< no API key >>

To use this module you must sign up for an API key (http://code.google.com/apis/maps/signup.html) and supply it as
the key parameter.

=item C<< no center >>

There must either be a center specified or at least one marker. In the latter case the first marker will be used as the center.

=item C<< no zoom >>

There must be a zoom parameter which is a number from 0 to 21.

=item C<< size length should be 2 >>

If present and in the form of an ARRAY ref, then the size must have two elements.

=item C<< width should be no more than 640 >>

=item C<< height should be no more than 640 >>

=item C<< cannot recognize size >>

The size parameter was neither an ARRAY ref nor a string matching the expected format.

=back


=head1 CONFIGURATION AND ENVIRONMENT

Geo::Google::MapObject requires no configuration files or environment variables.

=head1 DEPENDENCIES

=over 

=item Templating framework

We assume the use of L<HTML::Template::Pluggable> and L<HTML::Template::Plugin>
though other template frameworks may work.

=item Google Maps API

You need to have one of these which can be obtained from L<http://code.google.com/apis/maps/signup.html>.

=item Javascript and AJAX

We assume a degree of familiarity with javascript, AJAX and client side programming.
For the purposes of documentation we assume YUI: L<http://developer.yahoo.com/yui/>, but this
choice of framework is not mandated.

=back

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

Currently there is no support for paths, polygons or viewports. Also we are currently 
only supporting version 2 of the API.

Please report any bugs or feature requests to
C<bug-geo-google-mapobject@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Nicholas Bamber  C<< <nicholas@periapt.co.uk> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2009, Nicholas Bamber C<< <nicholas@periapt.co.uk> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

1; # End of Geo::Google::MapObject
