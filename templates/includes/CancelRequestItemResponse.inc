<ncip:RequestId>
[% IF data.RequestId.AgencyId -%]
<ncip:AgencyId>[% data.RequestId.AgencyId | xml %]</ncip:AgencyId>
[% END -%]
<ncip:RequestIdentifierValue>[% data.RequestId.RequestIdentifierValue | xml %]</ncip:RequestIdentifierValue>
[% IF data.RequestId.RequestIdentifierType -%]
<ncip:RequestIdentifierType>[% data.RequestId.RequestIdentifierType | xml %]</ncip:RequestIdentifierType>
[% END %]
</ncip:RequestId>
<ncip:UserId>
[% IF data.UserId.AgencyId -%]
<ncip:AgencyId>[% data.UserId.AgencyId | xml %]</ncip:AgencyId>
[% END -%]
<ncip:UserIdentifierValue>[% data.UserId.UserIdentifierValue | xml %]</ncip:UserIdentifierValue>
[% IF data.UserId.UserIdentifierType -%]
<ncip:UserIdentifierType>[% data.UserId.UserIdentifierType | xml %]</ncip:UserIdentiferiType>
[% END -%]
</ncip:UserId>
[% INCLUDE "includes/UserOptionalFields.inc" -%]
[% INCLUDE "includes/ItemOptionalFields.inc" -%]
