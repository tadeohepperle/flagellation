# a tiny DSL for flag based grammar templates

What problem does this solve? Let's say you have a game in which different events happen. Each event is subject + action.
As an example, let the action be `"deal 10 damage to you"` and the subject is either `"You"` or `"A monster"`.
Now we cannot just simply concatenate the two strings, because of grammar:

- `You deal 10 damage to you` should be `You deal 10 damage to yourself`.
- `A monster deal 10 damage to you` should be `A monster deals 10 damage to you`.

flaggelation is a tiny DSL that evaluates template strings in which you can set und unset flags and add conditional strings based on the flags that are set.

A template for the example above could be to use `You[+p=2]` as the you subject and `A monster[+p=3]` for the monster, setting a flag named `p` to a value of `"2"` or `"3"` for 2nd and 3rd person singular. Then the action string template can look like this: `deal[p=3?s] 10 damage to [p=2?yourself|you]`. Here the `[p=3?s]` checks if a `p` flag was set to value `3` before and if so, inserts the additional `s`. The `[p=2?yourself|you]` inserts `yourself` if the `p` flag was set to `2` and `you` otherwise.

## Syntax:

- set flag: `[+foo]` or `[+foo=bar]` (if specific value is needed)
- unset flag: `[-foo]` or override it with `[+foo=othervalue]`
- conditional insert: `[foo?insert this if foo is set]` or `[foo?insert this|otherwise this]`
- paste value of flag: `{foo}`. If `[+foo=abc]` was set before, this pastes `abc`, otherwise it pastes `foo`.
  `{foo|alternative}` can be used to paste an alternative string if foo is not set. `{foo|}` pastes the value of foo only if foo is set.

## limitations:

currently nested expressions are not supported and some of the syntax tokens cannot be used in the free text of the template string.
