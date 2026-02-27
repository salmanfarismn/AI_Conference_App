/**
 * Verification Controller
 * -----------------------
 * Handles ID card and payment receipt image uploads to Cloudinary,
 * stores URLs in Firestore, and provides admin verification workflow.
 *
 * COMPLETELY ISOLATED — does NOT modify any existing controllers,
 * authentication, payment, or submission logic.
 *
 * Routes:
 *   POST   /upload-id-card              → Upload ID card image
 *   POST   /upload-payment-receipt      → Upload payment receipt image
 *   GET    /verification-status/:userId → Get verification status
 *   POST   /admin/verify-user           → Admin approve/reject
 *   GET    /admin/verification-list     → Admin list all pending verifications
 */

const { getDb } = require("../utils/firebase");
const admin = require("firebase-admin");
const cloudinary = require("cloudinary").v2;
const multer = require("multer");

// ──────────────── Cloudinary Configuration ────────────────

cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
});

// ──────────────── Multer Configuration ────────────────

// Store files in memory (buffer) for streaming to Cloudinary
const storage = multer.memoryStorage();

const ALLOWED_MIME_TYPES = ["image/jpeg", "image/jpg", "image/png"];
const ALLOWED_EXTENSIONS = [".jpg", ".jpeg", ".png"];
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

const fileFilter = (req, file, cb) => {
    // Check MIME type first
    if (ALLOWED_MIME_TYPES.includes(file.mimetype)) {
        return cb(null, true);
    }
    // Fallback: check file extension (Flutter Web may send application/octet-stream)
    const ext = (file.originalname || "").toLowerCase().split(".").pop();
    if (ext && ALLOWED_EXTENSIONS.includes(`.${ext}`)) {
        return cb(null, true);
    }
    cb(
        new Error(
            "Invalid file type. Only JPG, JPEG, and PNG images are allowed."
        ),
        false
    );
};

const upload = multer({
    storage,
    fileFilter,
    limits: { fileSize: MAX_FILE_SIZE },
});

// Export multer middleware for routes
const uploadIdCard = upload.single("idCard");
const uploadPaymentReceipt = upload.single("paymentReceipt");

// ──────────────── Helper: Upload buffer to Cloudinary ────────────────

/**
 * Uploads a file buffer to Cloudinary.
 * @param {Buffer} buffer   File buffer from multer
 * @param {string} folder   Cloudinary folder path
 * @param {string} publicId Unique public ID (userId_timestamp)
 * @returns {Promise<string>} Secure URL of uploaded image
 */
function uploadToCloudinary(buffer, folder, publicId) {
    return new Promise((resolve, reject) => {
        const uploadStream = cloudinary.uploader.upload_stream(
            {
                folder,
                public_id: publicId,
                resource_type: "image",
                overwrite: true,
                secure: true,
            },
            (error, result) => {
                if (error) {
                    console.error("[VERIFICATION] Cloudinary upload error:", error);
                    reject(error);
                } else {
                    resolve(result.secure_url);
                }
            }
        );
        uploadStream.end(buffer);
    });
}

// ──────────────── Helper: Validate user exists ────────────────

/**
 * Verify that a user document exists in Firestore.
 * Returns the user data or null.
 */
async function getUserData(userId) {
    const db = getDb();
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) return null;
    return userDoc.data();
}

/**
 * Check if userId matches an admin.
 * This project uses Firebase Auth custom claims (role === 'admin').
 * We check that first via Admin SDK, then fall back to Firestore.
 */
