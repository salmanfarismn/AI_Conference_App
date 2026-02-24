/**
 * Payment Routes
 * --------------
 * Isolated routes for Easebuzz payment integration.
 * These routes are completely independent of existing backend routes.
 */

const express = require("express");
const router = express.Router();
const paymentController = require("../controllers/paymentController");

// Initiate a payment (Flutter → Backend → Easebuzz)
router.post("/create-payment", paymentController.createPayment);

// Easebuzz success callback (Easebuzz → Backend → Redirect to Flutter)
router.post("/payment-success", paymentController.paymentSuccess);

// Easebuzz failure callback (Easebuzz → Backend → Redirect to Flutter)
router.post("/payment-failure", paymentController.paymentFailure);

// Get payment status for a user
router.get("/payment-status/:uid", paymentController.getPaymentStatus);

module.exports = router;
