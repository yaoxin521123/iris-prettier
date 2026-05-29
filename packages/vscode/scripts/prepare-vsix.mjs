import { cpSync, mkdirSync, rmSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { execSync } from "node:child_process";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const bundled = join(root, "bundled", "@iris-prettier", "core");
const pkgPath = join(root, "package.json");
const nmCore = join(root, "node_modules", "@iris-prettier", "core");

rmSync(join(root, "bundled"), { recursive: true, force: true });
mkdirSync(bundled, { recursive: true });

execSync("npm run build", { cwd: join(root, "..", "core"), stdio: "inherit" });
cpSync(join(root, "..", "core", "package.json"), join(bundled, "package.json"));
cpSync(join(root, "..", "core", "dist"), join(bundled, "dist"), { recursive: true });

const pkg = JSON.parse(readFileSync(pkgPath, "utf8"));
pkg.dependencies["@iris-prettier/core"] = "file:./bundled/@iris-prettier/core";
writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + "\n");

rmSync(join(root, "node_modules", "@iris-prettier"), { recursive: true, force: true });
execSync("npm install --no-audit --no-fund", { cwd: root, stdio: "inherit" });

// 仅保留 node_modules 内一份 core，bundled 仅供 npm install 使用
if (!nmCore) {
  throw new Error("Failed to install @iris-prettier/core into node_modules");
}

console.log("Prepared @iris-prettier/core for VSIX (node_modules)");
