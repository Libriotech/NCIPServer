[% FOREACH id IN data.UserId -%]
<ncip:UserId>
<ncip:UserIdentifierValue>
[% id.UserIdentifierValue | xml %]
</ncip:UserIdentifierValue>
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
</ncip:UserId>
[% END -%]
[% INCLUDE "includes/UserOptionalFields.inc" -%]
