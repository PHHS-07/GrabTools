# GrabTools: Hyperlocal Real-Time Tools Rental Connector 🛠️🚀

**GrabTools** is a sophisticated, hyperlocal peer-to-peer marketplace built with Flutter and Firebase. It enables users to browse, rent, and instantly book tools from people in their proximity. Backed by an AI-assisted infrastructure and a rigorous zero-trust security architecture, the app ensures interactions are smooth, secure, and geographically relevant.

---

## ✨ Key Features

- 📍 **Hyperlocal Proximity Search:** Discover tools exactly where you need them using dynamic geolocation tracking and proximity factoring.
- 📆 **Real-Time Booking & Availability Engine:** An advanced, conflict-free booking lifecycle guarantees zero overlapping date ranges. The built-in native calendar visually masks unavailable dates instantly.
- 🛡️ **Zero-Trust Security & Trust Scores:** Protected exclusively via native `firestore.rules`. Booking capabilities securely rely on peer Trust Scores, blocking unreliable users at the database level and requiring manual approval for new listings if a user's trust is under 50.
- 🤖 **AI-Assisted Listing & Moderation:** Integrated with Google's Gemini AI to automatically generate rich descriptions and categories based solely on analyzing real-life images or tool titles.
- 🏆 **Smart Sorting Algorithm:** Front-page feeds asynchronously sort relying on a dynamically weighed algorithm measuring Trust Score (40%), Ratings (30%), Application Activity (20%), and Proximity (10%).
- ☁️ **Lean Cloud Infrastructure:** Runs an actively optimized Firebase suite that automates background tasks—such as dynamically expiring unconfirmed bookings natively via Pub/Sub—ensuring scalable architecture without high server overhead.

---

## 🏗 Architecture & Tech Stack

- **Frontend:** Flutter & Dart (provider state management)
- **Backend:** Firebase Firestore, Cloud Functions (Node.js Gen 1), Firebase Authentication
- **AI/ML:** Google Generative AI (Gemini 1.5 Flash / Gemini 2 Flash) for proxy autofill logic
- **Payments Flow:** Extensible payment tracking states integrated to native `upi` capabilities

### Firestore Security

This app enforces strict rules directly on the client. It completely restricts states so malicious requests skipping direct lifecycle phases (e.g., `requested` to `completed`) are rejected implicitly by Google Cloud.

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (Latest Stable version recommended)
- Firebase CLI installed natively (`npx firebase-tools` or `npm -g install firebase-tools`)
- A connected Firebase Project with Firestore, Functions, Pub/Sub, and Authentication enabled.

### 1. Installation

```bash
git clone https://github.com/PHHS-07/GrabTools.git
cd GrabTools
flutter pub get
```

### 2. Configure Firebase

Ensure you link the Flutter app to your active Firebase project instance using FlutterFire:
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

### 3. Deploy Backend

GrabTools strictly relies on its Firestore configurations and Cloud Functions. Deploy them natively:
```bash
cd functions
npm install
cd ..
npx firebase-tools deploy --only firestore:rules,functions
```

### 4. Run

```bash
flutter run
```

---

## 📄 License & Contribution
This project is proprietary or open for respective contributions depending on the hosting agreement. Please see the license accompanying this project or contact the repository owner.
