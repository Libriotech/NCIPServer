<ns1:Problem>
[% IF problem.Scheme -%]
<ns1:ProblemType Scheme="[% problem.Scheme | xml %]">
[% ELSE -%]
<ns1:ProblemType>
[% END -%]
[%- problem.ProblemType | xml %]</ns1:ProblemType>
<ns1:ProblemDetail>[% problem.ProblemDetail | xml %]</ns1:ProblemDetail>
<ns1:ProblemElement>[% problem.ProblemElement | xml %]</ns1:ProblemElement>
<ns1:ProblemValue>[% problem.ProblemValue | xml %]</ns1:ProblemValue>
</ns1:Problem>
