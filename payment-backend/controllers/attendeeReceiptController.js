/**
 * Attendee Receipt Controller
 * ----------------------------
 * Handles receipt generation and serving for paid attendees.
 *
 * IMPORTANT: This is separate from paper submission receipts.
 * Attendee receipts are looked up by txnid (not uid), since attendees
 * may not be registered users.
 *
 * Routes:
 *   GET /api/attendee-receipt/:txnid          → View receipt PDF inline
 *   GET /api/attendee-receipt/download/:txnid  → Download receipt PDF
 */

const PDFDocument = require("pdfkit");
const { getDb } = require("../utils/firebase");

// ─────────── Constants ───────────

const EVENT_NAME = "UCC ICON 2026";
const SUPPORT_EMAIL = "tcs2026@uccollege.edu.in";

// ─────────── PDF Generation ───────────

/**
 * Build a clean attendee receipt PDF.
 * Green checkmark → "Payment Successful" → simple table → footer.
 */
function generateAttendeeReceiptPDF(
    res,
    { attendeeData, receiptNumber, disposition }
) {
    const doc = new PDFDocument({
        size: "A4",
        margin: 60,
        info: {
            Title: `Attendee Receipt - ${receiptNumber}`,
            Author: EVENT_NAME,
            Subject: "Attendee Registration Receipt",
        },
    });

    // Set response headers
    const filename = `Attendee_Receipt_${receiptNumber}.pdf`;
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
    doc.strokeColor("#ffffff").lineWidth(4).lineCap("round").lineJoin("round");
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
        .text(
            `Thank you for registering as an attendee for ${EVENT_NAME}!`,
            leftMargin,
            currentY,
            { width: pageWidth, align: "center" }
        );

    // ──── TABLE ────
    currentY += 45;

    const tableX = leftMargin + 30;
    const tableWidth = pageWidth - 60;
    const labelColWidth = 160;
    const valueColWidth = tableWidth - labelColWidth;
    const rowHeight = 36;

    const rows = [
        { label: "Receipt Number", value: receiptNumber },
        {
            label: "Transaction ID",
            value: attendeeData.txnid || "N/A",
        },
        { label: "Date & Time", value: formatDate(attendeeData.paymentDate) },
        { label: "Full Name", value: attendeeData.name || "N/A" },
        { label: "Email Address", value: attendeeData.email || "N/A" },
        {
            label: "Organization",
            value: attendeeData.organization || "N/A",
        },
        { label: "Registration Type", value: "Attendee" },
        {
            label: "Amount Paid",
            value: `Rs. ${attendeeData.amount || "100"}`,
            isAmount: true,
        },
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
        .text("Details", tableX + labelColWidth, currentY + 11, {
            width: valueColWidth,
        });

    currentY += rowHeight;

    // Table rows
    rows.forEach((row, index) => {
        const bgColor = index % 2 === 0 ? "#ffffff" : ROW_GRAY;
        doc.rect(tableX, currentY, tableWidth, rowHeight).fill(bgColor);

        // Label
        doc.fontSize(10)
            .fillColor(TEXT_DARK)
            .font("Helvetica-Bold")
            .text(row.label, tableX + 12, currentY + 11, {
                width: labelColWidth - 12,
            });

        // Value
        doc.fontSize(10)
            .fillColor(row.isAmount ? AMOUNT_GREEN : TEXT_DARK)
            .font(row.isAmount ? "Helvetica-Bold" : "Helvetica")
            .text(row.value, tableX + labelColWidth, currentY + 11, {
                width: valueColWidth - 12,
            });

        currentY += rowHeight;
    });

    // Table border
    const tableHeight = rowHeight * (rows.length + 1);
    doc.rect(tableX, currentY - tableHeight, tableWidth, tableHeight)
        .lineWidth(0.5)
        .strokeColor(BORDER_GRAY)
        .stroke();

    // Horizontal lines
    for (let i = 0; i <= rows.length; i++) {
        const lineY = currentY - tableHeight + rowHeight * (i + 1);
        doc.moveTo(tableX, lineY)
            .lineTo(tableX + tableWidth, lineY)
            .lineWidth(0.3)
            .strokeColor(BORDER_GRAY)
            .stroke();
    }

    // Vertical divider
    doc.moveTo(tableX + labelColWidth, currentY - tableHeight)
        .lineTo(tableX + labelColWidth, currentY)
        .lineWidth(0.3)
        .strokeColor(BORDER_GRAY)
        .stroke();

    // ──── NOTE ────
    currentY += 30;

    doc.fontSize(11)
        .fillColor(TEXT_DARK)
        .font("Helvetica-Bold")
        .text("Note: ", leftMargin, currentY, {
            width: pageWidth,
            continued: true,
        });

    doc.fontSize(11)
        .fillColor(TEXT_GRAY)
        .font("Helvetica")
        .text("Attendee Registration Fee", { continued: false });

    // ──── FOOTER ────
    currentY += 35;

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
        const day = d.toLocaleDateString("en-IN", {
            timeZone: "Asia/Kolkata",
            day: "2-digit",
        });
        const month = d.toLocaleDateString("en-IN", {
            timeZone: "Asia/Kolkata",
            month: "short",
        });
        const year = d.toLocaleDateString("en-IN", {
            timeZone: "Asia/Kolkata",
            year: "numeric",
        });
        const time = d.toLocaleTimeString("en-IN", {
            timeZone: "Asia/Kolkata",
            hour: "2-digit",
            minute: "2-digit",
            hour12: true,
        });
        return `${day} ${month} ${year}, ${time}`;
    } catch {
        return isoString;
    }
}

