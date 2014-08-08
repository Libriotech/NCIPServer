[% FOREACH version IN data.versions -%]
<VersionSupported>
[%- version | xml -%]
</VersionSupported>
[% END -%]
