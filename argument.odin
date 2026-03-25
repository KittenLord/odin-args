package args

import "core:fmt"
import "core:slice"
import "core:strconv"



Flag :: distinct u64
SpecialValue :: distinct string

// TODO: more types (at the very least Special, Path, File, Directory)
Value :: union {
    Flag,   []Flag,
    bool,   []bool,
    i64,    []i64,
    u64,    []u64,
    f64,    []f64,
    string, []string,
}

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





// TODO: it might be useful to set min and max length (possibly unbounded) for a list argument

// TODO: we might want an argument type that allows ONLY special values (which is essentially a string type)




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
    beginPos : int,
    finalPos : int,
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

str_isArgument :: proc (s : string) -> bool {
    return len(s) > 0 && s[0] == '-'
}
        
arg_fitsSubcommand :: proc (arg : Argument, subcommand : []string) -> bool {
    return slice.has_prefix(subcommand, arg.sub)
}

arg_hasDefault :: proc (arg : Argument) -> bool {
    return is_just(arg.default)
}
