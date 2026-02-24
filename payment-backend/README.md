# Easebuzz Payment Integration

## 📂 File Structure

```
AI_Conference_App/
├── payment-backend/                    # ← NEW: Isolated payment backend
│   ├── .env.example                    # Environment variable template
│   ├── .gitignore
│   ├── package.json
│   ├── server.js                       # Express server entry point
│   ├── controllers/
│   │   └── paymentController.js        # Payment create/success/failure handlers
│   ├── routes/
│   │   └── paymentRoutes.js            # Isolated payment routes
│   └── utils/
│       ├── hashUtils.js                # SHA-512 hash generation/verification
│       └── firebase.js                 # Firebase Admin SDK init
│
└── myweb/                              # ← Existing Flutter app (minimal changes)
    └── lib/
        ├── main.dart                   # MODIFIED: Added /payment-result route
        ├── services/
        │   └── payment_service.dart    # NEW: Payment API client
        └── app/screens/
            ├── home_screen.dart        # MODIFIED: Added payment button section
            ├── payment_confirmation_screen.dart  # NEW: Pre-payment confirmation
            └── payment_result_screen.dart        # NEW: Post-payment result
```

## 🔧 Backend Setup

### 1. Install Dependencies

```bash
cd payment-backend
npm install
```

### 2. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` with your actual credentials:

```env
EASEBUZZ_ENV=test
EASEBUZZ_MERCHANT_KEY=your_actual_key
EASEBUZZ_MERCHANT_SALT=your_actual_salt
PORT=3001
FRONTEND_URL=http://localhost:5000
```

### 3. Firebase Service Account

Download your Firebase project's service account key:
1. Go to Firebase Console → Project Settings → Service accounts
2. Click "Generate new private key"
3. Save the file as `payment-backend/serviceAccountKey.json`

⚠️ **NEVER commit this file to git** (it's already in `.gitignore`).

### 4. Start the Backend

```bash
# Test mode
npm start

# Or with nodemon for development
npx nodemon server.js
```

Verify it's running: `http://localhost:3001/api/health`

## 🖥️ Frontend Configuration

In `myweb/lib/services/payment_service.dart`, update the `_baseUrl`:

```dart
// Development
static const String _baseUrl = 'http://localhost:3001/api';

// Production (update to your deployed backend URL)
// static const String _baseUrl = 'https://your-backend.onrender.com/api';
```

## 🔐 Security Architecture

```
Flutter Web (Frontend)
    ↓  POST /api/create-payment { uid }
Backend API
    ↓  Fetch user from Firestore
    ↓  Verify fullPaperStatus == "accepted"
    ↓  Verify paymentStatus != "paid"
    ↓  Determine amount from role (NEVER trust frontend)
    ↓  Generate SHA-512 hash (key|txnid|amount|...|salt)
    ↓  Call Easebuzz Initiate API
    ↓  Return payment URL to Flutter
Flutter Web
    ↓  Redirect to Easebuzz payment page
Easebuzz Payment Page
    ↓  User completes payment
    ↓  POST /api/payment-success (or /payment-failure)
Backend API
    ↓  Verify reverse hash
    ↓  Update Firestore (paymentStatus, paymentTxnId, etc.)
    ↓  Redirect to Flutter /#/payment-result?status=success
Flutter Web
    ↓  Show PaymentResultScreen
```

## 🧪 Test Mode

- **Test URL**: `https://testpay.easebuzz.in/pay/`
- **Live URL**: `https://pay.easebuzz.in/pay/`
- Toggle via `EASEBUZZ_ENV` in `.env`

### Test Card Details (Easebuzz Sandbox)
- Card: `4012001037141112`
- Expiry: Any future date
- CVV: `123`
- Name: Any

## 📦 Database Fields Added

The following fields are appended to existing `submissions` documents (only for full papers):

| Field | Type | Description |
|-------|------|-------------|
| `paymentStatus` | string | `unpaid` / `pending` / `paid` / `failed` |
| `paymentAmount` | number | Amount paid (250 or 500) |
| `paymentTxnId` | string | Unique transaction ID |
| `paymentDate` | string | ISO date of payment |
| `paymentInitiatedAt` | string | ISO date when payment was initiated |
| `paymentGatewayStatus` | string | Raw status from Easebuzz |

## 🚀 Production Deployment Checklist

- [ ] Set `EASEBUZZ_ENV=live` in `.env`
- [ ] Use production Easebuzz credentials (key + salt)
- [ ] Deploy backend to hosting (Render, Railway, etc.)
- [ ] Update `FRONTEND_URL` to production Flutter web URL
- [ ] Update `_baseUrl` in `payment_service.dart` to deployed backend URL
- [ ] Ensure `serviceAccountKey.json` is securely available in production
- [ ] Set up HTTPS for the backend
- [ ] Update Easebuzz callback URLs (`surl`/`furl`) if needed
- [ ] Test end-to-end flow in production
- [ ] Monitor backend logs for payment errors

## ⚠️ Extension-Only Compliance

This integration follows strict extension-only rules:

✅ **Created (new files)**:
- `payment-backend/` — entirely new, isolated module
- `payment_service.dart` — new service
- `payment_confirmation_screen.dart` — new screen
- `payment_result_screen.dart` — new screen

✅ **Modified (minimal, additive changes only)**:
- `main.dart` — Added 1 import + 1 route (`/payment-result`)
- `home_screen.dart` — Added 2 imports + 1 method call + 1 new method

❌ **NOT modified**:
- Authentication system
- Role management system
- Abstract submission module
- Full paper submission logic
- Admin approval logic
- Dashboard layout structure
- Existing services (auth_service, firestore_service, etc.)
