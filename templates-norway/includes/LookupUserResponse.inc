
<ns1:UserId>
<ns1:UserIdentifierValue>[% user.userdata.cardnumber | xml %]</ns1:UserIdentifierValue>
</ns1:UserId>
[%# <ns1:UserFiscalAccount></ns1:UserFiscalAccount>
ns1:LoanedItemsCount
ns1:LoanedItem
ns1:RequestedItemsCount
ns1:RequestedItem
%]
<ns1:UserOptionalFields>
[% FOREACH element IN elements %]
  [% IF element.textContent == 'User Address Information' %]
     <ns1:UserAddressInformation>
      <ns1:UserAddressRoleType>Primary Address</ns1:UserAddressRoleType>
     <ns1:PhysicalAddress>
       <ns1:StructuredAddress>
       <ns1:Line1>[% user.userdata.streetnumber | xml %] [% user.userdata.address | xml %]</ns1:Line1>
       [% IF user.userdata.address2 %]
       <ns1:Line2>[% user.userdata.address2 | xml %]</ns1:Line2>
       [% END %]
       [% IF user.userdata.city %]
       <ns1:Locality>[% user.userdata.city | xml %]</ns1:Locality>
       [% END %]
       [% IF user.userdata.state %]
       <ns1:Region>[% user.userdata.state | xml %]</ns1:Region>
       [% END %]
       [% IF user.userdata.zipcode %]
       <ns1:PostalCode>[% user.userdata.zipcode | xml %]</ns1:PostalCode>
       [% END %]
       [% IF user.userdata.country %]
       <ns1:Country>[% user.userdata.country | xml %]</ns1:Country>
       [% END %]
       </ns1:StructuredAddress>
     </ns1:PhysicalAddress>
     </ns1:UserAddressInformation>
  [% END %]
  [% IF element.textContent == 'Name Information' %]
    <ns1:NameInformation>
      <ns1:PersonalNameInformation>
        <ns1:StructuredPersonalUserName>
          <ns1:GivenName>[% user.userdata.firstname | xml %]</ns1:GivenName>
          <ns1:Surname>[% user.userdata.surname | xml %]</ns1:Surname>
        </ns1:StructuredPersonalUserName>
      </ns1:PersonalNameInformation>
    </ns1:NameInformation>
  [% END %]
[% END %]
</ns1:UserOptionalFields>
