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
package NCIP::ILS::Evergreen;

use Modern::Perl;
use XML::LibXML::Simple qw(XMLin);
use DateTime;
use DateTime::Format::ISO8601;
use Digest::MD5 qw/md5_hex/;
use OpenSRF::System;
use OpenSRF::AppSession;
use OpenSRF::Utils qw/:datetime/;
use OpenSRF::Utils::SettingsClient;
use OpenILS::Utils::Fieldmapper;
use OpenILS::Utils::Normalize qw(clean_marc);
use OpenILS::Application::AppUtils;
use OpenILS::Const qw/:const/;
use MARC::Record;
use MARC::Field;
use MARC::File::XML;
use List::MoreUtils qw/uniq/;
use POSIX qw/strftime/;

# We need a bunch of NCIP::* objects.
use NCIP::Response;
use NCIP::Problem;
use NCIP::User;
use NCIP::User::OptionalFields;
use NCIP::User::AddressInformation;
use NCIP::User::Id;
use NCIP::User::BlockOrTrap;
use NCIP::User::Privilege;
use NCIP::User::PrivilegeStatus;
use NCIP::StructuredPersonalUserName;
use NCIP::StructuredAddress;
use NCIP::ElectronicAddress;
use NCIP::RequestId;
use NCIP::Item::Id;

# Inherit from NCIP::ILS.
use parent qw(NCIP::ILS);

=head1 NAME

Evergreen - Evergreen driver for NCIPServer

=head1 SYNOPSIS

    my $ils = NCIP::ILS::Evergreen->new(name => $config->{NCIP.ils.value});

=head1 DESCRIPTION

NCIP::ILS::Evergreen is the default driver for Evergreen and
NCIPServer. It was initially developed to work with Auto-Graphics'
SHAREit software using a subset of an unspecified ILL/DCB profile.

=cut

# Default values we define for things that might be missing in our
# runtime environment or configuration file that absolutely must have
# values.
#
# OILS_NCIP_CONFIG_DEFAULT is the default location to find our
# driver's configuration file.  This location can be overridden by
# setting the path in the OILS_NCIP_CONFIG environment variable.
#
# BIB_SOURCE_DEFAULT is the config.bib_source.id to use when creating
# "short" bibs.  It is used only if no entry is supplied in the
# configuration file.  The provided default is 2, the id of the
# "System Local" source that comes with a default Evergreen
# installation.
use constant {
    OILS_NCIP_CONFIG_DEFAULT => '/openils/conf/oils_ncip.xml',
    BIB_SOURCE_DEFAULT => 2
};

# A common Evergreen code shortcut to use AppUtils:
my $U = 'OpenILS::Application::AppUtils';

# The usual constructor:
sub new {
    my $class = shift;
    $class = ref($class) if (ref $class);

    # Instantiate our parent with the rest of the arguments.  It
    # creates a blessed hashref.
    my $self = $class->SUPER::new(@_);

    # Look for our configuration file, load, and parse it:
    $self->_configure();

    # Bootstrap OpenSRF and prepare some OpenILS components.
    $self->_bootstrap();

    # Initialize the rest of our internal state.
    $self->_init();

    return $self;
}

=head1 HANDLER METHODS

=head2 lookupuser

    $ils->lookupuser($request);

Processes a LookupUser request.

=cut

