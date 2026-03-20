package args

import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:os"




/*

Features:

# Value (possibly required):
program --value 15

# Alias:
program -v 15

# Flag:
program -f

# Counted flag:
program -f -f -f

# List:
program -v 15 -v 69 -v 420

# Special value:
program -v -

# Default value:
program [-v 15]

# Positional argument:
program file.txt

# Subcommand:
program status

# Stop parsing:
program -- irrelevant args, possibly used for something else by the program

*/

// TODO: it might be useful to set min and max length (possibly unbounded) for a list argument

// TODO: we might want an argument type that allows ONLY special values (which is essentially a string type)

// TODO: --verbatim flag that allows for positional arguments and argument values starting with '-' (including "--")
// (I'm actually not sure if "verbatim" is the right word to use, but I like how it sounds)
// also it should force the value to NOT be a special value, i.e. if we have a string argument with a special value
// "stdout", providing --verbatim stdout will make it a regular string value
VERBATIM :: "--verbatim"












Parser :: struct {
    // Configuration
    arguments : []Argument,
    subcommands : [][]string,

    // Runtime (mostly)
    tokens : [dynamic]Token,
    index : int,
    errors : [dynamic]Error,

    pos : int,
    subcommand : [dynamic]string,
}

TokenDrawType :: enum {
    None,

    Error, 
    Highlighted
}

TokenType :: enum {
    Value,
    PositionalValue,
    Flag,
    Verbatim,
    Subcommand,
    DoubleDash,

    ProgramName,
}

Token :: struct {
    type : TokenType,
    draw : TokenDrawType,
    value : string,
}

parser_pushError :: proc (p : ^Parser, e : Error) {
    append(&p.errors, e)
}

parser_setLastToken :: proc (p : ^Parser, type : TokenType) {
    if len(p.tokens) <= 0 { return }
    p.tokens[len(p.tokens) - 1].type = type
}

parser_lastTokenHasType :: proc (p : ^Parser) -> bool {
    if len(p.tokens) <= 0 { return true }
    return p.tokens[len(p.tokens) - 1].type != nil
}



parseSingleArgumentType :: proc (p : ^Parser, arg : ^Argument, s : string, $ty : typeid) -> (value : ty, ok : bool = false) {
    defer if !ok {
        type := determineType(s)
        if arg_doesAllowSpecialValues(arg^) && is_type(string, type) {
            parser_pushError(p, Error_UnrecognizedSpecialValue{ p.index - 1, arg, s })
        }
        else {
            parser_pushError(p, Error_ArgumentMismatchedType{ p.index - 1, arg, s })
        }
    }

    when ty == bool {
        if      s == "true"  || s == "0" { value = true }
        else if s == "false" || s == "0" { value = false }
        else { return }
        ok = true
        return
    }
    when ty == i64 {
        value, ok = strconv.parse_i64_maybe_prefixed(s)
        return
    }
    when ty == u64 {
        value, ok = strconv.parse_u64_maybe_prefixed(s)
        return
    }
    when ty == f64 {
        value, ok = strconv.parse_f64(s)
        return
    }
    when ty == string {
        value = s
        ok = true
        return
    }

    return
}

parseSingleArgument :: proc (p : ^Parser, arg : ^Argument, s : string, verbatim : bool) -> (ok : bool = false) {
    if !arg_isList(arg^) && arg.provided {
        parser_pushError(p, Error_ArgumentRepeat{ p.index - 1, arg })
        return
    }

    for sv in arg.special {
        if verbatim { break }

        if sv == s {
            v := SpecialValue(s)

            if arg_isList(arg^) {
                append(&arg.array, v)
            }
            else {
                arg.value = v
            }

            arg.provided = true
            ok = true
            return
        }
    }

    switch _ in arg.type {
    case Flag, []Flag:
        f, _ := arg_getValueOrAssign(arg, Flag, 0)
        f += 1
        arg.value = mkValue(Flag, f)
    case bool:      arg.value = mkValue(bool, parseSingleArgumentType(p, arg, s, bool) or_return)
    case i64:       arg.value = mkValue(i64, parseSingleArgumentType(p, arg, s, i64) or_return)
    case u64:       arg.value = mkValue(u64, parseSingleArgumentType(p, arg, s, u64) or_return)
    case f64:       arg.value = mkValue(f64, parseSingleArgumentType(p, arg, s, f64) or_return)
    case string:    arg.value = mkValue(string, parseSingleArgumentType(p, arg, s, string) or_return)
    case []bool:    append(&arg.array, mkValueS(bool, parseSingleArgumentType(p, arg, s, bool) or_return))
    case []i64:     append(&arg.array, mkValueS(i64, parseSingleArgumentType(p, arg, s, i64) or_return))
    case []u64:     append(&arg.array, mkValueS(u64, parseSingleArgumentType(p, arg, s, u64) or_return))
    case []f64:     append(&arg.array, mkValueS(f64, parseSingleArgumentType(p, arg, s, f64) or_return))
    case []string:  append(&arg.array, mkValueS(string, parseSingleArgumentType(p, arg, s, string) or_return))
    case: panic("bad")
    }

    arg.provided = true

    ok = true
    return
}




