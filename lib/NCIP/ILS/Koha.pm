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

use C4::Members qw{ GetMemberDetails };
use C4::Items qw { GetItem };
use C4::Reserves
  qw {CanBookBeReserved AddReserve GetReservesFromItemnumber CancelReserve GetReservesFromBiblionumber};

use NCIP::Item::Id;
use NCIP::Problem;
use NCIP::RequestId;
use NCIP::User::Id;

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
    unless ($borrower) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Unknown User',
            ProblemDetail  => "User with barcode $cardnumber unknown",
            ProblemElement => $cardnumber_field,
            ProblemValue   => 'NULL',
        });
        $response->problem($problem);
        return $response;
    }

    # FIXME Get rid of these? 
    my $result;
    my $biblionumber;
    
    my $itemdata;
    # Find the barcode from the request, if there is one
    my ( $barcode, $barcode_field ) = $self->find_item_barcode($request);
    if ($barcode) {
        # We have a barcode (or something passing itself off as a barcode), 
        # try to use it to get item data
        $itemdata = GetItem( undef, $barcode );
        # unless ( $itemdata ) {
        #     my $problem = NCIP::Problem->new({
        #         ProblemType    => 'Unknown Item',
        #         ProblemDetail  => "Item $barcode is unknown",
        #         ProblemElement => $barcode_field,
        #         ProblemValue   => $barcode,
        #     });
        #     $response->problem($problem);
        #     return $response;
        # }
    }
    
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

    # $self->userenv();
    my $request_id;

    # Check if it is possible to make a reservation
    if ( CanBookBeReserved( $borrower->{borrowernumber}, $itemdata->{biblionumber} )) {
        my $biblioitemnumber = $itemdata->{biblionumber};

        # Add reserve here
        # FIXME We should be able to place an ILL request in the ILL module as an alternative workflow
        AddReserve(
            $response->{'header'}->{'ToAgencyId'}->{'AgencyId'}, # branch
            $borrower->{borrowernumber},                         # borrowernumber
            $itemdata->{biblionumber},                           # biblionumber
            'a',                                                 # constraint
            [$biblioitemnumber],                                 # bibitems
            1,                                                   # priority
            undef,                                               # resdate
            undef,                                               # expdate
            'Placed By ILL',                                     # notes
            '',                                                  # title
            $itemdata->{'itemnumber'} || undef,                  # checkitem
            undef,                                               # found
        );
        if ($biblionumber) {
            my $reserves = GetReservesFromBiblionumber({
                biblionumber => $itemdata->{biblionumber}
            });
            $request_id = $reserves->[1]->{reserve_id};
        } else {
            my ( $reservedate, $borrowernumber, $branchcode2, $reserve_id,
                $wait )
              = GetReservesFromItemnumber( $itemdata->{'itemnumber'} );
            $request_id = $reserve_id;
        }
    } else {
        # A reservation can not be made
        my $problem = NCIP::Problem->new({
            ProblemType        => 'Item Does Not Circulate',
                ProblemDetail  => 'Request of Item cannot proceed because the Item is non-circulating',
                ProblemElement => 'BibliographicRecordIdentifier',
                ProblemValue   => 'NULL',
        });
        $response->problem($problem);
        return $response;

    }

    # Build the response    
    my $data = {
        RequestId => NCIP::RequestId->new(
            # FIXME Check if one was provided in $request->{$message}->{RequestId}
            $request_id # the id of the reserve we added
        ),
        ItemId => NCIP::Item::Id->new(
            {
                AgencyId => 'FIXME', # $selection_ou->shortname(),
                ItemIdentifierValue => 'FIXME', # $bre->id(),
                ItemIdentifierType => 'SYSNUMBER'
            }
        ),
        UserId => NCIP::User::Id->new(
            {
                UserIdentifierValue => $borrower->{'cardnumber'},
                UserIdentifierType => 'Barcode Id'
            }
        ),
        RequestType => $request->{$message}->{RequestType},
        RequestScopeType => 'TRUE', # FIXME
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

1;
