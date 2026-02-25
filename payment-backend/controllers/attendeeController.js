/**
 * Attendee Payment Controller
 * ---------------------------
 * Handles attendee registration payment creation, success callback,
 * and failure callback.
 *
 * IMPORTANT: This is completely separate from paper submission payments.
 * Attendee data is stored in the 'attendees' Firestore collection.
 *
 * SECURITY CONSTRAINTS:
 * - Amount is ALWAYS ₹100, hardcoded server-side.
 * - Hash is generated server-side only; salt is never exposed.
 * - Duplicate registrations are prevented via email uniqueness check.
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

// Attendee registration fee — HARDCODED, never trust frontend
const ATTENDEE_FEE = "100.00";

/**
 * Get the Easebuzz API base URL based on environment.
 */
function getEasebuzzBaseUrl() {
    return EASEBUZZ_ENV() === "live"
        ? "https://pay.easebuzz.in"
        : "https://testpay.easebuzz.in";
}

/**
 * Generate attendee receipt number.
 * Format: EVT-ATT-2026-<random4digits>
 */
function generateAttendeeReceiptNumber() {
    const randomPart = Math.floor(1000 + Math.random() * 9000);
    return `EVT-ATT-2026-${randomPart}`;
}

/**
 * POST /create-attendee-payment
 *
 * Request body: { name, email, phone, organization, frontendUrl }
 *
 * Flow:
 * 1. Validate input fields
 * 2. Check for duplicate registration (by email)
 * 3. Set amount = 100 (hardcoded)
 * 4. Generate txnid and hash
 * 5. Call Easebuzz initiate API
 * 6. Store pending attendee record
 * 7. Return payment URL to frontend
 */
