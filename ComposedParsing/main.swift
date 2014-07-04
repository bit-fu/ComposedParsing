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
 *      2014·06·26          Created by Ulrich Singer
 */

import Foundation


let arithmetic = Parser(terminals:["+", "-", "*", "/", "%", "Num", "(", ")"])

arithmetic.rule("term", parses:
    "(" &> "expr" &> ")" !> { $ in $(2) }
 |> "Num")

arithmetic.rule("sgn", parses:
    "-" &> "sgn" !> { $ in
        let rhs = $(2) as NSNumber
        return -rhs.doubleValue
    }
 |> "+" &> "sgn" !> { $ in
        let rhs = $(2) as NSNumber
        return rhs.doubleValue
    }
 |> "term")

arithmetic.rule("mul", parses:
    "sgn" &> "*" &> "mul" !> { $ in
        let lhs = $(1) as NSNumber
        let rhs = $(3) as NSNumber
        return lhs.doubleValue * rhs.doubleValue
    }
 |> "sgn" &> "/" &> "mul" !> { $ in
        let lhs = $(1) as NSNumber
        let rhs = $(3) as NSNumber
        return lhs.doubleValue / rhs.doubleValue
    }
 |> "sgn" &> "%" &> "mul" !> { $ in
        let lhs = $(1) as NSNumber
        let rhs = $(3) as NSNumber
        return lhs.doubleValue % rhs.doubleValue
    }
 |> "sgn")

arithmetic.rule("sum", parses:
    "mul" &> "+" &> "sum" !> { $ in
        let lhs = $(1) as NSNumber
        let rhs = $(3) as NSNumber
        return lhs.doubleValue + rhs.doubleValue
    }
 |> "mul" &> "-" &> "sum" !> { $ in
        let lhs = $(1) as NSNumber
        let rhs = $(3) as NSNumber
        return lhs.doubleValue - rhs.doubleValue
    }
 |> "mul")

arithmetic.rule("expr", parses: "sum")

let tokenSource = ArrayLexer(tokens:[("(",""), ("Num",1), ("-",""), ("Num",6), (")",""), ("/",""), ("+",""), ("Num",4)])

var rule = "expr"<!
var val: Parser.Result
let t0 = NSDate()
for _ in 1..100
{
    val = arithmetic.start(rule, tokenSource)
    tokenSource.reset()
}
let t1 = NSDate()
let dt = t1.timeIntervalSinceDate(t0)
println("∆t = \(dt) s\n\(val)")


/* ~ main.swift ~ */