sub lookupuser {
    my $self = shift;
    my $request = shift;

    # Check our session and login if necessary.
    $self->login() unless ($self->checkauth());

    my $message_type = $self->parse_request_type($request);

    # Let's go ahead and create our response object. We need this even
    # if there is a problem.
    my $response = NCIP::Response->new({type => $message_type . "Response"});
    $response->header($self->make_header($request));

    # Need to parse the request object to get the user barcode.
    my ($barcode, $idfield) = $self->find_user_barcode($request);

    # If we did not find a barcode, then report the problem.
    if (ref($barcode) eq 'NCIP::Problem') {
        $response->problem($barcode);
        return $response;
    }

    # Look up our patron by barcode:
    my $user = $self->retrieve_user_by_barcode($barcode, $idfield);
    if (ref($user) eq 'NCIP::Problem') {
        $response->problem($user);
        return $response;
    }

    # We got the information, so lets fill in our userdata.
    my $userdata = NCIP::User->new();

    # Make an array of the user's active barcodes.
    my $ids = [];
    foreach my $card (@{$user->cards()}) {
        if ($U->is_true($card->active())) {
            my $id = NCIP::User::Id->new({
                UserIdentifierType => 'Barcode',
                UserIdentifierValue => $card->barcode()
            });
            push(@$ids, $id);
        }
    }
    $userdata->UserId($ids);

    # Check if they requested any optional fields and return those.
    my $elements = $request->{$message_type}->{UserElementType};
    if ($elements) {
        $elements = [$elements] unless (ref $elements eq 'ARRAY');
        my $optionalfields = NCIP::User::OptionalFields->new();

        # First, we'll look for name information.
        if (grep {$_ eq 'Name Information'} @$elements) {
            my $name = NCIP::StructuredPersonalUserName->new();
            $name->Surname($user->family_name());
            $name->GivenName($user->first_given_name());
            $name->Prefix($user->prefix());
            $name->Suffix($user->suffix());
            $optionalfields->NameInformation($name);
        }

        # Next, check for user address information.
        if (grep {$_ eq 'User Address Information'} @$elements) {
            my $addresses = [];

            # See if the user has any valid, physcial addresses.
            foreach my $addr (@{$user->addresses()}) {
                next if ($U->is_true($addr->pending()));
                my $address = NCIP::User::AddressInformation->new({UserAddressRoleType=>$addr->address_type()});
                my $physical = NCIP::StructuredAddress->new();
                $physical->Line1($addr->street1());
                $physical->Line2($addr->street2());
                $physical->Locality($addr->city());
                $physical->Region($addr->state());
                $physical->PostalCode($addr->post_code());
                $physical->Country($addr->country());
                $address->PhysicalAddress($physical);
                push @$addresses, $address;
            }

            # Right now, we're only sharing email address if the user
            # has it. We don't share phone numbers.
            if ($user->email()) {
                my $address = NCIP::User::AddressInformation->new({UserAddressRoleType=>'Email Address'});
                $address->ElectronicAddress(
                    NCIP::ElectronicAddress->new({
                        Type=>'Email Address',
                        Data=>$user->email()
                    })
                );
                push @$addresses, $address;
            }

            $optionalfields->UserAddressInformation($addresses);
        }

        # Check for User Privilege.
        if (grep {$_ eq 'User Privilege'} @$elements) {
            # Get the user's group:
            my $pgt = $U->simplereq(
                'open-ils.pcrud',
                'open-ils.pcrud.retrieve.pgt',
                $self->{session}->{authtoken},
                $user->profile()
            );
            if ($pgt) {
                my $privilege = NCIP::User::Privilege->new();
                $privilege->AgencyId($user->home_ou->shortname());
                $privilege->AgencyUserPrivilegeType($pgt->name());
                $privilege->ValidToDate($user->expire_date());
                $privilege->ValidFromDate($user->create_date());

                my $status = 'Active';
                if (_expired($user)) {
                    $status = 'Expired';
                } elsif ($U->is_true($user->barred())) {
                    $status = 'Barred';
                } elsif (!$U->is_true($user->active())) {
                    $status = 'Inactive';
                }
                if ($status) {
                    $privilege->UserPrivilegeStatus(
                        NCIP::User::PrivilegeStatus->new({
                            UserPrivilegeStatusType => $status
                        })
                    );
                }

                $optionalfields->UserPrivilege([$privilege]);
            }
        }

        # Check for Block Or Trap.
        if (grep {$_ eq 'Block Or Trap'} @$elements) {
            my $blocks = [];

            # First, let's check if the profile is blocked from ILL.
            if (grep {$_->id() == $user->profile()} @{$self->{blocked_profiles}}) {
                my $block = NCIP::User::BlockOrTrap->new();
                $block->AgencyId($user->home_ou->shortname());
                $block->BlockOrTrapType('Block Interlibrary Loan');
                push @$blocks, $block;
            }

            # Next, we loop through the user's standing penalties
            # looking for blocks on CIRC, HOLD, and RENEW.
            my ($have_circ, $have_renew, $have_hold) = (0,0,0);
            foreach my $penalty (@{$user->standing_penalties()}) {
                next unless($penalty->standing_penalty->block_list());
                my @block_list = split(/\|/, $penalty->standing_penalty->block_list());
                my $ou = $U->simplereq(
                    'open-ils.pcrud',
                    'open-ils.pcrud.retrieve.aou',
                    $self->{session}->{authtoken},
                    $penalty->org_unit()
                );

                # Block checkout.
                if (!$have_circ && grep {$_ eq 'CIRC'} @block_list) {
                    my $bot = NCIP::User::BlockOrTrap->new();
                    $bot->AgencyId($ou->shortname());
                    $bot->BlockOrTrapType('Block Checkout');
                    push @$blocks, $bot;
                    $have_circ = 1;
                }

                # Block holds.
                if (!$have_hold && grep {$_ eq 'HOLD' || $_ eq 'FULFILL'} @block_list) {
                    my $bot = NCIP::User::BlockOrTrap->new();
                    $bot->AgencyId($ou->shortname());
                    $bot->BlockOrTrapType('Block Holds');
                    push @$blocks, $bot;
                    $have_hold = 1;
                }

                # Block renewals.
                if (!$have_renew && grep {$_ eq 'RENEW'} @block_list) {
                    my $bot = NCIP::User::BlockOrTrap->new();
                    $bot->AgencyId($ou->shortname());
                    $bot->BlockOrTrapType('Block Renewals');
                    push @$blocks, $bot;
                    $have_renew = 1;
                }

                # Stop after we report one of each, even if more
                # blocks remain.
                last if ($have_circ && $have_renew && $have_hold);
            }

            $optionalfields->BlockOrTrap($blocks);
        }

        $userdata->UserOptionalFields($optionalfields);
    }

    $response->data($userdata);

    return $response;
}

=head2 acceptitem

    $ils->acceptitem($request);

Processes an AcceptItem request.

=cut

