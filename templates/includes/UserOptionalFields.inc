[% IF data.UserOptionalFields -%]
<ncip:UserOptionalFields>
[% IF data.UserOptionalFields.NameInformation -%]
<ncip:NameInformation>
<ncip:PersonalNameInformation>
<ncip:StructuredPersonalUserName>
[% IF data.UserOptionalFields.NameInformation.GivenName -%]
<ncip:GivenName>[% data.UserOptionalFields.NameInformation.GivenName | xml %]</ncip:GivenName>
[% END -%]
<ncip:Surname>[% data.UserOptionalFields.NameInformation.Surname | xml %]</ncip:Surname>
[% IF data.UserOptionalFields.NameInformation.Prefix -%]
<ncip:Prefix>[% data.UserOptionalFields.NameInformation.Prefix %]</ncip:Prefix>
[% END -%]
[% IF data.UserOptionalFields.NameInformation.Suffix -%]
<ncip:Suffix>[% data.UserOptionalFields.NameInformation.Suffix %]</ncip:Suffix>
[% END -%]
[% IF data.UserOptionalFields.NameInformation.Initials -%]
<ncip:Initials>[% data.UserOptionalFields.NameInformation.Initials %]</ncip:Initials>
[% END -%]
</ncip:StructuredPersonalUserName>
</ncip:PersonalNameInformation>
</ncip:NameInformation>
[% END -%]
[% IF data.UserOptionalFields.UserAddressInformation -%]
[% FOREACH element IN data.UserOptionalFields.UserAddressInformation -%]
<ncip:UserAddressInformation>
<ncip:UserAddressRoleType>[% element.UserAddressRoleType | xml %]</ncip:UserAddressRoleType>
[% IF element.PhysicalAddress -%]
<ncip:PhysicalAddress>
<ncip:StructuredAddress>
<ncip:Line1>[% element.PhysicalAddress.Line1 | xml %]</ncip:Line1>
[% IF element.PhysicalAddress.Line2 -%]
<ncip:Line2>[% element.PhysicalAddress.Line2 | xml %]</ncip:Line2>
[% END -%]
[% IF element.PhysicalAddress.Locality -%]
<ncip:Locality>[% element.PhysicalAddress.Locality | xml %]</ncip:Locality>
[% END -%]
[% IF element.PhysicalAddress.Region -%]
<ncip:Region>[% element.PhysicalAddress.Region | xml %]</ncip:Region>
[% END -%]
[% IF element.PhysicalAddress.Country -%]
<ncip:Country>[% element.PhysicalAddress.Country | xml %]</ncip:Country>
[% END -%]
[% IF element.PhysicalAddress.PostalCode -%]
<ncip:PostalCode>[% element.PhysicalAddress.PostalCode | xml %]</ncip:PostalCode>
[% END -%]
</ncip:StructuredAddress>
<ncip:PhysicalAddressType>Postal Address</ncip:PhysicalAddressType>
</ncip:PhysicalAddress>
[% ELSIF element.ElectronicAddress -%]
<ncip:ElectronicAddress>
<ncip:ElectronicAddressType>[% element.ElectronicAddress.Type | xml %]</ncip:ElectronicAddressType>
<ncip:ElectronicAddressData>[% element.ElectronicAddress.Data | xml %]</ncip:ElectronicAddressData>
</ncip:ElectronicAddress>
[% END -%]
</ncip:UserAddressInformation>
[% END -%]
[% END -%]
[% IF data.UserOptionalFields.UserPrivilege -%]
[% FOREACH privilege IN data.UserOptionalFields.UserPrivilege -%]
<ncip:UserPrivilege>
<ncip:AgencyId>[% privilege.AgencyId | xml -%]</ncip:AgencyId>
<ncip:AgencyUserPrivilegeType>[% privilege.AgencyUserPrivilegeType | xml %]</ncip:AgencyUserPrivilegeType>
[% IF privilege.ValidFromDate -%]
<ncip:ValidFromDate>[% privilege.ValidFromDate | xml %]</ncip:ValidFromDate>
[% END -%]
[% IF privilege.ValidToDate -%]
<ncip:ValidToDate>[% privilege.ValidToDate | xml %]</ncip:ValidToDate>
[% END -%]
[% IF privilege.UserPrivilegeDescription -%]
<ncip:UserPrivilegeDescription>[% privilege.UserPrivilegeDescription | xml %]</ncip:UserPrivilegeDescription>
[% END -%]
[% IF privilege.UserPrivilegeStatus -%]
<ncip:UserPrivilegeStatus>
<ncip:UserPrivilegeStatusType>
[% privilege.UserPrivilegeStatus.UserPrivilegeStatusType | xml %]
</ncip:UserPrivilegeStatusType>
[% IF privilege.UserPrivilegeStatus.DateOfUserPrivilegeStatus -%]
<ncip:DateOfUserPrivilegeStatus>
[% privilege.UserPrivilegeStatus.DateOfUserPrivilegeStatus | xml %]
</ncip:DateOfUserPrivilegeStatus>
[% END -%]
</ncip:UserPrivilegeStatus>
[% END -%]
</ncip:UserPrivilege>
[% END -%]
[% END -%]
[% IF data.UserOptionalFields.UserLanguage -%]
[% FOREACH language IN data.UserOptionalFields.UserLanguage -%]
<ncip:UserLanguage>[% language | xml %]</ncip:UserLanguage>
[% END -%]
[% END -%]
[% IF data.UserOptionalFields.BlockOrTrap -%]
[% FOREACH block IN data.UserOptionalFields.BlockOrTrap -%]
<ncip:BlockOrTrap>
<ncip:AgencyId>[% block.AgencyId | xml %]</ncip:AgencyId>
<ncip:BlockOrTrapType>[% block.BlockOrTrapType | xml %]</ncip:BlockOrTrapType>
[% IF block.ValidFromDate -%]
<ncip:ValidFromDate>[% block.ValidFromDate %]</ncip:ValidFromDate>
[% END -%]
[% IF block.ValidToDate -%]
<ncip:ValidToDate>[% block.ValidToDate %]</ncip:ValidToDate>
[% END %]
</ncip:BlockOrTrap>
[% END -%]
[% END -%]
</ncip:UserOptionalFields>
[% END -%]
