ComposedParsing
===============

A simple parser definition utility in Swift using composable functions for rules.

This is how a simple grammar for standard arithmetics might look like:

```swift

let arithmetic = Parser(terminals:["+", "-", "*", "/", "%", "Num", "(", ")"])

arithmetic.rule("expr", parses: "sum")

arithmetic.rule("sum", parses: "mul" &> "sumTail")

arithmetic.rule("sumTail", parses:
    "+" &> "mul"
        &> { $ in ($(0) as! NSNumber).doubleValue + ($(2) as! NSNumber).doubleValue }
        &> "sumTail"

 |> "-" &> "mul"
        &> { $ in ($(0) as! NSNumber).doubleValue - ($(2) as! NSNumber).doubleValue }
        &> "sumTail"

 |> { $ in $(0) })

arithmetic.rule("mul", parses: "sgn" &> "mulTail")

arithmetic.rule("mulTail", parses:
    "*" &> "sgn"
        &> { $ in ($(0) as! NSNumber).doubleValue * ($(2) as! NSNumber).doubleValue }
        &> "mulTail"

 |> "/" &> "sgn"
        &> { $ in ($(0) as! NSNumber).doubleValue / ($(2) as! NSNumber).doubleValue }
        &> "mulTail"

 |> "%" &> "sgn"
        &> { $ in ($(0) as! NSNumber).doubleValue % ($(2) as! NSNumber).doubleValue }
        &> "mulTail"

 |> { $ in $(0) })

arithmetic.rule("sgn", parses:
    "-" &> "sgn" &> { $ in -($(2) as! NSNumber).doubleValue }
 |> "+" &> "sgn" &> { $ in +($(2) as! NSNumber).doubleValue }
 |> "term")

arithmetic.rule("term", parses:
    "(" &> "expr" &> ")" &> { $ in $(2) }
 |> "Num")

// Parse this grammar on the given token source.
arithmetic.start("expr"<!, tokenSource)
```

## Rule Elements

Let's say we have a Lexer that yields tokens for words and numbers.  Call the word tokens `"W"` (with a string value) and the number tokens `"N"` (with a numeric value).  Then we can define a Parser:

```swift
let parser = Parser(terminals:["W", "N"])
```

Add some rules:

```swift
parser.rule("word", parses: "W")
parser.rule("num", parses: "N")
parser.rule("numWord", parses: "num" &> "word")
```

Now we can explain the components.

### Strings

You use Strings in your rules to refer to terminals and nonterminals.

A terminal is parsed successfully if the Lexer's next token has that terminal name.  The set of terminals is defined in the Parser's constructor.

Nonterminals are the parsing rules you define with the `rule` method.  A nonterminal is parsed successfully if the components of the rule defined (the value of the `parses` argument) can be parsed.

In the example above, `"num"`, `"word"` and `"numWord"` refer to nonterminals, and `"W"` and `"N"` refer to terminals.

It is your responsibility to use different sets of names for terminals and nonterminals.  In case of an overlap, a string will refer to its terminal interpretation.

### Composition Operators

Nonterminals are there so you can compose larger grammatical units out of smaller ones.  For that, you use the composition operators.

#### Conjunction
```swift
LHS &> RHS
```
Parses `LHS` first, then `RHS`.  If `LHS` fails, `RHS` is not parsed and the whole conjunction fails.  If `LHS` succeeds, the conjunction's value is the value of `RHS`.  Writing `A &> B &> C` is equivalent to writing `(A &> B) &> C`.

#### Disjunction
```swift
LHS |> RHS
```
Parses `LHS` first and if it succeeds, returns its value without parsing `RHS`.  If `LHS` fails, `RHS` is parsed and the disjunction returns its value.  Writing `A |> B |> C` is equivalent to writing `(A |> B) |> C`.

The disjunction has a lower precedence than the conjunction.  That means, if you write `A |> B &> C |> D`, it's the same as `A |> (B &> C) |> D`.

#### Termination

When defining a grammar, you normally want it to apply to all available input and only parse successfully after the last input token has been made sense of.  You express this with the termination operator.

```swift
RULE<!
```
or

```swift
RULE <! ACTION
```

After the `RULE` parses successfully, the termination operator verifies that the Lexer has no tokens left, and if so, returns the `RULE`'s value.  If the Lexer has still tokens left, the operator fails.

The second form doesn't necessarily return the `RULE`'s value but the value of your `ACTION` code block, if the operator succeeds.

### Actions

You only need two kinds of things to compose your rules of: Strings, to refer to the named parts of your grammar, and actions, which are Swift code blocks with an interface that's defined by the Parser class.  The job of an action is to take values that resulted from parsing other elements before, doing something with them, and then return some value to signal success, or `nil` to signal failure.

Let's add an action to the last rule of our parser example above:

```swift
parser.rule("numWord", parses: "num" &> "word" &> { $ in
		let n = $(1) as! NSNumber
		let w = $(2) as! NSString
		println("\(n) \(w)")
		return true
	})
```

The action block is passed one argument, which is a value getter function.  Here, it is named `$`.  The argument you pass to the getter is the position number, in the current rule, of the element whose value you want to obtain.  The first rule element has the number 1.

Every operand of the composition functions, if parsed successfully, returns a value.  It's those values you pick up with the getter function.  Failed parses don't leave a value.

Action blocks also have a return value whose type is identical to the terminal and nonterminal types.  Thus, your action return value can become the value of the nonterminal it belongs to (like in the example above).

If your action returns `nil`, it is viewed as a failed parse.  Otherwise the value is stored in the place that corresponds to the action's position in the rule, and is available to later actions as `$(N)` (where `N` is the position number of the previous rule).

## Known Shortcomings

- There are no warnings for any rule conflicts or generally bad rule constructions.
- Syntax errors in rule definitions will produce strange messages.
- The parser doesn't do left-associative rules naturally.
- `parser.rule("foo", parses: "foo" |> ...)` *will* create a Stack Overflow® via infinite recursion, without prior warning.

## Good Points

- Type inference is your friend.  You need no boiler plate or syntactic sugar to formulate rules in the Parser's composition language.
- If you write reasonably efficient rules, the machine will waste no time getting your input parsed.  The internal representation of rules is consciously chosen so the Parser can manipulate it into speedy processing.

## Remarks

This project was inspired by  [swift-parser-generator](https://github.com/dparnell/swift-parser-generator), but also aims to be different.  I still want the Lexer to do low level work like converting digit strings to numbers.  By writing a Lexer yourself, you at least have the chance to maximise efficiency there, while in parser rules you don't have so much sway.
