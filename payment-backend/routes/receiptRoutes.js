/**
 * Receipt Routes
 * --------------
 * Isolated routes for receipt generation and download.
 *
 * GET /api/receipt/status/:uid    → Check if receipt is available
 * GET /api/receipt/download/:uid  → Download receipt PDF
 * GET /api/receipt/:uid           → View receipt PDF (inline)
 */

const express = require("express");
const router = express.Router();
const {
    viewReceipt,
    downloadReceipt,
    getReceiptStatus,
} = require("../controllers/receiptController");

// Receipt status check (must be before /:uid to avoid route conflict)
router.get("/receipt/status/:uid", getReceiptStatus);

// Download receipt as attachment
router.get("/receipt/download/:uid", downloadReceipt);

// View receipt inline (browser preview)
router.get("/receipt/:uid", viewReceipt);

module.exports = router;