verify_arg :: proc (arg : Argument) -> bool {
    if arg.required && is_just(arg.default) { return false }
    if is_none(arg.position) && len(arg.name) == 0 { return false }

    // TODO: compare type of arg.type and arg.default

    return true
}

verify :: proc (c : ^Parser) -> bool {
    for arg in c.arguments {
        verify_arg(arg) or_return
    }

    return true
}

reset :: proc (c : ^Parser) {
    c.pos = 0
    resize(&c.subcommand, 0)

    for &a in c.arguments {
        a.value = {}
        a.provided = false
        resize(&a.array, 0)
        a.beginPos = -1
        a.finalPos = -1
    }
}

// TODO: actual errors instead of a boolean (since this is actually user-facing)
parse :: proc (c : ^Parser, strings : []string, skipFirst : bool = true) -> (ok : bool = false) {
    strings := strings
    if skipFirst {
        _, strings = str_pop(c, strings) or_return
        parser_setLastToken(c, .ProgramName)
    }

    s : string
    next : bool = true

    loop: for true {
        s, strings = str_pop(c, strings) or_break loop
        verbatim := s == VERBATIM

        if s == VERBATIM {
            parser_setLastToken(c, .Verbatim)
        }
        else if str_isArgument(s) {
            parser_setLastToken(c, .Flag)
        }

        for sc in c.subcommands {
            if verbatim { break }

            if !slice.has_prefix(sc, c.subcommand[:]) { continue }
            index := len(c.subcommand)

            if index >= len(sc) || sc[index] != s { continue }

            append(&c.subcommand, s)

            parser_setLastToken(c, .Subcommand)

            continue loop
        }

        for &arg in c.arguments {
            if !slice.has_prefix(c.subcommand[:], arg.sub) { continue }

            positional := arg_isPositionalAt(arg, c.pos)
            named      := str_isArgument(s) && slice.contains(arg.name, s) && !verbatim

            if !positional && !named { continue }

            if arg.beginPos == -1 { arg.beginPos = c.pos }
            arg.finalPos = c.pos

            if positional {
                c.pos += 1

                if !verbatim {
                    parser_setLastToken(c, .PositionalValue)
                }
            }
            else if named /* && !verbatim */ {
                parser_setLastToken(c, .Flag)

                if !arg_isType(arg, Flag) {
                    ok : bool
                    s, ok = str_peek(c, strings)

                    if !ok {
                        parser_pushError(c, Error_ArgumentMissingValue{ c.index - 1, &arg })
                        return
                    }

                    if s != VERBATIM && str_isArgument(s) {
                        // NOTE: we assume that user forgor argument
                        parser_pushError(c, Error_DashValueWithoutVerbatim{ c.index - 1, s })
                        continue loop
                    }

                    s, strings, ok = str_pop(c, strings)

                    verbatim = (s == VERBATIM)

                    if s == VERBATIM {
                        parser_setLastToken(c, .Verbatim)
                    }
                }
            }

            if verbatim {
                ok : bool
                s, strings, ok = str_pop(c, strings)
                if !ok {
                    parser_pushError(c, Error_VerbatimWithoutValue{ c.index - 1 })
                    return
                }
            }

            parser_setLastToken(c, .Value)
            if positional { parser_setLastToken(c, .PositionalValue) }

            _ = parseSingleArgument(c, &arg, s, verbatim)

            continue loop
        }



        // Couldn't find fitting argument/subcommand
        if str_isArgument(s) && !verbatim {
            parser_pushError(c, Error_UnrecognizedArgument{ c.index - 1, s })

            s = str_peek(c, strings) or_return
            if s == VERBATIM {
                _, strings = str_pop(c, strings) or_return
                parser_setLastToken(c, .Verbatim)
                _, strings = str_pop(c, strings) or_return
                parser_setLastToken(c, .Value)
            }
            else if str_isArgument(s) {

            }
            else {
                _, strings = str_pop(c, strings) or_return
                parser_setLastToken(c, .Value)
            }
        }
        else if verbatim {
            n, ok := str_peek(c, strings)
            if ok {
                s, strings = str_pop(c, strings) or_return
                parser_setLastToken(c, .PositionalValue)
                parser_pushError(c, Error_UnexpectedPositionalArgument{ c.index - 1, s })
            }
            else {
                // parser_pushError(c, Error_UnexpectedPositionalArgument{ c.index - 1, s })
                parser_pushError(c, Error_VerbatimWithoutValue{ c.index - 1 })
            }
        }
        else {
            // TODO: there should be some heuristic to determine whether the user
            // mistakenly added a positional argument, or used a non-existent subcommand.
            // In fact the latter is likely much more common

            parser_pushError(c, Error_UnexpectedPositionalArgument{ c.index - 1, s })
            parser_setLastToken(c, .PositionalValue)
        }
    }
    
    ok = (len(c.errors) == 0)
    return
}

