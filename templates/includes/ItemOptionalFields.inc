[% IF data.ItemOptionalFields -%]
<ItemOptionalFields>
[% IF data.ItemOptionalFields.BibliographicDescription -%]
<BibliographicDescription>
[% IF data.ItemOptionalFields.BibliographicDescription.Author -%]
<Author>
[% data.ItemOptionalFields.BibliographicDescription.Author | xml %]
</Author>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.Title -%]
<Title>
[% data.ItemOptionalFields.BibliographicDescription.Title | xml %]
</Title>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.Publisher -%]
<Publisher>
[% data.ItemOptionalFields.BibliographicDescription.Publisher | xml %]
</Publisher>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.PublicationDate -%]
<PublicationDate>
[% data.ItemOptionalFields.BibliographicDescription.PublicationDate | xml %]
</PublicationDate>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.Edition -%]
<Edition>
[% data.ItemOptionalFields.BibliographicDescription.Edition | xml %]
</Edition>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.BibliographicRecordId;
      id = data.ItemOptionalFields.BibliographicDescription.BibliographicRecordId -%]
<BibliographicRecordId>
<BibliographicRecordIdentifier>
[% id.BibliographicRecordIdentifier | xml %]
</BibliographicRecordIdentifer>
[% IF id.BibliographicRecordIdentifierCode -%]
<BibliographicRecordIdentifierCode>
[% id.BibliographicRecordIdentifierCode | xml %]
</BibliographicRecordIdentifierCode>
[% END -%]
[% IF id.AgencyId -%]
<AgencyId>
[% id.AgencyId | xml %]
</AgencyId>
[% END -%]
</BibliographicRecordId>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.BibliographicItemId;
      id = data.ItemOptionalFields.BibliographicDescription.BibliographicItemId -%]
<BibliographicItemId>
<BibliographicItemIdentifier>
[% id.BibliographicItemIdentifier | xml %]
</BibliographicItemIdentifier>
[% IF id.BibliographicItemIdentifierCode -%]
<BibliographicItemIdentifierCode>
[% id.BibliographicItemIdentifierCode | xml %]
</BibliographicItemIdentifierCode>
[% END -%]
</BibliographicItemId>
[% END -%]
</BibliographicDescription>
[% END -%]
[% IF data.ItemOptionalFields.ItemDescription -%]
<ItemDescription>
<CallNumber>
[% data.ItemOptionalFields.ItemDescription.CallNumber | xml %]
</CallNumber>
</ItemDescription>
[% END -%]
[% IF data.ItemOptionalFields.CirculationStatus -%]
<CirculationStatus>
[% data.ItemOptionalFields.CirculationStatus | xml %]
</CirculationStatus>
[% END -%]
[% IF data.ItemOptionalFields.DateDue -%]
<DateDue>
[% data.ItemOptionalFields.DateDue | xml %]
</DateDue>
[% END -%]
[% IF data.ItemOptionalFields.ItemUseRestrictionType -%]
<ItemUseRestrictionType>
[% data.ItemOptionalFields.ItemUseRestrictionType | xml %]
</ItemUseRestrictionType>
[% END -%]
[% IF data.ItemOptionalFields.PhysicalCondition -%]
<PhysicalCondition>
[% data.ItemOptionalFields.PhysicalCondition | xml %]
</PhysicalCondition>
[% END -%]
</ItemOptionalFields>
[% END -%]