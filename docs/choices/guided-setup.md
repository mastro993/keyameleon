# Guided setup

Guided setup has three saved stages: **Permissions**, **Keyboards**, and **Ready**.

- Permission is checked when the window opens, and a grant advances Permissions automatically. Before macOS has asked, the footer offers **Allow Input Monitoring**; afterward it offers **Open System Settings** and **Restart Keyameleon**.
- Keyboards saves each assignment and exclusion immediately. Continue and Set Up Later both reach Ready, even with no assignments. Back returns to Keyboards without losing changes. The step is one scrolling region (progress, explanation, rows, note) above a footer that stays reachable.
- Ready reports the number of assignments and the current switching state, points to Settings › Apps for App Assignments (setup has no Apps step), including paused, unavailable, and missing permission. **Finish** closes setup, removes the Dock icon, and starts the menu bar app; **Open Settings** closes setup, starts the menu bar app, then opens Settings. Completion is saved first and handled once.
- Until setup is complete Keyameleon is a regular app with a Dock icon, there is no status item, and Activity-Triggered Switching selects no Input Source. Permission and keyboard discovery still run so setup can advance. `ActivityTriggeredSwitching.appliesKeyboardAssignments` is the gate; `ApplicationDelegate` opens it on completion.
- Closing the window keeps the saved stage and quits Keyameleon, since nothing else is on screen. Opening Keyameleon again, or reopening the running app, shows setup at the saved stage.
