/*  ————————————————————————————————————————————————————————————————————————  *
*
*      ArrayLexer.swift
*      ~~~~~~~~~~~~~~~~
*
*      Model class for a token source
*
*      Project:            ComposedParsing
*
*      File encoding:      UTF-8
*
*      2014·06·26          Created by Ulrich Singer
*/

import Foundation


/// A primitive token source that consumes a fixed array.
class ArrayLexer : Lexer
{
    var _tokens: [Token]
    var _index: Int
    var _limit: Int

    init (tokens: [Token])
    {
        _tokens = tokens
        _index  = tokens.startIndex
        _limit  = tokens.endIndex
    }
    
    func reset ()
    {
        _index  = _tokens.startIndex
    }
    
    /// <Lexer> Conformity

    func next () -> Token?
    {
        if _index < _limit
        {
            let token = _tokens[_index]
            ++_index

            return token
        }

        return nil
    }

    func tell () -> Int
    {
        return _index
    }

    func seek (index: Int)
    {
        _index = index
    }

    func done () -> Bool
    {
        return _index >= _limit
    }

}   // class ArrayLexer


/* ~ ArrayLexer.swift ~ */