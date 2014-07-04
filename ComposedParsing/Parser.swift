/*  ————————————————————————————————————————————————————————————————————————  *
 *
 *      Parser.swift
 *      ~~~~~~~~~~~~
 *
 *      Model class for grammar parsing
 *
 *      Project:            ComposedParsing
 *
 *      File encoding:      UTF-8
 *
 *      2014·06·26          Created by Ulrich Singer
 */

import Foundation


/// A token, as returned from the Lexer.
typealias Token = (terminal: String, value: Parser.Value)

/// A source of tokens for the Parser.
protocol Lexer
{
    /// Consumes & returns the next token.
    func next () -> Token?

    func tell () -> Int

    func seek (Int)

    /// Returns `true` if all tokens have been consumed.
    func done () -> Bool
}

/// A Parser using rules made of composable functions.
class Parser
{
    typealias Value  = AnyObject
    typealias Result = Value?
    typealias Rule   = (Parser, Lexer) -> Result
    typealias Getter = (Int) -> Value
    typealias Action = (Getter) -> Result

    // Abstraction for nonterminal elements.
    enum Part
    {
        case RulePromise(String)
        case TerminalLex(String)
        case NestedParse(Part[])    // Boxing Array
        case Conjunction(Part[])    // Actual Array
        case Disjunction(Part[])    // Actual Array
        case Computation(Action[])  // Boxing Array
        case Termination(Part[])    // Boxing Array
    }

    var _ruleMap: Dictionary<String, Bool>
    var _partMap: Dictionary<String, Part>
    var _values:  Value[]
    var _stkptr:  Int
    var _ntbase:  Int

    func store (value: Value)
    {
        if _stkptr >= _values.count
        {
            _values.append(value)
        }
        else
        {
            _values[_stkptr] = value
        }
        ++_stkptr
    }

    // Rule interpreter.
    func execute (part: Part, _ lexer: Lexer)
    -> Result
    {
        func resolve (name: String) -> Part
        {
            if let _    = _ruleMap[name] { return .TerminalLex(name)   }
            if let part = _partMap[name] { return .NestedParse([part]) }

            println("Parser error: Undefined symbol “\(name)”")
            return .Disjunction([])     // Constant Failure.
        }
        
        func element (body: Part[], index: Int) -> Part
        {
            var part = body[index]
            switch part
            {
            case .RulePromise(let name) :
                part = resolve(name)
                body[index] = part
            default :
                nil
            }
            return part
        }

        switch part
        {
        case .RulePromise(let name) :
            return execute(resolve(name), lexer)
            
        case .TerminalLex(let name) :
            if let (term, value: Value) = lexer.next()
            {
                if term == name
                {
                    store(value)
                    return value
                }
            }
            return nil

        case .NestedParse(let partBox) :
            let stkptr = _stkptr
            let ntbase = _ntbase
            _ntbase = stkptr
            let result: Result = execute(partBox[0], lexer)
            _stkptr = stkptr
            _ntbase = ntbase
            if let value: Value = result { store(value) }
            return result
            
        case .Conjunction(let body) :
            var index = 0
            let limit = body.count
            var latest: Result = true
            while latest && index < limit
            {
                latest = execute(element(body, index), lexer)
                ++index
            }
            return latest
            
        case .Disjunction(let body) :
            let stkptr = _stkptr
            let mark = lexer.tell()
            let count = body.count
            for index in 0...count
            {
                let result: Result = execute(element(body, index), lexer)
                if result { return result }
                _stkptr = stkptr
                lexer.seek(mark)
            }
            return nil
            
        case .Computation(let actionBox) :
            return actionBox[0](getter)
            
        case .Termination(let partBox) :
            let result: Result = execute(partBox[0], lexer)
            return lexer.done() ? result : nil
        }
    }

    // Getter for the current NT's parse results.
    @lazy var getter: Getter = { [unowned self] index in self._values[self._ntbase + index - 1] }

    /// Constructs a parser for a grammar with the given terminal symbols.
    init (terminals: String[])
    {
        _ruleMap = Dictionary()
        _partMap = Dictionary()
        _values  = []
        _stkptr  = 0
        _ntbase  = 0

        for name in terminals
        {
            _ruleMap[name] = true
        }
    }

    /// Defines a parsing rule for the named nonterminal in the grammar.
    func rule (name: String, parses part: Part)
    {
        _partMap[name] = part
    }

    /// Defines a parsing rule for the named nonterminal in the grammar.
    func rule (name: String, parses symbol: String)
    {
        rule(name, parses: .RulePromise(symbol))
    }

    /// Parses the defined grammar starting with the given rule.
    func start (part: Part, _ lexer: Lexer)
    -> Result
    {
        _values = []
        _stkptr = 0
        _ntbase = 0

        return execute(part, lexer)
    }

    /// Parses the defined grammar with the given start symbol.
    func start (symbol: String, _ lexer: Lexer)
    -> Result
    {
        return start(.RulePromise(symbol), lexer)
    }

}   // class Parser


