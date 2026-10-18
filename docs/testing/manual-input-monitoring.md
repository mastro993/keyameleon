# Manual verification: Input Monitoring

Checklists for [Manual verification](../testing.md#manual-verification).

## Input Monitoring persistence

Do not use the ad hoc test build for this.

1. Build with Xcode Run or `run.sh open`, grant Input Monitoring to that Debug build in System Settings, then quit and reopen it.
2. Rebuild and run again. The permission must stay granted and no prompt may return.

A grant made to an earlier ad hoc build may need replacing once for the newly signed app.

## Input Monitoring recovery

`InputMonitoringRecoveryTests` covers the actions per decision, the Settings deep link, the relaunch guard, the one-time stale reset, and that a manual launch never resets with injected side effects, so tests never open System Settings, run `tccutil`, or quit. `SetupModelTests` covers a grant advancing setup through the permission watch. Check the real behavior on macOS 26 with the Debug identity, never the installed release's: every reset below removes only the row for `dev.fedemas.keyameleon.debug` ([ADR 0008](../adr/0008-separate-debug-identity.md)). Afterwards, quit the Debug app and open the installed release: it must still read Input Monitoring as granted.

1. **Unknown.** Run `tccutil reset ListenEvent dev.fedemas.keyameleon.debug`, then open the Debug app with `./Scripts/run.sh open`. Guided setup and the menu notice offer only Allow Input Monitoring. Choosing it shows the macOS alert, Keyameleon appears switched off in Input Monitoring, and the UI switches to Open System Settings with Restart Keyameleon.
2. **Grant.** Choose Open System Settings: Input Monitoring opens, including when System Settings is already open on another pane. Turn Keyameleon on and choose Quit & Reopen: Keyameleon reopens Ready, and Guided setup continues at Keyboards.
3. **Later.** Repeat with Later instead. If the status does not recover within a few seconds, Restart Keyameleon reopens it Ready.
4. **Stale row.** With the switch on for the signed Debug app, quit it and open the ad hoc test app that `./Scripts/run.sh test` built, `build/test/Build/Products/Debug/Keyameleon (Dev).app`. It has the same Debug bundle identifier but a different signature, so it reads Input Monitoring is off. Choose Restart Keyameleon: after reopening, the macOS alert appears and Keyameleon is listed switched off. Turn it on, choose Later, then Restart Keyameleon: Ready. Restart Keyameleon reopens this copy by path, while Quit & Reopen could open the signed copy instead. To give the row back to the signed app, quit the test app, run `./Scripts/run.sh open`, and repeat the same steps.
5. Quit Keyameleon normally and reopen: nothing is reset and no alert appears.
