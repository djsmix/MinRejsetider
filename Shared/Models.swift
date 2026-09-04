import Foundation

// MARK: - Fælles konstanter
enum SharedConstants {
    static let appGroup = "group.dk.minrejsetider.shared"
    /// INGEN nøgle i koden — repoet er offentligt. Indsæt dit eget accessId
    /// i appen (Indstillinger) og på hver widget (langt tryk → Rediger).
    static let defaultAccessId = ""
    static let monthlyLimit = 50_000
    /// Min interval (sek) mellem API-kald fra appen når den er åben
    static let minAppInterval: TimeInterval = 60
    /// Min interval (sek) mellem widget-kald
    static let minWidgetInterval: TimeInterval = 300 // 5 min
    /// Cache TTL
    static let cacheTTL: TimeInterval = 180
}

// MARK: - Station (bruger indtaster selv)
struct Station: Codable, Identifiable, Hashable {
    var id: String   // Rejseplanen stop-ID, fx "8603330"
    var name: String // Visningsnavn, fx "Kongens Nytorv St. (Metro)"
    var lineFilter: String // fx "M1,M2" eller "" = alle
    var directionFilter: String // legacy fritekst (indeholder-match) eller "" = alle
    var directions: [String] = [] // valgte retninger (tom = alle). Match er tilgivende.

    var identifier: String { id }

    /// Kort navn til overskrifter ("Kongens Nytorv St. (Metro)" → "Kongens Nytorv")
    var shortName: String {
        name.replacingOccurrences(of: " St. (Metro)", with: "")
            .replacingOccurrences(of: " (Metro)", with: "")
    }

    init(id: String, name: String, lineFilter: String = "", directionFilter: String = "", directions: [String] = []) {
        self.id = id; self.name = name
        self.lineFilter = lineFilter; self.directionFilter = directionFilter
        self.directions = directions
    }

    // Bagudkompatibel decoding: gamle gemte indstillinger uden 'directions' overlever
    enum CodingKeys: String, CodingKey { case id, name, lineFilter, directionFilter, directions }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        lineFilter = try c.decodeIfPresent(String.self, forKey: .lineFilter) ?? ""
        directionFilter = try c.decodeIfPresent(String.self, forKey: .directionFilter) ?? ""
        directions = try c.decodeIfPresent([String].self, forKey: .directions) ?? []
    }
}

// MARK: - Tidsvindue (widgets må KUN kalde her)
struct TimeWindow: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    /// 1=Søn ... 7=Lør (Calendar.component(.weekday))
    var weekdays: Set<Int> = [2,3,4,5,6]
    var startMinutes: Int = 6*60        // 06:00
    var endMinutes: Int = 9*60          // 09:00
    var enabled: Bool = true

    var label: String {
        let days = TimeWindow.shortDays(weekdays)
        return "\(days) \(TimeWindow.mm(startMinutes))–\(TimeWindow.mm(endMinutes))"
    }

    static func mm(_ m: Int) -> String {
        String(format: "%02d:%02d", m/60, m%60)
    }
    static func shortDays(_ s: Set<Int>) -> String {
        // man-fre genvej
        if s == [2,3,4,5,6] { return "Man–fre" }
        if s == [2,3,4,5,6,7] { return "Man–lør" }
        if s == [1,7] { return "Weekend" }
        let names = [1:"Søn",2:"Man",3:"Tir",4:"Ons",5:"Tor",6:"Fre",7:"Lør"]
        return s.sorted().compactMap { names[$0] }.joined(separator:",")
    }
}

// MARK: - Afgang
struct Departure: Codable, Identifiable, Hashable {
    var id: String { "\(stopId)-\(time)-\(line)-\(direction)" }
    var stopId: String
    var stopName: String
    var line: String      // "M1"
    var name: String      // "M1"
    var direction: String
    var time: String      // planlagt "14:32"
    var rtTime: String?   // realtime
    var track: String?
    var cancelled: Bool
    var delayMinutes: Int

    var displayTime: String { rtTime ?? time }
    var isDelayed: Bool { delayMinutes > 1 }
}

// MARK: - Settings (gemt i App Group)
struct AppSettings: Codable {
    var accessId: String = SharedConstants.defaultAccessId
    var stations: [Station] = [
        Station(id: "8603330", name: "København H (Metro)", lineFilter: "", directionFilter: ""),
        Station(id: "8603308", name: "Kongens Nytorv St. (Metro)", lineFilter: "", directionFilter: "")
    ]
    var windows: [TimeWindow] = [
        TimeWindow(weekdays: [2,3,4,5,6], startMinutes: 6*60, endMinutes: 9*60),
        TimeWindow(weekdays: [2,3,4,5,6], startMinutes: 15*60, endMinutes: 18*60+30)
    ]
    var hardStopAtLimit: Bool = true
}
