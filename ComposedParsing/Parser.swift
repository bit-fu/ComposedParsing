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

    /// Returns the current position in the underlying input stream.
    func tell () -> Int

    /// Moves to the given position in the underlying input stream,
    /// undoing token consumption from that position onward.
    func seek (Int)

    /// Returns `true` if all tokens have been consumed.
    /// Note that a `seek()` might revert this state.
    func done () -> Bool
}

/// A Parser using rules made of composable functions.
class Parser
{
    /// —— Public Types ——

    // Values that occur during parsing.  Those are terminal values
    // from the lexer as well as parse results of nonterminal rules
    // and return values from your action code blocks.
    typealias Value  = NSObject

    // Actual rule result type includes the possibility of failure.
    typealias Result = Value?

    // Interface that lets your action code blocks access the parse
    // results of previous elements in the current nonterminal rule.
    // Naming the Getter as `$`, you access the first value with
    // `$(1)`.  `$(0)` would access the last value that was parsed
    // before the current rule became active.  It is your responsibility
    // to keep the index argument to the Getter in a sensible range.
    typealias Getter = (Int) -> Value

    // Your action code blocks.  Note that you may return nil to signal failure.
    typealias Action = (Getter) -> Result

    /// —— Public Methods ——

    /// Constructs a parser for a grammar with the given terminal symbols.
    init (terminals: String[])
    {
        _tsRule = Dictionary()
        _ntRule = Dictionary()
        _values = []
        _stkptr = 0
        _ntbase = 0

        for name in terminals
        {
            _tsRule[name] = true
        }
    }

    /// Defines a parsing rule for the named nonterminal in the grammar.
    func rule (name: String, parses rule: Rule)
    {
        _ntRule[name] = rule
    }

    /// Defines a parsing rule for the named nonterminal in the grammar.
    func rule (name: String, parses symbol: String)
    {
        rule(name, parses: .RulePromise(symbol))
    }

    /// Defines a parsing rule for the named nonterminal in the grammar.
    func rule (name: String, parses block: Parser.Action)
    {
        rule(name, parses: .Computation([block]))
    }

    /// Parses the defined grammar starting with the given rule.
    func start (rule: Rule, _ lexer: Lexer)
    -> Result
    {
        _values = []
        _stkptr = 0
        _ntbase = 0

        return execute(compile(rule), lexer)
    }

    /// Parses the defined grammar with the given start symbol.
    func start (symbol: String, _ lexer: Lexer)
    -> Result
    {
        return start(.RulePromise(symbol), lexer)
    }

    /// —— Private Parts ——

    // Abstraction for nonterminal elements.
    enum Rule
    {
        case RulePromise(String)
        case TerminalLex(String)
        case NestedParse(Rule[])    // Boxing Array
        case Conjunction(Rule[])    // Actual Array
        case Disjunction(Rule[])    // Actual Array
        case Computation(Action[])  // Boxing Array
        case Termination(Rule[])    // Boxing Array
    }

    var _tsRule: Dictionary<String, Bool>
    var _ntRule: Dictionary<String, Rule>
    var _values: Value[]
    var _stkptr: Int
    var _ntbase: Int

    // Getter for the current NT's parse results.
    @lazy var getter: Getter = { [unowned self] index in self._values[self._ntbase + index - 1] }

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

