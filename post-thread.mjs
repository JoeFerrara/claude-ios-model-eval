#!/usr/bin/env node

// Post an X thread from a markdown file.
//
// Usage:
//   node post-thread.mjs articles/v2-x-short.md
//   node post-thread.mjs articles/v2-x-long.md --dry-run
//   node post-thread.mjs articles/v2-x-short.md --substack-url "https://yourname.substack.com/p/your-post"
//
// Environment variables (or .env file):
//   X_API_KEY, X_API_SECRET, X_ACCESS_TOKEN, X_ACCESS_SECRET
//
// Hashtags are appended to the first tweet automatically.
// A Substack link is appended to the last tweet if --substack-url is provided.

import { readFileSync } from "fs";
import { TwitterApi } from "twitter-api-v2";

const HASHTAGS = "\n\n#iOSDev #SwiftUI #BuildInPublic #AIAgents #LLM";

// ---------------------------------------------------------------------------
// Parse args
// ---------------------------------------------------------------------------
const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const substackIdx = args.indexOf("--substack-url");
const substackUrl = substackIdx !== -1 ? args[substackIdx + 1] : null;
const mdFile = args.find((a) => !a.startsWith("--") && a !== substackUrl);

if (!mdFile) {
  console.error("Usage: node post-thread.mjs <thread.md> [--dry-run] [--substack-url URL]");
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Load .env if present (simple key=value, no dependency needed)
// ---------------------------------------------------------------------------
try {
  const envText = readFileSync(".env", "utf-8");
  for (const line of envText.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    let val = trimmed.slice(eq + 1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    if (!process.env[key]) process.env[key] = val;
  }
} catch {
  // no .env file, rely on environment
}

// ---------------------------------------------------------------------------
// Parse markdown into tweets
// ---------------------------------------------------------------------------
function parseTweets(markdown) {
  const tweets = [];
  // Split on **Tweet N:** pattern
  const parts = markdown.split(/\*\*Tweet \d+:\*\*\n?/);

  for (let i = 1; i < parts.length; i++) {
    let text = parts[i].trim();

    // Convert markdown code blocks to plain text (X doesn't render them)
    // Keep the content but remove the ``` fences
    text = text.replace(/```\w*\n?([\s\S]*?)```/g, (_, code) => code.trim());

    // Remove any trailing blank lines
    text = text.replace(/\n{3,}/g, "\n\n").trim();

    tweets.push(text);
  }

  return tweets;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
const markdown = readFileSync(mdFile, "utf-8");
const tweets = parseTweets(markdown);

if (tweets.length === 0) {
  console.error("No tweets found. Expected **Tweet N:** markers in the file.");
  process.exit(1);
}

// Add hashtags to first tweet
tweets[0] += HASHTAGS;

// Add Substack link to last tweet
if (substackUrl) {
  tweets[tweets.length - 1] += `\n\nFull writeup: ${substackUrl}`;
}

// Check character limits
// X Premium allows 25,000 chars, but tweets over 280 show "Show more" to free users.
// Use --strict for 280 limit. Default warns at 280 but only blocks at 25,000.
const strict = args.includes("--strict");
const HARD_LIMIT = strict ? 280 : 25000;
const SOFT_LIMIT = 280;
let hasWarnings = false;
let hasErrors = false;
for (let i = 0; i < tweets.length; i++) {
  const len = tweets[i].length;
  if (len > HARD_LIMIT) {
    console.error(`\x1b[31mError: Tweet ${i + 1} is ${len} chars (limit ${HARD_LIMIT})\x1b[0m`);
    hasErrors = true;
  } else if (len > SOFT_LIMIT) {
    console.warn(`\x1b[33mNote: Tweet ${i + 1} is ${len} chars (>${SOFT_LIMIT} = "Show more" for free users)\x1b[0m`);
  }
}
if (hasErrors) {
  console.error("\x1b[31mAborted: tweets exceed character limit.\x1b[0m");
  process.exit(1);
}

// Preview
console.log(`\n\x1b[1mThread: ${tweets.length} tweets from ${mdFile}\x1b[0m\n`);
for (let i = 0; i < tweets.length; i++) {
  const len = tweets[i].length;
  const color = len > SOFT_LIMIT ? "\x1b[33m" : "\x1b[36m";
  console.log(`${color}--- Tweet ${i + 1} (${len} chars) ---\x1b[0m`);
  console.log(tweets[i]);
  console.log();
}

if (dryRun) {
  console.log("\x1b[33m--dry-run: not posting.\x1b[0m");
  process.exit(0);
}

// no pause needed — warnings are informational for Premium accounts

// Validate credentials
const { X_API_KEY, X_API_SECRET, X_ACCESS_TOKEN, X_ACCESS_SECRET } = process.env;
if (!X_API_KEY || !X_API_SECRET || !X_ACCESS_TOKEN || !X_ACCESS_SECRET) {
  console.error("\x1b[31mMissing X API credentials.\x1b[0m");
  console.error("Set these in .env or environment:");
  console.error("  X_API_KEY, X_API_SECRET, X_ACCESS_TOKEN, X_ACCESS_SECRET");
  console.error("\nGet them at: https://developer.x.com/en/portal/dashboard");
  process.exit(1);
}

// Post the thread
const client = new TwitterApi({
  appKey: X_API_KEY,
  appSecret: X_API_SECRET,
  accessToken: X_ACCESS_TOKEN,
  accessSecret: X_ACCESS_SECRET,
});

console.log("Posting thread...\n");

try {
  const result = await client.v2.tweetThread(tweets);
  console.log(`\x1b[32mPosted ${result.length} tweets.\x1b[0m\n`);
  for (let i = 0; i < result.length; i++) {
    const id = result[i].data.id;
    console.log(`Tweet ${i + 1}: https://x.com/i/status/${id}`);
  }
  console.log(`\nThread URL: https://x.com/i/status/${result[0].data.id}`);
} catch (err) {
  console.error("\x1b[31mFailed to post thread:\x1b[0m", err.message || err);
  if (err.data) console.error(JSON.stringify(err.data, null, 2));
  process.exit(1);
}
