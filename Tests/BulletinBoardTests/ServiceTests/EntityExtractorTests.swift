import XCTest
@testable import BulletinBoard

final class EntityExtractorTests: XCTestCase {

    // MARK: - Email extraction

    func testExtractEmail() {
        let entities = EntityExtractor.extract(from: "Contact us at info@example.com for details")
        let emails = entities.filter { $0.type == .email }
        XCTAssertEqual(emails.count, 1)
        XCTAssertEqual(emails.first?.text, "info@example.com")
    }

    // MARK: - URL extraction

    func testExtractURL() {
        let entities = EntityExtractor.extract(from: "Visit https://www.example.com/page for more info")
        let urls = entities.filter { $0.type == .url }
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.text, "https://www.example.com/page")
    }

    // MARK: - Money extraction

    func testExtractMoney() {
        let entities = EntityExtractor.extract(from: "The company raised $50 million in funding worth $2.5 billion")
        let money = entities.filter { $0.type == .money }
        XCTAssertGreaterThanOrEqual(money.count, 1)
        XCTAssertTrue(money.contains(where: { $0.text.contains("$50 million") }))
    }

    func testExtractMoneyWithCents() {
        let entities = EntityExtractor.extract(from: "The item costs $19.99")
        let money = entities.filter { $0.type == .money }
        XCTAssertEqual(money.count, 1)
        XCTAssertEqual(money.first?.text, "$19.99")
    }

    // MARK: - Date extraction

    func testExtractFullDate() {
        let entities = EntityExtractor.extract(from: "The event is on January 15, 2025")
        let dates = entities.filter { $0.type == .date }
        XCTAssertEqual(dates.count, 1)
        XCTAssertTrue(dates.first?.text.contains("January") ?? false)
    }

    func testExtractNumericDate() {
        let entities = EntityExtractor.extract(from: "Due date: 03/15/2025")
        let dates = entities.filter { $0.type == .date }
        XCTAssertEqual(dates.count, 1)
        XCTAssertEqual(dates.first?.text, "03/15/2025")
    }

    // MARK: - Organization extraction

    func testExtractOrganization() {
        let entities = EntityExtractor.extract(from: "Shares of Acme Corp rose 5% today")
        let orgs = entities.filter { $0.type == .organization }
        XCTAssertEqual(orgs.count, 1)
        XCTAssertEqual(orgs.first?.text, "Acme Corp")
    }

    func testExtractOrganizationWithInc() {
        let entities = EntityExtractor.extract(from: "Apple Inc announced new products")
        let orgs = entities.filter { $0.type == .organization }
        XCTAssertTrue(orgs.contains(where: { $0.text.contains("Apple") && $0.text.contains("Inc") }))
    }

    // MARK: - Person extraction

    func testExtractPerson() {
        let entities = EntityExtractor.extract(from: "Dr. Sarah Johnson presented the findings")
        let persons = entities.filter { $0.type == .person }
        XCTAssertEqual(persons.count, 1)
        XCTAssertTrue(persons.first?.text.contains("Sarah") ?? false)
        XCTAssertTrue(persons.first?.text.contains("Johnson") ?? false)
    }

    func testExtractPersonWithTitle() {
        let entities = EntityExtractor.extract(from: "Sen. John Smith introduced the bill")
        let persons = entities.filter { $0.type == .person }
        XCTAssertEqual(persons.count, 1)
        XCTAssertTrue(persons.first?.text.contains("John") ?? false)
    }

    // MARK: - Mixed extraction

    func testExtractMultipleTypes() {
        let text = "Dr. Jane Smith at Acme Corp announced a $10 million investment on January 5, 2025. Contact press@acme.com"
        let entities = EntityExtractor.extract(from: text)

        let types = Set(entities.map { $0.type })
        XCTAssertTrue(types.contains(.person))
        XCTAssertTrue(types.contains(.organization))
        XCTAssertTrue(types.contains(.money))
        XCTAssertTrue(types.contains(.date))
        XCTAssertTrue(types.contains(.email))
    }

    func testDeduplication() {
        let text = "Contact info@test.com or info@test.com for details"
        let entities = EntityExtractor.extract(from: text)
        let emails = entities.filter { $0.type == .email }
        XCTAssertEqual(emails.count, 1)
    }

    func testEmptyText() {
        let entities = EntityExtractor.extract(from: "")
        XCTAssertTrue(entities.isEmpty)
    }

    func testHTMLStripping() {
        let entities = EntityExtractor.extract(from: "<p>Contact <a href='#'>info@example.com</a></p>")
        let emails = entities.filter { $0.type == .email }
        XCTAssertEqual(emails.count, 1)
    }
}