async function isAdminUser(adminId) {
    console.log(`[VERIFICATION] Checking admin status for UID: ${adminId}`);

    try {
        // Primary: Check Firebase Auth custom claims
        const userRecord = await admin.auth().getUser(adminId);
        console.log(`[VERIFICATION] Custom claims for ${adminId}:`, JSON.stringify(userRecord.customClaims));
        if (userRecord.customClaims && userRecord.customClaims.role === "admin") {
            console.log(`[VERIFICATION] ✅ Admin confirmed via custom claims`);
            return true;
        }
    } catch (err) {
        console.warn("[VERIFICATION] Could not check custom claims for", adminId, err.message);
    }

    // Fallback: Check Firestore admins collection
    const db = getDb();
    const adminDoc = await db.collection("admins").doc(adminId).get();
    console.log(`[VERIFICATION] admins/${adminId} exists:`, adminDoc.exists);
    if (adminDoc.exists) return true;

    // Fallback: Check users collection for admin role
    const userDoc = await db.collection("users").doc(adminId).get();
    console.log(`[VERIFICATION] users/${adminId} exists:`, userDoc.exists, "role:", userDoc.exists ? userDoc.data().role : "N/A");
    if (userDoc.exists && userDoc.data().role === "admin") return true;

    console.log(`[VERIFICATION] ❌ Admin check FAILED for ${adminId}`);
    return false;
}

// ──────────────── POST /upload-id-card ────────────────

/**
 * Upload ID card image.
 * Body: multipart/form-data with fields:
 *   - userId (string)  — Firebase user UID
 *   - idCard (file)    — Image file (JPG/PNG/JPEG, max 5MB)
 */
async function handleUploadIdCard(req, res) {
    try {
        const { userId } = req.body;

        // Validate userId
        if (!userId || !userId.trim()) {
            return res.status(400).json({
                success: false,
                error: "userId is required.",
            });
        }

        // Validate file was provided
        if (!req.file) {
            return res.status(400).json({
                success: false,
                error: "No file uploaded. Please select a JPG, JPEG, or PNG image (max 5MB).",
            });
        }

        // Verify user exists
        const userData = await getUserData(userId);
        if (!userData) {
            return res.status(404).json({
                success: false,
                error: "User not found.",
            });
        }

        // Check if already approved — prevent re-upload
        if (userData.verificationStatus === "approved") {
            return res.status(400).json({
                success: false,
                error: "Your documents are already verified. Re-upload is not allowed.",
            });
        }

        // Upload to Cloudinary
        const timestamp = Date.now();
        const publicId = `${userId}_${timestamp}`;
        const folder = "conference/id-cards";

        console.log(`[VERIFICATION] Uploading ID card for user ${userId}...`);
        const secureUrl = await uploadToCloudinary(req.file.buffer, folder, publicId);
        console.log(`[VERIFICATION] ID card uploaded: ${secureUrl}`);

        // Update Firestore user document
        const db = getDb();
        await db.collection("users").doc(userId).set(
            {
                idCardUrl: secureUrl,
                verificationStatus: userData.verificationStatus === "rejected" ? "pending" : (userData.verificationStatus || "pending"),
                lastDocumentUploadAt: new Date().toISOString(),
            },
            { merge: true }
        );

        return res.status(200).json({
            success: true,
            message: "ID card uploaded successfully.",
            idCardUrl: secureUrl,
            verificationStatus: "pending",
        });
    } catch (error) {
        console.error("[VERIFICATION] Upload ID card error:", error);

        // Handle multer-specific errors
        if (error.code === "LIMIT_FILE_SIZE") {
            return res.status(400).json({
                success: false,
                error: "File size exceeds 5MB limit.",
            });
        }

        return res.status(500).json({
            success: false,
            error: "Internal server error.",
            details: error.message,
        });
    }
}

// ──────────────── POST /upload-payment-receipt ────────────────

/**
 * Upload payment receipt image.
 * Body: multipart/form-data with fields:
 *   - userId (string)        — Firebase user UID
 *   - paymentReceipt (file)  — Image file (JPG/PNG/JPEG, max 5MB)
 */
