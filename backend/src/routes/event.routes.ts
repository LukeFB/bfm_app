import { Router } from "express";
import { z } from "zod";
import { prisma } from "../lib/prisma";
import { authenticate } from "../middleware/auth";
import { validateRequest } from "../middleware/validate-request";
import { Prisma } from "../generated/prisma/client";

const router = Router();

const baseEventSchema = z.object({
  title: z.string().trim().min(3).max(200),
  endDate: z.coerce.date(),
});

const eventCreateSchema = baseEventSchema;
const eventUpdateSchema = baseEventSchema.partial();

const eventQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(20).default(5),
  upcomingOnly: z.coerce.boolean().default(true),
});

router.get(
  "/",
  validateRequest(eventQuerySchema, "query"),
  async (req, res, next) => {
    try {
      const parsed = req.query as unknown as z.infer<typeof eventQuerySchema>;
      const { limit, upcomingOnly } = parsed;
      const now = new Date();

      const where: Prisma.EventWhereInput = {};
      if (upcomingOnly) {
        where.endDate = { gte: now };
      }
      const events = await prisma.event.findMany({
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
    } catch (err) {
      next(err);
    }
  },
);

router.post(
  "/",
  authenticate,
  validateRequest(eventCreateSchema),
  async (req, res, next) => {
    try {
      const data = req.body as z.infer<typeof eventCreateSchema>;
      const event = await prisma.event.create({
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
  validateRequest(eventUpdateSchema),
  async (req, res, next) => {
    try {
      const params = req.params as unknown as { id: number };
      const { id } = params;
      const data = req.body as z.infer<typeof eventUpdateSchema>;
      const payload: Prisma.EventUpdateInput = {
        title: data.title,
        endDate: data.endDate,
      };
      if (data.endDate) {
        payload.startDate = data.endDate;
      }
      const event = await prisma.event.update({
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
      await prisma.event.delete({ where: { id } });
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  },
);

export default router;
