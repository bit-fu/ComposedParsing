ComposedParsing
===============

A simple parser definition utility in Swift using composable functions for rules

This is how a simple grammar for standard arithmetics might look like:

```swift

let arithmetic = Parser(terminals:["+", "-", "*", "/", "%", "Num", "(", ")"])

arithmetic.rule("expr", parses: "sum")

arithmetic.rule("sum", parses: "mul" &> "sumTail")

arithmetic.rule("sumTail", parses:
    "+" &> "mul"
        &> { $ in ($(0) as NSNumber).doubleValue + ($(2) as NSNumber).doubleValue }
        &> "sumTail"

 |> "-" &> "mul"
        &> { $ in ($(0) as NSNumber).doubleValue - ($(2) as NSNumber).doubleValue }
        &> "sumTail"

 |> { $ in $(0) })

arithmetic.rule("mul", parses: "sgn" &> "mulTail")

arithmetic.rule("mulTail", parses:
    "*" &> "sgn"
        &> { $ in ($(0) as NSNumber).doubleValue * ($(2) as NSNumber).doubleValue }
        &> "mulTail"

 |> "/" &> "sgn"
        &> { $ in ($(0) as NSNumber).doubleValue / ($(2) as NSNumber).doubleValue }
        &> "mulTail"

 |> "%" &> "sgn"
        &> { $ in ($(0) as NSNumber).doubleValue % ($(2) as NSNumber).doubleValue }
        &> "mulTail"

 |> { $ in $(0) })

arithmetic.rule("sgn", parses:
    "-" &> "sgn" &> { $ in -($(2) as NSNumber).doubleValue }
 |> "+" &> "sgn" &> { $ in +($(2) as NSNumber).doubleValue }
 |> "term")

arithmetic.rule("term", parses:
    "(" &> "expr" &> ")" &> { $ in $(2) }
 |> "Num")

// Parse this grammar on the given token source.
arithmetic.start("expr"<!, tokenSource)
```

This project was inspired by  [swift-parser-generator](https://github.com/dparnell/swift-parser-generator), but also aims to be different.  I still want the Lexer to do low level work like converting digit strings to numbers.  By writing a Lexer yourself, you at least have the chance to maximize efficiency there, while in parser rules you don't have so much sway.  You're very much subject to the parser's machinery, which isn't particularly intelligent and just as efficient as I came up with in a few days.  So while this might be a useful tool, it's certainly not on the same level as `yacc(1)` or `bison(1)`.

## Known Shortcomings

- There are no warnings for any conflicts and syntax errors in rule definitions will produce strange messages.
- The parser doesn't do left-binding rules naturally.  Especially, `parser.rule("foo", parses: "foo" |> ...)` will create a Stack Overflow® via endless recursion (and without prior warning).
- It doesn't create independent static code but a "parse tree" containing your action code blocks (Swift-compiled closures) that must be interpreted by a `Parser` method to perform a parse.  OTOH, those closures should have no problem accessing common resources from the grammar's definition environment.
