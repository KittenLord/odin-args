package args_testing

import args ".."

import "core:testing"

@(test)
no_verbatim :: proc (t : ^testing.T) {
    value : string

    parser := args.Parser{
        arguments = {
            { type = string{}, name = { "--v" }, store = &value, required = true },
        },

        subcommands = {
            { value = {} }
        }
    }

    args.reset(&parser)
    args.parse(&parser, { "./program", "--v", "--my_value" })
    args.terminate(&parser)

    testing.expect(t, parser.failure)
    testing.expect(t, args.error_is(args.Error_DashValueWithoutVerbatim, parser.errors[0]))
}


@(test)
yes_verbatim :: proc (t : ^testing.T) {
    value : string

    parser := args.Parser{
        arguments = {
            { type = string{}, name = { "--v" }, store = &value, required = true },
        },

        subcommands = {
            { value = {} }
        }
    }

    args.reset(&parser)
    args.parse(&parser, { "./program", "--v", "--verbatim", "--my_value" })
    args.terminate(&parser)

    testing.expect(t, parser.success)
    testing.expect_value(t, value, "--my_value")
}



@(test)
verbatim_special :: proc (t : ^testing.T) {
    value : args.Special(string)

    parser := args.Parser{
        arguments = {
            { type = string{}, name = { "--v" }, store = &value, required = true, special = { "--special" } },
        },

        subcommands = {
            { value = {} }
        }
    }

    args.reset(&parser)
    args.parse(&parser, { "./program", "--v", "--special" })
    args.terminate(&parser)

    testing.expect(t, parser.success)
    testing.expect(t, value.(args.SpecialValue) == "--special")


    args.reset(&parser)
    args.parse(&parser, { "./program", "--v", "--verbatim", "--special" })
    args.terminate(&parser)

    testing.expect(t, parser.success)
    testing.expect(t, value.(string) == "--special")
}
