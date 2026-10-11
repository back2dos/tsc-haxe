# Toolchains for builds, gates, launchers and the test matrix (sourced by sh scripts; the Makefile
# reads the same values through `sh -c '. tools/env.sh; echo $VAR'`). Every value can be overridden
# by an environment variable of the same name. The caller sets ROOT (repository root) first.
#   HAXE_HOME   stock Haxe 4.3.7 (used by tools/haxe)
#   NODE        node for the JS target
#   JAVA        JDK 21 java for the JVM target; JAVA_OPTS: deep recursion needs a big thread stack
#               (the java launcher runs main() in a new thread with the -Xss size); -Xlog:exceptions=off:
#               Haxe declares `throws java.lang.Object` on methods that throw a String, and HotSpot
#               logs a warning to stdout when it reflects on such a method.
#   DOTNET      .NET 8 SDK for the C# target; HAXELIB_CS: the project-local haxelib repo with hxcs
#               (only for C# builds; the global haxelib repo is never changed)
#   PYTHON      Python 3.12 for the Python target
: "${HAXE_HOME:=/home/mib/Development/tools/haxe-347}"
: "${NODE:=node}"
: "${JAVA:=/home/mib/Development/tools/jdk21/bin/java}"
: "${JAVA_OPTS:=-Xss1g -XX:+UseParallelGC -Xlog:exceptions=off}"
: "${DOTNET:=/home/mib/Development/tools/dotnet8/dotnet}"
: "${PYTHON:=/usr/bin/python3}"
: "${HAXELIB_CS:=${ROOT:?tools/env.sh: set ROOT to the repository root first}/tools/.haxelib-cs}"
DOTNET_CLI_TELEMETRY_OPTOUT=1
export HAXE_HOME NODE JAVA JAVA_OPTS DOTNET PYTHON HAXELIB_CS DOTNET_CLI_TELEMETRY_OPTOUT
