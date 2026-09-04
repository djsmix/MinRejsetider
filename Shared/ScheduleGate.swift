import Foundation

/// Styrer HVORNÅR der må bruges API-kald.
/// Regel: appen må hente når den er åben (med min-interval).
/// Widgets må KUN hente inden for definerede tidsvinduer.
enum ScheduleGate {

    static func minutesSinceMidnight(_ d: Date, cal: Calendar = .current) -> Int {
        let c = cal.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0)*60 + (c.minute ?? 0)
    }

    static func isActive(now: Date = Date(), windows: [TimeWindow], cal: Calendar = .current) -> Bool {
        let wd = cal.component(.weekday, from: now)
        let m = minutesSinceMidnight(now, cal: cal)
        return windows.contains { w in
            w.enabled && w.weekdays.contains(wd) && m >= w.startMinutes && m < w.endMinutes
        }
    }

    /// Næste vindues-start efter `date`. Bruges til widget refresh uden kald.
    static func nextWindowStart(after date: Date = Date(), windows: [TimeWindow], cal: Calendar = .current) -> Date? {
        let active = windows.filter { $0.enabled }
        guard !active.isEmpty else { return nil }
        // kig 8 dage frem
        for dayOffset in 0..<8 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            let wd = cal.component(.weekday, from: day)
            for w in active where w.weekdays.contains(wd) {
                var comps = cal.dateComponents([.year,.month,.day], from: day)
                comps.hour = w.startMinutes/60; comps.minute = w.startMinutes%60; comps.second = 0
                if let start = cal.date(from: comps), start > date {
                    return start
                }
            }
        }
        return nil
    }

    /// Må widgetten lave netværkskald lige nu?
    static func widgetMayFetch(now: Date, lastFetch: Date?, windows: [TimeWindow]) -> Bool {
        guard isActive(now: now, windows: windows) else { return false }
        if let last = lastFetch, now.timeIntervalSince(last) < SharedConstants.minWidgetInterval {
            return false
        }
        return true
    }

    /// Må appen (foreground) hente lige nu? Appen er åben = brugerhandling,
    /// så vi tillader også uden for vindue, men respekterer min-interval.
    static func appMayFetch(now: Date, lastFetch: Date?) -> Bool {
        if let last = lastFetch, now.timeIntervalSince(last) < SharedConstants.minAppInterval {
            return false
        }
        return true
    }
}
