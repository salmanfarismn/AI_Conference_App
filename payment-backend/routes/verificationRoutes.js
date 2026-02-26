/**
 * Verification Routes
 * -------------------
 * Routes for document verification (ID card + payment receipt uploads).
 *
 * POST   /upload-id-card              → Upload ID card image
 * POST   /upload-payment-receipt      → Upload payment receipt image
 * GET    /verification-status/:userId → Get verification status
 * POST   /admin/verify-user           → Admin approve/reject
 * GET    /admin/verification-list     → Admin list pending verifications
 */

const express = require("express");
const router = express.Router();

const {
    uploadIdCard,
    uploadPaymentReceipt,
    handleUploadIdCard,
    handleUploadPaymentReceipt,
    getVerificationStatus,
    adminVerifyUser,
    adminGetVerificationList,
    wrapMulterHandler,
} = require("../controllers/verificationController");

// ──────────────── User Routes ────────────────

// Upload ID card image (multipart/form-data)
router.post(
    "/upload-id-card",
    wrapMulterHandler(uploadIdCard, handleUploadIdCard)
);

// Upload payment receipt image (multipart/form-data)
router.post(
    "/upload-payment-receipt",
    wrapMulterHandler(uploadPaymentReceipt, handleUploadPaymentReceipt)
);

// Get verification status for a user
router.get("/verification-status/:userId", getVerificationStatus);

// ──────────────── Admin Routes ────────────────

// Admin: approve or reject a user's verification
router.post("/admin/verify-user", adminVerifyUser);

// Admin: list all users with verification documents
router.get("/admin/verification-list", adminGetVerificationList);

module.exports = router;
