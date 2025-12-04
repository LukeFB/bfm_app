"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateRequest = void 0;
const error_handler_1 = require("./error-handler");
const validateRequest = (schema, target = "body") => (req, _res, next) => {
    const data = target === "body"
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
        return next(new error_handler_1.AppError("Validation failed", 422, formatted));
    }
    if (target === "body") {
        req.body = result.data;
    }
    else if (target === "query") {
        Object.assign(req.query, result.data);
    }
    else {
        Object.assign(req.params, result.data);
    }
    return next();
};
exports.validateRequest = validateRequest;
//# sourceMappingURL=validate-request.js.map