async function handleUploadPaymentReceipt(req, res) {
    try {
        const { userId } = req.body;

        // Validate userId
        if (!userId || !userId.trim()) {
            return res.status(400).json({
                success: false,
                error: "userId is required.",
            });
        }

        // Validate file was provided
        if (!req.file) {
            return res.status(400).json({
                success: false,
                error: "No file uploaded. Please select a JPG, JPEG, or PNG image (max 5MB).",
            });
        }

        // Verify user exists
        const userData = await getUserData(userId);
        if (!userData) {
            return res.status(404).json({
                success: false,
                error: "User not found.",
            });
        }

        // Check if already approved — prevent re-upload
        if (userData.verificationStatus === "approved") {
            return res.status(400).json({
                success: false,
                error: "Your documents are already verified. Re-upload is not allowed.",
            });
        }

        // Upload to Cloudinary
        const timestamp = Date.now();
        const publicId = `${userId}_${timestamp}`;
        const folder = "conference/payment-receipts";

        console.log(`[VERIFICATION] Uploading payment receipt for user ${userId}...`);
        const secureUrl = await uploadToCloudinary(req.file.buffer, folder, publicId);
        console.log(`[VERIFICATION] Payment receipt uploaded: ${secureUrl}`);

        // Update Firestore user document
        const db = getDb();
        await db.collection("users").doc(userId).set(
            {
                paymentReceiptImageUrl: secureUrl,
                verificationStatus: userData.verificationStatus === "rejected" ? "pending" : (userData.verificationStatus || "pending"),
                lastDocumentUploadAt: new Date().toISOString(),
            },
            { merge: true }
        );

        return res.status(200).json({
            success: true,
            message: "Payment receipt uploaded successfully.",
            paymentReceiptImageUrl: secureUrl,
            verificationStatus: "pending",
        });
    } catch (error) {
        console.error("[VERIFICATION] Upload payment receipt error:", error);

        if (error.code === "LIMIT_FILE_SIZE") {
            return res.status(400).json({
                success: false,
                error: "File size exceeds 5MB limit.",
            });
        }

        return res.status(500).json({
            success: false,
            error: "Internal server error.",
            details: error.message,
        });
    }
}

// ──────────────── GET /verification-status/:userId ────────────────

/**
 * Get verification status for a user.
 */
async function getVerificationStatus(req, res) {
    try {
        const { userId } = req.params;

        if (!userId) {
            return res.status(400).json({
                success: false,
                error: "userId is required.",
            });
        }

        const userData = await getUserData(userId);
        if (!userData) {
            return res.status(404).json({
                success: false,
                error: "User not found.",
            });
        }

        return res.status(200).json({
            success: true,
            userId,
            idCardUrl: userData.idCardUrl || null,
            paymentReceiptImageUrl: userData.paymentReceiptImageUrl || null,
            verificationStatus: userData.verificationStatus || "not_submitted",
            verificationDate: userData.verificationDate || null,
            verifiedBy: userData.verifiedBy || null,
        });
    } catch (error) {
        console.error("[VERIFICATION] Get status error:", error);
        return res.status(500).json({
            success: false,
            error: "Internal server error.",
            details: error.message,
        });
    }
}

// ──────────────── POST /admin/verify-user ────────────────

/**
 * Admin approves or rejects a user's verification documents.
 * Body: { userId, action: "approved"|"rejected", adminId }
 */
async function adminVerifyUser(req, res) {
    try {
        const { userId, action, adminId } = req.body;

        // Validate required fields
        if (!userId || !action || !adminId) {
            return res.status(400).json({
                success: false,
                error: "userId, action, and adminId are required.",
            });
        }

        // Validate action
        if (!["approved", "rejected"].includes(action)) {
            return res.status(400).json({
                success: false,
                error: "action must be 'approved' or 'rejected'.",
            });
        }

        // Verify admin privileges
        const adminIsValid = await isAdminUser(adminId);
        if (!adminIsValid) {
            return res.status(403).json({
                success: false,
                error: "Unauthorized. Admin privileges required.",
            });
        }

        // Verify target user exists
        const userData = await getUserData(userId);
        if (!userData) {
            return res.status(404).json({
                success: false,
                error: "User not found.",
            });
        }

        // Update verification status
        const db = getDb();
        const updateData = {
            verificationStatus: action,
            verifiedBy: adminId,
        };

        if (action === "approved") {
            updateData.verificationDate = new Date().toISOString();
        }

        await db.collection("users").doc(userId).set(updateData, { merge: true });

        console.log(
            `[VERIFICATION] Admin ${adminId} ${action} user ${userId}`
        );

        return res.status(200).json({
            success: true,
            message: `User verification ${action} successfully.`,
            userId,
            verificationStatus: action,
        });
    } catch (error) {
        console.error("[VERIFICATION] Admin verify error:", error);
        return res.status(500).json({
            success: false,
            error: "Internal server error.",
            details: error.message,
        });
    }
}

