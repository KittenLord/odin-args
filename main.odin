package args


import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:os"




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
    // ok := parse(&parser, os.args)
    // fmt.println(ok)
    // fmt.println(parser.errors)
    terminate(&parser)


    // fmt.println(l)
    // fmt.println(parser.tokens[:])

    printErrors(os.to_writer(os.stdout), &parser)

    // printTokens(os.to_writer(os.stdout), parser.tokens[:])
}
