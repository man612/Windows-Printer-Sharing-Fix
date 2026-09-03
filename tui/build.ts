import solidPlugin from "@opentui/solid/bun-plugin"
import { copyFileSync, mkdirSync } from "node:fs"
import { resolve } from "node:path"

const root = import.meta.dir
mkdirSync(resolve(root, "dist"), { recursive: true })

const result = await Bun.build({
  entrypoints: [resolve(root, "src/index.tsx")],
  target: "bun",
  plugins: [solidPlugin],
  sourcemap: "none",
  minify: false,
  compile: {
    outfile: resolve(root, "dist/PrinterFixTUI.exe"),
    autoloadDotenv: false,
    autoloadBunfig: false,
    autoloadTsconfig: false,
    autoloadPackageJson: false,
  },
})

if (!result.success) {
  for (const log of result.logs) console.error(log)
  process.exit(1)
}

copyFileSync(resolve(root, "../FixPrinter.ps1"), resolve(root, "dist/FixPrinter.ps1"))
copyFileSync(resolve(root, "../EngineApi.ps1"), resolve(root, "dist/EngineApi.ps1"))
console.log(`Built ${resolve(root, "dist/PrinterFixTUI.exe")}`)
