require("dotenv").config();
const { initializeFirebase, getDb } = require("./utils/firebase");

async function debug() {
    initializeFirebase();
    const db = getDb();

    const allSnap = await db.collection("submissions").get();
    console.log("Total submissions: " + allSnap.size);
    console.log("---");

    // Group by user
    const byUser = {};
    for (const doc of allSnap.docs) {
        const d = doc.data();
        const uid = d.uid || "unknown";
        if (!byUser[uid]) byUser[uid] = [];
        byUser[uid].push({
            submissionType: d.submissionType || "MISSING",
            status: d.status || "MISSING",
            paymentStatus: d.paymentStatus || "none",
        });
    }

    // Only show users who have at least one accepted/accepted_with_revision
    for (const [uid, subs] of Object.entries(byUser)) {
        const hasAccepted = subs.some(s =>
            s.status === "accepted" || s.status === "accepted_with_revision"
        );
        if (!hasAccepted) continue;

        const userDoc = await db.collection("users").doc(uid).get();
        const name = userDoc.exists ? (userDoc.data().name || "?") : "NOT_FOUND";

        console.log("USER: " + name + " | uid: " + uid);
        for (const s of subs) {
            const eligible = s.submissionType === "fullpaper" &&
                (s.status === "accepted" || s.status === "accepted_with_revision");
            console.log("  type=" + s.submissionType + " | status=" + s.status +
                " | payment=" + s.paymentStatus +
                " | eligible=" + (eligible ? "YES" : "NO"));
        }
        console.log("---");
    }

    process.exit(0);
}

debug().catch(err => { console.error(err); process.exit(1); });
