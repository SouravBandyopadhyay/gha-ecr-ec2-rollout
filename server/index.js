import express from "express";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const port = Number(process.env.PORT || 3000);
const publicDir = path.join(__dirname, "public");

app.get("/api/health", (_req, res) => {
  res.json({
    status: "ok",
    version: process.env.APP_VERSION || "1.0.0",
    gitSha: process.env.GIT_SHA || "local",
    time: new Date().toISOString(),
  });
});

app.use(express.static(publicDir));

app.get("*", (_req, res) => {
  res.sendFile(path.join(publicDir, "index.html"));
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Server listening on ${port}`);
});
