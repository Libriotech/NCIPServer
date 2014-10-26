[% FOREACH id IN data.UserId -%]
<UserId>
[% IF id.UserIdentifierType -%]
<UserIdentifierType>[% id.UserIdentifierType | xml %]</UserIdentifierType>
[% END -%]
[% IF id.AgencyId -%]
<AgencyId>[% id.AgencyId %]</AgencyId>
[% END -%]
<UserIdentifierValue>[% id.UserIdentifierValue | xml %]</UserIdentifierValue>
</UserId>
[% END -%]
[% INCLUDE "includes/UserOptionalFields.inc" -%]
