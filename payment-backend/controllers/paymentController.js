/**
 * Payment Controller
 * ------------------
 * Handles payment creation, success callback, and failure callback.
 * 
 * SECURITY CONSTRAINTS:
 * - Amount is ALWAYS determined server-side from user role in DB.
 * - Hash is generated server-side only; salt is never exposed.
 * - Duplicate payments are prevented via idempotency checks.
 * - Callback hash is verified before updating payment status.
 */

const { getDb } = require("../utils/firebase");
const {
    generatePaymentHash,
    generateReverseHash,
    generateTxnId,
} = require("../utils/hashUtils");
const axios = require("axios");

const EASEBUZZ_KEY = () => process.env.EASEBUZZ_MERCHANT_KEY;
const EASEBUZZ_SALT = () => process.env.EASEBUZZ_MERCHANT_SALT;
const EASEBUZZ_ENV = () => process.env.EASEBUZZ_ENV || "test";

/**
 * Get the Easebuzz API base URL based on environment.
 */
function getEasebuzzBaseUrl() {
    return EASEBUZZ_ENV() === "live"
        ? "https://pay.easebuzz.in"
        : "https://testpay.easebuzz.in";
}

/**
 * Determine fee based on role.
 * Student → ₹250, Scholar → ₹500
 * CRITICAL: Never trust frontend amount. Always derive from DB role.
 */
function getAmountForRole(role) {
    const normalizedRole = (role || "").toLowerCase().trim();
    if (normalizedRole === "student") return "250.00";
    if (normalizedRole === "scholar") return "500.00";
    // Default to higher amount for safety
    return "500.00";
}

/**
 * POST /create-payment
 * 
 * Request body: { uid: string }
 * 
 * Flow:
 * 1. Fetch user from Firestore
 * 2. Verify full paper is approved
 * 3. Verify payment not already completed
 * 4. Determine amount from role
 * 5. Generate hash
 * 6. Call Easebuzz initiate API
 * 7. Return access key to frontend
 */
