# Print the OS CPU, not the CPU of this shell.
# Git Bash on Windows ARM64 is an x64 process, so uname -m is x86_64.
# Windows PowerShell 5.1 reports OSArchitecture as X64 from that process too.
# The machine environment in the registry is the installed OS architecture.
host_machine() {
  local line raw
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*)
      if command -v reg.exe >/dev/null 2>&1; then
        line="$(reg.exe query 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' /v PROCESSOR_ARCHITECTURE 2>/dev/null | tr -d '\r')"
        raw="$(printf '%s\n' "${line}" | awk 'NF { last = $NF } END { print last }')"
        case "${raw}" in
          ARM64 | aarch64) printf '%s\n' aarch64; return 0 ;;
          AMD64 | x86_64) printf '%s\n' x86_64; return 0 ;;
        esac
      fi
      ;;
  esac
  uname -m
}
