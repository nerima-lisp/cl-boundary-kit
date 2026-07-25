# Assertions and Testing Helpers

- `assert-recorded-call`
- `assert-recorded-call-count`
- `assert-recorded-call-sequence`
- `assert-no-recorded-call`
- `assert-recorded-call-order`
- `assert-recorded-operations`
- `filter-recorded-calls`
- `count-recorded-calls`
- `find-recorded-call`
- `recorded-call-operations`
- `recorded-call-results`
- `recorded-call-operation`
- `recorded-call-arguments`
- `recorded-call-result`
- `nth-recorded-call`
- `last-recorded-call`
- `event-values`
- `find-event`
- `count-events`
- `assert-event-present`
- `assert-no-event`
- `assert-event-count`
- `boundary-call-plist`

`assert-recorded-call` checks a recorder call list for an operation, optional
arguments, and an optional result, signaling an error when no matching call is
present. `assert-recorded-call-count` asserts how many matching calls were
recorded without forcing the whole call history into an `equal` comparison.
`assert-recorded-call-sequence` asserts ordered call history and can relax the
tail with `:exact-length nil` when you only care about a prefix. Supplying `:result nil` asserts an explicit `nil` result. `boundary-call-plist` builds the same plist shape used by the built-in recorders from an explicit argument list,
which is useful when you want to compare or construct expected call records
directly in tests.
`assert-no-recorded-call` is the negative assertion: it signals when a matching
call is present, letting a test assert that an operation did not happen.
`filter-recorded-calls` and `count-recorded-calls` are the non-asserting
counterparts of `assert-recorded-call` and `assert-recorded-call-count`: they
return the matching subset or its count without signaling, and
`recorded-call-operations` returns just the `:operation` of each recorded call in
order for quick sequence checks.
`assert-recorded-call-order` asserts that a series of operations appear in call
order as a (not necessarily adjacent) subsequence, so a test can check that one
operation happened before another. `assert-recorded-operations` sits between
`assert-recorded-call-sequence` and `assert-recorded-call-order`: it asserts the
exact ordered list of operation names while ignoring arguments and results. `recorded-call-results` returns just the
`:result` of each recorded call, and `nth-recorded-call` and `last-recorded-call`
return a single recorded call by index or the most recent one.
`recorded-call-operation`, `recorded-call-arguments`, and `recorded-call-result`
pull the individual fields out of a single recorded call, so they compose with
`nth-recorded-call`/`last-recorded-call` for concise single-call assertions.
`find-event`, `count-events`, `assert-event-present`, and `assert-no-event` work
on the event lists captured by the fire-and-forget boundaries (`recording-log-events`,
`recording-metric-events`, `recording-published-messages`,
`recording-sent-notifications`): each takes a plist of key/value constraints and
matches events whose keys hold those values, so a test can assert (for example)
that a log event with `:level :error` was emitted regardless of the event shape.
`assert-event-count` mirrors `assert-recorded-call-count` for events, and
`find-recorded-call` is the single-result counterpart of `filter-recorded-calls`,
so the operation-based and event-based helper families stay symmetric.
`event-values` pulls a chosen key from every event (the event-based counterpart
of `recorded-call-operations`/`-results`), for example every log event's `:level`.

See [Testing Helper](core-concepts.md#testing-helper) for the minimal
`assert-recorded-call`/`boundary-call-plist` pattern, and
[Assert On Recorded Boundary Calls](cookbook.md#assert-on-recorded-boundary-calls)
in the Cookbook for an end-to-end example combining several of these helpers.
