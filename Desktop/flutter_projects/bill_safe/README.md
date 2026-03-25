# BillSafe 🧾

> AI-powered Flutter app that scans restaurant bills, detects overcharges, and verifies GSTIN using Gemini Vision API.

BillSafe helps Indian consumers detect illegal charges and overcharges on restaurant bills. Scan any bill using your camera, and BillSafe will analyze it with AI to flag suspicious items, verify the restaurant's GSTIN, and help you know your rights.

---

## Features

- **AI Bill Analysis** — Uses Google Gemini Vision to scan and analyze restaurant bills
- **Overcharge Detection** — Flags illegal fees like service charge above 10%, double GST, etc.
- **GSTIN Verification** — Verifies restaurant's GST number via GSTINCheck API
- **Scan History** — Stores all past scans with bill images locally
- **Onboarding Flow** — 3-page onboarding for first-time users

---

## Tech Stack

- **Flutter** (Android)
- **Google Gemini API** (`gemini-2.5-flash`) — Vision-based bill analysis
- **GSTINCheck API** — Real-time GSTIN verification
- **SharedPreferences** — Local scan history storage
- **ImagePicker + path_provider** — Camera/gallery access and image persistence

---

## Getting Started

### Prerequisites

- Flutter SDK installed
- Android Studio / VS Code
- Google Cloud account with Gemini API enabled and billing set up
- GSTINCheck API key (free at gstincheck.co.in)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/bill-safe.git
   cd bill-safe
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Create the `.env` file** inside the `assets/` folder:
   ```
   GEMINI_API_KEY=your_gemini_api_key_here
   GSTIN_API_KEY=your_gstin_api_key_here
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

### Build Release APK

```bash
flutter build apk --release
```

APK will be at `build/app/outputs/flutter-apk/app-release.apk`

---

## API Keys

| Key | Where to get |
|-----|-------------|
| `GEMINI_API_KEY` | [Google Cloud Console](https://console.cloud.google.com) → Enable Gemini API |
| `GSTIN_API_KEY` | [gstincheck.co.in](https://gstincheck.co.in) → Free registration |

> **Note:** Never commit your `.env` file. It is already added to `.gitignore`.

---

## Project Structure

```
lib/
├── main.dart                  # App entry point, onboarding check
├── models/
│   └── bill_scan.dart         # BillScan data model
├── screens/
│   ├── home_screen.dart       # Home dashboard
│   ├── scan_screen.dart       # Camera/gallery bill scan
│   ├── analysis_result_screen.dart  # AI analysis results
│   ├── history_screen.dart    # Past scans
│   └── onboarding_screen.dart # First-launch onboarding
└── services/
    ├── gemini_service.dart    # Gemini Vision API integration
    ├── gstin_service.dart     # GSTIN verification
    └── storage_service.dart   # SharedPreferences storage
```

---

## License

MIT License
