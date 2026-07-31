import XCTest
@testable import TerminalGridApp

final class ProjectTypeDetectorTests: XCTestCase {
    private var rootURL: URL!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectTypeDetectorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: rootURL)
    }

    func testDetectsFlutterBeforeNestedNativePlatforms() throws {
        try write("dependencies:\n  flutter:\n    sdk: flutter\n", to: "pubspec.yaml")
        try createDirectory("android")
        try createDirectory("ios")

        XCTAssertEqual(ProjectTypeDetector.detect(at: rootURL), .flutter)
        XCTAssertEqual(ProjectType.flutter.supportedPlatforms, [.android, .ios])
    }

    func testDetectsAndroidNative() throws {
        try write("pluginManagement {}", to: "settings.gradle.kts")
        try write("plugins {}", to: "app/build.gradle.kts")

        XCTAssertEqual(ProjectTypeDetector.detect(at: rootURL), .androidNative)
        XCTAssertEqual(ProjectType.androidNative.supportedPlatforms, [.android])
    }

    func testDetectsIOSNative() throws {
        try createDirectory("Example.xcodeproj")

        XCTAssertEqual(ProjectTypeDetector.detect(at: rootURL), .iosNative)
        XCTAssertEqual(ProjectType.iosNative.supportedPlatforms, [.ios])
    }

    func testDoesNotMisclassifyUnsupportedCrossPlatformProject() throws {
        try write("include(\":app\")", to: "settings.gradle")
        try write("plugins {}", to: "build.gradle")
        try createDirectory("Example.xcodeproj")

        XCTAssertEqual(ProjectTypeDetector.detect(at: rootURL), .unknown)
    }

    func testPlainDartProjectIsUnknown() throws {
        try write("name: example\n", to: "pubspec.yaml")

        XCTAssertEqual(ProjectTypeDetector.detect(at: rootURL), .unknown)
    }

    private func createDirectory(_ relativePath: String) throws {
        try FileManager.default.createDirectory(
            at: rootURL.appendingPathComponent(relativePath),
            withIntermediateDirectories: true
        )
    }

    private func write(_ contents: String, to relativePath: String) throws {
        let url = rootURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
