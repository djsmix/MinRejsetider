import Foundation

/// Alle københavnske metrostationer med korrekte Rejseplanen stop-ID'er.
/// Hentet én gang via location.name "(Metro)" — derfor koster stationsvalg
/// i appen 0 API-kald (søgning sker lokalt).
/// `lines` er kun vejledning — filtrering sker via Station.lineFilter (tom = alle).
struct MetroStation: Identifiable, Hashable {
    var id: String { extId }
    var extId: String
    var name: String   // API-navn, bruges som visningsnavn
    var short: String  // kort navn til listen
    var lines: String  // fx "M1 · M2"
}

enum MetroStations {
    static let all: [MetroStation] = [
        .init(extId: "8603342", name: "Aksel Møllers Have St. (Metro)", short: "Aksel Møllers Have", lines: "M3"),
        .init(extId: "8603324", name: "Amager Strand St. (Metro)", short: "Amager Strand", lines: "M2"),
        .init(extId: "8603321", name: "Amagerbro St. (Metro)", short: "Amagerbro", lines: "M2"),
        .init(extId: "8603313", name: "Bella Center St. (Metro)", short: "Bella Center", lines: "M1"),
        .init(extId: "8603309", name: "Christianshavn St. (Metro)", short: "Christianshavn", lines: "M1 · M2"),
        .init(extId: "8603311", name: "DR Byen St. (Metro)", short: "DR Byen", lines: "M1"),
        .init(extId: "8603348", name: "Enghave Brygge St. (Metro)", short: "Enghave Brygge", lines: "M4"),
        .init(extId: "8603344", name: "Enghave Plads St. (Metro)", short: "Enghave Plads", lines: "M3"),
        .init(extId: "8603304", name: "Fasanvej St. (Metro)", short: "Fasanvej", lines: "M1 · M2"),
        .init(extId: "8603326", name: "Femøren St. (Metro)", short: "Femøren", lines: "M2"),
        .init(extId: "8603302", name: "Flintholm St. (Metro)", short: "Flintholm", lines: "M1 · M2"),
        .init(extId: "8603306", name: "Forum St. (Metro)", short: "Forum", lines: "M1 · M2"),
        .init(extId: "8603343", name: "Frederiksberg Allé St. (Metro)", short: "Frederiksberg Allé", lines: "M3"),
        .init(extId: "8603305", name: "Frederiksberg St. (Metro)", short: "Frederiksberg", lines: "M1 · M2 · M3"),
        .init(extId: "8603332", name: "Gammel Strand St. (Metro)", short: "Gammel Strand", lines: "M3 · M4"),
        .init(extId: "8603347", name: "Havneholmen St. (Metro)", short: "Havneholmen", lines: "M4"),
        .init(extId: "8603310", name: "Islands Brygge St. (Metro)", short: "Islands Brygge", lines: "M1"),
        .init(extId: "8603327", name: "Kastrup St. (Metro)", short: "Kastrup", lines: "M2"),
        .init(extId: "8603308", name: "Kongens Nytorv St. (Metro)", short: "Kongens Nytorv", lines: "M1 · M2 · M3 · M4"),
        .init(extId: "8603330", name: "København H (Metro)", short: "København H", lines: "M3 · M4"),
        .init(extId: "8603351", name: "København Syd St. (Metro)", short: "København Syd", lines: "M4"),
        .init(extId: "8603328", name: "Københavns Lufthavn St. (Metro)", short: "Lufthavnen", lines: "M2"),
        .init(extId: "8603322", name: "Lergravsparken St. (Metro)", short: "Lergravsparken", lines: "M2"),
        .init(extId: "8603303", name: "Lindevang St. (Metro)", short: "Lindevang", lines: "M1 · M2"),
        .init(extId: "8603333", name: "Marmorkirken St. (Metro)", short: "Marmorkirken", lines: "M3 · M4"),
        .init(extId: "8603350", name: "Mozarts Plads St. (Metro)", short: "Mozarts Plads", lines: "M4"),
        .init(extId: "8603346", name: "Nordhavn St. (Metro)", short: "Nordhavn", lines: "M4"),
        .init(extId: "8603341", name: "Nuuks Plads St. (Metro)", short: "Nuuks Plads", lines: "M3"),
        .init(extId: "8603339", name: "Nørrebro St. (Metro)", short: "Nørrebro", lines: "M3"),
        .init(extId: "8603340", name: "Nørrebros Runddel St. (Metro)", short: "Nørrebros Runddel", lines: "M3"),
        .init(extId: "8603307", name: "Nørreport St. (Metro)", short: "Nørreport", lines: "M1 · M2"),
        .init(extId: "8603345", name: "Orientkaj St. (Metro)", short: "Orientkaj", lines: "M4"),
        .init(extId: "8603336", name: "Poul Henningsens Plads St. (Metro)", short: "Poul Henningsens Pl.", lines: "M3"),
        .init(extId: "8603331", name: "Rådhuspladsen St. (Metro)", short: "Rådhuspladsen", lines: "M3 · M4"),
        .init(extId: "8603338", name: "Skjolds Plads St. (Metro)", short: "Skjolds Plads", lines: "M3"),
        .init(extId: "8603349", name: "Sluseholmen St. (Metro)", short: "Sluseholmen", lines: "M4"),
        .init(extId: "8603312", name: "Sundby St. (Metro)", short: "Sundby", lines: "M1"),
        .init(extId: "8603335", name: "Trianglen St. (Metro)", short: "Trianglen", lines: "M3"),
        .init(extId: "8603301", name: "Vanløse St. (Metro)", short: "Vanløse", lines: "M1 · M2"),
        .init(extId: "8603317", name: "Vestamager St. (Metro)", short: "Vestamager", lines: "M1"),
        .init(extId: "8603337", name: "Vibenshus Runddel St. (Metro)", short: "Vibenshus Runddel", lines: "M3"),
        .init(extId: "8603315", name: "Ørestad St. (Metro)", short: "Ørestad", lines: "M1"),
        .init(extId: "8603323", name: "Øresund St. (Metro)", short: "Øresund", lines: "M2"),
        .init(extId: "8603334", name: "Østerport St. (Metro)", short: "Østerport", lines: "M3 · M4"),
    ]

    /// Typiske endestationer som retningsforslag (M3 er ring — brug live-afgange).
    static func termini(forLineHint lines: String) -> [String] {
        var out: [String] = []
        if lines.contains("M1") { out += ["Vestamager", "Vanløse"] }
        if lines.contains("M2") { out += ["Lufthavnen", "Vanløse"] }
        if lines.contains("M4") { out += ["København Syd", "Orientkaj"] }
        return Array(Set(out)).sorted()
    }

    static func search(_ query: String) -> [MetroStation] {        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all.sorted { $0.short < $1.short } }
        return all.filter { $0.short.lowercased().contains(q) || $0.name.lowercased().contains(q) }
            .sorted { $0.short < $1.short }
    }
}
