import { parse } from "csv-parse/sync";

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

const fieldMap: Record<string, keyof ReferralCsvRow> = {
  "organisation name": "organisationName",
  organisation: "organisationName",
  name: "organisationName",
  category: "category",
  website: "website",
  phone: "phone",
  services: "services",
  service: "services",
  demographics: "demographics",
  audience: "demographics",
  availability: "availability",
  email: "email",
  mail: "email",
  address: "address",
  region: "region",
  area: "region",
};

const normaliseHeader = (header: string): keyof ReferralCsvRow | undefined => {
  const key = header.trim().toLowerCase();
  return fieldMap[key];
};

export const parseReferralCsv = (input: Buffer | string): ReferralCsvRow[] => {
  const raw = parse(input, {
    columns: true,
    skip_empty_lines: true,
    bom: true,
    trim: true,
  }) as Record<string, string>[];

  return raw.map((row) => {
    const parsed: ReferralCsvRow = {};
    for (const [key, value] of Object.entries(row)) {
      const mapped = normaliseHeader(key);
      if (!mapped) continue;
      const val = value?.toString().trim();
      if (val) {
        parsed[mapped] = val;
      }
    }
    return parsed;
  });
};

