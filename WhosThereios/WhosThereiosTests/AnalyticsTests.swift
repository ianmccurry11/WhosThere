//
//  AnalyticsTests.swift
//  WhosThereiosTests
//
//  Created by Claude on 2/4/26.
//

import XCTest
@testable import WhosThereios

// MARK: - AnalyticsEvent Tests

final class AnalyticsEventTests: XCTestCase {

    func testEventInitialization() {
        let sessionId = "test-session-123"
        let event = AnalyticsEvent(
            name: "test_event",
            parameters: ["key": "value"],
            sessionId: sessionId
        )

        XCTAssertEqual(event.name, "test_event")
        XCTAssertEqual(event.parameters["key"], "value")
        XCTAssertEqual(event.sessionId, sessionId)
        XCTAssertNotNil(event.id)
        XCTAssertNotNil(event.timestamp)
    }

    func testEventWithEmptyParameters() {
        let event = AnalyticsEvent(
            name: "empty_params_event",
            parameters: [:],
            sessionId: "session"
        )

        XCTAssertTrue(event.parameters.isEmpty)
        XCTAssertEqual(event.name, "empty_params_event")
    }

    func testEventTimestampIsRecent() {
        let beforeCreation = Date()
        let event = AnalyticsEvent(
            name: "timing_test",
            parameters: [:],
            sessionId: "session"
        )
        let afterCreation = Date()

        XCTAssertGreaterThanOrEqual(event.timestamp, beforeCreation)
        XCTAssertLessThanOrEqual(event.timestamp, afterCreation)
    }

    func testEventUniqueIds() {
        let event1 = AnalyticsEvent(name: "event1", parameters: [:], sessionId: "s")
        let event2 = AnalyticsEvent(name: "event2", parameters: [:], sessionId: "s")

        XCTAssertNotEqual(event1.id, event2.id)
    }
}

// MARK: - AnalyticsParameters Tests

final class AnalyticsParametersTests: XCTestCase {

    func testAddStringParameter() {
        let params = AnalyticsParameters.with { p in
            p.add("key", "value")
        }

        XCTAssertEqual(params["key"], "value")
    }

    func testAddNilStringParameter() {
        let nilString: String? = nil
        let params = AnalyticsParameters.with { p in
            p.add("key", nilString)
        }

        XCTAssertNil(params["key"])
    }

    func testAddIntParameter() {
        let params = AnalyticsParameters.with { p in
            p.add("count", 42)
        }

        XCTAssertEqual(params["count"], "42")
    }

    func testAddBoolParameter() {
        let params = AnalyticsParameters.with { p in
            p.add("enabled", true)
            p.add("disabled", false)
        }

        XCTAssertEqual(params["enabled"], "true")
        XCTAssertEqual(params["disabled"], "false")
    }

    func testAddDoubleParameter() {
        let params = AnalyticsParameters.with { p in
            p.add("value", 3.14159)
        }

        XCTAssertEqual(params["value"], "3.14")
    }

    func testMultipleParameters() {
        let params = AnalyticsParameters.with { p in
            p.add("string", "hello")
            p.add("int", 123)
            p.add("bool", true)
        }

        XCTAssertEqual(params.count, 3)
        XCTAssertEqual(params["string"], "hello")
        XCTAssertEqual(params["int"], "123")
        XCTAssertEqual(params["bool"], "true")
    }
}

// MARK: - AnalyticsEventName Tests

final class AnalyticsEventNameTests: XCTestCase {

    func testEventNameRawValues() {
        XCTAssertEqual(AnalyticsEventName.appLaunch.rawValue, "app_launch")
        XCTAssertEqual(AnalyticsEventName.signInAttempted.rawValue, "sign_in_attempted")
        XCTAssertEqual(AnalyticsEventName.signInSuccess.rawValue, "sign_in_success")
        XCTAssertEqual(AnalyticsEventName.signInFailure.rawValue, "sign_in_failure")
        XCTAssertEqual(AnalyticsEventName.signOut.rawValue, "sign_out")
        XCTAssertEqual(AnalyticsEventName.groupCreated.rawValue, "group_created")
        XCTAssertEqual(AnalyticsEventName.groupJoined.rawValue, "group_joined")
        XCTAssertEqual(AnalyticsEventName.groupLeft.rawValue, "group_left")
        XCTAssertEqual(AnalyticsEventName.checkIn.rawValue, "check_in")
        XCTAssertEqual(AnalyticsEventName.checkOut.rawValue, "check_out")
        XCTAssertEqual(AnalyticsEventName.achievementUnlocked.rawValue, "achievement_unlocked")
        XCTAssertEqual(AnalyticsEventName.messageSent.rawValue, "message_sent")
        XCTAssertEqual(AnalyticsEventName.screenView.rawValue, "screen_view")
        XCTAssertEqual(AnalyticsEventName.errorOccurred.rawValue, "error_occurred")
    }
}

