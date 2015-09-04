#
#===============================================================================
#
#         FILE: Koha.pm
#
#  DESCRIPTION:
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Chris Cormack (rangi), chrisc@catalyst.net.nz, Magnus Enger (magnuse) magnus@libriotech.no
# ORGANIZATION: Koha Development Team
#      VERSION: 1.0
#      CREATED: 05/11/13 11:14:09
#     REVISION: ---
#===============================================================================
package NCIP::ILS::Koha;

use Modern::Perl;
use Data::Dumper; # FIXME Debug
use Dancer ':syntax';

use C4::Biblio;
use C4::Branch;
use C4::Circulation qw { AddRenewal CanBookBeRenewed GetRenewCount };
use C4::Members qw{ GetMemberDetails };
use C4::Items qw { AddItem GetItem };
use C4::Reserves qw {CanBookBeReserved AddReserve GetReservesFromItemnumber CancelReserve GetReservesFromBiblionumber};
use C4::Log;

use Koha::ILLRequests;

use NCIP::Item::Id;
use NCIP::Problem;
use NCIP::RequestId;
use NCIP::User::Id;
use NCIP::Item::BibliographicDescription;

# Inherit from NCIP::ILS.
use parent qw(NCIP::ILS);

=head1 NAME

Koha - Koha driver for NCIPServer

=head1 SYNOPSIS

    my $ils = NCIP::ILS::Koha->new(name => $config->{NCIP.ils.value});

=cut

# The usual constructor:
sub new {
    my $class = shift;
    $class = ref($class) if (ref $class);

    # Instantiate our parent with the rest of the arguments.  It
    # creates a blessed hashref.
    my $self = $class->SUPER::new(@_);

    # Look for our configuration file, load, and parse it:
    # $self->_configure();

    # Bootstrap OpenSRF and prepare some OpenILS components.
    # $self->_bootstrap();

    # Initialize the rest of our internal state.
    # $self->_init();

    return $self;
}

=head1 HANDLER METHODS

=head2 lookupagency

    $response = $ils->lookupagency($request);

Handle the NCIP LookupAgency message.

=cut

sub lookupagency {

    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    # FIXME $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    my $library = GetBranchDetail( config->{'isilmap'}->{ $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId} } );

    my $data = {
        fromagencyid => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
        toagencyid => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
        RequestType => $request->{$message}->{RequestType},
        library => $library,
        orgtype => ucfirst C4::Context->preference( "UsageStatsLibraryType" ),
        applicationprofilesupportedtype => 'NNCIPP 1.0',
    };

    $response->data($data);
    return $response;

}

=head2 itemshipped

    $response = $ils->itemshipped($request);

Handle the NCIP ItemShipped message.

=cut

sub itemshipped {

    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    # FIXME $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));
    
    # Change the status of the request
    # Find the request
    my $illRequests = Koha::ILLRequests->new;
    my $saved_requests = $illRequests->search({
        # This is a request we have sent out ourselves, so we can use the value
        # of RequestIdentifierValue directly against the id column
        'id' => $request->{$message}->{RequestId}->{RequestIdentifierValue},
    });
    # There should only be one request, so we use the zero'th one
    my $saved_request = $saved_requests->[0];
    $saved_request->editStatus({ 'status' => 'SHIPPING' });
    $saved_request->editStatus({ 'remote_barcode' => $request->{$message}->{ItemId}->{ItemIdentifierValue} });

    # FIXME Update the bibliographic data if new data is sent
    
    my $data = {
        fromagencyid           => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
        toagencyid             => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
        AgencyId               => $request->{$message}->{RequestId}->{AgencyId},
        RequestIdentifierValue => $request->{$message}->{RequestId}->{RequestIdentifierValue},
        RequestType            => $request->{$message}->{RequestType},
    };

    $response->data($data);
    return $response;

}

=head2 itemreceived

    $response = $ils->itemreceived($request);

Handle the NCIP ItemReceived message.

=cut

sub itemreceived {

    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    # FIXME $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # FIXME Change the status of the request
    # Find the request
    my $illRequests = Koha::ILLRequests->new;
    my $saved_requests = $illRequests->search({
        'status'    => 'SHIPPED',
        'remote_id' => $request->{$message}->{RequestId}->{AgencyId} . ':' . $request->{$message}->{RequestId}->{RequestIdentifierValue},
    });
    # There should only be one request, so we use the zero'th one
    my $saved_request = $saved_requests->[0];
    $saved_request->editStatus({ 'status' => 'RECEIVED' });

    my $data = {
        fromagencyid           => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
        toagencyid             => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
        AgencyId               => $request->{$message}->{RequestId}->{AgencyId},
        RequestIdentifierValue => $request->{$message}->{RequestId}->{RequestIdentifierValue},
        RequestType            => $request->{$message}->{RequestType},
    };

    $response->data($data);
    return $response;

}

