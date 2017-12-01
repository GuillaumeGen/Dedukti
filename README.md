USER MANUAL FOR DEDUKTI v2.5 (DRAFT)
====================================

### INSTALLATION


#### FROM OPAM

    opam repository add deducteam https://gforge.inria.fr/git/opam-deducteam/opam-deducteam.git
    opam update
    opam install dedukti.2.5

#### FROM SOURCES

In order to compile `Dedukti` you will need `OCaml` and `Menhir`.

    git clone https://github.com/Deducteam/Dedukti.git
    cd Dedukti
    make
    sudo make install

### QUICK START

    $ dkcheck examples/append.dk
    > File examples/append.dk was successfully checked.

### COMMAND LINE PROGRAMS

* `dkcheck` is the type-checker for `Dedukti`.
* `dktop` is an interactive wrapper around the type-checker.
* `dkdep` is a dependency generator for `Dedukti` files.
* `dkindent` is a program to indent `Dedukti` files.

### A SMALL EXAMPLE

A `Dedukti` file must begin with the name of the module.

    #NAME my_module.

Then we can declare constants, giving their name and their type.
`Dedukti` distinguishes two kinds of declarations:

* declaration of a *static* symbol `f` of type `A` is written `f : A`,
* declaration of a *definable* symbol `f` of type `A` is written `def f : A`.

Definable symbols can be defined using rewrite rules, static symbols can not be defined.

    Nat: Type.
    zero: Nat.
    succ: Nat -> Nat.
    def plus: Nat -> Nat -> Nat.

Let's add rewrite rules to compute additions.

    [ n ] plus zero n --> n
    [ n ] plus n zero --> n
    [ n, m ] plus (succ n) m --> succ (plus n m)
    [ n, m ] plus n (succ m) --> succ (plus n m).

When adding rewrite rules, `Dedukti` checks that they preserves typing.
For this, it checks that the left-hand and right-hand sides of the rules have the same type in some context giving types to the free variables
(in fact, the criterion used is more general, see below), that the free variables occurring in the right-hand side also occur in the left-hand side
and that the left-hand side is a *higher-order pattern* (see below).

**Remark:** there is no constraint on the number of rewrite rules associated with a definable symbol.
However it is necessary that the rewrite system generated by the rewrite rules together with beta-reduction
be confluent and terminating on well-typed terms. Confluence can be checked using the option `-cc` (see below),
termination is not checked (yet?).

**Remark:** Because static symbols cannot appear at head of rewrite rules, they are injective with respect to conversion and this information can be exploited by
`Dedukti` for type-checking rewrite rules (see below).

### ADVANCED FEATURES

#### SPLITTING A DEVELOPMENT BETWEEN SEVERAL FILES

A development in `Dedukti` is usually composed of several files corresponding to different modules.
Using `dkcheck` with the option `-e` will produce a file `my_module.dko` that exports the constants
and rewrite rules declared in the module `my_module`.
Then you can use these symbols in other files/modules using the prefix notation `my_module.identifier`.

#### COMMENTS

In `Dedukti` comments are delimited by `(;` and `;)`.

    (; This is a comment ;)

#### COMMANDS

Supported commands are:

    #WHNF t.        (;  display the weak head normal form of term t ;)
    #HNF t.         (;  diplay the head normal form of t. ;)
    #SNF t.         (;  display the strong normal form of t. ;)
    #STEP t.        (;  display a one-step reduce of t. ;)
    #CONV t1, t2.   (;  display "OK" if t1 and t2 are convertible, "KO" otherwise. ;)
    #CHECK t1, t2.  (;  display "OK" if t1 has type t2, "KO" otherwise. ;)
    #INFER t1.      (;  infer the type of t1 and display it. ;)
    #PRINT s.       (;  print the string s. ;)

#### DEFINITIONS

`Dedukti` supports definitions:

    def three : Nat := succ ( succ ( succ ( zero ) ) ).

or, omitting the type,

    def three := succ ( succ ( succ ( zero ) ) ).

A definition is syntactic sugar for a declaration followed by a rewrite rule.
The definition above is equivalent to:

    def three : Nat.
    [ ] three --> succ ( succ ( succ ( zero ) ) ).

Using the keyword `thm` instead of `def` makes a definition *opaque*, meaning that the defined symbol do not reduce
to the body of the definition. This means that the rewrite rule is not added to the system.

    thm three := succ ( succ ( succ ( zero ) ) ).

This can be useful when the body of a definition does not matter (only its existence matters), to avoid adding
a useless rewrite rule.

#### JOKERS

When a variable is not used on the right-hand side of a rewrite rule, it can be
replaced by an underscore on the left-hand side.

    def mult : Nat -> Nat -> Nat.
    [ n ] mult zero n --> zero
    [ n, m ] mult (succ n) m --> plus m (mult n m).

