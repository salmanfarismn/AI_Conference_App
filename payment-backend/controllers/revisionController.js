/**
 * Revision Controller
 * -------------------
 * Handles full paper revision resubmission workflow.
 *
 * COMPLETELY ISOLATED — does NOT modify any existing controllers,
 * authentication, payment, abstract, or original submission logic.
 *
 * Routes:
 *   POST   /paper/resubmit/:paperId   → Resubmit revised paper
 *   GET    /paper/versions/:paperId   → Get all versions of a paper
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

const storage = multer.memoryStorage();

const ALLOWED_PDF_MIME_TYPES = [
    "application/pdf",
];
const ALLOWED_PDF_EXTENSIONS = [".pdf"];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

const fileFilter = (req, file, cb) => {
    // Check MIME type
    if (ALLOWED_PDF_MIME_TYPES.includes(file.mimetype)) {
        return cb(null, true);
    }
    // Fallback: check file extension (Flutter Web may send application/octet-stream)
    const ext = (file.originalname || "").toLowerCase().split(".").pop();
    if (ext && ALLOWED_PDF_EXTENSIONS.includes(`.${ext}`)) {
        return cb(null, true);
    }
    cb(
        new Error(
            "Invalid file type. Only PDF files are allowed for paper resubmission."
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
const uploadRevisedPaper = upload.single("revisedPaper");

// ──────────────── Helper: Upload buffer to Cloudinary ────────────────

/**
 * Uploads a PDF buffer to Cloudinary.
 * @param {Buffer} buffer   File buffer from multer
 * @param {string} folder   Cloudinary folder path
 * @param {string} publicId Unique public ID
 * @returns {Promise<string>} Secure URL of uploaded file
 */
function uploadToCloudinary(buffer, folder, publicId) {
    return new Promise((resolve, reject) => {
        const uploadStream = cloudinary.uploader.upload_stream(
            {
                folder,
                public_id: publicId,
                resource_type: "raw", // PDF files use 'raw' resource type
                overwrite: true,
                secure: true,
            },
            (error, result) => {
                if (error) {
                    console.error("[REVISION] Cloudinary upload error:", error);
                    reject(error);
                } else {
                    resolve(result.secure_url);
                }
            }
        );
        uploadStream.end(buffer);
    });
}

// ──────────────── POST /paper/resubmit/:paperId ────────────────

/**
 * Resubmit a revised paper.
 *
 * URL Params:
 *   - paperId (string) — Firestore document ID of the submission
 *
 * Body (multipart/form-data):
 *   - userId (string)       — Firebase user UID
 *   - revisedPaper (file)   — PDF file (max 10MB)
 *
 * Logic:
 *   1. Validate authenticated user
 *   2. Ensure paper belongs to user
 *   3. Ensure current status == accepted_with_revision
 *   4. Upload to Cloudinary
 *   5. Archive current version into versions[] array
 *   6. Increment currentVersion
 *   7. Update pdfUrl to new file
 *   8. Set status = pending_review
 */
