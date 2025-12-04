"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createApp = void 0;
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const morgan_1 = __importDefault(require("morgan"));
const path_1 = __importDefault(require("path"));
const fs_1 = __importDefault(require("fs"));
const routes_1 = __importDefault(require("./routes"));
const error_handler_1 = require("./middleware/error-handler");
const createApp = () => {
    const app = (0, express_1.default)();
    app.use((0, helmet_1.default)());
    app.use((0, cors_1.default)({
        origin: "*",
        methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    }));
    app.use(express_1.default.json({ limit: "1mb" }));
    app.use(express_1.default.urlencoded({ extended: true }));
    app.use((0, morgan_1.default)("combined", {
        skip: () => process.env.NODE_ENV === "test",
    }));
    app.get("/", (_req, res) => {
        res.json({ status: "bfm-backend", version: "1.0.0" });
    });
    app.use("/api", routes_1.default);
    const publicDir = path_1.default.join(process.cwd(), "public");
    if (fs_1.default.existsSync(publicDir)) {
        app.use("/admin", express_1.default.static(publicDir));
        app.get(/^\/admin(\/.*)?$/, (_req, res) => {
            res.sendFile(path_1.default.join(publicDir, "index.html"));
        });
    }
    app.use(error_handler_1.notFoundHandler);
    app.use(error_handler_1.errorHandler);
    return app;
};
exports.createApp = createApp;
//# sourceMappingURL=app.js.map