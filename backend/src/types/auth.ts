import { StaffRole } from "../generated/prisma/client";

export type AuthenticatedUser = {
  id: number;
  email: string;
  role: StaffRole;
};