sub acceptitem {
    my $self = shift;
    my $request = shift;

    # Check our session and login if necessary.
    $self->login() unless ($self->checkauth());

    # Common preparation.
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # We only accept holds for the time being.
    if ($request->{$message}->{RequestedActionType} !~ /^hold\w/i) {
        # We need the item id or we can't do anything at all.
        my ($item_barcode, $item_idfield) = $self->find_item_barcode($request);
        if (ref($item_barcode) eq 'NCIP::Problem') {
            $response->problem($item_barcode);
            return $response;
        }

        # We need to find a patron barcode or we can't look anyone up
        # to place a hold.
        my ($user_barcode, $user_idfield) = $self->find_user_barcode($request, 'UserIdentifierValue');
        if (ref($user_barcode) eq 'NCIP::Problem') {
            $response->problem($user_barcode);
            return $response;
        }
        # Look up our patron by barcode:
        my $user = $self->retrieve_user_by_barcode($user_barcode, $user_idfield);
        if (ref($user) eq 'NCIP::Problem') {
            $response->problem($user);
            return $response;
        }
        # We're doing patron checks before looking for bibliographic
        # information and creating the item because problems with the
        # patron are more likely to occur.
        my $problem = $self->check_user_for_problems($user, 'HOLD');
        if ($problem) {
            $response->problem($problem);
            return $response;
        }

        # Check if the item barcode already exists:
        my $item = $self->retrieve_copy_details_by_barcode($item_barcode);
        if ($item) {
            # What to do here was not defined in the
            # specification. Since the copies that we create this way
            # should get deleted when checked in, it would be an error
            # if we try to create another one. It means that something
            # has gone wrong somewhere.
            $response->problem(
                NCIP::Problem->new(
                    {
                        ProblemType => 'Duplicate Item',
                        ProblemDetail => "Item with barcode $item_barcode already exists.",
                        ProblemElement => $item_idfield,
                        ProblemValue => $item_barcode
                    }
                )
            );
            return $response;
        }

        # Now, we have to create our new copy and/or bib and call number.

        # First, we have to gather the necessary information from the
        # request.  Store in a hashref for convenience. We may write a
        # method to get this information in the future if we find we
        # need it in other handlers. Such a function would be a
        # candidate to go into our parent, NCIP::ILS.
        my $item_info = {
            barcode => $item_barcode,
            call_number => $request->{$message}->{ItemOptionalFields}->{ItemDescription}->{CallNumber},
            title => $request->{$message}->{ItemOptionalFields}->{BibliographicDescription}->{Author},
            author => $request->{$message}->{ItemOptionalFields}->{BibliographicDescription}->{Title},
            publisher => $request->{$message}->{ItemOptionalFields}->{BibliographicDescription}->{Publisher},
            publication_date => $request->{$message}->{ItemOptionalFields}->{BibliographicDescription}->{PublicationDate},
            medium => $request->{$message}->{ItemOptionalFields}->{BibliographicDescription}->{MediumType},
            electronic => $request->{$message}->{ItemOptionalFields}->{BibliographicDescription}->{ElectronicResource}
        };

        if ($self->{config}->{items}->{use_precats}) {
            # We only need to create a precat copy.
            $item = $self->create_precat_copy($item_info);
        } else {
            # We have to create a "partial" bib record, a call number and a copy.
            $item = $self->create_fuller_copy($item_info);
        }

        # If we failed to create the copy, report a problem.
        unless ($item) {
            $response->problem(
                {
                    ProblemType => 'Temporary Processing Failure',
                    ProblemDetail => 'Failed to create the item in the system',
                    ProblemElement => $item_idfield,
                    ProblemValue => $item_barcode
                }
            );
            return $response;
        }

        # We try to find the pickup location in our database. It's OK
        # if it does not exist, the user's home library will be used
        # instead.
        my $location = $request->{$message}->{PickupLocation};
        if ($location) {
            $location = $self->retrieve_org_unit_by_shortname($location);
        }

        # Now, we place the hold on the newly created copy on behalf
        # of the patron retrieved above.
        my $hold = $self->place_hold($item, $user, $location);
        if (ref($hold) eq 'NCIP::Problem') {
            $response->problem($hold);
            return $response;
        }

        # We return the RequestId and optionally, the ItemID. We'll
        # just return what was sent to us, since we ignored all of it
        # but the barcode.
        my $data = {};
        $data->{RequestId} = NCIP::RequestId->new(
            {
                AgencyId => $request->{$message}->{RequestId}->{AgencyId},
                RequestIdentifierType => $request->{$message}->{RequestId}->{RequestIdentifierType},
                RequestIdentifierValue => $request->{$message}->{RequestId}->{RequestIdentifierValue}
            }
        );
        $data->{ItemId} = NCIP::Item::Id->new(
            {
                AgencyId => $request->{$message}->{ItemId}->{AgencyId},
                ItemIdentifierType => $request->{$message}->{ItemId}->{ItemIdentifierType},
                ItemIdentifierValue => $request->{$message}->{ItemId}->{ItemIdentifierValue}
            }
        );
        $response->data($data);

    } else {
        my $problem = NCIP::Problem->new();
        $problem->ProblemType('Unauthorized Combination Of Element Values For System');
        $problem->ProblemDetail('We only support Hold For Pickup');
        $problem->ProblemElement('RequestedActionType');
        $problem->ProblemValue($request->{$message}->{RequestedActionType});
        $response->problem($problem);
    }

    return $response;
}

=head2 checkinitem

    $response = $ils->checkinitem($request);

Checks the item in if we can find the barcode in the message. It
returns problems if it cannot find the item in the system or if the
item is not checked out.

It could definitely use some more brains at some point as it does not
fully support everything that the standard allows. It also does not
really check if the checkin succeeded or not.

=cut

