"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const zod_1 = require("zod");
const prisma_1 = require("../lib/prisma");
const auth_1 = require("../middleware/auth");
const validate_request_1 = require("../middleware/validate-request");
const router = (0, express_1.Router)();
const baseTipSchema = zod_1.z.object({
    title: zod_1.z.string().trim().min(3).max(200),
    expiresAt: zod_1.z.coerce.date(),
});
const tipCreateSchema = baseTipSchema;
const tipUpdateSchema = baseTipSchema.partial();
const tipQuerySchema = zod_1.z.object({
    limit: zod_1.z.coerce.number().int().min(1).max(20).default(1),
});
router.get("/", (0, validate_request_1.validateRequest)(tipQuerySchema, "query"), async (req, res, next) => {
    try {
        const parsed = req.query;
        const { limit } = parsed;
        const tips = await prisma_1.prisma.tip.findMany({
            where: { isActive: true },
            orderBy: [{ expiresAt: "asc" }],
            take: Number(limit),
            select: {
                id: true,
                title: true,
                expiresAt: true,
                createdAt: true,
                updatedAt: true,
            },
        });
        res.json(tips);
    }
    catch (err) {
        next(err);
    }
});
router.post("/", auth_1.authenticate, (0, validate_request_1.validateRequest)(tipCreateSchema), async (req, res, next) => {
    try {
        const data = req.body;
        const tip = await prisma_1.prisma.tip.create({
            data: {
                title: data.title,
                body: "",
                expiresAt: data.expiresAt,
                createdById: req.user?.id,
            },
            select: {
                id: true,
                title: true,
                expiresAt: true,
                createdAt: true,
                updatedAt: true,
            },
        });
        res.status(201).json(tip);
    }
    catch (err) {
        next(err);
    }
});
router.put("/:id", auth_1.authenticate, (0, validate_request_1.validateRequest)(zod_1.z.object({ id: zod_1.z.coerce.number().int().positive() }), "params"), (0, validate_request_1.validateRequest)(tipUpdateSchema), async (req, res, next) => {
    try {
        const params = req.params;
        const { id } = params;
        const data = req.body;
        const tip = await prisma_1.prisma.tip.update({
            where: { id },
            data: {
                title: data.title,
                expiresAt: data.expiresAt,
                body: "",
            },
            select: {
                id: true,
                title: true,
                expiresAt: true,
                createdAt: true,
                updatedAt: true,
            },
        });
        res.json(tip);
    }
    catch (err) {
        next(err);
    }
});
router.delete("/:id", auth_1.authenticate, (0, validate_request_1.validateRequest)(zod_1.z.object({ id: zod_1.z.coerce.number().int().positive() }), "params"), async (req, res, next) => {
    try {
        const params = req.params;
        const { id } = params;
        await prisma_1.prisma.tip.delete({ where: { id } });
        res.status(204).send();
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=tip.routes.js.map