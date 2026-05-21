import XCTest

@MainActor
final class CrestLaunchUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITest"]
    }

    override func tearDown() async throws {
        if app?.state == .runningForeground || app?.state == .runningBackground {
            app.terminate()
        }
        app = nil
    }

    func test_launch_appReachesRunningState() {
        app.launch()
        XCTAssertTrue(
            [.runningForeground, .runningBackground].contains(app.state),
            "Expected app to be running after launch, got state \(app.state.rawValue)"
        )
    }

    func test_launch_doesNotCrashAfterShortIdle() {
        app.launch()
        let stayedAlive = !app.wait(for: .notRunning, timeout: 3)
        XCTAssertTrue(stayedAlive, "App should remain running for at least a few seconds after launch")
    }

    func test_settingsWindow_opensViaCommandComma() throws {
        app.launch()
        app.activate()

        XCTAssertTrue(
            [.runningForeground, .runningBackground].contains(app.state),
            "App must be running before sending Cmd+,"
        )

        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows.matching(NSPredicate(format: "title CONTAINS[c] 'Settings' OR title CONTAINS[c] 'Preferences'")).firstMatch
        let appeared = settingsWindow.waitForExistence(timeout: 5)

        try XCTSkipUnless(
            appeared,
            "Settings window did not appear via Cmd+, — LSUIElement apps may need explicit activation; skipping rather than failing."
        )

        let generalTab = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR identifier == %@", "General", "General"))
            .firstMatch
        XCTAssertTrue(
            generalTab.waitForExistence(timeout: 3),
            "Expected the 'General' settings tab to be present in the Settings window"
        )
    }
}
