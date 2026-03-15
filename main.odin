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

Value :: union {
    Flag,   []Flag,
    bool,   []bool,
    i64,    []i64,
    u64,    []u64,
    f64,    []f64,
    string, []string,
}

SpecialValue :: distinct string

Special :: union($ty : typeid) {
    ty,
    SpecialValue,
}

DefaultValue :: distinct Special(Value)
DefaultList  :: distinct []Special(Value)

// NOTE: using Maybe(Default) makes sense semantically, but because odin is retarded it is redundant
// as every union has an implicit nil variant. In fact, due to a compiler bug this redundancy directly
// impacts the user, so we should probably use Default.nil instead of Maybe(Default).nil
Default :: union {
    DefaultValue,
    DefaultList,
}





/*

# Argument <-> store type

{ type = type, required = false, special = nil, default = nil } <-> Maybe(type)

{ type = type, required = false, special = { ... }, default = nil } <-> Maybe(Special(type))

{ type = type, required = true, special = nil, default = nil } <-> type
{ type = type, required = false, special = nil, default = ... } <-> type

{ type = type, required = true, special = { ... }, default = nil } <-> Special(type)
{ type = type, required = false, special = { ... }, default = ... } <-> Special(type)



{ type = []type, required = false, special = nil, default = nil } <-> Maybe([]type)

{ type = []type, required = false, special = { ... }, default = nil } <-> Maybe([]Special(type)) 

{ type = []type, required = true, special = nil, default = nil } <-> []type
{ type = []type, required = false, special = nil, default = { ... } } <-> []type

{ type = []type, required = true, special = { ... }, default = nil } <-> []Special(type)
{ type = []type, required = false, special = { ... }, default = { ... } } <-> []Special(type)



# Essentially this boils down to:

If required == false && default == nil -> Maybe
If special != nil -> Special
If list and special -> []Special

*/

Argument :: struct {
    // Never changing
    type     : Value,
    name     : []string,
    position : Maybe(int),
    required : bool,
    special  : []string,
    default  : Maybe(Default),
    sub      : []string,

    store    : rawptr,


    // Reset per distinct parse
    provided : bool, // NOTE: false if default
    value    : Maybe(Special(Value)),
    array    : [dynamic]Special(Value),
}

verify_arg :: proc (arg : Argument) -> bool {
    if arg.required && is_just(arg.default) { return false }
    if is_none(arg.position) && len(arg.name) == 0 { return false }

    // TODO: compare type of arg.type and arg.default

    return true
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



mkValue :: proc ($ty : typeid, value : ty) -> Maybe(Special(Value)) {
    av : Value = value
    asv : Special(Value) = av
    masv : Maybe(Special(Value)) = asv
    return masv
}

mkValueS :: proc ($ty : typeid, value : ty) -> Special(Value) {
    av : Value = value
    asv : Special(Value) = av
    return asv
}



arg_getValue :: proc (arg : ^Argument, $ty : typeid) -> (ty, bool) {
    // NOTE: Assuming called already typechecked
    if is_just(arg.value) { return arg.value.(ty), true }
    return {}, false
}

arg_getValueOrAssign :: proc (arg : ^Argument, $ty : typeid, value : ty) -> (ty, bool) {
    if is_just(arg.value) { return arg.value.?.(Value).(ty), true }
    else {
        arg.value = mkValue(ty, value)
        return value, false
    }
}

arg_isOptional :: proc (arg : Argument) -> bool {
    return !arg.required && is_none(arg.default)
}



arg_isList :: proc (arg : Argument, valueForFlagArray : bool = true) -> bool {
    switch _ in arg.type {
    case Flag: return false
    case []Flag: return valueForFlagArray
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

arg_doesAllowSpecialValues :: proc (arg : Argument) -> bool {
    return len(arg.special) > 0
}

arg_isPositionalAt :: proc (arg : Argument, pos : int) -> (ok : bool = false) {
    v := arg.position.? or_return
    return pos == v
}

arg_isType :: proc (arg : Argument, $ty : typeid) -> bool {
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
    if !arg_isList(arg^) && arg.provided { return }

    for sv in arg.special {
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
    case bool:      arg.value = mkValue(bool, parseSingleArgumentType(arg, s, bool) or_return)
    case i64:       arg.value = mkValue(i64, parseSingleArgumentType(arg, s, i64) or_return)
    case u64:       arg.value = mkValue(u64, parseSingleArgumentType(arg, s, u64) or_return)
    case f64:       arg.value = mkValue(f64, parseSingleArgumentType(arg, s, f64) or_return)
    case string:    arg.value = mkValue(string, parseSingleArgumentType(arg, s, string) or_return)
    case []bool:    append(&arg.array, mkValueS(bool, parseSingleArgumentType(arg, s, bool) or_return))
    case []i64:     append(&arg.array, mkValueS(i64, parseSingleArgumentType(arg, s, i64) or_return))
    case []u64:     append(&arg.array, mkValueS(u64, parseSingleArgumentType(arg, s, u64) or_return))
    case []f64:     append(&arg.array, mkValueS(f64, parseSingleArgumentType(arg, s, f64) or_return))
    case []string:  append(&arg.array, mkValueS(string, parseSingleArgumentType(arg, s, string) or_return))
    case: panic("bad")
    }

    arg.provided = true

    ok = true
    return
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
    }
}

// TODO: actual errors instead of a boolean (since this is actually user-facing)
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

            positional := arg_isPositionalAt(arg, c.pos)
            named      := slice.contains(arg.name, s)

            if !positional && !named { continue }

            if positional {
                c.pos += 1
            }
            else if named {
                if !arg_isType(arg, Flag) {
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

assign :: proc (c : ^Parser) {
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

        fmt.println("hello")

        if arg_doesAllowSpecialValues(arg) { dumpSpecial(arg, src, ty) }
        else                               { dumpValue(arg, src, ty) }
    }

    for arg in c.arguments {
        if arg.store == nil { continue }
        if (!arg_isList(arg) && is_none(arg.value)) || (arg_isList(arg) && is_none(arg.default) && !arg.provided) {
            fmt.printfln("goodbye %v", arg)
            // TODO: set store to {}
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
}



main :: proc () {
    hello : Maybe(u64)
    l : []u64

    parser := Parser{
        arguments = {
            { type = u64{},  name = { "--hello" }, store = &hello }, 
            { type = Flag{}, name = { "--help" } }, 
            { type = []u64{}, name = { "-l" }, store = &l, default = Default(DefaultList({ Value(u64(1)), Value(u64(2)), Value(u64(3)) })) },
        }
    }

    reset(&parser)
    ok := parse(&parser, { "./program", "--hello", "53", "--help", "-l", "5" })
    fmt.println(ok)
    assign(&parser)




    fmt.println(l)
}