async function createPayment(req, res) {
    try {
        const { uid, frontendUrl: clientFrontendUrl } = req.body;

        if (!uid) {
            return res.status(400).json({ success: false, error: "User ID is required." });
        }

        // Use client-provided URL if available, otherwise fall back to env
        const frontendUrl = clientFrontendUrl || process.env.FRONTEND_URL || "http://localhost:5000";

        const db = getDb();

        // 1. Fetch user profile
        const userDoc = await db.collection("users").doc(uid).get();
        if (!userDoc.exists) {
            return res.status(404).json({ success: false, error: "User not found." });
        }
        const userData = userDoc.data();

        // 2. Check if user has an approved full paper
        // Simplified query to avoid the need for composite indices
        const submissionsSnap = await db
            .collection("submissions")
            .where("uid", "==", uid)
            .get();

        if (submissionsSnap.empty) {
            console.log(`[PAYMENT] No submissions found for user ${uid}`);
            return res.status(403).json({
                success: false,
                error: "No submissions found for this account.",
            });
        }

        // Filter for specific type and status in code
        const approvedDocs = submissionsSnap.docs.filter((doc) => {
            const d = doc.data();
            const type = String(d.submissionType || "").toLowerCase().trim();
            const status = String(d.status || "").toLowerCase().trim();

            return type === "fullpaper" && (status === "accepted" || status === "accepted_with_revision");
        });

        if (approvedDocs.length === 0) {
            console.log(`[PAYMENT] User ${uid} has ${submissionsSnap.size} submissions but none are approved full papers.`);
            return res.status(403).json({
                success: false,
                error: "Full paper must be approved before payment.",
            });
        }

        // 3. Check if payment is already completed (idempotency)
        const fullPaperDoc = approvedDocs[0];
        const fullPaperData = fullPaperDoc.data();
        if (fullPaperData.paymentStatus === "paid") {
            return res.status(409).json({
                success: false,
                error: "Payment already completed.",
                paymentTxnId: fullPaperData.paymentTxnId,
            });
        }

        // 4. Determine amount from role (NEVER trust frontend)
        const role = userData.role || "scholar";
        const amount = getAmountForRole(role);

        // 5. Generate transaction ID
        const txnid = generateTxnId();

        // 6. Build payment payload
        const firstname = userData.name || "User";
        const email = userData.email || "";
        const phone = userData.phone || "9999999999";
        const productinfo = `Conference Fee - ${role === "student" ? "Student" : "Scholar"}`;

        const key = EASEBUZZ_KEY();
        const salt = EASEBUZZ_SALT();

        const hash = generatePaymentHash({
            key,
            txnid,
            amount,
            productinfo,
            firstname,
            email,
            salt,
        });

        // 7. Prepare Easebuzz initiate API call
        // Use BACKEND_URL env var for reliable callback URLs in production;
        // fall back to auto-detection from request headers.
        const backendBaseUrl = process.env.BACKEND_URL
            || `${req.protocol}://${req.get("host")}`;

        const initiatePayload = {
            key,
            txnid,
            amount,
            productinfo,
            firstname,
            email,
            phone,
            surl: `${backendBaseUrl}/api/payment-success`,
            furl: `${backendBaseUrl}/api/payment-failure`,
            hash,
        };

        // Call Easebuzz initiate transaction API
        const easebuzzInitUrl = `${getEasebuzzBaseUrl()}/payment/initiateLink`;

        const formData = new URLSearchParams(initiatePayload).toString();

        const easebuzzResponse = await axios.post(easebuzzInitUrl, formData, {
            headers: {
                "Content-Type": "application/x-www-form-urlencoded",
            },
        });

        // Safely parse response (may be string or object depending on Easebuzz Content-Type)
        let responseData = easebuzzResponse.data;
        if (typeof responseData === 'string') {
            try { responseData = JSON.parse(responseData); } catch (e) { /* not JSON */ }
        }

        if (responseData && responseData.status == 1) {
            // Store pending transaction in the submission doc for verification later
            await fullPaperDoc.ref.update({
                paymentStatus: "pending",
                paymentTxnId: txnid,
                paymentAmount: parseFloat(amount),
                paymentInitiatedAt: new Date().toISOString(),
                paymentFrontendUrl: frontendUrl,
            });

            const accessKey = responseData.data;
            const paymentUrl = `${getEasebuzzBaseUrl()}/pay/${accessKey}`;

            return res.status(200).json({
                success: true,
                paymentUrl,
                accessKey,
                txnid,
                amount,
                role,
            });
        } else {
            console.error("Easebuzz initiate failed:", responseData);
            return res.status(500).json({
                success: false,
                error: "Failed to initiate payment with gateway.",
                details: responseData?.message || "Unknown error",
            });
        }
    } catch (error) {
        console.error("Create payment error:", error);
        return res.status(500).json({
            success: false,
            error: "Internal server error.",
            details: error.message,
        });
    }
}

/**
 * POST /payment-success
 * 
 * Called by Easebuzz after successful payment.
 * Verifies hash, updates Firestore, redirects to Flutter.
 */
async function paymentSuccess(req, res) {
    try {
        const {
            txnid,
            amount,
            productinfo,
            firstname,
            email,
            status,
            hash: receivedHash,
        } = req.body;

        console.log("Payment success callback received:", { txnid, amount, status });

        const key = EASEBUZZ_KEY();
        const salt = EASEBUZZ_SALT();

        // Verify hash
        const expectedHash = generateReverseHash({
            salt,
            status,
            email,
            firstname,
            productinfo,
            amount,
            txnid,
            key,
        });

        if (receivedHash !== expectedHash) {
            console.error("Hash mismatch! Possible tampering.", {
                received: receivedHash,
                expected: expectedHash,
            });

            const frontendUrl = process.env.FRONTEND_URL || "http://localhost:5000";
            return res.redirect(
                `${frontendUrl}/#/payment-result?status=failed&reason=hash_mismatch&txnid=${txnid}`
            );
        }

        // Update Firestore
        const db = getDb();
        const submissionsSnap = await db
            .collection("submissions")
            .where("paymentTxnId", "==", txnid)
            .limit(1)
            .get();

        if (!submissionsSnap.empty) {
            const docRef = submissionsSnap.docs[0].ref;
            const existingData = submissionsSnap.docs[0].data();

            // Prevent duplicate updates
            if (existingData.paymentStatus !== "paid") {
                await docRef.update({
                    paymentStatus: "paid",
                    paymentAmount: parseFloat(amount),
                    paymentDate: new Date().toISOString(),
                    paymentGatewayStatus: status,
                });
            }
        }

        // Use the frontend URL stored during payment creation
        const storedFrontendUrl = !submissionsSnap.empty
            ? submissionsSnap.docs[0].data().paymentFrontendUrl
            : null;
        const frontendUrl = storedFrontendUrl || process.env.FRONTEND_URL || "http://localhost:5000";
        return res.redirect(
            `${frontendUrl}/#/payment-result?status=success&txnid=${txnid}&amount=${amount}`
        );
    } catch (error) {
        console.error("Payment success handler error:", error);
        const frontendUrl = process.env.FRONTEND_URL || "http://localhost:5000";
        return res.redirect(
            `${frontendUrl}/#/payment-result?status=failed&reason=server_error`
        );
    }
}

