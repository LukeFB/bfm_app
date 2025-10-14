from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

# Our other files
import db
import auth

app = FastAPI()

# Allow CORS for frontend testing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
    
@app.get("/entries")
async def list_entries():
    return db.get_entries()

@app.post("/entries")
async def create_entry(data: dict, username: str = Depends(auth.get_current_user)):
    title = data.get("title")
    description = data.get("description")
    if not title or not description:
        raise HTTPException(400, "Title and description required")
    db.add_entry(username, title, description)
    return {"ok": True}
    
frontend_path = os.path.join(os.path.dirname(__file__), "backend-ui", "build")
app.mount("/", StaticFiles(directory=frontend_path, html=True), name="frontend")