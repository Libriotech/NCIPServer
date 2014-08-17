# ---------------------------------------------------------------
# Copyright © 2014 Jason Stephenson <jason@sigio.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# ---------------------------------------------------------------
package NCIP::ILS::Evergreen;

use Modern::Perl;
use Object::Tiny qw/name/;
use XML::LibXML::Simple qw(XMLin);
use DateTime;
use DateTime::Format::ISO8601;
use Digest::MD5 qw/md5_hex/;
use OpenSRF::System;
use OpenSRF::Utils qw/:datetime/;
use OpenSRF::Utils::SettingsClient;
use OpenILS::Utils::Fieldmapper;
use OpenILS::Utils::CStoreEditor qw/:funcs/;
use OpenILS::Application::AppUtils;
use OpenILS::Const qw/:const/;
use MARC::Record;
use MARC::Field;
use MARC::File::XML;

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
    $class = ref $class or $class;

    # Instantiate our Object::Tiny parent with the rest of the
    # arguments.  It creates a blessed hashref.
    my $self = $class->SUPER::new(@_);

    # Look for our configuration file, load, and parse it:
    $self->_configure();

    # Bootstrap OpenSRF and prepare some OpenILS components.
    $self->_bootstrap();

    # Initialize the rest of our internal state.
    $self->_init();

    return $self;
}

# Subroutines required by the NCIPServer interface:
sub itemdata {}

sub userdata {
    my $self = shift;
    my $barcode = shift;

    # Check our session and login if necessary.
    $self->login() unless ($self->checkauth());

    # Initialize the hashref we need to return to the caller.
    my $userdata = {
        borrowernumber => '',
        cardnumber => '',
        streetnumber => '',
        address => '',
        address2 => '',
        city => '',
        state => '',
        zipcode => '',
        country => '',
        firstname => '',
        surname => '',
        blocked => ''
    };

    # Look up our patron by barcode:
    my $user = $U->simplereq(
        'open-ils.actor',
        'open-ils.actor.user.fleshed.retrieve_by_barcode',
        $barcode,
        0
    );

    # Check for a failure, or a deleted, inactive, or expired user,
    # and if so, return empty userdata.
    if (!$user || $U->event_code($user) || $user->deleted() || !$user->active()
            || _expired($user) || !$user->card()->active()) {
        # We'll return the empty userdata hashref to indicate a patron
        # was not found.
        return ($userdata, 'Borrower not found');
    }

    # We also need to check if the barcode used to retrieve the patron
    # is an active barcode.
    if (!grep {$_->barcode() eq $barcode && $_->active()} @{$user->cards()}) {
        return ($userdata, 'Borrower not found');
    }

    # We got the information, so lets fill in our userdata.
    $userdata->{borrowernumber} = $user->id();
    $userdata->{cardnumber} = $user->card()->barcode();
    $userdata->{firstname} = $user->first_given_name();
    $userdata->{surname} = $user->family_name();
    # Use the first address in the array that is valid and not
    # pending, since no one said whether or not to use billing or
    # mailing address.
    my @addrs = grep {$_->valid() && !$_->pending()} @{$user->addresses()};
    if (@addrs) {
        $userdata->{city} = $addrs[0]->city();
        $userdata->{country} = $addrs[0]->country();
        $userdata->{zipcode} = $addrs[0]->post_code();
        $userdata->{state} = $addrs[0]->state();
        $userdata->{address} = $addrs[0]->street1();
        $userdata->{address2} = $addrs[0]->street2();
    }

    # Check for barred patron.
    if ($user->barred()) {
        $userdata->{blocked} = "Patron account barred.";
    }

    # Check if the patron's profile is blocked from ILL.
    if (!$userdata->{blocked} &&
            grep {$_->id() == $user->profile()} @{$self->{block_profiles}}) {
        $userdata->{blocked} = "Patron group blocked from ILL.";
    }

    # Check for penalties that block CIRC, HOLD, or RENEW.
    unless ($userdata->{blocked}) {
        foreach my $penalty (@{$user->standing_penalties()}) {
            if ($penalty->standing_penalty->block_list()) {
                my @blocks = split /\|/,
                    $penalty->standing_penalty->block_list();
                if (grep /(?:CIRC|HOLD|RENEW)/, @blocks) {
                    $userdata->{blocked} = $penalty->standing_penalty->label();
                    last;
                }
            }
        }
    }

    return ($userdata, $userdata->{blocked});
}

