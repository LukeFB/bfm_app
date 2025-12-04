import { env } from "../config/env";
import { prisma } from "../lib/prisma";
import { hashPassword } from "../utils/password";
import { StaffRole } from "../generated/prisma/client";

const ensureEnv = (key: "adminEmail" | "adminPassword"): string => {
  const value = env[key];
  if (!value) {
    throw new Error(`Missing ${key} in environment for seeding`);
  }
  return value;
};

const main = async () => {
  const email = ensureEnv("adminEmail").toLowerCase();
  const password = ensureEnv("adminPassword");

  const passwordHash = await hashPassword(password);

  const user = await prisma.staffUser.upsert({
    where: { email },
    update: { passwordHash, role: StaffRole.ADMIN },
    create: {
      email,
      passwordHash,
      role: StaffRole.ADMIN,
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
    await prisma.$disconnect();
  });
