<ncip:RequestId>
[% IF data.RequestId.AgencyId -%]
<ncip:AgencyId>[% data.RequestId.AgencyId | xml %]</ncip:AgencyId>
[% END -%]
[% IF data.RequestId.RequestIdentifierType -%]
<ncip:RequestIdentifierType>[% data.RequestId.RequestIdentifierType | xml %]</ncip:RequestIdentifierType>
[% END -%]
<ncip:RequestIdentifierValue>[% data.RequestId.RequestIdentifierValue | xml %]</ncip:RequestIdentifierValue>
</ncip:RequestId>
[% IF data.ItemId -%]
<ncip:ItemId>
[% IF data.ItemId.AgencyId -%]
<ncip:AgencyId>[% data.ItemId.AgencyId | xml %]</ncip:AgencyId>
[% END -%]
[% IF data.ItemId.ItemIdentifierType -%]
<ncip:ItemIdentifierType>[% data.ItemId.ItemIdentifierType | xml %]</ncip:ItemIdentifierType>
[% END -%]
<ncip:ItemIdentifierValue>[% data.ItemId.ItemIdentifierValue | xml %]</ncip:ItemIdentifierValue>
</ncip:ItemId>
[% END -%]
[% INCLUDE "includes/UserOptionalFields.inc" -%]
