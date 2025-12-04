import type { NextFunction, Request, Response } from "express";
import type { ZodTypeAny } from "zod";
import { AppError } from "./error-handler";

export const validateRequest =
  (schema: ZodTypeAny, target: "body" | "query" | "params" = "body") =>
  (req: Request, _res: Response, next: NextFunction) => {
    const data =
      target === "body"
        ? req.body
        : target === "query"
          ? req.query
          : req.params;

    const result = schema.safeParse(data);
    if (!result.success) {
      const formatted = result.error.issues.map((issue) => ({
        path: issue.path.join("."),
        message: issue.message,
      }));
      return next(new AppError("Validation failed", 422, formatted));
    }

    if (target === "body") {
      req.body = result.data as typeof req.body;
    } else if (target === "query") {
      Object.assign(req.query, result.data);
    } else {
      Object.assign(req.params, result.data);
    }

    return next();
  };
