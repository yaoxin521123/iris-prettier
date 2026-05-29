import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const pkgPath = join(dirname(fileURLToPath(import.meta.url)), "..", "package.json");
const pkg = JSON.parse(readFileSync(pkgPath, "utf8"));
pkg.dependencies["@iris-prettier/core"] = "file:../core";
writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + "\n");
console.log("Restored package.json dependency to file:../core");
