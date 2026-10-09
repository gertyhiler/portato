# macOS operation and troubleshooting

Open `~/Applications/Portato Menu Bar.app`. By default, the app connects to an
existing daemon or starts the bundled Go core once if none is available. Retry
with Start Daemon. Settings can disable startup. Closing the menu leaves the
daemon and its tunnels running.

Open Portato at Login uses macOS ServiceManagement. When macOS requires approval,
choose Allow in Login Items. The menu reads the actual OS registration status.
Daemon Login Service separately opens launchd installation/removal in Terminal.
Removing that service stops its daemon. After moving the application, reinstall
the service so it references the new bundled executable path.

Add Tunnel and Edit Tunnel save through the daemon API. Advanced fields such as
jump and tags are preserved. Use the shared YAML through Open Configuration, or
the TUI, to edit advanced settings. Reload Configuration validates YAML immediately;
Go retains the last working configuration if validation fails. If another client
changed a tunnel while its form was open, reopen the form before saving. This is
stale-form detection, not a transactional lock across clients.

State is synchronized by SSE and a five-second refresh. The IPC token is read
for every request. `/info` reports the protocol version and actual YAML path,
including custom `--config` paths. Use a compatible build for a daemon lacking `/info` or using another protocol.
The menu displays compatibility/authentication errors without starting another
daemon. Only a missing/refused socket permits startup. Update the app and bundled
core together; do not use the upstream updater to replace the bundled executable.

For startup errors, inspect the TUI and the standard Portato Go logs. Diagnostic
modes `--menu-json` and `--list-json` neither start the daemon nor change login items.
A connected SSH tunnel does not prove the destination service is listening.
