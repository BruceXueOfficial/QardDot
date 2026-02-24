import XCTest

final class KnowledgeCardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesToForeground() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testTabNavigationSmoke() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["新增"].tap()
        XCTAssertTrue(app.staticTexts["新建卡片"].waitForExistence(timeout: 2))

        app.tabBars.buttons["仓库"].tap()
        XCTAssertTrue(app.staticTexts["卡片管理"].waitForExistence(timeout: 2))

        app.tabBars.buttons["个人"].tap()
        XCTAssertTrue(app.staticTexts["个人"].waitForExistence(timeout: 2))

        app.tabBars.buttons["广场"].tap()
        XCTAssertTrue(app.staticTexts["知识广场"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testAddCardEntrySheetFlowSmoke() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["新增"].tap()
        XCTAssertTrue(app.staticTexts["新建卡片"].waitForExistence(timeout: 2))

        app.staticTexts["手动新建"].tap()
        XCTAssertTrue(app.navigationBars["手动新建"].waitForExistence(timeout: 2))

        app.buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["新建卡片"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testGraphCreateAndWarehouseSwitchSmoke() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["新增"].tap()
        XCTAssertTrue(app.staticTexts["新建图谱"].waitForExistence(timeout: 2))

        app.buttons["新建图谱"].firstMatch.tap()
        XCTAssertTrue(app.buttons["创建图谱"].waitForExistence(timeout: 2))
        app.buttons["创建图谱"].tap()

        XCTAssertTrue(app.buttons["graph_editor_add_button"].waitForExistence(timeout: 4))
        app.buttons["graph_editor_close_button"].tap()

        app.tabBars.buttons["仓库"].tap()
        XCTAssertTrue(app.buttons["图谱仓库"].waitForExistence(timeout: 2))
        app.buttons["图谱仓库"].tap()
        XCTAssertTrue(app.staticTexts["图谱仓库"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testKnowledgeSquareRecommendationSplitCardSmoke() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["广场"].tap()
        XCTAssertTrue(app.staticTexts["知识广场"].waitForExistence(timeout: 2))

        let card = app.otherElements["knowledgeSquare.recommendation.card"].firstMatch
        guard card.waitForExistence(timeout: 3) else {
            throw XCTSkip("No recommendation card rendered in current test data.")
        }

        XCTAssertTrue(app.otherElements["knowledgeSquare.recommendation.top"].firstMatch.exists)
        XCTAssertTrue(app.otherElements["knowledgeSquare.recommendation.body"].firstMatch.exists)
        XCTAssertTrue(app.otherElements["knowledgeSquare.recommendation.footer"].firstMatch.exists)
    }
}
