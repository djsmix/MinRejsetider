"""Køres på macOS-runneren før xcodegen: laver en eSign-venlig variant.
- Fjerner widget-extension target (appex'er fejler ofte hos eSign/free certs)
- Fjerner App Groups entitlements (kræver betalt/eksplicit App ID)
- App-koden falder tilbage til .standard UserDefaults (se SharedCache.swift)
Brug: python3 .github/workflows/strip_for_esign.py
"""
import pathlib

try:
    import yaml
except ImportError:
    raise SystemExit("pyyaml mangler: kør 'pip install pyyaml' først")

proj = pathlib.Path("project.yml")
data = yaml.safe_load(proj.read_text(encoding="utf-8"))

targets = data.get("targets", {})
# Fjern widget-target
targets.pop("RejsetiderWidgetExtension", None)

app = targets.get("MinRejsetider", {})
# Fjern entitlements + widget-afhængighed
app.pop("entitlements", None)
app.pop("dependencies", None)
targets["MinRejsetider"] = app
data["targets"] = targets

# Schemes: kun app-target
schemes = data.get("schemes", {})
if "MinRejsetider" in schemes:
    schemes["MinRejsetider"]["build"] = {"targets": {"MinRejsetider": "all"}}
    data["schemes"] = schemes

proj.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True), encoding="utf-8")
print("project.yml strippet til app-only uden entitlements.")
print("Targets nu:", list(data["targets"].keys()))
