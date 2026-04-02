import XCTest
@testable import BulletinBoard
import LINKER

final class DateFormattingTests: XCTestCase {

    func test_justNow_forRecentTimestamp() {
        let timestamp = currentTimestamp() - 30
        XCTAssertEqual(DateFormatting.relativeDate(from: timestamp), "just now")
    }

    func test_minutesAgo() {
        let timestamp = currentTimestamp() - 300
        XCTAssertEqual(DateFormatting.relativeDate(from: timestamp), "5m ago")
    }

    func test_hoursAgo() {
        let timestamp = currentTimestamp() - 7200
        XCTAssertEqual(DateFormatting.relativeDate(from: timestamp), "2h ago")
    }

    func test_daysAgo() {
        let timestamp = currentTimestamp() - 259200
        XCTAssertEqual(DateFormatting.relativeDate(from: timestamp), "3d ago")
    }

    func test_boundary_59seconds_isJustNow() {
        let timestamp = currentTimestamp() - 59
        XCTAssertEqual(DateFormatting.relativeDate(from: timestamp), "just now")
    }

    func test_boundary_60seconds_is1mAgo() {
        let timestamp = currentTimestamp() - 60
        XCTAssertEqual(DateFormatting.relativeDate(from: timestamp), "1m ago")
    }

    func test_boundary_3599seconds_is59mAgo() {
        let timestamp = currentTimestamp() - 3599
        XCTAssertEqual(DateFormatting.relativeDate(from: timestamp), "59m ago")
    }

    func test_boundary_3600seconds_is1hAgo() {
        let timestamp = currentTimestamp() - 3600
        XCTAssertEqual(DateFormatting.relativeDate(from: timestamp), "1h ago")
    }
}
