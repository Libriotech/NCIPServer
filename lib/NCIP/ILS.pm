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

=head1 NAME

NCIP::ILS - A base class for NIPServer ILS drivers.

=head1 SYNOPSIS

C<use NCIP::ILS;>

C<my $ils = NCIP::ILS-E<gt>new(name =E<gt> $config-E<gt>{NCIP.ils.value});>

=head1 DESCRIPTION

NCIP::ILS is meant as a base class and test implementation of the ILS
specific drivers of NCIPServer.  If you wish to implement a driver for
your specific ILS, then it is recommended you subclass this module and
reimplement the methods as necessary.

=cut

sub new {
    my $invocant = shift;
    my $class = ref $invocant || $invocant;
    my $self = bless {@_}, $class;
    return $self;
}

=head1 HANDLER METHODS

When NCIPServer receives an incoming message, it translates the
requested service into lower case and then checks if the ILS has a
method by that name.  If it does that method is called with a single
argument consisting of the XML request converted to a hash ref via
XML::LibXML::Simple.  If the ILS does not support that service, then
the unsupportedservice method of the ILS is called and the resulting
problem response returned to the client.

All handler methods must return a NCIP::Response object.

The handler methods provided in this base class implementation are
those that were required for the initial implemenation of NCIPServer
to be used with a particular initiator software.  You may add any
additional handlers to your implementation as required without needing
to alter this base class.

=cut

# Methods required for SHAREit:

=head2 acceptitem

Called to handle the AcceptItem service request.  The inherited
implementation returns the Unsupported Service problem response.

=cut

sub acceptitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

=head2 cancelrequestitem

Called to handle the CancelRequestItem service request.  The inherited
implementation returns the Unsupported Service problem response.

=cut

sub cancelrequestitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

=head2 checkinitem

Called to handle the CheckInItem service request.  The inherited
implementation returns the Unsupported Service problem response.

=cut

sub checkinitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

=head2 checkoutitem

Called to handle the CheckOutItem service request.  The inherited
implementation returns the Unsupported Service problem response.

=cut

sub checkoutitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

=head2 lookupuser

Called to handle the LookupUser service request.  The inherited
implementation returns the Unsupported Service problem response.

=cut

sub lookupuser {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

=head2 renewitem

Called to handle the RenewItem service request.  The inherited
implementation returns the Unsupported Service problem response.

=cut

sub renewitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

=head2 requestitem

Called to handle the RequestItem service request.  The inherited
implementation returns the Unsupported Service problem response.

=cut

sub requestitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

# Other methods, just because.

=head2 lookupversion

Called to handle the LookupVersion service request.  The inherited
implementation returns the list of supported versions from
NCIP::Const.  You probably do not want to reimplement this method in
your subclass.

=cut

sub lookupversion {
    my $self = shift;
    my $request = shift;

    my $response = NCIP::Response->new({type => "LookupVersionResponse"});
    my $payload = {
        fromagencyid => $request->{LookupVersion}->{ToAgencyId}->{AgencyId},
        toagencyid => $request->{LookupVersion}->{FromAgencyId}->{AgencyId},
        versions => [ NCIP::Const::SUPPORTED_VERSIONS ]
    };
    $response->data($payload);

    return $response;
}

=head1 USEFUL METHODS

These are methods of the base class that you may want to use in your
subclass or that are used by NCIPserver or other methods of this base
class.  You very likely do not want to override these in your
subclass.

=cut

=head2 unsupportedservice

C<my $response = $ils-E<gt>unsupportedservice($request);>

This method has the same signature as a regular service handler
method.  It returns a response containing an Unsupported Service
problem.  It is used by NCIP.pm when the ILS cannot handle a message,
or your implementation could return this in the case of a
service/message you don't actually handle, though you may have the
proper function defined.

=cut

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

=head2 make_header

C<$response-E<gt>header($ils-E<gt>make_header($request));>

All subclasses will possibly want to create a ResponseHeader for the
response message.  Since the code for that could be highly redundant
if reimplemented by each subclass, the base class supplies an
implementation that retrieves the agency information from the
InitiationHeader of the request message, swaps the FromAgencyId with
the ToAgencyId, and vice versa.  It then returns a NCIP::Header to be
used in the NCIP::Response object's header field.

=cut

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

=head2 parse_request_type

C<my $type = $ils-E<gt>parse_request_type($request);>

Given the request hashref object, parse_request_type will return the
service being requested in the message.  This method is called by
NCIP.pm in order to determine which handler of the ILS object to call.
You may find it convenient to use this method in your own handler
implementations.  You should not need to override this method in your
subclass.

=cut

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

=head2 find_barcode

C<my $barcode = $ils-E<gt>find_user_barcode($request);>

If you have a request type that includes a user barcode identifier
value, this routine will find it. It presently works only on
LookupUser requests.

It will return the barcode in scalar context, or the barcode and the
tag of the field where the barcode was found in list context.

If multiple barcode fields are provided, it returns the first one that
it finds. This is not necessarily the first one given in the request
message. Maybe we should add a plural form of this method to find all
of the user barcodes provided?

=cut

sub find_user_barcode {
    my $self = shift;
    my $request = shift;

    my $barcode;
    my $field;
    my $message = $self->parse_request_type($request);
    return unless($message);
    if ($message eq 'LookupUser') {
        my $authinput = $request->{$message}->{AuthenticationInput};
        if ($authinput) {
            $field = 'AuthenticationInputData';
            # Convert to array ref if it isn't already.
            if (ref $authinput ne 'ARRAY') {
                $authinput = [$authinput];
            }
            foreach my $input (@$authinput) {
                if ($input->{AuthenticationInputType} =~ /barcode/i) {
                    $barcode = $input->{$field};
                    last;
                }
            }
        } else {
            $authinput = $request->{$message}->{UserId};
            if ($authinput) {
                $field = 'UserIdentifierValue';
                if (ref $authinput ne 'ARRAY') {
                    $authinput = [$authinput];
                }
                foreach my $input (@$authinput) {
                    if ($input->{UserIdentifierType} =~ /barcode/i) {
                        $barcode = $input->{$field};
                        last;
                    }
                }
            }
        }
    }

    return (wantarray) ? ($barcode, $field) : $barcode;
}

1;