async function createAttendeePayment(req, res) {
    try {
        const {
            name,
            email,
            phone,
            organization,
            frontendUrl: clientFrontendUrl,
        } = req.body;

        // ─── Validate required fields ───
        if (!name || !name.trim()) {
            return res
                .status(400)
                .json({ success: false, error: "Full name is required." });
        }
        if (!email || !email.trim()) {
            return res
                .status(400)
                .json({ success: false, error: "Email is required." });
        }
        if (!phone || !phone.trim()) {
            return res
                .status(400)
                .json({ success: false, error: "Phone number is required." });
        }

        // Basic email format validation
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email.trim())) {
            return res
                .status(400)
                .json({ success: false, error: "Invalid email format." });
        }

        // Basic phone validation (at least 10 digits)
        const phoneDigits = phone.replace(/\D/g, "");
        if (phoneDigits.length < 10) {
            return res
                .status(400)
                .json({ success: false, error: "Invalid phone number." });
        }

        const db = getDb();

        // ─── Check for duplicate registration (by email) ───
        const existingSnap = await db
            .collection("attendees")
            .where("email", "==", email.trim().toLowerCase())
            .where("paymentStatus", "==", "paid")
            .limit(1)
            .get();

        if (!existingSnap.empty) {
            return res.status(409).json({
                success: false,
                error: "This email is already registered as an attendee.",
                existingTxnId: existingSnap.docs[0].data().txnid,
            });
        }

        // Use client-provided URL if available, otherwise fall back to env
        const frontendUrl =
            clientFrontendUrl ||
            process.env.FRONTEND_URL ||
            "http://localhost:5000";

        // ─── Build payment payload ───
        const amount = ATTENDEE_FEE; // NEVER trust frontend amount
        const txnid = generateTxnId();
        const firstname = name.trim();
        const cleanEmail = email.trim().toLowerCase();
        const cleanPhone = phoneDigits.slice(-10); // Last 10 digits
        const productinfo = "Attendee Registration Fee";

        const key = EASEBUZZ_KEY();
        const salt = EASEBUZZ_SALT();

        const hash = generatePaymentHash({
            key,
            txnid,
            amount,
            productinfo,
            firstname,
            email: cleanEmail,
            salt,
        });

        // ─── Call Easebuzz initiate API ───
        const backendBaseUrl =
            process.env.BACKEND_URL ||
            `${req.protocol}://${req.get("host")}`;

        const initiatePayload = {
            key,
            txnid,
            amount,
            productinfo,
            firstname,
            email: cleanEmail,
            phone: cleanPhone,
            surl: `${backendBaseUrl}/api/attendee-payment-success`,
            furl: `${backendBaseUrl}/api/attendee-payment-failure`,
            hash,
        };

        const easebuzzInitUrl = `${getEasebuzzBaseUrl()}/payment/initiateLink`;
        const formData = new URLSearchParams(initiatePayload).toString();

        const easebuzzResponse = await axios.post(easebuzzInitUrl, formData, {
            headers: {
                "Content-Type": "application/x-www-form-urlencoded",
            },
        });

        // Safely parse response
        let responseData = easebuzzResponse.data;
        if (typeof responseData === "string") {
            try {
                responseData = JSON.parse(responseData);
            } catch (e) {
                /* not JSON */
            }
        }

        if (responseData && responseData.status == 1) {
            // ─── Store pending attendee record ───
            await db.collection("attendees").add({
                name: firstname,
                email: cleanEmail,
                phone: cleanPhone,
                organization: (organization || "").trim(),
                amount: parseFloat(amount),
                txnid,
                paymentStatus: "pending",
                paymentType: "attendee_registration",
                paymentInitiatedAt: new Date().toISOString(),
                paymentFrontendUrl: frontendUrl,
                receiptNumber: null,
            });

            const accessKey = responseData.data;
            const paymentUrl = `${getEasebuzzBaseUrl()}/pay/${accessKey}`;

            console.log(
                `[ATTENDEE] Payment initiated for ${cleanEmail}, txnid=${txnid}`
            );

            return res.status(200).json({
                success: true,
                paymentUrl,
                accessKey,
                txnid,
                amount,
            });
        } else {
            console.error("[ATTENDEE] Easebuzz initiate failed:", responseData);
            return res.status(500).json({
                success: false,
                error: "Failed to initiate payment with gateway.",
                details: responseData?.message || "Unknown error",
            });
        }
    } catch (error) {
        console.error("[ATTENDEE] Create payment error:", error);
        return res.status(500).json({
            success: false,
            error: "Internal server error.",
            details: error.message,
        });
    }
}

/**
 * POST /attendee-payment-success
 *
 * Called by Easebuzz after successful attendee payment.
 * Verifies hash, updates Firestore attendees collection, redirects to Flutter.
 */
async function attendeePaymentSuccess(req, res) {
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

        console.log("[ATTENDEE] Payment success callback:", {
            txnid,
            amount,
            status,
        });

        const key = EASEBUZZ_KEY();
        const salt = EASEBUZZ_SALT();

        // ─── Verify hash ───
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
            console.error("[ATTENDEE] Hash mismatch! Possible tampering.", {
                received: receivedHash,
                expected: expectedHash,
            });

            const frontendUrl =
                process.env.FRONTEND_URL || "http://localhost:5000";
            return res.redirect(
                `${frontendUrl}/#/payment-result?status=failed&reason=hash_mismatch&txnid=${txnid}&type=attendee`
            );
        }

        // ─── Update Firestore attendees collection ───
        const db = getDb();
        const attendeesSnap = await db
            .collection("attendees")
            .where("txnid", "==", txnid)
            .limit(1)
            .get();

        let storedFrontendUrl = null;

        if (!attendeesSnap.empty) {
            const docRef = attendeesSnap.docs[0].ref;
            const existingData = attendeesSnap.docs[0].data();
            storedFrontendUrl = existingData.paymentFrontendUrl;

            // Prevent duplicate updates
            if (existingData.paymentStatus !== "paid") {
                const receiptNumber = generateAttendeeReceiptNumber();
                await docRef.update({
                    paymentStatus: "paid",
                    paymentAmount: parseFloat(amount),
                    paymentDate: new Date().toISOString(),
                    paymentGatewayStatus: status,
                    receiptNumber,
                });

                console.log(
                    `[ATTENDEE] Payment completed: ${email}, receipt=${receiptNumber}`
                );
            }
        }

        const frontendUrl =
            storedFrontendUrl ||
            process.env.FRONTEND_URL ||
            "http://localhost:5000";
        return res.redirect(
            `${frontendUrl}/#/payment-result?status=success&txnid=${txnid}&amount=${amount}&type=attendee`
        );
    } catch (error) {
        console.error("[ATTENDEE] Payment success handler error:", error);
        const frontendUrl =
            process.env.FRONTEND_URL || "http://localhost:5000";
        return res.redirect(
            `${frontendUrl}/#/payment-result?status=failed&reason=server_error&type=attendee`
        );
    }
}