// ──────────────── GET /admin/verification-list ────────────────

/**
 * Admin: List all users who have uploaded verification documents.
 * Returns users with idCardUrl or paymentReceiptImageUrl set.
 */
async function adminGetVerificationList(req, res) {
    try {
        const { adminId } = req.query;

        // Verify admin
        if (!adminId) {
            return res.status(400).json({
                success: false,
                error: "adminId query parameter is required.",
            });
        }

        const adminIsValid = await isAdminUser(adminId);
        if (!adminIsValid) {
            return res.status(403).json({
                success: false,
                error: "Unauthorized. Admin privileges required.",
            });
        }

        const db = getDb();

        // Get all users who have a verificationStatus field
        const usersSnap = await db
            .collection("users")
            .where("verificationStatus", "in", ["pending", "approved", "rejected"])
            .get();

        const users = [];
        usersSnap.forEach((doc) => {
            const data = doc.data();
            const institution = data.institution || "";
            // Check exemption status from institution
            const normalizedInst = institution.toLowerCase().trim();
            const isExempt = ["uc college", "union christian college"].includes(normalizedInst);

            users.push({
                userId: doc.id,
                name: data.name || "",
                email: data.email || "",
                phone: data.phone || "",
                role: data.role || "",
                institution: institution,
                idCardUrl: data.idCardUrl || null,
                paymentReceiptImageUrl: data.paymentReceiptImageUrl || null,
                verificationStatus: data.verificationStatus || "not_submitted",
                verificationDate: data.verificationDate || null,
                verifiedBy: data.verifiedBy || null,
                lastDocumentUploadAt: data.lastDocumentUploadAt || null,
                paymentExempted: isExempt,
                exemptionReason: isExempt ? "Institutional Fee Waiver" : null,
            });
        });

        // Sort: pending first, then rejected, then approved
        const statusOrder = { pending: 0, rejected: 1, approved: 2 };
        users.sort(
            (a, b) =>
                (statusOrder[a.verificationStatus] || 3) -
                (statusOrder[b.verificationStatus] || 3)
        );

        return res.status(200).json({
            success: true,
            count: users.length,
            users,
        });
    } catch (error) {
        console.error("[VERIFICATION] Admin list error:", error);
        return res.status(500).json({
            success: false,
            error: "Internal server error.",
            details: error.message,
        });
    }
}

// ──────────────── Multer Error Handler Middleware ────────────────

/**
 * Wraps a multer upload middleware + handler to catch multer errors gracefully.
 */
function wrapMulterHandler(multerMiddleware, handler) {
    return (req, res, next) => {
        multerMiddleware(req, res, (err) => {
            if (err) {
                if (err instanceof multer.MulterError) {
                    if (err.code === "LIMIT_FILE_SIZE") {
                        return res.status(400).json({
                            success: false,
                            error: "File size exceeds 5MB limit.",
                        });
                    }
                    return res.status(400).json({
                        success: false,
                        error: `Upload error: ${err.message}`,
                    });
                }
                return res.status(400).json({
                    success: false,
                    error: err.message || "File upload error.",
                });
            }
            handler(req, res, next);
        });
    };
}

module.exports = {
    uploadIdCard,
    uploadPaymentReceipt,
    handleUploadIdCard,
    handleUploadPaymentReceipt,
    getVerificationStatus,
    adminVerifyUser,
    adminGetVerificationList,
    wrapMulterHandler,
};
