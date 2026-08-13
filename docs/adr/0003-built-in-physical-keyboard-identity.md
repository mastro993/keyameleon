# Treat the built-in Physical Keyboard as one identity

On a supported Mac with a built-in Physical Keyboard, Keyameleon treats all
CoreHID keyboard services that macOS marks as built-in as one stable Physical
Keyboard. It does not reject this Physical Keyboard when its services have a
missing or different software identity or different interface facts. These
services belong to one integrated Physical Keyboard and cannot represent two
separately assigned keyboards. External Physical Keyboards keep the strict
stable and unique Physical Keyboard Identity rules.

Keyameleon uses one fixed local Physical Keyboard Identity for the built-in
Physical Keyboard. This identity does not contain or depend on a CoreHID
software identity, hardware identifier, or Mac identifier. It stays stable when
macOS changes the services that represent the built-in Physical Keyboard.

On the first launch with this identity rule, Keyameleon automatically moves the
Physical Keyboard Name and Keyboard Assignment from an old built-in record when
exactly one such record exists. This migration is a narrow exception to the rule
that Keyameleon does not automatically move saved data between changed Physical
Keyboard Identities.

When multiple old built-in records exist, Keyameleon does not migrate or delete
them automatically. It shows the built-in Physical Keyboard as unassigned and
keeps the old records. The user can use the existing replacement flow to move
the Physical Keyboard Name and Keyboard Assignment from one selected old
record. The user can also create a new Keyboard Assignment or forget old
records.

During automatic migration, Keyameleon deletes Diagnostic Data linked to the
old built-in identity. It does not relink that data to the fixed identity. New
Diagnostic Data uses the fixed identity.

For its default Physical Keyboard Name, Keyameleon uses the one nonempty macOS
product name when all built-in services report the same name. If the services
report different names or no name, Keyameleon uses `Built-in Keyboard`.
