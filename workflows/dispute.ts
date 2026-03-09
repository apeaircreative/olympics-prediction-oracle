import { cre, type Runtime } from "@chainlink/cre-sdk";

// Dispute Workflow: Handles low-confidence settlements
async function handleDispute(runtime: Runtime<any>, marketId: number, confidence: number): Promise<void> {
    runtime.log(`[Dispute] Market ${marketId} disputed due to low confidence (${confidence.toFixed(1)}%)`);

    // In real impl: Notify token holders for UMA-style dispute
    // Mock: Log and reject settlement
    runtime.log(`[Dispute] Settlement rejected - awaiting human review or higher consensus`);
}

const httpTrigger = new cre.capabilities.HTTPCapability().trigger({});

const entry = cre.handler(httpTrigger, async (runtime: Runtime<any>, triggerData: any): Promise<any> => {
    const { marketId, confidence } = triggerData;
    await handleDispute(runtime, marketId, confidence);

    return {
        status: "Dispute Logged",
        message: `Dispute for market ${marketId} initiated`
    };
});

export async function main() {
    const runner = await Runner.newRunner();
    await runner.run(() => [entry]);
}
