import { dirname, resolve } from "node:path"
import { existsSync } from "node:fs"

export type Severity = "ok" | "info" | "warn" | "fail"
export type FindingCode =
  | "spooler-missing" | "spooler-stopped" | "wpp-enabled"
  | "rpc-privacy-off" | "point-print-off" | "guest-on"
  | "legacy-lm" | "blank-password" | "smb1-on" | "public-network"
  | "print-events"

export type PrinterInfo = {
  Name?: string; DriverName?: string; PortName?: string; Shared?: boolean
  ShareName?: string; Type?: string; ComputerName?: string
}
export type NetworkProfile = {
  Name?: string; InterfaceAlias?: string; InterfaceIndex?: number
  NetworkCategory?: string; IPv4Connectivity?: string; IPv6Connectivity?: string
}
export type Diagnosis = {
  os: { Name: string; Build: number; DisplayVersion: string }
  role: string
  spooler: string
  printers: PrinterInfo[]
  sharedPrinters: PrinterInfo[]
  connections: PrinterInfo[]
  profiles: NetworkProfile[]
  wppEnabled: boolean
  smb1Client: string
  rpcPrivacy: { Present: boolean; Value: unknown }
  pointAndPrint: { Present: boolean; Value: unknown }
  guestAuth: { Present: boolean; Value: unknown }
  lmCompatibility: { Present: boolean; Value: unknown }
  blankPassword: { Present: boolean; Value: unknown }
  printErrors: Array<{ TimeCreated?: string; Id?: number; LevelDisplayName?: string; Message?: string }>
}
function rootCandidates() {
  const exeDir = dirname(process.execPath)
  return [
    process.env.PRINTERFIX_ROOT,
    resolve(import.meta.dir, "..", ".."),
    exeDir,
    process.cwd(),
  ].filter(Boolean) as string[]
}

export function findEngineScript(): string {
  for (const root of rootCandidates()) {
    const candidate = resolve(root, "FixPrinter.ps1")
    if (existsSync(candidate)) return candidate
  }
  throw new Error("FixPrinter.ps1 could not be located next to the TUI or repository root.")
}

function psQuote(value: string) {
  return `'${value.replaceAll("'", "''")}'`
}

export async function diagnose(): Promise<Diagnosis> {
  const script = findEngineScript()
  const command = `$ErrorActionPreference='Stop'; . ${psQuote(script)} -NoElevation -LibraryMode; ` +
    `$d=Invoke-Diagnosis -Quiet; ` +
    `$o=[ordered]@{os=$d.OS;role=$d.Role;spooler=$(if($d.Spooler){$d.Spooler.Status.ToString()}else{'Missing'});` +
    `printers=@($d.Printers);sharedPrinters=@($d.SharedPrinters);connections=@($d.Connections);profiles=@($d.Profiles);` +
    `wppEnabled=[bool]$d.WPP.Enabled;smb1Client=[string]$d.SMB1Client;rpcPrivacy=$d.RpcPrivacy;pointAndPrint=$d.PointAndPrint;` +
    `guestAuth=$d.GuestAuth;lmCompatibility=$d.LmCompatibility;blankPassword=$d.BlankPassword;printErrors=@($d.PrintErrors)}; ` +
    `$o|ConvertTo-Json -Depth 6 -Compress`

  const child = Bun.spawn(["powershell.exe", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command], {
    stdout: "pipe",
    stderr: "pipe",
    windowsHide: true,
  })
  const [stdout, stderr, code] = await Promise.all([
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
    child.exited,
  ])
  if (code !== 0) throw new Error(stderr.trim() || `PowerShell engine exited with code ${code}`)
  return JSON.parse(stdout.trim()) as Diagnosis
}
export function deriveFindings(d: Diagnosis): Array<{ code: FindingCode; severity: Severity; detail?: string }> {
  const out: Array<{ code: FindingCode; severity: Severity; detail?: string }> = []
  if (d.spooler === "Missing") out.push({ code: "spooler-missing", severity: "fail" })
  else if (d.spooler.toLowerCase() !== "running") out.push({ code: "spooler-stopped", severity: "warn" })
  if (d.wppEnabled) out.push({ code: "wpp-enabled", severity: "info" })
  if (d.rpcPrivacy?.Present && Number(d.rpcPrivacy.Value) === 0) out.push({ code: "rpc-privacy-off", severity: "warn" })
  if (d.pointAndPrint?.Present && Number(d.pointAndPrint.Value) === 0) out.push({ code: "point-print-off", severity: "warn" })
  if (d.guestAuth?.Present && Number(d.guestAuth.Value) === 1) out.push({ code: "guest-on", severity: "warn" })
  if (d.lmCompatibility?.Present && Number(d.lmCompatibility.Value) <= 2) out.push({ code: "legacy-lm", severity: "warn", detail: String(d.lmCompatibility.Value) })
  if (d.blankPassword?.Present && Number(d.blankPassword.Value) === 0) out.push({ code: "blank-password", severity: "warn" })
  if (/^Enabled/i.test(d.smb1Client)) out.push({ code: "smb1-on", severity: "warn" })
  if (d.profiles.some((p) => p.NetworkCategory === "Public" && p.IPv4Connectivity !== "Disconnected")) out.push({ code: "public-network", severity: "info" })
  if (d.printErrors.length > 0) out.push({ code: "print-events", severity: "info", detail: String(d.printErrors.length) })
  return out
}
export type EngineAction =
  | "safe.restart-spooler" | "safe.firewall" | "safe.discovery" | "safe.clear-queue" | "safe.network-private"
  | "compat.rpc-pipe" | "compat.point-print-connect" | "compat.remove-connection" | "compat.rpc-privacy-off"
  | "legacy.smb1-client" | "legacy.guest" | "legacy.lm1" | "restore.latest"

export type EngineActionOptions = {
  argument?: string
  interfaceIndex?: number
  confirmed?: boolean
}

export type EngineResult = {
  ok: boolean
  message: string
  snapshot?: string
  restartRequired?: boolean
}

function findSiblingScript(name: string): string {
  const engine = findEngineScript()
  const candidate = resolve(dirname(engine), name)
  if (!existsSync(candidate)) throw new Error(`${name} could not be located next to FixPrinter.ps1.`)
  return candidate
}
export async function runEngineAction(action: EngineAction, options: EngineActionOptions = {}): Promise<EngineResult> {
  const script = findEngineScript()
  const api = findSiblingScript("EngineApi.ps1")
  const arg = options.argument ?? ""
  const index = options.interfaceIndex ?? -1
  const confirmed = options.confirmed ? "$true" : "$false"
  const command = `$ErrorActionPreference='Stop'; . ${psQuote(script)} -NoElevation -LibraryMode; . ${psQuote(api)}; ` +
    `$r=Invoke-PrinterFixEngineAction -Action ${psQuote(action)} -Argument ${psQuote(arg)} -InterfaceIndex ${index} -Confirmed:${confirmed}; ` +
    `$r|ConvertTo-Json -Depth 5 -Compress`
  const child = Bun.spawn(["powershell.exe", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command], {
    stdout: "pipe",
    stderr: "pipe",
    windowsHide: true,
  })
  const [stdout, stderr, code] = await Promise.all([
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
    child.exited,
  ])
  if (code !== 0) throw new Error(stderr.trim() || `PowerShell engine exited with code ${code}`)
  const lines = stdout.trim().split(/\r?\n/).filter(Boolean)
  const json = lines.at(-1)
  if (!json) throw new Error("Engine returned no result.")
  return JSON.parse(json) as EngineResult
}
