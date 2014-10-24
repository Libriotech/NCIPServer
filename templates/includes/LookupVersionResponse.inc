<FromAgencyId>
<AgencyId>
[%- data.fromagencyid -%]
</AgencyId>
</FromAgencyId>
<ToAgencyId>
<AgencyId>
[%- data.toagencyid -%]
</AgencyId>
</ToAgencyId>
[% FOREACH version IN data.versions -%]
<VersionSupported>
[%- version | xml -%]
</VersionSupported>
[% END -%]
