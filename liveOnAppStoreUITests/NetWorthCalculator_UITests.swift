import XCTest

final class NetWorthCalculator_UITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func test_calculateWithEmptyNetWorth_showsError() {
        // Tap Calculate without entering net worth
        app.buttons["Calculate"].tap()

        // Verify error message appears
        let errorText = app.staticTexts["Please enter a valid current net worth."]
        XCTAssertTrue(
            errorText.waitForExistence(timeout: 2),
            "Expected error message to appear when net worth is empty"
        )

        // Verify output text is still present
        let outputText = app.staticTexts
            .containing(NSPredicate(format: "label CONTAINS %@", "Net worth after"))
            .firstMatch

        XCTAssertTrue(outputText.exists)
    }
}
