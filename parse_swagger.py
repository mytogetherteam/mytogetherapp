import json

def parse_swagger():
    encodings = ['utf-16', 'utf-8', 'latin-1']
    data = None
    
    for enc in encodings:
        try:
            with open('swagger.json', 'r', encoding=enc) as f:
                data = json.load(f)
            break
        except Exception:
            continue
            
    if not data:
        return

    paths = data.get('paths', {})
    target_path = '/api/mobile/shops/{shopId}'
    if target_path in paths:
        methods = paths[target_path]
        if 'get' in methods:
            get_op = methods['get']
            print(f"Path: {target_path}")
            print("Parameters:")
            params = get_op.get('parameters', [])
            for p in params:
                print(f"  - Name: {p.get('name')}")
                print(f"    In: {p.get('in')}")
                print(f"    Required: {p.get('required')}")
                print(f"    Schema: {p.get('schema')}")
    else:
        print(f"Path {target_path} not found exactly. Checking similar...")
        for p in paths:
            if 'shops/' in p and '{' in p:
                print(f"Found: {p}")

if __name__ == "__main__":
    parse_swagger()
