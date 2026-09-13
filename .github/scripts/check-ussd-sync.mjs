#!/usr/bin/env node
/**
 * USSD sync check — CubaCell Connect.
 *
 * MyUSSDCodes-collection is the single source of truth for USSD codes across
 * all of albertolicea00's apps. This script compares the dial strings this repo
 * ships against the canonical `cuba-cubacel` collection and fails on any drift,
 * so a code changed in one place can't silently rot the others.
 *
 * Zero dependencies. Node 18+ (uses global fetch). Exit 0 = in sync, 1 = drift.
 *
 * Local testing: set CANONICAL_FILE to a local copy of the collection file, e.g.
 *   CANONICAL_FILE=../my-ussd-codes/my-ussd-codes-collection/codes/cuba-cubacel.json \
 *     node .github/scripts/check-ussd-sync.mjs
 */

import fs from "node:fs";

const CANONICAL_ID = "cuba-cubacel";
const CANONICAL_URL = `https://raw.githubusercontent.com/albertolicea00/MyUSSDCodes-collection/main/codes/${CANONICAL_ID}.json`;
const LOCAL_FILE = "CubaCellConnect/codes.json";

/** Repo-specific: pull every dial string out of this repo's own catalog. */
function extractLocal(json) {
  return (json.codes ?? []).map((c) => c.code);
}

const lines = [];
const say = (s = "") => lines.push(s);

async function loadCanonical() {
  if (process.env.CANONICAL_FILE) {
    return JSON.parse(fs.readFileSync(process.env.CANONICAL_FILE, "utf8"));
  }
  const res = await fetch(CANONICAL_URL, { headers: { "user-agent": "ussd-sync-check" } });
  if (!res.ok) {
    throw new Error(`canonical not reachable: HTTP ${res.status} for ${CANONICAL_URL}`);
  }
  return res.json();
}

function report(missing, extra) {
  say(`## USSD sync check — \`${CANONICAL_ID}\``);
  say();
  say(`Source of truth: [MyUSSDCodes-collection \`codes/${CANONICAL_ID}.json\`](${CANONICAL_URL})`);
  say(`Local catalog: \`${LOCAL_FILE}\``);
  say();
  if (missing.length) {
    say(`### ${missing.length} code(s) in the collection but missing here (app is behind)`);
    say("```");
    missing.forEach((c) => say(`+ ${c}`));
    say("```");
    say();
  }
  if (extra.length) {
    say(`### ${extra.length} code(s) here but not in the collection (add them upstream or remove)`);
    say("```");
    extra.forEach((c) => say(`- ${c}`));
    say("```");
    say();
  }
  say(`Reconcile by editing the source of truth in MyUSSDCodes-collection, then syncing \`${LOCAL_FILE}\` to match.`);
}

async function main() {
  let canonical;
  try {
    canonical = await loadCanonical();
  } catch (err) {
    say(`## USSD sync check failed to run`);
    say();
    say(String(err.message));
    finish(true);
    return;
  }

  const local = new Set(extractLocal(JSON.parse(fs.readFileSync(LOCAL_FILE, "utf8"))));
  const canon = new Set((canonical.codes ?? []).map((c) => c.code));

  const missing = [...canon].filter((c) => !local.has(c)).sort();
  const extra = [...local].filter((c) => !canon.has(c)).sort();
  const drift = missing.length > 0 || extra.length > 0;

  if (drift) report(missing, extra);
  else {
    say(`In sync: ${canon.size} unique dial string(s) match MyUSSDCodes-collection \`${CANONICAL_ID}\`.`);
  }
  finish(drift);
}

function finish(drift) {
  const out = lines.join("\n") + "\n";
  process.stdout.write(out);
  if (process.env.REPORT_FILE) fs.writeFileSync(process.env.REPORT_FILE, out);
  process.exit(drift ? 1 : 0);
}

main();
