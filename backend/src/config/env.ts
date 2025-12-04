import dotenv from "dotenv";

dotenv.config();

type EnvShape = {
  nodeEnv: string;
  port: number;
  jwtSecret: string;
  databaseUrl: string;
  adminEmail?: string;
  adminPassword?: string;
};

const required = (key: string): string => {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing required environment variable ${key}`);
  }
  return value;
};

export const env: EnvShape = {
  nodeEnv: process.env.NODE_ENV ?? "development",
  port: Number(process.env.PORT ?? 4000),
  jwtSecret: required("JWT_SECRET"),
  databaseUrl: required("DATABASE_URL"),
  adminEmail: process.env.ADMIN_EMAIL,
  adminPassword: process.env.ADMIN_PASSWORD,
};

