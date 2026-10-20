# Toolchains for builds, gates, launchers and the test matrix (sourced by sh scripts; the Makefile
# sources it through tools/targets.sh). The caller sets ROOT (repository root) first.
# Precedence: environment variable > tools/env.local.sh (machine-specific, not in git) > default.
# The defaults take each tool from PATH.
#   HAXE_HOME   directory of a Haxe 4.3.7 install (haxe + std/), used by tools/haxe; empty: haxe on PATH
#   NODE        node for the JS target
#   JAVA        java (JDK 21) for the JVM target; JAVA_OPTS: deep recursion needs a big thread stack
#               (the java launcher runs main() in a new thread with the -Xss size); -Xlog:exceptions=off:
#               Haxe declares `throws java.lang.Object` on methods that throw a String, and HotSpot
#               logs a warning to stdout when it reflects on such a method.
#   DOTNET      dotnet (.NET 8 SDK) for the C# target; HAXELIB_CS: the project-local haxelib repo with
#               hxcs (only for C# builds; `make setup-cs`; the global haxelib repo is never changed)
#   PYTHON      python3 (3.12) for the Python target
#   HXMC_HOME   an hxmc checkout (github.com/benmerckx/hxmc) with the tool built (make hxmc) for the hxmc target
_env_local="${ROOT:?tools/env.sh: set ROOT to the repository root first}/tools/env.local.sh"
[ -f "$_env_local" ] && . "$_env_local"
: "${HAXE_HOME:=}"
: "${NODE:=node}"
: "${JAVA:=java}"
: "${JAVA_OPTS:=-Xss1g -XX:+UseParallelGC -Xlog:exceptions=off}"
: "${DOTNET:=dotnet}"
: "${PYTHON:=python3}"
: "${HXMC_HOME:=}"
: "${HAXELIB_CS:=$ROOT/tools/.haxelib-cs}"
DOTNET_CLI_TELEMETRY_OPTOUT=1
export HAXE_HOME NODE JAVA JAVA_OPTS DOTNET PYTHON HXMC_HOME HAXELIB_CS DOTNET_CLI_TELEMETRY_OPTOUT
