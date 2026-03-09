/**
 * CRE Spellcheck — Tiny Utility
 * Fast, non-interactive check for market questions.
 */

import { validateText, getDefaultBundledSettingsAsync, mergeSettings, loadConfig } from "cspell-lib";
import { existsSync } from "fs";
import path from "path";
import { fileURLToPath } from "url";
import color from "picocolors";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CSPELL_CONFIG = path.resolve(__dirname, "cspell.json");

async function main() {
    const input = process.argv[2];
    if (!input) {
        console.log(color.dim("Usage: bun check.ts \"your question\""));
        process.exit(1);
    }

    const defaultSettings = await getDefaultBundledSettingsAsync();
    const projectConfig = existsSync(CSPELL_CONFIG) ? await loadConfig(CSPELL_CONFIG) : {};
    const settings = mergeSettings(defaultSettings, projectConfig);

    const issues = await validateText(input, settings);

    if (issues.length === 0) {
        console.log(color.green("✓ Question is clean."));
        process.exit(0);
    }

    console.log(color.yellow(`⚠️  ${issues.length} issue(s) detected:`));
    issues.forEach(issue => {
        console.log(`   - "${color.bold(issue.text)}" (suggestion: ${issue.suggestions?.slice(0, 1).join(", ") || "none"})`);
    });

    process.exit(1);
}

main();
