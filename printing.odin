package args

import "core:fmt"
import "core:io"

COLOR_VERBATIM :: "\e[1;90m"
COLOR_DOUBLEDASH :: "\e[1;90m"
COLOR_PROGRAMNAME :: "\e[1;90m"
COLOR_VALUE :: "\e[1;96m"
COLOR_POSITIONALVALUE :: "\e[1;94m"
COLOR_FLAG :: "\e[0m"
COLOR_SUBCOMMAND :: "\e[0m"

COLOR_ERROR :: "\e[1;4;31m"
COLOR_HIGHLIGHTED :: "\e[1;4;33m"

COLOR_RESET :: "\e[0m"

printToken :: proc (w : io.Stream, token : Token) {
    color := ""
    quote := false

    switch token.type {
    case .Value:                color = COLOR_VALUE;            quote = is_type(string, determineType(token.value))
    case .PositionalValue:      color = COLOR_POSITIONALVALUE;  quote = is_type(string, determineType(token.value))
    case .Flag:                 color = COLOR_FLAG
    case .Verbatim:             color = COLOR_VERBATIM
    case .Subcommand:           color = COLOR_SUBCOMMAND
    case .DoubleDash:           color = COLOR_DOUBLEDASH
    case .ProgramName:          color = COLOR_PROGRAMNAME
    }

    switch token.draw {
    case .None:
    case .Error:                color = COLOR_ERROR
    case .Highlighted:          color = COLOR_HIGHLIGHTED
    }

    quoteS := quote ? "\"" : ""
    fmt.wprintf(w, "%v%v%v%v" + COLOR_RESET, color, quoteS, token.value, quoteS)
}

printTokens :: proc (w : io.Stream, tokens : []Token) {
    for token, i in tokens {
        if i != 0 { io.write_rune(w, ' ') }
        printToken(w, token)
    }
}

printType :: proc (w : io.Stream, t : Value) {
    switch _ in t {
    case Flag:          io.write_string(w, "flag")
    case u64:           io.write_string(w, "natural number")
    case i64:           io.write_string(w, "whole number")
    case f64:           io.write_string(w, "real number")
    case bool:          io.write_string(w, "boolean value")
    case string:        io.write_string(w, "string")

    case []Flag:        io.write_string(w, "repeating flag")
    case []u64:         io.write_string(w, "list of natural numbers")
    case []i64:         io.write_string(w, "list of whole numbers")
    case []f64:         io.write_string(w, "list of real numbers")
    case []bool:        io.write_string(w, "list of boolean values")
    case []string:      io.write_string(w, "list of strings")

    case: panic("bad")
    }
}

printArgType :: proc (w : io.Stream, arg : Argument) {
    printType(w, arg.type)
    if arg_doesAllowSpecialValues(arg) {
        fmt.wprintf(w, " or %v", arg.special)
    }
}

printArgName :: proc (w : io.Stream, arg : Argument) {
    if len(arg.name) != 0 {
        io.write_string(w, arg.name[0])
    }
    else {
        fmt.wprintf(w, "<%v>", arg.position)
    }
}

printSubcommand :: proc (w : io.Stream, sub : []string) {
    for s, i in sub {
        if i != 0 { fmt.wprint(w, " ") }
        fmt.wprint(w, s)
    }
}


// TODO: these should be more modular (i.e. little to no formatting assumed for the most part)
printError :: proc (w : io.Stream, p : ^Parser, error : Error) {
    defer parser_resetDraw(p)

    switch e in error {
    case Error_UnrecognizedArgument:
        fmt.wprintfln(w, "ERROR: Unrecognized argument \"%v\"", e.argument)

        p.tokens[e.pos].draw = .Error

        printTokens(w, p.tokens[:])
    case Error_RequiredArgumentMissing:
        fmt.wprint(w, "ERROR: Required argument \"")
        printArgName(w, e.argument^)
        fmt.wprint(w, "\" has not been provided a value\n")

        fmt.wprintf(w, "\tExpected: ")
            printArgType(w, e.argument^)
    case Error_ArgumentRepeat:
        fmt.wprint(w, "ERROR: Argument \"")
        printArgName(w, e.argument^)
        fmt.wprint(w, "\" is repeated multiple times\n")

        p.tokens[e.pos].draw = .Error
        p.tokens[e.pos - 1].draw = .Error
        p.tokens[e.argument.beginPos].draw = .Highlighted
        
        printTokens(w, p.tokens[:])
    case Error_ArgumentMismatchedType:
        fmt.wprint(w, "ERROR: Argument \"")
        printArgName(w, e.argument^)
        fmt.wprint(w, "\" has been provided an invalid value\n")

        fmt.wprintf(w, "\tExpected: ")
            printArgType(w, e.argument^)
            io.write_rune(w, '\n')
        fmt.wprintf(w, "\tReceived: ")
            printType(w, determineType(e.receivedValue))
            io.write_rune(w, '\n')
        
        p.tokens[e.pos].draw = .Error

        printTokens(w, p.tokens[:])
    case Error_UnrecognizedSubcommand:
        fmt.wprint(w, "ERROR: Unrecognized subcommand \"")
        printSubcommand(w, e.subcommand)
        fmt.wprint(w, "\"\n")

        s, ok := parser_findMostSimilarSubcommand(p^, p.subcommand[:])
        if ok {
            fmt.wprint(w, "\tClosest match: \"")
            printSubcommand(w, s)
            fmt.wprint(w, "\"\n")
        }

        i := 0
        for &t in p.tokens {
            if t.type != .Subcommand { continue }
            isMatch := ok && i < len(s)

            if isMatch { t.draw = .Highlighted }
            else       { t.draw = .Error }
        }

        printTokens(w, p.tokens[:])
    case Error_UnrecognizedSpecialValue:
        fmt.wprint(w, "ERROR: Argument \"")
        printArgName(w, e.argument^)
        fmt.wprintfln(w, "\" has been provided an unrecognized special value \"%v\"", e.specialValue)

        fmt.wprintf(w, "\tExpected: ")
            printArgType(w, e.argument^)
            io.write_rune(w, '\n')
        fmt.wprintf(w, "\tReceived: ")
            printType(w, determineType(e.specialValue))
            io.write_rune(w, '\n')

        p.tokens[e.pos].draw = .Error

        printTokens(w, p.tokens[:])
    case Error_DashValueWithoutVerbatim:
        fmt.wprintfln(w, "ERROR: Values beginning with '-' must be escaped by using \"--verbatim\" before them")

        p.tokens[e.pos].draw = .Error
        p.tokens[e.pos - 1].draw = .Highlighted

        printTokens(w, p.tokens[:])
    case Error_ArgumentMissingValue:
        fmt.wprint(w, "ERROR: Argument \"")
        printArgName(w, e.argument^)
        fmt.wprint(w, "\" has not been provided a value\n")

        p.tokens[e.pos].draw = .Highlighted

        printTokens(w, p.tokens[:])
    case Error_UnexpectedPositionalArgument:
        fmt.wprintfln(w, "ERROR: Unexpected positional argument \"%v\"", e.value)

        p.tokens[e.pos].draw = .Error

        printTokens(w, p.tokens[:])
    case Error_VerbatimWithoutValue:
        fmt.wprintfln(w, "ERROR: \"--verbatim\" must be followed by a value")

        p.tokens[e.pos].draw = .Highlighted

        printTokens(w, p.tokens[:])

    case: panic("bad")
    }

    return
}

printErrors :: proc (w : io.Stream, p : ^Parser) {
    for error, i in p.errors {
        if i != 0 {
            io.write_string(w, "\n\n")
        }
        printError(w, p, error)
    }
}
