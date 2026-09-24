# Print the OS CPU, not the CPU of this shell.
# Git Bash on Windows ARM64 is often an x64 process, so uname -m says x86_64.
host_machine() {
  local raw
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*)
      if command -v powershell.exe >/dev/null 2>&1; then
        raw="$(powershell.exe -NoProfile -Command '[System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture' 2>/dev/null | tr -d '\r')"
        case "${raw}" in
          Arm64) printf '%s\n' aarch64; return 0 ;;
          X64) printf '%s\n' x86_64; return 0 ;;
        esac
      fi
      ;;
  esac
  uname -m
}
