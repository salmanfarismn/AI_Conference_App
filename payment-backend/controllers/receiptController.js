/**
 * Receipt Controller
 * ------------------
 * Handles receipt generation and serving for paid users.
 *
 * SECURITY CONSTRAINTS:
 * - Only users with paymentStatus === "paid" can access receipt.
 * - UID is validated against Firestore.
 * - Receipts are generated on-demand (no storage cost).
 * - Receipt number is stored in Firestore for reference.
 */

const PDFDocument = require("pdfkit");
const { getDb } = require("../utils/firebase");
const path = require("path");
const fs = require("fs");

// ─────────── Constants ───────────

const EVENT_NAME = "UCC ICON 2026";
const SUPPORT_EMAIL = "tcs2026@uccollege.edu.in";

// ─────────── PDF Generation ───────────

/**
 * Build a clean, minimal receipt PDF matching the design reference.
 * Green checkmark → "Payment Successful" → simple table → footer.
 */
function generateReceiptPDF(res, { userData, submission, receiptNumber, disposition }) {
    const doc = new PDFDocument({
        size: "A4",
        margin: 60,
        info: {
            Title: `Receipt - ${receiptNumber}`,
            Author: EVENT_NAME,
            Subject: "Payment Receipt",
        },
    });

    // Set response headers
    const filename = `Receipt_${receiptNumber}.pdf`;
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader(
        "Content-Disposition",
        `${disposition}; filename="${filename}"`
    );

    doc.pipe(res);

    const pageWidth = doc.page.width - 120; // 60 margin each side
    const leftMargin = 60;

    // ──── Colors ────
    const SUCCESS_GREEN = "#16a34a";
    const TEXT_DARK = "#1a1a2e";
    const TEXT_GRAY = "#555555";
    const ROW_GRAY = "#f0f0f0";
    const BORDER_GRAY = "#cccccc";
    const AMOUNT_GREEN = "#16a34a";

    // ──── GREEN CHECKMARK CIRCLE ────
    const centerX = doc.page.width / 2;
    let currentY = 80;

    // Green circle
    const circleRadius = 30;
    doc.circle(centerX, currentY, circleRadius).fill(SUCCESS_GREEN);

    // White checkmark (drawn as lines)
    doc.strokeColor("#ffffff")
        .lineWidth(4)
        .lineCap("round")
        .lineJoin("round");
    doc.moveTo(centerX - 14, currentY)
        .lineTo(centerX - 4, currentY + 12)
        .lineTo(centerX + 16, currentY - 10)
        .stroke();

    // ──── HEADING ────
    currentY += circleRadius + 25;

    doc.fontSize(24)
        .fillColor(TEXT_DARK)
        .font("Helvetica-Bold")
        .text("Payment Successful", leftMargin, currentY, {
            width: pageWidth,
            align: "center",
        });

    currentY += 35;

    doc.fontSize(12)
        .fillColor(TEXT_GRAY)
        .font("Helvetica")
        .text(`Thank you for registering for ${EVENT_NAME}!`, leftMargin, currentY, {
            width: pageWidth,
            align: "center",
        });

    // ──── TABLE ────
    currentY += 45;

    const tableX = leftMargin + 30;
    const tableWidth = pageWidth - 60;
    const labelColWidth = 160;
    const valueColWidth = tableWidth - labelColWidth;
    const rowHeight = 36;

    const rows = [
        { label: "Transaction ID", value: submission.paymentTxnId || "N/A" },
        { label: "Date & Time", value: formatDate(submission.paymentDate) },
        { label: "Full Name", value: userData.name || "N/A" },
        { label: "Email Address", value: userData.email || "N/A" },
        { label: "Category", value: formatRole(userData.role) },
        { label: "Participation Type", value: "Offline" },
        { label: "Amount Paid", value: `₹${submission.paymentAmount || "0"}`, isAmount: true },
    ];

    // Table header
    doc.rect(tableX, currentY, tableWidth, rowHeight).fill("#e8e8e8");

    doc.fontSize(11)
        .fillColor(TEXT_DARK)
        .font("Helvetica-Bold")
        .text("Field", tableX + 12, currentY + 11, { width: labelColWidth });

    doc.fontSize(11)
        .fillColor(TEXT_DARK)
        .font("Helvetica-Bold")
        .text("Details", tableX + labelColWidth, currentY + 11, { width: valueColWidth });

    currentY += rowHeight;

    // Table rows
    rows.forEach((row, index) => {
        // Alternating background
        const bgColor = index % 2 === 0 ? "#ffffff" : ROW_GRAY;
        doc.rect(tableX, currentY, tableWidth, rowHeight).fill(bgColor);

        // Label
        doc.fontSize(10)
            .fillColor(TEXT_DARK)
            .font("Helvetica-Bold")
            .text(row.label, tableX + 12, currentY + 11, { width: labelColWidth - 12 });

        // Value
        doc.fontSize(10)
            .fillColor(row.isAmount ? AMOUNT_GREEN : TEXT_DARK)
            .font(row.isAmount ? "Helvetica-Bold" : "Helvetica")
            .text(row.value, tableX + labelColWidth, currentY + 11, { width: valueColWidth - 12 });

        currentY += rowHeight;
    });

    // Table border
    const tableHeight = rowHeight * (rows.length + 1); // +1 for header
    doc.rect(tableX, currentY - tableHeight, tableWidth, tableHeight)
        .lineWidth(0.5)
        .strokeColor(BORDER_GRAY)
        .stroke();

    // Horizontal lines for each row
    for (let i = 0; i <= rows.length; i++) {
        const lineY = currentY - tableHeight + rowHeight * (i + 1);
        doc.moveTo(tableX, lineY)
            .lineTo(tableX + tableWidth, lineY)
            .lineWidth(0.3)
            .strokeColor(BORDER_GRAY)
            .stroke();
    }

    // Vertical divider between columns
    doc.moveTo(tableX + labelColWidth, currentY - tableHeight)
        .lineTo(tableX + labelColWidth, currentY)
        .lineWidth(0.3)
        .strokeColor(BORDER_GRAY)
        .stroke();

    // ──── FOOTER ────
    currentY += 40;

    doc.fontSize(9)
        .fillColor(TEXT_GRAY)
        .font("Helvetica-Oblique")
        .text(
            "This is a system-generated receipt and does not require a physical signature.",
            leftMargin,
            currentY,
            { width: pageWidth, align: "center" }
        );

    currentY += 18;

    doc.fontSize(8)
        .fillColor(TEXT_GRAY)
        .font("Helvetica")
        .text(
            `For queries, contact: ${SUPPORT_EMAIL}`,
            leftMargin,
            currentY,
            { width: pageWidth, align: "center" }
        );

    doc.end();
}

