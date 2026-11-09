import Foundation
import Testing
@testable import IleDelbeCore

@Suite struct AgendaTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func ev(_ id: String, start: TimeInterval, dur: TimeInterval = 1800, allDay: Bool = false,
                    title: String = "E") -> AgendaEvent {
        AgendaEvent(id: id, title: title, start: now.addingTimeInterval(start),
                    end: now.addingTimeInterval(start + dur), isAllDay: allDay, colorHex: nil, meetingURL: nil)
    }

    @Test func upcomingFiltersSortsLimits() {
        let events = [
            ev("allday", start: 600, allDay: true),
            ev("ended", start: -7200, dur: 3600),
            ev("far", start: 90_000),
            ev("c", start: 7200),
            ev("inprogress", start: -600, dur: 1800),
            ev("b", start: 600),
        ]
        #expect(Agenda.upcoming(events, now: now).map(\.id) == ["inprogress", "b"])
        #expect(Agenda.upcoming([ev("x", start: 100)], now: now).map(\.id) == ["x"])
    }

    @Test func infoLine() {
        #expect(Agenda.infoLine([ev("a", start: 720, title: "Point produit")], now: now) == "Point produit dans 12 min")
        #expect(Agenda.infoLine([ev("a", start: 30, title: "Point produit")], now: now) == "Point produit dans 1 min")
        #expect(Agenda.infoLine([ev("a", start: 3660)], now: now) == nil)
        #expect(Agenda.infoLine([], now: now) == nil)
        #expect(Agenda.infoLine([ev("a", start: -60)], now: now) == nil)
    }

    @Test func infoLineSkipsInProgressEvent() {
        let events = [ev("cur", start: -600, dur: 1800), ev("next", start: 600, title: "Revue")]
        #expect(Agenda.infoLine(events, now: now) == "Revue dans 10 min")
    }

    @Test func meetingLinks() {
        #expect(MeetingLink.find(in: ["Lien : https://meet.google.com/abc-defg-hij merci"])
            == URL(string: "https://meet.google.com/abc-defg-hij"))
        #expect(MeetingLink.find(in: [nil, "https://acme.zoom.us/j/123456789?pwd=x"])
            == URL(string: "https://acme.zoom.us/j/123456789?pwd=x"))
        let teams = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_x/0?context=y"
        #expect(MeetingLink.find(in: [teams]) == URL(string: teams))
        #expect(MeetingLink.find(in: ["https://example.com"]) == nil)
        #expect(MeetingLink.find(in: [nil, nil]) == nil)
        #expect(MeetingLink.find(in: ["https://zoom.us/j/1", "https://meet.google.com/aaa-bbbb-ccc"])
            == URL(string: "https://zoom.us/j/1"))
        #expect(MeetingLink.find(in: ["(https://meet.google.com/abc-defg-hij)."])
            == URL(string: "https://meet.google.com/abc-defg-hij"))
    }
}
