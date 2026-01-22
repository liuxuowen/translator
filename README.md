# Real-time Simultaneous Interpretation Demo (Qwen)

This project demonstrates a real-time speech-to-speech translation system using the Qwen Multimodal Model (via Alibaba DashScope).

## Prerequisites

1.  Python 3.8+
2.  Alibaba Cloud DashScope API Key (with access to `qwen-audio-turbo` and `qwen-turbo`).

## Setup

1.  **Install Dependencies**:
    ```bash
    pip install -r requirements.txt
    ```

2.  **Configure API Key**:
    Open the `.env` file and paste your DashScope API key:
    ```
    DASHSCOPE_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxx
    ```
    (Or set it as an environment variable `DASHSCOPE_API_KEY`)

## Running the Demo

1.  **Start the Server**:
    ```bash
    python app.py
    ```

2.  **Access the Interface**:
    Open a web browser and navigate to:
    [http://localhost:8000](http://localhost:8000)

3.  **Use**:
    - Click "开始发言 (Start Speaking)".
    - Allow microphone access.
    - Speak into the microphone (Chinese or English).
    - The recognized text and its translation will appear in the text boxes.
    - Click "停止发言 (Stop Speaking)" to stop.

## Implementation Details

-   **Frontend**: Captures audio using `MediaRecorder` API and sends `webm` chunks every 2 seconds via WebSocket.
-   **Backend**: 
    -   Receives audio chunks.
    -   Saves chunks purely temporarily.
    -   Calls **Qwen-Audio-Turbo** for speech-to-text transcription.
    -   Calls **Qwen-Turbo** for text-to-text translation (CN <-> EN).
-   **Streaming**: The demo uses chunk-based streaming to simulate real-time performance with the large multimodal model.

## Troubleshooting

-   **WebSocket Disconnects**: Ensure your network is stable.
-   **Audio not recognized**: Ensure your microphone is working and the browser permission is granted.
-   **API Errors**: Check the console output for DashScope error messages (usually invalid API key or insufficient quota).
