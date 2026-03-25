package args

import "core:fmt"
import "core:slice"
import "core:strconv"


/*

Possible user errors

- Unrecognized argument
    - string that starts with '-', but isn't a known argument
- A required argument being absent
- A non-list argument appearing more than once
- An argument being provided a value not of its type
- An argument allowing for special values receiving unrecognized special value
- Unrecognized subcommand
- Recognized, but unfinished subcommand
    - i.e. we allow subcommands "list stuff" and "list things", but not "list" by itself
- Argument receiving a value starting with a '-' without a --verbatim flag
- Argument not being provided a value
    - the last non-flag argument without a value following it
- Unexpected positional argument

*/


Error_UnrecognizedArgument :: struct { //
    pos : int,
    argument : string,
}

Error_RequiredArgumentMissing :: struct { //
    argument : ^Argument,
}

Error_ArgumentRepeat :: struct { //
    pos : int,
    argument : ^Argument,
}

Error_ArgumentMismatchedType :: struct { //
    pos : int,
    argument : ^Argument,
    receivedValue : string,
}

Error_UnrecognizedSubcommand :: struct { //
    subcommand : []string,
}

Error_UnrecognizedSpecialValue :: struct { //
    pos : int,
    argument : ^Argument,
    specialValue : string,
}

Error_DashValueWithoutVerbatim :: struct { //
    pos : int,
    value : string,
}

Error_ArgumentMissingValue :: struct { //
    pos : int,
    argument : ^Argument,
}

Error_UnexpectedPositionalArgument :: struct { //
    pos : int,
    value : string,
}

Error_VerbatimWithoutValue :: struct { //
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
}
