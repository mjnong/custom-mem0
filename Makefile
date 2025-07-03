PHONY: all clean

all: clean build

.PHONY: run-dev run mcp-inspect




run-dev:
	@echo "Running the application..."
	@fastapi dev src/app/main.py

run:
	@echo "Running the application in production mode..."
	@fastapi run src/app/main.py --host 0.0.0.0 --port 8000


mcp-inspect:
	@echo "Running MCP inspection..."
	@npx @modelcontextprotocol/inspector