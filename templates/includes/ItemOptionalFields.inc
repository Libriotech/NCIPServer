[% IF data.ItemOptionalFields -%]
<ncip:ItemOptionalFields>
[% IF data.ItemOptionalFields.BibliographicDescription -%]
<ncip:BibliographicDescription>
[% IF data.ItemOptionalFields.BibliographicDescription.Author -%]
<ncip:Author>
[% data.ItemOptionalFields.BibliographicDescription.Author | xml %]
</ncip:Author>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.Title -%]
<ncip:Title>
[% data.ItemOptionalFields.BibliographicDescription.Title | xml %]
</ncip:Title>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.Publisher -%]
<ncip:Publisher>
[% data.ItemOptionalFields.BibliographicDescription.Publisher | xml %]
</ncip:Publisher>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.PublicationDate -%]
<ncip:PublicationDate>
[% data.ItemOptionalFields.BibliographicDescription.PublicationDate | xml %]
</ncip:PublicationDate>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.Edition -%]
<ncip:Edition>
[% data.ItemOptionalFields.BibliographicDescription.Edition | xml %]
</ncip:Edition>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.BibliographicRecordId;
      id = data.ItemOptionalFields.BibliographicDescription.BibliographicRecordId -%]
<ncip:BibliographicRecordId>
<ncip:BibliographicRecordIdentifier>
[% id.BibliographicRecordIdentifier | xml %]
</ncip:BibliographicRecordIdentifer>
[% IF id.BibliographicRecordIdentifierCode -%]
<ncip:BibliographicRecordIdentifierCode>
[% id.BibliographicRecordIdentifierCode | xml %]
</ncip:BibliographicRecordIdentifierCode>
[% END -%]
[% IF id.AgencyId -%]
<ncip:AgencyId>
[% id.AgencyId | xml %]
</ncip:AgencyId>
[% END -%]
</ncip:BibliographicRecordId>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.BibliographicItemId;
      id = data.ItemOptionalFields.BibliographicDescription.BibliographicItemId -%]
<ncip:BibliographicItemId>
<ncip:BibliographicItemIdentifier>
[% id.BibliographicItemIdentifier | xml %]
</ncip:BibliographicItemIdentifier>
[% IF id.BibliographicItemIdentifierCode -%]
<ncip:BibliographicItemIdentifierCode>
[% id.BibliographicItemIdentifierCode | xml %]
</ncip:BibliographicItemIdentifierCode>
[% END -%]
</ncip:BibliographicItemId>
[% END -%]
</ncip:BibliographicDescription>
[% END -%]
[% IF data.ItemOptionalFields.ItemDescription -%]
<ncip:ItemDescription>
<ncip:CallNumber>
[% data.ItemOptionalFields.ItemDescription.CallNumber | xml %]
</ncip:CallNumber>
</ncip:ItemDescription>
[% END -%]
[% IF data.ItemOptionalFields.CirculationStatus -%]
<ncip:CirculationStatus>
[% data.ItemOptionalFields.CirculationStatus | xml %]
</ncip:CirculationStatus>
[% END -%]
[% IF data.ItemOptionalFields.DateDue -%]
<ncip:DateDue>
[% data.ItemOptionalFields.DateDue | xml %]
</ncip:DateDue>
[% END -%]
[% IF data.ItemOptionalFields.ItemUseRestrictionType -%]
<ncip:ItemUseRestrictionType>
[% data.ItemOptionalFields.ItemUseRestrictionType | xml %]
</ncip:ItemUseRestrictionType>
[% END -%]
[% IF data.ItemOptionalFields.PhysicalCondition -%]
<ncip:PhysicalCondition>
[% data.ItemOptionalFields.PhysicalCondition | xml %]
</ncip:PhysicalCondition>
[% END -%]
</ncip:ItemOptionalFields>
[% END -%]