sub checkinitem {
    my $self = shift;
    my $request = shift;

    # Check our session and login if necessary:
    $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # We need the copy barcode from the message.
    my ($item_barcode, $item_idfield) = $self->find_item_barcode($request);
    if (ref($item_barcode) eq 'NCIP::Problem') {
        $response->problem($item_barcode);
        return $response;
    }

    # Retrieve the copy details.
    my $details = $self->retrieve_copy_details_by_barcode($item_barcode);
    unless ($details) {
        # Return an Unkown Item problem unless we find the copy.
        $response->problem(
            NCIP::Problem->new(
                {
                    ProblemType => 'Unknown Item',
                    ProblemDetail => "Item with barcode $barcode is not known.",
                    ProblemElement => $item_idfield,
                    ProblemValue => $item_barcode
                }
            )
        );
        return $response;
    }

    # Look for a circulation and examine its information:
    my $circ = $details->{circ};
    if (!$circ || $circ->checkin_time()) {
        # Item isn't checked out.
        $response->problem(
            NCIP::Problem->new(
                {
                    ProblemType => 'Item Not Checked Out',
                    ProblemDetail => "Item with barcode $barcode not checkout out.",
                    ProblemElement => $item_idfield,
                    ProblemValue => $item_barcode
                }
            )
        );
    } else {
        # Isolate the copy.
        my $copy = $details->{copy};

        # Get data on the patron who has it checked out.
        my $user = $self->retrieve_user_by_id($details->{circ}->usr());

        # At some point in the future, we should probably check if the
        # request contains a user barcode. We would then look that
        # user up, too, and make sure it is the same user that has the
        # item checked out. If not, we would report a
        # problem. However, the user id is optional in the CheckInItem
        # message, and it doesn't look like our target system sends
        # it.

        # Checkin parameters. We want to skip hold targeting or making
        # transits, to force the checkin despite the copy status, as
        # well as void overdues.
        my $params = {
            barcode => $copy->barcode(),
            force => 1,
            noop => 1,
            void_overdues => 1
        };
        my $result = $U->simplereq(
            'open-ils.circ',
            'open-ils.circ.checkin.override',
            $self->{session}->{authtoken},
            $params
        );

        # We should check for errors here, but I'll leave that for
        # later.

        my $data = {
            ItemId => NCIP::Item::Id->new(
                {
                    AgencyId => $request->{$message}->{ItemId}->{AgencyId},
                    ItemIdentifierType => $request->{$message}->{ItemId}->{ItemIdentifierType},
                    ItemIdentifierValue => $request->{$message}->{ItemId}->{ItemIdentifierValue}
                }
            ),
            UserId => NCIP::User::Id->new(
                {
                    UserIdentifierType => 'Barcode Id',
                    UserIdentifierValue => $user->card->barcode()
                }
            )
        };

        $response->data($data);

        # At some point in the future, we should probably check if
        # they requested optional user or item elements and return
        # those. For the time being, we ignore those at the risk of
        # being considered non-compliant.
    }

    return $response
}

=head1 METHODS USEFUL to SUBCLASSES

=head2 login

    $ils->login();

Login to Evergreen via OpenSRF. It uses internal state from the
configuration file to login.

=cut

# Login via OpenSRF to Evergreen.
sub login {
    my $self = shift;

    # Get the authentication seed.
    my $seed = $U->simplereq(
        'open-ils.auth',
        'open-ils.auth.authenticate.init',
        $self->{config}->{credentials}->{username}
    );

    # Actually login.
    if ($seed) {
        my $response = $U->simplereq(
            'open-ils.auth',
            'open-ils.auth.authenticate.complete',
            {
                username => $self->{config}->{credentials}->{username},
                password => md5_hex(
                    $seed . md5_hex($self->{config}->{credentials}->{password})
                ),
                type => 'staff',
                workstation => $self->{config}->{credentials}->{workstation}
            }
        );
        if ($response) {
            $self->{session}->{authtoken} = $response->{payload}->{authtoken};
            $self->{session}->{authtime} = $response->{payload}->{authtime};

            # Set/reset the work_ou and user data in case something changed.

            # Retrieve the work_ou as an object.
            $self->{session}->{work_ou} = $U->simplereq(
                'open-ils.pcrud',
                'open-ils.pcrud.search.aou',
                $self->{session}->{authtoken},
                {shortname => $self->{config}->{credentials}->{work_ou}}
            );

            # We need the user information in order to do some things.
            $self->{session}->{user} = $U->check_user_session($self->{session}->{authtoken});

        }
    }
}

=head2 checkauth

    $valid = $ils->checkauth();

Returns 1 if the object a 'valid' authtoken, 0 if not.

=cut

sub checkauth {
    my $self = shift;

    # We use AppUtils to do the heavy lifting.
    if (defined($self->{session})) {
        if ($U->check_user_session($self->{session}->{authtoken})) {
            return 1;
        } else {
            return 0;
        }
    }

    # If we reach here, we don't have a session, so we are definitely
    # not logged in.
    return 0;
}

=head2 retrieve_user_by_barcode

    $user = $ils->retrieve_user_by_barcode($user_barcode, $user_idfield);

Do a fleshed retrieve of a patron by barcode. Return the patron if
found and valid. Return a NCIP::Problem of 'Unknown User' otherwise.

The id field argument is used for the ProblemElement field in the
NCIP::Problem object.

An invalid patron is one where the barcode is not found in the
database, the patron is deleted, or the barcode used to retrieve the
patron is not active. The problem element is also returned if an error
occurs during the retrieval.

=cut

sub retrieve_user_by_barcode {
    my ($self, $barcode, $idfield) = @_;
    my $result = $U->simplereq(
        'open-ils.actor',
        'open-ils.actor.user.fleshed.retrieve_by_barcode',
        $self->{session}->{authtoken},
        $barcode,
        1
    );

    # Check for a failure, or a deleted, inactive, or expired user,
    # and if so, return empty userdata.
    if (!$result || $U->event_code($result) || $U->is_true($result->deleted())
            || !grep {$_->barcode() eq $barcode && $U->is_true($_->active())} @{$result->cards()}) {

        my $problem = NCIP::Problem->new();
        $problem->ProblemType('Unknown User');
        $problem->ProblemDetail("User with barcode $barcode unknown");
        $problem->ProblemElement($idfield);
        $problem->ProblemValue($barcode);
        $result = $problem;
    }

    return $result;
}

=head2 retrieve_user_by_id

    $user = $ils->retrieve_user_by_id($id);

