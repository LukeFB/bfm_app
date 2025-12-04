import { Router } from "express";
import multer from "multer";
import { z } from "zod";
import { prisma } from "../lib/prisma";
import { authenticate } from "../middleware/auth";
import { validateRequest } from "../middleware/validate-request";
import { AppError } from "../middleware/error-handler";
import { parseReferralCsv } from "../utils/csv";
import { Prisma } from "../generated/prisma/client";

const router = Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 2 * 1024 * 1024 },
});

const optionalString = (max = 255) =>
  z
    .string()
    .trim()
    .max(max)
    .transform((val) => (val.length ? val : undefined))
    .optional();

const referralSchema = z
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
    isActive: z.boolean().optional(),
  })
  .refine(
    (data) => Object.values(data).some((val) => val !== undefined),
    "At least one field is required",
  );

const referralQuerySchema = z.object({
  search: z.string().trim().optional(),
  category: z.string().trim().optional(),
  region: z.string().trim().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(25),
});

router.get(
  "/",
  validateRequest(referralQuerySchema, "query"),
  async (req, res, next) => {
    try {
      const parsed = req.query as unknown as z.infer<typeof referralQuerySchema>;
      const { search, category, region, limit } = parsed;

      const filters: Prisma.ReferralWhereInput = { isActive: true };
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

      const referrals = await prisma.referral.findMany({
        where: filters,
        orderBy: { updatedAt: "desc" },
        take: Number(limit),
      });
      res.json(referrals);
    } catch (err) {
      next(err);
    }
  },
);

router.post(
  "/",
  authenticate,
  validateRequest(referralSchema),
  async (req, res, next) => {
    try {
      const data = req.body as z.infer<typeof referralSchema>;
      const record = await prisma.referral.create({
        data: { ...data, createdById: req.user?.id },
      });
      res.status(201).json(record);
    } catch (err) {
      next(err);
    }
  },
);

router.put(
  "/:id",
  authenticate,
  validateRequest(
    z.object({ id: z.coerce.number().int().positive() }),
    "params",
  ),
  validateRequest(referralSchema),
  async (req, res, next) => {
    try {
      const params = req.params as unknown as { id: number };
      const { id } = params;
      const data = req.body as z.infer<typeof referralSchema>;
      const updated = await prisma.referral.update({
        where: { id },
        data,
      });
      res.json(updated);
    } catch (err) {
      next(err);
    }
  },
);

router.delete(
  "/:id",
  authenticate,
  validateRequest(
    z.object({ id: z.coerce.number().int().positive() }),
    "params",
  ),
  async (req, res, next) => {
    try {
      const params = req.params as unknown as { id: number };
      const { id } = params;
      await prisma.referral.delete({ where: { id } });
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  },
);

router.post(
  "/import",
  authenticate,
  upload.single("file"),
  async (req, res, next) => {
    try {
      if (!req.file) {
        throw new AppError("CSV file is required", 400);
      }
      const rows = parseReferralCsv(req.file.buffer);
      const filtered = rows.filter((row) =>
        Object.values(row).some((val) => Boolean(val?.trim())),
      );

      if (!filtered.length) {
        throw new AppError("No rows detected in CSV", 400);
      }

      const created = await prisma.$transaction(
        filtered.map((row) =>
          prisma.referral.create({
            data: {
              ...row,
              createdById: req.user?.id,
            },
          }),
        ),
      );

      res.status(201).json({
        count: created.length,
      });
    } catch (err) {
      next(err);
    }
  },
);

export default router;
