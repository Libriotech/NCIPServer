[%-
    IF data.RequestId.RequestIdentifierValue;
        INCLUDE "includes/RequestId.inc";
    END;
    IF data.ItemId.ItemIdentifierValue;
        INCLUDE "includes/ItemId.inc";
    END;
    INCLUDE "includes/UserId.inc";
    IF data.RequestType;
-%]
<ns1:RequestType>[% data.RequestType | xml %]</ns1:RequestType>
[%
    END;
    IF data.RequestScopeType;
%]
<ns1:RequestScopeType>[% data.RequestScopeType | xml %]</ns1:RequestScopeType>
[%
    END;
    INCLUDE "includes/ItemOptionalFields.inc";
    INCLUDE "includes/UserOptionalFields.inc"
-%]
