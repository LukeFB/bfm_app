import * as runtime from "@prisma/client/runtime/library";
import * as $Class from "./internal/class";
import * as Prisma from "./internal/prismaNamespace";
export * as $Enums from './enums';
export * from "./enums";
/**
 * ## Prisma Client
 *
 * Type-safe database client for TypeScript
 * @example
 * ```
 * const prisma = new PrismaClient()
 * // Fetch zero or more StaffUsers
 * const staffUsers = await prisma.staffUser.findMany()
 * ```
 *
 * Read more in our [docs](https://www.prisma.io/docs/reference/tools-and-interfaces/prisma-client).
 */
export declare const PrismaClient: $Class.PrismaClientConstructor;
export type PrismaClient<LogOpts extends Prisma.LogLevel = never, OmitOpts extends Prisma.PrismaClientOptions["omit"] = Prisma.PrismaClientOptions["omit"], ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = $Class.PrismaClient<LogOpts, OmitOpts, ExtArgs>;
export { Prisma };
/**
 * Model StaffUser
 *
 */
export type StaffUser = Prisma.StaffUserModel;
/**
 * Model Referral
 *
 */
export type Referral = Prisma.ReferralModel;
/**
 * Model Tip
 *
 */
export type Tip = Prisma.TipModel;
/**
 * Model Event
 *
 */
export type Event = Prisma.EventModel;
//# sourceMappingURL=client.d.ts.map