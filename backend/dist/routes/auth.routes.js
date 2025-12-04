"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const zod_1 = require("zod");
const prisma_1 = require("../lib/prisma");
const validate_request_1 = require("../middleware/validate-request");
const password_1 = require("../utils/password");
const auth_1 = require("../middleware/auth");
const error_handler_1 = require("../middleware/error-handler");
const router = (0, express_1.Router)();
const loginSchema = zod_1.z.object({
    email: zod_1.z
        .string()
        .email()
        .transform((v) => v.toLowerCase()),
    password: zod_1.z.string().min(6),
});
router.post("/login", (0, validate_request_1.validateRequest)(loginSchema), async (req, res, next) => {
    try {
        const { email, password } = req.body;
        const user = await prisma_1.prisma.staffUser.findUnique({ where: { email } });
        if (!user) {
            throw new error_handler_1.AppError("Invalid credentials", 401);
        }
        const isMatch = await (0, password_1.verifyPassword)(password, user.passwordHash);
        if (!isMatch) {
            throw new error_handler_1.AppError("Invalid credentials", 401);
        }
        const token = (0, auth_1.signAccessToken)({
            id: user.id,
            email: user.email,
            role: user.role,
        });
        res.json({
            token,
            user: {
                id: user.id,
                email: user.email,
                role: user.role,
            },
        });
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=auth.routes.js.map