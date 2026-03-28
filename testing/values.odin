package args_testing

import args ".."

import "core:testing"

@(test)
values :: proc (t : ^testing.T) {
    v_flag      : args.Flag
    v_bool      : bool
    v_u64       : u64
    v_i64       : i64
    v_f64       : f64
    v_string    : string

    v_flags     : args.Flag
    v_bools     : []bool
    v_u64s      : []u64
    v_i64s      : []i64
    v_f64s      : []f64
    v_strings   : []string

    parser := args.Parser{
        arguments = {
            { type = args.Flag{}, name = { "--flag" }, store = &v_flag, required = true },
            { type = bool{},      name = { "--bool" }, store = &v_bool, required = true },
            { type = i64{},       name = { "--i64" }, store = &v_i64, required = true },
            { type = u64{},       name = { "--u64" }, store = &v_u64, required = true },
            { type = f64{},       name = { "--f64" }, store = &v_f64, required = true },
            { type = string{},    name = { "--string" }, store = &v_string, required = true },

            { type = []args.Flag{}, name = { "--flags" }, store = &v_flags, required = true },
            { type = []bool{},      name = { "--bools" }, store = &v_bools, required = true },
            { type = []i64{},       name = { "--i64s" }, store = &v_i64s, required = true },
            { type = []u64{},       name = { "--u64s" }, store = &v_u64s, required = true },
            { type = []f64{},       name = { "--f64s" }, store = &v_f64s, required = true },
            { type = []string{},    name = { "--strings" }, store = &v_strings, required = true },
        },

        subcommands = {
            { value = { } }
        }
    }

    args.reset(&parser)
    args.parse(&parser, { "./program",
        "--flag", 
        "--bool", "true",
        "--i64", "-5",
        "--u64", "67",
        "--f64", "6.9",
        "--string", "hello",

        "--flags", "--flags", "--flags", "--flags",
        "--bools", "false", "--bools", "true",
        "--i64s", "-67", "--i64s", "500",
        "--u64s", "21", "--u64s", "0",
        "--f64s", "123.456", "--f64s", "-23.0",
        "--strings", "amog", "--strings", "ngus",
    })
    args.terminate(&parser)

    testing.expect(t, parser.success)

    testing.expect_value(t, v_flag, 1)
    testing.expect_value(t, v_bool, true)
    testing.expect_value(t, v_i64, -5)
    testing.expect_value(t, v_u64, 67)
    testing.expect_value(t, v_f64, 6.9)
    testing.expect_value(t, v_string, "hello")

    testing.expect(t, v_flags == 4)
    testing.expect(t, v_bools[0] == false && v_bools[1] == true)
    testing.expect(t, v_i64s[0] == -67 && v_i64s[1] == 500)
    testing.expect(t, v_u64s[0] == 21 && v_u64s[1] == 0)
    testing.expect(t, v_f64s[0] == 123.456 && v_f64s[1] == -23.0)
    testing.expect(t, v_strings[0] == "amog" && v_strings[1] == "ngus")
}


