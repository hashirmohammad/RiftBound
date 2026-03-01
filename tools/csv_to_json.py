import csv, json, sys

in_csv = sys.argv[1]
out_json = sys.argv[2]

def parse_int(x):
    x = (x or "").strip()
    return int(x) if x.isdigit() else 0

def parse_tags(s):
    return [t.strip() for t in (s or "").split(",") if t.strip()]

cards = []

with open(in_csv, newline="", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        cards.append({
            "card_id": row.get("Card Number", "").strip(),
            "set_code": row.get("Set", "").strip(),
            "name": row.get("Card Name", "").strip(),
            "cost": parse_int(row.get("Energy")),
            "might": parse_int(row.get("Might")),
            "domain": row.get("Domain", "").strip(),
            "type": row.get("Card Type", "").strip(),
            "keywords": parse_tags(row.get("Tags")),
            "rules_text": row.get("Ability", "").strip(),
            "rarity": row.get("Rarity", "").strip(),
            "artist": row.get("Artist", "").strip(),
            "image_url": row.get("Image URL", "").strip()
        })

with open(out_json, "w", encoding="utf-8") as f:
    json.dump(cards, f, ensure_ascii=False, indent=2)

print(f"Wrote {len(cards)} cards to {out_json}")