/// Rule Compositions

operator prefix  =< {}                                    // Transparent
operator prefix  =! {}                                    // Transparent
operator infix   &> { associativity left precedence 40 }  // Conjunction
operator infix   !> { associativity left precedence 30 }  // Computation
operator infix   <! { associativity left precedence 30 }  // Termination & Computation
operator infix   |> { associativity left precedence 20 }  // Disjunction
operator postfix <! {}                                    // Termination


/// =<`value`   (an Unconditional Success rule)
/// Successfully parses an empty slice of input and returns the given value.
@prefix func =< (value: Parser.Value)
-> Parser.Part
{
    return .Computation([{ _ in value }])
}

/// =!`action`   (an Unconditional Success rule)
/// Successfully parses an empty slice of input and returns the action's value.
@prefix func =! (action: Parser.Action)
-> Parser.Part
{
    return .Computation([action])
}

/// `part` &> `part`
/// Attempts to parse the conjunction of LHS and RHS sequentially.
@infix func &> (lhsPart: Parser.Part, rhsPart: Parser.Part)
-> Parser.Part
{
    switch lhsPart
    {
    case .Conjunction(let lhsBody) :
        var body = lhsBody
        switch rhsPart
        {
        case .Conjunction(let rhsBody) :
            body.extend(rhsBody)
            return .Conjunction(body)

        default :
            body.append(rhsPart)
            return .Conjunction(body)
        }

    default :
        switch rhsPart
        {
        case .Conjunction(let rhsBody) :
            var body = rhsBody
            body.insert(lhsPart, atIndex: 0)
            return .Conjunction(body)

        default :
            return .Conjunction([lhsPart, rhsPart])
        }
    }
}

@infix func &> (lhsPart: Parser.Part, rhsName: String)
-> Parser.Part
{
    return (lhsPart &> .RulePromise(rhsName))
}

@infix func &> (lhsName: String, rhsPart: Parser.Part)
-> Parser.Part
{
    return (.RulePromise(lhsName) &> rhsPart)
}

@infix func &> (lhsName: String, rhsName: String)
-> Parser.Part
{
    return .Conjunction([.RulePromise(lhsName), .RulePromise(rhsName)])
}

/// `part` |> `part`
/// Attempts to parse LHS first and RHS afterwards, if LHS fails.
@infix func |> (lhsPart: Parser.Part, rhsPart: Parser.Part)
-> Parser.Part
{
    switch lhsPart
    {
    case .Disjunction(let lhsBody) :
        var body = lhsBody
        switch rhsPart
        {
        case .Disjunction(let rhsBody) :
            body.extend(rhsBody)
            return .Disjunction(body)

        default :
            body.append(rhsPart)
            return .Disjunction(body)
        }

    default :
        switch rhsPart
        {
        case .Disjunction(let rhsBody) :
            var body = rhsBody
            body.insert(lhsPart, atIndex: 0)
            return .Disjunction(body)

        default :
            return .Disjunction([lhsPart, rhsPart])
        }
    }
}

@infix func |> (lhsPart: Parser.Part, rhsName: String)
-> Parser.Part
{
    return (lhsPart |> .RulePromise(rhsName))
}

@infix func |> (lhsName: String, rhsPart: Parser.Part)
-> Parser.Part
{
    return (.RulePromise(lhsName) |> rhsPart)
}

@infix func |> (lhsName: String, rhsName: String)
-> Parser.Part
{
    return .Disjunction([.RulePromise(lhsName), .RulePromise(rhsName)])
}

/// `part` !> `action`
/// Returns the actions's value if the rule could be parsed.
@infix func !> (condition: Parser.Part, action: Parser.Action)
-> Parser.Part
{
    return (condition &> .Computation([action]))
}

@infix func !> (condName: String, action: Parser.Action)
-> Parser.Part
{
    return (.RulePromise(condName) &> .Computation([action]))
}

/// `part`<!
/// Asserts End-Of-Input (EOI) after parsing the preceding rule.
@postfix func <! (part: Parser.Part)
-> Parser.Part
{
    return .Termination([part])
}

@postfix func <! (name: String)
-> Parser.Part
{
    return .Termination([.RulePromise(name)])
}

/// `part` <! `action`
/// Asserts EOI after parsing the rule, then returns the action's value.
@infix func <! (condition: Parser.Part, action: Parser.Action)
-> Parser.Part
{
    return (.Termination([condition]) &> .Computation([action]))
}

@infix func <! (condName: String, action: Parser.Action)
-> Parser.Part
{
    return (.Termination([.RulePromise(condName)]) &> .Computation([action]))
}

/// Sequence construction utility for use in rule actions.
func cons (car: AnyObject, cdr: AnyObject)
-> AnyObject[]
{
    var list = cdr as AnyObject[];
    list.insert(car, atIndex: 0)
    return list
}


/* ~ Parser.swift ~ */