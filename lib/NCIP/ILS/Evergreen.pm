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

sub itemdata {}

sub userdata {}

sub checkin {}

sub checkout {}

sub renew {}

sub request {}

sub cancelrequest {}

sub acceptitem {}

1;
