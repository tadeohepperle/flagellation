package flagellation
import "core:fmt"
import "core:strings"
import "core:testing"
import "core:unicode/utf8"

tprint :: fmt.tprint
print :: fmt.println


main :: proc() {
	tests(nil)
}

evaluate :: proc(template: string, allocator := context.allocator) -> (res: string, err: Error) {
	b: strings.Builder
	strings.builder_init(&b, allocator)
	flags: map[string]string = make(map[string]string, context.temp_allocator)
	template_local := template
	cursor := &template_local
	err = _evaluate(cursor, &b, &flags)
	if err, ok := err.(string); ok {
		parsed_len := len(template) - len(cursor^)
		parsed_until := template[:parsed_len]
		_, last_ru_size := utf8.decode_last_rune(parsed_until)

		return "", tprint(err, " at \"", template[parsed_len - last_ru_size:], "\"", sep = "")
	}
	return strings.to_string(b), nil
}


Cursor :: ^string
Error :: Maybe(string)

_evaluate :: proc(cursor: Cursor, b: ^strings.Builder, flags: ^map[string]string) -> (err: Error) {
	loop: for {
		str, token := _read_until_token(cursor, {.BracketOpen, .CurlyOpen})
		strings.write_string(b, str)
		#partial switch token {
		case .NoToken:
			break loop
		case .BracketOpen:
			t := _expect_token(cursor)
			#partial switch t {
			case .NoToken:
				// this means [myflag?insert this]
				key, t := _read_until_token(cursor, {.QuestionMark, .BracketClose, .Equal})
				expected_value: string
				if t == .Equal {
					expected_value, t = _read_until_token(cursor, {.QuestionMark, .BracketClose})
				}
				if t != .QuestionMark {
					return "'?' expected after key in brackets"
				}

				insert_str: string
				insert_str_else: string
				insert_str, t = _read_until_token(cursor, {.BracketClose, .Pipe})
				if t == .Pipe {
					insert_str_else, t = _read_until_token(cursor, {.BracketClose})
				}
				if t != .BracketClose {
					return "expected ']'"
				}
				flag_value, flag_is_set := flags[key]
				condition_is_true :=
					flag_is_set && (flag_value == expected_value || expected_value == "")
				if condition_is_true {
					strings.write_string(b, insert_str)
				} else if insert_str_else != "" {
					strings.write_string(b, insert_str_else)
				}
			case .Plus:
				// add a flag [+myflag] or [+myflag=hello]
				key, t := _read_until_token(cursor, {.Equal, .BracketClose})
				value: string
				if t == .Equal {
					value, t = _read_until_token(cursor, {.BracketClose})
				}
				if t != .BracketClose {
					return "expected ']'"
				}
				flags[key] = value
			case .Minus:
				// remove flag [-myflag]
				key, t := _read_until_token(cursor, {.BracketClose})
				if t != .BracketClose {
					return "expected ']'"
				}
				delete_key(flags, key)
			case:
				return tprint("invalid '", TOKEN_RUNES[t], "' token", sep = "")
			}
		case .CurlyOpen:
			// {X} or {X|not found} or {X|}
			variable, t := _read_until_token(cursor, {.Pipe, .CurlyClose})
			alternative: string
			alternative_specified: bool
			if t == .Pipe {
				alternative, t = _read_until_token(cursor, {.CurlyClose})
				alternative_specified = true
			}
			variable_value, has_variable := flags[variable]
			if has_variable {
				strings.write_string(b, variable_value)
			} else {
				if alternative_specified {
					strings.write_string(b, alternative)
				} else {
					strings.write_string(b, variable)
				}
			}
		case:
			panic("should not get here")
		}

	}

	return nil
}

TokenSet :: bit_set[Token;u16]
Token :: enum u8 {
	NoToken,
	BracketOpen, // [
	BracketClose, // ]
	CurlyOpen, // {
	CurlyClose, // }
	QuestionMark, // ?
	Pipe, // | 
	Plus, // +
	Minus, // -
	Equal,
	Colon,
}
@(rodata)
TOKEN_RUNES := [Token]rune {
	.NoToken      = {},
	.BracketOpen  = '[',
	.BracketClose = ']',
	.CurlyOpen    = '{',
	.CurlyClose   = '}',
	.QuestionMark = '?',
	.Pipe         = '|',
	.Plus         = '+',
	.Minus        = '-',
	.Equal        = '=',
	.Colon        = ':',
}
_read_until_token :: proc(cursor: Cursor, stop_tokens: TokenSet) -> (res: string, token: Token) {
	str := cursor^
	n_bytes := 0
	for {
		if len(cursor) == 0 {
			return str[:n_bytes], .NoToken
		}
		cur_ru, size := utf8.decode_rune_in_string(cursor^)
		token = _rune_to_token(cur_ru)
		if token != .NoToken && token in stop_tokens {
			res = str[:n_bytes]
			cursor^ = str[n_bytes + size:]
			return res, token
		}
		n_bytes += size
		cursor^ = str[n_bytes:]
	}
}

_rune_to_token :: #force_inline proc "contextless" (ru: rune) -> Token {
	switch ru {
	case '[':
		return .BracketOpen
	case ']':
		return .BracketClose
	case '{':
		return .CurlyOpen
	case '}':
		return .CurlyClose
	case '?':
		return .QuestionMark
	case '|':
		return .Pipe
	case '+':
		return .Plus
	case '-':
		return .Minus
	case '=':
		return .Equal
	case ':':
		return .Colon
	}
	return .NoToken
}

_expect_token :: proc(cursor: Cursor) -> (token: Token) {
	cur_ru, size := utf8.decode_rune_in_string(cursor^)
	token = _rune_to_token(cur_ru)
	if token != .NoToken {
		cursor^ = cursor[size:]
	}
	return token
}
