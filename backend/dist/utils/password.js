"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyPassword = exports.hashPassword = void 0;
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const SALT_ROUNDS = 12;
const hashPassword = async (plain) => {
    return bcryptjs_1.default.hash(plain, SALT_ROUNDS);
};
exports.hashPassword = hashPassword;
const verifyPassword = async (plain, hash) => {
    return bcryptjs_1.default.compare(plain, hash);
};
exports.verifyPassword = verifyPassword;
//# sourceMappingURL=password.js.map