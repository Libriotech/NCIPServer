<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns1:NCIPMessage xmlns:ns1="http://www.niso.org/2008/ncip" ns1:version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.niso.org/2008/ncip http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">
	<!-- Usage in NNCIPP 1.0 is in use-case 3, call #8: ACK "Owner library informs Home library that a user requests one Item" -->
	<ns1:ItemShippedResponse>
		<!-- The ResponseHeader, stating from- and to-agency, is mandatory. -->
		<ns1:ResponseHeader>
			<!-- Home Library -->
			<ns1:FromAgencyId>
				<ns1:AgencyId>NO-7654321</ns1:AgencyId>
			</ns1:FromAgencyId>
			<!-- Owner Library -->
			<ns1:ToAgencyId>
				<ns1:AgencyId>NO-1234567</ns1:AgencyId>
			</ns1:ToAgencyId>
		</ns1:ResponseHeader>
		<!-- Echo UserId and ItemId to inform that msg was recived and is OK -->
		<ns1:Ext>
			<ns1:UserId>
				<ns1:UserIdentifierValue>N-342567</ns1:UserIdentifierValue>
			</ns1:UserId>
			<ns1:ItemId>
				<ns1:ItemIdentifierValue>82sd23457</ns1:ItemIdentifierValue>
			</ns1:ItemId>
		</ns1:Ext>
	</ns1:ItemShippedResponse>
</ns1:NCIPMessage>