/**
 * POST /payment-failure
 * 
 * Called by Easebuzz after failed/cancelled payment.
 * Resets payment status, redirects to Flutter.
 */
async function paymentFailure(req, res) {
    try {
        const { txnid, status } = req.body;

        console.log("Payment failure callback received:", { txnid, status });

        // Reset payment status in Firestore
        const db = getDb();
        const submissionsSnap = await db
            .collection("submissions")
            .where("paymentTxnId", "==", txnid)
            .limit(1)
            .get();

        if (!submissionsSnap.empty) {
            const docRef = submissionsSnap.docs[0].ref;
            const existingData = submissionsSnap.docs[0].data();

            // Only reset if not already paid (safety check)
            if (existingData.paymentStatus !== "paid") {
                await docRef.update({
                    paymentStatus: "failed",
                    paymentGatewayStatus: status || "failed",
                    paymentFailedAt: new Date().toISOString(),
                });
            }
        }

        // Use the frontend URL stored during payment creation
        const storedFrontendUrl = !submissionsSnap.empty
            ? submissionsSnap.docs[0].data().paymentFrontendUrl
            : null;
        const frontendUrl = storedFrontendUrl || process.env.FRONTEND_URL || "http://localhost:5000";
        return res.redirect(
            `${frontendUrl}/#/payment-result?status=failed&txnid=${txnid}&reason=payment_failed`
        );
    } catch (error) {
        console.error("Payment failure handler error:", error);
        const frontendUrl = process.env.FRONTEND_URL || "http://localhost:5000";
        return res.redirect(
            `${frontendUrl}/#/payment-result?status=failed&reason=server_error`
        );
    }
}

/**
 * GET /payment-status/:uid
 * 
 * Returns the payment status for a user's approved full paper.
 */
async function getPaymentStatus(req, res) {
    try {
        const { uid } = req.params;

        if (!uid) {
            return res.status(400).json({ success: false, error: "User ID is required." });
        }

        const db = getDb();

        // Find the user's approved full paper
        // Simplified query to avoid the need for composite indices
        const submissionsSnap = await db
            .collection("submissions")
            .where("uid", "==", uid)
            .get();

        const approvedDocs = submissionsSnap.docs.filter((doc) => {
            const d = doc.data();
            const type = String(d.submissionType || "").toLowerCase().trim();
            const status = String(d.status || "").toLowerCase().trim();

            return type === "fullpaper" && (status === "accepted" || status === "accepted_with_revision");
        });

        if (approvedDocs.length === 0) {
            return res.status(200).json({
                success: true,
                hasApprovedPaper: false,
                paymentStatus: null,
            });
        }

        const data = approvedDocs[0].data();

        return res.status(200).json({
            success: true,
            hasApprovedPaper: true,
            paymentStatus: data.paymentStatus || "unpaid",
            paymentAmount: data.paymentAmount || null,
            paymentTxnId: data.paymentTxnId || null,
            paymentDate: data.paymentDate || null,
        });
    } catch (error) {
        console.error("Get payment status error:", error);
        return res.status(500).json({
            success: false,
            error: "Internal server error.",
            message: error.message,
            stack: process.env.NODE_ENV === "development" ? error.stack : undefined,
        });
    }
}

module.exports = {
    createPayment,
    paymentSuccess,
    paymentFailure,
    getPaymentStatus,
};
