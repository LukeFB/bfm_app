import type { Request, Response, NextFunction } from "express";
import jwt, { JwtPayload } from "jsonwebtoken";
import { env } from "../config/env";
import type { AuthenticatedUser } from "../types/auth";
import { StaffRole } from "../generated/prisma/client";

type TokenPayload = {
  sub: number;
  email: string;
  role: StaffRole;
};

export const signAccessToken = (user: AuthenticatedUser): string => {
  const payload: TokenPayload = {
    sub: user.id,
    email: user.email,
    role: user.role,
  };

  return jwt.sign(payload, env.jwtSecret, {
    expiresIn: "12h",
  });
};

export const authenticate = (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    return res.status(401).json({ message: "Authentication required" });
  }

  const token = header.substring("Bearer ".length);
  try {
    const decoded = jwt.verify(token, env.jwtSecret);
    if (typeof decoded === "string" || decoded === null) {
      throw new Error("Invalid token payload");
    }
    const payload = decoded as JwtPayload;
    if (
      typeof payload.sub !== "number" ||
      typeof payload.email !== "string" ||
      typeof payload.role !== "string"
    ) {
      throw new Error("Invalid token payload");
    }

    req.user = {
      id: payload.sub,
      email: payload.email,
      role: payload.role as StaffRole,
    };
    return next();
  } catch (err) {
    return res.status(401).json({ message: "Invalid or expired token" });
  }
};
