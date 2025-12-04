"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseReferralCsv = void 0;
const sync_1 = require("csv-parse/sync");
const fieldMap = {
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
const normaliseHeader = (header) => {
    const key = header.trim().toLowerCase();
    return fieldMap[key];
};
const parseReferralCsv = (input) => {
    const raw = (0, sync_1.parse)(input, {
        columns: true,
        skip_empty_lines: true,
        bom: true,
        trim: true,
    });
    return raw.map((row) => {
        const parsed = {};
        for (const [key, value] of Object.entries(row)) {
            const mapped = normaliseHeader(key);
            if (!mapped)
                continue;
            const val = value?.toString().trim();
            if (val) {
                parsed[mapped] = val;
            }
        }
        return parsed;
    });
};
exports.parseReferralCsv = parseReferralCsv;
//# sourceMappingURL=csv.js.map