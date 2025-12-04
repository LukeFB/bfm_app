"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const multer_1 = __importDefault(require("multer"));
const zod_1 = require("zod");
const prisma_1 = require("../lib/prisma");
const auth_1 = require("../middleware/auth");
const validate_request_1 = require("../middleware/validate-request");
const error_handler_1 = require("../middleware/error-handler");
const csv_1 = require("../utils/csv");
const router = (0, express_1.Router)();
const upload = (0, multer_1.default)({
    storage: multer_1.default.memoryStorage(),
    limits: { fileSize: 2 * 1024 * 1024 },
});
const optionalString = (max = 255) => zod_1.z
    .string()
    .trim()
    .max(max)
    .transform((val) => (val.length ? val : undefined))
    .optional();
const referralSchema = zod_1.z
    .object({
    organisationName: optionalString(200),
    category: optionalString(120),
    website: optionalString(300),
    phone: optionalString(60),
    services: optionalString(1000),
    demographics: optionalString(400),
    availability: optionalString(400),
    email: optionalString(200),
    address: optionalString(400),
    region: optionalString(120),
    notes: optionalString(1000),
    isActive: zod_1.z.boolean().optional(),
})
    .refine((data) => Object.values(data).some((val) => val !== undefined), "At least one field is required");
const referralQuerySchema = zod_1.z.object({
    search: zod_1.z.string().trim().optional(),
    category: zod_1.z.string().trim().optional(),
    region: zod_1.z.string().trim().optional(),
    limit: zod_1.z.coerce.number().int().min(1).max(100).default(25),
});
router.get("/", (0, validate_request_1.validateRequest)(referralQuerySchema, "query"), async (req, res, next) => {
    try {
        const parsed = req.query;
        const { search, category, region, limit } = parsed;
        const filters = { isActive: true };
        if (category) {
            filters.category = { contains: category };
        }
        if (region) {
            filters.region = { contains: region };
        }
        if (search) {
            filters.OR = [
                { organisationName: { contains: search } },
                { services: { contains: search } },
                { demographics: { contains: search } },
            ];
        }
        const referrals = await prisma_1.prisma.referral.findMany({
            where: filters,
            orderBy: { updatedAt: "desc" },
            take: Number(limit),
        });
        res.json(referrals);
    }
    catch (err) {
        next(err);
    }
});
router.post("/", auth_1.authenticate, (0, validate_request_1.validateRequest)(referralSchema), async (req, res, next) => {
    try {
        const data = req.body;
        const record = await prisma_1.prisma.referral.create({
            data: { ...data, createdById: req.user?.id },
        });
        res.status(201).json(record);
    }
    catch (err) {
        next(err);
    }
});
router.put("/:id", auth_1.authenticate, (0, validate_request_1.validateRequest)(zod_1.z.object({ id: zod_1.z.coerce.number().int().positive() }), "params"), (0, validate_request_1.validateRequest)(referralSchema), async (req, res, next) => {
    try {
        const params = req.params;
        const { id } = params;
        const data = req.body;
        const updated = await prisma_1.prisma.referral.update({
            where: { id },
            data,
        });
        res.json(updated);
    }
    catch (err) {
        next(err);
    }
});
router.delete("/:id", auth_1.authenticate, (0, validate_request_1.validateRequest)(zod_1.z.object({ id: zod_1.z.coerce.number().int().positive() }), "params"), async (req, res, next) => {
    try {
        const params = req.params;
        const { id } = params;
        await prisma_1.prisma.referral.delete({ where: { id } });
        res.status(204).send();
    }
    catch (err) {
        next(err);
    }
});
router.post("/import", auth_1.authenticate, upload.single("file"), async (req, res, next) => {
    try {
        if (!req.file) {
            throw new error_handler_1.AppError("CSV file is required", 400);
        }
        const rows = (0, csv_1.parseReferralCsv)(req.file.buffer);
        const filtered = rows.filter((row) => Object.values(row).some((val) => Boolean(val?.trim())));
        if (!filtered.length) {
            throw new error_handler_1.AppError("No rows detected in CSV", 400);
        }
        const created = await prisma_1.prisma.$transaction(filtered.map((row) => prisma_1.prisma.referral.create({
            data: {
                ...row,
                createdById: req.user?.id,
            },
        })));
        res.status(201).json({
            count: created.length,
        });
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=referral.routes.js.map