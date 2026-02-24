/**
 * Easebuzz Hash Utility
 * ---------------------
 * Generates and verifies SHA-512 hashes for Easebuzz payment gateway.
 * SECURITY: This module MUST run server-side only. Never expose salt.
 */

const crypto = require("crypto");

/**
 * Generate SHA-512 hash for payment initiation.
 * Format: key|txnid|amount|productinfo|firstname|email|||||||||||salt
 */
function generatePaymentHash({
    key,
    txnid,
    amount,
    productinfo,
    firstname,
    email,
    salt,
}) {
    const hashString = `${key}|${txnid}|${amount}|${productinfo}|${firstname}|${email}|||||||||||${salt}`;
    return crypto.createHash("sha512").update(hashString).digest("hex");
}

/**
 * Generate reverse hash for payment verification (response callback).
 * Format: salt|status|||||||||||email|firstname|productinfo|amount|txnid|key
 */
function generateReverseHash({
    salt,
    status,
    email,
    firstname,
    productinfo,
    amount,
    txnid,
    key,
}) {
    const hashString = `${salt}|${status}|||||||||||${email}|${firstname}|${productinfo}|${amount}|${txnid}|${key}`;
    return crypto.createHash("sha512").update(hashString).digest("hex");
}

/**
 * Generate a unique transaction ID.
 * Format: TXN_<timestamp>_<random6chars>
 */
function generateTxnId() {
    const timestamp = Date.now();
    const random = crypto.randomBytes(3).toString("hex").toUpperCase();
    return `TXN_${timestamp}_${random}`;
}

module.exports = {
    generatePaymentHash,
    generateReverseHash,
    generateTxnId,
};
