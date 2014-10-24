<ncip:FromAgencyId>
<ncip:AgencyId>
[%- data.fromagencyid -%]
</ncip:AgencyId>
</ncip:FromAgencyId>
<ncip:ToAgencyId>
<ncip:AgencyId>
[%- data.toagencyid -%]
</ncip:AgencyId>
</ncip:ToAgencyId>
[% FOREACH version IN data.versions -%]
<ncip:VersionSupported>
[%- version | xml -%]
</ncip:VersionSupported>
[% END -%]