=head2 requestitem

    $response = $ils->requestitem($request);

Handle the NCIP RequestItem message.

=cut

sub requestitem {
    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    # FIXME $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # Find the cardnumber of the borrower
    # my ( $cardnumber, $cardnumber_field ) = $self->find_user_barcode( $request );
    # unless( $cardnumber ) {
    #     my $problem = NCIP::Problem->new({
    #         ProblemType    => 'Needed Data Missing',
    #         ProblemDetail  => 'Cannot find user barcode in message',
    #         ProblemElement => $cardnumber_field,
    #         ProblemValue   => 'NULL',
    #     });
    #     $response->problem($problem);
    #     return $response;
    # }

    # Find the library (borrower) based on the FromAgencyId
    my $cardnumber = _isil2barcode( $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId} );
    my $borrower = GetMemberDetails( undef, $cardnumber );
    unless ( $borrower ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Unknown User',
            ProblemDetail  => "User with barcode $cardnumber unknown",
            ProblemElement => 'AgencyId',
            ProblemValue   => 'NULL',
        });
        $response->problem( $problem );
        return $response;
    }
    
    my $itemdata;
    # Find the barcode from the request, if there is one
    # FIXME Figure out if we have a barcode or RFID
    my $itemidentifiertype  = $request->{$message}->{ItemId}->{ItemIdentifierType};
    my $itemidentifiervalue = $request->{$message}->{ItemId}->{ItemIdentifierValue};
    my ( $barcode, $barcode_field ) = $self->find_item_barcode($request);
    if ( $itemidentifiertype eq "Barcode" && $itemidentifiervalue ne '' ) {
        # We have a barcode (or something passing itself off as a barcode), 
        # try to use it to get item data
        $itemdata = GetItem( undef, $itemidentifiervalue );
        unless ( $itemdata ) {
            my $problem = NCIP::Problem->new({
                ProblemType    => 'Unknown Item',
                ProblemDetail  => "Item $itemidentifiervalue is unknown",
                ProblemElement => 'ItemIdentifierValue',
                ProblemValue   => $itemidentifiervalue,
            });
            $response->problem($problem);
            return $response;
        }
    }
    
    my $bibliodata   = GetBiblioData( $itemdata->{'biblionumber'} );
    my $lang_code = _get_langcode_from_bibliodata( $bibliodata );
    
    
    # FIXME Deal with BibliographicId
    # else {
    #     if ( $type eq 'SYSNUMBER' ) {
    #         $itemdata = GetBiblioData($biblionumber);
    #     }
    #     elsif ( $type eq 'ISBN' ) {

    #         #deal with this
    #     }
    # }

    # Bail out if we have no data by now
    unless ($itemdata) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Unknown Item',
            ProblemDetail  => "Item is unknown",
            ProblemElement => 'NULL',
            ProblemValue   => 'NULL',
        });
        $response->problem($problem);
        return $response;
    }

    # Create a new request with the newly created biblionumber
    my $illRequest   = Koha::ILLRequests->new;
    my $saved_request = $illRequest->request({
        'biblionumber' => $itemdata->{'biblionumber'},
        'branch'       => 'ILL', # FIXME
        'borrower'     => $borrower->{'borrowernumber'}, # Home Library
    });
    $saved_request->editStatus({
        'remote_user'    => $request->{$message}->{UserId}->{UserIdentifierValue},
        'remote_id'      => $request->{$message}->{RequestId}->{AgencyId} . ':' . $request->{$message}->{RequestId}->{RequestIdentifierValue},
        'remote_barcode' => $request->{$message}->{ItemId}->{ItemIdentifierValue},
    });

    # Check if it is possible to make a reservation
    # if ( CanBookBeReserved( $borrower->{borrowernumber}, $itemdata->{biblionumber} )) {
    #     my $biblioitemnumber = $itemdata->{biblionumber};
    #     # Add reserve here
    #     # FIXME We should be able to place an ILL request in the ILL module as an alternative workflow
    #     AddReserve(
    #         $response->{'header'}->{'ToAgencyId'}->{'AgencyId'}, # branch
    #         $borrower->{borrowernumber},                         # borrowernumber
    #         $itemdata->{biblionumber},                           # biblionumber
    #         'a',                                                 # constraint
    #         [$biblioitemnumber],                                 # bibitems
    #         1,                                                   # priority
    #         undef,                                               # resdate
    #         undef,                                               # expdate
    #         'Placed By ILL',                                     # notes
    #         '',                                                  # title
    #         $itemdata->{'itemnumber'} || undef,                  # checkitem
    #         undef,                                               # found
    #     );
    #     if ($biblionumber) {
    #         my $reserves = GetReservesFromBiblionumber({
    #             biblionumber => $itemdata->{biblionumber}
    #         });
    #         $request_id = $reserves->[1]->{reserve_id};
    #     } else {
    #         my ( $reservedate, $borrowernumber, $branchcode2, $reserve_id,
    #             $wait )
    #           = GetReservesFromItemnumber( $itemdata->{'itemnumber'} );
    #         $request_id = $reserve_id;
    #     }
    # } else {
    #     # A reservation can not be made
    #     my $problem = NCIP::Problem->new({
    #         ProblemType        => 'Item Does Not Circulate',
    #             ProblemDetail  => 'Request of Item cannot proceed because the Item is non-circulating',
    #             ProblemElement => 'BibliographicRecordIdentifier',
    #             ProblemValue   => 'NULL',
    #     });
    #     $response->problem($problem);
    #     return $response;
    # }

    # Build the response
    my $data = {
        ToAgencyId   => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
        FromAgencyId => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
        RequestId => NCIP::RequestId->new({
            # Echo back the RequestIdentifier found in the request
            AgencyId => $request->{$message}->{RequestId}->{AgencyId},
            RequestIdentifierValue => $request->{$message}->{RequestId}->{RequestIdentifierValue},
        }),
        ItemId => NCIP::Item::Id->new(
            {
                ItemIdentifierValue => $itemidentifiervalue,
                ItemIdentifierType => $itemidentifiertype,
            }
        ),
        UserId => NCIP::User::Id->new(
            {
                UserIdentifierValue => $request->{$message}->{UserId}->{UserIdentifierValue},
            }
        ),
        RequestType => $request->{$message}->{RequestType},
        ItemOptionalFields => NCIP::Item::BibliographicDescription->new(
            {
                Author             => $bibliodata->{'author'},
                PlaceOfPublication => $bibliodata->{'place'},
                PublicationDate    => $bibliodata->{'copyrightdate'},
                Publisher          => $bibliodata->{'publishercode'},
                Title              => $bibliodata->{'title'},
                BibliographicLevel => 'Book', # FIXME
                Language           => $lang_code,
                MediumType         => 'Book', # FIXME
            }
        ),
    };

        # Look for UserElements requested and add it to the response:
        # my $elements = $request->{$message}->{UserElementType};
        # if ($elements) {
        #     $elements = [$elements] unless (ref $elements eq 'ARRAY');
        #     my $optionalfields = $self->handle_user_elements($user, $elements);
        #     $data->{UserOptionalFields} = $optionalfields;
        # }
        # $elements = $request->{$message}->{ItemElementType};
        # if ($elements) {
        #     $elements = [$elements] unless (ref($elements) eq 'ARRAY');
        #     my $optionalfields = $self->handle_item_elements($copy_details->{copy}, $elements);
        #     $data->{ItemOptionalFields} = $optionalfields;
        # }

    $response->data($data);
    return $response;

}

