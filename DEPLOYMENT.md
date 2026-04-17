# Deployment Guide for GrabTools Cloud Functions

## Prerequisites
- Firebase CLI installed (`firebase --version`)
- Gemini API key from https://aistudio.google.com/app/apikey
- Connected to grabtools-07 Firebase project

## Deploy aiProxy Cloud Function

### 1. Deploy Function
```bash
firebase deploy --only functions:aiProxy
```

### 2. Set Gemini API Key as environment variable
```bash
gcloud functions deploy aiProxy --region=us-central1 --update-env-vars GENERATIVE_API_KEY="YOUR_GEMINI_API_KEY",GEMINI_MODEL="gemini-2-flash"
```

### 3. Get Function URL
After deployment, the URL will be displayed. It looks like:
```
https://us-central1-grabtools-07.cloudfunctions.net/aiProxy
```

### 4. Update Flutter App
Update `lib/main.dart` or create a config file with the function URL:
```dart
final aiService = AiService(functionUrl: 'https://us-central1-grabtools-07.cloudfunctions.net/aiProxy');
```

## Notes
- The aiProxy function uses Google Gemini API (not OpenAI)
- Requires `GENERATIVE_API_KEY` env var to be set on the function
- Function will be available at the region specified (default: us-central1)
