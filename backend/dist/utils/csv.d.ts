export type ReferralCsvRow = {
    organisationName?: string;
    category?: string;
    website?: string;
    phone?: string;
    services?: string;
    demographics?: string;
    availability?: string;
    email?: string;
    address?: string;
    region?: string;
};
export declare const parseReferralCsv: (input: Buffer | string) => ReferralCsvRow[];
//# sourceMappingURL=csv.d.ts.map