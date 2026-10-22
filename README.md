# Telegram Feedback API (Render Web Service)

This server receives screenshot + caption from a Lua script and forwards them to a Telegram channel using the Telegram Bot API.

## Endpoint

- `GET /` — health/status response
- `POST /feedback` — accepts `application/x-www-form-urlencoded` fields:
  - `base64_image`: Base64 screenshot (optionally with a `data:image/...;base64,` prefix)
  - `caption`: caption text

## Deploy on Render

1. Upload these files to a GitHub repository.
2. In Render, select **New + → Web Service** and connect the repository.
3. Runtime: Node. Build command: `npm install`. Start command: `npm start`.
4. Add environment variables in Render:
   - `TELEGRAM_BOT_TOKEN` = token from BotFather (keep secret)
   - `TELEGRAM_CHAT_ID` = `@PublicChannelUsername` or the numeric ID for a private channel
5. Add the bot to the target channel as an administrator with permission to post messages.
6. Deploy. Open the service URL; `/` should report `status: online`.
7. In the Lua config, set the server URL to `https://YOUR-SERVICE.onrender.com/feedback`.

## Important

- This server expects `base64_image` and `caption` fields in URL-encoded form. If your Lua code sends JSON or uses different field names, adjust either the Lua request or this server.
- Do not put the bot token in the Lua file or commit it to GitHub.
- The caption is sent with Telegram `parse_mode=HTML`. Ensure the caption uses valid Telegram HTML; remove `parse_mode` in `server.js` if it is plain text or arbitrary markup.
- This is a starter implementation. Add authentication (for example, a shared secret header) before exposing a production endpoint, so strangers cannot spam your Telegram channel.
