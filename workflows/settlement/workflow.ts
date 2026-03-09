// ===== IMPORTS =====
import { cre, ok, consensusIdenticalAggregation, bytesToHex, type Runtime, type HTTPSendRequester } from "@chainlink/cre-sdk";
import { Runner } from "@chainlink/cre-sdk";

// ===== CONSTANTS =====
// Constants – justified for stability / safety (mainnet thinking)
const LEARNING_RATE = 0.005;          // Small to avoid oscillation on noisy real data
const MOMENTUM_ALPHA = 0.95;          // Strong but stable momentum
const WEIGHT_CLIP_MIN = 0.3;          // Allow decay without disappearing
const WEIGHT_CLIP_MAX = 3.0;          // Prevent single-source dominance
const MIN_UPDATE_THRESHOLD = 0.70;    // Slightly below confidence threshold
const VARIANCE_PENALTY_FACTOR = 1.5;  // Stronger disagreement penalty
const OUTLIER_Z_THRESHOLD = 2.5;      // Standard outlier detection

// ===== DATA =====
import OLYMPIC_DATA from '../../docs/olympic-data.json';

// ===== SOURCES =====
// Pro Oracle Design: 4 authoritative sources only – no generative AI in resolution
// Weights & reliabilities reflect verifiability + independence + historical accuracy
const SOURCES = [
  { name: "ISU Official",       weight: 1.8, reliability: 0.98 },   // Primary federation results – highest trust
  { name: "Olympics.com",       weight: 1.5, reliability: 0.94 },   // Official IOC platform – structured, low spin
  { name: "Sportradar",         weight: 1.3, reliability: 0.92 },   // Commercial sports data provider – used by broadcasters
  { name: "News Headlines",     weight: 0.7, reliability: 0.78 }    // Aggregated media – lowest weight due to PR/ad noise
];

// Olympic data for realistic context (from docs/olympic-data.json)
// In prod: load from secret or fetch from ISU/Olympics API.

// ===== UTILITY FUNCTIONS =====

async function fetchRealOutcome(runtime: Runtime<any>, marketId: number, sourceName: string): Promise<boolean> {
  // TODO: Real HTTP fetches (ISU, Olympics.com, Sportradar APIs)
  runtime.log(`[WARN] Mock outcome for ${sourceName} – IMPLEMENT REAL FETCH FOR MAINNET`);

  // Optional realism: seeded random instead of strict %2
  const seed = marketId * 1103515245 + 12345;
  return (seed % 100) < 50; // ~50% Yes, reproducible per marketId
}

// Dynamic source weighting by market type
function getSourceWeights(marketId: number): number[] {
  // Market types: 0=headline, 1=technical, 2=subjective, 3=outcome
  const marketType = marketId % 4;
  switch (marketType) {
    case 0: // Headline (rivalry, placement) - boost News
      return [1.3, 1.1, 1.2, 1.0]; // ISU, Olympics, Sportradar, News
    case 1: // Technical (backflip, points) - boost Sportradar  
      return [1.4, 1.1, 1.5, 0.8];
    case 2: // Subjective (performance) - balanced
      return [1.5, 1.2, 1.0, 0.9];
    case 3: // Outcome (final results) - boost ISU
      return [1.8, 1.3, 1.1, 0.7];
    default:
      return [1.5, 1.2, 1.0, 0.7]; // Default weights
  }
}

// Adaptive confidence thresholds by market type
function getConfidenceThreshold(marketId: number): number {
  const marketType = marketId % 4;
  switch (marketType) {
    case 1: // Technical - lower threshold (more uncertainty)
      return 65;
    case 3: // Outcome - higher threshold (more confidence)
      return 85;
    default:
      return 75; // Standard threshold
  }
}

