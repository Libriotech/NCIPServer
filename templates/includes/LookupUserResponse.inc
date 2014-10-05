[% FOREACH id IN data.UserId -%]
<UserId>
<UserIdentifierValue>
[% id.UserIdentifierValue | xml %]
</UserIdentifierValue>
[% IF id.UserIdentifierType -%]
<UserIdentifierType>
[% id.UserIdentifierType | xml %]
</UserIdentifierType>
[% END -%]
[% IF id.AgencyId -%]
<AgencyId>
[% id.AgencyId %]
</AgencyId>
[% END -%]
</UserId>
[% END -%]
[% INCLUDE "includes/UserOptionalFields.inc" -%]
