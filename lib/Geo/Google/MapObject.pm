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

    use Geo::Google::MapObject;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=head2 new

Supported arguments are

=over

=item center

=item zoom

=item size

=item format

=item maptype

=item mobile

Defaults to false.

=item key

The mandatory API key.

=item sensor

Defaults to false.

=item markers

If present the markers should be an array ref so that it can be used in a TMPL_LOOP.

=item hl

This parameter specifies the language to be used.

=back

=cut

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
    return bless \%args, $class;
}

=head2 static_map_url

Returns a URL suitable for use as a fallback inside a noscript element.

=cut

sub static_map_url {
    my $self = shift;
    my $url = "http://maps.google.com/maps/api/staticmap?";
    my @params;

    # First the easy parameters
    foreach my $i (qw(center zoom size format mobile key sensor hl)) {
        push @params, "$i=$self->{$i}" if exists $self->{$i};
    }

    if (exists $self->{markers}) {
        # Now sort the markers
        my %markers;
        foreach my $m (@{$self->{markers}}) {
                my @style;
                push @style, "color:$m->{color}" if exists $m->{color};
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

Just returns the marker array.

=cut

sub markers {
    my $self = shift;
    return $self->{markers} || [];
}

=head2 json

This function uses the L<JSON> module to return a JSON representation of the object.

=cut

sub json {
    my $self = shift;
    use JSON;
    my %args = %$self;
    delete $args{key};
    use HTML::Entities;
    my %maptype = (
        roadmap=>0,
        satellite=>1,
        terrain=>2,
        hybrid=>3,
    );
    $args{maptype} = $maptype{$args{maptype}} if exists $args{maptype};
    if (exists $args{size}) {
        my @size = split /x/, $args{size};
        $args{size} = {width=>$size[0], height=>$size[1]};
    }
    foreach my $i (0..$#{$args{markers}}) {
        delete $args{markers}[$i]->{color};
        delete $args{markers}[$i]->{label};
        delete $args{markers}[$i]->{size};
        $args{markers}[$i]->{title} = decode_entities($args{markers}[$i]->{title}) if exists $args{markers}[$i]->{title};
    }
    return to_json(\%args, {utf8 => 1, allow_blessed => 1});
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

Currently there is no support for paths, polygons or viewports.

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
