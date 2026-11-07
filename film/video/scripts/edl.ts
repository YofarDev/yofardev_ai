import { sections } from "../src/sections";
import { hits, regions } from "../src/audio";
console.log(JSON.stringify({ sections: sections(), regions: regions(), hits: hits() }, null, 1));
