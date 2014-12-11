[%-
    IF data.RequestId;
        INCLUDE "includes/RequestId.inc";
    END;
    INCLUDE "includes/ItemId.inc";
    INCLUDE "includes/UserId.inc";
    IF data.RequestType;
-%]
<RequestType>[% data.RequestType | xml %]</RequestType>
[%-
    END;
    IF data.RequestScopeType;
-%]
<RequestScopeType>[% data.RequestScopeType | xml %]</RequestScopeType>
[%-
    END;
    INCLUDE "includes/ItemOptionalFields.inc";
    INCLUDE "includes/UserOptionalFields.inc"
-%]
