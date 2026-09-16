# Next-layer correlation

Windows Printer Sharing Fix can turn the evidence it already collected into a conservative **Next layer to investigate** result.

This result is a troubleshooting priority, **not a root-cause claim**. It does not add network probes, change Windows state, or automatically recommend security downgrades.

## Dependency order

When a shared-printer target path has been tested, the correlation layer prioritizes the earliest failed prerequisite:

1. local Print Spooler availability/state;
2. DNS/name resolution;
3. SMB/TCP 445 reachability;
4. RPC Endpoint Mapper/TCP 135 reachability;
5. host share namespace access;
6. WPP, driver/package, policy, sharing/connection, and other PrintService evidence;
7. functional test-print verification when no earlier problem is evident.

A successful TCP 135 check proves only RPC Endpoint Mapper reachability. It does **not** prove that later dynamic RPC ports are reachable.
## Without a target-path test

If the local Spooler is healthy but no target path was tested, the result is `RemoteTransportUntested`. Local WPP state, Public network profile state, and normalized PrintService categories can still appear as supporting signals, but the tool does not pretend they outrank untested DNS/SMB/RPC dependencies.

## Structured result

Sanitized JSON includes only normalized data:

```json
{
  "Layer": "RpcReachability",
  "Reason": "TargetRpc135Failed",
  "RemoteTransportTested": true,
  "Signals": ["PrintService:SharingOrConnection"],
  "RootCauseClaimed": false
}
```

`Signals` never includes hostnames, printer/share names, IP addresses, credentials, or raw PrintService messages.
