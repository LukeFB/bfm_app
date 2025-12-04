"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const env_1 = require("../config/env");
const prisma_1 = require("../lib/prisma");
const password_1 = require("../utils/password");
const client_1 = require("../generated/prisma/client");
const ensureEnv = (key) => {
    const value = env_1.env[key];
    if (!value) {
        throw new Error(`Missing ${key} in environment for seeding`);
    }
    return value;
};
const main = async () => {
    const email = ensureEnv("adminEmail").toLowerCase();
    const password = ensureEnv("adminPassword");
    const passwordHash = await (0, password_1.hashPassword)(password);
    const user = await prisma_1.prisma.staffUser.upsert({
        where: { email },
        update: { passwordHash, role: client_1.StaffRole.ADMIN },
        create: {
            email,
            passwordHash,
            role: client_1.StaffRole.ADMIN,
        },
    });
    // eslint-disable-next-line no-console
    console.log(`Seeded admin user ${user.email}`);
};
main()
    .catch((err) => {
    // eslint-disable-next-line no-console
    console.error("Failed to seed admin user", err);
    process.exit(1);
})
    .finally(async () => {
    await prisma_1.prisma.$disconnect();
});
//# sourceMappingURL=seed-admin.js.map