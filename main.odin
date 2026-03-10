package args

import "core:fmt"
import "core:slice"
import "core:strconv"




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


Flag :: distinct u64

ArgumentValue :: union {
    Flag,   []Flag,
    bool,   []bool,
    i64,    []i64,
    u64,    []u64,
    f64,    []f64,
    string, []string,
}

SpecialValue :: distinct string

ArgumentSpecialValue :: union($ty : typeid) {
    ty,
    SpecialValue,
}

Argument :: struct {
    // Never changing
    type : ArgumentValue, // NOTE: This should never ever be changed after initializing
    name : []string,
    position : Maybe(int),
    required : bool,
    allowedSpecialValues : []string,
    default : Maybe(ArgumentSpecialValue(ArgumentValue)),
    sub : []string,

    store : rawptr,


    // Reset per distinct parse
    provided : bool, // NOTE: false if default
    value : Maybe(ArgumentSpecialValue(ArgumentValue)),
    array : [dynamic]ArgumentSpecialValue(ArgumentValue),
}

Parser :: struct {
    arguments : []Argument,
    subcommands : [][]string,

    pos : int,
    subcommand : [dynamic]string,
}

take_string :: proc (strings : []string) -> (s : string, rest : []string, ok : bool = false) {
    if len(strings) == 0 { return }
    return strings[0], strings[1:], true
}

is_just :: proc (v : Maybe($ty)) -> bool {
    _, ok := v.?
    return ok
}

is_none :: proc (v : Maybe($ty)) -> bool {
    _, ok := v.?
    return !ok
}

getValue :: proc (arg : ^Argument, $ty : typeid) -> (ty, bool) {
    // NOTE: Assuming called already typechecked
    if is_just(arg.value) { return arg.value.(ty), true }
    return {}, false
}

mkValue :: proc ($ty : typeid, value : ty) -> Maybe(ArgumentSpecialValue(ArgumentValue)) {
    av : ArgumentValue = value
    asv : ArgumentSpecialValue(ArgumentValue) = av
    masv : Maybe(ArgumentSpecialValue(ArgumentValue)) = asv
    return masv
}

mkValueS :: proc ($ty : typeid, value : ty) -> ArgumentSpecialValue(ArgumentValue) {
    av : ArgumentValue = value
    asv : ArgumentSpecialValue(ArgumentValue) = av
    return asv
}

getValueOrAssign :: proc (arg : ^Argument, $ty : typeid, value : ty) -> (ty, bool) {
    if is_just(arg.value) { return arg.value.?.(ArgumentValue).(ty), true }
    else {
        arg.value = mkValue(ty, value)
        return value, false
    }
}

argIsList :: proc (arg : Argument) -> bool {
    switch _ in arg.type {
    case Flag: return false
    case []Flag: return true
    case bool: return false
    case []bool: return true
    case i64: return false
    case []i64: return true
    case u64: return false
    case []u64: return true
    case f64: return false
    case []f64: return true
    case string: return false
    case []string: return true
    case: panic("bad")
    }
}

isPositionalAt :: proc (pos : int, arg : Argument) -> (ok : bool = false) {
    v := arg.position.? or_return
    return pos == v
}

isType :: proc (arg : Argument, $ty : typeid) -> bool {
    _, ok := arg.type.(ty)
    return ok
}

parseSingleArgumentType :: proc (arg : ^Argument, s : string, $ty : typeid) -> (value : ty, ok : bool = false) {
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

parseSingleArgument :: proc (arg : ^Argument, s : string) -> (ok : bool = false) {
    if !argIsList(arg^) && arg.provided { return }

    for sv in arg.allowedSpecialValues {
        if sv == s {
            if !argIsList(arg^) {
                arg.value = SpecialValue(s)
            }
            else {
                append(&arg.array, SpecialValue(s))
            }

            arg.provided = true
            ok = true
            return
        }
    }

    switch _ in arg.type {
    case Flag, []Flag:
        f, _ := getValueOrAssign(arg, Flag, 0)
        f += 1
        arg.value = mkValue(Flag, f)
    case bool:
        value := parseSingleArgumentType(arg, s, bool) or_return
        arg.value = mkValue(bool, value)
    case []bool:
        value := parseSingleArgumentType(arg, s, bool) or_return
        append(&arg.array, mkValueS(bool, value))
    case i64:
        value := parseSingleArgumentType(arg, s, i64) or_return
        arg.value = mkValue(i64, value)
    case []i64:
        value := parseSingleArgumentType(arg, s, i64) or_return
        append(&arg.array, mkValueS(i64, value))
    case u64:
        value := parseSingleArgumentType(arg, s, u64) or_return
        arg.value = mkValue(u64, value)
    case []u64:
        value := parseSingleArgumentType(arg, s, u64) or_return
        append(&arg.array, mkValueS(u64, value))
    case f64:
        value := parseSingleArgumentType(arg, s, f64) or_return
        arg.value = mkValue(f64, value)
    case []f64:
        value := parseSingleArgumentType(arg, s, f64) or_return
        append(&arg.array, mkValueS(f64, value))
    case string:
        value := parseSingleArgumentType(arg, s, string) or_return
        arg.value = mkValue(string, value)
    case []string:
        value := parseSingleArgumentType(arg, s, string) or_return
        append(&arg.array, mkValueS(string, value))
    case: panic("bad")
    }

    arg.provided = true

    ok = true
    return
}

reset :: proc (c : ^Parser) {
    c.pos = 0
    resize(&c.subcommand, 0)

    for &a in c.arguments {
        a.value = a.default
    }
}

parse :: proc (c : ^Parser, strings : []string, skipFirst : bool = true) -> (ok : bool = false) {
    strings := strings
    if skipFirst { strings = strings[1:] }

    s : string
    next : bool = true

    loop: for true {
        if s, strings, next = take_string(strings); !next { break }

        for sc in c.subcommands {
            if !slice.has_prefix(sc, c.subcommand[:]) { continue }
            index := len(c.subcommand)

            if index >= len(sc) || sc[index] != s { continue }

            append(&c.subcommand, s)

            continue loop
        }

        for &arg in c.arguments {
            if !slice.has_prefix(c.subcommand[:], arg.sub) { continue }

            arg_positional := isPositionalAt(c.pos, arg)
            arg_named      := slice.contains(arg.name, s)

            if !arg_positional && !arg_named { continue }

            if arg_positional {
                c.pos += 1
            }
            else {
                if !isType(arg, Flag) {
                    s, strings = take_string(strings) or_return
                }
            }

            parseSingleArgument(&arg, s) or_return
            continue loop
        }

        ok = false
        return
    }
    
    ok = true
    return
}



main :: proc () {
    parser := Parser{
        arguments = {
            { type = u64{}, name = { "--hello" } }, 
            { type = []Flag{}, name = { "--help" } }, 
        }
    }

    reset(&parser)
    ok := parse(&parser, { "./program", "--hello", "64", "--help", "--help" })
    fmt.println(ok)


    fmt.println("Hello, World!")
}
