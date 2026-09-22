import Testing
@testable import Keyameleon

@Test("Hosted unit-test process reads XCTest configuration path")
func hostedUnitTestProcessReadsXCTestConfigurationPath() {
    #expect(
        KeyameleonHostedUnitTestProcess.isDetected(
            environment: ["XCTestConfigurationFilePath": "/tmp/test"]
        )
    )
}

@Test("Hosted unit-test process reads XCTest bundle path")
func hostedUnitTestProcessReadsXCTestBundlePath() {
    #expect(
        KeyameleonHostedUnitTestProcess.isDetected(
            environment: ["XCTestBundlePath": "/tmp/bundle.xctest"]
        )
    )
}

@Test("Hosted unit-test process ignores a launch without XCTest host env")
func hostedUnitTestProcessIgnoresLaunchWithoutXCTestHostEnv() {
    #expect(!KeyameleonHostedUnitTestProcess.isDetected(environment: [:]))
}

@Test("Preview process reads the Xcode preview environment flag")
func previewProcessReadsXcodeEnvironmentFlag() {
    #expect(
        KeyameleonPreviewProcess.isDetected(
            environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"]
        )
    )
}

@Test("Preview process requires the enabled flag value")
func previewProcessRequiresEnabledFlagValue() {
    #expect(
        !KeyameleonPreviewProcess.isDetected(
            environment: ["XCODE_RUNNING_FOR_PREVIEWS": "0"]
        )
    )
    #expect(!KeyameleonPreviewProcess.isDetected(environment: [:]))
}
