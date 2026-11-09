#lang pollen

◊; MATH-1 fixture, read by Pollen itself (pollen-test.rkt): the three fixture
◊; expressions inline and on their own line, nested braces, the alternate
◊; delimiters for braces that do not balance, and an aside holding both forms.
◊; tools/maths.py reads tests/ too, so the cache always holds these.

A weight ◊m{W_a^{\min}}, a mean ◊m{\bar{x} = \frac{1}{n}\sum_{i=1}^{n} x_i}, a
rate ◊m{\text{incidence} = \frac{\text{new cases}}{\text{person-time at risk}}}
and a set ◊m|{\left\{ x : x > 0 \right.}|.

◊m[#:display #t]{W_a^{\min}}

◊m[#:display #t]{
\bar{x} = \frac{1}{n}\sum_{i=1}^{n} x_i
}

Text, then ◊m[#:display #t]{\text{incidence} = \frac{\text{new cases}}{\text{person-time at risk}}} inside the paragraph.

A circle◊aside{An aside's ◊m{W_a^{\min}} and its own line:
◊m[#:display #t]{\bar{x} = \frac{1}{n}\sum_{i=1}^{n} x_i}} and on.
