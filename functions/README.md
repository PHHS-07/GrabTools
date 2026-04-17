AI Proxy Cloud Function
======================

This folder contains a simple Cloud Function HTTP proxy used by the GrabTools app.

Features
- Accepts POST requests with JSON body. Recognizes several payload shapes:
  - `{ "prompt": "..." }`
  - `{ "messages": [ { role, content }, ... ] }`
  - `{ "input": "..." }` or `{ "text": "..." }`
  - Optional: `imageUrl` and `categories` (array)
- Calls Google Generative Language (Gemini) if `GENERATIVE_API_KEY` is set.
- Returns a configuration error if `GENERATIVE_API_KEY` is not set.

Deployment (gcloud)
1. Install and authenticate gcloud CLI and enable Cloud Functions API.

2. From this `functions/` directory, install dependencies locally (optional):

   npm install

3. Deploy the function (example):

   gcloud functions deploy aiProxy \
     --region=us-central1 \
     --runtime=nodejs18 \
     --trigger-http \
     --allow-unauthenticated \
     --entry-point=aiProxy

4. Set your Gemini / Generative Language API key and model as environment variables (optional):

   gcloud functions deploy aiProxy --update-env-vars GENERATIVE_API_KEY="YOUR_KEY",GEMINI_MODEL="gemini-2-flash" --region=us-central1

   - `GEMINI_MODEL` defaults to `gemini-2-flash` but can be set to any supported model name.

Testing

Use curl to test after deploy (replace URL):

  curl -X POST "https://REGION-PROJECT.cloudfunctions.net/aiProxy" \
    -H "Content-Type: application/json" \
    -d '{"prompt":"Need to cut down the tree in front of my house","categories":["Gardening","Tree Services"]}'

Notes
- The function prefers the Generative Language API (Gemini) when `GENERATIVE_API_KEY` is provided.
- Ensure the API key has appropriate access and quota. Check Cloud Function logs for detailed errors on upstream failures.
