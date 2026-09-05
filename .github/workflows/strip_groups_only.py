"""Variant C: behold ActivityKit/widget-extension, men fjern App Groups entitlements.
Bruges til gratis certs (eSign/Sideloadly/SideStore), hvor custom App Groups
ikke er dækket af provisioning-profilen.

Live Activity-data sendes gennem ActivityKit og kræver derfor ikke App Groups.

Brug: python3 .github/workflows/strip_groups_only.py
"""
import pathlib

try:
    import yaml
except ImportError:
    raise SystemExit("pyyaml mangler: kør 'pip install pyyaml' først")

proj = pathlib.Path("project.yml")
data = yaml.safe_load(proj.read_text(encoding="utf-8"))

for name, target in data.get("targets", {}).items():
    if "entitlements" in target:
        del target["entitlements"]
        print(f"fjernet entitlements fra {name}")

proj.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True), encoding="utf-8")
print("Targets:", list(data.get("targets", {}).keys()))