    // Destructive rule preprocessor.
    func compile (rule: Rule, _ ntNames: String[] = [])
    -> Rule
    {
        switch rule
        {
        case .RulePromise(let name) :
            if let _ = _tsRule[name]
            {
                return .TerminalLex(name)
            }
            if let namedRule = _ntRule[name]
            {
                var newRule = namedRule
                if !contains(ntNames, name)
                {
                    var moreNames = ntNames.copy()
                    moreNames.append(name)
                    newRule = compile(namedRule, moreNames)
                }
                switch newRule
                {
                case .NestedParse(_) :
                    break
                case .TerminalLex(_) :
                    break
                case .Computation(_) :
                    break
                default :
                    newRule = .NestedParse([newRule])
                }
                _ntRule[name] = newRule
                return newRule
            }
            println("Parser error: Undefined symbol “\(name)”")
            return .Disjunction([])     // Constant Failure.

        case .Conjunction(let body) :
            for index in 0..body.count
            {
                body[index] = compile(body[index], ntNames)
            }
            return rule

        case .Disjunction(let body) :
            for index in 0..body.count
            {
                body[index] = compile(body[index], ntNames)
            }
            return rule

        case .Termination(let ruleBox) :
            ruleBox[0] = compile(ruleBox[0], ntNames)
            return rule

        default :
            return rule
        }
    }

    // Rule interpreter.
    func execute (rule: Rule, _ lexer: Lexer)
    -> Result
    {
        switch rule
        {
        case .RulePromise(_) :
            return execute(compile(rule), lexer)

        case .TerminalLex(let name) :
            if let (terminal, value) = lexer.next()
            {
                if terminal == name
                {
                    store(value)
                    return value
                }
            }
            return nil

        case .NestedParse(let ruleBox) :
            let stkptr = _stkptr
            let ntbase = _ntbase
            _ntbase = stkptr
            let result = execute(ruleBox[0], lexer)
            _stkptr = stkptr
            _ntbase = ntbase
            if let value = result { store(value) }
            return result

        case .Conjunction(let body) :
            var index = 0
            let count = body.count
            var latest: Result = true
            while latest && index < count
            {
                latest = execute(body[index++], lexer)
            }
            return latest

        case .Disjunction(let body) :
            let stkptr = _stkptr
            let mark = lexer.tell()
            for index in 0..body.count
            {
                let result = execute(body[index], lexer)
                if result { return result }
                _stkptr = stkptr
                lexer.seek(mark)
            }
            return nil

        case .Computation(let actionBox) :
            let result = actionBox[0](getter)
            if let value = result { store(value) }
            return result

        case .Termination(let ruleBox) :
            let result = execute(ruleBox[0], lexer)
            return lexer.done() ? result : nil
        }
    }

}   // class Parser


/// Rule Compositions

operator prefix  =< {}                                    // Transparent
operator infix   &> { associativity left precedence 40 }  // Conjunction
operator infix   <! { associativity left precedence 30 }  // Termination & Computation
operator infix   |> { associativity left precedence 20 }  // Disjunction
operator postfix <! {}                                    // Termination


/// =<`value`   (an Unconditional Success rule)
/// Successfully parses an empty slice of input and returns the given value.
@prefix func =< (value: Parser.Value)
-> Parser.Rule
{
    return .Computation([{ _ in value }])
}

/// `rule` &> `rule`
/// Attempts to parse the conjunction of LHS and RHS sequentially.
@infix func &> (lhsRule: Parser.Rule, rhsRule: Parser.Rule)
-> Parser.Rule
{
    switch lhsRule
    {
    case .Conjunction(let lhsBody) :
        var body = lhsBody.copy()
        switch rhsRule
        {
        case .Conjunction(let rhsBody) :
            body.extend(rhsBody)
            return .Conjunction(body)

        default :
            body.append(rhsRule)
            return .Conjunction(body)
        }

    default :
        switch rhsRule
        {
        case .Conjunction(let rhsBody) :
            var body = rhsBody.copy()
            body.insert(lhsRule, atIndex: 0)
            return .Conjunction(body)

        default :
            return .Conjunction([lhsRule, rhsRule])
        }
    }
}

@infix func &> (lhsRule: Parser.Rule, rhsBlock: Parser.Action)
-> Parser.Rule
{
    return (lhsRule &> .Computation([rhsBlock]))
}

@infix func &> (lhsRule: Parser.Rule, rhsName: String)
-> Parser.Rule
{
    return (lhsRule &> .RulePromise(rhsName))
}

