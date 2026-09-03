import { mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import type { Locale } from "./i18n"

export type AppConfig = {
  locale: Locale
  mouse: boolean
  animations: boolean
}

const defaults: AppConfig = { locale: "en", mouse: true, animations: true }
const base = process.env.LOCALAPPDATA || process.env.APPDATA || process.cwd()
export const configPath = join(base, "WindowsPrinterSharingFix", "config.json")

export function loadConfig(): AppConfig {
  try {
    const parsed = JSON.parse(readFileSync(configPath, "utf8")) as Partial<AppConfig>
    return {
      locale: parsed.locale === "id" ? "id" : "en",
      mouse: parsed.mouse !== false,
      animations: parsed.animations !== false,
    }
  } catch {
    return { ...defaults }
  }
}

export function saveConfig(config: AppConfig) {
  mkdirSync(dirname(configPath), { recursive: true })
  writeFileSync(configPath, JSON.stringify(config, null, 2), "utf8")
}
