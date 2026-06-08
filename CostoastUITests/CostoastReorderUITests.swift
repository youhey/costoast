//
//  CostoastReorderUITests.swift
//  CostoastUITests
//
//  Created by Codex on 2026/06/08.
//

import XCTest

final class CostoastReorderUITests: XCTestCase {
    func testMoveButtonsReorderCardsInCustomOrder() {
        let app = XCUIApplication()
        app.launchEnvironment["COSTOAST_UI_TEST_SEED_REORDER"] = "1"
        app.launch()

        let aws = rowElement(app: app, id: "billing-card-row-00000000-0000-0000-0000-000000000001")
        let cloudflare = rowElement(app: app, id: "billing-card-row-00000000-0000-0000-0000-000000000002")
        let deepLAPI = rowElement(app: app, id: "billing-card-row-00000000-0000-0000-0000-000000000003")
        let awsMoveUp = app.buttons["move-card-up-00000000-0000-0000-0000-000000000001"]
        let awsMoveDown = app.buttons["move-card-down-00000000-0000-0000-0000-000000000001"]
        let deepLAPIMoveDown = app.buttons["move-card-down-00000000-0000-0000-0000-000000000003"]

        XCTAssertTrue(aws.waitForExistence(timeout: 5))
        XCTAssertTrue(cloudflare.waitForExistence(timeout: 5))
        XCTAssertTrue(deepLAPI.waitForExistence(timeout: 5))
        XCTAssertTrue(awsMoveUp.waitForExistence(timeout: 5))
        XCTAssertTrue(awsMoveDown.waitForExistence(timeout: 5))
        XCTAssertTrue(deepLAPIMoveDown.waitForExistence(timeout: 5))
        XCTAssertFalse(awsMoveUp.isEnabled)
        XCTAssertFalse(deepLAPIMoveDown.isEnabled)
        XCTAssertLessThan(aws.frame.minY, cloudflare.frame.minY)
        XCTAssertLessThan(cloudflare.frame.minY, deepLAPI.frame.minY)

        awsMoveDown.click()

        XCTAssertTrue(waitForAWSBelowCloudflare(app: app), "AWS should move below Cloudflare after clicking Move Card Down.")
    }

    private func waitForAWSBelowCloudflare(app: XCUIApplication) -> Bool {
        let timeout = Date().addingTimeInterval(5)
        while Date() < timeout {
            let aws = rowElement(app: app, id: "billing-card-row-00000000-0000-0000-0000-000000000001")
            let cloudflare = rowElement(app: app, id: "billing-card-row-00000000-0000-0000-0000-000000000002")
            if aws.exists, cloudflare.exists, aws.frame.minY > cloudflare.frame.minY {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    private func rowElement(app: XCUIApplication, id: String) -> XCUIElement {
        app.groups[id]
    }
}
