import os
import time
import signal
import asyncio
from typing import Dict, List, Optional
from datetime import datetime
from fastapi import FastAPI, Request, HTTPException, Response
from fastapi.responses import RedirectResponse, HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from pydantic import BaseModel, HttpUrl, Field, validator
from concurrent.futures import ThreadPoolExecutor
import uvloop
import nanoid

# Use uvloop for better performance (faster than asyncio's default event loop)
asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())

# Models
class CreateURLRequest(BaseModel):
    url: str
    
    @validator('url')
    def url_must_be_valid(cls, v):
        if not v.startswith('http://') and not v.startswith('https://'):
            raise ValueError('URL must start with http:// or https://')
        return v

class URLResponse(BaseModel):
    original_url: str
    short_code: str
    short_url: str
    created_at: datetime
    access_count: int

class AnalyticsResponse(BaseModel):
    total_urls: int
    total_clicks: int
    urls: List[URLResponse]

# In-memory store with thread-safe operations
class URLStore:
    def __init__(self):
        self._store: Dict[str, dict] = {}
        self._lock = asyncio.Lock()
        self._executor = ThreadPoolExecutor(max_workers=4)  # For CPU-bound tasks
    
    async def add(self, short_code: str, url_data: dict):
        async with self._lock:
            self._store[short_code] = url_data
    
    async def get(self, short_code: str) -> Optional[dict]:
        # Read operations don't need a lock for better concurrency
        return self._store.get(short_code)
    
    async def increment_access_count(self, short_code: str) -> bool:
        # Using a thread for atomic increment (CPU-bound)
        def _increment():
            if short_code in self._store:
                self._store[short_code]['access_count'] += 1
                return True
            return False
        
        # Run in a thread to avoid blocking the event loop
        return await asyncio.get_event_loop().run_in_executor(
            self._executor, _increment
        )
    
    async def get_all(self) -> List[dict]:
        # Avoid locking for read operations
        return list(self._store.values())
    
    async def count(self) -> int:
        return len(self._store)
    
    async def total_clicks(self) -> int:
        # Using a thread for summing (CPU-bound)
        def _sum_clicks():
            return sum(url['access_count'] for url in self._store.values())
        
        # Run in a thread to avoid blocking the event loop
        return await asyncio.get_event_loop().run_in_executor(
            self._executor, _sum_clicks
        )

# Initialize FastAPI with optimized settings
app = FastAPI(
    title="URL Shortener",
    description="High-performance URL shortener written in Python with FastAPI",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
)

# Add middleware for better performance
app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize URL store
url_store = URLStore()

# Serve static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Load the HTML template only once during startup
@app.on_event("startup")
async def startup_event():
    global index_html
    try:
        with open("static/index.html", "r") as f:
            app.state.index_html = f.read()
    except FileNotFoundError:
        app.state.index_html = "<h1>Failed to load index.html</h1>"

# Graceful shutdown
@app.on_event("shutdown")
async def shutdown_event():
    # Close thread pool
    url_store._executor.shutdown(wait=True)
    print("Server shutting down...")

# Add request timing middleware
@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = str(process_time)
    return response

# Routes
@app.get("/", response_class=HTMLResponse)
async def read_root():
    return HTMLResponse(content=app.state.index_html)

@app.post("/api/shorten", response_model=URLResponse)
async def create_short_url(request: CreateURLRequest):
    start_time = time.time()
    
    # Generate short code (6 characters like in Rust/Go versions)
    short_code = nanoid.generate(size=6)
    
    # Generate a unique ID
    id = nanoid.generate(size=10)
    
    # Create URL object
    url_data = {
        "id": id,
        "original_url": request.url,
        "short_code": short_code,
        "created_at": datetime.now(),
        "access_count": 0
    }
    
    # Save to in-memory store
    await url_store.add(short_code, url_data)
    
    # Log the time taken
    elapsed = time.time() - start_time
    print(f"[create_short_url] Time taken: {elapsed:.6f}s")
    
    # Get base URL from environment or use default
    base_url = os.getenv("BASE_URL", "http://localhost:3000")
    
    # Return the shortened URL
    return URLResponse(
        original_url=url_data["original_url"],
        short_code=url_data["short_code"],
        short_url=f"{base_url}/{url_data['short_code']}",
        created_at=url_data["created_at"],
        access_count=url_data["access_count"]
    )

@app.get("/{short_code}")
async def redirect_to_url(short_code: str):
    # Get URL from store
    url_data = await url_store.get(short_code)
    if not url_data:
        raise HTTPException(status_code=404, detail="URL not found")
    
    # Increment access count asynchronously (don't wait for it)
    asyncio.create_task(url_store.increment_access_count(short_code))
    
    # Redirect to original URL
    return RedirectResponse(url=url_data["original_url"], status_code=301)

@app.get("/api/urls", response_model=List[URLResponse])
async def get_all_urls():
    # Get all URLs
    urls = await url_store.get_all()
    
    # Get base URL from environment or use default
    base_url = os.getenv("BASE_URL", "http://localhost:3000")
    
    # Convert to response DTOs
    responses = [
        URLResponse(
            original_url=url["original_url"],
            short_code=url["short_code"],
            short_url=f"{base_url}/{url['short_code']}",
            created_at=url["created_at"],
            access_count=url["access_count"]
        )
        for url in urls
    ]
    
    # Sort by creation date descending
    responses.sort(key=lambda x: x.created_at, reverse=True)
    
    return responses

@app.get("/api/analytics", response_model=AnalyticsResponse)
async def get_analytics():
    # Get all URLs
    urls = await url_store.get_all()
    
    # Get base URL from environment or use default
    base_url = os.getenv("BASE_URL", "http://localhost:3000")
    
    # Convert to response DTOs
    responses = [
        URLResponse(
            original_url=url["original_url"],
            short_code=url["short_code"],
            short_url=f"{base_url}/{url['short_code']}",
            created_at=url["created_at"],
            access_count=url["access_count"]
        )
        for url in urls
    ]
    
    # Sort by access count descending
    responses.sort(key=lambda x: x.access_count, reverse=True)
    
    # Calculate analytics
    return AnalyticsResponse(
        total_urls=await url_store.count(),
        total_clicks=await url_store.total_clicks(),
        urls=responses
    )

# Handle graceful shutdown signals
def handle_exit_signal(signum, frame):
    print(f"Received exit signal {signum}")
    # Let the application shutdown hook handle the cleanup
    
# Register signal handlers
signal.signal(signal.SIGINT, handle_exit_signal)
signal.signal(signal.SIGTERM, handle_exit_signal)

if __name__ == "__main__":
    import uvicorn
    
    port = int(os.getenv("PORT", "3000"))
    
    # Run the server with optimized settings
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        log_level="info",
        workers=os.cpu_count(),  # Use all available CPU cores
        loop="uvloop",  # Use uvloop for better performance
        http="httptools",  # Use httptools for better HTTP parsing performance
        lifespan="on",
        access_log=True
    )
