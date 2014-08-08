# ---------------------------------------------------------------
# Copyright © 2014 Jason J.A. Stephenson <jason@sigio.com>
#
# This file is part of NCIPServer.
#
# NCIPServer is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# NCIPServer is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with NCIPServer.  If not, see <http://www.gnu.org/licenses/>.
# ---------------------------------------------------------------
package NCIP::ILS;

use Modern::Perl;
use NCIP::Const;
use NCIP::Header;
use NCIP::Problem;
use NCIP::Response;

sub new {
    my $invocant = shift;
    my $class = ref $invocant || $invocant;
    my $self = bless {@_}, $class;
    return $self;
}

# Methods required for SHAREit:

sub acceptitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

sub cancelrequestitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

sub checkinitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

sub checkoutitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

sub lookupuser {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

sub renewitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

sub requestitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

# Other methods, just because.

# Handle a LookupVersion Request.  You probably want to just call this
# one from your subclasses rather than reimplement it.
sub lookupversion {
    my $self = shift;
    my $request = shift;

    my $response = NCIP::Response->new({type => "LookupVersionResponse"});
    $response->header($self->make_header($request));
    my $payload = {
        versions => [ NCIP::Const::SUPPORTED_VERSIONS ]
    };
    $response->data($payload);

    return $response;
}

# A few helper methods:

# This is a handy method that subclasses should probably not override.
# It returns a response containing an Unsupported Service problem.  It
# is used by NCIP.pm when the ILS cannot handle a message, or your
# implementation could return this in the case of a service/message
# you don't actually handle, though you may have the proper function
# defined.
sub unsupportedservice {
    my $self = shift;
    my $request = shift;

    my $service = $self->parse_request_type($request);

    my $response = NCIP::Response->new({type => $service . 'Response'});
    my $problem = NCIP::Problem->new();
    $problem->ProblemType('Unsupported Service');
    $problem->ProblemDetail("$service service is not supported by this implementation.");
    $problem->ProblemElement("NULL");
    $problem->ProblemValue("Not Supported");
    $response->problem($problem);

    return $response;
}

# All subclasses will possibly want to create a ResponseHeader and the
# code for that would be highly redundant.  We supply a default
# implementation here that can retrieve the agency information from
# the InitiationHeader of the message, swap their values, and return a
# NCIP::Header.
sub make_header {
    my $self = shift;
    my $request = shift;

    my $initheader;
    my $header;

    my $key = $self->parse_request_type($request);
    $initheader = $request->{$key}->{InitiationHeader}
        if ($key && $request->{$key}->{InitiationHeader});

    if ($initheader && $initheader->{FromAgencyId}
            && $initheader->{ToAgencyId}) {
        $header = NCIP::Header->new({
            FromAgencyId => $initheader->{ToAgencyId},
            ToAgencyId => $initheader->{FromAgencyId}
        });
    }

    return $header;
}

sub parse_request_type {
    my $self = shift;
    my $request = shift;
    my $type;

    for my $key (keys %$request) {
        if (ref $request->{$key} eq 'HASH') {
            $type = $key;
            last;
        }
    }

    return $type;
}

1;
