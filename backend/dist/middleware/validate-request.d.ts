import type { NextFunction, Request, Response } from "express";
import type { ZodTypeAny } from "zod";
export declare const validateRequest: (schema: ZodTypeAny, target?: "body" | "query" | "params") => (req: Request, _res: Response, next: NextFunction) => void;
//# sourceMappingURL=validate-request.d.ts.map