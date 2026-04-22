# 🛠️ GrabTools — Hyperlocal Real-Time Tools Rental Connector with Trust-Driven Architecture 🛠️🚀

**GrabTools** is a sophisticated, hyperlocal peer-to-peer marketplace built with Flutter and Firebase. It enables users to browse, rent, and instantly book tools from people in their proximity. Backed by an AI-assisted infrastructure and a rigorous zero-trust security architecture, the app ensures interactions are smooth, secure, and geographically relevant.

---

## 🚀 Core Idea

Unlike generic marketplaces, GrabTools focuses on reducing fraud probability through layered trust signals rather than enforcing rigid identity verification.

The system combines:
- User behavior tracking
- Transaction-level proof validation
- Trust scoring
- Firestore rule enforcement

This creates a controlled and defensible rental ecosystem.

---

## ✨ Key Features

### 📍 Hyperlocal Discovery
- Real-time proximity-based tool search
- Distance-aware ranking for relevance

### 📆 Conflict-Free Booking System
- Strict booking lifecycle enforcement:
  requested → approved → paid → verified → completed
- Overlap-safe availability engine
- Calendar UI disables unavailable dates in real time

### 🛡️ Zero-Trust Security Architecture
- All critical logic enforced via Firestore Security Rules
- Prevents:
  - state skipping
  - unauthorized updates
  - invalid booking transitions
- No reliance on client-side validation

### 🧠 Trust Score System
- Dynamic scoring based on:
  - successful transactions
  - cancellations
  - behavior patterns
- Automatic restrictions:
  - low trust → limited actions
  - high cancellation rate → booking blocked

### 🔐 Transaction-Level Proof System (Anti-Fraud Core)
At the time of tool handover:
- Users submit live proof including:
  - Selfie with tool
  - Dynamic verification code (e.g., GT-8421)
  - Timestamp + GPS capture

Proof strength is evaluated based on:
- Live capture
- GPS match
- AI tool consistency
- Code presence

Displayed as:
Proof Strength: HIGH / MEDIUM / LOW  
Confidence: XX%

### ⚠️ Risk Visibility System
- “Low verification — proceed at your own risk”
- “No pickup proof submitted”
- Promotes informed decisions instead of blind trust

### 🤖 AI-Assisted Moderation
- Uses Gemini AI for:
  - tool description generation
  - category classification
  - image consistency checks

AI is assistive, not authoritative.

### 🏆 Smart Ranking Algorithm
Score =
Trust Score (40%) + Ratings (30%) + Activity (20%) + Proximity (10%)

### 📊 Demand Awareness
- Detects high-demand categories based on:
  - recent bookings
  - local activity
- Displays: “High demand in your area”

### 💳 Payment Flow (Lightweight & Extensible)
- Payment states:
  pending → paid → verified
- Optional payment proof upload
- Easily extendable to payment gateways

### 📉 Cancellation Penalty System
- Tracks cancellation rate
- If >30%:
  - booking blocked
  - trust score reduced
  - visibility lowered

### 📦 Tool Usage History
- Displays:
  - total rentals
  - last rented time
- Builds long-term trust

---

## 🏗 Architecture & Tech Stack

Frontend:
- Flutter (Dart)
- Provider (state management)

Backend:
- Firebase Firestore
- Firebase Authentication
- Cloud Functions (minimal usage)

AI Layer:
- Google Gemini API

---

## 🔐 Security Philosophy

GrabTools follows a Zero-Trust Model:

No client action is trusted without database-level validation.

All critical logic is enforced using:
- Firestore Rules
- Role-based validation
- State transition control

---

## ⚖️ System Limitations

- Does not provide legal identity verification
- OTP and proof systems act as trust signals, not guarantees
- AI detection is assistive, not fully reliable

---

## 🧠 Design Principle

Trust = Identity Signals + Behavior + Transaction Proof

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK
- Firebase CLI
- Firebase Project (Firestore + Auth + Functions enabled)

### Installation

git clone https://github.com/PHHS-07/GrabTools.git  
cd GrabTools  
flutter pub get  

### Configure Firebase

dart pub global activate flutterfire_cli  
flutterfire configure  

### Deploy Backend

cd functions  
npm install  
cd ..  
npx firebase-tools deploy --only firestore:rules,functions  

### Run

flutter run  

---

## 🎯 What Makes This Project Unique

- Trust-aware marketplace architecture  
- Transaction-level fraud resistance  
- Zero-trust enforcement using Firestore rules  
- Behavior-driven system control  
- Minimal backend cost with high reliability  

---

## 📄 License & Contribution

This project is proprietary or open for respective contributions depending on the hosting agreement. Please see the license accompanying this project or contact us.

---

## 📌 Final Note

GrabTools is designed as a real-world system simulation focusing on practical trade-offs, scalable architecture, and fraud mitigation strategies rather than unrealistic perfect security claims.

