package args

import "core:fmt"
import "core:slice"
import "core:strconv"

// - Unrecognized argument
//    - string that starts with '-', but isn't a known argument
Error_UnrecognizedArgument :: struct { //
    pos : int,
    argument : string,
}

// - A required argument being absent
Error_RequiredArgumentMissing :: struct { //
    argument : ^Argument,
}

// - A non-list argument appearing more than once
Error_ArgumentRepeat :: struct { //
    pos : int,
    argument : ^Argument,
}

// - An argument being provided a value not of its type
Error_ArgumentMismatchedType :: struct { //
    pos : int,
    argument : ^Argument,
    receivedValue : string,
}

// - Unrecognized subcommand
// - Recognized, but unfinished subcommand
//     - i.e. we allow subcommands "list stuff" and "list things", but not "list" by itself
Error_UnrecognizedSubcommand :: struct { //
    subcommand : []string,
}

// - An argument allowing for special values receiving unrecognized special value
Error_UnrecognizedSpecialValue :: struct { //
    pos : int,
    argument : ^Argument,
    specialValue : string,
}

// - Argument receiving a value starting with a '-' without a --verbatim flag
Error_DashValueWithoutVerbatim :: struct { //
    pos : int,
    value : string,
}

// - Argument not being provided a value
//     - the last non-flag argument without a value following it
Error_ArgumentMissingValue :: struct { //
    pos : int,
    argument : ^Argument,
}

// - Unexpected positional argument
Error_UnexpectedPositionalArgument :: struct { //
    pos : int,
    value : string,
}

// - Argument not being provided a value
//     - the last non-flag argument without a value following it
Error_VerbatimWithoutValue :: struct { //
    pos : int,
}

// - Doubledash provided if explicitly forbidden
Error_DoubleDashForbidden :: struct { //
    pos : int,
}

Error :: union {
    Error_UnrecognizedArgument,
    Error_RequiredArgumentMissing,
    Error_ArgumentRepeat,
    Error_ArgumentMismatchedType,
    Error_UnrecognizedSubcommand,
    Error_UnrecognizedSpecialValue,
    Error_DashValueWithoutVerbatim,
    Error_ArgumentMissingValue,
    Error_UnexpectedPositionalArgument,
    Error_VerbatimWithoutValue,
    Error_DoubleDashForbidden,
}

error_is :: proc ($ty : typeid, e : Error) -> bool {
    #partial switch _ in e {
    case ty: return true
    }
    return false
}
