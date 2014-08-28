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
use OpenSRF::Utils qw/:datetime/;
use OpenSRF::Utils::SettingsClient;
use OpenILS::Utils::Fieldmapper;
use OpenILS::Application::AppUtils;
use OpenILS::Const qw/:const/;
use MARC::Record;
use MARC::Field;
use MARC::File::XML;

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

# Inherit from NCIP::ILS.
use parent qw(NCIP::ILS);

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

    # If we can't find a barcode, report a problem.
    unless ($barcode) {
        $idfield = 'AuthenticationInputType' unless ($idfield);
        # Fill in a problem object and stuff it in the response.
        my $problem = NCIP::Problem->new();
        $problem->ProblemType('Needed Data Missing');
        $problem->ProblemDetail('Cannot find user barcode in message.');
        $problem->ProblemElement($idfield);
        $problem->ProblemValue('Barcode');
        $response->problem($problem);
        return $response;
    }

    # Look up our patron by barcode:
    my $user = $U->simplereq(
        'open-ils.actor',
        'open-ils.actor.user.fleshed.retrieve_by_barcode',
        $self->{session}->{authtoken},
        $barcode,
        1
    );

    # Check for a failure, or a deleted, inactive, or expired user,
    # and if so, return empty userdata.
    if (!$user || $U->event_code($user) || $U->is_true($user->deleted())
            || !grep {$_->barcode() eq $barcode && $U->is_true($_->active())} @{$user->cards()}) {

        my $problem = NCIP::Problem->new();
        $problem->ProblemType('Unknown User');
        $problem->ProblemDetail("User with barcode $barcode unknown");
        $problem->ProblemElement($idfield);
        $problem->ProblemValue($barcode);
        $response->problem($problem);
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

# Implementation functions that might be useful to a subclass.

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
        }
    }
}

# Return 1 if we have a 'valid' authtoken, 0 if not.
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

    # Retrieve the work_ou as an object.
    $self->{work_ou} = $U->simplereq(
        'open-ils.pcrud',
        'open-ils.pcrud.search.aou',
        $self->{session}->{authtoken},
        {shortname => $self->{config}->{credentials}->{work_ou}}
    );

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
    foreach (@{$self->{config}->{items}->{stat_cat_entry}}) {
        # Must have the stat_cat attr and the name, so we must have a
        # reference.
        next unless(ref $_);
        # We want to limit the search to the work org and its
        # ancestors.
        my $ancestors = $U->get_org_ancestors($self->{work_ou}->id());
        # We only want 1, so we don't do .atomic.
        my $result = $U->simplereq(
            'open-ils.cstore',
            'open-ils.cstore.direct.asset.stat_cat_entry.search',
            {
                stat_cat => $_->{stat_cat},
                value => $_->{content},
                owner => $ancestors
            }
        );
        push(@{$self->{stat_cat_entries}}, $result) if ($result);
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

1;
