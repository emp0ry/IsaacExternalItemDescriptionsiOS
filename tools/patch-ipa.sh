#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 decrypted-Isaac.ipa [output.ipa]" >&2
  exit 64
fi

input_ipa="${1:A}"
output_ipa="${2:-${input_ipa:r}-ExternalItemDescriptions.ipa}"
output_ipa="${output_ipa:A}"
script_dir="${0:A:h}"
project_root="${script_dir:h}"
dylib="${project_root}/build/IsaacExternalItemDescriptions.dylib"
description_db="${project_root}/build/IsaacEID.bundle/descriptions.json"

[[ -f "$input_ipa" ]] || { echo "Input IPA not found: $input_ipa" >&2; exit 66; }
[[ "$input_ipa" != "$output_ipa" ]] || { echo "Input and output IPA paths must differ" >&2; exit 64; }
if [[ -e "$output_ipa" && "${FORCE:-0}" != "1" ]]; then
  echo "Output exists: $output_ipa (set FORCE=1 to replace it)" >&2
  exit 73
fi
if [[ -n "${ENTITLEMENTS:-}" && ! -f "${ENTITLEMENTS:A}" ]]; then
  echo "Entitlements file not found: ${ENTITLEMENTS:A}" >&2
  exit 66
fi
if [[ ! -f "$dylib" ]]; then
  make -C "$project_root" dylib
fi
if [[ -n "${EID_SOURCE:-}" ]]; then
  make -C "$project_root" EID_SOURCE="${EID_SOURCE:A}" descriptions
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/IsaacEID.XXXXXX")"
cleanup() {
  if [[ -n "${work_dir:-}" && "$work_dir" == *IsaacEID.* && -d "$work_dir" ]]; then
    rm -rf "$work_dir"
  fi
}
trap cleanup EXIT INT TERM

ditto -x -k "$input_ipa" "$work_dir"
apps=("$work_dir"/Payload/*.app(N/))
(( ${#apps} == 1 )) || { echo "IPA must contain exactly one Payload/*.app" >&2; exit 65; }
app="${apps[1]}"
info="$app/Info.plist"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info")"
executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$info")"
executable="$app/$executable_name"

[[ "$bundle_id" == "com.Nicalis.Isaac-iOS" ]] || {
  echo "Refusing non-Isaac bundle identifier: $bundle_id" >&2
  exit 65
}
[[ -f "$executable" ]] || { echo "Main executable not found: $executable" >&2; exit 66; }

mkdir -p "$app/Frameworks"
cp "$dylib" "$app/Frameworks/IsaacExternalItemDescriptions.dylib"
chmod 0755 "$app/Frameworks/IsaacExternalItemDescriptions.dylib"
if [[ -f "$description_db" ]]; then
  mkdir -p "$app/Frameworks/IsaacEID.bundle"
  cp "$description_db" "$app/Frameworks/IsaacEID.bundle/descriptions.json"
else
  echo "No imported EID database; the dylib will use Isaac's bundled item metadata." >&2
fi
python3 "$script_dir/macho-add-dylib.py" "$executable" \
  '@executable_path/Frameworks/IsaacExternalItemDescriptions.dylib'

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  nested_args=(--force --sign "$SIGNING_IDENTITY" --timestamp=none)
  app_args=("${nested_args[@]}")
  if [[ -n "${ENTITLEMENTS:-}" ]]; then
    app_args+=(--entitlements "${ENTITLEMENTS:A}")
  fi
  while IFS= read -r nested; do
    codesign "${nested_args[@]}" "$nested"
  done < <(find "$app" -depth \( -name '*.framework' -o -name '*.dylib' -o -name '*.appex' \) -print)
  codesign "${app_args[@]}" "$app"
  codesign --verify --deep --strict "$app"
else
  rm -rf "$app/_CodeSignature"
  echo "Created an unsigned patched IPA; set SIGNING_IDENTITY and optionally ENTITLEMENTS to sign." >&2
fi

if [[ -e "$output_ipa" ]]; then rm -f "$output_ipa"; fi
(cd "$work_dir" && ditto -c -k --sequesterRsrc --keepParent Payload "$output_ipa")
echo "$output_ipa"
