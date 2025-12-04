"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.authenticate = exports.signAccessToken = void 0;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const env_1 = require("../config/env");
const signAccessToken = (user) => {
    const payload = {
        sub: user.id,
        email: user.email,
        role: user.role,
    };
    return jsonwebtoken_1.default.sign(payload, env_1.env.jwtSecret, {
        expiresIn: "12h",
    });
};
exports.signAccessToken = signAccessToken;
const authenticate = (req, res, next) => {
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
        return res.status(401).json({ message: "Authentication required" });
    }
    const token = header.substring("Bearer ".length);
    try {
        const decoded = jsonwebtoken_1.default.verify(token, env_1.env.jwtSecret);
        if (typeof decoded === "string" || decoded === null) {
            throw new Error("Invalid token payload");
        }
        const payload = decoded;
        if (typeof payload.sub !== "number" ||
            typeof payload.email !== "string" ||
            typeof payload.role !== "string") {
            throw new Error("Invalid token payload");
        }
        req.user = {
            id: payload.sub,
            email: payload.email,
            role: payload.role,
        };
        return next();
    }
    catch (err) {
        return res.status(401).json({ message: "Invalid or expired token" });
    }
};
exports.authenticate = authenticate;
//# sourceMappingURL=auth.js.map