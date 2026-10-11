import fs from "node:fs";
import path from "node:path";
import { db } from "../db/client";

interface SeedCompany {
  isin: string;
  name: string;
  ticker: string;
}

const seedPath = path.join(__dirname, "..", "..", "data", "companies_seed.json");
const seed: { companies: SeedCompany[] } = JSON.parse(fs.readFileSync(seedPath, "utf-8"));

const upsert = db.prepare(`
  INSERT INTO companies (ticker, isin, name_full)
  VALUES (@ticker, @isin, @name)
  ON CONFLICT(ticker) DO UPDATE SET
    isin = excluded.isin,
    name_full = excluded.name_full,
    is_active = 1,
    updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
`);

db.exec("BEGIN TRANSACTION");
for (const company of seed.companies) {
  upsert.run({ ticker: company.ticker, isin: company.isin, name: company.name });
}
db.exec("COMMIT");

console.log(`Zaimportowano/zaktualizowano ${seed.companies.length} spółek.`);
