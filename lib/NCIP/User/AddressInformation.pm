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
package NCIP::User::AddressInformation;

use parent qw(Class::Accessor);

=head1 NAME

AddressInformation - A user's Address Information

=head1 SYNOPSIS



=head1 DESCRIPTION

=head1 FIELDS

=head2 UserAddressRoleType

A text string to indicate the role of the address.

=head2 PhysicalAddress

A physical address stored in a StructuredAddress.

=cut

NCIP::User::AddressInformation->mk_accessors(
    qw(UserAddressRoleType PhysicalAddress)
);

1;