=head2 itemrequested

    $response = $ils->itemrequested($request);

Handle the NCIP ItemRequested message.

=cut

sub itemrequested {

    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    # FIXME $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # Get the ID of library we ordered from
    my $ordered_from = _isil2barcode( $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId} );

    # Create a minimal MARC record based on ItemOptionalFields
    my $bibdata = $request->{$message}->{ItemOptionalFields}->{BibliographicDescription};
    my $xml = '<record>
    <datafield tag="100" ind1=" " ind2=" ">
        <subfield code="a">' . $bibdata->{Author} . '</subfield>
    </datafield>
    <datafield tag="245" ind1=" " ind2=" ">
        <subfield code="a">' . $bibdata->{Title} . '</subfield>
    </datafield>
    <datafield tag="260" ind1=" " ind2=" ">
        <subfield code="a">' . $bibdata->{PlaceOfPublication} . '</subfield>
        <subfield code="b">' . $bibdata->{Publisher} .          '</subfield>
        <subfield code="c">' . $bibdata->{PublicationDate} .    '</subfield>
    </datafield>
    </record>';
    my $record = MARC::Record->new_from_xml( $xml, 'UTF-8' );
    my ( $biblionumber, $biblioitemnumber ) = AddBiblio( $record, 'FA' );

    # Add an item
    my $item = {
        'homebranch'    => 'ILL',
        'holdingbranch' => 'ILL',
        'itype'         => 'ILL',
    };
    my ( $x_biblionumber, $x_biblioitemnumber, $itemnumber ) = AddItem( $item, $biblionumber );

    # Get the borrower that the request is meant for
    my $cardnumber = $request->{$message}->{UserId}->{UserIdentifierValue};
    my $borrower = GetMemberDetails( undef, $cardnumber );

    # Create a new request with the newly created biblionumber
    my $illRequest   = Koha::ILLRequests->new;
    my $saved_request = $illRequest->request({
        'biblionumber' => $biblionumber,
        'branch'       => 'ILL', # FIXME
        'borrower'     => $borrower->{'borrowernumber'},
        'ordered_from' => $ordered_from,
    });
    $saved_request->editStatus({ 'status' => 'ORDERED' });

    my $data = {
        RequestType  => $message,
        ToAgencyId   => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
        FromAgencyId => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
        UserId       => $request->{$message}->{UserId}->{UserIdentifierValue},
        ItemId       => $request->{$message}->{ItemId}->{ItemIdentifierValue},
    };

    $response->data($data);
    return $response;

}

