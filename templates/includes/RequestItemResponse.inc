<RequestId>
[% IF data.RequestId.AgencyId -%]
<AgencyId>[% data.RequestId.AgencyId | xml %]</AgencyId>
[% END -%]
[% IF data.RequestId.RequestIdentifierType -%]
<RequestIdentifierType>[% data.RequestId.RequestIdentifierType | xml %]</RequestIdentifierType>
[% END %]
<RequestIdentifierValue>[% data.RequestId.RequestIdentifierValue | xml %]</RequestIdentifierValue>
</RequestId>
<UserId>
[% IF data.UserId.AgencyId -%]
<AgencyId>[% data.UserId.AgencyId | xml %]</AgencyId>
[% END -%]
[% IF data.UserId.UserIdentifierType -%]
<UserIdentifierType>[% data.UserId.UserIdentifierType | xml %]</UserIdentiferiType>
<UserIdentifierValue>[% data.UserId.UserIdentifierValue | xml %]</UserIdentifierValue>
[% END -%]
</UserId>
<RequestType>[% data.RequestType | xml %]</RequestType>
<RequestScopeType>[% data.RequestScopeType | xml %]</RequestScopeType>
[% INCLUDE "includes/ItemOptionalFields.inc" -%]
[% INCLUDE "includes/UserOptionalFields.inc" -%]