@infix func &> (lhsBlock: Parser.Action, rhsRule: Parser.Rule)
-> Parser.Rule
{
    return (.Computation([lhsBlock]) &> rhsRule)
}

@infix func &> (lhsBlock: Parser.Action, rhsName: String)
-> Parser.Rule
{
    return (.Computation([lhsBlock]) &> .RulePromise(rhsName))
}

@infix func &> (lhsName: String, rhsRule: Parser.Rule)
-> Parser.Rule
{
    return (.RulePromise(lhsName) &> rhsRule)
}

@infix func &> (lhsName: String, rhsBlock: Parser.Action)
-> Parser.Rule
{
    return (.RulePromise(lhsName) &> .Computation([rhsBlock]))
}

@infix func &> (lhsName: String, rhsName: String)
-> Parser.Rule
{
    return .Conjunction([.RulePromise(lhsName), .RulePromise(rhsName)])
}

/// `rule` |> `rule`
/// Attempts to parse LHS first and RHS afterwards, if LHS fails.
@infix func |> (lhsRule: Parser.Rule, rhsRule: Parser.Rule)
-> Parser.Rule
{
    switch lhsRule
    {
    case .Disjunction(let lhsBody) :
        var body = lhsBody.copy()
        switch rhsRule
        {
        case .Disjunction(let rhsBody) :
            body.extend(rhsBody)
            return .Disjunction(body)

        default :
            body.append(rhsRule)
            return .Disjunction(body)
        }

    default :
        switch rhsRule
        {
        case .Disjunction(let rhsBody) :
            var body = rhsBody.copy()
            body.insert(lhsRule, atIndex: 0)
            return .Disjunction(body)

        default :
            return .Disjunction([lhsRule, rhsRule])
        }
    }
}

@infix func |> (lhsRule: Parser.Rule, rhsBlock: Parser.Action)
-> Parser.Rule
{
    return (lhsRule |> .Computation([rhsBlock]))
}

@infix func |> (lhsRule: Parser.Rule, rhsName: String)
-> Parser.Rule
{
    return (lhsRule |> .RulePromise(rhsName))
}

@infix func |> (lhsBlock: Parser.Action, rhsRule: Parser.Rule)
-> Parser.Rule
{
    return (.Computation([lhsBlock]) |> rhsRule)
}

@infix func |> (lhsBlock: Parser.Action, rhsName: String)
-> Parser.Rule
{
    return (.Computation([lhsBlock]) |> .RulePromise(rhsName))
}

@infix func |> (lhsName: String, rhsRule: Parser.Rule)
-> Parser.Rule
{
    return (.RulePromise(lhsName) |> rhsRule)
}

@infix func |> (lhsName: String, rhsBlock: Parser.Action)
-> Parser.Rule
{
    return (.RulePromise(lhsName) |> .Computation([rhsBlock]))
}

@infix func |> (lhsName: String, rhsName: String)
-> Parser.Rule
{
    return .Disjunction([.RulePromise(lhsName), .RulePromise(rhsName)])
}

/// `rule`<!
/// Asserts End-Of-Input (EOI) after parsing the preceding rule.
@postfix func <! (rule: Parser.Rule)
-> Parser.Rule
{
    return .Termination([rule])
}

@postfix func <! (name: String)
-> Parser.Rule
{
    return .Termination([.RulePromise(name)])
}

@postfix func <! (block: Parser.Action)
-> Parser.Rule
{
    return .Termination([.Computation([block])])
}

/// `rule` <! `action`
/// Asserts EOI after parsing the rule, then returns the action's value.
@infix func <! (rule: Parser.Rule, block: Parser.Action)
-> Parser.Rule
{
    return (.Termination([rule]) &> .Computation([block]))
}

@infix func <! (name: String, block: Parser.Action)
-> Parser.Rule
{
    return (.Termination([.RulePromise(name)]) &> .Computation([block]))
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