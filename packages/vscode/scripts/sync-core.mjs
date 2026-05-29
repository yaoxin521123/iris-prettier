import { cpSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const coreRoot = join(root, "..", "core");
const bundledRoot = join(root, "bundled", "@iris-prettier", "core");

cpSync(join(coreRoot, "dist"), join(bundledRoot, "dist"), { recursive: true });

const pkg = JSON.parse(readFileSync(join(coreRoot, "package.json"), "utf8"));
writeFileSync(
  join(bundledRoot, "package.json"),
  JSON.stringify(
    {
      name: pkg.name,
      version: pkg.version,
      type: pkg.type,
      main: pkg.main,
      types: pkg.types,
      exports: pkg.exports,
    },
    null,
    2
  ) + "\n"
);

console.log("Synced @iris-prettier/core into bundled/");
