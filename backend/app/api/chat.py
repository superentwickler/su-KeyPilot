# Chat: AI-Agent (Ollama)
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.models.schemas import ChatRequest, ChatResponse
from app.services.agent import execute

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("", response_model=ChatResponse)
async def chat(req: ChatRequest, db: AsyncSession = Depends(get_db)):
    try:
        reply, action = await execute(db, req.message)
        return ChatResponse(reply=reply, action_performed=action)
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
