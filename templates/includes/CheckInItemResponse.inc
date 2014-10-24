<ncip:ItemId>
[% IF data.ItemId.AgencyId -%]
<ncip:AgencyId>[% data.ItemId.AgencyId | xml %]</ncip:AgencyId>
[% END -%]
[% IF data.ItemId.ItemIdentifierType -%]
<ncip:ItemIdentifierType>[% data.ItemId.ItemIdentifierType | xml %]</ncip:ItemIdentifierType>
[% END -%]
<ncip:ItemIdentifierValue>[% data.ItemId.ItemIdentifierValue | xml %]</ncip:ItemIdentifierValue>
</ncip:ItemId>
[% IF data.UserId -%]
<ncip:UserId>
[% IF data.UserId.AgencyId -%]
<ncip:AgencyId>[% data.UserId.AgencyId | xml %]</ncip:AgencyId>
[% END -%]
[% IF data.UserId.UserIdentifierType -%]
<ncip:UserIdentifierType>[% data.UserId.UserIdentifierType | xml %]</ncip:UserIdentifierType>
[% END -%]
<ncip:UserIdentifierValue>[% data.UserId.UserIdentifierValue | xml %]</ncip:UserIdentifierValue>
</ncip:UserId>
[% END -%]
[% INCLUDE "includes/UserOptionalFields.inc" -%]
[% INCLUDE "includes/ItemOptionalFields.inc" -%]
