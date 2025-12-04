import { Router } from "express";
import { z } from "zod";
import { prisma } from "../lib/prisma";
import { authenticate } from "../middleware/auth";
import { validateRequest } from "../middleware/validate-request";
import { Prisma } from "../generated/prisma/client";

const router = Router();

const baseTipSchema = z.object({
  title: z.string().trim().min(3).max(200),
  expiresAt: z.coerce.date(),
});

const tipCreateSchema = baseTipSchema;
const tipUpdateSchema = baseTipSchema.partial();

const tipQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(20).default(1),
});

router.get(
  "/",
  validateRequest(tipQuerySchema, "query"),
  async (req, res, next) => {
    try {
      const parsed = req.query as unknown as z.infer<typeof tipQuerySchema>;
      const { limit } = parsed;

      const tips = await prisma.tip.findMany({
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
    } catch (err) {
      next(err);
    }
  },
);

router.post(
  "/",
  authenticate,
  validateRequest(tipCreateSchema),
  async (req, res, next) => {
    try {
      const data = req.body as z.infer<typeof tipCreateSchema>;
      const tip = await prisma.tip.create({
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
  validateRequest(tipUpdateSchema),
  async (req, res, next) => {
    try {
      const params = req.params as unknown as { id: number };
      const { id } = params;
      const data = req.body as z.infer<typeof tipUpdateSchema>;
      const tip = await prisma.tip.update({
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
      await prisma.tip.delete({ where: { id } });
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  },
);

export default router;
