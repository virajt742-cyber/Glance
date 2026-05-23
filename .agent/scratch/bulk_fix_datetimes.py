import os
import re

files = [
    r"tests\test_provider_notes_and_review_reply.py",
    r"tests\test_provider_metrics.py",
    r"tests\test_promos.py",
    r"tests\test_notification_hooks.py",
    r"tests\test_marketplace_features.py",
    r"tests\test_chat_read_receipts.py",
    r"tests\test_booking_slots.py",
    r"tests\test_booking_invoices.py"
]

for file_path in files:
    full_path = os.path.join(os.getcwd(), file_path)
    if not os.path.exists(full_path):
        print(f"Skipping {file_path}, not found.")
        continue
        
    with open(full_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Replace datetime.utcnow()
    new_content = content.replace("datetime.utcnow()", "datetime.now(timezone.utc)")
    
    # Ensure timezone is imported from datetime
    if "from datetime import" in new_content and "timezone" not in new_content:
        new_content = re.sub(r"from datetime import ([^,\n]+)", r"from datetime import \1, timezone", new_content)
    elif "from datetime import" not in new_content and "import datetime" in new_content:
        # If it's just 'import datetime', we need to check if they use datetime.timezone
        pass # most likely they use datetime.datetime.now(datetime.timezone.utc) but here it's datetime.now
    
    if new_content != content:
        with open(full_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed {file_path}")
    else:
        print(f"No changes needed for {file_path}")