assign :: proc (c : ^Parser) -> bool {
    assignMaybe :: proc (store : $pty/^$ty, value : $vty, maybe : bool) {
        if maybe {
            store := cast(^Maybe(ty))store
            store ^= value
        }
        else {
            store ^= value
        }
    }

    assignSingle :: proc (arg : Argument, $ty : typeid) {
        value := arg.value.?

        if arg_doesAllowSpecialValues(arg) {
            store := cast(^Special(ty))arg.store

            switch v in value {
            case SpecialValue:  assignMaybe(store, v, arg_isOptional(arg))
            case Value:         assignMaybe(store, v.(ty), arg_isOptional(arg))
            }
        }
        else {
            store := cast(^ty)arg.store
            assignMaybe(store, value.(Value).(ty), arg_isOptional(arg))
        }
    }

    assignList :: proc (arg : Argument, $ty : typeid) {
        src := arg.provided ? arg.array[:] : cast([]Special(Value))arg.default.?.(DefaultList) // NOTE: if it is absent we would have continued in the main loop

        dumpValue :: proc (arg : Argument, src : []Special(Value), $ty : typeid) {
            result := make([]ty, len(src))
            for &v, i in result {
                v = src[i].(Value).(ty)
            }

            assignMaybe(cast(^[]ty)arg.store, result, arg_isOptional(arg))
            return
        }

        dumpSpecial :: proc (arg : Argument, src : []Special(Value), $ty : typeid) {
            result := make([]Special(ty), len(src))
            for &v, i in result {
                switch s in src[i] {
                case SpecialValue: v = s
                case Value:        v = s.(ty)
                }
            }

            assignMaybe(cast(^[]Special(ty))arg.store, result, arg_isOptional(arg))
        }

        if arg_doesAllowSpecialValues(arg) { dumpSpecial(arg, src, ty) }
        else                               { dumpValue(arg, src, ty) }
    }

    // TODO: Check for errors that can only be detected at the very end of parsing, such as a required argument missing,
    // invalid (unfinished) subcommand... Actually that's it probably

    for arg in c.arguments {
        if arg.store == nil { continue }
        if (!arg_isList(arg) && is_none(arg.value)) || (arg_isList(arg) && is_none(arg.default) && !arg.provided) {
            if arg_isList(arg) {
                (cast(^Maybe([]u8))arg.store)^ = {}
            }
            else if arg_doesAllowSpecialValues(arg) {
                (cast(^Maybe(Special(u8)))arg.store)^ = {}
            }
            else {
                (cast(^Maybe(u8))arg.store)^ = {}
            }

            continue
        }

        if arg_isList(arg, false) {
            switch _ in arg.type {
            case []bool:        assignList(arg, bool)
            case []i64:         assignList(arg, i64)
            case []u64:         assignList(arg, u64)
            case []f64:         assignList(arg, f64)
            case []string:      assignList(arg, string)
            case Flag, []Flag, bool, i64, u64, f64, string: panic("bad")
            }
        }
        else {
            switch _ in arg.type {
            case Flag, []Flag:  assignSingle(arg, Flag)
            case bool:          assignSingle(arg, bool)
            case i64:           assignSingle(arg, i64)
            case u64:           assignSingle(arg, u64)
            case f64:           assignSingle(arg, f64)
            case string:        assignSingle(arg, string)

            // case:
            case []bool, []i64, []u64, []f64, []string: panic("bad") // HACK: for some reason `case:` doesn't work? compiler bug?
            }
        }
    }

    return true
}



main :: proc () {
    hello : Maybe(u64)
    l : []u64

    parser := Parser{
        arguments = {
            { type = u64{},   name = { "--hello" }, required = true, store = &hello }, 
            { type = Flag{},  name = { "--help" } }, 
            { type = []u64{}, name = { "-l" }, store = &l, default = Default(DefaultList({ Value(u64(1)), Value(u64(2)), Value(u64(3)) })) },
        }
    }

    reset(&parser)
    ok := parse(&parser, { "./program", "--verbatim", "5" })
    fmt.println(ok)
    fmt.println(parser.errors)
    assign(&parser)


    fmt.println(l)
    fmt.println(parser.tokens[:])

    printTokens(os.to_writer(os.stdout), parser.tokens[:])
}
