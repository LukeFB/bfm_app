"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_routes_1 = __importDefault(require("./auth.routes"));
const referral_routes_1 = __importDefault(require("./referral.routes"));
const tip_routes_1 = __importDefault(require("./tip.routes"));
const event_routes_1 = __importDefault(require("./event.routes"));
const router = (0, express_1.Router)();
router.get("/healthz", (_req, res) => {
    res.json({ status: "ok", timestamp: new Date().toISOString() });
});
router.use("/auth", auth_routes_1.default);
router.use("/referrals", referral_routes_1.default);
router.use("/tips", tip_routes_1.default);
router.use("/events", event_routes_1.default);
exports.default = router;
//# sourceMappingURL=index.js.map