sub checkin {}

sub checkout {}

sub renew {}

sub request {}

sub cancelrequest {}

sub acceptitem {}

# Implementation functions that might be useful to a subclass.

# Get a CStoreEditor:
sub editor {
    my $self = shift;

    # If we have an editor, check the validity of the auth session, then
    # invalidate the editor if the session is not valid.
    if ($self->{editor}) {
        undef($self->{editor}) unless ($self->checkauth());
    }

    # If we don't have an editor, make a new one.
    unless (defined($self->{editor})) {
        $self->login() unless ($self->checkauth());
        $self->{editor} = new_editor(authtoken=>$self->{session}->{authtoken});
    }

    return $self->{editor};
}

# Login via OpenSRF to Evergreen.
sub login {
    my $self = shift;

    # Get the authentication seed.
    my $seed = $U->simplereq(
        'open-ils.auth',
        'open-ils.auth.authenticate.init',
        $self->{config}->{username}
    );

    # Actually login.
    if ($seed) {
        my $response = $U->simplereq(
            'open-ils.auth',
            'open-ils.auth.authenticate.complete',
            {
                username => $self->{config}->{username},
                password => md5_hex(
                    $seed . md5_hex($self->{config}->{password})
                ),
                type => 'staff',
                workstation => $self->{config}->{workstation}
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

    # We implement our own version of this function, rather than rely
    # on CStoreEditor, because we may want to check this at times that
    # we don't have a CStoreEditor.

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

# Bootstrap OpenSRF::System, load the IDL, and initialize the
# CStoreEditor module.
sub _bootstrap {
    my $self = shift;

    my $bootstrap_config = $self->{config}->{bootstrap};
    OpenSRF::System->bootstrap_client(config_file => $bootstrap_config);

    my $idl = OpenSRF::Utils::SettingsClient->new->config_value("IDL");
    Fieldmapper->import(IDL => $idl);

    OpenILS::Utils::CStoreEditor->init;
}

# Login and then initialize some object data based on the
# configuration.
sub _init {
    my $self = shift;

    # Login to Evergreen.
    $self->login();

    # Create an editor.
    my $e = $self->editor();

    # Retrieve the work_ou as an object.
    my $work_ou = $e->search_actor_org_unit(
        {shortname => $self->{config}->{credentials}->{work_ou}}
    );
    $self->{work_ou} = $work_ou->[0] if ($work_ou && @$work_ou);

    # Load the barred groups as pgt objects into a blocked_profiles
    # list.
    $self->{blocked_profiles} = [];
    foreach (@{$self->{config}->{patrons}->{block_profile}}) {
        if (ref $_) {
            my $pgt = $e->retrieve_permission_grp_tree($_->{grp});
            push(@{$blocked_profiles}, $pgt) if ($pgt);
        } else {
            my $result = $e->search_permission_grp_tree({name => $_});
            if ($result && @$result) {
                map {push(@{$self->{blocked_profiles}}, $_)} @$result;
            }
        }
    }

    # Load the bib source if we're not using precats.
    unless ($self->{config}->{items}->{use_precats}) {
        # Retrieve the default
        my $cbs = $e->retrieve_config_bib_source(BIB_SOURCE_DEFAULT);
        my $data = $self->{config}->{items}->{bib_source};
        if ($data) {
            $data = $data->[0] if (ref($data) eq 'ARRAY');
            if (ref $data) {
                my $result = $e->retrieve_config_bib_source($data->{cbs});
                $cbs = $result if ($result);
            } else {
                my $result = $e->search_config_bib_source({source => $data-});
                if ($result && @$result) {
                    $cbs = $result->[0]; # Use the first one.
                }
            }
        }
        $self->{bib_source} = $cbs;
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
        my $result = $e->search_asset_stat_cat_entry(
            {
                stat_cat => $_->{stat_cat},
                value => $_->{content},
                owner => $ancestors
            }
        );
        if ($result && @$result) {
            map {push(@{$self->{stat_cat_entries}}, $_)} @$result;
        }
    }
}

# Standalone, "helper" functions.  These do not take an object or
# class reference.

# Strip leading and trailing whitespace (incl. newlines) from a string
# value.
sub _strip {
    my $string = shift;
    if ($string) {
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
    }
    return $string;
}

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