async function handleResubmitPaper(req, res) {
    try {
        const { paperId } = req.params;
        const { userId } = req.body;

        // ─── Validate inputs ───
        if (!paperId || !paperId.trim()) {
            return res.status(400).json({
                success: false,
                error: "paperId URL parameter is required.",
            });
        }

        if (!userId || !userId.trim()) {
            return res.status(400).json({
                success: false,
                error: "userId is required.",
            });
        }

        if (!req.file) {
            return res.status(400).json({
                success: false,
                error: "No file uploaded. Please select a PDF file (max 10MB).",
            });
        }

        // ─── Fetch paper from Firestore ───
        const db = getDb();
        const paperRef = db.collection("submissions").doc(paperId);
        const paperDoc = await paperRef.get();

        if (!paperDoc.exists) {
            return res.status(404).json({
                success: false,
                error: "Paper submission not found.",
            });
        }

        const paperData = paperDoc.data();

        // ─── Validate ownership ───
        if (paperData.uid !== userId) {
            console.warn(
                `[REVISION] Unauthorized resubmission attempt: user ${userId} tried to resubmit paper owned by ${paperData.uid}`
            );
            return res.status(403).json({
                success: false,
                error: "You are not authorized to resubmit this paper.",
            });
        }

        // ─── Validate paper type ───
        if (paperData.submissionType !== "fullpaper") {
            return res.status(400).json({
                success: false,
                error: "Only full paper submissions can be revised.",
            });
        }

        // ─── Validate current status ───
        if (paperData.status !== "accepted_with_revision") {
            return res.status(400).json({
                success: false,
                error: `Paper cannot be resubmitted. Current status is '${paperData.status}'. Only papers with status 'accepted_with_revision' can be revised.`,
            });
        }

        // ─── Calculate version numbers ───
        const currentVersion = paperData.currentVersion || 1;
        const newVersion = currentVersion + 1;
        const existingVersions = paperData.versions || [];

        // ─── Archive current version into versions array ───
        const archivedVersion = {
            version: currentVersion,
            fileUrl: paperData.pdfUrl || "",
            submittedAt: paperData.updatedAt || paperData.createdAt || admin.firestore.FieldValue.serverTimestamp(),
            status: paperData.status,
            adminComment: paperData.reviewComments || "",
            reviewedBy: paperData.reviewedBy || "",
            reviewedAt: paperData.reviewedAt || null,
        };

        // ─── Upload to Cloudinary ───
        const referenceNumber = paperData.referenceNumber || paperId;
        const timestamp = Date.now();
        const publicId = `${referenceNumber}_v${newVersion}_${timestamp}`;
        const folder = "conference/full-papers/revisions";

        console.log(
            `[REVISION] Uploading revised paper for ${referenceNumber} (v${newVersion})...`
        );
        const secureUrl = await uploadToCloudinary(
            req.file.buffer,
            folder,
            publicId
        );
        console.log(`[REVISION] Revised paper uploaded: ${secureUrl}`);

        // ─── Update Firestore ───
        const updatedVersions = [...existingVersions, archivedVersion];

        await paperRef.update({
            pdfUrl: secureUrl,
            status: "pending_review",
            currentVersion: newVersion,
            versions: updatedVersions,
            reviewComments: "", // Clear admin comments for new version
            reviewedBy: admin.firestore.FieldValue.delete(), // Clear reviewer
            reviewedAt: admin.firestore.FieldValue.delete(), // Clear review timestamp
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastRevisionAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(
            `[REVISION] ✅ Paper ${paperId} (${referenceNumber}) revised to v${newVersion} by user ${userId}`
        );

        return res.status(200).json({
            success: true,
            message: `Paper revised successfully. Now at version ${newVersion}.`,
            paperId,
            referenceNumber,
            currentVersion: newVersion,
            newFileUrl: secureUrl,
            status: "pending_review",
            totalVersions: updatedVersions.length,
        });
    } catch (error) {
        console.error("[REVISION] Resubmission error:", error);

        if (error.code === "LIMIT_FILE_SIZE") {
            return res.status(400).json({
                success: false,
                error: "File size exceeds 10MB limit.",
            });
        }

        return res.status(500).json({
            success: false,
            error: "Internal server error.",
            details: error.message,
        });
    }
}

// ──────────────── GET /paper/versions/:paperId ────────────────

/**
 * Get all versions of a paper submission.
 *
 * URL Params:
 *   - paperId (string) — Firestore document ID
 *
 * Query Params:
 *   - userId (string) — Firebase user UID (for ownership check)
 *   - adminId (string) — Optional admin UID (bypasses ownership)
 */
async function getPaperVersions(req, res) {
    try {
        const { paperId } = req.params;
        const { userId, adminId } = req.query;

        if (!paperId) {
            return res.status(400).json({
                success: false,
                error: "paperId is required.",
            });
        }

        if (!userId && !adminId) {
            return res.status(400).json({
                success: false,
                error: "userId or adminId query parameter is required.",
            });
        }

        const db = getDb();
        const paperDoc = await db.collection("submissions").doc(paperId).get();

        if (!paperDoc.exists) {
            return res.status(404).json({
                success: false,
                error: "Paper submission not found.",
            });
        }

        const paperData = paperDoc.data();

        // Check access: either the paper owner or an admin
        if (adminId) {
            // Verify admin privileges
            let isAdmin = false;
            try {
                const userRecord = await admin.auth().getUser(adminId);
                if (
                    userRecord.customClaims &&
                    userRecord.customClaims.role === "admin"
                ) {
                    isAdmin = true;
                }
            } catch (_) { }

            if (!isAdmin) {
                const adminDoc = await db
                    .collection("admins")
                    .doc(adminId)
                    .get();
                if (adminDoc.exists) isAdmin = true;
            }

            if (!isAdmin) {
                return res.status(403).json({
                    success: false,
                    error: "Unauthorized. Admin privileges required.",
                });
            }
        } else if (paperData.uid !== userId) {
            return res.status(403).json({
                success: false,
                error: "You can only view versions of your own papers.",
            });
        }

        // Build version list including current version
        const versions = paperData.versions || [];
        const currentVersionEntry = {
            version: paperData.currentVersion || 1,
            fileUrl: paperData.pdfUrl || "",
            submittedAt: paperData.updatedAt || paperData.createdAt || null,
            status: paperData.status,
            adminComment: paperData.reviewComments || "",
            reviewedBy: paperData.reviewedBy || "",
            reviewedAt: paperData.reviewedAt || null,
            isCurrent: true,
        };

        return res.status(200).json({
            success: true,
            paperId,
            referenceNumber: paperData.referenceNumber || "",
            title: paperData.title || "",
            currentVersion: paperData.currentVersion || 1,
            status: paperData.status,
            versions: [...versions, currentVersionEntry],
        });
    } catch (error) {
        console.error("[REVISION] Get versions error:", error);
        return res.status(500).json({
            success: false,
            error: "Internal server error.",
            details: error.message,
        });
    }
}

// ──────────────── Multer Error Handler ────────────────

function wrapMulterHandler(multerMiddleware, handler) {
    return (req, res, next) => {
        multerMiddleware(req, res, (err) => {
            if (err) {
                if (err instanceof multer.MulterError) {
                    if (err.code === "LIMIT_FILE_SIZE") {
                        return res.status(400).json({
                            success: false,
                            error: "File size exceeds 10MB limit.",
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
    uploadRevisedPaper,
    handleResubmitPaper,
    getPaperVersions,
    wrapMulterHandler,
};
