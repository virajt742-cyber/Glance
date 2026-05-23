import subprocess
import json
import os
import sys

def main():
    target_dir = r"C:\Users\Viraj\.gemini\antigravity-ide\mcp\code-review-graph"
    os.makedirs(target_dir, exist_ok=True)
    
    # Start the MCP server process
    try:
        proc = subprocess.Popen(
            ["code-review-graph", "serve"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=sys.stderr,
            text=True,
            bufsize=1,
            shell=True
        )
    except Exception as e:
        print(f"Error starting process: {e}")
        return

    def send_req(req):
        print(f"Sending: {json.dumps(req)}")
        proc.stdin.write(json.dumps(req) + "\n")
        proc.stdin.flush()

    def read_res():
        while True:
            line = proc.stdout.readline()
            if not line:
                return None
            try:
                data = json.loads(line)
                print(f"Received valid JSON RPC: {data}")
                return data
            except json.JSONDecodeError:
                print(f"Ignored stdout line: {line.strip()}")

    # Initialize
    send_req({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {
                "name": "extractor",
                "version": "1.0.0"
            }
        }
    })
    
    while True:
        res = read_res()
        if not res:
            break
        if res.get("id") == 1:
            break
            
    send_req({
        "jsonrpc": "2.0",
        "method": "notifications/initialized"
    })
    
    # List tools
    send_req({
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/list",
        "params": {}
    })
    
    tools = None
    while True:
        res = read_res()
        if not res:
            break
        if res.get("id") == 2:
            tools = res.get("result", {}).get("tools", [])
            break

    print(f"Found {len(tools) if tools else 0} tools")
    
    if tools:
        for tool in tools:
            tool_name = tool.get("name")
            schema = {
                "name": tool_name,
                "description": tool.get("description", ""),
                "parameters": tool.get("inputSchema", {})
            }
            with open(os.path.join(target_dir, f"{tool_name}.json"), "w") as f:
                json.dump(schema, f, indent=2)

    # For now, let's just dump tools.json so I can inspect the output.
    with open("tools_dump.json", "w") as f:
        json.dump(tools, f, indent=2)
        
    proc.terminate()
    print("Done")

if __name__ == "__main__":
    main()
