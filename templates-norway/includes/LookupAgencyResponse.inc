<ns1:ResponseHeader>
    <ns1:FromAgencyId>
        <ns1:AgencyId>[% data.fromagencyid | xml %]</ns1:AgencyId>
    </ns1:FromAgencyId>
    <ns1:ToAgencyId>
        <ns1:AgencyId>[% data.toagencyid | xml %]</ns1:AgencyId>
    </ns1:ToAgencyId>
</ns1:ResponseHeader>
<ns1:AgencyId>FIXME</ns1:AgencyId>
[% IF data.applicationprofilesupportedtype -%]
<ns1:ApplicationProfileSupportedType>[% data.applicationprofilesupportedtype | xml %]</ns1:ApplicationProfileSupportedType>
[% END -%]
