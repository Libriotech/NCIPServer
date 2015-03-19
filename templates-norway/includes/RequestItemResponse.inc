<ns1:RequestId>
  <ns1:AgencyId>FIXME[% requestagency | xml %]</ns1:AgencyId>
  <ns1:RequestIdentifierValue>[% messages.request_id | xml %]</ns1:RequestIdentifierValue>
</ns1:RequestId>
<!-- <ns1:RequestId>FIXME:[% messages.request_id | xml %]</ns1:RequestId> -->
<ns1:UserId>
    <ns1:AgencyId>FIXME</ns1:AgencyId>
    <ns1:UserIdentifierValue>[% userid | xml %]</ns1:UserIdentifierValue>
</ns1:UserId>
<ns1:RequestType>[% requesttype | xml %]</ns1:RequestType>
<ns1:RequestScopeType>0</ns1:RequestScopeType>