Similar to C<retrieve_user_by_barcode> but takes the user's database
id rather than barcode. This is useful when you have a circulation or
hold and need to get information about the user's involved in the hold
or circulaiton.

It returns a fleshed user on success or undef on failure.

=cut

sub retrieve_user_by_id {
    my ($self, $id) = @_;

    # Do a fleshed retrieve of the patron, and flesh the fields that
    # we would normally use.
    my $result = $U->simplereq(
        'open-ils.actor',
        'open-ils.actor.user.fleshed.retrieve',
        $self->{session}->{authtoken},
        $id,
        [ 'card', 'cards', 'standing_penalties', 'addresses', 'home_ou' ]
    );
    # Check for an error.
    undef($result) if ($result && $U->event_code($result));

    return $result;
}

=head2 check_user_for_problems

    $problem = $ils>check_user_for_problems($user, 'HOLD, 'CIRC', 'RENEW');

This function checks if a user has a blocked profile or any from a
list of provided blocks. If it does, then a NCIP::Problem object is
returned, otherwise an undefined value is returned.

The list of blocks appears as additional arguments after the user. You
can provide any value(s) that might appear in a standing penalty block
lit in Evergreen. The example above checks for HOLD, CIRC, and
RENEW. Any number of such values can be provided. If none are
provided, the function only checks if the patron's profiles appears in
the object's blocked profiles list.

It stops on the first matching block, if any.

=cut

sub check_user_for_problems {
    my $self = shift;
    my $user = shift;
    my @blocks = @_;

    # Fill this in if we have a problem, otherwise just return it.
    my $problem;

    # First, check the user's profile.
    if (grep {$_->id() == $user->profile()} @{$self->{blocked_profiles}}) {
        $problem = NCIP::Problem->new(
            {
                ProblemType => 'User Blocked',
                ProblemDetail => 'User blocked from inter-library loan',
                ProblemElement => 'NULL',
                ProblemValue => 'NULL'
            }
        );
    }

    # Next, check if the patron has one of the indicated blocks.
    unless ($problem) {
        foreach my $block (@blocks) {
            if (grep {$_->standing_penalty->block_list() =~ /$block/} @{$user->standing_penalties()}) {
                $problem = NCIP::Problem->new(
                    {
                        ProblemType => 'User Blocked',
                        ProblemDetail => 'User blocked from ' .
                            ($block eq 'HOLD') ? 'holds' : (($block eq 'RENEW') ? 'renewals' :
                                                                (($block eq 'CIRC') ? 'checkout' : lc($block))),
                        ProblemElement => 'NULL',
                        ProblemValue => 'NULL'
                    }
                );
                last;
            }
        }
    }

    return $problem;
}

=head2 retrieve_copy_details_by_barcode

    $copy = $ils->retrieve_copy_details_by_barcode($copy_barcode);

Look up and retrieve some copy details by the copy barcode. This
method returns either a hashref with the copy details or undefined if
no copy exists with that barcode or if some error occurs.

The hashref has the fields copy, hold, transit, circ, volume, and mvr.

This method differs from C<retrieve_user_by_barcode> in that a copy
cannot be invalid if it exists and it is not always an error if no
copy exists. In some cases, when handling AcceptItem, we might prefer
there to be no copy.

=cut

sub retrieve_copy_details_by_barcode {
    my $self = shift;
    my $barcode = shift;

    my $copy = $U->simplereq(
        'open-ils.circ',
        'open-ils.circ.copy_details.retrieve.barcode',
        $self->{session}->{authtoken},
        $barcode
    );

    # If $copy is an event, return undefined.
    if ($copy && $U->event_code($copy)) {
        undef($copy);
    }

    return $copy;
}

=head2 retrieve_org_unit_by_shortname

    $org_unit = $ils->retrieve_org_unit_by_shortname($shortname);

Retrieves an org. unit from the database by shortname. Returns the
org. unit as a Fieldmapper object or undefined.

=cut

sub retrieve_org_unit_by_shortname {
    my $self = shift;
    my $shortname = shift;

    my $aou = $U->simplereq(
        'open-ils.pcrud',
        'open-ils.pcrud.search.aou',
        $self->{session}->{authtoken},
        {shortname => {'=' => {transform => 'lower', value => ['lower', $shortname]}}}
    );

    return $aou;
}

=head2 create_precat_copy

    $item_info->{
        barcode => '312340123456789',
        author => 'Public, John Q.',
        title => 'Magnum Opus',
        call_number => '005.82',
        publisher => 'Brick House',
        publication_date => '2014'
    };

    $item = $ils->create_precat_copy($item_info);


Create a "precat" copy to use for the incoming item using a hashref of
item information. At a minimum, the barcode, author and title fields
need to be filled in. The other fields are ignored if provided.

This method is called by the AcceptItem handler if the C<use_precats>
configuration option is turned on.

=cut

sub create_precat_copy {
    my $self = shift;
    my $item_info = shift;

    my $item = Fieldmapper::asset::copy->new();
    $item->barcode($item_info->{barcode});
    $item->call_number(OILS_PRECAT_CALL_NUMBER);
    $item->dummy_title($item_info->{title});
    $item->dummy_author($item_info->{author});
    $item->circ_lib($self->{session}->{work_ou}->id());
    $item->circulate('t');
    $item->holdable('t');
    $item->opac_visible('f');
    $item->deleted('f');
    $item->fine_level(OILS_PRECAT_COPY_FINE_LEVEL);
    $item->loan_duration(OILS_PRECAT_COPY_LOAN_DURATION);
    $item->location(1);
    $item->status(0);
    $item->editor($self->{session}->{user}->id());
    $item->creator($self->{session}->{user}->id());
    $item->isnew(1);

    # Actually create it:
    my $xact;
    my $ses = OpenSRF::AppSession->create('open-ils.pcrud');
    $ses->connect();
    eval {
        $xact = $ses->request(
            'open-ils.pcrud.transaction.begin',
            $self->{session}->{authtoken}
        )->gather(1);
        $item = $ses->request(
            'open-ils.pcrud.create.acp',
            $self->{session}->{authtoken},
            $item
        )->gather(1);
        $xact = $ses->request(
            'open-ils.pcrud.transaction.commit',
            $self->{session}->{authtoken}
        )->gather(1);
    };
    if ($@) {
        undef($item);
        if ($xact) {
            eval {
                $ses->request(
                    'open-ils.pcrud.transaction.rollback',
                    $self->{session}->{authtoken}
                )->gather(1);
            };
        }
    }
    $ses->disconnect();

    return $item;
}

=head2 create_fuller_copy

    $item_info->{
        barcode => '31234003456789',
        author => 'Public, John Q.',
        title => 'Magnum Opus',
        call_number => '005.82',
        publisher => 'Brick House',
        publication_date => '2014'
    };

    $item = $ils->create_fuller_copy($item_info);

Creates a skeletal bibliographic record, call number, and copy for the
incoming item using a hashref with item information in it. At a
minimum, the barcode, author, title, and call_number fields must be
filled in.

This method is used by the AcceptItem handler if the C<use_precats>
configuration option is NOT set.

=cut

sub create_fuller_copy {
    my $self = shift;
    my $item_info = shift;

    my $item;

    # We do everything in one transaction, because it should be atomic.
    my $ses = OpenSRF::AppSession->create('open-ils.pcrud');
    $ses->connect();
    my $xact;
    eval {
        $xact = $ses->request(
            'open-ils.pcrud.transaction.begin',
            $self->{session}->{authtoken}
        )->gather(1);
    };
    if ($@) {
        undef($xact);
    }

    # The rest depends on there being a transaction.
    if ($xact) {

        # Create the MARC record.
        my $record = MARC::Record->new();
        $record->encoding('UTF-8');
        $record->leader('00881nam a2200193   4500');
        my $datespec = strftime("%Y%m%d%H%M%S.0", localtime);
        my @fields = ();
        push(@fields, MARC::Field->new('005', $datespec));
        push(@fields, MARC::Field->new('082', '0', '4', 'a' => $item_info->{call_number}));
        push(@fields, MARC::Field->new('245', '0', '0', 'a' => $item_info->{title}));
        # Publisher is a little trickier:
        if ($item_info->{publisher}) {
            my $pub = MARC::Field->new('260', ' ', ' ', 'a' => '[S.l.]', 'b' => $item_info->{publisher});
            $pub->add_subfields('c' => $item_info->{publication_date}) if ($item_info->{publication_date});
            push(@fields, $pub);
        }
        # We have no idea if the author is personal corporate or something else, so we use a 720.
        push(@fields, MARC::Field->new('720', ' ', ' ', 'a' => $item_info->{author}, '4' => 'aut'));
        $record->append_fields(@fields);
        my $marc = clean_marc($record);

        # Create the bib object.
        my $bib = Fieldmapper::biblio::record_entry->new();
        $bib->creator($self->{session}->{user}->id());
        $bib->editor($self->{session}->{user}->id());
        $bib->source($self->{bib_source}->id());
        $bib->active('t');
        $bib->deleted('f');
        $bib->marc($marc);
        $bib->isnew(1);

        eval {
            $bib = $ses->request(
                'open-ils.pcrud.create.bre',
                $self->{session}->{authtoken},
                $bib
            )->gather(1);
        };
        if ($@) {
            undef($bib);
            eval {
                $ses->request(
                    'open-ils.pcrud.transaction.rollback',
                    $self->{session}->{authtoken}
                )->gather(1);
            };
        }

        # Create the call number
        my $acn;
        if ($bib) {
            $acn = Fieldmapper::asset::call_number->new();
            $acn->creator($self->{session}->{user}->id());
            $acn->editor($self->{session}->{user}->id());
            $acn->label($item_info->{call_number});
            $acn->record($bib->id());
            $acn->owning_lib($self->{session}->{work_ou}->id());
            $acn->deleted('f');
            $acn->isnew(1);

            eval {
                $acn = $ses->request(
                    'open-ils.pcrud.create.acn',
                    $self->{session}->{authtoken},
                    $acn
                )->gather(1);
            };
            if ($@) {
                undef($acn);
                eval {
                    $ses->request(
                        'open-ils.pcrud.transaction.rollback',
                        $self->{session}->{authtoken}
                    )->gather(1);
                };
            }
        }

        # create the copy
        if ($acn) {
            $item = Fieldmapper::asset::copy->new();
            $item->barcode($item_info->{barcode});
            $item->call_number($acn->id());
            $item->circ_lib($self->{session}->{work_ou}->id);
            $item->circulate('t');
            $item->holdable('t');
            $item->opac_visible('f');
            $item->deleted('f');
            $item->fine_level(OILS_PRECAT_COPY_FINE_LEVEL);
            $item->loan_duration(OILS_PRECAT_COPY_LOAN_DURATION);
            $item->location(1);
            $item->status(0);
            $item->editor($self->{session}->{user}->id);
            $item->creator($self->{session}->{user}->id);
            $item->isnew(1);

            eval {
                $item = $ses->request(
                    'open-ils.pcrud.create.acp',
                    $self->{session}->{authtoken},
                    $item
                )->gather(1);

                # Cross our fingers and commit the work.
                $xact = $ses->request(
                    'open-ils.pcrud.transaction.commit',
                    $self->{session}->{authtoken}
                )->gather(1);
            };
            if ($@) {
                undef($item);
                eval {
                    $ses->request(
                        'open-ils.pcrud.transaction.rollback',
                        $self->{session}->{authtoken}
                    )->gather(1) if ($xact);
                };
            }
        }
    }

    # We need to disconnect our session.
    $ses->disconnect();

    # Now, we handle our asset stat_cat entries.
    if ($item) {
        # It would be nice to do these in the above transaction, but
        # pcrud does not support the ascecm object, yet.
        foreach my $entry (@{$self->{stat_cat_entries}}) {
            my $map = Fieldmapper::asset::stat_cat_entry_copy_map->new();
            $map->isnew(1);
            $map->stat_cat($entry->stat_cat());
            $map->stat_cat_entry($entry->id());
            $map->owning_copy($item->id());
            # We don't really worry if it succeeds or not.
            $U->simplereq(
                'open-ils.circ',
                'open-ils.circ.stat_cat.asset.copy_map.create',
                $self->{session}->{authtoken},
                $map
            );
        }
    }

    return $item;
}

=head2 place_hold

    $hold = $ils->place_hold($item, $user, $location);

This function places a hold on $item for $user for pickup at
$location. If location is not provided or undefined, the user's home
library is used as a fallback.

$item can be a copy (asset::copy), volume (asset::call_number), or bib
(biblio::record_entry). The appropriate hold type will be placed
depending on the object.

On success, the method returns the object representing the hold. On
failure, a NCIP::Problem object, describing the failure, is returned.

=cut

sub place_hold {
    my $self = shift;
    my $item = shift;
    my $user = shift;
    my $location = shift;

    # If $location is undefined, use the user's home_ou, which should
    # have been fleshed when the user was retrieved.
    $location = $user->home_ou() unless ($location);

    # $hold is the hold. $params is for the is_possible check.
    my ($hold, $params);

    # Prep the hold with fields common to all hold types:
    $hold = Fieldmapper::action::hold_request->new();
    $hold->isnew(1); # Just to make sure.
    $hold->target($item->id());
    $hold->usr($user->id());
    $hold->pickup_lib($location->id());
    if (!$user->email()) {
        $hold->email_notify('f');
        $hold->phone_notify($user->day_phone()) if ($user->day_phone());
    } else {
        $hold->email_notify('t');
    }

    # Ditto the params:
    $params = { pickup_lib => $location->id(), patronid => $user->id() };

    if (ref($item) eq 'Fieldmapper::asset::copy') {
        $hold->hold_type('C');
        $hold->current_copy($item->id());
        $params->{hold_type} = 'C';
        $params->{copy_id} = $item->id();
    } elsif (ref($item) eq 'Fieldmapper::asset::call_number') {
        $hold->hold_type('V');
        $params->{hold_type} = 'V';
        $params->{volume_id} = $item->id();
    } elsif (ref($item) eq 'Fieldmapper::biblio::record_entry') {
        $hold->hold_type('T');
        $params->{hold_type} = 'T';
        $params->{titleid} = $item->id();
    }

    # Check if the hold is possible:
    my $r = $U->simplereq(
        'open-ils.circ',
        'open-ils.circ.title_hold.is_possible',
        $self->{session}->{authtoken},
        $params
    );

    if ($r->{success}) {
        $hold = $U->simplereq(
            'open-ils.circ',
            'open-ils.circ.holds.create.override',
            $self->{session}->{authtoken},
            $hold
        );
        if (ref($hold) eq 'HASH') {
            $hold = _problem_from_event('Request Not Possible', $hold);
        }
    } elsif ($r->{last_event}) {
        $hold = _problem_from_event('Request Not Possible', $r->{last_event});
    } elsif ($r->{text_code}) {
        $hold = _problem_from_event('Request Not Possible', $r);
    } else {
        $hold = _problem_from_event('Request Not Possible');
    }

    return $hold;
}

=head1 OVERRIDDEN PARENT METHODS

=head2 find_user_barcode

We dangerously override our parent's C<find_user_barcode> to return
either the $barcode or a Problem object. In list context the barcode
or problem will be the first argument and the id field, if any, will
be the second. We also add a second, optional, argument to indicate a
default value for the id field in the event of a failure to find
anything at all. (Perl lets us get away with this.)

=cut

sub find_user_barcode {
    my $self = shift;
    my $request = shift;
    my $default = shift;

    unless ($default) {
        my $message = $self->parse_request_type($request);
        if ($message eq 'LookupUser') {
            $default = 'AuthenticationInputData';
        } else {
            $default = 'UserIdentifierValue';
        }
    }

    my ($value, $idfield) = $self->SUPER::find_user_barcode($request);

    unless ($value) {
        $idfield = $default unless ($idfield);
        $value = NCIP::Problem->new();
        $value->ProblemType('Needed Data Missing');
        $value->ProblemDetail('Cannot find user barcode in message.');
        $value->ProblemElement($idfield);
        $value->ProblemValue('NULL');
    }

    return (wantarray) ? ($value, $idfield) : $value;
}

=head2 find_item_barcode

We do pretty much the same thing as with C<find_user_barcode> for
C<find_item_barcode>.

=cut

sub find_item_barcode {
    my $self = shift;
    my $request = shift;
    my $default = shift || 'ItemIdentifierValue';

    my ($value, $idfield) = $self->SUPER::find_item_barcode($request);

    unless ($value) {
        $idfield = $default unless ($idfield);
        $value = NCIP::Problem->new();
        $value->ProblemType('Needed Data Missing');
        $value->ProblemDetail('Cannot find item barcode in message.');
        $value->ProblemElement($idfield);
        $value->ProblemValue('NULL');
    }

    return (wantarray) ? ($value, $idfield) : $value;
}

# private subroutines not meant to be used directly by subclasses.
# Most have to do with setup and/or state checking of implementation
# components.

# Find, load, and parse our configuration file:
sub _configure {
    my $self = shift;

    # Find the configuration file via variables:
    my $file = OILS_NCIP_CONFIG_DEFAULT;
    $file = $ENV{OILS_NCIP_CONFIG} if ($ENV{OILS_NCIP_CONFIG});

    $self->{config} = XMLin($file, NormaliseSpace => 2,
                            ForceArray => ['block_profile', 'stat_cat_entry']);
}

# Bootstrap OpenSRF::System and load the IDL.
sub _bootstrap {
    my $self = shift;

    my $bootstrap_config = $self->{config}->{bootstrap};
    OpenSRF::System->bootstrap_client(config_file => $bootstrap_config);

    my $idl = OpenSRF::Utils::SettingsClient->new->config_value("IDL");
    Fieldmapper->import(IDL => $idl);
}

# Login and then initialize some object data based on the
# configuration.
sub _init {
    my $self = shift;

    # Login to Evergreen.
    $self->login();

    # Load the barred groups as pgt objects into a blocked_profiles
    # list.
    $self->{blocked_profiles} = [];
    foreach (@{$self->{config}->{patrons}->{block_profile}}) {
        my $pgt;
        if (ref $_) {
            $pgt = $U->simplereq(
                'open-ils.pcrud',
                'open-ils.pcrud.retrieve.pgt',
                $self->{session}->{authtoken},
                $_->{grp}
            );
        } else {
            $pgt = $U->simplereq(
                'open-ils.pcrud',
                'open-ils.pcrud.search.pgt',
                $self->{session}->{authtoken},
                {name => $_}
            );
        }
        push(@{$self->{blocked_profiles}}, $pgt) if ($pgt);
    }

    # Load the bib source if we're not using precats.
    unless ($self->{config}->{items}->{use_precats}) {
        # Retrieve the default
        $self->{bib_source} = $U->simplereq(
            'open-ils.pcrud',
            'open-ils.pcrud.retrieve.cbs',
            $self->{session}->{authtoken},
            BIB_SOURCE_DEFAULT);
        my $data = $self->{config}->{items}->{bib_source};
        if ($data) {
            $data = $data->[0] if (ref($data) eq 'ARRAY');
            my $result;
            if (ref $data) {
                $result = $U->simplereq(
                    'open-ils.pcrud',
                    'open-ils.pcrud.retrieve.cbs',
                    $self->{session}->{authtoken},
                    $data->{cbs}
                );
            } else {
                $result = $U->simplereq(
                    'open-ils.pcrud',
                    'open-ils.pcrud.search.cbs',
                    $self->{session}->{authtoken},
                    {source => $data}
                );
            }
            $self->{bib_source} = $result if ($result);
        }
    }

    # Load the required asset.stat_cat_entries:
    $self->{stat_cat_entries} = [];
    # First, make a regex for our ou and ancestors:
    my $ancestors = join("|", @{$U->get_org_ancestors($self->{session}->{work_ou}->id())});
    my $re = qr/(?:$ancestors)/;
    # Get the uniq stat_cat ids from the configuration:
    my @cats = uniq map {$_->{stat_cat}} @{$self->{config}->{items}->{stat_cat_entry}};
    # Retrieve all of the fleshed stat_cats and entries for the above.
    my $stat_cats = $U->simplereq(
        'open-ils.circ',
        'open-ils.circ.stat_cat.asset.retrieve.batch',
        $self->{session}->{authtoken},
        @cats
    );
    foreach my $entry (@{$self->{config}->{items}->{stat_cat_entry}}) {
        # Must have the stat_cat attr and the name, so we must have a
        # reference.
        next unless(ref $entry);
        my ($stat) = grep {$_->id() == $entry->{stat_cat}} @$stat_cats;
        push(@{$self->{stat_cat_entries}}, grep {$_->owner() =~ $re && $_->value() eq $entry->{content}} @{$stat->entries()});
    }
}

# Standalone, "helper" functions.  These do not take an object or
# class reference.

# Check if a user is past their expiration date.
sub _expired {
    my $user = shift;
    my $expired = 0;

    # Users might not expire.  If so, they have no expire_date.
    if ($user->expire_date()) {
        my $expires = DateTime::Format::ISO8601->parse_datetime(
            cleanse_ISO8601($user->expire_date())
        )->epoch();
        my $now = DateTime->now()->epoch();
        $expired = $now > $expires;
    }

    return $expired;
}

# Creates a NCIP Problem from an event. Takes a string for the problem
# type, the event hashref, and optional arguments for the
# ProblemElement and ProblemValue fields.
sub _problem_from_event {
    my ($type, $evt, $element, $value) = @_;

    my $detail;

    # This block will likely need to get smarter in the near future.
    if ($evt) {
        if ($evt->{text_code} eq 'PERM_FAILURE') {
            $detail = 'Permission Failure: ' . $evt->{ilsperm};
            $detail =~ s/\.override$//;
        } else {
            $detail = 'ILS returned ' . $evt->{text_code} . ' error.';
        }
    } else {
        $detail = 'Detail not available.';
    }

    return NCIP::Problem->new(
        {
            ProblemType => $type,
            ProblemDetail => $detail,
            ProblemElement => ($element) ? $element : 'NULL',
            ProblemValue => ($value) ? $value : 'NULL'
        }
    );
}

1;