/**
 * Find paid attendee by txnid.
 */
async function findPaidAttendee(txnid) {
    const db = getDb();
    const snap = await db
        .collection("attendees")
        .where("txnid", "==", txnid)
        .where("paymentStatus", "==", "paid")
        .limit(1)
        .get();

    if (snap.empty) return null;
    return { id: snap.docs[0].id, ...snap.docs[0].data() };
}

// ─────────── Route Handlers ───────────

/**
 * GET /api/attendee-receipt/:txnid
 * Serves the attendee receipt PDF inline (for browser preview).
 */
async function viewAttendeeReceipt(req, res) {
    try {
        const { txnid } = req.params;

        if (!txnid) {
            return res
                .status(400)
                .json({ success: false, error: "Transaction ID is required." });
        }

        const attendeeData = await findPaidAttendee(txnid);

        if (!attendeeData) {
            return res.status(403).json({
                success: false,
                error: "No paid attendee registration found for this transaction.",
            });
        }

        const receiptNumber =
            attendeeData.receiptNumber || `EVT-ATT-2026-${txnid.slice(-4)}`;

        generateAttendeeReceiptPDF(res, {
            attendeeData,
            receiptNumber,
            disposition: "inline",
        });
    } catch (error) {
        console.error("[ATTENDEE RECEIPT] View error:", error);
        return res.status(500).json({
            success: false,
            error: "Failed to generate attendee receipt.",
        });
    }
}

/**
 * GET /api/attendee-receipt/download/:txnid
 * Serves the attendee receipt PDF as a downloadable attachment.
 */
async function downloadAttendeeReceipt(req, res) {
    try {
        const { txnid } = req.params;

        if (!txnid) {
            return res
                .status(400)
                .json({ success: false, error: "Transaction ID is required." });
        }

        const attendeeData = await findPaidAttendee(txnid);

        if (!attendeeData) {
            return res.status(403).json({
                success: false,
                error: "No paid attendee registration found for this transaction.",
            });
        }

        const receiptNumber =
            attendeeData.receiptNumber || `EVT-ATT-2026-${txnid.slice(-4)}`;

        generateAttendeeReceiptPDF(res, {
            attendeeData,
            receiptNumber,
            disposition: "attachment",
        });
    } catch (error) {
        console.error("[ATTENDEE RECEIPT] Download error:", error);
        return res.status(500).json({
            success: false,
            error: "Failed to generate attendee receipt.",
        });
    }
}

module.exports = {
    viewAttendeeReceipt,
    downloadAttendeeReceipt,
};
