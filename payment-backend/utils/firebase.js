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
            const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, "utf8"));
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
            });
        } else {
            // Priority 3: Default credentials (Cloud Run, GCF, etc.)
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
