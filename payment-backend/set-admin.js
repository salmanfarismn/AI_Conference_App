/**
 * One-time script to set admin custom claim for a user.
 * Usage: node set-admin.js <uid>
 */
require("dotenv").config();
const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

// Initialize Firebase Admin
const rawPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || path.join(__dirname, "serviceAccountKey.json");
const serviceAccountPath = path.resolve(rawPath);
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, "utf8"));

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const uid = process.argv[2];
if (!uid) {
    console.error("Usage: node set-admin.js <uid>");
    process.exit(1);
}

(async () => {
    try {
        // Check current claims
        const user = await admin.auth().getUser(uid);
        console.log("Current user:", user.email);
        console.log("Current claims:", JSON.stringify(user.customClaims));

        // Set admin claim
        await admin.auth().setCustomUserClaims(uid, { role: "admin" });
        console.log(`✅ Admin claim set for ${uid}`);

        // Verify
        const updated = await admin.auth().getUser(uid);
        console.log("Updated claims:", JSON.stringify(updated.customClaims));

        process.exit(0);
    } catch (err) {
        console.error("Error:", err.message);
        process.exit(1);
    }
})();
