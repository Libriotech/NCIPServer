<ns1:Problem>
[% IF problem.Scheme -%]
<ns1:ProblemType Scheme="[% problem.Scheme | xml %]">
[% ELSE -%]
<ns1:ProblemType>
[% END -%]
[%- problem.ProblemType | xml %]</ns1:ProblemType>
[% IF problem.ProblemDetail  %]<ns1:ProblemDetail>[%  problem.ProblemDetail  | xml %]</ns1:ProblemDetail>[% END %]
[% IF problem.ProblemElement %]<ns1:ProblemElement>[% problem.ProblemElement | xml %]</ns1:ProblemElement>[% END %]
[% IF problem.ProblemValue   %]<ns1:ProblemValue>[%   problem.ProblemValue   | xml %]</ns1:ProblemValue>[% END %]
</ns1:Problem>