The first rule can also be written:

    [ ] mult zero _ --> zero.

#### TYPING OF REWRITE RULES

A typical example of the use of dependent types is the type of Vector defined as lists parametrized by their size:

    Elt: Type.
    Vector: Nat -> Type.
    nil: Vector zero.
    cons: n:Nat -> Elt -> Vector n -> Vector (succ n).

and a typical operation on vectors is concatenation:

    def append: n:Nat -> Vector n -> m:Nat -> Vector m -> Vector (plus n m).
    [ n, v ] append zero nil n v --> v
    [ n, v1, m, e, v2 ] append (succ n) (cons n e v1) m v2 --> cons (plus n m) e (append n v1 m v2).

These rules verify the typing constraint given above: both left-hand and right-hand sides have the same type.

Also, the second rule is non-left-linear; this is usually an issue because non-left-linear rewrite rules usually generate
a non-confluent rewrite system when combined with beta-reduction.

However, because we only intend to rewrite *well-typed* terms, the rule above is computationally equivalent to the following left-linear rule:

    [ n, v1, m, e, v2, x ] append x (cons n e v1) m v2 --> cons (plus n m) e (append n v1 m v2).

`Dedukti` will also accept this rule, even if the left-hand side is not well-typed, because it is able to detect that, because of typing
constraints, `x` can only be instantiated by a term of the form `succ n`
(this comes from the fact that `Vector` is a static symbol and is
hence injective with respect to conversion: from the type-checking constraint `Vector x = Vector (succ n)`, `Dedukti` deduces `x = succ n`).


For the same reason, it is not necessary to check that the first argument of `append` is `zero` for the first rule:

    [ n, v, x ] append x nil n v --> v.

Using underscores, we can write:

    [ v ] append _ nil _ v --> v
    [ n, v1, m, e, v2 ] append _ (cons n e v1) m v2 --> cons (plus n m) e (append n v1 m v2).

#### BRACKET PATTERNS

A different solution to the same problem is to mark with brackets the parts of the left-hand
side of the rewrite rules that are constrained by typing.

    [ n, v1, m, e, v2 ] append (succ n) (cons {n} e v1) m v2 --> cons (plus n m) e (append n v1 m v2).

The information between brackets will be used when typing the rule but they will not be match against when
using the rule (as if they were replaced by fresh variables).

**Remark:** in order to make this feature type-safe, `Dedukti` checks that the typing constraint is verified when using the rule and fails otherwise.

**Remark:** a variable can occur inside brackets only if it also occurs outside brackets and on the left of the brackets.

#### NON-LEFT-LINEAR REWRITE RULES

By default, `Dedukti` rejects non-left-linear rewrite rules because they usually generated non confluent rewrite systems
when combined with beta-reduction. This behaviour can be changed by invoking `dkcheck` with the option `-nl`.

    eq: Nat -> Nat -> Bool.
    [ n ] eq n n --> true.

#### HIGHER-ORDER REWRITE RULES

In the previous examples, left-hand sides of rewrite rules were first-order terms.
In fact, `Dedukti` supports a larger class of left-hand sides: *higher-order patterns*.

A *higher-order pattern* is a beta-normal term whose free variables are applied to (possibly empty) vectors of distinct bound variables.

A classical example of the use of higher-order rules is the encoding the simply types lambda-calculus with beta-reduction:

    type: Type.
    arrow: type -> type -> type.

    term: type -> Type.

    def app: a:type -> b:type -> term (arrow a b) -> term a -> term b.
    lambda: a:type -> b:type -> (term a -> term b) -> term (arrow a b).

    [ f, arg ] app _ _ (lambda _ _ (x => f x)) arg --> f arg.

**Remark:** type annotations on abstraction *must* be omitted.

**Remark:** free variables must be applied to the same number of arguments on the left-hand side and on the right-hand side
of the rule.

**Remark:** with such rewrite rules, matching is done modulo beta in order to preserve confluence.
This means that, in the context `(o: type)(c:term o)`, the term `App o o (Lam o o (x => x)) c` reduces to `c`.

#### CONFLUENCE CHECKING

`Dedukti` can check the confluence of the rewrite system generated by the rewrite rules and beta-reduction,
using an external confluence checker. For this you need to install a confluence checker for higher-order rewrite systems
supporting the TPDB format, for instance [CSI^HO](http://cl-informatik.uibk.ac.at/software/csi/ho/) or ACPH.

To enable confluence checking you need to call `dkcheck` with the option `-cc` followed by the path to the confluence checker:

    $ dkcheck -cc /path/to/csiho.sh examples/append.dk
    > File examples/append.dk was successfully checked.

### LICENSE

`Dedukti` is distributed under the CeCILL-B License.
