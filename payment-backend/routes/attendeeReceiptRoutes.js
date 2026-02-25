/**
 * Attendee Receipt Routes
 * ------------------------
 * Isolated routes for attendee receipt generation and download.
 * These routes use txnid (not uid) since attendees may not be registered users.
 *
 * GET /api/attendee-receipt/download/:txnid  → Download receipt PDF
 * GET /api/attendee-receipt/:txnid           → View receipt PDF (inline)
 */

const express = require("express");
const router = express.Router();
const {
    viewAttendeeReceipt,
    downloadAttendeeReceipt,
} = require("../controllers/attendeeReceiptController");

// Download attendee receipt as attachment (must be before /:txnid to avoid route conflict)
router.get("/attendee-receipt/download/:txnid", downloadAttendeeReceipt);

// View attendee receipt inline (browser preview)
router.get("/attendee-receipt/:txnid", viewAttendeeReceipt);

module.exports = router;
