<FromAgencyId>
[%- fromagencyid -%]
</FromAgencyId>
<ToAgencyId>
[%- toagencyid -%]
</ToAgencyId>
[% FOREACH version IN data.versions -%]
<VersionSupported>
[%- version | xml -%]
</VersionSupported>
[% END -%]
