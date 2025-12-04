import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import path from "path";
import fs from "fs";
import routes from "./routes";
import { errorHandler, notFoundHandler } from "./middleware/error-handler";

export const createApp = () => {
  const app = express();

  app.use(helmet());
  app.use(
    cors({
      origin: "*",
      methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    }),
  );
  app.use(express.json({ limit: "1mb" }));
  app.use(express.urlencoded({ extended: true }));
  app.use(
    morgan("combined", {
      skip: () => process.env.NODE_ENV === "test",
    }),
  );

  app.get("/", (_req, res) => {
    res.json({ status: "bfm-backend", version: "1.0.0" });
  });

  app.use("/api", routes);

  const publicDir = path.join(process.cwd(), "public");
  if (fs.existsSync(publicDir)) {
    app.use("/admin", express.static(publicDir));
    app.get(/^\/admin(\/.*)?$/, (_req, res) => {
      res.sendFile(path.join(publicDir, "index.html"));
    });
  }

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
};

