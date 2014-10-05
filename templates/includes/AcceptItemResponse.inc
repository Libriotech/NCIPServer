<RequestId>
[% IF data.RequestId.AgencyId -%]
<AgencyId>[% data.RequestId.AgencyId | xml %]</AgencyId>
[% END -%]
[% IF data.RequestId.RequestIdentifierType -%]
<RequestIdentifierType>[% data.RequestId.RequestIdentifierType | xml %]</RequestIdentifierType>
[% END -%]
<RequestIdentifierValue>[% data.RequestId.RequestIdentifierValue | xml %]</RequestIdentifierValue>
</RequestId>
[% IF data.ItemId -%]
<ItemId>
[% IF data.ItemId.AgencyId -%]
<AgencyId>[% data.ItemId.AgencyId | xml %]</AgencyId>
[% END -%]
[% IF data.ItemId.ItemIdentifierType -%]
<ItemIdentifierType>[% data.ItemId.ItemIdentifierType | xml %]</ItemIdentifierType>
[% END -%]
<ItemIdentifierValue>[% data.ItemId.ItemIdentifierValue | xml %]</ItemIdentifierValue>
</ItemId>
[% END -%]
[% INCLUDE "includes/UserOptionalFields.inc" -%]
