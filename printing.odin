package args

import "core:fmt"
import "core:io"
import str "core:strings"
import "core:slice"

COLOR_VERBATIM          :: "\e[90m"
COLOR_DOUBLEDASH        :: "\e[1;90m"
COLOR_PROGRAMNAME       :: "\e[90m"
COLOR_VALUE             :: "\e[96m"
COLOR_POSITIONALVALUE   :: "\e[1;94m"
COLOR_FLAG              :: "\e[0m"
COLOR_SUBCOMMAND        :: "\e[1;35m"

COLOR_ERROR             :: "\e[1;4;31m"
COLOR_HIGHLIGHTED       :: "\e[1;4;33m"

COLOR_HEADER            :: "\e[1;4m"

COLOR_RESET             :: "\e[0m"

INDENT                  :: 4

print_value :: proc (w : io.Stream, svalue : Special(Value)) {
    switch sv in svalue {
    case SpecialValue:
        fmt.wprintf(w, "$%v", sv)
    case Value:
        switch v in sv {
        case Flag:      fmt.wprintf(w, "%v", v)
        case bool:      fmt.wprintf(w, "%v", v)
        case i64:       fmt.wprintf(w, "%v", v)
        case u64:       fmt.wprintf(w, "%v", v)
        case f64:       fmt.wprintf(w, "%v", v)
        case string:    fmt.wprintf(w, "%v", v)

        case []Flag, []bool, []i64, []u64, []f64, []string:
        }
    }
}

print_default :: proc (w : io.Stream, default : Default) {
    switch d in default {
    case DefaultValue:
        print_value(w, cast(Special(Value))d)
    case DefaultList:
        for v, i in d {
            if i != 0 { fmt.wprint(w, ", ") }
            print_value(w, v)
        }
    }
}

