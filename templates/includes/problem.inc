<ncip:Problem>
[% IF problem.Scheme -%]
<ncip:ProblemType Scheme="[% problem.Scheme | xml %]">
[% ELSE -%]
<ncip:ProblemType>
[% END -%]
[% problem.ProblemType | xml %]
</ncip:ProblemType>
<ncip:ProblemDetail>
[% problem.ProblemDetail | xml %]
</ncip:ProblemDetail>
<ncip:ProblemElement>
[% problem.ProblemElement | xml %]
</ncip:ProblemElement>
<ncip:ProblemValue>
[% problem.ProblemValue | xml %]
</ncip:ProblemValue>
</ncip:Problem>
