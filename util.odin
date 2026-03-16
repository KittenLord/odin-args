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