print_token :: proc (w : io.Stream, token : Token) {
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

print_tokens :: proc (w : io.Stream, tokens : []Token) {
    for token, i in tokens {
        if i != 0 { io.write_rune(w, ' ') }
        print_token(w, token)
    }
}

print_type :: proc (w : io.Stream, t : Value) {
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

print_argType :: proc (w : io.Stream, arg : Argument) {
    print_type(w, arg.type)
    if arg_doesAllowSpecialValues(arg) {
        fmt.wprint(w, " ")
        for special in arg.special {
            fmt.wprintf(w, "| $%v", special)
        }
    }
}

print_argName :: proc (w : io.Stream, arg : Argument) {
    if len(arg.name) != 0 {
        io.write_string(w, arg.name[0])
    }
    else {
        fmt.wprintf(w, "<%v>", arg.position)
    }
}

print_argFullId :: proc (w : io.Stream, arg : Argument) {
    if len(arg.name) != 0 {
        fmt.wprint(w, arg.name[0])

        if len(arg.name) > 1 {
            fmt.wprint(w, " (")

            for s, i in arg.name {
                if i == 0 { continue }
                if i != 1 { fmt.wprint(w, ", ") }

                fmt.wprint(w, arg.name[i])
            }

            fmt.wprint(w, ")")
        }
    }
    else {
        fmt.wprintf(w, "<%v>", arg.position)
    }
}

print_subcommand :: proc (w : io.Stream, sub : []string) {
    if len(sub) == 0 {
        fmt.wprint(w, "-")
        return
    }

    for s, i in sub {
        if i != 0 { fmt.wprint(w, " ") }
        fmt.wprint(w, s)
    }
}

print_subcommand_length :: proc (sub : []string) -> (r : int = 0) {
    if len(sub) == 0 { return 1 }

    for s, i in sub {
        if i != 0 { r += 1 }
        r += len(s)
    }

    return
}

// NOTE: actually nah fuck it, this won't be modular, if someone
// needs customization they will write their own printer

print_error :: proc (w : io.Stream, p : ^Parser, error : Error) {
    defer parser_resetDraw(p)

    printTokens := true

    switch e in error {
    case Error_UnrecognizedArgument:
        fmt.wprintfln(w, "ERROR: Unrecognized argument \"%v\"", e.argument)

        p.tokens[e.pos].draw = .Error
    case Error_RequiredArgumentMissing:
        fmt.wprint(w, "ERROR: Required argument \"")
        print_argName(w, e.argument^)
        fmt.wprint(w, "\" has not been provided a value\n")

        fmt.wprintf(w, "\tExpected: ")
            print_argType(w, e.argument^)

        printTokens = false
    case Error_ArgumentRepeat:
        fmt.wprint(w, "ERROR: Argument \"")
        print_argName(w, e.argument^)
        fmt.wprint(w, "\" is repeated multiple times\n")

        p.tokens[e.pos].draw = .Error
        p.tokens[e.pos - 1].draw = .Error
        p.tokens[e.argument.beginPos].draw = .Highlighted
    case Error_ArgumentMismatchedType:
        fmt.wprint(w, "ERROR: Argument \"")
        print_argName(w, e.argument^)
        fmt.wprint(w, "\" has been provided an invalid value\n")

        fmt.wprintf(w, "\tExpected: ")
            print_argType(w, e.argument^)
            io.write_rune(w, '\n')
        fmt.wprintf(w, "\tReceived: ")
            print_type(w, determineType(e.receivedValue))
            io.write_rune(w, '\n')
        
        p.tokens[e.pos].draw = .Error
    case Error_UnrecognizedSubcommand:
        fmt.wprint(w, "ERROR: Unrecognized subcommand [")
        print_subcommand(w, e.subcommand)
        fmt.wprint(w, "]\n")

        s, ok := parser_findMostSimilarSubcommand(p^, p.subcommand[:])
        if ok {
            fmt.wprint(w, "\tClosest match: [")
            print_subcommand(w, s)
            fmt.wprint(w, "]\n")
        }

        i := 0
        for &t in p.tokens {
            if t.type != .Subcommand { continue }
            isMatch := ok && i < len(s)
            i += 1

            if isMatch { t.draw = .Highlighted }
            else       { t.draw = .Error }
        }
    case Error_UnrecognizedSpecialValue:
        fmt.wprint(w, "ERROR: Argument \"")
        print_argName(w, e.argument^)
        fmt.wprintfln(w, "\" has been provided an unrecognized special value \"%v\"", e.specialValue)

        fmt.wprintf(w, "\tExpected: ")
            print_argType(w, e.argument^)
            io.write_rune(w, '\n')
        fmt.wprintf(w, "\tReceived: ")
            print_type(w, determineType(e.specialValue))
            io.write_rune(w, '\n')

        p.tokens[e.pos].draw = .Error
    case Error_DashValueWithoutVerbatim:
        fmt.wprintfln(w, "ERROR: Values beginning with '-' must be escaped by using \"--verbatim\" before them")

        p.tokens[e.pos].draw = .Error
        p.tokens[e.pos - 1].draw = .Highlighted
    case Error_ArgumentMissingValue:
        fmt.wprint(w, "ERROR: Argument \"")
        print_argName(w, e.argument^)
        fmt.wprint(w, "\" has not been provided a value\n")

        p.tokens[e.pos].draw = .Highlighted
    case Error_UnexpectedPositionalArgument:
        fmt.wprintfln(w, "ERROR: Unexpected positional argument \"%v\"", e.value)

        p.tokens[e.pos].draw = .Error
    case Error_VerbatimWithoutValue:
        fmt.wprintfln(w, "ERROR: \"--verbatim\" must be followed by a value")

        p.tokens[e.pos].draw = .Highlighted
    case Error_DoubleDashForbidden:
        fmt.wprintfln(w, "ERROR: Doubledash \"--\" usage is forbidden")

        p.tokens[e.pos].draw = .Error
    case: panic("bad")
    }

    if printTokens {
        print_tokens(w, p.tokens[:])
    }

    return
}

print_errors :: proc (w : io.Stream, p : ^Parser) {
    for error, i in p.errors {
        if i != 0 { io.write_string(w, "\n\n") }
        print_error(w, p, error)
    }
    fmt.wprint(w, "\n")
}


/*

help text drafting


// NOTE: is it useful to make text fit nicely within terminal width?

// NOTE: would it be better to always display all information, or have
// a "--help" vs "--help --help" distinction for less clutter?


# ./program --help

A program that does hopefully useful things

Subcommands:
    -               - aasdasdasda
    sub test        - short explanation
    sub amogus      - short explanation
    build           - short explanation
    create          - short explanation
    list things     - short explanation
    list stuff      - short explanation

Argument --version (-v):
    Write program's version and other useful
    information to stdout and terminate

Argument --help (-h):
    Write information about every used subcommand
    and argument to stdout and terminate. Adding
    the flag twice will display more information
    about the arguments



# ./program sub --hello 5 -l 3 --help --help

Subcommand [sub]:
    Perform an action that does an action that
    does an action that does a useful action

    Invoke "./program sub --help" for more info

Argument --hello (-h, -hl):
    A very detailed explanation of what this
    argument does

    Type: natural number | $default
    REQUIRED

Argument --list (-l):
    Another incredibly detailed explanation
    of this argument's function

    Type: list of whole numbers
    Default: 1, 2, 3



# ./program sub --help

Subcommand [sub]:
    Perform an action that does an action that
    does an action that does a useful action.

Related subcommands:
    sub test        - short explanation
    sub amogus      - short explanation

Argument --hello (-h, -hl):
    blah blah blah

Argument --list (-l):
    blah blah blah

Argument --idk:
    blah blah blah

*/

print_ntimes :: proc (w : io.Stream, s : string, n : int) {
    for i in 0 ..< n {
        fmt.wprint(w, s)
    }
}

printhelp_text :: proc (w : io.Stream, text : string, offset : int) {
    print_ntimes(w, " ", offset)
    fmt.wprint(w, text)
}

// TODO: descriptions should be nicely aligned, but i cant be bothered to do this shit right now

// printhelp_textBlock :: proc (w : io.Stream, text : string, width : int, offset : int, firstOffset : int) {
//     width := width - offset
//     text := text
//     remaining := width
//
//     print_ntimes(w, " ", firstOffset)
//
//     for true {
//         word, ok := str.split_iterator(&text, " ")
//         if !ok { break }
//
//         if len(word) <= remaining {
//             fmt.wprint(w, word)
//             remaining -= len(word)
//
//             if remaining >= 1 {
//                 fmt.wprint(w, " ")
//                 remaining -= 1
//             }
//         }
//
//         if remaining <= 0 {
//             fmt.wprint(w, "\n")
//             print_ntimes(w, " ", offset)
//         }
//     }
// }

printhelp_argument :: proc (w : io.Stream, arg : Argument, detailed : bool, subcommand : bool) {
    fmt.wprint(w, "\n" + COLOR_HEADER + "Argument" + COLOR_RESET + " ")
    if subcommand {
        fmt.wprint(w, "[")
        print_subcommand(w, arg.sub)
        fmt.wprint(w, "]::")
    }
    print_argFullId(w, arg)
    fmt.wprint(w, ":\n")

    if len(arg.description.short) != 0 {
        print_ntimes(w, " ", INDENT)
        fmt.wprint(w, arg.description.short)
        fmt.wprint(w, "\n")

        if detailed {
            fmt.wprint(w, "\n")
        }
    }

    if detailed {
        if true {
            print_ntimes(w, " ", INDENT)
            fmt.wprint(w, "Type:    ")
            print_argType(w, arg)
            fmt.wprint(w, "\n")
        }

        if is_just(arg.default) {
            print_ntimes(w, " ", INDENT)
            fmt.wprint(w, "Default: ")
            print_default(w, arg.default.?)
            fmt.wprint(w, "\n")
        }

        if arg.required {
            print_ntimes(w, " ", INDENT)
            fmt.wprint(w, "Required")
            fmt.wprint(w, "\n")
        }
    }
}

printhelp_arguments :: proc (w : io.Stream, p : Parser) {
    for arg in p.arguments {
        if .Print not_in arg.printFlags { continue }
        printhelp_argument(w, arg, .Detailed in arg.printFlags, .Subcommand in arg.printFlags)
    }
}

printhelp_argMarkBrief :: proc (p : Parser) {
    for &arg in p.arguments {
        arg.printFlags = arg.briefFlags
    }
}

printhelp_argMarkSubcommand :: proc (p : Parser, sub : []string, flags : PrintFlags) {
    for &arg in p.arguments {
        if !slice.equal(sub, arg.sub) { continue }
        arg.printFlags = flags
    }
}

printhelp_argMarkAll :: proc (p : Parser, flags : PrintFlags) {
    for &arg in p.arguments {
        arg.printFlags = flags
    }
}

printhelp_argOverride :: proc (p : Parser) {
    for &arg in p.arguments {
        for flag in PrintFlag {
            if flag in arg.overmFlags {
                if flag in arg.overvFlags {
                    arg.printFlags -= { flag }
                }
                else {
                    arg.printFlags += { flag }
                }
                // NOTE: ????
                // arg.printFlags[flag] = arg.overvFlags[flag]
            }
        }
    }
}

printhelp_subMarkAll :: proc (p : Parser, flags : PrintFlags) {
    for &sub in p.subcommands {
        sub.printFlags = flags
    }
}

printhelp_subcommand :: proc (w : io.Stream, sub : Subcommand, detailed : bool, width : int) {
    fmt.wprint(w, "\nSubcommand [")
    print_subcommand(w, sub.value)
    fmt.wprint(w, "]\n")

    desc := get_description(sub.description, detailed)
    if desc != "" {
        fmt.wprint(w, desc)
        fmt.wprint(w, "\n")
    }
}

printhelp_brief_subcommands :: proc (w : io.Stream, p : Parser, detailed : bool, width : int) {
    fmt.wprint(w, "\n" + COLOR_HEADER + "Subcommands" + COLOR_RESET + ":\n")

    descriptionOffset := 0
    for sub in p.subcommands {
        l := print_subcommand_length(sub.value)
        if l > descriptionOffset { descriptionOffset = l }
    }

    for sub, i in p.subcommands {
        if .Print not_in sub.printFlags { continue }
        desc := get_description(sub.description, detailed)

        print_ntimes(w, " ", INDENT)
        print_subcommand(w, sub.value)

        if desc != "" {
            l := print_subcommand_length(sub.value)
            print_ntimes(w, " ", descriptionOffset - l)
            fmt.wprint(w, " - ")
            printhelp_text(w, sub.description.short, 0)
        }

        fmt.wprint(w, "\n")
    }
}

printhelp_brief :: proc (w : io.Stream, p : Parser, detailed : bool, width : int) {
    printhelp_text(w, get_description(p.description, detailed), 0)
    fmt.wprint(w, "\n")

    printhelp_subMarkAll(p, { .Print })
    for s in p.subcommands {
        if .Print in s.printFlags {
            printhelp_brief_subcommands(w, p, detailed, width)
            break
        }
    }

    printhelp_argMarkBrief(p)
    printhelp_arguments(w, p)
    printhelp_argMarkAll(p, {})
}
