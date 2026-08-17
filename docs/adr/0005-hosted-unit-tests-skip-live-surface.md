# Hosted unit tests must not start live CoreHID or the status item

A hosted unit-test process is the Keyameleon app launched by `xcodebuild` for
`KeyameleonSwiftTesting` and `KeyameleonXCTest`. That process is detected by
`XCTestConfigurationFilePath` or `XCTestBundlePath`. It must not start
Activity-Triggered Switching, the lifecycle observer, the status item, or the
guided-setup window, and it must not start Sparkle. Those live streams and
AppKit surfaces keep `xcodebuild` from exiting after the tests have passed.

UI tests launch the real app without those environment keys and stay live.
There is no single-instance lock bypass. The test-only delegate initializer
defaults to no-op discovery, event, Input Source change, and lifecycle
adapters. `run.sh` may kill leftover Keyameleon processes only when their
executable path is under derived data.