// ─────────── Formatters ───────────

function formatDate(isoString) {
    if (!isoString) return "N/A";
    try {
        const d = new Date(isoString);
        const day = d.toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata", day: "2-digit" });
        const month = d.toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata", month: "short" });
        const year = d.toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata", year: "numeric" });
        const time = d.toLocaleTimeString("en-IN", { timeZone: "Asia/Kolkata", hour: "2-digit", minute: "2-digit", hour12: true });
        return `${day} ${month} ${year}, ${time}`;
    } catch {
        return isoString;
    }
}

function formatRole(role) {
    if (!role) return "N/A";
    const r = role.toLowerCase().trim();
    if (r === "student") return "Student";
    if (r === "scholar") return "Scholar";
    return role;
}

/**
 * Generate a unique receipt number from txnid.
 * Format: EVT-2026-<txnid>
 */
function generateReceiptNumber(txnid) {
    return `EVT-2026-${txnid}`;
}

/**
 * Find the user's paid full paper submission.
 * Returns { submission, userData } or null.
 */
async function findPaidSubmission(uid) {
    const db = getDb();

    // 1. Fetch user profile
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) return null;
    const userData = userDoc.data();

    // 2. Find approved + paid full paper
    const submissionsSnap = await db
        .collection("submissions")
        .where("uid", "==", uid)
        .where("submissionType", "==", "fullpaper")
        .get();

    const paidDoc = submissionsSnap.docs.find((doc) => {
        const d = doc.data();
        const isApproved = d.status === "accepted" || d.status === "accepted_with_revision";
        return isApproved && d.paymentStatus === "paid";
    });

    if (!paidDoc) return null;

    return {
        submission: { id: paidDoc.id, ...paidDoc.data() },
        userData,
    };
}