=head2 renewitem

    $response = $ils->renewitem($request);

Handle the NCIP RenewItem message.

=cut

sub renewitem {

    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    # FIXME $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # Find the cardnumber of the borrower
    my ( $cardnumber, $cardnumber_field ) = $self->find_user_barcode( $request );
    unless( $cardnumber ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Needed Data Missing',
            ProblemDetail  => 'Cannot find user barcode in message',
            ProblemElement => $cardnumber_field,
            ProblemValue   => 'NULL',
        });
        $response->problem($problem);
        return $response;
    }

    # Find the borrower based on the cardnumber
    my $borrower = GetMemberDetails( undef, $cardnumber );
    unless ( $borrower ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Unknown User',
            ProblemDetail  => "User with barcode $cardnumber unknown",
            ProblemElement => $cardnumber_field,
            ProblemValue   => 'NULL',
        });
        $response->problem($problem);
        return $response;
    }
    
    my $itemdata;
    # Find the barcode from the request, if there is one
    my ( $barcode, $barcode_field ) = $self->find_item_barcode($request);
    if ($barcode) {
        # We have a barcode (or something passing itself off as a barcode), 
        # try to use it to get item data
        $itemdata = GetItem( undef, $barcode );
        unless ( $itemdata ) {
            my $problem = NCIP::Problem->new({
                ProblemType    => 'Unknown Item',
                ProblemDetail  => "Item $barcode is unknown",
                ProblemElement => $barcode_field,
                ProblemValue   => $barcode,
            });
            $response->problem($problem);
            return $response;
        }
    }
    
    # Check if renewal is possible
    my ($ok,$error) = CanBookBeRenewed( $borrower->{'borrowernumber'}, $itemdata->{'itemnumber'} );
    unless ( $ok ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Item Not Renewable',
            ProblemDetail  => 'Item may not be renewed',
            # ProblemElement => 'FIXME',
            # ProblemValue   => 'FIXME',
        });
        $response->problem($problem);
        return $response;
    }

    # Do the actual renewal
    my $datedue = AddRenewal( $borrower->{'borrowernumber'}, $itemdata->{'itemnumber'} );
    if ( $datedue ) {
        # The renewal was successfull, change the status of the request
        # Find the request
        my $illRequests = Koha::ILLRequests->new;
        my $saved_requests = $illRequests->search({
            'status'         => 'RECEIVED',
            'remote_barcode' => $request->{$message}->{ItemId}->{ItemIdentifierValue},
        });
        # There should only be one request, so we use the zero'th one
        my $saved_request = $saved_requests->[0];
        $saved_request->editStatus({ 'status' => 'RENEWED' });
        # Check the number of remaning renewals
        my ( $renewcount, $renewsallowed, $renewsleft ) = GetRenewCount( $borrower->{'borrowernumber'}, $itemdata->{'itemnumber'} );
        # Send the response
        my $data = {
            ItemId => NCIP::Item::Id->new(
                {
                    AgencyId => $request->{$message}->{ItemId}->{AgencyId},
                    ItemIdentifierType => $request->{$message}->{ItemId}->{ItemIdentifierType},
                    ItemIdentifierValue => $request->{$message}->{ItemId}->{ItemIdentifierValue},
                }
            ),
            UserId => NCIP::User::Id->new(
                {
                    UserIdentifierType => 'Barcode Id',
                    UserIdentifierValue => $cardnumber,
                }
            ),
            DateDue      => $datedue,
            fromagencyid => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
            toagencyid   => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
            diag         => "renewals: $renewcount, renewals allowed: $renewsallowed, renewals left: $renewsleft",
        };
        $response->data($data);
        return $response;
    } else {
        # The renewal failed
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Item Not Renewable',
            ProblemDetail  => 'Item may not be renewed',
            # ProblemElement => 'FIXME',
            # ProblemValue   => 'FIXME',
        });
        $response->problem($problem);
        return $response;
    }

}

