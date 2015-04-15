[%-
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
-%]
