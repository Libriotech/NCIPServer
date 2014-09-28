<RequestId>
[% IF data.RequestId.AgencyId -%]
<AgencyId>[% data.RequestId.AgencyId | xml %]</AgencyId>
[% END -%]
<RequestIdentifierValue>[% data.RequestId.RequestIdentifierValue | xml %]</RequestIdentifierValue>
[% IF data.RequestId.RequestIdentifierType -%]
<RequestIdentifierType>[% data.RequestId.RequestIdentifierType | xml %]</RequestIdentifierType>
[% END %]
</RequestId>
<UserId>
[% IF data.UserId.AgencyId -%]
<AgencyId>[% data.UserId.AgencyId | xml %]</AgencyId>
[% END -%]
<UserIdentifierValue>[% data.UserId.UserIdentifierValue | xml %]</UserIdentifierValue>
[% IF data.UserId.UserIdentifierType -%]
<UserIdentifierType>[% data.UserId.UserIdentifierType | xml %]</UserIdentiferiType>
[% END -%]
</UserId>
