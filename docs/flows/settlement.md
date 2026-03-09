# Settlement Flow

## Overview
Resolve markets using advanced weighted oracle consensus with matrix ops, relative advantages, and adaptive weights. Includes dispute handling.

## Steps
1. Fetch outcomes from 4 sources (ISU, Olympics, Sportradar, News) with weights & reliabilities
2. Apply Tiny Math Engine: matrix transform, noise jitter, advantage normalization
3. Compute consensus via weighted advantages + gradient updates
4. Check confidence threshold (75%): resolve on-chain or dispute
5. Log weight adaptations for future runs

## Files
- `workflows/settlement/workflow.ts` (Tiny Math Engine consensus)
- `scripts/demo/demo-olympics.sh` (demo)

## Tiny Math Engine Algorithm

### 1. Data Matrix (Linear Algebra)
Sources as 4x3 matrix: [outcome_sign, weight, reliability]

```typescript
const matrix = outcomes.map(o => [o.outcome ? 1 : -1, o.weight, o.rawReliability]);
```

### 2. Non-Deterministic Noise (Competitiveness)
Add seeded Gaussian-like jitter (±2.5%) for variance:

```typescript
const noise = (Math.sin(seed + rel) * 0.05 - 0.025);
reliability += noise; // Clipped 0.1-1.0
```

### 3. Relative Advantages (GRPO-Style)
Normalize reliabilities for fairness:

```typescript
const advantages = reliabilities.map(r => (r - meanRel) / stdRel);
```

### 4. Consensus Score (Weighted Sum)
```typescript
let yesWeighted = 0, total = 0;
for (let i = 0; i < 4; i++) {
    const contrib = outcomeSigns[i] * advantages[i] * weights[i];
    yesWeighted += contrib;
    total += Math.abs(contrib);
}
const yesPct = yesWeighted / total;
const consensusOutcome = yesPct >= 0;
const confidence = Math.max(yesPct, 1 - yesPct) * 100;
```

### 5. Gradient Weight Updates (PPO-Inspired Calculus)
Adapt weights based on agreement:

```typescript
const learningRate = 0.01;
weights[i] += learningRate * (agreed ? 1 : -1); // Clipped 0.5-2.0
```

## Visualizations

### Reliability Distribution Graph
```
Reliability Scores (with Noise Jitter)
1.0 ━━━━━━━━● ISU (0.95 + noise)
    ━━━━━━● Olympics (0.90 + noise)
    ━━━━● Sportradar (0.85 + noise)
0.7 ━━● News (0.75 + noise)
    0.7  0.8  0.9  1.0
```

### Advantage Normalization Graph
```
Relative Advantages (Z-Score Style)
+1.5 ━━━━━━━━● ISU (high rel → advantage)
      ━━━━━━● Olympics
      ━━━━● Sportradar
-1.5 ━━● News (low rel → disadvantage)
      -2.0 -1.0 0.0 1.0 2.0
```

### Consensus Contribution Graph
```
Weighted Contributions to Yes/No
+2.0 ━━━━━━━━● ISU (sign * adv * wt)
      ━━━━━━● Olympics
      ━━━━● Sportradar
-2.0 ━━● News
      -2.0 -1.0 0.0 1.0 2.0
Sum > 0 → Yes Consensus
```

### Weight Adaptation Over Runs
```
Weight Evolution (Gradient Descent)
2.0 ━━━━━━━━● ISU (starts 1.5, adapts)
1.5 ━━━━━━● Olympics (1.2)
1.0 ━━━━● Sportradar (1.0)
0.7 ━━● News (0.7)
      Run1 Run2 Run3 Run4
```

This makes consensus adaptive, competitive, and math-rich!
