import os
import re

def fix_sqlalchemy_queries(directory):
    # Regex to match ClassName.query.get(id)
    # Pattern: ([A-Z][a-zA-Z0-9_]*)\.query\.get\(
    pattern = re.compile(r'([A-Z][a-zA-Z0-9_]*)\.query\.get\(')
    
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.py'):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                if '.query.get(' in content:
                    print(f"Fixing {path}")
                    # Replace ClassName.query.get(id) with db.session.get(ClassName, id)
                    new_content = pattern.sub(r'db.session.get(\1, ', content)
                    
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(new_content)

if __name__ == "__main__":
    fix_sqlalchemy_queries('app')
    fix_sqlalchemy_queries('tests')
