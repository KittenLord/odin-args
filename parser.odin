package args

import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:os"

VERBATIM   :: "--verbatim"
DOUBLEDASH :: "--"

DoubleDashBehavior :: enum {
    EnableVerbatim,
    StopParsing,
    Skip,
    Error,
}

Description :: struct {
    short   : string,
    long    : string,
}

get_description_short :: proc (d : Description) -> string {
    return d.short != "" ? d.short : d.long
}

get_description_long :: proc (d : Description) -> string {
    return d.long != "" ? d.long : d.short
}

get_description :: proc (d : Description, detailed : bool) -> string {
    return detailed ? get_description_long(d) : get_description_short(d)
}

PrintFlag :: enum {
    Print,
    Detailed,
    Subcommand,
}

PrintFlags :: bit_set[PrintFlag; u8]

Subcommand :: struct {
    value       : []string,
    description : Description,

    printFlags  : PrintFlags,
}

Parser :: struct {
    // Configuration
    description : Description,
    arguments   : []Argument,
    subcommands : []Subcommand,
    doubledash  : DoubleDashBehavior,

    // Runtime (mostly)
    tokens : [dynamic]Token,
    index : int,
    errors : [dynamic]Error,
    verbatim : bool,

    pos : int,
    subcommand : [dynamic]string,

    success : bool,
    failure : bool,
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



parser_findArgByName :: proc (p : ^Parser, name : string, subcommand : []string = nil) -> ^Argument {
    for &arg in p.arguments {
        if !arg_fitsSubcommand(arg, subcommand) { continue }
        if slice.contains(arg.name, name) { return &arg }
    }

    return nil
}

parser_findArgByStore :: proc (p : ^Parser, store : rawptr, subcommand : []string = nil) -> ^Argument {
    for &arg in p.arguments {
        if !arg_fitsSubcommand(arg, subcommand) { continue }
        if arg.store == store { return &arg }
    }

    return nil
}




parser_pushError :: proc (p : ^Parser, e : Error) {
    append(&p.errors, e)

    p.success = false
    p.failure = true
}

parser_setLastToken :: proc (p : ^Parser, type : TokenType) {
    if len(p.tokens) <= 0 { return }
    p.tokens[len(p.tokens) - 1].type = type
}

parser_lastTokenHasType :: proc (p : ^Parser) -> bool {
    if len(p.tokens) <= 0 { return true }
    return p.tokens[len(p.tokens) - 1].type != nil
}

parser_resetDraw :: proc (p : ^Parser) {
    for &token in p.tokens {
        token.draw = .None
    }
}

parser_findMostSimilarSubcommand :: proc (p : Parser, needle : []string) -> (result : []string, ok : bool = false) {
    length := 0
    candidate : []string

    for s in p.subcommands {
        if slice.equal(s.value, needle) {
            result = s.value
            ok = true
            return
        }

        l := slice.prefix_length(s.value, needle)
        if l > length {
            length = l
            candidate = s.value
        }
    }

    if length != 0 {
        result = candidate
        ok = true
        return
    }

    return
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
        if      s == "true"  || s == "1" || s == "yes" { value = true }
        else if s == "false" || s == "0" || s == "no"  { value = false }
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

    if !verbatim && arg_isSpecialValue(arg^, s) {
        if arg_isList(arg^) {
            append(&arg.array, SpecialValue(s))
        }
        else {
            arg.value = SpecialValue(s)
        }

        arg.provided = true
        ok = true
        return
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
    c.failure = false
    c.success = true

    c.pos = 0
    c.index = 0
    resize(&c.subcommand, 0)
    resize(&c.tokens, 0)
    resize(&c.errors, 0)
    c.verbatim = false

    for &a in c.arguments {
        a.value = {}
        a.provided = false
        resize(&a.array, 0)
        a.beginPos = -1
        a.finalPos = -1
    }
}





parse :: proc (c : ^Parser, strings : []string, skipFirst : bool = true) -> (remainder : []string, ok : bool = false) {
    strings := strings
    if skipFirst {
        _, strings = str_pop(c, strings) or_return
        parser_setLastToken(c, .ProgramName)
    }

    s : string
    next : bool = true

    loop: for true {
        s, strings = str_pop(c, strings) or_break loop
        verbatim := (s == VERBATIM) || c.verbatim

        if s == VERBATIM {
            parser_setLastToken(c, .Verbatim)
        }
        else if str_isArgument(s) {
            parser_setLastToken(c, .Flag)
        }

        if !verbatim && s == DOUBLEDASH {
            parser_setLastToken(c, .DoubleDash)

            switch c.doubledash {
            case .EnableVerbatim:
                c.verbatim = true
            case .StopParsing:
                remainder = strings
                return
            case .Skip:
            case .Error:
                parser_pushError(c, Error_DoubleDashForbidden{ c.index - 1 })
            }

            continue loop
        }

        for sc in c.subcommands {
            if verbatim { break }

            if !slice.has_prefix(sc.value, c.subcommand[:]) { continue }
            index := len(c.subcommand)

            if index >= len(sc.value) || sc.value[index] != s { continue }

            append(&c.subcommand, s)

            parser_setLastToken(c, .Subcommand)

            continue loop
        }

        for &arg in c.arguments {
            if !arg_fitsSubcommand(arg, c.subcommand[:]) { continue }

            positional := arg_isPositionalAt(arg, c.pos)
            named      := str_isArgument(s) && slice.contains(arg.name, s) && !verbatim

            if !positional && !named { continue }

            argPos := c.index - 1
            if verbatim && positional { argPos += 1 }

            if !(verbatim && positional) {
                if arg.beginPos == -1 { arg.beginPos = argPos }
                arg.finalPos = argPos
            }

            if positional {
                c.pos += 1

                if !verbatim {
                    parser_setLastToken(c, .PositionalValue)
                }
            }
            else if named /* && !verbatim */ {

                parser_setLastToken(c, .Flag)

                if !arg_isFlag(arg) {
                    ok : bool
                    s, ok = str_peek(c, strings)

                    if !ok {
                        parser_pushError(c, Error_ArgumentMissingValue{ c.index - 1, &arg })
                        arg.provided = true
                        return
                    }

                    if s != VERBATIM && str_isArgument(s) && !arg_isSpecialValue(arg, s) {
                        // NOTE: we assume that user forgor argument, unless it exactly matches special value
                        parser_pushError(c, Error_DashValueWithoutVerbatim{ c.index, s })
                        arg.provided = true
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
                    arg.provided = true
                    return
                }
            }

            if arg.beginPos == -1 { arg.beginPos = argPos }
            arg.finalPos = argPos

            if !parser_lastTokenHasType(c) { parser_setLastToken(c, .Value) }
            if positional { parser_setLastToken(c, .PositionalValue) }

            _ = parseSingleArgument(c, &arg, s, verbatim)

            // NOTE: even though we might error below, it's better to consider this as provided for better error reporting and help info
            arg.provided = true

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

    when ty == Flag || ty == []Flag {
        (cast(^Flag)arg.store)^ = value.(Value).(Flag)
        return
    }

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




terminate :: proc (c : ^Parser) -> bool {
    validSubcommand := false
    if c.subcommands == nil && len(c.subcommand[:]) == 0 {
        validSubcommand = true
    }

    for sub in c.subcommands {
        if slice.equal(sub.value, c.subcommand[:]) {
            validSubcommand = true
            break
        }
    }

    if !validSubcommand {
        parser_pushError(c, Error_UnrecognizedSubcommand{ c.subcommand[:] })
    }

    for &arg in c.arguments {
        if !arg.required { continue }
        if !arg_fitsSubcommand(arg, c.subcommand[:]) { continue }

        if !arg.provided && !arg_hasDefault(arg) {
            parser_pushError(c, Error_RequiredArgumentMissing{ &arg })
        }

        continue
    }

    if c.failure { return false }


    for arg in c.arguments {
        if arg.store == nil { continue }

        if arg_isFlag(arg) && !arg.provided {
            (cast(^Flag)arg.store)^ = 0
            continue
        }

        if (!arg_isList(arg) && is_none(arg.value)) || (arg_isList(arg) && is_none(arg.default) && !arg.provided) {
            // TODO: this should most probably be moved into assign_ procedures above
            setSingleNil :: proc (ty : Value, store : rawptr, special : bool) {
                if special {
                    switch _ in ty {
                    case bool: (cast(^Maybe(Special(bool)))store)^ = nil
                    case i64: (cast(^Maybe(Special(i64)))store)^ = nil
                    case u64: (cast(^Maybe(Special(u64)))store)^ = nil
                    case f64: (cast(^Maybe(Special(f64)))store)^ = nil
                    case string: (cast(^Maybe(Special(string)))store)^ = nil
                    case Flag, []Flag, []bool, []i64, []u64, []f64, []string: panic("bad")
                    }
                }
                else {
                    switch _ in ty {
                    case bool: (cast(^Maybe(bool))store)^ = nil
                    case i64: (cast(^Maybe(i64))store)^ = nil
                    case u64: (cast(^Maybe(u64))store)^ = nil
                    case f64: (cast(^Maybe(f64))store)^ = nil
                    case string: (cast(^Maybe(string))store)^ = nil
                    case Flag, []Flag, []bool, []i64, []u64, []f64, []string: panic("bad")
                    }
                }
            }

            if arg_isList(arg) {
                (cast(^Maybe([]u8))arg.store)^ = {}
            }
            else if arg_doesAllowSpecialValues(arg) {
                setSingleNil(arg.type, arg.store, true)
                // (cast(^Maybe(Special(u8)))arg.store)^ = {}
            }
            else {
                setSingleNil(arg.type, arg.store, false)
                // (cast(^Maybe(u8))arg.store)^ = {}
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

            case []bool, []i64, []u64, []f64, []string: panic("bad")
            }
        }
    }

    return true
}
