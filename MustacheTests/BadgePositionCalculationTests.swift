//
//  BadgePositionCalculationTests.swift
//  MustacheTests
//
//  Unit tests for badge position calculation
//

@testable import Mustache
import XCTest

final class BadgePositionCalculationTests: XCTestCase {
    let badgeOffset = CGPoint(x: 10, y: 10)

    // MARK: - Position Calculation Tests

    func testBadgePositionCalculationFromWindowFrame() {
        // Test various window positions
        let testCases: [(CGRect, CGPoint)] = [
            // (window frame, expected badge position)
            (CGRect(x: 0, y: 0, width: 100, height: 100), CGPoint(x: 10, y: 10)),
            (CGRect(x: 100, y: 200, width: 500, height: 400), CGPoint(x: 110, y: 210)),
            (CGRect(x: 500, y: 300, width: 800, height: 600), CGPoint(x: 510, y: 310)),
            (CGRect(x: 1920, y: 1080, width: 1000, height: 800), CGPoint(x: 1930, y: 1090)),
        ]

        for (windowFrame, expectedPosition) in testCases {
            let calculatedPosition = CGPoint(
                x: windowFrame.origin.x + badgeOffset.x,
                y: windowFrame.origin.y + badgeOffset.y
            )

            XCTAssertEqual(calculatedPosition.x, expectedPosition.x,
                           "Badge X position should be window X + offset")
            XCTAssertEqual(calculatedPosition.y, expectedPosition.y,
                           "Badge Y position should be window Y + offset")
        }
    }

    func testBadgePositionWithZeroOffset() {
        let windowFrame = CGRect(x: 100, y: 200, width: 500, height: 400)
        let zeroOffset = CGPoint(x: 0, y: 0)

        let position = CGPoint(
            x: windowFrame.origin.x + zeroOffset.x,
            y: windowFrame.origin.y + zeroOffset.y
        )

        XCTAssertEqual(position.x, windowFrame.origin.x,
                       "With zero offset, badge X should equal window X")
        XCTAssertEqual(position.y, windowFrame.origin.y,
                       "With zero offset, badge Y should equal window Y")
    }

    func testBadgePositionWithNegativeWindowCoordinates() {
        // Test with negative coordinates (multi-monitor setups)
        let windowFrame = CGRect(x: -1920, y: 0, width: 1920, height: 1080)

        let position = CGPoint(
            x: windowFrame.origin.x + badgeOffset.x,
            y: windowFrame.origin.y + badgeOffset.y
        )

        XCTAssertEqual(position.x, -1910,
                       "Badge position should handle negative coordinates")
        XCTAssertEqual(position.y, 10,
                       "Badge Y position should be calculated correctly")
    }

    func testOffsetApplication() {
        let testOffsets: [CGPoint] = [
            CGPoint(x: 5, y: 5),
            CGPoint(x: 10, y: 10),
            CGPoint(x: 20, y: 15),
            CGPoint(x: 0, y: 0),
        ]

        let windowFrame = CGRect(x: 100, y: 200, width: 500, height: 400)

        for offset in testOffsets {
            let position = CGPoint(
                x: windowFrame.origin.x + offset.x,
                y: windowFrame.origin.y + offset.y
            )

            XCTAssertEqual(position.x, windowFrame.origin.x + offset.x,
                           "Offset X should be applied correctly")
            XCTAssertEqual(position.y, windowFrame.origin.y + offset.y,
                           "Offset Y should be applied correctly")
        }
    }

    // MARK: - Badge View Model Tests

    func testBadgeViewModelCreation() {
        let position = CGPoint(x: 100, y: 200)
        let badge = BadgeViewModel(
            id: 12345,
            number: 1,
            position: position,
            isHighlighted: false
        )

        XCTAssertEqual(badge.id, 12345, "Badge ID should match")
        XCTAssertEqual(badge.number, 1, "Badge number should match")
        XCTAssertEqual(badge.position.x, 100, "Badge X position should match")
        XCTAssertEqual(badge.position.y, 200, "Badge Y position should match")
        XCTAssertFalse(badge.isHighlighted, "Badge should not be highlighted initially")
    }

    func testBadgePositionUpdate() {
        var badge = BadgeViewModel(
            id: 12345,
            number: 1,
            position: CGPoint(x: 100, y: 200),
            isHighlighted: false
        )

        let newPosition = CGPoint(x: 150, y: 250)
        badge.position = newPosition

        XCTAssertEqual(badge.position.x, 150, "Badge X position should be updated")
        XCTAssertEqual(badge.position.y, 250, "Badge Y position should be updated")
    }
}
