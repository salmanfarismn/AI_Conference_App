/**
 * Attendee Routes
 * ----------------
 * Isolated routes for attendee registration payment integration.
 * These routes are completely separate from paper submission payment routes.
 *
 * POST /api/create-attendee-payment       → Initiate attendee payment
 * POST /api/attendee-payment-success      → Easebuzz success callback
 * POST /api/attendee-payment-failure      → Easebuzz failure callback
 * GET  /api/attendee-status/:email        → Check attendee registration status
 */

const express = require("express");
const router = express.Router();
const attendeeController = require("../controllers/attendeeController");

// Initiate attendee payment (Frontend → Backend → Easebuzz)
router.post("/create-attendee-payment", attendeeController.createAttendeePayment);

// Easebuzz success callback (Easebuzz → Backend → Redirect to Flutter)
router.post("/attendee-payment-success", attendeeController.attendeePaymentSuccess);

// Easebuzz failure callback (Easebuzz → Backend → Redirect to Flutter)
router.post("/attendee-payment-failure", attendeeController.attendeePaymentFailure);

// Get attendee registration status by email
router.get("/attendee-status/:email", attendeeController.getAttendeeStatus);

module.exports = router;
