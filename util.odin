package args

import "core:fmt"
import "core:slice"
import "core:strconv"


str_pop :: proc (p : ^Parser, strings : []string) -> (s : string, rest : []string, ok : bool = false) {
    if len(strings) == 0 { return }
    p.index += 1
    append(&p.strings, strings[0])
    return strings[0], strings[1:], true
}

str_peek :: proc (p : ^Parser, strings : []string) -> (s : string, ok : bool = false) {
    if len(strings) == 0 { return }
    return strings[0], true
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

determineType :: proc (s : string) -> (type : Value) {
    if s == "true" || s == "false" { return bool{} }
    if _, ok := strconv.parse_u64_maybe_prefixed(s); ok { return u64{} }
    if _, ok := strconv.parse_i64_maybe_prefixed(s); ok { return i64{} }
    if _, ok := strconv.parse_f64(s); ok { return f64{} }
    return string{}
}


is_type :: proc ($ty : typeid, v : Value) -> bool {
    #partial switch _ in v {
    case ty: return true
    }

    return false
}

type_equal :: proc (a : Value, b : Value) -> bool {
    switch v in a {
    case u64:    return is_type(u64, b)
    case i64:    return is_type(i64, b)
    case f64:    return is_type(f64, b)
    case bool:   return is_type(bool, b)
    case string: return is_type(string, b)
    case Flag:   return is_type(Flag, b)

    case []u64:    return is_type([]u64, b)
    case []i64:    return is_type([]i64, b)
    case []f64:    return is_type([]f64, b)
    case []bool:   return is_type([]bool, b)
    case []string: return is_type([]string, b)
    case []Flag:   return is_type([]Flag, b)
    }

    return false
}
