/**
 * Firebase Admin SDK initialization.
 * Used to read/write Firestore from the payment backend.
 */

const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

let db = null;

function initializeFirebase() {
    if (admin.apps.length > 0) {
        db = admin.firestore();
        return db;
    }

    // Priority 1: Service account as JSON string (for cloud deployments like Render)
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
        console.log("[FIREBASE] Initializing with FIREBASE_SERVICE_ACCOUNT_JSON env var");
        const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
        });
    }
    // Priority 2: Service account file path (for local development)
    else {
        const rawPath =
            process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
            path.join(__dirname, "..", "serviceAccountKey.json");
        const serviceAccountPath = path.resolve(rawPath);

        if (fs.existsSync(serviceAccountPath)) {
            console.log("[FIREBASE] Initializing with service account file:", serviceAccountPath);
            const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, "utf8"));
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
            });
        } else {
            console.warn("[FIREBASE] ⚠️  No FIREBASE_SERVICE_ACCOUNT_JSON env var and no serviceAccountKey.json file found!");
            console.warn("[FIREBASE] ⚠️  Falling back to applicationDefault() — this will FAIL on Render.");
            console.warn("[FIREBASE] ⚠️  Please set FIREBASE_SERVICE_ACCOUNT_JSON in Render environment variables.");
            admin.initializeApp({
                credential: admin.credential.applicationDefault(),
            });
        }
    }

    db = admin.firestore();
    return db;
}

function getDb() {
    if (!db) {
        initializeFirebase();
    }
    return db;
}

module.exports = { initializeFirebase, getDb };
