/*  ————————————————————————————————————————————————————————————————————————  *
 *
 *      main.swift
 *      ~~~~~~~~~~
 *
 *      Demo for ComposedParsing
 *
 *      Project:            ComposedParsing
 *
 *      File encoding:      UTF-8
 *
 *      Created 2014·06·26: Ulrich Singer
 */

import Foundation


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

let tokenSource = ArrayLexer(tokens:[("(",""),("Num",6),("-",""),("Num",1),(")",""), ("/",""), ("+",""),("Num",2), ("/",""), ("-",""),("Num",2)])

var rule = "expr"<!
var val: Parser.Result
let t0 = NSDate()
for _ in 1...1000
{
    val = arithmetic.start(rule, tokenSource)
    tokenSource.reset()
}
let t1 = NSDate()
let dt = t1.timeIntervalSinceDate(t0)
println("∆t = \(dt) s\n\(val!)")


/* ~ main.swift ~ */