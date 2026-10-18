# Logging

- One process-wide `Log` with four levels (`verbose`, `debug`, `warning`, `error`) and three categories (`app`, `switching`, `setup`). Call sites emit one line without passing a logger around.
- Nothing is written until `Log.start` installs a writer at launch, so tests and previews never touch the real Logs folder.
- The writer appends to `~/Library/Logs/Keyameleon/keyameleon.log` (`Keyameleon Dev` for Debug builds) through one `O_APPEND` descriptor, rotates at 1 MiB, and keeps five rotated files. It collapses line breaks inside a message, truncates oversized records, and reopens the file if it is deleted or replaced. Every file operation is best effort and never interrupts switching.
- A line holds the timestamp, level, category, and message. Keyboard lines use the Physical Keyboard Name (the saved custom name first), never identities, paths, system error text, or Key Content.
- Logged events include launch, termination, store and Launch at Login failures, update checks, connections and disconnections, changes of Active Physical Keyboard, selection results (named by keyboard, or by app for an App Assignment), status changes, permission, Keyboard and App Assignment changes, External Change Response changes, Input Source selections from [automation](automation.md) at `debug` and automation URLs that fail or name no action at `warning`, and the start and end of each Input Source Hold at `debug`, with the reason it ended. There is no line per keystroke and none per App Activation, so the log keeps no history of the apps you use; `verbose` covers External Input Source Changes.
- A blocked second launch appends one line without rotating, so it never renames a file the running app holds open.
- A crash leaves no marker; the missing `Terminating` line shows it.
