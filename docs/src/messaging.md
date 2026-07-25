# Messaging

## Publisher

- `make-publisher`
- `make-test-publisher`
- `make-recording-publisher`
- `recording-published-messages`
- `reset-recording-published-messages`
- `publisher-publish`

The publisher boundary models fire-and-forget message publishing, mirroring the
logging and metrics boundaries. `publisher-publish` emits a
`(:topic <topic> :message <message>)` event and returns it; the topic must be a
non-nil symbol or a string while the message is arbitrary.
`make-publisher` sends each event to an injected `:emit-fn`, defaulting to a
no-op sink so a plain publisher drops messages instead of touching a broker.
`make-test-publisher` is the sinkless double that records each published message
and exposes them through `recording-published-messages`.
`make-recording-publisher` records each message and forwards it to a delegate,
defaulting to a no-op `make-publisher` sink, exposing the same history through
`recording-published-messages`.

See [`examples/test-publisher.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-publisher.lisp).

## Subscriber

- `make-subscriber`
- `make-test-subscriber`
- `make-recording-subscriber`
- `recording-subscriber-calls`
- `reset-recording-subscriber-calls`
- `subscriber-poll`
- `subscriber-poll-batch`

The subscriber boundary models consuming messages, pairing with the publisher
boundary. `subscriber-poll` returns the next message or `nil` when none is
available. `make-subscriber` wires that to an injected `:poll-fn`, while
`make-test-subscriber` is a queue-backed fake that yields its `:messages` in
order and returns `nil` once the queue is exhausted, mirroring a poll that finds
nothing waiting.
`make-recording-subscriber` records each poll while delegating to another
subscriber, defaulting to an empty `make-test-subscriber`, and exposes the
history through `recording-subscriber-calls`.
`subscriber-poll-batch` polls up to a maximum number of times, collecting
messages until a poll returns `nil` or the maximum is reached, so batch draining
always terminates even for a subscriber that keeps returning messages.

See [`examples/test-subscriber.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-subscriber.lisp).

## Notifier

- `make-notifier`
- `make-test-notifier`
- `make-recording-notifier`
- `recording-sent-notifications`
- `reset-recording-sent-notifications`
- `notifier-notify`

The notifier boundary models sending notifications such as email or push
messages. `notifier-notify` emits a `(:recipient <r> :subject <s> :body <b>)`
event for string recipient, subject, and body, and returns it. `make-notifier`
sends each event to an injected `:emit-fn`, defaulting to a no-op sink so a plain
notifier drops notifications instead of touching a backend.
`make-test-notifier` is the sinkless double that records each sent notification
and exposes them through `recording-sent-notifications`.
`make-recording-notifier` records each notification and forwards it to a
delegate, defaulting to a no-op `make-notifier` sink, exposing the same history
through `recording-sent-notifications`.

See [`examples/test-notifier.lisp`](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/examples/test-notifier.lisp).
