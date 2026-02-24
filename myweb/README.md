# UCCICON26 — Conference Paper Submission System

A Flutter-based academic conference management platform with a **Web Admin Panel** and a **Mobile App** (Android / iOS / Web), powered by Firebase and Cloudinary.

---

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Tech Stack](#tech-stack)
- [Features](#features)
- [Submission Workflow](#submission-workflow)
- [Firestore Data Model](#firestore-data-model)
- [Getting Started](#getting-started)
- [Firebase Setup](#firebase-setup)
- [Running the App](#running-the-app)
- [Security](#security)
- [Dependencies](#dependencies)

---

## Overview

| Platform | Entry Point | Purpose |
|----------|-------------|---------|
| **Web** | Admin Panel | Review submissions, accept/reject with comments, toggle submission windows |
| **Mobile / Web** | User App | Submit abstracts & full papers, track status in real time |

---

## Project Structure

```
lib/
├── admin/                        # Web admin panel
│   ├── admin_login_screen.dart
│   └── admin_dashboard_screen.dart
├── app/                          # User-facing app
│   ├── screens/
│   │   ├── welcome_screen.dart
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   ├── home_screen.dart
│   │   ├── submit_paper_screen.dart           # Abstract submission
│   │   ├── full_paper_submission_screen.dart   # Full paper submission
│   │   └── submission_status_screen.dart       # My Submissions
│   ├── widgets/
│   └── utils/
├── models/
│   ├── submission.dart           # Submission model (abstract + full paper)
│   ├── author.dart               # Author model (main + co-authors)
│   ├── user_profile.dart
│   └── app_settings.dart
├── services/
│   ├── auth_service.dart         # Firebase Auth (email/password + anonymous)
│   ├── firestore_service.dart    # Firestore CRUD operations
│   ├── cloudinary_service.dart   # Cloudinary PDF uploads
│   └── storage_service.dart      # Firebase Storage (legacy)
├── firebase_options.dart
└── main.dart
```

---

## Tech Stack

- **Framework**: Flutter (Dart) — single codebase for Web, Android, iOS
- **Auth**: Firebase Authentication (Email/Password + Anonymous sign-in)
- **Database**: Cloud Firestore (real-time sync)
- **File Storage**: Cloudinary (full paper PDFs), Firebase Storage (legacy)
- **UI**: Custom dark theme with glassmorphism, parallax backgrounds, and micro-animations

---

## Features

### Web Admin Panel

- **Secure login** – email/password with `role: 'admin'` custom claim enforcement
- **Submission dashboard** – view all submissions (abstracts & full papers) with real-time updates
- **Review workflow** – accept, reject, or request revisions with comments
- **Feature toggles** – enable/disable abstract and full paper submission windows in real time
- **Search & filter** – by reference number, title, or status

### Mobile / Web User App

- **Abstract submission** – title, author name, `.docx` upload with auto text extraction; works anonymously before registration
- **Full paper submission** – requires an accepted abstract; pre-fills title and authors from abstract; uploads PDF (max 10 MB) to Cloudinary
- **Multi-author support** – main author (name, affiliation, email, phone) + up to 5 co-authors
- **Reference number linking** – full paper shares the same `UCCICON26-XX` reference number as the abstract
- **My Submissions** – view all submissions with title, authors, type (Abstract / Full Paper), status, and review comments
- **Real-time status** – submission status and review comments update live via Firestore streams
- **Account linking** – anonymous users can register after submitting an abstract without losing their submission

---

## Submission Workflow

```
┌──────────────────────┐
│  Submit Abstract     │  Anonymous or logged-in user
│  (.docx upload)      │  → Creates document: submissionType = 'abstract'
│  → Ref: UCCICON26-XX │  → Sequential reference number assigned
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│  Admin Review        │  Accept / Reject / Revision
└────────┬─────────────┘
         │ (accepted)
         ▼
┌──────────────────────┐
│  Submit Full Paper   │  Pre-fills title & authors from abstract
│  (PDF upload)        │  → Creates NEW document: submissionType = 'fullpaper'
│  → Same Ref Number   │  → Linked by referenceNumber (abstract untouched)
└──────────────────────┘
```

**Key rules:**
- Full paper requires an accepted abstract
- Full paper creates a **separate** Firestore document (does not modify the abstract)
- Both documents share the same `referenceNumber` for linkage
- Title, authors, and co-authors are pre-filled from the abstract but remain editable

---

## Firestore Data Model

### `submissions` collection

| Field | Type | Description |
|-------|------|-------------|
| `uid` | string | User's Firebase UID |
| `referenceNumber` | string | e.g. `UCCICON26-01` |
| `title` | string | Paper/abstract title |
| `author` | string? | Legacy single-author field |
| `authors` | array | List of `Author` objects (name, affiliation, email?, phone?, isMainAuthor) |
| `submissionType` | string | `abstract` or `fullpaper` |
| `status` | string | `pending` · `submitted` · `under_review` · `accepted` · `rejected` · `revision_requested` |
| `pdfUrl` | string? | Cloudinary URL (full papers) |
| `docBase64` | string? | Base64-encoded `.docx` (abstracts) |
| `docName` | string? | Original file name |
| `extractedText` | string? | Text extracted from `.docx` |
| `reviewComments` | string? | Admin review feedback |
| `reviewedBy` | string? | Admin UID who reviewed |
| `createdAt` | timestamp | Submission timestamp |
| `updatedAt` | timestamp? | Last update timestamp |
| `reviewedAt` | timestamp? | Review timestamp |

### `users` collection

| Field | Type | Description |
|-------|------|-------------|
| `uid` | string | Firebase UID |
| `name` | string | Display name |
| `email` | string | Email address |
| `phone` | string | Phone number |
| `role` | string | `student` or `scholar` |

### `app_settings/settings` document

| Field | Type | Description |
|-------|------|-------------|
| `abstractSubmissionOpen` | boolean | Controls abstract submission availability |
| `fullPaperSubmissionOpen` | boolean | Controls full paper submission availability |

### `counters/submission_ref` document

| Field | Type | Description |
|-------|------|-------------|
| `lastNumber` | number | Auto-incremented counter for reference numbers |

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.0.0
- Firebase project with Authentication, Firestore, and Storage enabled
- Cloudinary account (for full paper PDF uploads)
- FlutterFire CLI (`dart pub global activate flutterfire_cli`)

### Firebase Setup

1. **Configure Firebase**
   ```bash
   flutterfire configure
   ```

2. **Enable authentication methods**
   - Firebase Console → Authentication → Sign-in method
   - Enable **Email/Password** and **Anonymous**

3. **Set admin custom claims**
   ```js
   const admin = require('firebase-admin');
   admin.auth().setCustomUserClaims(uid, { role: 'admin' });
   ```

4. **Deploy Firestore rules & indexes**
   ```bash
   firebase deploy --only firestore:rules
   firebase deploy --only firestore:indexes
   ```

5. **Initialize app settings**  
   Create `app_settings/settings` in Firestore:
   ```json
   {
     "abstractSubmissionOpen": true,
     "fullPaperSubmissionOpen": true
   }
   ```

6. **Reference counter** — auto-created on first submission; no manual setup needed.

---

## Running the App

```bash
# Install dependencies
flutter pub get

# Web (admin panel)
flutter run -d chrome

# Android / iOS
flutter run
```

---

## Security

- **Firestore rules** enforce user-scoped reads/writes — users can only access their own data
- **Admin access** requires the `role: 'admin'` custom claim; unauthorized users are signed out
- **App settings** are readable by authenticated users but writable only by admins
- **File uploads** are validated client-side (PDF only, 10 MB max)

---

## Dependencies

| Package | Purpose |
|---------|---------|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | Authentication |
| `cloud_firestore` | Database |
| `firebase_storage` | Legacy file storage |
| `cloudinary_public` | Full paper PDF uploads |
| `file_picker` | File selection |
| `intl` | Date/time formatting |
| `url_launcher` | Opening PDF links |
| `archive` / `xml` | `.docx` text extraction |
| `flutter_svg` | SVG asset rendering |
| `pdf` / `file_saver` | PDF generation & download |
| `http` | HTTP requests |