@(test)
values_maybe :: proc (t : ^testing.T) {
    v_bool      : Maybe(bool)
    v_u64       : Maybe(u64)
    v_i64       : Maybe(i64)
    v_f64       : Maybe(f64)
    v_string    : Maybe(string)

    v_bools     : Maybe([]bool)
    v_u64s      : Maybe([]u64)
    v_i64s      : Maybe([]i64)
    v_f64s      : Maybe([]f64)
    v_strings   : Maybe([]string)

    parser := args.Parser{
        arguments = {
            { type = bool{},      name = { "--bool" }, store = &v_bool },
            { type = i64{},       name = { "--i64" }, store = &v_i64 },
            { type = u64{},       name = { "--u64" }, store = &v_u64 },
            { type = f64{},       name = { "--f64" }, store = &v_f64 },
            { type = string{},    name = { "--string" }, store = &v_string },

            { type = []bool{},      name = { "--bools" }, store = &v_bools },
            { type = []i64{},       name = { "--i64s" }, store = &v_i64s },
            { type = []u64{},       name = { "--u64s" }, store = &v_u64s },
            { type = []f64{},       name = { "--f64s" }, store = &v_f64s },
            { type = []string{},    name = { "--strings" }, store = &v_strings },
        },

        subcommands = {
            { value = { } }
        }
    }

    args.reset(&parser)
    args.parse(&parser, { "./program",
        "--bool", "true",
        "--i64", "-5",
        "--u64", "67",
        "--f64", "6.9",
        "--string", "hello",

        "--bools", "false", "--bools", "true",
        "--i64s", "-67", "--i64s", "500",
        "--u64s", "21", "--u64s", "0",
        "--f64s", "123.456", "--f64s", "-23.0",
        "--strings", "amog", "--strings", "ngus",
    })
    args.terminate(&parser)

    testing.expect(t, parser.success)

    testing.expect(t, v_bool.? == true)
    testing.expect(t, v_i64.? == -5)
    testing.expect(t, v_u64.? == 67)
    testing.expect(t, v_f64.? == 6.9)
    testing.expect(t, v_string.? == "hello")

    testing.expect(t, v_bools.?[0] == false && v_bools.?[1] == true)
    testing.expect(t, v_i64s.?[0] == -67 && v_i64s.?[1] == 500)
    testing.expect(t, v_u64s.?[0] == 21 && v_u64s.?[1] == 0)
    testing.expect(t, v_f64s.?[0] == 123.456 && v_f64s.?[1] == -23.0)
    testing.expect(t, v_strings.?[0] == "amog" && v_strings.?[1] == "ngus")

    args.reset(&parser)
    args.parse(&parser, { "./program" })
    args.terminate(&parser)

    testing.expect(t, parser.success)
    
    testing.expect(t, v_bool == nil)
    testing.expect(t, v_i64 == nil)
    testing.expect(t, v_u64 == nil)
    testing.expect(t, v_f64 == nil)
    testing.expect(t, v_string == nil)
    testing.expect(t, v_bools == nil)
    testing.expect(t, v_i64s == nil)
    testing.expect(t, v_u64s == nil)
    testing.expect(t, v_f64s == nil)
    testing.expect(t, v_strings == nil)
}



@(test)
values_special :: proc (t : ^testing.T) {
    v_bool      : args.Special(bool)
    v_u64       : args.Special(u64)
    v_i64       : args.Special(i64)
    v_f64       : args.Special(f64)
    v_string    : args.Special(string)

    v_bools     : []args.Special(bool)
    v_u64s      : []args.Special(u64)
    v_i64s      : []args.Special(i64)
    v_f64s      : []args.Special(f64)
    v_strings   : []args.Special(string)

    parser := args.Parser{
        arguments = {
            { type = bool{},      name = { "--bool" }, store = &v_bool, required = true, special = { "a", "b" } },
            { type = i64{},       name = { "--i64" }, store = &v_i64, required = true, special = { "a", "b" } },
            { type = u64{},       name = { "--u64" }, store = &v_u64, required = true, special = { "a", "b" } },
            { type = f64{},       name = { "--f64" }, store = &v_f64, required = true, special = { "a", "b" } },
            { type = string{},    name = { "--string" }, store = &v_string, required = true, special = { "a", "b" } },

            { type = []bool{},      name = { "--bools" }, store = &v_bools, required = true, special = { "a", "b" } },
            { type = []i64{},       name = { "--i64s" }, store = &v_i64s, required = true, special = { "a", "b" } },
            { type = []u64{},       name = { "--u64s" }, store = &v_u64s, required = true, special = { "a", "b" } },
            { type = []f64{},       name = { "--f64s" }, store = &v_f64s, required = true, special = { "a", "b" } },
            { type = []string{},    name = { "--strings" }, store = &v_strings, required = true, special = { "a", "b" } },
        },

        subcommands = {
            { value = { } }
        }
    }

    args.reset(&parser)
    args.parse(&parser, { "./program",
        "--bool", "a",
        "--i64", "69",
        "--u64", "a",
        "--f64", "b",
        "--string", "a",

        "--bools", "a", "--bools", "true",
        "--i64s", "-67", "--i64s", "b",
        "--u64s", "a", "--u64s", "0",
        "--f64s", "123.456", "--f64s", "b",
        "--strings", "a", "--strings", "ngus",
    })
    args.terminate(&parser)

    testing.expect(t, parser.success)

    testing.expect(t, v_bool.(args.SpecialValue) == "a")
    testing.expect(t, v_i64.(i64) == 69)
    testing.expect(t, v_u64.(args.SpecialValue) == "a")
    testing.expect(t, v_f64.(args.SpecialValue) == "b")
    testing.expect(t, v_string.(args.SpecialValue) == "a")

    testing.expect(t, v_bools[0].(args.SpecialValue) == "a" && v_bools[1].(bool) == true)
    testing.expect(t, v_i64s[0].(i64) == -67 && v_i64s[1].(args.SpecialValue) == "b")
    testing.expect(t, v_u64s[0].(args.SpecialValue) == "a" && v_u64s[1].(u64) == 0)
    testing.expect(t, v_f64s[0].(f64) == 123.456 && v_f64s[1].(args.SpecialValue) == "b")
    testing.expect(t, v_strings[0].(args.SpecialValue) == "a" && v_strings[1].(string) == "ngus")
}



