# Usage

The argument parser is used in 5 steps:

1. Create the structure defining the argument parser
2. Reset the parser (sets argument fields such as `provided` to `false` as well as other required setup)
3. Feed arguments to the parser
    - Can be done in multiple batches, for example, first feed the terminal arguments, then the rest of the arguments from a file
4. Terminate the parser (assigns all pointers, reports extra errors, i.e. required argument missing)
5. Handle errors, if any

## Example

```odin
import args "..."
import "core:os"

package main

main :: proc () {
    parser := Parser{
        arguments = { ... },
        subcommands = { ... }
    }

    reset(&parser)

    parse(&parser, os.args) // Skips the first argument
    parse(&parser, { "--extra-arg", "5" }, false)

    terminate(&parser)

    if args.parser_hasErrors(parser) {
        // ...
        // report to user
        return
    }
}
```

# (hopefully) Exhaustive list of features

- Named arguments
    - Aliases
- Positional arguments
- List arguments
- Flag arguments (i.e. arguments without value)
    - Repeated flag arguments
- Required arguments
- Default values
- Special values (i.e. an argument can be provided a value of its type OR one out of special per argument-defined string tokens)
- Subcommands
- Escaping values that start with '-' using "--verbatim"
- Special handling for "--"

## Additional library features

- Pretty printing parsed command
- Error reporting
    - And pretty printing

# Argument specification

Each argument is defined by the following struct:

```odin
Argument :: struct {
    // Which value type is allowed. `Value` is a union, so that
    // the type can be assigned like `type = u64{}`, `type = []string{}`, etc.
    // The only member that is always unconditionally required
    // 
    // Supported types:
    // bool, i64, u64, f64, string, Flag,
    // all respective array versions (i.e. list arguments)
    type        : Value,

    // All names and aliases that the argument can be referred to as. The
    // first name is considered to be the primary one (e.g. for pretty printing).
    name        : []string,

    // Position at which the argument is expected to appear. No positional arguments
    // can follow after a positional list argument
    position    : Maybe(int),

    // Either (and only one) `name` or `position` must be assigned properly


    // If `true`, the parser will report an error upon termination if the
    // argument has not been provided
    // Iff `false` and `default == nil`, `store` must be of type `^Maybe(...)`
    required    : bool,

    // Special string values that can be accepted instead of the supposed type.
    // Special values take priority over regular string values, unless indicated
    // by --verbatim.
    // Iff not `nil`, `store` must use `Special(ty)` instead of `ty`
    special     : []string,

    // The default value of the argument. May be a
    //     - `DefaultValue`, alias for Special(Value)
    //     - `DefaultList`, alias for []Special(Value)
    // As of writing, there is a bug in Odin compiler which
    // requires you to provide the default value with explicit casting:
    // `default = Default(DefaultList({ ... }))`
    // `default = Default(DefaultValue({ ... }))`
    default     : Maybe(Default),

    // The minimal subcommand at which the argument enters the "namespace".
    // If `sub` is a prefix list of the current subcommand list, the argument
    // is "visible"
    sub         : []string,

    // Pointer to store the final value at. Must be same type as `type`, with
    // additional modifications specified by `required` and `special`
    // Maximal example: `^Maybe([]Special(u64))`
    // Can be nil
    store       : rawptr,


    // Members used by parser for accounting purposes are omitted
}
```
