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

sub new {
    my $invocant = shift;
    my $class = ref $invocant || $invocant;
    my $self = bless {@_}, $class;
    return $self;
}

# Methods required for SHAREit:

sub acceptitem {
}

sub cancelrequestitem {
}

sub checkinitem {
}

sub checkoutitem {
}

sub lookupuser {
}

sub renewitem {
}

sub requestitem {
}

# Other methods, just because.

# Handle a LookupVersion Request.  You probably want to just call this
# one from your subclasses rather than reimplement it.
sub lookupversion {
}

# A few helper methods:

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

    for my $key (keys %$request) {
        if ($request->{$key}->{InitiationHeader}) {
            $initheader = $request->{$key}->{InitiationHeader};
            last;
        }
    }

    if ($initheader && $initheader->{FromAgencyId}
            && $initheader->{ToAgencyId}) {
        $header = NCIP::Header->new(
            FromAgencyId => $initheader->{ToAgencyId},
            ToAgencyId => $initheader->{FromAgencyId}
        );
    }

    return $header;
}

1;
