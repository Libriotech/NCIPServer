[% INCLUDE "includes/CheckInItemResponse.inc" %]
[% IF data.DateDue -%]
<ncip:DateDue>[% data.DateDue | xml %]</ncip:DateDue>
[% END -%]
