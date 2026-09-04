import Foundation

/// Nedtælling til afgang ud fra "HH:MM" / "HH:MM:SS" (planlagt eller realtime).
/// Bruges både i app (tikkende sekunder) og widget (live timer-tekst).
enum Countdown {

    /// Afgangstidspunkt som Date (i dag; +1 døgn ved midnatsrulning).
    static func date(plan: String, rt: String? = nil, now: Date = Date(), cal: Calendar = .current) -> Date? {
        let s = (rt?.isEmpty == false ? rt! : plan)
        let p = s.split(separator: ":").compactMap { Int($0) }
        guard p.count >= 2 else { return nil }
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = p[0]; comps.minute = p[1]; comps.second = p.count >= 3 ? p[2] : 0
        guard let cand = cal.date(from: comps) else { return nil }
        // Tavlen viser næste 60 min — er tiden >30 min overskredet, er det i morgen
        if cand < now.addingTimeInterval(-30*60) {
            return cal.date(byAdding: .day, value: 1, to: cand)
        }
        return cand
    }

    static func secondsUntil(_ d: Departure, now: Date = Date()) -> Int? {
        guard let t = date(plan: d.time, rt: d.rtTime, now: now) else { return nil }
        return Int(t.timeIntervalSince(now).rounded())
    }

    /// Hovedvisning: sekunder (M:SS) vises KUN når der er <= 120 sek. til afgang.
    struct Display { var main: String; var sub: String; var urgent: Bool; var live: Bool }

    static func display(for d: Departure, now: Date = Date()) -> Display {
        guard let secs = secondsUntil(d, now: now) else {
            return Display(main: d.displayTime, sub: "", urgent: false, live: false)
        }
        if secs <= 0 && secs > -90 {
            return Display(main: "Nu", sub: d.displayTime, urgent: true, live: true)
        }
        if secs <= 120 && secs > 0 {
            return Display(main: String(format: "%d:%02d", secs/60, secs%60),
                           sub: "kl. \(d.displayTime)", urgent: true, live: true)
        }
        if secs < 3600 && secs > 0 {
            let m = Int((Double(secs)/60).rounded())
            return Display(main: "om \(m) min", sub: "kl. \(d.displayTime)", urgent: d.isDelayed, live: false)
        }
        return Display(main: "kl. \(d.displayTime)", sub: "", urgent: false, live: false)
    }
}
