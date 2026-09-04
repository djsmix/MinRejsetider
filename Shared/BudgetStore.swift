import Foundation

/// Tæller API-kald pr. kalendermåned i App Group.
/// 50.000/mdr ≈ 1.666/dag ≈ 69/time i snit — derfor skal vi ligge LANGT under.
final class BudgetStore {
    static let shared = BudgetStore()
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedConstants.appGroup) ?? .standard
    }
    private init() {}

    private func monthKey(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        return "apiCalls_" + f.string(from: date)
    }

    func currentCount() -> Int {
        defaults?.integer(forKey: monthKey()) ?? 0
    }

    func limit() -> Int { SharedConstants.monthlyLimit }

    func remaining() -> Int { max(0, limit() - currentCount()) }

    func percentUsed() -> Double {
        Double(currentCount()) / Double(limit())
    }

    /// Kald DENNE før hvert netværkskald. Returnerer false hvis der ikke må kaldes.
    /// hardStop respekterer Settings.hardStopAtLimit.
    func tryConsume(hardStop: Bool = true) -> Bool {
        let count = currentCount()
        if hardStop && count >= limit() { return false }
        // advarselstærskler håndteres i UI — her tillader vi, men tæller
        defaults?.set(count + 1, forKey: monthKey())
        defaults?.set(Date(), forKey: "lastCall")
        return true
    }

    /// Uden at tælle: må vi kalde?
    func canCall(hardStop: Bool = true) -> Bool {
        if hardStop && currentCount() >= limit() { return false }
        return true
    }

    func lastCall() -> Date? {
        defaults?.object(forKey: "lastCall") as? Date
    }

    var statusText: String {
        "\(currentCount()) / \(limit()) kald brugt i \(monthKey().replacingOccurrences(of: "apiCalls_", with: ""))"
    }
}
