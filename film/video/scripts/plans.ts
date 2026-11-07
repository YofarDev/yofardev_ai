import { toolsPlan, wardrobePlan, journeyPlan, finalePlan } from "../src/plans";
const t = toolsPlan();
console.log(t.segs.map((s) => `${s.from} +${s.dur} @${Math.round(s.atMs)} x${s.rate ?? 1}`).join("\n"), t.dur);
console.log(wardrobePlan().map((p) => `${p.label} at ${p.at} len ${p.len}`).join("\n"));
console.log(JSON.stringify(journeyPlan()), JSON.stringify(finalePlan()));
