package args

import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:os"

main :: proc () {
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

    parser := Parser{
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

    reset(&parser)
    parse(&parser, { "./program",
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
    terminate(&parser)

    reset(&parser)
    parse(&parser, { "./program" })
    terminate(&parser)


    fmt.println(v_u64, v_i64, v_bool, v_string)

    print_errors(os.to_writer(os.stdout), &parser)
}
