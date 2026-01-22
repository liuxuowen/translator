import os
import json
import asyncio
import time
import uuid
import logging
import threading
import queue
import subprocess
import psutil
from typing import List

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import uvicorn
from dotenv import load_dotenv
import dashscope
from http import HTTPStatus
from dashscope.audio.asr import Recognition, RecognitionCallback

# Load environment variables
load_dotenv()

# Configure Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Set DashScope API Key
api_key = os.getenv("DASHSCOPE_API_KEY")
if api_key:
    dashscope.api_key = api_key

# Force print for debugging
print("=== Application Starting ===", flush=True)

app = FastAPI()

# Setup Templates
templates = Jinja2Templates(directory="templates")

# Ensure temp directory exists
os.makedirs("temp_audio", exist_ok=True)

@app.get("/", response_class=HTMLResponse)
async def get(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/monitor", response_class=HTMLResponse)
async def monitor(request: Request):
    return templates.TemplateResponse("monitor.html", {"request": request})

@app.websocket("/ws/monitor")
async def monitor_ws_endpoint(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            # Gather system stats
            cpu_percent = psutil.cpu_percent(interval=None)
            memory = psutil.virtual_memory()
            net_io = psutil.net_io_counters()
            
            # Simple app stats: count active threads might be a rough proxy for load
            active_threads = threading.active_count()
            
            stats = {
                "cpu": cpu_percent,
                "memory_percent": memory.percent,
                "memory_used": f"{memory.used / (1024*1024):.1f} MB",
                "memory_total": f"{memory.total / (1024*1024):.1f} MB",
                "net_sent": f"{net_io.bytes_sent / (1024*1024):.2f} MB",
                "net_recv": f"{net_io.bytes_recv / (1024*1024):.2f} MB",
                "active_threads": active_threads
            }
            
            await websocket.send_json(stats)
            await asyncio.sleep(1) # Update every second
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.error(f"Monitor error: {e}")

def is_contains_chinese(strs):
    for _char in strs:
        if "\u4e00" <= _char <= "\u9fa5":
            return True
    return False

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    print("DEBUG: WebSocket connected", flush=True)
    logger.info("WebSocket connected")
    loop = asyncio.get_running_loop()

    class WSCallback(RecognitionCallback):
        def on_open(self):
            print("DEBUG: DashScope ASR Session Opened", flush=True)
            logger.info("ASR Session Opened")

        def on_complete(self):
            print("DEBUG: DashScope ASR Session Completed", flush=True)
            logger.info("ASR Session Completed")

        def on_close(self):
            print("DEBUG: DashScope ASR Session Closed", flush=True)
            logger.info("ASR Session Closed")

        def on_event(self, result):
            print(f"DEBUG: ASR Event Received: {result}", flush=True)
            try:
                sentence = result.get_sentence() if hasattr(result, "get_sentence") else None
                if not sentence:
                    logger.debug("ASR event without sentence: %s", result)
                    return
                text = sentence.get("text", "")
                if not text:
                    logger.debug("ASR sentence without text: %s", sentence)
                    return

                is_end = False
                try:
                    if hasattr(result, "is_sentence_end"):
                        is_end = result.is_sentence_end(sentence)
                    elif "is_sentence_end" in sentence:
                        is_end = sentence.get("is_sentence_end", False)
                except Exception:
                    is_end = False

                asyncio.run_coroutine_threadsafe(
                    websocket.send_json({
                        "type": "transcription",
                        "content": text,
                        "is_final": is_end
                    }),
                    loop
                )

                logger.info("ASR text: %s | end=%s", text, is_end)

                if is_end and text.strip():
                    # Determine target language and system prompt
                    if is_contains_chinese(text):
                        target_lang = "English"
                        system_content = "You are a professional simultaneous interpreter. Translate the following Chinese text into English directly. Do not explain. Do not output the original text. Output ONLY the translation."
                    else:
                        target_lang = "Chinese"
                        system_content = "You are a professional simultaneous interpreter. Translate the following English text into Chinese directly. Do not explain. Do not output the original text. Output ONLY the translation."
                    
                    user_content = text

                    async def perform_translation(sys_prompt, user_prompt):
                        try:
                            # Use run_in_executor to avoid blocking the asyncio loop with synchronous network calls
                            trans_response = await loop.run_in_executor(
                                None, 
                                lambda: dashscope.Generation.call(
                                    model="qwen-turbo",
                                    messages=[
                                        {'role': 'system', 'content': sys_prompt},
                                        {'role': 'user', 'content': user_prompt}
                                    ],
                                    result_format='message'
                                )
                            )

                            if trans_response.status_code == HTTPStatus.OK:
                                translated = trans_response.output.choices[0].message.content
                                await websocket.send_json({
                                    "type": "translation",
                                    "content": translated
                                })
                                logger.info("Translation: %s", translated)
                            else:
                                logger.error(f"Translation failed: {trans_response.code} - {trans_response.message}")
                        except Exception as e:
                            logger.error(f"Translation error: {str(e)}")

                    # Fire and forget translation task
                    asyncio.run_coroutine_threadsafe(
                        perform_translation(system_content, user_content),
                        loop
                    )
            except Exception as e:
                logger.error(f"ASR callback error: {e}")

        def on_error(self, result):
            print(f"DEBUG: ASR Error: {result}", flush=True)
            try:
                message = getattr(result, "message", "ASR error")
                asyncio.run_coroutine_threadsafe(
                    websocket.send_json({"type": "error", "content": message}),
                    loop
                )
            except Exception:
                pass

    rec = Recognition(
        model="paraformer-realtime-v2",
        format="pcm",
        sample_rate=16000,
        callback=WSCallback(),
        punctuation_prediction_enabled=True
    )

    # Use ffmpeg to transcode incoming audio (WebM/Ogg/etc) to raw PCM 16k mono
    # This solves the browser audio format compatibility issues
    try:
        ffmpeg_cmd = [
            'ffmpeg',
            '-i', 'pipe:0',    # Read from stdin
            '-f', 's16le',     # Output PCM signed 16-bit little-endian
            '-ac', '1',        # Mono
            '-ar', '16000',    # 16kHz
            '-vn',             # No video
            'pipe:1'           # Write to stdout
        ]
        process = subprocess.Popen(
            ffmpeg_cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        print("DEBUG: FFmpeg process started", flush=True)
    except Exception as e:
        print(f"DEBUG: Failed to start FFmpeg: {e}", flush=True)
        return

    stop_event = threading.Event()

    def recognition_worker():
        try:
            print("DEBUG: Recognition worker started", flush=True)
            logger.info("Recognition worker started")
            rec.start()
            print("DEBUG: rec.start() called successfully", flush=True)
            
            # Read from FFmpeg stdout and feed to Recognition
            chunk_size = 640 # 20ms of 16k 16bit mono (16000 * 2 * 0.02)
            while not stop_event.is_set():
                chunk = process.stdout.read(chunk_size)
                if not chunk:
                    print("DEBUG: FFmpeg output ended", flush=True)
                    break
                rec.send_audio_frame(chunk)
                # print(f"DEBUG: Sent {len(chunk)} bytes to ASR", flush=True)
        except Exception as e:
            print(f"DEBUG: Recognition worker error: {e}", flush=True)
            logger.error(f"Recognition worker error: {e}")
        finally:
            print("DEBUG: Recognition worker stopping", flush=True)
            try:
                rec.stop()
            except Exception:
                pass
            logger.info("Recognition worker stopped")

    worker_thread = threading.Thread(target=recognition_worker, daemon=True)
    worker_thread.start()

    try:
        chunk_count = 0
        while True:
            data = await websocket.receive_bytes()
            if not data:
                break
            
            # Write received browser audio to FFmpeg stdin
            try:
                process.stdin.write(data)
                process.stdin.flush()
            except Exception as e:
                print(f"DEBUG: Error writing to ffmpeg: {e}", flush=True)
                break

            chunk_count += 1
            if chunk_count % 10 == 0:
                print(f"DEBUG: Received 10 audio chunks (Last size: {len(data)})", flush=True)
    except WebSocketDisconnect:
        print("DEBUG: WebSocket disconnected", flush=True)
        logger.info("WebSocket disconnected")
    except Exception as e:
        print(f"DEBUG: Error in websocket loop: {str(e)}", flush=True)
        logger.error(f"Error in websocket loop: {str(e)}")
    finally:
        stop_event.set()
        # Clean up FFmpeg process
        try:
            process.terminate()
            process.wait(timeout=1)
        except:
            pass

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
