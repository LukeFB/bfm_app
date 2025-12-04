"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.prisma = void 0;
const client_1 = require("../generated/prisma/client");
const env_1 = require("../config/env");
const createPrismaClient = () => new client_1.PrismaClient({
    log: ["error", "warn"],
    datasourceUrl: env_1.env.databaseUrl,
});
exports.prisma = global.prisma ?? createPrismaClient();
if (process.env.NODE_ENV !== "production") {
    global.prisma = exports.prisma;
}
//# sourceMappingURL=prisma.js.map