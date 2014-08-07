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
package NCIP::Header;
use parent qw(Class::Accessor);

# This is a NCIP ResponseHeader object.  We do not implement an
# initator, so we do not implement the InitiationHeader and we do not
# attempt to make this object generic enough to handle that field.
# The fields are as defined in Z39.83-1-2012.  Ext is provided but is
# not used by the current iteration of NCIPServer.

NCIP::Problem->mk_accessors(qw(FromSystemId FromSystemAuthentication
                               FromAgencyId FromAgencyAuthentication
                               ToSystemId ToAgencyId Ext));

1;
