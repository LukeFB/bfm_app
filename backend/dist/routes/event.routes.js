"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const zod_1 = require("zod");
const prisma_1 = require("../lib/prisma");
const auth_1 = require("../middleware/auth");
const validate_request_1 = require("../middleware/validate-request");
const router = (0, express_1.Router)();
const baseEventSchema = zod_1.z.object({
    title: zod_1.z.string().trim().min(3).max(200),
    endDate: zod_1.z.coerce.date(),
});
const eventCreateSchema = baseEventSchema;
const eventUpdateSchema = baseEventSchema.partial();
const eventQuerySchema = zod_1.z.object({
    limit: zod_1.z.coerce.number().int().min(1).max(20).default(5),
    upcomingOnly: zod_1.z.coerce.boolean().default(true),
});
router.get("/", (0, validate_request_1.validateRequest)(eventQuerySchema, "query"), async (req, res, next) => {
    try {
        const parsed = req.query;
        const { limit, upcomingOnly } = parsed;
        const now = new Date();
        const where = {};
        if (upcomingOnly) {
            where.endDate = { gte: now };
        }
        const events = await prisma_1.prisma.event.findMany({
            where,
            orderBy: { endDate: "asc" },
            take: Number(limit),
            select: {
                id: true,
                title: true,
                endDate: true,
                updatedAt: true,
            },
        });
        res.json(events);
    }
    catch (err) {
        next(err);
    }
});
router.post("/", auth_1.authenticate, (0, validate_request_1.validateRequest)(eventCreateSchema), async (req, res, next) => {
    try {
        const data = req.body;
        const event = await prisma_1.prisma.event.create({
            data: {
                title: data.title,
                endDate: data.endDate,
                startDate: data.endDate,
                createdById: req.user?.id,
            },
            select: {
                id: true,
                title: true,
                endDate: true,
                updatedAt: true,
            },
        });
        res.status(201).json(event);
    }
    catch (err) {
        next(err);
    }
});
router.put("/:id", auth_1.authenticate, (0, validate_request_1.validateRequest)(zod_1.z.object({ id: zod_1.z.coerce.number().int().positive() }), "params"), (0, validate_request_1.validateRequest)(eventUpdateSchema), async (req, res, next) => {
    try {
        const params = req.params;
        const { id } = params;
        const data = req.body;
        const payload = {
            title: data.title,
            endDate: data.endDate,
        };
        if (data.endDate) {
            payload.startDate = data.endDate;
        }
        const event = await prisma_1.prisma.event.update({
            where: { id },
            data: payload,
            select: {
                id: true,
                title: true,
                endDate: true,
                updatedAt: true,
            },
        });
        res.json(event);
    }
    catch (err) {
        next(err);
    }
});
router.delete("/:id", auth_1.authenticate, (0, validate_request_1.validateRequest)(zod_1.z.object({ id: zod_1.z.coerce.number().int().positive() }), "params"), async (req, res, next) => {
    try {
        const params = req.params;
        const { id } = params;
        await prisma_1.prisma.event.delete({ where: { id } });
        res.status(204).send();
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=event.routes.js.map