// Market-specific noise scaling
function getNoiseScale(marketId: number): number {
  const marketType = marketId % 4;
  switch (marketType) {
    case 1: // Technical - lower noise
      return 0.01;
    case 2: // Subjective - higher noise
      return 0.03;
    case 3: // Outcome - minimal noise
      return 0.005;
    default:
      return 0.025; // Standard noise
  }
// ===== MAIN SETTLEMENT LOGIC =====

async function settleMarketWithConsensus(runtime: Runtime<any>, marketId: number): Promise<void> {
  runtime.log(`[Settlement] Starting consensus oracle for market ${marketId} (type: ${marketId % 4})`);
  
  // Log Olympic context for realism
  const spHighlights = OLYMPIC_DATA.days[0]!.highlights!.join(', ');
  const fsKeyMoments = OLYMPIC_DATA.days[1]!.key_moments!.join(', ');
  runtime.log(`[Olympic Context] Short Program: ${spHighlights}`);
  runtime.log(`[Olympic Context] Free Skate: ${fsKeyMoments}`);
  
  // Load persisted sources (mainnet-ready: use CRE secrets)
  let sources = SOURCES;
  const secretResult = runtime.getSecret({ id: "ORACLE_SOURCES_STATE" }).result();
  if (secretResult && typeof secretResult === 'string') {
    try {
      const loaded = JSON.parse(secretResult);
      if (Array.isArray(loaded) && loaded.length === SOURCES.length) {
        sources = loaded;
        runtime.log("[Load] Persisted sources loaded from secret");
      }
    } catch (e) {
      runtime.log("[Load] Failed to parse secret – using defaults");
    }
  } else {
    runtime.log("[Load] No persisted state – using defaults");
  }

  // Fetch outcomes (parallel in real world)
  const dynamicWeights = getSourceWeights(marketId);
  const noiseScale = getNoiseScale(marketId);
  
  const outcomesPromises = sources.map(async (source, i) => {
    try {
      const outcome = await fetchRealOutcome(runtime, marketId, source.name);
      const weight = dynamicWeights[i];
      runtime.log(`[${source.name}] (${weight.toFixed(2)}): ${outcome ? 'Yes' : 'No'} (rel: ${source.reliability.toFixed(3)})`);
      return { outcome, weight, rawReliability: source.reliability };
    } catch (e) {
      runtime.log(`[Fetch Error] ${source.name} failed: ${(e as Error).message} – skipping source`);
      return null; // Will filter below
    }
  });

  const rawOutcomes = await Promise.all(outcomesPromises);
  const outcomes = rawOutcomes.filter(o => o !== null);

  if (outcomes.length < 3) {
    runtime.log(`[Error] Quorum failed after errors: only ${outcomes.length}/4 sources`);
    return;
  }

  // Matrix: [sign, weight, reliability]
  const matrix = outcomes.map(o => [o.outcome ? 1 : -1, o.weight, o.rawReliability] as [number, number, number]);

  // Market-specific LCG PRNG noise
  let seed = (marketId * 1103515245 + 12345) % (1 << 31);
  matrix.forEach(row => {
    seed = (seed * 1103515245 + 12345) % (1 << 31);
    const r = seed / (1 << 31);
    const noise = (r * noiseScale - noiseScale/2); // Scaled noise
    row[2] += noise;
    row[2] = Math.max(0.1, Math.min(1.0, row[2]));
  });

  const outcomeSigns = matrix.map(r => r[0]);
  let weights = matrix.map(r => r[1]);
  const reliabilities = matrix.map(r => r[2]);

  // Relative advantages (z-scores)
  const meanRel = reliabilities.reduce((a, b) => a + b, 0) / reliabilities.length;
  const variance = reliabilities.reduce((sum, r) => sum + (r - meanRel) ** 2, 0) / reliabilities.length;
  const stdRel = Math.sqrt(variance) || 1;
  const advantages = reliabilities.map(r => (r - meanRel) / stdRel);

  // Weighted score
  const yesWeighted = advantages.reduce((sum, adv, i) => sum + outcomeSigns[i] * adv * weights[i], 0);
  const totalAbs = advantages.reduce((sum, adv, i) => sum + Math.abs(outcomeSigns[i] * adv * weights[i]), 0);
  const yesPct = totalAbs ? yesWeighted / totalAbs : 0;
  const consensusOutcome = yesPct >= 0;
  const agreementStrength = Math.abs(yesPct);

  // Confidence with variance penalty
  const confidencePenalty = Math.min(0.8, variance * VARIANCE_PENALTY_FACTOR);
  let confidence = Math.round(agreementStrength * 100 * (1 - confidencePenalty));
  confidence = Math.max(0, Math.min(100, confidence));

  runtime.log(`[Consensus] ${consensusOutcome ? 'Yes' : 'No'} | Strength: ${agreementStrength.toFixed(3)} | Var: ${variance.toFixed(3)} | Conf: ${confidence}%`);

  // Outlier detection (safety rail)
  const zScores = reliabilities.map(r => (r - meanRel) / stdRel);
  const outliers = zScores.map((z, i) => Math.abs(z) > OUTLIER_Z_THRESHOLD ? i : -1).filter(i => i >= 0);
  if (outliers.length > 0) {
    runtime.log(`[Anomaly] Outliers detected: ${outliers.map(i => sources[i].name).join(', ')}`);
    outliers.forEach(i => { weights[i] *= 0.3; }); // Hard downweight for this run
  }

  // Adaptive update with momentum
  const momentum = new Array(weights.length).fill(0); // TODO: persist in prod
  if (agreementStrength >= MIN_UPDATE_THRESHOLD) {
    const agreementMask = outcomeSigns.map(s => (s > 0) === consensusOutcome ? 1 : -1);
    for (let i = 0; i < weights.length; i++) {
      const update = LEARNING_RATE * agreementMask[i];
      momentum[i] = MOMENTUM_ALPHA * momentum[i] + update;
      weights[i] += momentum[i];
      weights[i] = Math.max(WEIGHT_CLIP_MIN, Math.min(WEIGHT_CLIP_MAX, weights[i]));
      runtime.log(`[Adapt] ${sources[i].name} weight → ${weights[i].toFixed(3)} (mom: ${momentum[i].toFixed(4)})`);
    }

    // Persist stub (mainnet: use runtime.setSecret)
    const updatedSources = sources.map((s, i) => ({ ...s, weight: weights[i] }));
    runtime.log(`[Persist] Updated state (set as secret "ORACLE_SOURCES_STATE"): ${JSON.stringify(updatedSources, null, 2)}`);
    // In real prod: runtime.setSecret({ id: "ORACLE_SOURCES_STATE", value: JSON.stringify(updatedSources) });
  } else {
    runtime.log("[Adapt] Consensus too weak – skipping update");
  }

  // Adaptive confidence threshold
  const confidenceThreshold = getConfidenceThreshold(marketId);
  let reportData;
  if (confidence < confidenceThreshold) {
    runtime.log(`[Dispute] Confidence ${confidence}% < ${confidenceThreshold}% threshold – market disputed`);
    reportData = { marketId, outcome: 2, confidence, variance: variance.toFixed(3), marketType: marketId % 4, category: "Malinin vs Kagiyama 2026" };
  } else {
    reportData = { marketId, outcome: consensusOutcome ? 0 : 1, confidence, marketType: marketId % 4, category: "Malinin vs Kagiyama 2026" };
  }
  
  const encodedPayload = new TextEncoder().encode(JSON.stringify(reportData));

  const report = runtime.report({
      encodedPayload: encodedPayload as any,
      encoderName: "evm",
      signingAlgo: "secp256k1"
    }).result();

    if (!report) {
      runtime.log(`[Error] Report generation failed`);
      return;
    }

    const evmClient = new cre.capabilities.EVMClient(16015286601757825753n);
    const MARKET_ADDRESS = "0xfa96065F919762EFb7Bef68Edf9fb0559CC3e3a3";

    try {
      const reply = evmClient.writeReport(runtime, { receiver: MARKET_ADDRESS, report }).result();
      runtime.log(`[Success] Market ${marketId} settled – tx: ${bytesToHex(reply.txHash || new Uint8Array())}`);
    } catch (e: any) {
      runtime.log(`[Settlement] Write failed: ${e.message}`);
    }
}

// ===== TRIGGERS AND ENTRY POINTS =====

const httpTrigger = new cre.capabilities.HTTPCapability().trigger({});

const entry = cre.handler(httpTrigger, async (runtime: Runtime<any>, triggerData: any): Promise<any> => {
  const marketId = triggerData?.marketId || 1;
  await settleMarketWithConsensus(runtime, marketId);
  return {
    status: "Success",
    message: `Market ${marketId} settlement attempted with enhanced consensus oracle`
  };
});

export async function main() {
  const runner = await Runner.newRunner();
  await runner.run(() => [entry]);
}

main();