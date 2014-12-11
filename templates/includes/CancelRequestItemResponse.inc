[%-
    IF data.RequestId;
       INCLUDE "includes/RequestId.inc";
    END;
    IF data.ItemId;
        INCLUDE "includes/ItemId.inc";
    END;
    INCLUDE "includes/UserId.inc";
    INCLUDE "includes/ItemOptionalFields.inc"
    INCLUDE "includes/UserOptionalFields.inc";
-%]
