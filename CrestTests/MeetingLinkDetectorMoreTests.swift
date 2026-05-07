import XCTest
@testable import Crest

/// Extended coverage for MeetingLinkDetector beyond the tier-1 patterns
/// in MeetingLinkDetectorTests.
final class MeetingLinkDetectorMoreTests: XCTestCase {

    // MARK: - Tier 1 (extra)

    func test_detectsGoToMeeting() {
        let link = MeetingLinkDetector.detect(in: "Join: https://www.gotomeet.me/JaneDoe")
        XCTAssertEqual(link?.service, .gotoMeeting)
    }

    func test_detectsBlueJeans() {
        let link = MeetingLinkDetector.detect(in: "Dial in https://bluejeans.com/123456789")
        XCTAssertEqual(link?.service, .bluejeans)
    }

    // MARK: - Tier 2

    func test_detectsAmazonChime() {
        let link = MeetingLinkDetector.detect(in: "https://chime.aws/1234567890")
        XCTAssertEqual(link?.service, .chime)
    }

    func test_detectsSkype() {
        let link = MeetingLinkDetector.detect(in: "https://join.skype.com/abc123def")
        XCTAssertEqual(link?.service, .skype)
    }

    func test_detectsDiscord() {
        let link = MeetingLinkDetector.detect(in: "Hop in https://discord.gg/abc123")
        XCTAssertEqual(link?.service, .discord)
    }

    func test_detects8x8() {
        let link = MeetingLinkDetector.detect(in: "https://8x8.vc/standup-room")
        XCTAssertEqual(link?.service, .meet8x8)
    }

    func test_detectsFaceTime() {
        let link = MeetingLinkDetector.detect(in: "https://facetime.apple.com/join#v=1&p=abc")
        XCTAssertEqual(link?.service, .facetime)
    }

    // MARK: - Tier 3

    func test_detectsDailyCo() {
        let link = MeetingLinkDetector.detect(in: "https://acme.daily.co/standup")
        XCTAssertEqual(link?.service, .daily)
    }

    func test_detectsCalCom() {
        let link = MeetingLinkDetector.detect(in: "Book at https://cal.com/jdoe/30min")
        XCTAssertEqual(link?.service, .cal)
    }

    // MARK: - Multi-source nil handling

    func test_detectMultiSource_returnsNilWhenAllSourcesEmpty() {
        XCTAssertNil(MeetingLinkDetector.detect(location: nil, notes: nil, url: nil))
        XCTAssertNil(MeetingLinkDetector.detect(location: "", notes: "", url: nil))
    }

    func test_detectMultiSource_skipsLocationWithoutLinkAndUsesNotes() {
        let link = MeetingLinkDetector.detect(
            location: "Conference Room A",
            notes: "Zoom backup: https://us02web.zoom.us/j/12345678901"
        )
        XCTAssertEqual(link?.service, .zoom)
    }

    // MARK: - First-match-wins on duplicates

    func test_returnsFirstMatchWhenMultipleSameServiceLinks() {
        let text = """
        Primary: https://meet.google.com/aaa-bbbb-ccc
        Backup: https://meet.google.com/xxx-yyyy-zzz
        """
        let link = MeetingLinkDetector.detect(in: text)
        XCTAssertEqual(link?.url.absoluteString, "https://meet.google.com/aaa-bbbb-ccc")
    }

    // MARK: - Generic fallback

    func test_genericFallback_matchesURLContainingMeetingKeyword() {
        let link = MeetingLinkDetector.detect(in: "Webinar at https://example.com/webinar/q1-kickoff")
        XCTAssertEqual(link?.service, .other)
    }

    func test_genericFallback_doesNotMatchPlainDocsURL() {
        XCTAssertNil(MeetingLinkDetector.detect(in: "Read https://example.com/docs/getting-started"))
    }
}
