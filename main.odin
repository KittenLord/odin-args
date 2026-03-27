package args

import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:os"

main :: proc () {
    hello : Maybe(u64)
    l : []u64

    parser := Parser{
        description = { "Very cool program", "" },

        arguments = {
            { type = u64{},   name = { "--hello" }, special = { "null" }, required = true, store = &hello }, 
            { type = Flag{},  name = { "--help", "-h", "-hlp" }, description = { "Write information about every used subcommand and argument to stdout and terminate. Adding the flag twice will display more information about the arguments", "" } }, 
            { type = []u64{}, name = { "-l" }, store = &l, default = Default(DefaultList({ Value(u64(1)), Value(u64(2)), Value(u64(3)) })) },
        },

        subcommands = {
            { { "build" }, Description{ "build the project", "" } },
            { { "test" },  Description{ "test your very cool project", "" } },
        },
    }

    reset(&parser)
    parse(&parser, { "./program", "test", "--hello", "5", "--hello", "5", "-l" })
    terminate(&parser)

    // print_errors(os.to_writer(os.stdout), &parser)

    // fmt.println(parser.tokens[:])
    // printTokens(os.to_writer(os.stdout), parser.tokens[:])

    fmt.println()
    printhelp_help(os.to_writer(os.stdout), parser, true, 9999)
    fmt.println()
}
