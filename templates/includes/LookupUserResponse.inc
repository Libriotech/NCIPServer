[% FOREACH id IN data.UserId -%]
<ncip:UserId>
[% IF id.UserIdentifierType -%]
<ncip:UserIdentifierType>
[% id.UserIdentifierType | xml %]
</ncip:UserIdentifierType>
[% END -%]
[% IF id.AgencyId -%]
<ncip:AgencyId>
[% id.AgencyId %]
</ncip:AgencyId>
[% END -%]
<ncip:UserIdentifierValue>
[% id.UserIdentifierValue | xml %]
</ncip:UserIdentifierValue>
</ncip:UserId>
[% END -%]
[% INCLUDE "includes/UserOptionalFields.inc" -%]
