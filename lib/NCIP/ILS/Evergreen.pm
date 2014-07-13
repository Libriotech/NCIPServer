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
use XML::XPath;
use OpenSRF::System;
use OpenSRF::Utils::SettingsClient;
use Digest::MD5 qw/md5_hex/;
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

sub userdata {}

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
    my $seed = $U->simple_req(
        'open-ils.auth',
        'open-ils.auth.authenticate.init',
        $self->{config}->{username}
    );

    # Actually login.
    if ($seed) {
        my $response = $U->simple_req(
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

    # Load our configuration with XML::XPath.
    my $xpath = XML::XPath->new(filename => $file);
    # Load configuration into $self:
    $self->{config}->{bootstrap} =
        _strip($xpath->findvalue("/ncip/bootstrap")->value());
    $self->{config}->{username} =
        _strip($xpath->findvalue("/ncip/credentials/username")->value());
    $self->{config}->{password} =
        _strip($xpath->findvalue("/ncip/credentials/password")->value());
    $self->{config}->{work_ou} =
        _strip($xpath->findvalue("/ncip/credentials/work_ou")->value());
    $self->{config}->{workstation} =
        _strip($xpath->findvalue("/ncip/credentials/workstation")->value());
    # Look for a list of patron profiles to treat as blocked.  This is
    # useful if you have a patron group or groups that are not
    # permitted to do ILL.
    $self->{config}->{barred_groups} = [];
    my $nodes = $xpath->findnodes('/ncip/patrons/block_profile');
    if ($nodes) {
        foreach my $node ($nodes->get_nodelist()) {
            my $data = {id => 0, name => ""};
            my $attr = $xpath->findvalue('@pgt', $node);
            if ($attr) {
                $data->{id} = $attr;
            }
            $data->{name} = _strip($node->string_value());
            push(@{$self->{config}->{barred_groups}}, $data)
                if ($data->{id} || $data->{name});
        }
    }
    # Check for the use_precats setting for acceptitem.  This should
    # only be set if you are using 2.7.0-alpha or later of Evergreen.
    $self->{config}->{use_precats} = 0;
    undef($nodes);
    $nodes = $xpath->find('/ncip/items/use_precats');
    $self->{config}->{use_precats} = 1 if ($nodes);
    # If we're not using precats, we will be making "short" bibs.  We
    # need to look up and see if a special bib source has been
    # configured for these.
    undef($nodes);
    $nodes = $xpath->findnodes('/ncip/items/bib_source');
    if ($nodes) {
        my $node = $nodes->get_node(1);
        my $attr = $xpath->findvalue('@cbs', $node);
        if ($attr) {
            $self->{config}->{cbs}->{id} = $attr;
        }
        $self->{config}->{cbs}->{name} = _strip($node->string_value());
    }
    # Look for any required asset.copy.stat_cat_entry entries.
    $self->{config}->{asces} = [];
    undef($nodes);
    $nodes = $xpath->findnodes('/ncip/items/stat_cat_entry');
    if ($nodes) {
        foreach my $node ($nodes->get_nodelist()) {
            my $data = {asc => 0, id => 0, name => ''};
            my $asc = $xpath->findvalue('@asc', $node);
            $data->{asc} = $asc if ($asc);
            my $asce = $xpath->findvalue('@asce', $node);
            $data->{id} = $asce if ($asce);
            $data->{name} = _strip($node->string_value());
            push(@{$self->{config}->{asces}}, $data)
                if ($data->{id} || ($data->{name} && $data->{asc}));
        }
    }
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

    # Load the barred groups as pgt objects into a blocked_profiles
    # list.
    $self->{blocked_profiles} = [];
    foreach (@{$self->{config}->{barred_groups}}) {
        if ($_->{id}) {
            my $pgt = $e->retrieve_permission_grp_tree($_->{id});
            push(@{$self->{blocked_profiles}}, $pgt) if ($pgt);
        } else {
            my $result = $e->search_permission_grp_tree(
                {name => $_->{name}}
            );
            if ($result && @$result) {
                map {push(@{$self->{blocked_profiles}}, $_)} @$result;
            }
        }
    }

    # Load the bib source if we're not using precats.
    unless ($self->{config}->{use_precats}) {
        # Retrieve the default
        my $cbs = $e->retrieve_config_bib_source(BIB_SOURCE_DEFAULT);
        my $data = $self->{config}->{cbs};
        if ($data) {
            if ($data->{id}) {
                my $result = $e->retrieve_config_bib_source($data->{id});
                $cbs = $result if ($result);
            } else {
                my $result = $e->search_config_bib_source(
                    {source => $data->{name}}
                );
                if ($result && @$result) {
                    $cbs = $result->[0]; # Use the first one.
                }
            }
        }
        $self->{bib_source} = $cbs;
    }

    # Load the required asset.stat_cat_entries:
    $self->{asces} = [];
    foreach (@{$self->{config}->{asces}}) {
        if ($_->{id}) {
            my $asce = $e->retrieve_asset_stat_cat_entry($_->{id});
            push(@{$self->{asces}}, $asce) if ($asce);
        } elsif ($_->{asc} && $_->{name}) {
            # We may actually want to retrieve the ancestor tree
            # beginning with $self->{config}->{work_ou} and limit the
            # next search where the owner is one of those org units.
            my $result = $e->search_asset_stat_cat_entry(
                {
                    stat_cat => $_->{asc},
                    value => $_->{name}
                }
            );
            if ($result && @$result) {
                map {push(@{$self->{asces}}, $_)} @$result;
            }
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

1;