@(test)
values_special_maybe :: proc (t : ^testing.T) {
    v_bool      : Maybe(args.Special(bool))
    v_u64       : Maybe(args.Special(u64))
    v_i64       : Maybe(args.Special(i64))
    v_f64       : Maybe(args.Special(f64))
    v_string    : Maybe(args.Special(string))

    v_bools     : Maybe([]args.Special(bool))
    v_u64s      : Maybe([]args.Special(u64))
    v_i64s      : Maybe([]args.Special(i64))
    v_f64s      : Maybe([]args.Special(f64))
    v_strings   : Maybe([]args.Special(string))

    parser := args.Parser{
        arguments = {
            { type = bool{},      name = { "--bool" }, store = &v_bool, special = { "a", "b" } },
            { type = i64{},       name = { "--i64" }, store = &v_i64, special = { "a", "b" } },
            { type = u64{},       name = { "--u64" }, store = &v_u64, special = { "a", "b" } },
            { type = f64{},       name = { "--f64" }, store = &v_f64, special = { "a", "b" } },
            { type = string{},    name = { "--string" }, store = &v_string, special = { "a", "b" } },

            { type = []bool{},      name = { "--bools" }, store = &v_bools, special = { "a", "b" } },
            { type = []i64{},       name = { "--i64s" }, store = &v_i64s, special = { "a", "b" } },
            { type = []u64{},       name = { "--u64s" }, store = &v_u64s, special = { "a", "b" } },
            { type = []f64{},       name = { "--f64s" }, store = &v_f64s, special = { "a", "b" } },
            { type = []string{},    name = { "--strings" }, store = &v_strings, special = { "a", "b" } },
        },

        subcommands = {
            { value = { } }
        }
    }

    args.reset(&parser)
    args.parse(&parser, { "./program",
        "--bool", "a",
        "--i64", "69",
        "--u64", "a",
        "--f64", "b",
        "--string", "a",

        "--bools", "a", "--bools", "true",
        "--i64s", "-67", "--i64s", "b",
        "--u64s", "a", "--u64s", "0",
        "--f64s", "123.456", "--f64s", "b",
        "--strings", "a", "--strings", "ngus",
    })
    args.terminate(&parser)

    testing.expect(t, parser.success)

    testing.expect(t, v_bool.?.(args.SpecialValue) == "a")
    testing.expect(t, v_i64.?.(i64) == 69)
    testing.expect(t, v_u64.?.(args.SpecialValue) == "a")
    testing.expect(t, v_f64.?.(args.SpecialValue) == "b")
    testing.expect(t, v_string.?.(args.SpecialValue) == "a")

    testing.expect(t, v_bools.?[0].(args.SpecialValue) == "a" && v_bools.?[1].(bool) == true)
    testing.expect(t, v_i64s.?[0].(i64) == -67 && v_i64s.?[1].(args.SpecialValue) == "b")
    testing.expect(t, v_u64s.?[0].(args.SpecialValue) == "a" && v_u64s.?[1].(u64) == 0)
    testing.expect(t, v_f64s.?[0].(f64) == 123.456 && v_f64s.?[1].(args.SpecialValue) == "b")
    testing.expect(t, v_strings.?[0].(args.SpecialValue) == "a" && v_strings.?[1].(string) == "ngus")

    args.reset(&parser)
    args.parse(&parser, { "./program" })
    args.terminate(&parser)

    testing.expect(t, parser.success)
    
    testing.expect(t, v_bool == nil)
    testing.expect(t, v_i64 == nil)
    testing.expect(t, v_u64 == nil)
    testing.expect(t, v_f64 == nil)
    testing.expect(t, v_string == nil)
    testing.expect(t, v_bools == nil)
    testing.expect(t, v_i64s == nil)
    testing.expect(t, v_u64s == nil)
    testing.expect(t, v_f64s == nil)
    testing.expect(t, v_strings == nil)
}