/**
 * Ensure receiptNumber is stored in the submission doc.
 */
async function ensureReceiptNumber(docId, txnid) {
    const db = getDb();
    const docRef = db.collection("submissions").doc(docId);
    const doc = await docRef.get();
    const data = doc.data();

    if (data.receiptNumber) {
        return data.receiptNumber;
    }

    const receiptNumber = generateReceiptNumber(txnid);
    await docRef.update({
        receiptNumber,
        receiptGeneratedAt: new Date().toISOString(),
    });

    return receiptNumber;
}

// ─────────── Route Handlers ───────────

/**
 * GET /api/receipt/:uid
 * Serves the receipt PDF inline (for browser preview).
 */
async function viewReceipt(req, res) {
    try {
        const { uid } = req.params;

        if (!uid) {
            return res.status(400).json({ success: false, error: "User ID is required." });
        }

        const result = await findPaidSubmission(uid);

        if (!result) {
            return res.status(403).json({
                success: false,
                error: "No paid submission found. Receipt is only available after successful payment.",
            });
        }

        const { submission, userData } = result;

        // Ensure receipt number exists
        const receiptNumber = await ensureReceiptNumber(
            submission.id,
            submission.paymentTxnId
        );

        generateReceiptPDF(res, {
            userData,
            submission,
            receiptNumber,
            disposition: "inline",
        });
    } catch (error) {
        console.error("View receipt error:", error);
        return res.status(500).json({
            success: false,
            error: "Failed to generate receipt.",
        });
    }
}

/**
 * GET /api/receipt/download/:uid
 * Serves the receipt PDF as a downloadable attachment.
 */
async function downloadReceipt(req, res) {
    try {
        const { uid } = req.params;

        if (!uid) {
            return res.status(400).json({ success: false, error: "User ID is required." });
        }

        const result = await findPaidSubmission(uid);

        if (!result) {
            return res.status(403).json({
                success: false,
                error: "No paid submission found. Receipt is only available after successful payment.",
            });
        }

        const { submission, userData } = result;

        // Ensure receipt number exists
        const receiptNumber = await ensureReceiptNumber(
            submission.id,
            submission.paymentTxnId
        );

        generateReceiptPDF(res, {
            userData,
            submission,
            receiptNumber,
            disposition: "attachment",
        });
    } catch (error) {
        console.error("Download receipt error:", error);
        return res.status(500).json({
            success: false,
            error: "Failed to generate receipt.",
        });
    }
}

/**
 * GET /api/receipt/status/:uid
 * Returns receipt metadata (for Flutter to know if receipt is available).
 */
async function getReceiptStatus(req, res) {
    try {
        const { uid } = req.params;

        if (!uid) {
            return res.status(400).json({ success: false, error: "User ID is required." });
        }

        const result = await findPaidSubmission(uid);

        if (!result) {
            return res.status(200).json({
                success: true,
                receiptAvailable: false,
            });
        }

        const { submission } = result;

        return res.status(200).json({
            success: true,
            receiptAvailable: true,
            receiptNumber: submission.receiptNumber || generateReceiptNumber(submission.paymentTxnId),
            paymentDate: submission.paymentDate,
            paymentAmount: submission.paymentAmount,
        });
    } catch (error) {
        console.error("Receipt status error:", error);
        return res.status(500).json({
            success: false,
            error: "Failed to check receipt status.",
        });
    }
}

module.exports = {
    viewReceipt,
    downloadReceipt,
    getReceiptStatus,
};
