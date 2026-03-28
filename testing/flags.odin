package args_testing

import args ".."

import "core:testing"

@(test)
helpOnce :: proc (t : ^testing.T) {
    help : args.Flag

    parser := args.Parser{
        arguments = {
            { type = args.Flag{}, name = { "--help" }, store = &help },
        },

        subcommands = {
            { value = {} }
        }
    }

    args.reset(&parser)
    args.parse(&parser, { "./program", "--help" })
    args.terminate(&parser)

    testing.expect(t, help == 1)
    testing.expect(t, parser.success)
}

@(test)
helpOnceList :: proc (t : ^testing.T) {
    help : args.Flag

    parser := args.Parser{
        arguments = {
            { type = []args.Flag{}, name = { "--help" }, store = &help },
        },

        subcommands = {
            { value = {} }
        }
    }

    args.reset(&parser)
    args.parse(&parser, { "./program", "--help" })
    args.terminate(&parser)

    testing.expect(t, help == 1)
    testing.expect(t, parser.success)
}

@(test)
helpThriceList :: proc (t : ^testing.T) {
    help : args.Flag

    parser := args.Parser{
        arguments = {
            { type = []args.Flag{}, name = { "--help" }, store = &help },
        },

        subcommands = {
            { value = {} }
        }
    }

    args.reset(&parser)
    args.parse(&parser, { "./program", "--help", "--help", "--help" })
    args.terminate(&parser)

    testing.expect(t, help == 3)
    testing.expect(t, parser.success)
}
