<FromAgencyId>
[%- data.fromagencyid -%]
</FromAgencyId>
<ToAgencyId>
[%- data.toagencyid -%]
</ToAgencyId>
[% FOREACH version IN data.versions -%]
<VersionSupported>
[%- version | xml -%]
</VersionSupported>
[% END -%]
