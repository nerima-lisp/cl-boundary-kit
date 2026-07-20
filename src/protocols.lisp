;;;; src/protocols.lisp

(in-package #:cl-boundary-kit)

(defgeneric clock-now (clock)
  (:documentation "Return CLOCK's wall-clock time value."))
(defgeneric clock-monotonic (clock)
  (:documentation "Return CLOCK's monotonic time value."))

(defgeneric random-source-random (random-source limit)
  (:documentation "Return a pseudo-random value from RANDOM-SOURCE less than LIMIT."))

(defgeneric uuid-generate (source)
  (:documentation "Return a fresh unique identifier string from SOURCE."))

(defgeneric temp-path-next (source)
  (:documentation "Return a fresh unique temporary pathname from SOURCE."))

(defgeneric args-list (args)
  (:documentation "Return ARGS's command-line arguments as a fresh list."))
(defgeneric args-count (args)
  (:documentation "Return how many command-line arguments ARGS holds."))
(defgeneric args-nth (args index)
  (:documentation "Return ARGS's command-line argument at zero-based INDEX, or NIL."))

(defgeneric host-info-hostname (host-info)
  (:documentation "Return HOST-INFO's host name string."))
(defgeneric host-info-username (host-info)
  (:documentation "Return HOST-INFO's user name string."))
(defgeneric host-info-pid (host-info)
  (:documentation "Return HOST-INFO's process id."))

(defgeneric sleeper-sleep (sleeper seconds)
  (:documentation "Pause through SLEEPER for SECONDS and return SECONDS."))

(defgeneric console-read-line (console)
  (:documentation "Read one line of input through CONSOLE, or NIL at end of input."))
(defgeneric console-write-line (console line)
  (:documentation "Write LINE to CONSOLE's standard output and return LINE."))
(defgeneric console-write (console text)
  (:documentation "Write TEXT to CONSOLE's standard output without a trailing newline and return TEXT."))
(defgeneric console-write-error (console line)
  (:documentation "Write LINE to CONSOLE's error output and return LINE."))

(defgeneric system-exit (system &optional code)
  (:documentation "Request process termination through SYSTEM with exit CODE."))

(defgeneric kv-get (store key &optional default)
  (:documentation "Return KEY's value from STORE plus a present-p secondary value, or DEFAULT."))
(defgeneric kv-put (store key value)
  (:documentation "Store VALUE under KEY in STORE and return VALUE."))
(defgeneric kv-delete (store key)
  (:documentation "Remove KEY from STORE and return whether it was present."))
(defgeneric kv-keys (store)
  (:documentation "Return STORE's current keys."))
(defgeneric kv-update (store key function &optional default)
  (:documentation "Read KEY from STORE (or DEFAULT), apply FUNCTION, store the result, and return it."))
(defgeneric kv-clear (store)
  (:documentation "Remove every key from STORE and return STORE."))
(defgeneric kv-get-or-put (store key default-thunk)
  (:documentation "Return KEY from STORE, or store and return DEFAULT-THUNK's value when absent."))
(defgeneric kv-increment (store key &optional delta)
  (:documentation "Add DELTA to KEY's numeric value in STORE (absent = 0) and return the new value."))

(defgeneric lock-acquire (lock)
  (:documentation "Acquire LOCK and return true."))
(defgeneric lock-release (lock)
  (:documentation "Release LOCK and return true."))

(defgeneric semaphore-acquire (semaphore)
  (:documentation "Acquire one permit from SEMAPHORE and return true."))
(defgeneric semaphore-release (semaphore)
  (:documentation "Return one permit to SEMAPHORE and return true."))
(defgeneric semaphore-available (semaphore)
  (:documentation "Return the number of permits currently available in SEMAPHORE."))

(defgeneric working-directory-get (working-directory)
  (:documentation "Return WORKING-DIRECTORY's current directory pathname."))
(defgeneric working-directory-set (working-directory path)
  (:documentation "Set WORKING-DIRECTORY's current directory to PATH and return it."))

(defgeneric dns-resolve (resolver hostname)
  (:documentation "Resolve HOSTNAME through RESOLVER and return its address list."))

(defgeneric secret-get (store name &optional default)
  (:documentation "Return NAME's secret from STORE plus a present-p secondary value, or DEFAULT."))
(defgeneric secret-names (store)
  (:documentation "Return the configured secret names in STORE (their keys, not their values)."))

(defgeneric feature-enabled-p (flags name)
  (:documentation "Return whether the feature flag NAME is enabled in FLAGS."))
(defgeneric feature-flags-enabled (flags)
  (:documentation "Return the names of the flags currently enabled in FLAGS."))

(defgeneric cache-get (cache key &optional default)
  (:documentation "Return KEY's cached value from CACHE plus a present-p secondary value, or DEFAULT."))
(defgeneric cache-put (cache key value &key ttl)
  (:documentation "Store VALUE under KEY in CACHE with optional TTL and return VALUE."))
(defgeneric cache-evict (cache key)
  (:documentation "Remove KEY from CACHE and return whether it was present."))
(defgeneric cache-fetch (cache key thunk &key ttl)
  (:documentation "Return KEY's cached value, or compute it with THUNK, store it with optional TTL, and return it."))
(defgeneric cache-clear (cache)
  (:documentation "Remove every entry from CACHE and return CACHE."))

(defgeneric rate-limiter-allow-p (limiter)
  (:documentation "Consume one unit from LIMITER and return whether it was permitted."))
(defgeneric rate-limiter-available (limiter)
  (:documentation "Return the number of units currently available in LIMITER."))

(defgeneric scheduler-schedule (scheduler delay thunk)
  (:documentation "Schedule THUNK to run after DELAY through SCHEDULER and return a task id."))
(defgeneric scheduler-cancel (scheduler id)
  (:documentation "Cancel the task ID in SCHEDULER and return whether it was pending."))

(defgeneric logger-log (logger level message &rest fields)
  (:documentation "Emit a log event through LOGGER with LEVEL, MESSAGE, and plist-style FIELDS."))

(defgeneric metrics-count (metrics name amount)
  (:documentation "Emit a counter metric named NAME incremented by AMOUNT through METRICS."))
(defgeneric metrics-gauge (metrics name value)
  (:documentation "Emit a gauge metric named NAME set to VALUE through METRICS."))
(defgeneric metrics-timing (metrics name milliseconds)
  (:documentation "Emit a timing metric named NAME of MILLISECONDS through METRICS."))

(defgeneric publisher-publish (publisher topic message)
  (:documentation "Publish MESSAGE on TOPIC through PUBLISHER and return the event."))

(defgeneric subscriber-poll (subscriber)
  (:documentation "Poll SUBSCRIBER for the next message, or NIL when none is available."))

(defgeneric notifier-notify (notifier recipient subject body)
  (:documentation "Send a notification to RECIPIENT with SUBJECT and BODY through NOTIFIER."))
