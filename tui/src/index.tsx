import "@opentui/solid/preload"
import { createCliRenderer } from "@opentui/core"
import { render, useKeyboard, useRenderer, useTerminalDimensions } from "@opentui/solid"
import { For, Match, Show, Switch, createMemo, createSignal, onCleanup, onMount } from "solid-js"
import { loadConfig, saveConfig, type AppConfig } from "./config"
import { findingText, systemValue, tr, tx, td, type StringKey } from "./i18n"
import { deriveFindings, diagnose, runEngineAction, type Diagnosis, type EngineAction, type FindingCode, type Severity } from "./engine"

type Page = "home" | "diagnose" | "repairs" | "guide" | "settings"
type RepairTab = "safe" | "advanced" | "legacy"
type ConfirmRequest = {
  title: string; body: string; action: EngineAction; word?: string; inputLabel?: string; inputHint?: string;
  options?: Array<{ label: string; value: string }>; interfaceMode?: boolean
}

const theme = {
  bg: "#0b0f14", panel: "#101720", panel2: "#151e29", raised: "#1b2633",
  border: "#263445", borderActive: "#4a6a84", text: "#d6dee8", muted: "#7f8d9d",
  accent: "#71d7c2", accent2: "#79b8ff", success: "#9ed072", warning: "#e6b566", danger: "#ef7890",
}

const nav: Array<{ page: Page; icon: string; key: StringKey }> = [
  { page: "home", icon: "\u25C6", key: "dashboard" },
  { page: "diagnose", icon: "\u25CE", key: "diagnose" },
  { page: "repairs", icon: "\u25C7", key: "repairs" },
  { page: "guide", icon: "?", key: "guide" },
  { page: "settings", icon: "\u2699", key: "settings" },
]

function clickSafe(renderer: ReturnType<typeof useRenderer>) {
  return !renderer.getSelection()?.getSelectedText()
}
function Button(props: { label: string; onPress: () => void; tone?: "accent" | "danger" | "quiet"; disabled?: boolean }) {
  const renderer = useRenderer()
  const [hover, setHover] = createSignal(false)
  const color = () => props.tone === "danger" ? theme.danger : props.tone === "quiet" ? theme.muted : theme.accent
  return (
    <box
      height={3} paddingLeft={2} paddingRight={2} border borderStyle="rounded"
      borderColor={hover() ? color() : theme.border}
      backgroundColor={hover() ? theme.raised : theme.panel2}
      onMouseOver={() => setHover(true)} onMouseOut={() => setHover(false)}
      onMouseUp={() => { if (!props.disabled && clickSafe(renderer)) props.onPress() }}
    >
      <text fg={props.disabled ? theme.muted : color()}><b>{props.label}</b></text>
    </box>
  )
}

function Badge(props: { text: string; tone?: Severity | "accent" }) {
  const fg = () => ({ ok: theme.success, info: theme.accent2, warn: theme.warning, fail: theme.danger, accent: theme.accent }[props.tone ?? "accent"])
  return <text fg={fg()}>{"\u25CF"} {props.text}</text>
}

function Section(props: { title: string; children: any }) {
  return (
    <box flexDirection="column" gap={1}>
      <text fg={theme.text}><b>{props.title}</b></text>
      <box flexDirection="column" border borderStyle="rounded" borderColor={theme.border} backgroundColor={theme.panel} padding={1} gap={1}>
        {props.children}
      </box>
    </box>
  )
}

