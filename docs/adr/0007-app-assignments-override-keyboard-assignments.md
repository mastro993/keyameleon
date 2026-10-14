# App Assignments override Keyboard Assignments

Keyameleon switches the Input Source per Physical Keyboard and, since #187, per
app. An App Assignment applies to every Physical Keyboard while its app is the
Frontmost App, and it wins over the Active Physical Keyboard's Keyboard
Assignment. The Wanted Input Source is the Frontmost App's App Assignment, else
the Active Physical Keyboard's Keyboard Assignment, else none. Website
Assignments (#188) are expected to sit above App Assignments in the same chain.

We rejected a per-keyboard, per-app matrix ("Terminal on the external keyboard
uses U.S., on the built-in keyboard Italian"). It is the most expressive model,
but it multiplies the settings a person must fill in, and the motivating case,
an app that always needs one layout, is global. A matrix can still be added
later as an exception on top of a global App Assignment.

An App Activation triggers switching just as Activation Activity does, instead
of waiting for the next key press. Waiting would make the first key in an
assigned app use the wrong Input Source every time, which per-app switchers
avoid. The cost is that macOS "Automatically switch to a document's input
source" also switches on app activation; its changes count as External Input
Source Changes, so the docs tell people to turn it off.

Any App Activation ends an Input Source Hold. Switching apps is a strong signal
of a new context, and a hold that followed the person into an assigned app
would hide that app's App Assignment.

Keyameleon itself becoming active is not an App Activation, so editing an App
Assignment in Settings never changes the Input Source under the person.
