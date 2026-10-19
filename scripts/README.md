# scripts

Run every script from the project root (they use root-relative paths).

- `dev/*.dart` – one-off code/asset fix scripts, e.g. `dart scripts/dev/update_visa_data.dart`.
- `swagger/` – API swagger/docs dumps. `cd scripts/swagger && python3 parse_swagger.py` (reads `swagger.json` from the current folder).
- `archive/` – old bug report and patch kept for reference; safe to delete.
