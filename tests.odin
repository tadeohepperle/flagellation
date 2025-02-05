package flaggelation
import "core:fmt"
import "core:testing"
@(test)
tests :: proc(t: ^testing.T) {
	SubjectAndExpected :: struct {
		damage:   int,
		subject:  string,
		expected: string,
	}

	effect := "deal[3?s] {X} damage to" // flag 3 for 3rd person singular, flag 2 for 2nd person singular
	target := "[2?yourself|you]"

	cases := []SubjectAndExpected {
		{damage = 3, subject = "You[+2]", expected = "You deal 3 damage to yourself"},
		{damage = 8, subject = "He[+3]", expected = "He deals 8 damage to you"},
		{damage = -1, subject = "He[+3]", expected = "He deals X damage to you"},
	}

	for c in cases {
		damage_def := fmt.tprintf("[+X={}]", c.damage) if c.damage != -1 else ""
		template := tprint(damage_def, c.subject, " ", effect, " ", target, sep = "")
		result, err := evaluate(template)
		print(template, "  -->  ", result)
		testing.expect_value(t, err, nil)
		testing.expect_value(t, result, c.expected)
	}
}