// MARK: - AnalyticsDiscrepancy Tests

final class AnalyticsDiscrepancyTests: XCTestCase {

    func testDiscrepancyInitialization() {
        let discrepancy = AnalyticsDiscrepancy(
            eventName: "check_in",
            localCount: 5,
            expectedCount: 10,
            description: "Mismatch detected"
        )

        XCTAssertEqual(discrepancy.eventName, "check_in")
        XCTAssertEqual(discrepancy.localCount, 5)
        XCTAssertEqual(discrepancy.expectedCount, 10)
        XCTAssertEqual(discrepancy.description, "Mismatch detected")
        XCTAssertNotNil(discrepancy.id)
    }

    func testDiscrepancyUniqueIds() {
        let d1 = AnalyticsDiscrepancy(eventName: "e1", localCount: 1, expectedCount: 2, description: "")
        let d2 = AnalyticsDiscrepancy(eventName: "e2", localCount: 1, expectedCount: 2, description: "")

        XCTAssertNotEqual(d1.id, d2.id)
    }
}

// MARK: - AnalyticsService Tests

@MainActor
final class AnalyticsServiceTests: XCTestCase {

    var service: AnalyticsService!

    override func setUp() async throws {
        service = AnalyticsService.shared
        service.clearEvents()
        service.resetPersistedCounts()
    }

    override func tearDown() async throws {
        service.clearEvents()
        service.resetPersistedCounts()
    }

    func testServiceIsSingleton() {
        let service1 = AnalyticsService.shared
        let service2 = AnalyticsService.shared

        XCTAssertTrue(service1 === service2)
    }

    func testSessionIdExists() {
        XCTAssertFalse(service.sessionId.isEmpty)
    }

    func testTrackEventWithEnumName() {
        service.track(.appLaunch)

        XCTAssertEqual(service.recentEvents.count, 1)
        XCTAssertEqual(service.recentEvents.first?.name, "app_launch")
    }

    func testTrackEventWithStringName() {
        service.track("custom_event", parameters: ["custom_key": "custom_value"])

        XCTAssertEqual(service.recentEvents.count, 1)
        XCTAssertEqual(service.recentEvents.first?.name, "custom_event")
        XCTAssertEqual(service.recentEvents.first?.parameters["custom_key"], "custom_value")
    }

    func testEventCountsAreUpdated() {
        service.track(.checkIn)
        service.track(.checkIn)
        service.track(.checkOut)

        let counts = service.getAggregatedCounts()
        XCTAssertEqual(counts["check_in"], 2)
        XCTAssertEqual(counts["check_out"], 1)
    }

    func testRecentEventsLimitedToMax() {
        // Track more than 100 events
        for i in 0..<150 {
            service.track("event_\(i)")
        }

        XCTAssertEqual(service.recentEvents.count, 100)
        // Most recent should be first
        XCTAssertEqual(service.recentEvents.first?.name, "event_149")
    }

    func testClearEvents() {
        service.track(.appLaunch)
        service.track(.signOut)
        XCTAssertEqual(service.recentEvents.count, 2)

        service.clearEvents()
        XCTAssertEqual(service.recentEvents.count, 0)
    }

    func testResetSession() {
        let originalSessionId = service.sessionId
        service.track(.appLaunch)

        service.resetSession()

        XCTAssertNotEqual(service.sessionId, originalSessionId)
        XCTAssertEqual(service.recentEvents.count, 0)
    }

    func testGetEventsSinceDate() {
        let beforeEvents = Date()
        Thread.sleep(forTimeInterval: 0.01)

        service.track(.signInAttempted)
        service.track(.signInSuccess)

        let eventsSinceBefore = service.getEventsSince(beforeEvents)
        XCTAssertEqual(eventsSinceBefore.count, 2)

        let futureDate = Date().addingTimeInterval(60)
        let eventsSinceFuture = service.getEventsSince(futureDate)
        XCTAssertEqual(eventsSinceFuture.count, 0)
    }

    func testGetEventsNamedWithString() {
        service.track(.checkIn)
        service.track(.checkOut)
        service.track(.checkIn)

        let checkInEvents = service.getEvents(named: "check_in")
        XCTAssertEqual(checkInEvents.count, 2)
    }

    func testGetEventsNamedWithEnum() {
        service.track(.groupCreated)
        service.track(.groupJoined)
        service.track(.groupCreated)

        let groupCreatedEvents = service.getEvents(named: .groupCreated)
        XCTAssertEqual(groupCreatedEvents.count, 2)
    }

    func testSessionDuration() {
        let duration = service.sessionDuration
        XCTAssertGreaterThanOrEqual(duration, 0)
    }

    func testExportEventsAsJSON() {
        service.track(.appLaunch, parameters: ["test": "value"])

        let json = service.exportEventsAsJSON()

        XCTAssertTrue(json.contains("app_launch"))
        XCTAssertTrue(json.contains("test"))
        XCTAssertTrue(json.contains("value"))
    }

