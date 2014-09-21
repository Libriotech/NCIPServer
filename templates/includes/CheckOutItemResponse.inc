[% INCLUDE "includes/CheckInItemResponse.inc" %]
[% IF data.DateDue -%]
<DateDue>[% data.DateDue | xml %]</DateDue>
[% END -%]
