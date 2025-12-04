import type { Request, Response, NextFunction } from "express";
import type { AuthenticatedUser } from "../types/auth";
export declare const signAccessToken: (user: AuthenticatedUser) => string;
export declare const authenticate: (req: Request, res: Response, next: NextFunction) => void | Response<any, Record<string, any>>;
//# sourceMappingURL=auth.d.ts.map