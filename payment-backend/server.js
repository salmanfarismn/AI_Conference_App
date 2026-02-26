/**
 * Easebuzz Payment Backend Server
 * ================================
 * Isolated Express server for handling Easebuzz payment integration.
 * 
 * This server is completely independent of any existing backend.
 * It only handles payment-related endpoints.
 * 
 * Endpoints:
 *   POST /api/create-payment     → Initiate payment
 *   POST /api/payment-success    → Easebuzz success callback
 *   POST /api/payment-failure    → Easebuzz failure callback
 *   GET  /api/payment-status/:uid → Check payment status
 *   GET  /api/receipt/:uid        → View receipt PDF
 *   GET  /api/receipt/download/:uid → Download receipt PDF
 *   GET  /api/receipt/status/:uid  → Check receipt availability
 */

require("dotenv").config();

const express = require("express");
const cors = require("cors");
const { initializeFirebase } = require("./utils/firebase");
const paymentRoutes = require("./routes/paymentRoutes");
const receiptRoutes = require("./routes/receiptRoutes");
const attendeeRoutes = require("./routes/attendeeRoutes");
const attendeeReceiptRoutes = require("./routes/attendeeReceiptRoutes");
const verificationRoutes = require("./routes/verificationRoutes");
const revisionRoutes = require("./routes/revisionRoutes");

const app = express();
const PORT = process.env.PORT || 3001;

// Trust proxy headers (required for Render/Heroku/etc.)
// Without this, req.protocol is always 'http' behind a reverse proxy,
// which breaks Easebuzz surl/furl callback URLs in production.
app.set('trust proxy', 1);

// ──────────────── Middleware ────────────────

// CORS — allow Flutter web app origin
const allowedOrigins = [
    process.env.FRONTEND_URL || "http://localhost:5000",
    "http://localhost:5000",
    "http://localhost:8080",
    "http://localhost:3000",
    "https://m-app-754d5.web.app",
    "https://m-app-754d5.firebaseapp.com",
];

// Paths that receive callbacks from Easebuzz (server-to-server).
// These MUST bypass CORS origin checks since the payment gateway
// posts to them directly.
const easebuzzCallbackPaths = [
    "/api/payment-success",
    "/api/payment-failure",
    "/api/attendee-payment-success",
    "/api/attendee-payment-failure",
];

// Configure the CORS middleware instance
const corsMiddleware = cors({
    origin: function (origin, callback) {
        // Allow requests with no origin (server-to-server, curl, etc.)
        if (!origin) return callback(null, true);
        if (allowedOrigins.indexOf(origin) !== -1) {
            return callback(null, true);
        }
        // In development, allow all origins
        if (process.env.EASEBUZZ_ENV !== "live") {
            return callback(null, true);
        }
        // In live mode, still allow any localhost origin (for local testing)
        try {
            const originUrl = new URL(origin);
            if (originUrl.hostname === "localhost" || originUrl.hostname === "127.0.0.1") {
                return callback(null, true);
            }
        } catch (_) { /* invalid URL, fall through to block */ }
        return callback(new Error("Not allowed by CORS"));
    },
    credentials: true,
});

// Apply CORS selectively: skip it entirely for Easebuzz callback routes
// because the payment gateway POSTs directly to these URLs and may send
// an origin header that isn't in our allowedOrigins list.
app.use((req, res, next) => {
    if (easebuzzCallbackPaths.includes(req.path)) {
        // Allow the callback through without CORS checks
        res.header("Access-Control-Allow-Origin", "*");
        return next();
    }
    // All other routes go through normal CORS
    corsMiddleware(req, res, next);
});

// Parse URL-encoded bodies (Easebuzz callbacks come as form data)
app.use(express.urlencoded({ extended: true }));

// Parse JSON bodies (Flutter API calls)
app.use(express.json());

// ──────────────── Firebase Init ────────────────

initializeFirebase();
console.log("✅ Firebase Admin SDK initialized");

// ──────────────── Routes ────────────────

app.use("/api", paymentRoutes);
app.use("/api", receiptRoutes);
app.use("/api", attendeeRoutes);
app.use("/api", attendeeReceiptRoutes);
app.use("/api", verificationRoutes);
app.use("/api", revisionRoutes);

// Health check
app.get("/api/health", (req, res) => {
    res.json({
        status: "ok",
        service: "easebuzz-payment-backend",
        env: process.env.EASEBUZZ_ENV || "test",
        timestamp: new Date().toISOString(),
    });
});

// ──────────────── Error Handler ────────────────

app.use((err, req, res, next) => {
    console.error("Unhandled error:", {
        message: err.message,
        stack: err.stack,
        path: req.path,
        method: req.method,
        origin: req.headers?.origin,
    });
    res.status(500).json({
        success: false,
        error: "Internal server error",
        path: req.path,
    });
});

// ──────────────── Start Server ────────────────

app.listen(PORT, () => {
    console.log(`\n🚀 Payment Backend running on port ${PORT}`);
    console.log(`   Environment: ${process.env.EASEBUZZ_ENV || "test"}`);
    console.log(`   Health: http://localhost:${PORT}/api/health`);
    console.log(`   Backend URL: ${process.env.BACKEND_URL || "(auto-detected from request)"}`);
    console.log(`   Frontend URL: ${process.env.FRONTEND_URL || "http://localhost:5000"}\n`);
});
