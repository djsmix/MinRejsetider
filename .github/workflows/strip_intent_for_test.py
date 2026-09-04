"""TEST-variant: fjern App Intents fra widgetten for at isolere eSign-installationsfejl.
- Sletter Widget/StationIntent.swift
- Erstatter Provider med minimal statisk provider (viser blot 'Test', 0 kald)
- Skifter AppIntentConfiguration -> StaticConfiguration
Brug: python3 .github/workflows/strip_intent_for_test.py
"""
import pathlib
import re

root = pathlib.Path(".")

intent_file = root / "Widget" / "StationIntent.swift"
if intent_file.exists():
    intent_file.unlink()
    print("slettet Widget/StationIntent.swift")

widget = root / "Widget" / "RejsetiderWidget.swift"
text = widget.read_text(encoding="utf-8")

static_provider = '''struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> RejsetiderEntry {
        RejsetiderEntry(date: Date(), departures: [], active: true, nextWindow: nil,
                        budgetUsed: 0, stationLabel: "Test", needsKey: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (RejsetiderEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RejsetiderEntry>) -> Void) {
        let e = placeholder(in: context)
        completion(Timeline(entries: [e], policy: .after(Date().addingTimeInterval(3600))))
    }
}
'''

# Erstat alt fra "struct Provider" til linjen før "/// Fælles hjælpere"
pattern = re.compile(r"struct Provider: AppIntentTimelineProvider \{(?s:.*?)\n\}\n\n(?=/// Fælles hjælpere)")
assert pattern.search(text), "fandt ikke Provider-blokken"
text = pattern.sub(static_provider + "\n", text)

old_config = "AppIntentConfiguration(kind: kind, intent: StationIntent.self, provider: Provider())"
new_config = "StaticConfiguration(kind: kind, provider: Provider())"
assert old_config in text, "fandt ikke AppIntentConfiguration-linjen"
text = text.replace(old_config, new_config)

widget.write_text(text, encoding="utf-8")
print("Provider gjort statisk + StaticConfiguration sat.")