    func testDiscrepanciesWhenMatching() {
        // When counts match, no discrepancies
        let discrepancies = service.getDiscrepancies(
            actualCheckIns: 0,
            actualGroupsCreated: 0,
            actualAchievements: 0
        )

        XCTAssertEqual(discrepancies.count, 0)
    }

    func testDiscrepanciesWhenMismatched() {
        service.track(.checkIn)
        service.track(.checkIn)

        // Tracked 2 check-ins but actual is 5
        let discrepancies = service.getDiscrepancies(
            actualCheckIns: 5,
            actualGroupsCreated: 0,
            actualAchievements: 0
        )

        XCTAssertEqual(discrepancies.count, 1)
        XCTAssertEqual(discrepancies.first?.eventName, "check_in")
        XCTAssertEqual(discrepancies.first?.localCount, 2)
        XCTAssertEqual(discrepancies.first?.expectedCount, 5)
    }

    // MARK: - Convenience Method Tests

    func testTrackScreenView() {
        service.trackScreenView("home")

        XCTAssertEqual(service.recentEvents.count, 1)
        XCTAssertEqual(service.recentEvents.first?.name, "screen_view")
        XCTAssertEqual(service.recentEvents.first?.parameters["screen_name"], "home")
    }

    func testTrackSignInAttempted() {
        service.trackSignInAttempted(method: "apple")

        XCTAssertEqual(service.recentEvents.first?.name, "sign_in_attempted")
        XCTAssertEqual(service.recentEvents.first?.parameters["method"], "apple")
    }

    func testTrackSignInSuccess() {
        service.trackSignInSuccess(method: "anonymous", isNewUser: true)

        XCTAssertEqual(service.recentEvents.first?.name, "sign_in_success")
        XCTAssertEqual(service.recentEvents.first?.parameters["method"], "anonymous")
        XCTAssertEqual(service.recentEvents.first?.parameters["is_new_user"], "true")
    }

    func testTrackSignInFailure() {
        service.trackSignInFailure(method: "apple", errorCode: "auth_error")

        XCTAssertEqual(service.recentEvents.first?.name, "sign_in_failure")
        XCTAssertEqual(service.recentEvents.first?.parameters["method"], "apple")
        XCTAssertEqual(service.recentEvents.first?.parameters["error_code"], "auth_error")
    }

    func testTrackGroupCreated() {
        service.trackGroupCreated(groupId: "group123", hasBoundary: true, isPublic: false)

        XCTAssertEqual(service.recentEvents.first?.name, "group_created")
        XCTAssertEqual(service.recentEvents.first?.parameters["group_id"], "group123")
        XCTAssertEqual(service.recentEvents.first?.parameters["has_boundary"], "true")
        XCTAssertEqual(service.recentEvents.first?.parameters["is_public"], "false")
    }

    func testTrackCheckIn() {
        service.trackCheckIn(groupId: "group456", isManual: true)

        XCTAssertEqual(service.recentEvents.first?.name, "check_in")
        XCTAssertEqual(service.recentEvents.first?.parameters["group_id"], "group456")
        XCTAssertEqual(service.recentEvents.first?.parameters["is_manual"], "true")
    }

    func testTrackCheckOut() {
        service.trackCheckOut(groupId: "group789", isManual: false, durationMinutes: 45)

        XCTAssertEqual(service.recentEvents.first?.name, "check_out")
        XCTAssertEqual(service.recentEvents.first?.parameters["group_id"], "group789")
        XCTAssertEqual(service.recentEvents.first?.parameters["is_manual"], "false")
        XCTAssertEqual(service.recentEvents.first?.parameters["duration_minutes"], "45")
    }

    func testTrackAchievementUnlocked() {
        service.trackAchievementUnlocked(achievementType: "first_check_in", points: 10)

        XCTAssertEqual(service.recentEvents.first?.name, "achievement_unlocked")
        XCTAssertEqual(service.recentEvents.first?.parameters["achievement_type"], "first_check_in")
        XCTAssertEqual(service.recentEvents.first?.parameters["points"], "10")
    }

    func testTrackMessageSent() {
        service.trackMessageSent(groupId: "chat_group", messageLength: 150)

        XCTAssertEqual(service.recentEvents.first?.name, "message_sent")
        XCTAssertEqual(service.recentEvents.first?.parameters["group_id"], "chat_group")
        XCTAssertEqual(service.recentEvents.first?.parameters["message_length"], "150")
    }

    func testTrackError() {
        service.trackError(errorType: "network", context: "fetchData", message: "Connection timeout")

        XCTAssertEqual(service.recentEvents.first?.name, "error_occurred")
        XCTAssertEqual(service.recentEvents.first?.parameters["error_type"], "network")
        XCTAssertEqual(service.recentEvents.first?.parameters["context"], "fetchData")
        XCTAssertEqual(service.recentEvents.first?.parameters["message"], "Connection timeout")
    }
}
