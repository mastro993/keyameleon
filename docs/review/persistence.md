# Review guideline: Persistence

CodeRabbit applies this to `Sources/**/*{Store,Persistence,SavedPhysicalKeyboardChange}*.swift` (see `knowledge_base.code_guidelines` in `.coderabbit.yaml`).

Persistence rules (docs/choices/persistence.md): records and designations share one explicit SwiftData
transaction with autosave off; a change reports success only after the whole transaction saves; failures
roll back and keep the request for an exact Retry. Unreadable data keeps the last good state and shows a
Retry notice; never delete, recreate, or substitute an in-memory store at runtime. Any SwiftData model
change must come with a migration and tests. Renamed or removed UserDefaults keys and Keychain items need
an explicit migration story for installed releases. Debug builds have their own identity and data
(docs/adr/0008-separate-debug-identity.md); storage paths must follow the bundle ID, not the display name.
