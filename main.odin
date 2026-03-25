package args

import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:os"

main :: proc () {
    hello : Maybe(u64)
    l : []u64

    parser := Parser{
        arguments = {
            { type = u64{},   name = { "--hello" }, special = { "null" }, required = true, store = &hello }, 
            { type = Flag{},  name = { "--help" } }, 
            { type = []u64{}, name = { "-l" }, store = &l, default = Default(DefaultList({ Value(u64(1)), Value(u64(2)), Value(u64(3)) })) },
        },
        subcommands = {
            { "test", "aboba" }
        }
    }

    reset(&parser)
    parse(&parser, { "./program", "test", "--hello", "5", "--hello", "5", "-l" })
    terminate(&parser)

    print_errors(os.to_writer(os.stdout), &parser)

    // fmt.println(parser.tokens[:])
    // printTokens(os.to_writer(os.stdout), parser.tokens[:])
}
