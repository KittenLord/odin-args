package args

import "core:fmt"
import "core:io"

COLOR_VERBATIM :: "\e[1;90m"
COLOR_DOUBLEDASH :: "\e[1;90m"
COLOR_PROGRAMNAME :: "\e[1;90m"
COLOR_VALUE :: "\e[1;96m"
COLOR_POSITIONALVALUE :: "\e[1;94m"

COLOR_RESET :: "\e[0m"

printToken :: proc (w : io.Stream, token : Token) {
    if token.draw != .None {
        switch token.draw {
        case .None:
        case .Error:
            fmt.wprintf(w, "\e[1;4;31m%v" + COLOR_RESET, token.value)
        case .Highlighted:
            fmt.wprintf(w, "\e[1;4;33m%v" + COLOR_RESET, token.value)
        }

        return
    }

    switch token.type {
    case .Value:
        fmt.wprintf(w, COLOR_VALUE + "%v" + COLOR_RESET, token.value)
    case .PositionalValue:
        fmt.wprintf(w, COLOR_POSITIONALVALUE + "%v" + COLOR_RESET, token.value)
    case .Flag:
        fmt.wprintf(w, "%v", token.value)
    case .Verbatim:
        fmt.wprintf(w, COLOR_VERBATIM + "%v" + COLOR_RESET, token.value)
    case .Subcommand:
        fmt.wprintf(w, "%v", token.value)
    case .DoubleDash:
        fmt.wprintf(w, COLOR_DOUBLEDASH + "%v" + COLOR_RESET, token.value)
    case .ProgramName:
        fmt.wprintf(w, COLOR_PROGRAMNAME + "%v" + COLOR_RESET, token.value)
    }
}

printTokens :: proc (w : io.Stream, tokens : []Token) {
    for token, i in tokens {
        if i != 0 { io.write_rune(w, ' ') }
        printToken(w, token)
    }
}

printError :: proc (w : io.Stream, error : Error) {
    switch e in error {
    case Error_UnrecognizedArgument:
    case Error_RequiredArgumentMissing:
    case Error_ArgumentRepeat:
    case Error_ArgumentMismatchedType:
    case Error_UnrecognizedSubcommand:
    case Error_UnrecognizedSpecialValue:
    case Error_DashValueWithoutVerbatim:
    case Error_ArgumentMissingValue:
    case Error_UnexpectedPositionalArgument:
    case Error_VerbatimWithoutValue:

    case: panic("bad")
    }
}
