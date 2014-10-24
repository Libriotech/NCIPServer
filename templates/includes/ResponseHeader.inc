<ncip:ResponseHeader>
<ncip:FromAgencyId>
<ncip:AgencyId>
[% header.FromAgencyId.AgencyId | xml %]
</ncip:AgencyId>
</ncip:FromAgencyId>
<ncip:ToAgencyId>
<ncip:AgencyId>
[% header.ToAgencyId.AgencyId  | xml %]
</ncip:AgencyId>
</ncip:ToAgencyId>
</ncip:ResponseHeader>