=head2 cancelrequestitem

    $response = $ils->cancelrequestitem($request);

Handle the NCIP CancelRequestItem message.

=cut

sub cancelrequestitem {

    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    # FIXME $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # Find the cardnumber of the borrower
    my ( $cardnumber, $cardnumber_field ) = $self->find_user_barcode( $request );
    unless( $cardnumber ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Needed Data Missing',
            ProblemDetail  => 'Cannot find user barcode in message',
            ProblemElement => $cardnumber_field,
            ProblemValue   => 'NULL',
        });
        $response->problem($problem);
        return $response;
    }

    # Find the borrower based on the cardnumber
    my $borrower = GetMemberDetails( undef, $cardnumber );
    unless ( $borrower ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Unknown User',
            ProblemDetail  => "User with barcode $cardnumber unknown",
            ProblemElement => $cardnumber_field,
            ProblemValue   => 'NULL',
        });
        $response->problem($problem);
        return $response;
    }

    my $requestid = $request->{$message}->{RequestId}->{RequestIdentifierValue};
    my $reserve = CancelReserve( { reserve_id => $requestid } );
    # CancelReserve returns data about the reserve on success, undef on failure
    # FIXME We can be more specific about the failure if we check the reserve
    # more in depth before we do CancelReserve, e.g. with GetReserve
    unless ( $reserve ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'FIXME RequestItem can not be cancelled',
            ProblemDetail  => "Request with id $requestid unknown",
            ProblemElement => 'RequestIdentifierValue',
            ProblemValue   => $requestid,
        });
        $response->problem($problem);
        return $response;
    }

    # If we got this far, the request was successfully cancelled
    my $data = {
        RequestId => NCIP::RequestId->new(
            {
                AgencyId => $request->{$message}->{RequestId}->{AgencyId},
                RequestIdentifierType => $request->{$message}->{RequestId}->{RequestIdentifierType},
                RequestIdentifierValue => $request->{$message}->{RequestId}->{RequestIdentifierValue},
            }
        ),
        UserId => NCIP::User::Id->new(
            {
                UserIdentifierType => 'Barcode Id',
                UserIdentifierValue => $borrower->{'cardnumber'},
            }
        ),
        ItemId => NCIP::Item::Id->new(
            {
                AgencyId => $request->{$message}->{ItemId}->{AgencyId},
                ItemIdentifierType => $request->{$message}->{ItemId}->{ItemIdentifierType},
                ItemIdentifierValue => $request->{$message}->{ItemId}->{ItemIdentifierValue},
            }
        ),
    };

    $response->data($data);
    return $response;

}

# Turn NO-xxxxxxx into xxxxxxx
sub _isil2barcode {

    my ( $s ) = @_;
    $s =~ s/^NO-//i;
    return $s;

}

=head2 _get_langcode_from_bibliodata 

Take a record and pick ut the language code in controlfield 008, position 35-37.

=cut

sub _get_langcode_from_bibliodata {

    my ( $bibliodata ) = @_;

    my $marcxml = $bibliodata->{'marcxml'};
    my $record = MARC::Record->new_from_xml( $marcxml, 'UTF-8' );
    my $f008 = $record->field( '008' )->data();
    my $lang_code = '   ';
    if ( $f008 ) {
        $lang_code = substr $f008, 35, 3;
    }
    return $lang_code;

}

=head2 log_to_ils

    $self->{ils}->log_to_ils( $xml );

We want to keep a log of all NCIP messages in one place - in the ILS. This
function will do that for us. 

=cut

sub log_to_ils {

    my ( $self, $type, $xml ) = @_;
    logaction( 'ILL', $type, undef, $xml );

}

1;