function Stat(props: { label: string; value: string; tone?: Severity }) {
  return (
    <box flexGrow={1} minWidth={17} flexDirection="column" border borderStyle="rounded" borderColor={theme.border} backgroundColor={theme.panel} padding={1}>
      <text fg={theme.muted}>{props.label}</text>
      <text fg={props.tone === "warn" ? theme.warning : props.tone === "fail" ? theme.danger : theme.text}><b>{props.value}</b></text>
    </box>
  )
}
function App() {
  const renderer = useRenderer()
  const dims = useTerminalDimensions()
  const initial = loadConfig()
  const [config, setConfig] = createSignal<AppConfig>(initial)
  const [page, setPage] = createSignal<Page>("home")
  const [navIndex, setNavIndex] = createSignal(0)
  const [repairTab, setRepairTab] = createSignal<RepairTab>("safe")
  const [diagnosis, setDiagnosis] = createSignal<Diagnosis | null>(null)
  const [busy, setBusy] = createSignal(false)
  const [error, setError] = createSignal("")
  const [spinner, setSpinner] = createSignal(0)
  const [palette, setPalette] = createSignal(false)
  const [paletteIndex, setPaletteIndex] = createSignal(0)
  const [confirmRequest, setConfirmRequest] = createSignal<ConfirmRequest | null>(null)
  const [confirmWord, setConfirmWord] = createSignal("")
  const [dialogInput, setDialogInput] = createSignal("")
  const [dialogOption, setDialogOption] = createSignal(0)
  const [dialogStage, setDialogStage] = createSignal(0)
  const [actionBusy, setActionBusy] = createSignal(false)
  const [actionError, setActionError] = createSignal("")
  const [toast, setToast] = createSignal("")
  let toastTimer: ReturnType<typeof setTimeout> | undefined

  const locale = () => config().locale
  const t = (key: StringKey) => tr(locale(), key)
  const x = (key: Parameters<typeof tx>[1]) => tx(locale(), key)
  const detail = (key: Parameters<typeof td>[1]) => td(locale(), key)
  const compact = createMemo(() => dims().width < 94 || dims().height < 25)
  const veryCompact = createMemo(() => dims().width < 72)
  const findings = createMemo(() => diagnosis() ? deriveFindings(diagnosis()!) : [])
  const spinFrames = ["\u280B", "\u2819", "\u2839", "\u2838", "\u283C", "\u2834", "\u2826", "\u2827", "\u2807", "\u280F"]

  function notify(message: string) {
    setToast(message)
    if (toastTimer) clearTimeout(toastTimer)
    toastTimer = setTimeout(() => setToast(""), 2200)
  }

  function persist(next: AppConfig) {
    setConfig(next)
    saveConfig(next)
  }

  function go(next: Page) {
    setPage(next)
    const idx = nav.findIndex((item) => item.page === next)
    if (idx >= 0) setNavIndex(idx)
  }

  async function runDiagnosis() {
    if (busy()) return
    setBusy(true); setError(""); setPage("diagnose")
    try {
      const result = await diagnose()
      setDiagnosis(result)
      notify(t("diagnosisDone"))
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e))
    } finally {
      setBusy(false)
    }
  }
  const paletteCommands = () => [
    { label: t("dashboard"), run: () => go("home") },
    { label: t("runDiagnosis"), run: () => void runDiagnosis() },
    { label: t("repairs"), run: () => go("repairs") },
    { label: t("guide"), run: () => go("guide") },
    { label: t("settings"), run: () => go("settings") },
    { label: locale() === "en" ? "Bahasa Indonesia" : "English", run: () => persist({ ...config(), locale: locale() === "en" ? "id" : "en" }) },
  ]

  onMount(() => {
    renderer.useMouse = config().mouse
    const timer = setInterval(() => {
      if ((busy() || actionBusy()) && config().animations) setSpinner((v) => (v + 1) % spinFrames.length)
    }, 80)
    onCleanup(() => clearInterval(timer))
  })

  useKeyboard((key) => {
    if (key.ctrl && key.name === "p") {
      key.preventDefault(); setPalette((v) => !v); setPaletteIndex(0); return
    }
    if (palette()) {
      if (key.name === "escape") { setPalette(false); return }
      if (key.name === "up") { setPaletteIndex((v) => Math.max(0, v - 1)); return }
      if (key.name === "down") { setPaletteIndex((v) => Math.min(paletteCommands().length - 1, v + 1)); return }
      if (key.name === "return" || key.name === "enter") {
        const cmd = paletteCommands()[paletteIndex()]; setPalette(false); cmd?.run(); return
      }
      return
    }
    if (confirmRequest()) {
      const request = confirmRequest()!
      if (key.name === "escape" && !actionBusy()) { setConfirmRequest(null); return }
      if (actionBusy()) return
      if (dialogStage() === 0 && request.options?.length) {
        if (key.name === "up") { setDialogOption((v) => Math.max(0, v - 1)); return }
        if (key.name === "down") { setDialogOption((v) => Math.min(request.options!.length - 1, v + 1)); return }
        if (key.name === "return" || key.name === "enter") { nextDialogStage(); return }
      }
      if (request.inputLabel || (dialogStage() === 1 && request.word)) return
      if (key.name === "return" || key.name === "enter") { nextDialogStage(); return }
      return
    }
    if (key.name === "escape") { if (page() !== "home") go("home"); return }
    if (key.name === "?" || (key.shift && key.name === "/")) { go("guide"); return }
    if (key.name === "q" && !key.ctrl) { renderer.destroy(); return }
    if (key.name === "up" || key.name === "k") { setNavIndex((v) => (v + nav.length - 1) % nav.length); return }
    if (key.name === "down" || key.name === "j") { setNavIndex((v) => (v + 1) % nav.length); return }
    if (key.name === "return" || key.name === "enter") { go(nav[navIndex()]!.page); return }
  })

  onCleanup(() => { if (toastTimer) clearTimeout(toastTimer) })
  function HomePage() {
    const d = diagnosis()
    return (
      <scrollbox flexGrow={1} verticalScrollbarOptions={{ trackOptions: { foregroundColor: theme.borderActive, backgroundColor: theme.bg } }}>
        <box flexDirection="column" padding={compact() ? 1 : 2} gap={1}>
          <box flexDirection="column" marginBottom={1}>
            <text fg={theme.accent}><b>{t("startHere")}</b></text>
            <text fg={theme.text}>{t("tagline")}</text>
            <text fg={theme.muted}>{t("helpHint")}</text>
          </box>
          <box flexDirection={compact() ? "column" : "row"} gap={1}>
            <box flexGrow={1} flexDirection="column" border borderStyle="rounded" borderColor={theme.accent} backgroundColor={theme.panel} padding={1} gap={1}
              onMouseUp={() => { if (clickSafe(renderer)) void runDiagnosis() }}>
              <text fg={theme.accent}><b>{"\u25CE"}  {t("runDiagnosis")}</b>  {"\u00B7"}  {t("recommended")}</text>
              <text fg={theme.muted}>{t("startHereBody")}</text>
            </box>
            <box flexGrow={1} flexDirection="column" border borderStyle="rounded" borderColor={theme.border} backgroundColor={theme.panel} padding={1} gap={1}
              onMouseUp={() => { if (clickSafe(renderer)) { setRepairTab("safe"); go("repairs") } }}>
              <text fg={theme.success}><b>{"\u25C7"}  {t("safeRepair")}</b></text>
              <text fg={theme.muted}>{t("safeRepairBody")}</text>
            </box>
          </box>
          <Show when={d} fallback={
            <Section title={t("status")}>
              <text fg={theme.muted}>{x("noSessionDiagnosis")}</text>
              <box flexDirection="row"><Button label={t("runDiagnosis")} onPress={() => void runDiagnosis()} /></box>
            </Section>
          }>
            {(data) => <>
              <text fg={theme.text} marginTop={1}><b>{t("status")}</b></text>
              <box flexDirection={compact() ? "column" : "row"} gap={1}>
                <Stat label={t("os")} value={`${data().os.Name} ${data().os.DisplayVersion || ""}`} />
                <Stat label={t("role")} value={systemValue(locale(), data().role)} />
                <Stat label={t("spooler")} value={systemValue(locale(), data().spooler)} tone={data().spooler === "Running" ? "ok" : "warn"} />
              </box>
              <box flexDirection={compact() ? "column" : "row"} gap={1}>
                <Stat label={t("printers")} value={String(data().printers.length)} />
                <Stat label={t("wpp")} value={data().wppEnabled ? x("active") : x("inactive")} tone={data().wppEnabled ? "info" : "ok"} />
                <Stat label={t("smb1")} value={systemValue(locale(), data().smb1Client)} tone={/^Enabled/i.test(data().smb1Client) ? "warn" : "ok"} />
              </box>
            </>}
          </Show>
        </box>
      </scrollbox>
    )
  }
  function DiagnosisPage() {
    const d = diagnosis()
    return (
      <scrollbox flexGrow={1} verticalScrollbarOptions={{ trackOptions: { foregroundColor: theme.borderActive, backgroundColor: theme.bg } }}>
        <box flexDirection="column" padding={compact() ? 1 : 2} gap={1}>
          <text fg={theme.text}><b>{t("diagnosisTitle")}</b></text>
          <text fg={theme.muted}>{t("diagnosisIntro")}</text>
          <Show when={busy()}>
            <box height={5} border borderStyle="rounded" borderColor={theme.accent} backgroundColor={theme.panel} padding={1} flexDirection="column">
              <text fg={theme.accent}><b>{config().animations ? spinFrames[spinner()] : "..."}  {t("diagnosisWorking")}</b></text>
              <text fg={theme.muted}>{x("diagnosisReadOnlyBody")}</text>
            </box>
          </Show>
          <Show when={!!error()}>
            <box border borderStyle="rounded" borderColor={theme.danger} backgroundColor={theme.panel} padding={1}>
              <text fg={theme.danger}><b>{error()}</b></text>
            </box>
          </Show>
          <Show when={!busy() && !d}>
            <box flexDirection="row"><Button label={t("runDiagnosis")} onPress={() => void runDiagnosis()} /></box>
          </Show>
          <Show when={!busy() ? d : null}>{(data) =>
            <box flexDirection="column" gap={1}>
              <box flexDirection={compact() ? "column" : "row"} gap={1}>
                <Stat label={t("os")} value={`${data().os.Name} build ${data().os.Build}`} />
                <Stat label={t("role")} value={systemValue(locale(), data().role)} />
                <Stat label={t("spooler")} value={systemValue(locale(), data().spooler)} tone={data().spooler === "Running" ? "ok" : "warn"} />
              </box>
              <Section title={t("recentFindings")}>
                <Show when={findings().length > 0} fallback={<text fg={theme.success}>{"\u25CF"} {t("noFindings")}</text>}>
                  <For each={findings()}>{(item) =>
                    <box flexDirection="row" gap={1}>
                      <Badge text={item.severity.toUpperCase()} tone={item.severity} />
                      <text fg={theme.text}>{findingText[locale()][item.code as FindingCode]}{item.detail ? ` (${item.detail})` : ""}</text>
                    </box>
                  }</For>
                </Show>
              </Section>
              <Section title={t("printers")}>
                <Show when={data().printers.length > 0} fallback={<text fg={theme.muted}>{x("noPrinters")}</text>}>
                  <For each={data().printers.slice(0, 8)}>{(p) =>
                    <box flexDirection="row" gap={1}>
                      <text fg={theme.text}>{"\u2022"} {p.Name || "?"}</text>
                      <text fg={theme.muted}>{p.DriverName || ""}</text>
                    </box>
                  }</For>
                </Show>
              </Section>
              <box flexDirection="row" gap={1}><Button label={t("refresh")} onPress={() => void runDiagnosis()} /></box>
            </box>
          }</Show>
        </box>
      </scrollbox>
    )
  }

  function RepairCard(props: { title: string; body: string; tone?: "safe" | "advanced" | "legacy"; onPress: () => void }) {
    const [hover, setHover] = createSignal(false)
    const accent = () => props.tone === "legacy" ? theme.danger : props.tone === "advanced" ? theme.warning : theme.success
    return (
      <box flexDirection="column" border borderStyle="rounded" borderColor={hover() ? accent() : theme.border}
        backgroundColor={hover() ? theme.raised : theme.panel} padding={1} gap={1}
        onMouseOver={() => setHover(true)} onMouseOut={() => setHover(false)}
        onMouseUp={() => { if (clickSafe(renderer)) props.onPress() }}>
        <text fg={accent()}><b>{props.title}</b></text>
        <text fg={theme.muted}>{props.body}</text>
      </box>
    )
  }

  function RepairsPage() {
    const safeCards = [
      ["safeRestart", "safeRestartBody"], ["safeFirewall", "safeFirewallBody"],
      ["safeDiscovery", "safeDiscoveryBody"], ["safeQueue", "safeQueueBody"], ["safeNetwork", "safeNetworkBody"],
      ["restore", "restoreBody"],
    ] as const
    const advancedCards = [
      ["rpcPipe", "rpcPipeBody"], ["pointPrint", "pointPrintBody"], ["wppHelp", "wppHelpBody"],
      ["resetConnection", "resetConnectionBody"], ["rpcPrivacy", "rpcPrivacyBody"],
    ] as const
    const legacyCards = [
      ["smb1Legacy", "smb1LegacyBody"], ["guestLegacy", "guestLegacyBody"], ["lmLegacy", "lmLegacyBody"],
    ] as const
    const cards = () => repairTab() === "safe" ? safeCards : repairTab() === "advanced" ? advancedCards : legacyCards
    return (
      <box flexDirection="column" flexGrow={1} padding={compact() ? 1 : 2} gap={1}>
        <box flexDirection="row" gap={1}>
          <Button label={t("safe")} tone={repairTab() === "safe" ? "accent" : "quiet"} onPress={() => setRepairTab("safe")} />
          <Button label={t("advanced")} tone={repairTab() === "advanced" ? "accent" : "quiet"} onPress={() => setRepairTab("advanced")} />
          <Button label={t("legacy")} tone={repairTab() === "legacy" ? "danger" : "quiet"} onPress={() => setRepairTab("legacy")} />
        </box>
        <scrollbox flexGrow={1} verticalScrollbarOptions={{ trackOptions: { foregroundColor: theme.borderActive, backgroundColor: theme.bg } }}>
          <box flexDirection="column" gap={1} paddingTop={1}>
            <For each={cards()}>{(card, index) =>
              <RepairCard title={t(card[0])} body={t(card[1])}
                tone={repairTab() === "legacy" ? "legacy" : repairTab() === "advanced" ? "advanced" : "safe"}
                onPress={() => openRepair(repairTab(), index())} />
            }</For>
          </box>
        </scrollbox>
      </box>
    )
  }
  function requestAction(request: ConfirmRequest) {
    setConfirmWord("")
    setDialogInput("")
    setDialogOption(0)
    setDialogStage(request.word && !request.inputLabel && !request.options?.length ? 1 : 0)
    setActionError("")
    setConfirmRequest(request)
  }

  async function executeRequestedAction() {
    const request = confirmRequest()
    if (!request || actionBusy()) return
    if (request.word && confirmWord().trim().toUpperCase() !== request.word) return
    const option = request.options?.[dialogOption()]
    setActionBusy(true); setActionError("")
    try {
      const result = await runEngineAction(request.action, {
        argument: request.inputLabel ? dialogInput().trim() : request.interfaceMode ? "" : option?.value,
        interfaceIndex: request.interfaceMode && option ? Number(option.value) : undefined,
        confirmed: true,
      })
      if (!result.ok) throw new Error(result.message)
      setConfirmRequest(null)
      notify(`${x("actionSucceeded")}: ${request.title}`)
      try { setDiagnosis(await diagnose()) } catch {}
    } catch (e) {
      setActionError(e instanceof Error ? e.message : String(e))
    } finally {
      setActionBusy(false)
    }
  }

  function openRepair(tab: RepairTab, index: number) {
    if (tab === "safe") {
      const actions = ["safe.restart-spooler", "safe.firewall", "safe.discovery"] as const
      if (index < 3) {
        const titles = ["safeRestart", "safeFirewall", "safeDiscovery"] as const
        requestAction({ title: t(titles[index]!), body: t(((["safeRestartBody","safeFirewallBody","safeDiscoveryBody"] as const)[index])!), action: actions[index]! })
        return
      }
      if (index === 3) {
        requestAction({ title: t("safeQueue"), body: x("clearConfirmBody"), action: "safe.clear-queue", word: "CLEAR" })
        return
      }
      if (index === 5) {
        requestAction({ title: t("restore"), body: x("restoreConfirmBody"), action: "restore.latest" })
        return
      }
      const profiles = diagnosis()?.profiles.filter((p) => p.IPv4Connectivity !== "Disconnected" && p.NetworkCategory !== "DomainAuthenticated") ?? []
      if (!profiles.length) { notify(detail("needsDiagnosis")); return }
      requestAction({ title: t("safeNetwork"), body: t("safeNetworkBody"), action: "safe.network-private", interfaceMode: true,
        options: profiles.map((p) => ({ label: `${p.InterfaceAlias || p.Name || t("network")} \u00B7 ${systemValue(locale(), p.NetworkCategory || "")}`, value: String(p.InterfaceIndex ?? -1) })) })
      return
    }
    if (tab === "advanced") {
      if (index === 0) {
        requestAction({ title: t("rpcPipe"), body: t("rpcPipeBody"), action: "compat.rpc-pipe" }); return
      }
      if (index === 1) {
        requestAction({ title: t("pointPrint"), body: `${t("pointPrintBody")} ${t("dangerConfirm")}`, action: "compat.point-print-connect",
          word: "RISK", inputLabel: x("printerPath"), inputHint: x("printerPathHint") }); return
      }
      if (index === 2) {
        go("diagnose"); notify(x("protectedPrintInfo")); return
      }
      if (index === 3) {
        const connections = diagnosis()?.connections ?? []
        if (!connections.length) { notify(detail("needsDiagnosis")); return }
        requestAction({ title: t("resetConnection"), body: t("resetConnectionBody"), action: "compat.remove-connection", word: "REMOVE",
          options: connections.map((p) => ({ label: p.Name || "?", value: p.Name || "" })) }); return
      }
      requestAction({ title: t("rpcPrivacy"), body: `${t("rpcPrivacyBody")} ${t("dangerConfirm")}`, action: "compat.rpc-privacy-off", word: "RISK" })
      return
    }
    const legacy = [
      { title: "smb1Legacy", body: "smb1LegacyBody", action: "legacy.smb1-client" },
      { title: "guestLegacy", body: "guestLegacyBody", action: "legacy.guest" },
      { title: "lmLegacy", body: "lmLegacyBody", action: "legacy.lm1" },
    ] as const
    const item = legacy[index]
    if (item) requestAction({ title: t(item.title), body: `${t(item.body)} ${t("dangerConfirm")}`, action: item.action, word: "LEGACY" })
  }
  function GuidePage() {
    const steps = [
      ["guideStep1", "guideStep1Body"], ["guideStep2", "guideStep2Body"], ["guideStep3", "guideStep3Body"],
      ["guideStep4", "guideStep4Body"], ["guideStep5", "guideStep5Body"],
    ] as const
    return (
      <scrollbox flexGrow={1} focused={page() === "guide"} verticalScrollbarOptions={{ trackOptions: { foregroundColor: theme.borderActive, backgroundColor: theme.bg } }}>
        <box flexDirection="column" padding={compact() ? 1 : 2} gap={1}>
          <text fg={theme.text}><b>{t("guideTitle")}</b></text>
          <text fg={theme.muted}>{t("guideIntro")}</text>
          <For each={steps}>{(step) =>
            <box flexDirection="column" border borderStyle="rounded" borderColor={theme.border} backgroundColor={theme.panel} padding={1} gap={1}>
              <text fg={theme.accent}><b>{t(step[0])}</b></text>
              <text fg={theme.text}>{t(step[1])}</text>
            </box>
          }</For>
          <box border borderStyle="rounded" borderColor={theme.warning} backgroundColor={theme.panel} padding={1} flexDirection="column" gap={1}>
            <text fg={theme.warning}><b>{t("highRisk")}</b></text>
            <text fg={theme.muted}>{t("legacyRepairBody")}</text>
          </box>
        </box>
      </scrollbox>
    )
  }

  function SettingRow(props: { title: string; body: string; value: string; onPress: () => void; active?: boolean }) {
    const [hover, setHover] = createSignal(false)
    return (
      <box flexDirection={compact() ? "column" : "row"} justifyContent="space-between" border borderStyle="rounded"
        borderColor={hover() ? theme.borderActive : theme.border} backgroundColor={hover() ? theme.raised : theme.panel} padding={1} gap={1}
        onMouseOver={() => setHover(true)} onMouseOut={() => setHover(false)} onMouseUp={() => { if (clickSafe(renderer)) props.onPress() }}>
        <box flexDirection="column" flexGrow={1}>
          <text fg={theme.text}><b>{props.title}</b></text><text fg={theme.muted}>{props.body}</text>
        </box>
        <Badge text={props.value} tone={props.active ? "ok" : "info"} />
      </box>
    )
  }
  function SettingsPage() {
    return (
      <scrollbox flexGrow={1} verticalScrollbarOptions={{ trackOptions: { foregroundColor: theme.borderActive, backgroundColor: theme.bg } }}>
        <box flexDirection="column" padding={compact() ? 1 : 2} gap={1}>
          <text fg={theme.text}><b>{t("settings")}</b></text>
          <SettingRow title={t("language")} body={t("languageBody")}
            value={locale() === "id" ? t("indonesian") : t("english")}
            active onPress={() => persist({ ...config(), locale: locale() === "en" ? "id" : "en" })} />
          <SettingRow title={t("mouse")} body={t("mouseBody")}
            value={config().mouse ? x("active") : x("inactive")} active={config().mouse}
            onPress={() => { const next={...config(),mouse:!config().mouse}; renderer.useMouse=next.mouse; persist(next) }} />
          <SettingRow title={t("animations")} body={t("animationsBody")}
            value={config().animations ? x("active") : x("inactive")} active={config().animations}
            onPress={() => persist({ ...config(), animations: !config().animations })} />
          <Section title={t("theme")}><text fg={theme.muted}>{t("themeBody")}</text></Section>
          <Show when={compact()}>
            <box border borderStyle="rounded" borderColor={theme.warning} backgroundColor={theme.panel} padding={1} flexDirection="column">
              <text fg={theme.warning}><b>{t("compact")}</b></text><text fg={theme.muted}>{t("compactBody")}</text>
            </box>
          </Show>
        </box>
      </scrollbox>
    )
  }

  function Header() {
    return (
      <box height={4} flexDirection="row" justifyContent="space-between" alignItems="center" paddingLeft={2} paddingRight={2}
        border={false} borderColor={theme.border} backgroundColor={theme.panel}>
        <box flexDirection="column">
          <box flexDirection="row" gap={1}>
            <text fg={theme.accent}><b>{t("appName")}</b></text>
            <text fg={theme.muted}>v4.1</text>
          </box>
          <text fg={theme.muted}>{veryCompact() ? t(nav.find((n)=>n.page===page())?.key ?? "dashboard") : t("tagline")}</text>
        </box>
        <box flexDirection="column" alignItems="flex-end">
          <Badge text={busy() || actionBusy() ? t("running") : t("ready")} tone={busy() || actionBusy() ? "info" : "ok"} />
          <text fg={theme.muted}>{dims().width}x{dims().height}</text>
        </box>
      </box>
    )
  }
  function NavItem(props: { item: typeof nav[number]; index: number; compact?: boolean }) {
    const [hover, setHover] = createSignal(false)
    const selected = () => page() === props.item.page
    return (
      <box height={3} paddingLeft={props.compact ? 1 : 2} paddingRight={props.compact ? 1 : 2} alignItems="center"
        border={selected()} borderStyle="rounded" borderColor={selected() ? theme.borderActive : theme.panel}
        backgroundColor={selected() || hover() ? theme.raised : theme.panel}
        onMouseOver={() => setHover(true)} onMouseOut={() => setHover(false)}
        onMouseUp={() => { if (clickSafe(renderer)) go(props.item.page) }}>
        <text fg={selected() ? theme.accent : hover() ? theme.text : theme.muted}>
          <b>{props.item.icon} {props.compact ? t(props.item.key).slice(0, 10) : t(props.item.key)}</b>
        </text>
      </box>
    )
  }

  function Sidebar() {
    return (
      <box width={25} flexDirection="column" backgroundColor={theme.panel} border={["right"]} borderColor={theme.border} padding={1} gap={1}>
        <text fg={theme.muted}>{x("keyboardMouse")}</text>
        <For each={nav}>{(item, index) => <NavItem item={item} index={index()} />}</For>
        <box flexGrow={1} />
        <box border borderStyle="rounded" borderColor={theme.border} padding={1} flexDirection="column">
          <text fg={theme.success}>{"\u25CF"} {t("footerReadOnly")}</text>
          <text fg={theme.muted}>{t("footerAdmin")}</text>
        </box>
      </box>
    )
  }

  function CompactNav() {
    return (
      <box height={4} flexDirection="row" backgroundColor={theme.panel} border={["bottom"]} borderColor={theme.border} paddingLeft={1} paddingRight={1}>
        <For each={nav}>{(item, index) =>
          <box flexGrow={1}><NavItem item={item} index={index()} compact /></box>
        }</For>
      </box>
    )
  }
  function Footer() {
    return (
      <box height={2} backgroundColor={theme.panel} border={["top"]} borderColor={theme.border} paddingLeft={2} paddingRight={2} justifyContent="space-between">
        <text fg={theme.muted}>{veryCompact() ? x("compactNavigation") : t("shortcuts")}</text>
        <Show when={!!toast()}><text fg={theme.accent}><b>{toast()}</b></text></Show>
      </box>
    )
  }

  function nextDialogStage() {
    const request = confirmRequest()
    if (!request) return
    if (dialogStage() === 0) {
      if (request.inputLabel && !dialogInput().trim()) return
      if (request.word) { setDialogStage(1); setConfirmWord(""); return }
    }
    void executeRequestedAction()
  }

  function ConfirmOverlay() {
    const request = confirmRequest()
    if (!request) return null
    const width = Math.min(Math.max(46, dims().width - 12), 72)
    const left = Math.max(1, Math.floor((dims().width - width) / 2))
    const top = Math.max(2, Math.floor((dims().height - 16) / 2))
    return (
      <box position="absolute" zIndex={100} left={left} top={top} width={width} minHeight={12} flexDirection="column"
        border borderStyle="rounded" borderColor={request.word ? theme.warning : theme.accent} backgroundColor={theme.panel2} padding={1} gap={1}>
        <text fg={request.word ? theme.warning : theme.accent}><b>{x("actionConfirm")} {"\u00B7"} {request.title}</b></text>
        <text fg={theme.text}>{request.body}</text>
        <Show when={dialogStage() === 0 && !!request.options?.length}>
          <box flexDirection="column" gap={0}>
            <text fg={theme.muted}>{request.interfaceMode ? x("selectNetwork") : x("selectPrinter")}</text>
            <For each={request.options}>{(option, index) =>
              <box height={2} paddingLeft={1} backgroundColor={dialogOption() === index() ? theme.raised : theme.panel2}
                onMouseUp={() => { if (clickSafe(renderer)) setDialogOption(index()) }}>
                <text fg={dialogOption() === index() ? theme.accent : theme.text}>{dialogOption() === index() ? ">" : " "} {option.label}</text>
              </box>
            }</For>
          </box>
        </Show>
        <Show when={dialogStage() === 0 && !!request.inputLabel}>
          <box flexDirection="column" gap={1}>
            <text fg={theme.muted}>{request.inputLabel}</text>
            <input focused placeholder={request.inputHint ?? ""} value={dialogInput()} onInput={setDialogInput} onSubmit={nextDialogStage}
              backgroundColor={theme.bg} focusedBackgroundColor={theme.bg} textColor={theme.text} focusedTextColor={theme.text}
              cursorColor={theme.accent} placeholderColor={theme.muted} />
          </box>
        </Show>
        <Show when={dialogStage() === 1 && !!request.word}>
          <box flexDirection="column" gap={1}>
            <text fg={theme.warning}>{t("typeToConfirm")}: <b>{request.word}</b></text>
            <input focused placeholder={request.word} value={confirmWord()} onInput={setConfirmWord} onSubmit={nextDialogStage}
              backgroundColor={theme.bg} focusedBackgroundColor={theme.bg} textColor={theme.text} focusedTextColor={theme.text}
              cursorColor={theme.warning} placeholderColor={theme.muted} />
          </box>
        </Show>
        <Show when={!!actionError()}>
          <box flexDirection="column" border borderStyle="rounded" borderColor={theme.danger} padding={1}>
            <text fg={theme.danger}><b>{x("actionFailed")}</b></text>
            <text fg={theme.muted}>{detail("technicalDetails")}: {actionError()}</text>
          </box>
        </Show>
        <Show when={actionBusy()}>
          <text fg={theme.accent}><b>{config().animations ? spinFrames[spinner()] : "..."} {t("running")}</b></text>
        </Show>
        <box flexDirection="row" justifyContent="flex-end" gap={1}>
          <Button label={t("cancel")} tone="quiet" disabled={actionBusy()} onPress={() => setConfirmRequest(null)} />
          <Button label={t("confirm")} tone={request.word ? "danger" : "accent"} disabled={actionBusy() || (dialogStage() === 1 && !!request.word && confirmWord().trim().toUpperCase() !== request.word)} onPress={nextDialogStage} />
        </box>
      </box>
    )
  }

  function PaletteOverlay() {
    if (!palette()) return null
    const width = Math.min(Math.max(40, dims().width - 18), 64)
    const left = Math.max(1, Math.floor((dims().width - width) / 2))
    const top = Math.max(2, Math.floor((dims().height - 14) / 2))
    return (
      <box position="absolute" zIndex={90} left={left} top={top} width={width} flexDirection="column"
        border borderStyle="rounded" borderColor={theme.accent} backgroundColor={theme.panel2} padding={1} gap={1}>
        <text fg={theme.accent}><b>{x("commandPalette")}</b></text>
        <text fg={theme.muted}>{x("commandPaletteHint")}</text>
        <For each={paletteCommands()}>{(cmd, index) =>
          <box height={2} paddingLeft={1} backgroundColor={paletteIndex() === index() ? theme.raised : theme.panel2}
            onMouseOver={() => setPaletteIndex(index())}
            onMouseUp={() => { if (clickSafe(renderer)) { setPalette(false); cmd.run() } }}>
            <text fg={paletteIndex() === index() ? theme.accent : theme.text}>
              {paletteIndex() === index() ? ">" : " "} {cmd.label}
            </text>
          </box>
        }</For>
      </box>
    )
  }
  function Content() {
    return (
      <Switch>
        <Match when={page() === "home"}><HomePage /></Match>
        <Match when={page() === "diagnose"}><DiagnosisPage /></Match>
        <Match when={page() === "repairs"}><RepairsPage /></Match>
        <Match when={page() === "guide"}><GuidePage /></Match>
        <Match when={page() === "settings"}><SettingsPage /></Match>
      </Switch>
    )
  }

  return (
    <box width="100%" height="100%" flexDirection="column" backgroundColor={theme.bg}>
      <Header />
      <Show when={compact()}><CompactNav /></Show>
      <box flexGrow={1} flexDirection="row">
        <Show when={!compact()}><Sidebar /></Show>
        <box flexGrow={1} flexDirection="column"><Content /></box>
      </box>
      <Footer />
      <PaletteOverlay />
      <ConfirmOverlay />
    </box>
  )
}

let resolveClosed!: () => void
const closed = new Promise<void>((resolve) => { resolveClosed = resolve })

const renderer = await createCliRenderer({
  screenMode: "main-screen",
  useMouse: true,
  enableMouseMovement: true,
  autoFocus: true,
  clearOnShutdown: true,
  exitOnCtrlC: true,
  targetFps: 30,
  maxFps: 60,
  onDestroy: () => resolveClosed(),
})

await render(() => <App />, renderer)
await closed