#!/bin/bash
# Compile the desktop NewPipe sidecar and shade its runtime jars into one jar.
set -eu
jars="${1:?jar directory}"
src="${2:?kotlin source root}"
out="${3:?output jar}"

classes="$(mktemp -d)"
fat="$(mktemp -d)"
trap 'rm -rf "$classes" "$fat"' EXIT

mapfile -t sources < <(find "$src" -name '*.kt' | sort)
cp="$(find "$jars" -name '*.jar' ! -name 'kotlin-compiler-embeddable-*.jar' | paste -sd: -)"
java -cp "$(find "$jars" -name '*.jar' | paste -sd: -)" org.jetbrains.kotlin.cli.jvm.K2JVMCompiler \
  -no-stdlib \
  -jvm-target 17 \
  -cp "$cp" \
  -d "$classes" \
  "${sources[@]}"

shopt -s nullglob
for jar in "$jars"/*.jar; do
  case "$(basename "$jar")" in
    kotlin-compiler-embeddable-*|kotlin-daemon-embeddable-*) continue ;;
  esac
  unzip -qo "$jar" -d "$fat"
done
rm -rf "$fat"/META-INF/*.SF "$fat"/META-INF/*.RSA "$fat"/META-INF/*.DSA
cp -a "$classes"/. "$fat"/
mkdir -p "$(dirname "$out")"
jar cfe "$out" com.fazilvk.fluxtube.spike.MainKt -C "$fat" .
