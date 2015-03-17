<ns1:RequestId>
  <ns1:AgencyId>[% requestagency | xml %]</ns1:AgencyId>
  <ns1:RequestIdentifierValue>[% requestid | xml %]</ns1:RequestIdentifierValue>
</ns1:RequestId>
<ns1:ItemId>
  <ns1:ItemIdentifierType>Item Barcode</ns1:ItemIdentifierType>
  <ns1:ItemIdentifierValue>[% newbarcode | xml%]</ns1:ItemIdentifierValue>
</ns1:ItemId>
