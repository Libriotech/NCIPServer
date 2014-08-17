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
package NCIP::User::Privilege;

use parent qw(Class::Accessor);

=head1 NAME

Privilege -

=head1 SYNOPSIS



=head1 DESCRIPTION

=head1 FIELDS

=head2 AgencyId

=head2 AgencyUserPrivilegeType

=head2 ValidFromDate

=head2 ValidToDate

=head2 UserPrivilegeStatus

=head2 UserPrivilegeDescription

=cut

NCIP::User::Privilege->mk_accessors(
    qw(
          AgencyId
          AgencyUserPrivilegeType
          ValidFromDate
          ValidToDate
          UserPrivilegeStatus
          UserPrivilegeDescription
      )
);

1;
