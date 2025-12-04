import { Router } from "express";
import authRoutes from "./auth.routes";
import referralRoutes from "./referral.routes";
import tipRoutes from "./tip.routes";
import eventRoutes from "./event.routes";

const router = Router();

router.get("/healthz", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

router.use("/auth", authRoutes);
router.use("/referrals", referralRoutes);
router.use("/tips", tipRoutes);
router.use("/events", eventRoutes);

export default router;

