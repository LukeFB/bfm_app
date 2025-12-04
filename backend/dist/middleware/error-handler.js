"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.errorHandler = exports.notFoundHandler = exports.AppError = void 0;
class AppError extends Error {
    constructor(message, statusCode = 400, details) {
        super(message);
        this.statusCode = statusCode;
        this.details = details;
    }
}
exports.AppError = AppError;
const notFoundHandler = (req, res) => {
    res.status(404).json({
        message: `Route ${req.method} ${req.originalUrl} not found`,
    });
};
exports.notFoundHandler = notFoundHandler;
// eslint-disable-next-line @typescript-eslint/no-unused-vars
const errorHandler = (err, _req, res, _next) => {
    const status = err instanceof AppError ? err.statusCode : 500;
    const payload = {
        message: err.message || "Unexpected error",
    };
    if (err instanceof AppError && err.details) {
        payload.details = err.details;
    }
    if (status >= 500) {
        // eslint-disable-next-line no-console
        console.error(err);
    }
    res.status(status).json(payload);
};
exports.errorHandler = errorHandler;
//# sourceMappingURL=error-handler.js.map