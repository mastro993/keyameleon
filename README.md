# Keyameleon

Keyameleon is a native Swift 6 macOS menu bar app for Multilingual Professionals.

## Build and test

Install [XcodeGen](https://github.com/yonaskolb/XcodeGen), then run:

```sh
./Scripts/run.sh test
```

Build and launch the shell with:

```sh
./Scripts/run.sh open
```

The app uses one AppKit process. It has no Dock icon. Its durable menu bar item opens or quits Keyameleon. Closing the window keeps the process running and allows the window to reopen from the menu.
