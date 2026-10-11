import { db } from "../db/client";

export interface MatchCandidate {
  id: number;
  ticker: string;
  normalizedName: string;
  compactName: string;
}

export type MatchConfidence = "exact" | "fuzzy" | "unmatched";

export interface MatchResult {
  companyId: number | null;
  ticker: string | null;
  confidence: MatchConfidence;
}

const SUFFIXES = [
  " SPOLKA AKCYJNA",
  " SPOLKA EUROPEJSKA",
  " S A",
  " SA",
  " W RESTRUKTURYZACJI W LIKWIDACJI",
  " W RESTRUKTURYZACJI",
  " W LIKWIDACJI",
];

export function normalizeName(raw: string): string {
  let s = raw
    .toUpperCase()
    .replace(/Ł/g, "L")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "") // strip diacritics left over after NFD (ó->o, ą->a, ć->c, ś->s, ź/ż->z, ń->n, ...)
    .replace(/[^A-Z0-9 ]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  for (const suffix of SUFFIXES) {
    if (s.endsWith(suffix)) {
      s = s.slice(0, -suffix.length).trim();
    }
  }
  return s;
}

function bigrams(s: string): Set<string> {
  const padded = ` ${s} `;
  const result = new Set<string>();
  for (let i = 0; i < padded.length - 1; i++) {
    result.add(padded.slice(i, i + 2));
  }
  return result;
}

function diceCoefficient(a: string, b: string): number {
  if (a === b) return 1;
  const bigramsA = bigrams(a);
  const bigramsB = bigrams(b);
  let intersection = 0;
  for (const bg of bigramsA) {
    if (bigramsB.has(bg)) intersection++;
  }
  return (2 * intersection) / (bigramsA.size + bigramsB.size);
}

const FUZZY_THRESHOLD = 0.82;

let cachedCandidates: MatchCandidate[] | null = null;

function loadCandidates(): MatchCandidate[] {
  if (!cachedCandidates) {
    const rows = db
      .prepare("SELECT id, ticker, name_full FROM companies WHERE is_active = 1")
      .all() as { id: number; ticker: string; name_full: string }[];
    cachedCandidates = rows.map((row) => {
      const normalizedName = normalizeName(row.name_full);
      return {
        id: row.id,
        ticker: row.ticker,
        normalizedName,
        compactName: normalizedName.replace(/ /g, ""),
      };
    });
  }
  return cachedCandidates;
}

export function invalidateMatcherCache(): void {
  cachedCandidates = null;
}

/**
 * ESPI/EBI titles on bankier.pl come as "NAZWA SPÓŁKI: tytuł komunikatu" —
 * the part before the first colon is the company name we match against.
 */
export function extractCompanyNameFromEspiTitle(title: string): string {
  const idx = title.indexOf(":");
  return idx === -1 ? title : title.slice(0, idx);
}

const MIN_COMPACT_CONTAINMENT_LENGTH = 4;

/**
 * Short-form sources (e.g. stockwatch.pl's earnings calendar) identify a
 * company by an abbreviated code rather than its full legal name — often
 * the ticker itself, or the legal name with spaces and suffixes stripped
 * (e.g. "BOGDANKA" for "Lubelski Węgiel Bogdanka", "PKNORLEN" for "Orlen").
 * We only accept a containment match when exactly one candidate qualifies,
 * to avoid false positives between similarly-prefixed companies.
 */
function matchByTickerOrContainment(rawName: string, candidates: MatchCandidate[]): MatchCandidate | null {
  const compactRaw = rawName.toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (!compactRaw) return null;

  const tickerHit = candidates.find((c) => c.ticker === compactRaw);
  if (tickerHit) return tickerHit;

  if (compactRaw.length < MIN_COMPACT_CONTAINMENT_LENGTH) return null;

  const contained = candidates.filter(
    (c) =>
      c.compactName.length >= MIN_COMPACT_CONTAINMENT_LENGTH &&
      (c.compactName.includes(compactRaw) || compactRaw.includes(c.compactName))
  );
  return contained.length === 1 ? contained[0] : null;
}

export function matchCompanyByName(rawName: string): MatchResult {
  const normalized = normalizeName(rawName);
  if (!normalized) return { companyId: null, ticker: null, confidence: "unmatched" };

  const candidates = loadCandidates();

  const exact = candidates.find((c) => c.normalizedName === normalized);
  if (exact) return { companyId: exact.id, ticker: exact.ticker, confidence: "exact" };

  const containment = matchByTickerOrContainment(rawName, candidates);
  if (containment) return { companyId: containment.id, ticker: containment.ticker, confidence: "fuzzy" };

  let best: { candidate: MatchCandidate; score: number } | null = null;
  for (const candidate of candidates) {
    const score = diceCoefficient(normalized, candidate.normalizedName);
    if (!best || score > best.score) best = { candidate, score };
  }

  if (best && best.score >= FUZZY_THRESHOLD) {
    return { companyId: best.candidate.id, ticker: best.candidate.ticker, confidence: "fuzzy" };
  }

  return { companyId: null, ticker: null, confidence: "unmatched" };
}
