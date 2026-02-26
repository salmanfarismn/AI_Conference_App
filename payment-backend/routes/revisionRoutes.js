/**
 * Revision Routes
 * ---------------
 * Routes for full paper revision resubmission workflow.
 *
 * POST   /paper/resubmit/:paperId   → Resubmit revised paper (multipart)
 * GET    /paper/versions/:paperId   → Get all versions of a paper
 */

const express = require("express");
const router = express.Router();

const {
    uploadRevisedPaper,
    handleResubmitPaper,
    getPaperVersions,
    wrapMulterHandler,
} = require("../controllers/revisionController");

// ──────────────── User Routes ────────────────

// Resubmit revised paper (multipart/form-data with PDF)
router.post(
    "/paper/resubmit/:paperId",
    wrapMulterHandler(uploadRevisedPaper, handleResubmitPaper)
);

// Get all versions of a paper
router.get("/paper/versions/:paperId", getPaperVersions);

module.exports = router;
