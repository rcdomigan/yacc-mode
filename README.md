yacc-mode.el
============

Provides an emacs major mode for editing yacc files.  I wasn't able to find such a thing when I was in a compilers course and wound up making this; maybe it'll save someone in the same position some time.

Indentation
===========

Basically, C indentation rules are applied between braces ("{}"), but suspended outside of them.  Outside of the braces, yacc-mode tries to line up grammar rules.

```
typed_identifier_list   : declaring_id ',' typed_identifier_list
                          {
                            c_declare_var($1, (Signifer)$3);
                            $$ = $3;
                          }
                        | declaring_id ':' type
                          {
                            c_declare_var($1, (Signifer)$3);
                            $$ = $3;
                          }
                       ;
```

The indentation mostly work, if you hit tab a few times outside the C blocks it likely won't do what you expect.


Examining grammar rule
======================

The mode provides a few helpers for examining token references (ie $$, $1):

I'll use |x| to show where point is, ie in ```|t|hing``` point is on t

* yacc-find-type: prints the %type or %token information corresponding to the token reference under point, ie

```C++
%token <sym> IDENTIFIER DIGITS STRIN
%type <sym> number opt_params program_name declaring_id 

...

declaring_id            : IDENTIFIER
                          {
                            |$|$ = $1 ;
                          }
                       ;
```
puts 'sym' in the message buffer

* yacc-highlight-matching-word: highlights the word in the grammar matching the reference under point.  This function is attached to the yacc-idle-timer, so you can just put point on the references you want to examine.

```C++
declaring_id            : IDENTIFIER
                          {
                            $$ = |$|1 ;
                          }
                       ;
```

