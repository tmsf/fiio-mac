# shellcheck shell=bash
# Sourced by the tools/*.sh scripts. Resolves the repo root and the built binaries.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin"
for t in audioprops running setdefault usbdesc; do
  [ -x "$BIN/$t" ] || { echo "missing $BIN/$t — run 'make' in $ROOT first" >&2; exit 1; }
done
fiio_node() { ioreg -p IOUSB -l -w0 2>/dev/null | grep -A30 '+-o FiiO'; }
fiio_node_summary() { fiio_node | grep -E '\+-o |idProduct|bcdDevice|USB Product Name|bNumConfigurations|kUSBCurrentConfiguration|bcdUSB|"Device Speed"'; }
