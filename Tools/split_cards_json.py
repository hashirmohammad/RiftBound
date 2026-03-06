import json
import os
import re
import sys

input_json = sys.argv[1]
output_folder = sys.argv[2]

def safe_filename(text):
    text = text.strip()
    text = re.sub(r'[<>:"/\\|?*]', '', text)
    text = text.replace(" ", "_")
    text = text.replace("/", "-")
    return text

with open(input_json, "r", encoding="utf-8") as f:
    cards = json.load(f)

os.makedirs(output_folder, exist_ok=True)

count = 0

for card in cards:
    card_id = card.get("card_id", "").strip()
    card_name = card.get("name", "").strip()

    if not card_name:
        continue

    if card_id:
        filename = f"{safe_filename(card_id)}_{safe_filename(card_name)}.json"
    else:
        filename = f"{safe_filename(card_name)}.json"

    filepath = os.path.join(output_folder, filename)

    with open(filepath, "w", encoding="utf-8") as out_file:
        json.dump(card, out_file, ensure_ascii=False, indent=2)

    count += 1

print(f"Created {count} individual card JSON files in {output_folder}")