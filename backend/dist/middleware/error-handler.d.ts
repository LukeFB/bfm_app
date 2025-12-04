import type { NextFunction, Request, Response } from "express";
export declare class AppError extends Error {
    statusCode: number;
    details?: unknown;
    constructor(message: string, statusCode?: number, details?: unknown);
}
export declare const notFoundHandler: (req: Request, res: Response) => void;
export declare const errorHandler: (err: Error | AppError, _req: Request, res: Response, _next: NextFunction) => void;
//# sourceMappingURL=error-handler.d.ts.map