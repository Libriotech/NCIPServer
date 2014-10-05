<ItemId>
[% IF data.ItemId.AgencyId -%]
<AgencyId>[% data.ItemId.AgencyId | xml %]</AgencyId>
[% END -%]
[% IF data.ItemId.ItemIdentifierType -%]
<ItemIdentifierType>[% data.ItemId.ItemIdentifierType | xml %]</ItemIdentifierType>
[% END -%]
<ItemIdentifierValue>[% data.ItemId.ItemIdentifierValue | xml %]</ItemIdentifierValue>
</ItemId>
[% IF data.UserId -%]
<UserId>
[% IF data.UserId.AgencyId -%]
<AgencyId>[% data.UserId.AgencyId | xml %]</AgencyId>
[% END -%]
[% IF data.UserId.UserIdentifierType -%]
<UserIdentifierType>[% data.UserId.UserIdentifierType | xml %]</UserIdentifierType>
[% END -%]
<UserIdentifierValue>[% data.UserId.UserIdentifierValue | xml %]</UserIdentifierValue>
</UserId>
[% END -%]
[% INCLUDE "includes/UserOptionalFields.inc" -%]
