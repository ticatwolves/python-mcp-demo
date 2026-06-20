"""
FastMCP quickstart example.

Run from the repository root:
    uv run examples/snippets/servers/fastmcp_quickstart.py
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from mcp.server.fastmcp import FastMCP

# Create an MCP server
mcp = FastMCP("Demo", json_response=True)

# Add an addition tool
@mcp.tool()
async def add(a: int, b: int) -> int:
    """Add two numbers"""
    return a + b

# Add a dynamic greeting resource
@mcp.resource("greeting://{name}")
async def get_greeting(name: str) -> str:
    """Get a personalized greeting"""
    return f"Hello, {name}!"

# Add a prompt
@mcp.prompt()
async def greet_user(name: str, style: str = "friendly") -> str:
    """Generate a greeting prompt"""
    styles = {
        "friendly": "Please write a warm, friendly greeting",
        "formal": "Please write a formal, professional greeting",
        "casual": "Please write a casual, relaxed greeting",
    }

    return f"{styles.get(style, styles['friendly'])} for someone named {name}."

@asynccontextmanager
async def app_lifespan(fastapi_app: FastAPI):
    async with mcp.session_manager.run():
        yield

app = FastAPI(title="Production MCP API Gateway", lifespan=app_lifespan)

@app.get("/health")
async def health_check():
    return JSONResponse(status_code=200, content={"status": "healthy"})

app.mount("/", mcp.streamable_http_app())

# Run with streamable HTTP transport
if __name__ == "__main__":
    mcp.run(transport="streamable-http")
