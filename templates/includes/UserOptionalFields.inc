[% IF data.UserOptionalFields -%]
<UserOptionalFields>
[% IF data.UserOptionalFields.NameInformation -%]
<NameInformation>
<PersonalNameInformation>
<StructuredPersonalUserName>
[% IF data.UserOptionalFields.NameInformation.GivenName -%]
<GivenName>[% data.UserOptionalFields.NameInformation.GivenName | xml %]</GivenName>
[% END -%]
<Surname>[% data.UserOptionalFields.NameInformation.Surname | xml %]</Surname>
[% IF data.UserOptionalFields.NameInformation.Prefix -%]
<Prefix>[% data.UserOptionalFields.NameInformation.Prefix %]</Prefix>
[% END -%]
[% IF data.UserOptionalFields.NameInformation.Suffix -%]
<Suffix>[% data.UserOptionalFields.NameInformation.Suffix %]</Suffix>
[% END -%]
[% IF data.UserOptionalFields.NameInformation.Initials -%]
<Initials>[% data.UserOptionalFields.NameInformation.Initials %]</Initials>
[% END -%]
</StructuredPersonalUserName>
</PersonalNameInformation>
</NameInformation>
[% END -%]
[% IF data.UserOptionalFields.UserAddressInformation -%]
[% FOREACH element IN data.UserOptionalFields.UserAddressInformation -%]
<UserAddressInformation>
<UserAddressRoleType>[% element.UserAddressRoleType | xml %]</UserAddressRoleType>
[% IF element.PhysicalAddress -%]
<PhysicalAddress>
<StructuredAddress>
<Line1>[% element.PhysicalAddress.Line1 | xml %]</Line1>
[% IF element.PhysicalAddress.Line2 -%]
<Line2>[% element.PhysicalAddress.Line2 | xml %]</Line2>
[% END -%]
[% IF element.PhysicalAddress.Locality -%]
<Locality>[% element.PhysicalAddress.Locality | xml %]</Locality>
[% END -%]
[% IF element.PhysicalAddress.Region -%]
<Region>[% element.PhysicalAddress.Region | xml %]</Region>
[% END -%]
[% IF element.PhysicalAddress.PostalCode -%]
<PostalCode>[% element.PhysicalAddress.PostalCode | xml %]</PostalCode>
[% END -%]
[% IF element.PhysicalAddress.Country -%]
<Country>[% element.PhysicalAddress.Country | xml %]</Country>
[% END -%]
</StructuredAddress>
</PhysicalAddress>
[% ELSIF element.ElectronicAddress -%]
<ElectronicAddress>
<ElectronicAddressType>[% element.ElectronicAddress.Type | xml %]</ElectronicAddressType>
<ElectronicAddressData>[% element.ElectronicAddress.Data | xml %]</ElectronicAddressData>
</ElectronicAddress>
[% END -%]
</UserAddressInformation>
[% END -%]
[% END -%]
[% IF data.UserOptionalFields.UserPrivilege -%]
[% FOREACH privilege IN data.UserOptionalFields.UserPrivilege -%]
<UserPrivilege>
<AgencyId>[% privilege.AgencyId | xml -%]</AgencyId>
<AgencyUserPrivilegeType>[% privilege.AgencyUserPrivilegeType | xml %]</AgencyUserPrivilegeType>
[% IF privilege.ValidFromDate -%]
<ValidFromDate>[% privilege.ValidFromDate | xml %]</ValidFromDate>
[% END -%]
[% IF privilege.ValidToDate -%]
<ValidToDate>[% privilege.ValidToDate | xml %]</ValidToDate>
[% END -%]
[% IF privilege.UserPrivilegeDescription -%]
<UserPrivilegeDescription>[% privilege.UserPrivilegeDescription | xml %]</UserPrivilegeDescription>
[% END -%]
[% IF privilege.UserPrivilegeStatus -%]
<UserPrivilegeStatus>
<UserPrivilegeStatusType>
[% privilege.UserPrivilegeStatus.UserPrivilegeStatusType | xml %]
</UserPrivilegeStatusType>
[% IF privilege.UserPrivilegeStatus.DateOfUserPrivilegeStatus -%]
<DateOfUserPrivilegeStatus>
[% privilege.UserPrivilegeStatus.DateOfUserPrivilegeStatus | xml %]
</DateOfUserPrivilegeStatus>
[% END -%]
</UserPrivilegeStatus>
[% END -%]
</UserPrivilege>
[% END -%]
[% END -%]
[% IF data.UserOptionalFields.UserLanguage -%]
[% FOREACH language IN data.UserOptionalFields.UserLanguage -%]
<UserLanguage>[% language | xml %]</UserLanguage>
[% END -%]
[% END -%]
[% IF data.UserOptionalFields.BlockOrTrap -%]
[% FOREACH block IN data.UserOptionalFields.BlockOrTrap -%]
<BlockOrTrap>
<AgencyId>[% block.AgencyId | xml %]</AgencyId>
<BlockOrTrapType>[% block.BlockOrTrapType | xml %]</BlockOrTrapType>
[% IF block.ValidFromDate -%]
<ValidFromDate>[% block.ValidFromDate %]</ValidFromDate>
[% END -%]
[% IF block.ValidToDate -%]
<ValidToDate>[% block.ValidToDate %]</ValidToDate>
[% END %]
</BlockOrTrap>
[% END -%]
[% END -%]
</UserOptionalFields>
[% END -%]