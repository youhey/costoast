//
//  CostoastReorderUITests.swift
//  CostoastUITests
//
//  Created by Codex on 2026/06/08.
//

import XCTest

final class CostoastReorderUITests: XCTestCase {
    func testDragAndDropReordersCardsInCustomOrder() {
        let app = XCUIApplication()
        app.launchEnvironment["COSTOAST_UI_TEST_SEED_REORDER"] = "1"
        app.launch()

        let aws = rowElement(app: app, id: "billing-card-row-00000000-0000-0000-0000-000000000001")
        let cloudflare = rowElement(app: app, id: "billing-card-row-00000000-0000-0000-0000-000000000002")
        let deepLAPI = rowElement(app: app, id: "billing-card-row-00000000-0000-0000-0000-000000000003")
        let awsDragHandle = app.buttons["billing-card-drag-handle-00000000-0000-0000-0000-000000000001"]

        XCTAssertTrue(aws.waitForExistence(timeout: 5))
        XCTAssertTrue(cloudflare.waitForExistence(timeout: 5))
        XCTAssertTrue(deepLAPI.waitForExistence(timeout: 5))
        XCTAssertTrue(awsDragHandle.waitForExistence(timeout: 5))
        XCTAssertLessThan(aws.frame.minY, cloudflare.frame.minY)
        XCTAssertLessThan(cloudflare.frame.minY, deepLAPI.frame.minY)

        awsDragHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(
                forDuration: 1.0,
                thenDragTo: deepLAPI.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            )

        XCTAssertTrue(waitForReorderedAWSBelowDeepLAPI(app: app), "AWS should move below DeepL API after dropping.")
    }

    private func waitForReorderedAWSBelowDeepLAPI(app: XCUIApplication) -> Bool {
        let timeout = Date().addingTimeInterval(5)
        while Date() < timeout {
            let aws = rowElement(app: app, id: "billing-card-row-00000000-0000-0000-0000-000000000001")
            let deepLAPI = rowElement(app: app, id: "billing-card-row-00000000-0000-0000-0000-000000000003")
            if aws.exists, deepLAPI.exists, aws.frame.minY > deepLAPI.frame.minY {
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