/**
 * POST /attendee-payment-failure
 *
 * Called by Easebuzz after failed/cancelled attendee payment.
 * Resets payment status, redirects to Flutter.
 */
async function attendeePaymentFailure(req, res) {
    try {
        const { txnid, status } = req.body;

        console.log("[ATTENDEE] Payment failure callback:", { txnid, status });

        const db = getDb();
        const attendeesSnap = await db
            .collection("attendees")
            .where("txnid", "==", txnid)
            .limit(1)
            .get();

        let storedFrontendUrl = null;

        if (!attendeesSnap.empty) {
            const docRef = attendeesSnap.docs[0].ref;
            const existingData = attendeesSnap.docs[0].data();
            storedFrontendUrl = existingData.paymentFrontendUrl;

            // Only reset if not already paid (safety check)
            if (existingData.paymentStatus !== "paid") {
                await docRef.update({
                    paymentStatus: "failed",
                    paymentGatewayStatus: status || "failed",
                    paymentFailedAt: new Date().toISOString(),
                });
            }
        }

        const frontendUrl =
            storedFrontendUrl ||
            process.env.FRONTEND_URL ||
            "http://localhost:5000";
        return res.redirect(
            `${frontendUrl}/#/payment-result?status=failed&txnid=${txnid}&reason=payment_failed&type=attendee`
        );
    } catch (error) {
        console.error("[ATTENDEE] Payment failure handler error:", error);
        const frontendUrl =
            process.env.FRONTEND_URL || "http://localhost:5000";
        return res.redirect(
            `${frontendUrl}/#/payment-result?status=failed&reason=server_error&type=attendee`
        );
    }
}

/**
 * GET /attendee-status/:email
 *
 * Returns the attendee registration status for a given email.
 */
async function getAttendeeStatus(req, res) {
    try {
        const { email } = req.params;

        if (!email) {
            return res
                .status(400)
                .json({ success: false, error: "Email is required." });
        }

        const db = getDb();
        const attendeesSnap = await db
            .collection("attendees")
            .where("email", "==", email.toLowerCase().trim())
            .where("paymentStatus", "==", "paid")
            .limit(1)
            .get();

        if (attendeesSnap.empty) {
            return res.status(200).json({
                success: true,
                isRegistered: false,
            });
        }

        const data = attendeesSnap.docs[0].data();

        return res.status(200).json({
            success: true,
            isRegistered: true,
            name: data.name,
            email: data.email,
            txnid: data.txnid,
            receiptNumber: data.receiptNumber,
            paymentDate: data.paymentDate,
            amount: data.amount,
        });
    } catch (error) {
        console.error("[ATTENDEE] Get status error:", error);
        return res.status(500).json({
            success: false,
            error: "Internal server error.",
            message: error.message,
        });
    }
}

module.exports = {
    createAttendeePayment,
    attendeePaymentSuccess,
    attendeePaymentFailure,
    getAttendeeStatus,
};
