import express from "express";
import multer from "multer";

const app = express();
const PORT = process.env.PORT || 3000;

// Parse form-urlencoded requests, including large Base64 screenshots.
// Render's request limits and memory usage still apply, so keep screenshots reasonably sized.
app.use(express.urlencoded({ extended: false, limit: "15mb" }));
app.use(express.json({ limit: "15mb" }));

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }
});

app.get("/", (_req, res) => {
  res.json({
    ok: true,
    service: "Telegram Feedback API",
    status: "online",
    endpoint: "POST /feedback"
  });
});

app.post("/feedback", async (req, res) => {
  try {
    // This endpoint expects application/x-www-form-urlencoded fields:
    // base64_image and caption, matching the Lua script discussed.
    const base64Image = req.body?.base64_image;
    const caption = req.body?.caption;

    if (typeof base64Image !== "string" || typeof caption !== "string" || !base64Image.trim()) {
      return res.status(400).json({
        ok: false,
        error: "Missing base64_image or caption"
      });
    }

    if (!process.env.TELEGRAM_BOT_TOKEN || !process.env.TELEGRAM_CHAT_ID) {
      return res.status(500).json({
        ok: false,
        error: "Server configuration missing"
      });
    }

    const cleaned = base64Image
      .replace(/\s/g, "")
      .replace(/^data:image\/[a-zA-Z0-9.+-]+;base64,/, "");

    if (!/^[A-Za-z0-9+/]*={0,2}$/.test(cleaned)) {
      return res.status(400).json({ ok: false, error: "Invalid Base64 image" });
    }

    let bytes;
    try {
      bytes = Buffer.from(cleaned, "base64");
    } catch {
      return res.status(400).json({ ok: false, error: "Could not decode image" });
    }

    if (!bytes.length) {
      return res.status(400).json({ ok: false, error: "Image is empty" });
    }

    // Telegram sendPhoto accepts photos up to 10 MB.
    if (bytes.length > 10 * 1024 * 1024) {
      return res.status(413).json({ ok: false, error: "Image exceeds Telegram photo size limit" });
    }

    const form = new FormData();
    form.append("chat_id", process.env.TELEGRAM_CHAT_ID);
    form.append("photo", new Blob([bytes], { type: "image/jpeg" }), "feedback.jpg");
    form.append("caption", caption);
    // Remove this line if the caption is plain text or has unsupported HTML.
    form.append("parse_mode", "HTML");

    const telegramResponse = await fetch(
      `https://api.telegram.org/bot${process.env.TELEGRAM_BOT_TOKEN}/sendPhoto`,
      { method: "POST", body: form }
    );

    const telegramResult = await telegramResponse.json();

    if (!telegramResponse.ok || telegramResult.ok !== true) {
      console.error("Telegram sendPhoto failed:", {
        status: telegramResponse.status,
        error_code: telegramResult.error_code,
        description: telegramResult.description
      });

      return res.status(502).json({
        ok: false,
        error: "Telegram rejected the feedback",
        telegram_status: telegramResponse.status,
        description: telegramResult.description || "Unknown Telegram error"
      });
    }

    return res.json({
      ok: true,
      status: true,
      message: "Feedback delivered to Telegram",
      message_id: telegramResult.result?.message_id
    });
  } catch (error) {
    console.error("Feedback processing error:", error);
    return res.status(500).json({ ok: false, error: "Internal server error" });
  }
});

app.listen(PORT, () => {
  console.log(`Telegram Feedback API listening on port ${PORT}`);
});
