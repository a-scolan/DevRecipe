#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM="${DEVRECIPE_PLATFORM:-}"
REQUESTED_PROFILES=("default")
MODE="install"
WITH_CONTAINERS=false
WITH_PREFLIGHT=false
WITH_REVIEW=false
CONFIRM_UNINSTALL=false
UNINSTALL_IDS=()

usage() {
    cat <<'EOF'
Usage: bash ./DevRecipe_unix.bash [options]

Options:
  --profile ai-agents,cloud  Add optional profiles (default is always selected).
  --validate                 Validate the platform manifest without changes.
    --list                     List selected manifest entries without provider calls.
  --dry-run                  Print the provider plan without changes.
  --status                   Show declared entries and their current provider state.
    --containers               Install the explicit container runtime bundle for this host.
    --preflight                Inspect bounded local conflict evidence before installation.
    --review                   Require an interactive approval before each write.
    --uninstall <id[,id]>      Show a removal plan for exact declared IDs.
    --yes, -y                  Execute an --uninstall plan.
  --help, -h                 Show this help.
EOF
}

detect_platform() {
    if [[ -n "$PLATFORM" ]]; then
        case "$PLATFORM" in
            macos|linux) ;;
            *) printf 'Unknown DevRecipe platform: %s\n' "$PLATFORM" >&2; exit 2 ;;
        esac
    else
        case "$(uname -s)" in
            Darwin) PLATFORM="macos" ;;
            Linux) PLATFORM="linux" ;;
            *)
                printf 'Unsupported Unix host: %s. Use macOS or Ubuntu/Debian.\n' "$(uname -s)" >&2
                exit 1
                ;;
        esac
    fi

    if [[ "${DEVRECIPE_ALLOW_CROSS_PLATFORM_TEST:-false}" == true ]]; then
        return
    fi

    case "$(uname -s)" in
        Darwin) detected_platform="macos" ;;
        Linux) detected_platform="linux" ;;
        *) return ;;
    esac
    if [[ "$detected_platform" != "$PLATFORM" ]]; then
        printf 'This recipe targets %s, but the detected host is %s.\n' "$PLATFORM" "$detected_platform" >&2
        exit 1
    fi
}

array_contains() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

add_profile() {
    local profile="$1"
    profile="${profile//-/_}"
    case "$profile" in
        default|ai_agents|cloud) ;;
        *)
            printf "Unknown profile '%s'. Available profiles: default, ai-agents, cloud.\n" "$1" >&2
            exit 2
            ;;
    esac
    array_contains "$profile" "${REQUESTED_PROFILES[@]}" || REQUESTED_PROFILES+=("$profile")
}

set_mode() {
    local requested_mode="$1"
    if [[ "$MODE" != install && "$MODE" != "$requested_mode" ]]; then
        printf 'Choose only one mode: --validate, --list, --dry-run, --status, or --uninstall.\n' >&2
        exit 2
    fi
    MODE="$requested_mode"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            [[ $# -ge 2 ]] || { printf '%s\n' '--profile requires a value.' >&2; exit 2; }
            IFS=',' read -r -a profile_values <<< "$2"
            for profile in "${profile_values[@]}"; do add_profile "$profile"; done
            shift 2
            ;;
        --validate)
            set_mode validate
            shift
            ;;
        --list)
            set_mode list
            shift
            ;;
        --dry-run)
            set_mode dry-run
            shift
            ;;
        --status)
            set_mode status
            shift
            ;;
        --containers)
            WITH_CONTAINERS=true
            shift
            ;;
        --preflight)
            WITH_PREFLIGHT=true
            shift
            ;;
        --review)
            WITH_REVIEW=true
            shift
            ;;
        --uninstall)
            [[ $# -ge 2 ]] || { printf '%s\n' '--uninstall requires a declared identifier.' >&2; exit 2; }
            set_mode uninstall
            IFS=',' read -r -a uninstall_values <<< "$2"
            for uninstall_id in "${uninstall_values[@]}"; do
                [[ -n "$uninstall_id" ]] || { printf '%s\n' '--uninstall cannot contain an empty value.' >&2; exit 2; }
                array_contains "$uninstall_id" "${UNINSTALL_IDS[@]}" || UNINSTALL_IDS+=("$uninstall_id")
            done
            shift 2
            ;;
        --yes|-y)
            CONFIRM_UNINSTALL=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
done

detect_platform

if [[ "$CONFIRM_UNINSTALL" == true && "$MODE" != uninstall ]]; then
    printf '%s\n' '--yes requires --uninstall.' >&2
    exit 2
fi
if [[ "$WITH_PREFLIGHT" == true && "$MODE" != install && "$MODE" != dry-run ]]; then
    printf '%s\n' '--preflight is limited to installation or --dry-run.' >&2
    exit 2
fi
if [[ "$WITH_REVIEW" == true && "$MODE" != install && ! ( "$MODE" == uninstall && "$CONFIRM_UNINSTALL" == true ) ]]; then
    printf '%s\n' '--review is limited to installation or removal confirmed with --yes.' >&2
    exit 2
fi
if [[ "$WITH_REVIEW" == true && "$MODE" == dry-run ]]; then
    printf '%s\n' '--review cannot be combined with --dry-run.' >&2
    exit 2
fi
if [[ "$MODE" == install || "$MODE" == dry-run ]]; then
    WITH_PREFLIGHT=true
fi

TOML_PATH="$SCRIPT_DIR/DevRecipe_${PLATFORM}.toml"
if [[ ! -f "$TOML_PATH" ]]; then
    printf 'Invalid DevRecipe manifest: %s\n' "$TOML_PATH" >&2
    printf '%s\n' '  - file not found.' >&2
    printf '%s\n' 'No changes were made.' >&2
    exit 2
fi

validate_manifest() {
    local validation_errors
    if ! validation_errors=$(awk -v platform="$PLATFORM" '
        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }

        function add_error(path, message, location) {
            if (location == 0) location = "end of file"
            else location = "line " location
            printf "  - %s, `%s` : %s\n", location, path, message
            invalid = 1
        }

        function known_profile(profile) {
            return profile == "default" || profile == "ai_agents" || profile == "cloud"
        }

        function valid_identifier(value) {
            return value ~ /^[A-Za-z0-9_-]+$/
        }

        function package_provider_is_valid(provider) {
            if (platform == "macos") return provider == "os" || provider == "cask"
            return provider == "os" || provider == "flatpak"
        }

        {
            line = $0
            sub(/[[:space:]]*#.*/, "", line)
            line = trim(line)
            if (line == "") next

            if (line ~ /^\[/) {
                current_kind = ""
                current_section = ""
                if (line !~ /^\[[^]]+\]$/) {
                    add_error("section", "invalid TOML header", NR)
                    next
                }

                section = substr(line, 2, length(line) - 2)
                section_count = split(section, parts, "\\.")
                section_is_valid = 1
                for (part_index = 1; part_index <= section_count; part_index++) {
                    if (!valid_identifier(parts[part_index])) section_is_valid = 0
                }
                if (!section_is_valid) {
                    add_error("section." section, "invalid section segment", NR)
                    next
                }
                if (seen_section[section]++) add_error("section." section, "section declared more than once", NR)

                if (section == "metadata") {
                    metadata_seen = 1
                    current_kind = "metadata"
                    current_section = section
                    next
                }
                if (section_count == 2 && parts[1] == "profiles") {
                    current_kind = "profile"
                    current_section = section
                    current_profile = parts[2]
                    profile_seen[current_profile] = 1
                    if (!known_profile(current_profile)) {
                        add_error("profiles." current_profile, "unsupported profile; accepted values: default, ai_agents, cloud", NR)
                    }
                    next
                }
                if (section_count == 4 && (parts[1] == "packages" || parts[1] == "runtimes" || parts[1] == "tools" || parts[1] == "containers")) {
                    current_kind = "entry"
                    current_section = section
                    current_type = parts[1]
                    current_profile = parts[2]
                    current_provider = parts[3]
                    current_category = parts[4]
                    entry_section[current_section] = 1
                    profile_used[current_profile] = 1
                    if (!known_profile(current_profile)) {
                        add_error(current_type "." current_profile, "unsupported profile; accepted values: default, ai_agents, cloud", NR)
                    }
                    if ((current_type == "packages" || current_type == "containers") && !package_provider_is_valid(current_provider)) {
                        expected = platform == "macos" ? "cask, os" : "flatpak, os"
                        add_error(current_section, "unsupported provider; accepted values: " expected, NR)
                    }
                    if ((current_type == "runtimes" || current_type == "tools") && current_provider != "mise") {
                        add_error(current_section, "unsupported provider; accepted value: mise", NR)
                    }
                    next
                }
                add_error("section." section, "unknown section or invalid TOML level", NR)
                next
            }

            if (current_kind == "") {
                add_error("syntax", "entry outside a recognised section", NR)
                next
            }

            equals_index = index(line, "=")
            if (equals_index <= 1) {
                add_error(current_section, "invalid entry; use identifier = value", NR)
                next
            }
            key = trim(substr(line, 1, equals_index - 1))
            value = trim(substr(line, equals_index + 1))
            if (key ~ /^"[^"]+"$/) key = substr(key, 2, length(key) - 2)
            else if (!valid_identifier(key)) {
                add_error(current_section, "invalid key identifier", NR)
                next
            }
            if (seen_key[current_section SUBSEP key]++) {
                add_error(current_section "." key, "key declared more than once", NR)
                next
            }

            if (current_kind == "metadata") {
                if (key != "schema_version" || value != "2") {
                    add_error("metadata." key, "use schema_version = 2", NR)
                } else schema_declared = 1
                next
            }
            if (current_kind == "profile") {
                if (key != "description" || value !~ /^"[^"]+"$/) {
                    add_error("profiles." current_profile, "text description is required", NR)
                } else profile_description[current_profile] = 1
                next
            }

            entry_count[current_section]++
            if (key == "" || key ~ /[[:space:]]/) {
                add_error(current_section, "invalid package identifier", NR)
                next
            }
            if (value !~ /^"[^"]*"$/) {
                add_error(current_section "." key, "version must be a TOML string", NR)
                next
            }
            version = substr(value, 2, length(value) - 2)
            if (version == "" && !(current_type == "runtimes" && current_category == "optional")) {
                add_error(current_section "." key, "empty version is reserved for runtimes in the optional category", NR)
            } else if (version != trim(version)) {
                add_error(current_section "." key, "version must not contain leading or trailing spaces", NR)
            }
        }

        END {
            if (!metadata_seen) add_error("metadata", "[metadata] table is required", 0)
            if (metadata_seen && !schema_declared) add_error("metadata.schema_version", "required key missing; use schema_version = 2", 0)
            if (!profile_seen["default"]) add_error("profiles.default", "required profile is missing", 0)
            for (profile in profile_seen) {
                if (known_profile(profile) && !profile_description[profile]) {
                    add_error("profiles." profile, "text description is required", 0)
                }
            }
            for (profile in profile_used) {
                if (known_profile(profile) && !profile_seen[profile]) {
                    add_error("profiles." profile, "profile is used but not declared", 0)
                }
            }
            for (entry in entry_section) {
                if (!entry_count[entry]) add_error(entry, "must contain at least one entry", 0)
            }
            exit invalid ? 1 : 0
        }
    ' "$TOML_PATH"); then
        printf 'Invalid DevRecipe manifest: %s\n' "$TOML_PATH" >&2
        [[ -z "$validation_errors" ]] || printf '%s\n' "$validation_errors" >&2
        printf '%s\n' 'Action: correct the reported entries, then run the recipe again.' >&2
        printf '%s\n' 'No changes were made.' >&2
        return 1
    fi
}

read_manifest_entries() {
    awk '
        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }
        /^[[:space:]]*\[/ {
            section = $0
            sub(/^[[:space:]]*\[/, "", section)
            sub(/\][[:space:]]*(#.*)?$/, "", section)
            count = split(section, parts, "\\.")
            if (count == 4 && (parts[1] == "packages" || parts[1] == "runtimes" || parts[1] == "tools")) {
                type = parts[1]
                profile = parts[2]
                provider = parts[3]
                category = parts[4]
            } else type = ""
            next
        }
        type != "" {
            line = $0
            sub(/[[:space:]]*#.*/, "", line)
            if (line !~ /=/) next
            key = line
            sub(/[[:space:]]*=.*/, "", key)
            key = trim(key)
            sub(/^"/, "", key)
            sub(/"$/, "", key)
            value = line
            sub(/^[^=]*=[[:space:]]*/, "", value)
            value = trim(value)
            sub(/^"/, "", value)
            sub(/"$/, "", value)
            if (key != "") printf "%s\t%s\t%s\t%s\t%s\t%s\n", type, profile, provider, category, key, value
        }
    ' "$TOML_PATH"
}

read_container_entries() {
    awk '
        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }
        /^[[:space:]]*\[/ {
            section = $0
            sub(/^[[:space:]]*\[/, "", section)
            sub(/\][[:space:]]*(#.*)?$/, "", section)
            count = split(section, parts, "\\.")
            if (count == 4 && parts[1] == "containers") {
                profile = parts[2]
                provider = parts[3]
                category = parts[4]
            } else profile = ""
            next
        }
        profile != "" {
            line = $0
            sub(/[[:space:]]*#.*/, "", line)
            if (line !~ /=/) next
            key = line
            sub(/[[:space:]]*=.*/, "", key)
            key = trim(key)
            sub(/^"/, "", key)
            sub(/"$/, "", key)
            value = line
            sub(/^[^=]*=[[:space:]]*/, "", value)
            value = trim(value)
            sub(/^"/, "", value)
            sub(/"$/, "", value)
            if (key != "") printf "%s\t%s\t%s\t%s\t%s\n", profile, provider, category, key, value
        }
    ' "$TOML_PATH"
}

ENTRY_TYPES=()
ENTRY_PROFILES=()
ENTRY_PROVIDERS=()
ENTRY_CATEGORIES=()
ENTRY_NAMES=()
ENTRY_VERSIONS=()
OS_PACKAGES=()
CASK_PACKAGES=()
FLATPAK_PACKAGES=()
MISE_SPECS=()
CONTAINER_PROFILES=()
CONTAINER_TYPES=()
CONTAINER_PROVIDERS=()
CONTAINER_CATEGORIES=()
CONTAINER_NAMES=()
CONTAINER_VERSIONS=()
CONTAINER_OS_PACKAGES=()
CONTAINER_CASK_PACKAGES=()
CONTAINER_FLATPAK_PACKAGES=()

load_entries() {
    local type profile provider category name version
    while IFS=$'\t' read -r type profile provider category name version; do
        [[ -n "$version" ]] || continue
        array_contains "$profile" "${REQUESTED_PROFILES[@]}" || continue
        ENTRY_TYPES+=("$type")
        ENTRY_PROFILES+=("$profile")
        ENTRY_PROVIDERS+=("$provider")
        ENTRY_CATEGORIES+=("$category")
        ENTRY_NAMES+=("$name")
        ENTRY_VERSIONS+=("$version")
    done < <(read_manifest_entries)

    if [[ ${#ENTRY_NAMES[@]} -eq 0 ]]; then
        printf '%s\n' 'No active package or Mise tool exists for the selected profiles.' >&2
        exit 1
    fi
}

load_container_entries() {
    local profile provider category name version
    while IFS=$'\t' read -r profile provider category name version; do
        [[ -n "$version" ]] || continue
        array_contains "$profile" "${REQUESTED_PROFILES[@]}" || continue
        CONTAINER_PROFILES+=("$profile")
        CONTAINER_TYPES+=("packages")
        CONTAINER_PROVIDERS+=("$provider")
        CONTAINER_CATEGORIES+=("$category")
        CONTAINER_NAMES+=("$name")
        CONTAINER_VERSIONS+=("$version")
    done < <(read_container_entries)

    if [[ ${#CONTAINER_NAMES[@]} -eq 0 ]]; then
        printf '%s\n' 'No active container runtime exists for the selected profiles.' >&2
        exit 1
    fi
}

build_install_groups() {
    OS_PACKAGES=()
    CASK_PACKAGES=()
    FLATPAK_PACKAGES=()
    MISE_SPECS=()
    local index type provider name version
    for index in "${!ENTRY_NAMES[@]}"; do
        type="${ENTRY_TYPES[index]}"
        provider="${ENTRY_PROVIDERS[index]}"
        name="${ENTRY_NAMES[index]}"
        version="${ENTRY_VERSIONS[index]}"
        if [[ "$WITH_PREFLIGHT" == true ]] && devrecipe_preflight_is_excluded "$type" "$provider" "$name" "$version"; then
            continue
        fi
        case "$type:$provider" in
            packages:os)
                array_contains "$name" "${OS_PACKAGES[@]}" || OS_PACKAGES+=("$name")
                ;;
            packages:cask)
                array_contains "$name" "${CASK_PACKAGES[@]}" || CASK_PACKAGES+=("$name")
                ;;
            packages:flatpak)
                array_contains "$name" "${FLATPAK_PACKAGES[@]}" || FLATPAK_PACKAGES+=("$name")
                ;;
            runtimes:mise|tools:mise)
                array_contains "$name@$version" "${MISE_SPECS[@]}" || MISE_SPECS+=("$name@$version")
                ;;
        esac
    done
}

build_container_install_groups() {
    CONTAINER_OS_PACKAGES=()
    CONTAINER_CASK_PACKAGES=()
    CONTAINER_FLATPAK_PACKAGES=()
    local index provider name version
    for index in "${!CONTAINER_NAMES[@]}"; do
        provider="${CONTAINER_PROVIDERS[index]}"
        name="${CONTAINER_NAMES[index]}"
        version="${CONTAINER_VERSIONS[index]}"
        if [[ "$WITH_PREFLIGHT" == true ]] && devrecipe_preflight_is_excluded "${CONTAINER_TYPES[index]}" "$provider" "$name" "$version"; then
            continue
        fi
        case "$provider" in
            os)
                array_contains "$name" "${CONTAINER_OS_PACKAGES[@]}" || CONTAINER_OS_PACKAGES+=("$name")
                ;;
            cask)
                array_contains "$name" "${CONTAINER_CASK_PACKAGES[@]}" || CONTAINER_CASK_PACKAGES+=("$name")
                ;;
            flatpak)
                array_contains "$name" "${CONTAINER_FLATPAK_PACKAGES[@]}" || CONTAINER_FLATPAK_PACKAGES+=("$name")
                ;;
        esac
    done
}

provider_label() {
    local type="$1"
    local provider="$2"
    case "$PLATFORM:$type:$provider" in
        macos:packages:os) printf '%s' 'Homebrew formula' ;;
        macos:packages:cask) printf '%s' 'Homebrew cask' ;;
        linux:packages:os) printf '%s' 'APT' ;;
        linux:packages:flatpak) printf '%s' 'Flatpak user' ;;
        *:runtimes:mise|*:tools:mise) printf '%s' 'Mise' ;;
        *) printf '%s' "$provider" ;;
    esac
}

inventory_contains_exact_id() {
    local inventory="$1"
    local package_id="$2"
    local listed_id
    while IFS= read -r listed_id || [[ -n "$listed_id" ]]; do
        [[ "$listed_id" == "$package_id" ]] && return 0
    done <<< "$inventory"
    return 1
}

MACOS_FORMULAS_STATE="unavailable"
MACOS_FORMULAS=""
MACOS_CASKS_STATE="unavailable"
MACOS_CASKS=""
LINUX_APT_STATE="unavailable"
LINUX_APT=""
LINUX_FLATPAK_STATE="unavailable"
LINUX_FLATPAK=""

collect_status_inventories() {
    case "$PLATFORM" in
        macos)
            if command -v brew >/dev/null 2>&1; then
                if MACOS_FORMULAS=$(brew list --formula 2>/dev/null); then MACOS_FORMULAS_STATE="ready"; fi
                if MACOS_CASKS=$(brew list --cask 2>/dev/null); then MACOS_CASKS_STATE="ready"; fi
            fi
            ;;
        linux)
            if command -v dpkg-query >/dev/null 2>&1; then
                if LINUX_APT=$(dpkg-query -W -f='${db:Status-Status}\t${binary:Package}\n' 2>/dev/null | awk -F '\t' '$1 == "installed" { print $2 }'); then
                    LINUX_APT_STATE="ready"
                fi
            fi
            if command -v flatpak >/dev/null 2>&1; then
                if LINUX_FLATPAK=$(flatpak list --user --app --columns=app 2>/dev/null); then LINUX_FLATPAK_STATE="ready"; fi
            fi
            ;;
    esac
}

mise_binary() {
    if command -v mise >/dev/null 2>&1; then
        command -v mise
    elif [[ -x "$HOME/.local/bin/mise" ]]; then
        printf '%s\n' "$HOME/.local/bin/mise"
    else
        return 1
    fi
}

mise_status() {
    local package_id="$1"
    local version="$2"
    local output mise_bin spec
    spec="$package_id@$version"
    if ! mise_bin="$(mise_binary)"; then
        printf '%s' 'unavailable'
    elif output=$("$mise_bin" ls --installed "$spec" 2>/dev/null); then
        if [[ -n "${output//[[:space:]]/}" ]]; then
            printf '%s' 'installed'
        else
            printf '%s' 'missing'
        fi
    else
        printf '%s' 'unavailable'
    fi
}

mise_preflight_status() {
    local package_id="$1"
    local output mise_bin
    if ! mise_bin="$(mise_binary)"; then
        printf '%s' 'unavailable'
    elif output=$("$mise_bin" ls --installed "$package_id" 2>/dev/null); then
        if [[ -n "${output//[[:space:]]/}" ]]; then
            printf '%s' 'installed'
        else
            printf '%s' 'missing'
        fi
    else
        printf '%s' 'unavailable'
    fi
}

status_for_entry() {
    local index="$1"
    local type="${ENTRY_TYPES[index]}"
    local provider="${ENTRY_PROVIDERS[index]}"
    local package_id="${ENTRY_NAMES[index]}"
    local version="${ENTRY_VERSIONS[index]}"

    case "$PLATFORM:$type:$provider" in
        macos:packages:os)
            [[ "$MACOS_FORMULAS_STATE" == ready ]] || { printf '%s' 'unavailable'; return; }
            inventory_contains_exact_id "$MACOS_FORMULAS" "$package_id" && printf '%s' 'installed' || printf '%s' 'missing'
            ;;
        macos:packages:cask)
            [[ "$MACOS_CASKS_STATE" == ready ]] || { printf '%s' 'unavailable'; return; }
            inventory_contains_exact_id "$MACOS_CASKS" "$package_id" && printf '%s' 'installed' || printf '%s' 'missing'
            ;;
        linux:packages:os)
            [[ "$LINUX_APT_STATE" == ready ]] || { printf '%s' 'unavailable'; return; }
            inventory_contains_exact_id "$LINUX_APT" "$package_id" && printf '%s' 'installed' || printf '%s' 'missing'
            ;;
        linux:packages:flatpak)
            [[ "$LINUX_FLATPAK_STATE" == ready ]] || { printf '%s' 'unavailable'; return; }
            inventory_contains_exact_id "$LINUX_FLATPAK" "$package_id" && printf '%s' 'installed' || printf '%s' 'missing'
            ;;
        *:runtimes:mise|*:tools:mise)
            mise_status "$package_id" "$version"
            ;;
        *)
            printf '%s' 'unavailable'
            ;;
    esac
}

show_list() {
    printf '\n--- DECLARED ENTRIES ---\n'
    printf '%-12s | %-18s | %-36s | %-10s\n' 'Profile' 'Provider' 'Identifier' 'Version'
    printf '%s\n' '--------------------------------------------------------------------------------------'
    local index provider
    for index in "${!ENTRY_NAMES[@]}"; do
        provider="$(provider_label "${ENTRY_TYPES[index]}" "${ENTRY_PROVIDERS[index]}")"
        printf '%-12s | %-18s | %-36s | %-10s\n' \
            "${ENTRY_PROFILES[index]}" "$provider" "${ENTRY_NAMES[index]}" "${ENTRY_VERSIONS[index]}"
    done
    printf '%s\n' 'This list comes only from the manifest; no provider was queried.'
}

show_status() {
    collect_status_inventories
    printf '\n--- DECLARED ENTRY STATUS ---\n'
    printf '%-12s | %-18s | %-36s | %-10s | %-12s\n' 'Profile' 'Provider' 'Identifier' 'Version' 'Status'
    printf '%s\n' '-------------------------------------------------------------------------------------------------------'
    local index provider state
    for index in "${!ENTRY_NAMES[@]}"; do
        provider="$(provider_label "${ENTRY_TYPES[index]}" "${ENTRY_PROVIDERS[index]}")"
        state="$(status_for_entry "$index")"
        printf '%-12s | %-18s | %-36s | %-10s | %-12s\n' \
            "${ENTRY_PROFILES[index]}" "$provider" "${ENTRY_NAMES[index]}" "${ENTRY_VERSIONS[index]}" "$state"
    done
    printf '%s\n' '“unavailable”: the provider inventory is not accessible.'
    printf '%s\n' 'A present ID proves only that its provider knows it, not that DevRecipe installed it.'
}

show_dry_run_plan() {
    local heading="${1:--- DRY-RUN PLAN (no changes) ---}"
    build_install_groups
    printf '\n%s\n' "$heading"
    case "$PLATFORM" in
        macos)
            printf '%s\n' 'Homebrew: if brew is absent, run its official remote installer through curl and /bin/bash.'
            if [[ ${#OS_PACKAGES[@]} -gt 0 ]]; then
                printf 'Homebrew : brew install'; printf ' %q' "${OS_PACKAGES[@]}"; printf '\n'
            fi
            if [[ ${#CASK_PACKAGES[@]} -gt 0 ]]; then
                printf 'Homebrew : brew install --cask'; printf ' %q' "${CASK_PACKAGES[@]}"; printf '\n'
            fi
            ;;
        linux)
            if [[ ${#OS_PACKAGES[@]} -gt 0 || ${#FLATPAK_PACKAGES[@]} -gt 0 ]]; then
                printf '%s\n' 'APT: run sudo apt update before required APT installations.'
            fi
            if [[ ${#OS_PACKAGES[@]} -gt 0 ]]; then
                printf 'APT : sudo apt install -y'; printf ' %q' "${OS_PACKAGES[@]}"; printf '\n'
            fi
            if [[ ${#FLATPAK_PACKAGES[@]} -gt 0 ]]; then
                printf '%s\n' 'APT: install flatpak if the command is absent.'
                printf '%s\n' 'Flatpak: add the Flathub user remote if absent.'
                printf 'Flatpak : flatpak install --user -y flathub'; printf ' %q' "${FLATPAK_PACKAGES[@]}"; printf '\n'
            fi
            if array_contains 'claude-desktop' "${OS_PACKAGES[@]}"; then
                printf '%s\n' 'Claude Desktop: if its APT source is absent, download the Anthropic key and create the signed APT source.'
            fi
            ;;
    esac
    if [[ ${#MISE_SPECS[@]} -gt 0 ]]; then
        if [[ "$PLATFORM" == macos ]]; then
            printf '%s\n' 'Homebrew: install mise if the command is absent.'
        else
            printf '%s\n' 'Mise: if absent, run the remote bootstrap `curl https://mise.run | sh`.'
            printf '%s\n' 'APT: install curl if required by the Mise bootstrap.'
        fi
        printf 'Mise : mise install'; printf ' %q' "${MISE_SPECS[@]}"; printf '\n'
        printf '%s\n' 'Mise: installs without changing ~/.config/mise/config.toml or activating versions globally.'
    fi
}

show_container_dry_run_plan() {
    local heading="${1:--- CONTAINER DRY-RUN PLAN (no changes) ---}"
    build_container_install_groups
    printf '\n%s\n' "$heading"
    case "$PLATFORM" in
        macos)
            printf '%s\n' 'Homebrew: if brew is absent, run its official remote installer through curl and /bin/bash.'
            if [[ ${#CONTAINER_OS_PACKAGES[@]} -gt 0 ]]; then
                printf 'Homebrew : brew install'; printf ' %q' "${CONTAINER_OS_PACKAGES[@]}"; printf '\n'
            fi
            if [[ ${#CONTAINER_CASK_PACKAGES[@]} -gt 0 ]]; then
                printf 'Homebrew : brew install --cask'; printf ' %q' "${CONTAINER_CASK_PACKAGES[@]}"; printf '\n'
            fi
            if array_contains podman "${CONTAINER_OS_PACKAGES[@]}"; then
                printf '%s\n' 'Podman: if no machine exists, run `podman machine init --now`.'
            fi
            ;;
        linux)
            if [[ ${#CONTAINER_OS_PACKAGES[@]} -gt 0 || ${#CONTAINER_FLATPAK_PACKAGES[@]} -gt 0 ]]; then
                printf '%s\n' 'APT: run sudo apt update before required installations.'
            fi
            if [[ ${#CONTAINER_OS_PACKAGES[@]} -gt 0 ]]; then
                printf 'APT : sudo apt install -y'; printf ' %q' "${CONTAINER_OS_PACKAGES[@]}"; printf '\n'
            fi
            if [[ ${#CONTAINER_FLATPAK_PACKAGES[@]} -gt 0 ]]; then
                printf '%s\n' 'APT: install flatpak if the command is absent.'
                printf '%s\n' 'Flatpak: add the Flathub user remote if absent.'
                printf 'Flatpak : flatpak install --user -y flathub'; printf ' %q' "${CONTAINER_FLATPAK_PACKAGES[@]}"; printf '\n'
            fi
            ;;
    esac
    case "$PLATFORM" in
        macos) printf '%s\n' 'macOS Podman creates a machine only if no existing machine is detected.' ;;
        linux) printf '%s\n' 'Linux Podman remains rootless and creates no machine, service, or global configuration.' ;;
    esac
}

APT_UPDATED=false
apt_update_once() {
    [[ "$APT_UPDATED" == true ]] && return
    devrecipe_review_operation 'sudo apt update' 'elevated' 'APT package index' 'refresh the privileged APT package index'
    sudo apt update
    APT_UPDATED=true
}

configure_claude_desktop_repository() {
    local keyring_path="/usr/share/keyrings/claude-desktop-archive-keyring.asc"
    local source_path="/etc/apt/sources.list.d/claude-desktop.list"
    local source_line="deb [signed-by=${keyring_path}] https://downloads.claude.ai/claude-desktop/apt/stable stable main"

    if [[ -e "$source_path" || -L "$source_path" ]]; then
        printf 'Existing Anthropic repository preserved: %s\n' "$source_path"
        return 0
    fi
    if [[ -L "$keyring_path" || ( -e "$keyring_path" && ! -f "$keyring_path" ) ]]; then
        printf 'Anthropic repository: non-regular key path preserved: %s\n' "$keyring_path" >&2
        return 1
    fi

    devrecipe_review_operation 'sudo install -d -m 0755 /usr/share/keyrings' 'elevated' '/usr/share/keyrings' 'create the package-signing key directory'
    sudo install -d -m 0755 /usr/share/keyrings
    if [[ ! -e "$keyring_path" ]]; then
        devrecipe_review_operation "sudo curl -fsSLo $keyring_path https://downloads.claude.ai/claude-desktop/key.asc" 'elevated' 'https://downloads.claude.ai/claude-desktop/key.asc' 'download the Anthropic package signing key'
        sudo curl -fsSLo "$keyring_path" https://downloads.claude.ai/claude-desktop/key.asc
    fi
    devrecipe_review_operation "sudo tee $source_path" 'elevated' "$source_path" 'create the signed Anthropic APT source'
    printf '%s\n' "$source_line" | sudo tee "$source_path" >/dev/null
    apt_update_once
}

ensure_homebrew() {
    if ! command -v brew >/dev/null 2>&1; then
        devrecipe_review_operation 'curl Homebrew installer | /bin/bash' 'user; installer may request elevation' 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh' 'bootstrap Homebrew'
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    command -v brew >/dev/null 2>&1 || { printf '%s\n' 'Homebrew was not found after installation.' >&2; exit 1; }
}

run_macos_install() {
    local mise_bin
    ensure_homebrew
    if [[ ${#OS_PACKAGES[@]} -gt 0 ]]; then
        devrecipe_review_operation "brew install ${OS_PACKAGES[*]}" 'user' 'Homebrew formulae' 'install selected formula raw IDs'
        brew install "${OS_PACKAGES[@]}"
    fi
    if [[ ${#CASK_PACKAGES[@]} -gt 0 ]]; then
        devrecipe_review_operation "brew install --cask ${CASK_PACKAGES[*]}" 'user' 'Homebrew casks' 'install selected cask raw IDs'
        brew install --cask "${CASK_PACKAGES[@]}"
    fi
    if [[ ${#MISE_SPECS[@]} -gt 0 ]]; then
        if ! mise_bin="$(mise_binary)"; then
            devrecipe_review_operation 'brew install mise' 'user' 'Homebrew formula mise' 'install the Mise provider'
            brew install mise
        fi
        mise_bin="$(mise_binary)" || { printf '%s\n' 'Mise was not found after installation.' >&2; exit 1; }
        devrecipe_review_operation "mise install ${MISE_SPECS[*]}" 'user' 'Mise runtime store' 'install selected exact Mise specs'
        "$mise_bin" install "${MISE_SPECS[@]}"
    fi
}

run_linux_install() {
    local apt_packages=("${OS_PACKAGES[@]}")
    local initial_apt_packages=()
    local claude_packages=()
    local package has_claude=false mise_bin
    array_contains 'claude-desktop' "${OS_PACKAGES[@]}" && has_claude=true

    if [[ ${#FLATPAK_PACKAGES[@]} -gt 0 ]] && ! command -v flatpak >/dev/null 2>&1; then
        array_contains flatpak "${apt_packages[@]}" || apt_packages+=(flatpak)
    fi
    if [[ ${#MISE_SPECS[@]} -gt 0 ]] && ! mise_bin="$(mise_binary)" && ! command -v curl >/dev/null 2>&1; then
        array_contains curl "${apt_packages[@]}" || apt_packages+=(curl)
    fi
    if [[ "$has_claude" == true ]] && ! command -v curl >/dev/null 2>&1; then
        array_contains curl "${apt_packages[@]}" || apt_packages+=(curl)
    fi

    for package in "${apt_packages[@]}"; do
        if [[ "$package" == claude-desktop ]]; then
            claude_packages+=("$package")
        else
            initial_apt_packages+=("$package")
        fi
    done

    if [[ ${#initial_apt_packages[@]} -gt 0 || ${#claude_packages[@]} -gt 0 ]]; then
        command -v apt >/dev/null 2>&1 || { printf '%s\n' 'This recipe requires an APT-based distribution.' >&2; exit 1; }
    fi
    if [[ ${#initial_apt_packages[@]} -gt 0 ]]; then
        apt_update_once
        devrecipe_review_operation "sudo apt install -y ${initial_apt_packages[*]}" 'elevated' 'APT packages' 'install selected APT raw IDs'
        sudo apt install -y "${initial_apt_packages[@]}"
    fi
    if [[ ${#claude_packages[@]} -gt 0 ]]; then
        if ! command -v curl >/dev/null 2>&1; then
            apt_update_once
            devrecipe_review_operation 'sudo apt install -y curl' 'elevated' 'APT package curl' 'install bootstrap prerequisite'
            sudo apt install -y curl
        fi
        configure_claude_desktop_repository
        devrecipe_review_operation "sudo apt install -y ${claude_packages[*]}" 'elevated' 'APT packages' 'install selected Claude Desktop raw ID'
        sudo apt install -y "${claude_packages[@]}"
    fi
    if [[ ${#FLATPAK_PACKAGES[@]} -gt 0 ]]; then
        command -v flatpak >/dev/null 2>&1 || { printf '%s\n' 'Flatpak was not found after installation.' >&2; exit 1; }
        devrecipe_review_operation 'flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo' 'user' 'Flathub user remote' 'add the selected Flatpak remote if absent'
        flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        devrecipe_review_operation "flatpak install --user -y flathub ${FLATPAK_PACKAGES[*]}" 'user' 'Flathub user remote' 'install selected Flatpak raw IDs'
        flatpak install --user -y flathub "${FLATPAK_PACKAGES[@]}"
    fi
    if [[ ${#MISE_SPECS[@]} -gt 0 ]]; then
        if ! mise_bin="$(mise_binary)"; then
            command -v curl >/dev/null 2>&1 || { printf '%s\n' 'curl is required to install Mise.' >&2; exit 1; }
            devrecipe_review_operation 'curl https://mise.run | sh' 'user' 'https://mise.run' 'bootstrap Mise'
            curl https://mise.run | sh
        fi
        mise_bin="$(mise_binary)" || { printf '%s\n' 'Mise was not found after installation.' >&2; exit 1; }
        devrecipe_review_operation "mise install ${MISE_SPECS[*]}" 'user' 'Mise runtime store' 'install selected exact Mise specs'
        "$mise_bin" install "${MISE_SPECS[@]}"
    fi
}

initialize_macos_podman_machine() {
    local podman_bin machines
    podman_bin="$(command -v podman 2>/dev/null || true)"
    [[ -n "$podman_bin" ]] || { printf '%s\n' 'Podman was not found after installation.' >&2; return 1; }
    if ! machines="$("$podman_bin" machine list --format '{{.Name}}' 2>/dev/null)"; then
        printf '%s\n' 'Podman machine inventory is unavailable; no machine was created.' >&2
        return 1
    fi
    if [[ -n "${machines//[[:space:]]/}" ]]; then
        printf 'Existing Podman machine preserved: %s\n' "${machines//$'\n'/, }"
        return 0
    fi
    devrecipe_review_operation 'podman machine init --now' 'user' 'Podman machine' 'create and start a new Podman machine'
    "$podman_bin" machine init --now
}

run_macos_containers() {
    ensure_homebrew
    if [[ ${#CONTAINER_OS_PACKAGES[@]} -gt 0 ]]; then
        devrecipe_review_operation "brew install ${CONTAINER_OS_PACKAGES[*]}" 'user' 'Homebrew formulae' 'install selected container raw IDs'
        brew install "${CONTAINER_OS_PACKAGES[@]}"
    fi
    if [[ ${#CONTAINER_CASK_PACKAGES[@]} -gt 0 ]]; then
        devrecipe_review_operation "brew install --cask ${CONTAINER_CASK_PACKAGES[*]}" 'user' 'Homebrew casks' 'install selected container raw IDs'
        brew install --cask "${CONTAINER_CASK_PACKAGES[@]}"
    fi
    if array_contains podman "${CONTAINER_OS_PACKAGES[@]}"; then
        initialize_macos_podman_machine
    fi
}

run_linux_containers() {
    local apt_packages=("${CONTAINER_OS_PACKAGES[@]}")
    if [[ ${#CONTAINER_FLATPAK_PACKAGES[@]} -gt 0 ]] && ! command -v flatpak >/dev/null 2>&1; then
        array_contains flatpak "${apt_packages[@]}" || apt_packages+=(flatpak)
    fi
    if [[ ${#apt_packages[@]} -gt 0 ]]; then
        command -v apt >/dev/null 2>&1 || { printf '%s\n' 'This container recipe requires an APT-based distribution.' >&2; exit 1; }
        apt_update_once
        devrecipe_review_operation "sudo apt install -y ${apt_packages[*]}" 'elevated' 'APT packages' 'install selected container raw IDs'
        sudo apt install -y "${apt_packages[@]}"
    fi
    if [[ ${#CONTAINER_FLATPAK_PACKAGES[@]} -gt 0 ]]; then
        command -v flatpak >/dev/null 2>&1 || { printf '%s\n' 'Flatpak was not found after installation.' >&2; exit 1; }
        devrecipe_review_operation 'flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo' 'user' 'Flathub user remote' 'add the selected Flatpak remote if absent'
        flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        devrecipe_review_operation "flatpak install --user -y flathub ${CONTAINER_FLATPAK_PACKAGES[*]}" 'user' 'Flathub user remote' 'install selected container raw IDs'
        flatpak install --user -y flathub "${CONTAINER_FLATPAK_PACKAGES[@]}"
    fi
    printf '%s\n' 'Linux Podman runtime installed without creating a machine, service, or global configuration.'
}

REMOVE_TYPES=()
REMOVE_PROVIDERS=()
REMOVE_NAMES=()
REMOVE_VERSIONS=()

build_remove_plan() {
    local requested_id index matches match_index
    REMOVE_TYPES=()
    REMOVE_PROVIDERS=()
    REMOVE_NAMES=()
    REMOVE_VERSIONS=()
    for requested_id in "${UNINSTALL_IDS[@]}"; do
        matches=0
        match_index=-1
        for index in "${!ENTRY_NAMES[@]}"; do
            [[ "${ENTRY_NAMES[index]}" == "$requested_id" ]] || continue
            matches=$((matches + 1))
            match_index="$index"
        done
        if [[ "$matches" -eq 0 ]]; then
            printf 'Removal refused: `%s` is not declared in the selected profiles.\n' "$requested_id" >&2
            return 1
        fi
        if [[ "$matches" -gt 1 ]]; then
            printf 'Removal refused: `%s` is declared more than once; select a more specific profile.\n' "$requested_id" >&2
            return 1
        fi
        REMOVE_TYPES+=("${ENTRY_TYPES[match_index]}")
        REMOVE_PROVIDERS+=("${ENTRY_PROVIDERS[match_index]}")
        REMOVE_NAMES+=("${ENTRY_NAMES[match_index]}")
        REMOVE_VERSIONS+=("${ENTRY_VERSIONS[match_index]}")
    done
}

show_remove_plan() {
    printf '\n--- REMOVAL PLAN ---\n'
    printf '%-18s | %-36s | %-10s\n' 'Provider' 'Identifier' 'Version'
    printf '%s\n' '--------------------------------------------------------------------------'
    local index
    for index in "${!REMOVE_NAMES[@]}"; do
        printf '%-18s | %-36s | %-10s\n' \
            "$(provider_label "${REMOVE_TYPES[index]}" "${REMOVE_PROVIDERS[index]}")" "${REMOVE_NAMES[index]}" "${REMOVE_VERSIONS[index]}"
    done
    if [[ "$CONFIRM_UNINSTALL" != true ]]; then
        printf '%s\n' 'Plan only. Add --yes to execute these exact removals.'
    fi
    printf '%s\n' 'A present ID does not prove DevRecipe installed it: this action can remove a declared ID installed by someone else.'
    printf '%s\n' 'No configuration, provider bootstrap, remote, repository, container, OS feature, automatic dependency, or autoremove operation is removed.'
}

require_removal_presence() {
    local type="$1"
    local provider="$2"
    local name="$3"
    local version="$4"
    local inventory output mise_bin spec

    case "$PLATFORM:$type:$provider" in
        macos:packages:os)
            command -v brew >/dev/null 2>&1 || { printf '%s\n' 'Homebrew is required for this removal.' >&2; return 1; }
            inventory="$(brew list --formula 2>/dev/null)" || { printf 'Homebrew inventory is unavailable for `%s`.\n' "$name" >&2; return 1; }
            ;;
        macos:packages:cask)
            command -v brew >/dev/null 2>&1 || { printf '%s\n' 'Homebrew is required for this removal.' >&2; return 1; }
            inventory="$(brew list --cask 2>/dev/null)" || { printf 'Homebrew inventory is unavailable for `%s`.\n' "$name" >&2; return 1; }
            ;;
        linux:packages:os)
            command -v dpkg-query >/dev/null 2>&1 || { printf '%s\n' 'dpkg-query is required for this APT removal.' >&2; return 1; }
            inventory="$(dpkg-query -W -f='${db:Status-Status}\t${binary:Package}\n' 2>/dev/null | awk -F '\t' '$1 == "installed" { print $2 }')" || { printf 'APT inventory is unavailable for `%s`.\n' "$name" >&2; return 1; }
            ;;
        linux:packages:flatpak)
            command -v flatpak >/dev/null 2>&1 || { printf '%s\n' 'Flatpak is required for this removal.' >&2; return 1; }
            inventory="$(flatpak list --user --app --columns=app 2>/dev/null)" || { printf 'Flatpak inventory is unavailable for `%s`.\n' "$name" >&2; return 1; }
            ;;
        *:runtimes:mise|*:tools:mise)
            mise_bin="$(mise_binary)" || { printf 'Mise is required to remove `%s`.\n' "$name" >&2; return 1; }
            spec="$name@$version"
            output="$("$mise_bin" ls --installed "$spec" 2>/dev/null)" || { printf 'Mise inventory is unavailable for `%s`.\n' "$spec" >&2; return 1; }
            [[ -n "${output//[[:space:]]/}" ]] || { printf 'Mise does not list `%s`; no removal.\n' "$spec" >&2; return 1; }
            return 0
            ;;
        *)
            printf 'Unsupported removal: %s:%s\n' "$type" "$provider" >&2
            return 1
            ;;
    esac

    if ! inventory_contains_exact_id "$inventory" "$name"; then
        printf 'The selected provider does not list `%s`; no removal.\n' "$name" >&2
        return 1
    fi
}

run_remove_plan() {
    local index type provider name version mise_bin
    for index in "${!REMOVE_NAMES[@]}"; do
        type="${REMOVE_TYPES[index]}"
        provider="${REMOVE_PROVIDERS[index]}"
        name="${REMOVE_NAMES[index]}"
        version="${REMOVE_VERSIONS[index]}"
        require_removal_presence "$type" "$provider" "$name" "$version"
    done
    for index in "${!REMOVE_NAMES[@]}"; do
        type="${REMOVE_TYPES[index]}"
        provider="${REMOVE_PROVIDERS[index]}"
        name="${REMOVE_NAMES[index]}"
        version="${REMOVE_VERSIONS[index]}"
        case "$type:$provider" in
            runtimes:mise|tools:mise)
                mise_bin="$(mise_binary)"
                devrecipe_review_operation "mise uninstall $name@$version" 'user' 'Mise runtime store' 'remove the exact declared Mise spec'
                "$mise_bin" uninstall "$name@$version"
                ;;
        esac
    done
    for index in "${!REMOVE_NAMES[@]}"; do
        type="${REMOVE_TYPES[index]}"
        provider="${REMOVE_PROVIDERS[index]}"
        name="${REMOVE_NAMES[index]}"
        version="${REMOVE_VERSIONS[index]}"
        case "$PLATFORM:$type:$provider" in
            *:runtimes:mise|*:tools:mise) ;;
            macos:packages:os) devrecipe_review_operation "brew uninstall $name" 'user' 'Homebrew formula' 'remove the exact declared raw ID'; brew uninstall "$name" ;;
            macos:packages:cask) devrecipe_review_operation "brew uninstall --cask $name" 'user' 'Homebrew cask' 'remove the exact declared raw ID'; brew uninstall --cask "$name" ;;
            linux:packages:os) devrecipe_review_operation "sudo apt remove -y $name" 'elevated' 'APT package' 'remove the exact declared raw ID'; sudo apt remove -y "$name" ;;
            linux:packages:flatpak) devrecipe_review_operation "flatpak uninstall --user --no-related --keep-ref -y $name" 'user' 'Flatpak user application' 'remove the exact declared raw ID'; flatpak uninstall --user --no-related --keep-ref -y "$name" ;;
            *)
                printf 'Unsupported removal: %s:%s\n' "$type" "$provider" >&2
                exit 2
                ;;
        esac
    done
}

show_summary() {
    printf '\n--- SUBMITTED ENTRIES ---\n'
    printf '%-12s | %-18s | %-36s\n' 'Profile' 'Provider' 'Identifier'
    printf '%s\n' '----------------------------------------------------------------------------'
    local index
    for index in "${!ENTRY_NAMES[@]}"; do
        printf '%-12s | %-18s | %-36s\n' \
            "${ENTRY_PROFILES[index]}" \
            "$(provider_label "${ENTRY_TYPES[index]}" "${ENTRY_PROVIDERS[index]}")" \
            "${ENTRY_NAMES[index]}"
    done
    printf '%s\n' 'Use --status to compare this list with provider inventories.'
}

# Begin embedded preflight and review helpers.
DEVRECIPE_PREFLIGHT_THRESHOLD=90
DEVRECIPE_PREFLIGHT_MAX_EVIDENCE=3
DEVRECIPE_PREFLIGHT_EXCLUDED_IDS=()
DEVRECIPE_PREFLIGHT_EVIDENCE=()
DEVRECIPE_PREFLIGHT_ENTRY_HAS_EVIDENCE=false
DEVRECIPE_PREFLIGHT_CACHE_SOURCES=()
DEVRECIPE_PREFLIGHT_CACHE_SCOPES=()
DEVRECIPE_PREFLIGHT_CACHE_FILES=()
DEVRECIPE_PREFLIGHT_CACHE_DIR=''
DEVRECIPE_PREFLIGHT_APPROVE_ALL=false
DEVRECIPE_PREFLIGHT_DECLINE_ALL=false
DEVRECIPE_PREFLIGHT_NATIVE_SELECTED=()
DEVRECIPE_PREFLIGHT_NATIVE_CANCELLED=false
DEVRECIPE_REVIEW_ACTION_NUMBER=0
DEVRECIPE_REVIEW_APPROVED=()
DEVRECIPE_REVIEW_COMPLETED=()
DEVRECIPE_REVIEW_REJECTED=()
DEVRECIPE_REVIEW_UNREVIEWED=()
DEVRECIPE_REVIEW_PENDING=''

devrecipe_review_report() {
    [[ "${WITH_REVIEW:-false}" == true ]] || return 0
    printf '\n--- REVIEW REPORT ---\n'
    printf 'approved: %s\n' "${#DEVRECIPE_REVIEW_APPROVED[@]}"
    printf 'completed: %s\n' "${#DEVRECIPE_REVIEW_COMPLETED[@]}"
    printf 'rejected: %s\n' "${#DEVRECIPE_REVIEW_REJECTED[@]}"
    printf 'unreviewed: %s\n' "${#DEVRECIPE_REVIEW_UNREVIEWED[@]}"
    if [[ ${#DEVRECIPE_REVIEW_UNREVIEWED[@]} -gt 0 ]]; then
        printf 'unreviewed detail: %s\n' "${DEVRECIPE_REVIEW_UNREVIEWED[*]}"
    fi
}

devrecipe_review_finish() {
    [[ "${WITH_REVIEW:-false}" == true ]] || return 0
    if [[ -n "$DEVRECIPE_REVIEW_PENDING" ]]; then
        DEVRECIPE_REVIEW_COMPLETED+=("$DEVRECIPE_REVIEW_PENDING")
        DEVRECIPE_REVIEW_PENDING=''
    fi
    devrecipe_review_report
}

devrecipe_review_operation() {
    local command="$1"
    local privilege="$2"
    local source="$3"
    local effect="$4"
    local answer

    [[ "${WITH_REVIEW:-false}" == true ]] || return 0
    if [[ -n "$DEVRECIPE_REVIEW_PENDING" ]]; then
        DEVRECIPE_REVIEW_COMPLETED+=("$DEVRECIPE_REVIEW_PENDING")
        DEVRECIPE_REVIEW_PENDING=''
    fi
    if [[ ! -t 0 || ! -t 1 ]]; then
        DEVRECIPE_REVIEW_UNREVIEWED+=("$command")
        printf 'Review requires an interactive TTY; action remains unreviewed: %s\n' "$command" >&2
        devrecipe_review_report >&2
        return 3
    fi
    DEVRECIPE_REVIEW_ACTION_NUMBER=$((DEVRECIPE_REVIEW_ACTION_NUMBER + 1))
    printf '\n--- REVIEW ACTION %s ---\ncommand: %s\nprivilege: %s\nsource/target: %s\neffect: %s\n' "$DEVRECIPE_REVIEW_ACTION_NUMBER" "$command" "$privilege" "$source" "$effect"
    printf 'Approve this exact action? [y/N]: '
    if ! IFS= read -r answer; then
        DEVRECIPE_REVIEW_UNREVIEWED+=("$command")
        printf '\nReview input closed; action remains unreviewed.\n' >&2
        devrecipe_review_report >&2
        return 3
    fi
    case "$answer" in
        y|Y|yes|Yes|YES)
            DEVRECIPE_REVIEW_APPROVED+=("$DEVRECIPE_REVIEW_ACTION_NUMBER:$command")
            DEVRECIPE_REVIEW_PENDING="$DEVRECIPE_REVIEW_ACTION_NUMBER:$command"
            return 0
            ;;
        *)
            DEVRECIPE_REVIEW_REJECTED+=("$DEVRECIPE_REVIEW_ACTION_NUMBER:$command")
            DEVRECIPE_REVIEW_UNREVIEWED+=("actions after rejected checkpoint $DEVRECIPE_REVIEW_ACTION_NUMBER")
            printf 'Review rejected action %s; remaining actions are unreviewed.\n' "$DEVRECIPE_REVIEW_ACTION_NUMBER" >&2
            devrecipe_review_report >&2
            return 3
            ;;
    esac
}

# Compare only case-folded raw strings. No aliases or identifier rewriting occur.
devrecipe_preflight_score() {
    local query="$1"
    local evidence="$2"

    awk -v query="$query" -v evidence="$evidence" '
        BEGIN {
            query = tolower(query)
            evidence = tolower(evidence)
            query_length = length(query)
            evidence_length = length(evidence)
            if (query == evidence) {
                print 100
                exit
            }
            if (query_length == 0 || evidence_length == 0) {
                print 0
                exit
            }
            for (row = 0; row <= query_length; row++) distance[row, 0] = row
            for (column = 0; column <= evidence_length; column++) distance[0, column] = column
            for (row = 1; row <= query_length; row++) {
                query_character = substr(query, row, 1)
                for (column = 1; column <= evidence_length; column++) {
                    evidence_character = substr(evidence, column, 1)
                    substitution = distance[row - 1, column - 1] + (query_character == evidence_character ? 0 : 1)
                    deletion = distance[row - 1, column] + 1
                    insertion = distance[row, column - 1] + 1
                    best = substitution
                    if (deletion < best) best = deletion
                    if (insertion < best) best = insertion
                    distance[row, column] = best
                }
            }
            maximum = query_length > evidence_length ? query_length : evidence_length
            print int((1 - distance[query_length, evidence_length] / maximum) * 100 + 0.5)
        }
    '
}

devrecipe_preflight_separator_prefix_match() {
    local query="$1"
    local evidence="$2"

    awk -v query="$query" -v evidence="$evidence" '
        BEGIN {
            query = tolower(query)
            evidence = tolower(evidence)
            token_count = split(query, tokens, /[^[:alnum:]]+/)
            position = 1
            for (token_index = 1; token_index <= token_count; token_index++) {
                token = tokens[token_index]
                if (token == "") continue
                if (substr(evidence, position, length(token)) != token) exit 1
                position += length(token)
                while (token_index < token_count && position <= length(evidence) && substr(evidence, position, 1) !~ /[[:alnum:]]/) position++
            }
            if (position > length(evidence) || substr(evidence, position, 1) !~ /[[:alnum:]]/) exit 0
            exit 1
        }
    '
}

devrecipe_preflight_action_key() {
    printf '%s|%s|%s|%s' "$1" "$2" "$3" "$4"
}

devrecipe_preflight_is_excluded() {
    local type="$1"
    local provider="$2"
    local name="$3"
    local version="$4"
    local candidate
    candidate="$(devrecipe_preflight_action_key "$type" "$provider" "$name" "$version")"
    array_contains "$candidate" "${DEVRECIPE_PREFLIGHT_EXCLUDED_IDS[@]}"
}

devrecipe_preflight_evidence_rank() {
    case "$1" in
        selected-provider-inventory*) printf '%s' 1 ;;
        os-installation-record*|os-registration*) printf '%s' 2 ;;
        os-application-location*|os-installation-location*|os-launcher-record*|os-desktop-entry-metadata*) printf '%s' 3 ;;
        *) printf '%s' 4 ;;
    esac
}

devrecipe_preflight_begin_entry() {
    DEVRECIPE_PREFLIGHT_EVIDENCE=()
    DEVRECIPE_PREFLIGHT_ENTRY_HAS_EVIDENCE=false
}

devrecipe_preflight_flush_evidence() {
    local record
    [[ ${#DEVRECIPE_PREFLIGHT_EVIDENCE[@]} -gt 0 ]] || return 1
    while IFS= read -r record; do
        printf '%s\n' "$record"
    done < <(printf '%s\n' "${DEVRECIPE_PREFLIGHT_EVIDENCE[@]}" | sort -t '|' -k1,1n -k2,2nr -k3,3 -k4,4 | head -n "$DEVRECIPE_PREFLIGHT_MAX_EVIDENCE" | cut -d '|' -f5-)
    return 0
}

devrecipe_preflight_record() {
    local query="$1"
    local source="$2"
    local scope="$3"
    local location="$4"
    local value="$5"
    local score reason

    score="$(devrecipe_preflight_score "$query" "$value")"
    if [[ "$score" -eq 100 ]]; then
        reason='case-insensitive exact match'
    elif [[ "$score" -ge "$DEVRECIPE_PREFLIGHT_THRESHOLD" ]]; then
        reason='case-insensitive similarity at or above threshold'
    elif devrecipe_preflight_separator_prefix_match "$query" "$value"; then
        score=100
        reason='generated separator-flexible prefix match'
    else
        return 1
    fi
    DEVRECIPE_PREFLIGHT_EVIDENCE+=("$(devrecipe_preflight_evidence_rank "$source")|$score|$source|$location|  evidence | query=$(printf '%q' "$query") | source=$source | scope=$scope | location=$location | matched=$(printf '%q' "$value") | reason=$reason | similarity=$score/100 | threshold=$DEVRECIPE_PREFLIGHT_THRESHOLD/100")
    DEVRECIPE_PREFLIGHT_ENTRY_HAS_EVIDENCE=true
    return 0
}

devrecipe_preflight_incomplete() {
    local query="$1"
    local source="$2"
    local scope="$3"
    local reason="$4"

    printf '  incomplete | query=%q | source=%s | scope=%s | reason=%s\n' "$query" "$source" "$scope" "$reason"
}

devrecipe_preflight_redact_location() {
    local location="$1"
    location="${location#$HOME}"
    if [[ "$location" != "$1" ]]; then
        printf '<home>%s' "$location"
    else
        printf '%s' "$location"
    fi
}

devrecipe_preflight_collect_root() {
    local root="$1"
    local output="$2"
    shift 2
    local -a prefixes=("$@")
    local -a command=(find -P "$root" -xdev -maxdepth 2 \( -type d -o -type f \) \()
    local prefix index

    [[ -d "$root" && -r "$root" && -x "$root" ]] || return 1
    for index in "${!prefixes[@]}"; do
        prefix="${prefixes[index]}"
        command+=( -iname "$prefix*" )
        [[ "$index" -eq $((${#prefixes[@]} - 1)) ]] || command+=( -o )
    done
    command+=( \) -print )
    "${command[@]}" >"$output" 2>/dev/null
}

devrecipe_preflight_prepare_metadata_cache() {
    local -a queries=("$@") prefixes=() roots=() sources=() scopes=() pids=()
    local query prefix index cache_dir status_file

    [[ ${#DEVRECIPE_PREFLIGHT_CACHE_FILES[@]} -eq 0 ]] || return 0
    for query in "${queries[@]}"; do
        prefix="${query:0:1}"
        [[ -n "$prefix" ]] && array_contains "$prefix" "${prefixes[@]}" || prefixes+=("$prefix")
    done
    [[ ${#prefixes[@]} -gt 0 ]] || return 0
    case "$PLATFORM" in
        macos)
            roots=(/Applications "$HOME/Applications" "$HOME/Library/Application Support" "$HOME/Library/LaunchAgents" "$HOME/Library/Preferences")
            sources=(os-application-location os-application-location user-application-metadata user-launch-agent-metadata user-shortcut-metadata)
            scopes=(machine user user user user)
            ;;
        linux)
            roots=(/usr/share/applications /opt /usr/local "${XDG_DATA_HOME:-$HOME/.local/share}/applications" "${XDG_DATA_HOME:-$HOME/.local/share}" "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user" "${XDG_CONFIG_HOME:-$HOME/.config}")
            sources=(os-desktop-entry-metadata os-installation-location os-installation-location user-desktop-entry-metadata user-application-metadata user-service-metadata user-configuration-metadata)
            scopes=(machine machine machine user user user user)
            ;;
        *) return 0 ;;
    esac
    cache_dir="$(mktemp -d "${TMPDIR:-/tmp}/devrecipe-preflight.XXXXXX")" || return 0
    DEVRECIPE_PREFLIGHT_CACHE_DIR="$cache_dir"
    for index in "${!roots[@]}"; do
        devrecipe_preflight_collect_root "${roots[index]}" "$cache_dir/$index" "${prefixes[@]}" &
        pids+=("$!")
    done
    for index in "${!roots[@]}"; do
        status_file="$cache_dir/$index.status"
        if ! wait "${pids[index]}"; then
            : >"$cache_dir/$index"
            printf '%s\n' 'root inaccessible or partial scan' >"$status_file"
        fi
        DEVRECIPE_PREFLIGHT_CACHE_SOURCES+=("${sources[index]}")
        DEVRECIPE_PREFLIGHT_CACHE_SCOPES+=("${scopes[index]}")
        DEVRECIPE_PREFLIGHT_CACHE_FILES+=("$cache_dir/$index")
    done
}

devrecipe_preflight_cached_metadata_matches() {
    local query="$1"
    local index path location found=false count status_file
    for index in "${!DEVRECIPE_PREFLIGHT_CACHE_FILES[@]}"; do
        status_file="${DEVRECIPE_PREFLIGHT_CACHE_FILES[index]}.status"
        if [[ -s "$status_file" ]]; then
            devrecipe_preflight_incomplete "$query" "${DEVRECIPE_PREFLIGHT_CACHE_SOURCES[index]}" "${DEVRECIPE_PREFLIGHT_CACHE_SCOPES[index]}" "$(<"$status_file")"
        fi
        count=0
        while IFS= read -r path || [[ -n "$path" ]]; do
            [[ -n "$path" && ! -L "$path" ]] || continue
            count=$((count + 1))
            if [[ "$count" -gt 2000 ]]; then
                devrecipe_preflight_incomplete "$query" "${DEVRECIPE_PREFLIGHT_CACHE_SOURCES[index]}" "${DEVRECIPE_PREFLIGHT_CACHE_SCOPES[index]}" 'scan limit reached'
                break
            fi
            location="$(devrecipe_preflight_redact_location "$path")"
            if devrecipe_preflight_record "$query" "${DEVRECIPE_PREFLIGHT_CACHE_SOURCES[index]}" "${DEVRECIPE_PREFLIGHT_CACHE_SCOPES[index]}" "$location" "$(basename "$path")"; then found=true; fi
        done < "${DEVRECIPE_PREFLIGHT_CACHE_FILES[index]}"
    done
    [[ "$found" == true ]]
}

devrecipe_preflight_os_metadata_matches() {
    local query="$1"
    local found=false receipt

    case "$PLATFORM" in
        macos)
            if command -v pkgutil >/dev/null 2>&1; then
                while IFS= read -r receipt || [[ -n "$receipt" ]]; do
                    if devrecipe_preflight_record "$query" 'os-installation-record:pkgutil' 'machine' '<package-receipt>' "$receipt"; then found=true; fi
                done < <(pkgutil --pkgs 2>/dev/null) || devrecipe_preflight_incomplete "$query" 'os-installation-record:pkgutil' 'machine' 'receipt inventory unavailable'
            else
                devrecipe_preflight_incomplete "$query" 'os-installation-record:pkgutil' 'machine' 'pkgutil unavailable'
            fi
            ;;
        linux)
            ;;
    esac
    devrecipe_preflight_cached_metadata_matches "$query" && found=true
    [[ "$found" == true ]]
}

devrecipe_preflight_entry() {
    local type="$1"
    local provider="$2"
    local name="$3"
    local version="$4"
    local query="$name"
    local os_found=false evidence_found=false

    devrecipe_preflight_os_metadata_matches "$query" && os_found=true
    if devrecipe_preflight_flush_evidence; then evidence_found=true; fi
    [[ "$os_found" == true || "$evidence_found" == true ]]
}

devrecipe_preflight_provider_installed() {
    local type="$1"
    local provider="$2"
    local name="$3"
    local version="$4"

    case "$PLATFORM:$type:$provider" in
        *:runtimes:mise|*:tools:mise) [[ "$(mise_status "$name" "$version")" == installed ]] ;;
        macos:packages:os) [[ "$MACOS_FORMULAS_STATE" == ready ]] && inventory_contains_exact_id "$MACOS_FORMULAS" "$name" ;;
        macos:packages:cask) [[ "$MACOS_CASKS_STATE" == ready ]] && inventory_contains_exact_id "$MACOS_CASKS" "$name" ;;
        linux:packages:os) [[ "$LINUX_APT_STATE" == ready ]] && inventory_contains_exact_id "$LINUX_APT" "$name" ;;
        linux:packages:flatpak) [[ "$LINUX_FLATPAK_STATE" == ready ]] && inventory_contains_exact_id "$LINUX_FLATPAK" "$name" ;;
        *) return 1 ;;
    esac
}

devrecipe_preflight_provider_coverage() {
    local names_name="$1"
    local types_name="$2"
    local providers_name="$3"
    local -a names types providers
    local index has_mise=false has_macos_formula=false has_macos_cask=false has_linux_apt=false has_linux_flatpak=false
    local -a notes=()

    eval "names=(\"\${${names_name}[@]}\")"
    eval "types=(\"\${${types_name}[@]}\")"
    eval "providers=(\"\${${providers_name}[@]}\")"
    for index in "${!names[@]}"; do
        case "${types[index]}:${providers[index]}" in
            runtimes:mise|tools:mise) has_mise=true ;;
            packages:os) [[ "$PLATFORM" == macos ]] && has_macos_formula=true || has_linux_apt=true ;;
            packages:cask) has_macos_cask=true ;;
            packages:flatpak) has_linux_flatpak=true ;;
        esac
    done
    if [[ "$has_mise" == true ]] && ! mise_binary >/dev/null 2>&1; then
        notes+=('  coverage | source=Mise installed-tool inventory | scope=user | note=not available before Mise installation; no action is required unless matching evidence is shown')
    fi
    if [[ "$has_macos_formula" == true && "$MACOS_FORMULAS_STATE" != ready ]]; then
        notes+=('  coverage | source=Homebrew installed-formula inventory | scope=machine | note=not available before Homebrew bootstrap or when brew list fails; no action is required unless matching evidence is shown')
    fi
    if [[ "$has_macos_cask" == true && "$MACOS_CASKS_STATE" != ready ]]; then
        notes+=('  coverage | source=Homebrew installed-cask inventory | scope=machine | note=not available before Homebrew bootstrap or when brew list fails; no action is required unless matching evidence is shown')
    fi
    if [[ "$has_linux_apt" == true && "$LINUX_APT_STATE" != ready ]]; then
        notes+=('  coverage | source=APT installed-package inventory | scope=machine | note=not available when dpkg-query fails; no action is required unless matching evidence is shown')
    fi
    if [[ "$has_linux_flatpak" == true && "$LINUX_FLATPAK_STATE" != ready ]]; then
        notes+=('  coverage | source=Flatpak user-app inventory | scope=user | note=not available before Flatpak installation or when flatpak list fails; no action is required unless matching evidence is shown')
    fi
    [[ ${#notes[@]} -eq 0 ]] || { printf '\n--- PREFLIGHT COVERAGE NOTE (read-only) ---\n'; printf '%s\n' "${notes[@]}"; }
}

devrecipe_is_interactive_terminal() {
    [[ -t 0 && -t 1 ]]
}

devrecipe_preflight_native_write_line() {
    local line="$1"
    local columns="$2"
    local width=$((columns - 1))

    printf '\r'
    tput el || return 1
    if (( ${#line} > width )); then
        if (( width > 3 )); then
            line="${line:0:$((width - 3))}..."
        else
            line="${line:0:width}"
        fi
    fi
    printf '%-*s' "$width" "$line"
}

devrecipe_preflight_native_visible_rows() {
    local option_count="$1"
    local terminal_rows="$2"
    local header_rows=4
    local menu_chrome_rows=3
    local minimum_visible_rows=3
    local available_rows

    [[ "$option_count" =~ ^[0-9]+$ && "$terminal_rows" =~ ^[0-9]+$ ]] || return 1
    (( option_count > 0 )) || return 1
    available_rows=$((terminal_rows - header_rows - menu_chrome_rows))
    (( available_rows >= minimum_visible_rows )) || return 1
    (( available_rows > option_count )) && available_rows="$option_count"
    printf '%s' "$available_rows"
}

devrecipe_preflight_native_multiselect() {
    local -a options=("$@") selected=()
    local option_count="${#options[@]}"
    local rows columns index current=0 key suffix all_selected next_selected marker pointer
    local visible_rows menu_lines first_visible=0 maximum_first below checked_count=0
    local list_focused=true button=0 force_button cancel_button line

    [[ "$option_count" -gt 0 ]] || return 1
    devrecipe_is_interactive_terminal || return 1
    [[ -n "${TERM:-}" && "${TERM:-}" != dumb ]] || return 1
    command -v tput >/dev/null 2>&1 || return 1
    rows="$(tput lines 2>/dev/null)" || return 1
    columns="$(tput cols 2>/dev/null)" || return 1
    [[ "$rows" =~ ^[0-9]+$ && "$columns" =~ ^[0-9]+$ ]] || return 1
    (( columns >= 24 )) || return 1
    visible_rows="$(devrecipe_preflight_native_visible_rows "$option_count" "$rows")" || return 1
    tput cuu 1 >/dev/null 2>&1 || return 1
    tput el >/dev/null 2>&1 || return 1

    for index in "${!options[@]}"; do
        selected[index]=false
    done
    DEVRECIPE_PREFLIGHT_NATIVE_SELECTED=()
    DEVRECIPE_PREFLIGHT_NATIVE_CANCELLED=false
    menu_lines=$((visible_rows + 3))

    printf '\n--- PREFLIGHT CONFLICT SELECTION ---\n'
    printf 'Check exact declared entries to force; unchecked entries are declined.\n'
    printf 'Up/Down: move/scroll | Space: toggle | A: all | Left/Right or Tab: buttons | Enter: confirm | Escape: cancel | P: plain prompts\n'
    for ((index = 0; index < menu_lines; index++)); do
        printf '\n'
    done
    tput cuu "$menu_lines" || return 1

    while :; do
        if (( current < first_visible )); then
            first_visible="$current"
        elif (( current >= first_visible + visible_rows )); then
            first_visible=$((current - visible_rows + 1))
        fi
        maximum_first=$((option_count - visible_rows))
        (( first_visible > maximum_first )) && first_visible="$maximum_first"

        line=''
        (( first_visible > 0 )) && line="  ^ $first_visible more above"
        devrecipe_preflight_native_write_line "$line" "$columns" || return 1
        printf '\n'
        for ((index = first_visible; index < first_visible + visible_rows; index++)); do
            marker=' '
            pointer=' '
            [[ "${selected[index]}" == true ]] && marker='x'
            [[ "$list_focused" == true && "$index" -eq "$current" ]] && pointer='>'
            devrecipe_preflight_native_write_line "$pointer [$marker] ${options[index]}" "$columns" || return 1
            printf '\n'
        done

        below=$((option_count - (first_visible + visible_rows)))
        line=''
        (( below > 0 )) && line="  v $below more below"
        devrecipe_preflight_native_write_line "$line" "$columns" || return 1
        printf '\n'
        checked_count=0
        for index in "${!selected[@]}"; do
            [[ "${selected[index]}" == true ]] && checked_count=$((checked_count + 1))
        done
        force_button="[ Force selected ($checked_count) ]"
        cancel_button='[ Cancel ]'
        if [[ "$list_focused" == true ]]; then
            line="  $force_button  $cancel_button"
        elif [[ "$button" -eq 0 ]]; then
            line="> $force_button  $cancel_button"
        else
            line="  $force_button  > $cancel_button"
        fi
        devrecipe_preflight_native_write_line "$line" "$columns" || return 1

        if ! IFS= read -r -s -n 1 key; then
            printf '\n'
            return 3
        fi
        case "$key" in
            $'\e')
                suffix=''
                if IFS= read -r -s -n 2 -t 0.1 suffix; then
                    case "$suffix" in
                        "[A"|OA) if [[ "$list_focused" == true ]]; then (( current > 0 )) && current=$((current - 1)); else list_focused=true; fi ;;
                        "[B"|OB) if [[ "$list_focused" == true ]]; then if (( current < option_count - 1 )); then current=$((current + 1)); else list_focused=false; button=0; fi; fi ;;
                        "[C"|OC) list_focused=false; button=1 ;;
                        "[D"|OD) list_focused=false; button=0 ;;
                    esac
                    tput cuu "$((menu_lines - 1))" || return 1
                    continue
                fi
                for ((index = 0; index < option_count; index++)); do selected[index]=false; done
                DEVRECIPE_PREFLIGHT_NATIVE_CANCELLED=true
                DEVRECIPE_PREFLIGHT_NATIVE_SELECTED=("${selected[@]}")
                printf '\n'
                return 0
                ;;
            ' ')
                if [[ "$list_focused" == true ]]; then
                    if [[ "${selected[current]}" == true ]]; then selected[current]=false; else selected[current]=true; fi
                elif [[ "$button" -eq 0 ]]; then
                    DEVRECIPE_PREFLIGHT_NATIVE_SELECTED=("${selected[@]}")
                    printf '\n'
                    return 0
                else
                    for ((index = 0; index < option_count; index++)); do selected[index]=false; done
                    DEVRECIPE_PREFLIGHT_NATIVE_CANCELLED=true
                    DEVRECIPE_PREFLIGHT_NATIVE_SELECTED=("${selected[@]}")
                    printf '\n'
                    return 0
                fi
                ;;
            A|a)
                all_selected=true
                for ((index = 0; index < option_count; index++)); do
                    [[ "${selected[index]}" == true ]] || { all_selected=false; break; }
                done
                next_selected=false
                [[ "$all_selected" == false ]] && next_selected=true
                for ((index = 0; index < option_count; index++)); do selected[index]="$next_selected"; done
                ;;
            P|p)
                printf '\n'
                return 1
                ;;
            $'\t')
                if [[ "$list_focused" == true ]]; then list_focused=false; button=0; else button=$((1 - button)); fi
                ;;
            ''|$'\r')
                if [[ "$list_focused" == false && "$button" -eq 1 ]]; then
                    for ((index = 0; index < option_count; index++)); do selected[index]=false; done
                    DEVRECIPE_PREFLIGHT_NATIVE_CANCELLED=true
                fi
                DEVRECIPE_PREFLIGHT_NATIVE_SELECTED=("${selected[@]}")
                printf '\n'
                return 0
                ;;
        esac
        tput cuu "$((menu_lines - 1))" || return 1
    done
}

devrecipe_preflight_entries() {
    local names_name="$1"
    local types_name="$2"
    local providers_name="$3"
    local versions_name="$4"
    local -a names types providers versions
    local index found=false answer entry_output query native_status conflict_position
    local -a conflict_indices=() conflict_labels=()

    # Bash 3-compatible array copies; public recipe avoids nameref for portability.
    eval "names=(\"\${${names_name}[@]}\")"
    eval "types=(\"\${${types_name}[@]}\")"
    eval "providers=(\"\${${providers_name}[@]}\")"
    eval "versions=(\"\${${versions_name}[@]}\")"

    DEVRECIPE_PREFLIGHT_APPROVE_ALL=false
    DEVRECIPE_PREFLIGHT_DECLINE_ALL=false
    DEVRECIPE_PREFLIGHT_NATIVE_SELECTED=()
    DEVRECIPE_PREFLIGHT_NATIVE_CANCELLED=false
    devrecipe_preflight_prepare_metadata_cache "${names[@]}"
    for index in "${!names[@]}"; do
        query="${names[index]}"
        if devrecipe_preflight_provider_installed "${types[index]}" "${providers[index]}" "${names[index]}" "${versions[index]}"; then
            DEVRECIPE_PREFLIGHT_EXCLUDED_IDS+=("$(devrecipe_preflight_action_key "${types[index]}" "${providers[index]}" "${names[index]}" "${versions[index]}")")
            continue
        fi
        printf '\n--- PREFLIGHT CHECK: %s ---\n' "$query"
        devrecipe_preflight_begin_entry
        entry_output="$(devrecipe_preflight_entry "${types[index]}" "${providers[index]}" "${names[index]}" "${versions[index]}" || :)"
        [[ -z "$entry_output" ]] || printf '%s\n' "$entry_output"
        if grep -Fq 'evidence | query=' <<< "$entry_output"; then
            found=true
            conflict_indices+=("$index")
        fi
    done

    if [[ "$found" == true ]] && ! devrecipe_is_interactive_terminal; then
        printf 'Preflight needs human decisions; no mutation was attempted.\n' >&2
        return 3
    fi
    if [[ ${#conflict_indices[@]} -gt 0 ]]; then
        for index in "${conflict_indices[@]}"; do
            conflict_labels+=("${types[index]} | ${providers[index]} | ${names[index]} | ${versions[index]}")
        done
        if devrecipe_preflight_native_multiselect "${conflict_labels[@]}"; then
            for conflict_position in "${!conflict_indices[@]}"; do
                index="${conflict_indices[conflict_position]}"
                if [[ "$DEVRECIPE_PREFLIGHT_NATIVE_CANCELLED" == false && "${DEVRECIPE_PREFLIGHT_NATIVE_SELECTED[conflict_position]:-false}" == true ]]; then
                    printf '  decision=force | application=%s\n' "${names[index]}"
                else
                    DEVRECIPE_PREFLIGHT_EXCLUDED_IDS+=("$(devrecipe_preflight_action_key "${types[index]}" "${providers[index]}" "${names[index]}" "${versions[index]}")")
                    printf '  decision=decline | application=%s\n' "${names[index]}"
                fi
            done
            return 0
        fi
        native_status=$?
        if [[ "$native_status" -eq 3 ]]; then
            printf '\n  decision unresolved: input closed\n' >&2
            return 3
        fi
    fi
    for index in "${conflict_indices[@]}"; do
        if [[ "$DEVRECIPE_PREFLIGHT_APPROVE_ALL" == true ]]; then
            printf '  decision=force-all | application=%s\n' "${names[index]}"
            continue
        fi
        if [[ "$DEVRECIPE_PREFLIGHT_DECLINE_ALL" == true ]]; then
            DEVRECIPE_PREFLIGHT_EXCLUDED_IDS+=("$(devrecipe_preflight_action_key "${types[index]}" "${providers[index]}" "${names[index]}" "${versions[index]}")")
            printf '  decision=decline-all | application=%s\n' "${names[index]}"
            continue
        fi
        printf "Force exact declared installation for '%s'? [y/N/A=all yes/D=all no]: " "${names[index]}"
        if ! IFS= read -r answer; then
            printf '\n  decision unresolved: input closed\n' >&2
            return 3
        fi
        case "$answer" in
            A|"all yes"|"ALL YES")
                DEVRECIPE_PREFLIGHT_APPROVE_ALL=true
                printf '  decision=force-all | application=%s\n' "${names[index]}"
                ;;
            D|"all no"|"ALL NO")
                DEVRECIPE_PREFLIGHT_DECLINE_ALL=true
                DEVRECIPE_PREFLIGHT_EXCLUDED_IDS+=("$(devrecipe_preflight_action_key "${types[index]}" "${providers[index]}" "${names[index]}" "${versions[index]}")")
                printf '  decision=decline-all | application=%s\n' "${names[index]}"
                ;;
            y|Y|yes|YES|Yes) printf '  decision=force | application=%s\n' "${names[index]}" ;;
            *)
                DEVRECIPE_PREFLIGHT_EXCLUDED_IDS+=("$(devrecipe_preflight_action_key "${types[index]}" "${providers[index]}" "${names[index]}" "${versions[index]}")")
                printf '  decision=decline | application=%s\n' "${names[index]}"
                ;;
        esac
    done
    return 0
}

devrecipe_run_preflight() {
    local use_containers="$1"
    local preflight_status=0

    printf '\n--- PREFLIGHT CONFLICT EVIDENCE (read-only) ---\n'
    printf 'threshold=%s/100; similarity is evidence ordering only, never identity or provenance.\n' "$DEVRECIPE_PREFLIGHT_THRESHOLD"
    collect_status_inventories

    if [[ "$use_containers" == true ]]; then
        printf '\nContainer entries:\n'
        devrecipe_preflight_provider_coverage CONTAINER_NAMES CONTAINER_TYPES CONTAINER_PROVIDERS
        devrecipe_preflight_entries CONTAINER_NAMES CONTAINER_TYPES CONTAINER_PROVIDERS CONTAINER_VERSIONS || preflight_status=$?
    else
        printf '\nSelected entries:\n'
        devrecipe_preflight_provider_coverage ENTRY_NAMES ENTRY_TYPES ENTRY_PROVIDERS
        devrecipe_preflight_entries ENTRY_NAMES ENTRY_TYPES ENTRY_PROVIDERS ENTRY_VERSIONS || preflight_status=$?
    fi
    if [[ -n "$DEVRECIPE_PREFLIGHT_CACHE_DIR" ]]; then
        rm -rf "$DEVRECIPE_PREFLIGHT_CACHE_DIR"
        DEVRECIPE_PREFLIGHT_CACHE_DIR=''
        DEVRECIPE_PREFLIGHT_CACHE_SOURCES=()
        DEVRECIPE_PREFLIGHT_CACHE_SCOPES=()
        DEVRECIPE_PREFLIGHT_CACHE_FILES=()
    fi
    return "$preflight_status"
}
# End embedded preflight and review helpers.

if ! validate_manifest; then exit 2; fi
if [[ "$MODE" == validate ]]; then
    printf 'Valid manifest: %s (DevRecipe v2 contract).\n' "$(basename "$TOML_PATH")"
    exit 0
fi

if [[ "$WITH_CONTAINERS" == true ]]; then
    if [[ "$MODE" != install && "$MODE" != dry-run ]] || [[ "$CONFIRM_UNINSTALL" == true ]]; then
        printf '%s\n' '--containers is compatible only with installation or --dry-run.' >&2
        exit 2
    fi
    load_container_entries
    preflight_status=0
    devrecipe_run_preflight true || preflight_status=$?
    if [[ "$preflight_status" -ne 0 ]]; then
        exit "$preflight_status"
    fi
    if [[ "$MODE" == dry-run ]]; then
        show_container_dry_run_plan
        exit 0
    fi
    build_container_install_groups
    show_container_dry_run_plan '--- FINAL INSTALLATION PLAN AFTER PREFLIGHT ---'
    if [[ ${#CONTAINER_OS_PACKAGES[@]} -eq 0 && ${#CONTAINER_CASK_PACKAGES[@]} -eq 0 && ${#CONTAINER_FLATPAK_PACKAGES[@]} -eq 0 ]]; then
        printf '%s\n' 'No container actions remain after preflight; no changes were made.'
        exit 0
    fi
    case "$PLATFORM" in
        macos) run_macos_containers ;;
        linux) run_linux_containers ;;
    esac
    devrecipe_review_finish
    exit 0
fi

load_entries
if [[ "$MODE" == install || "$MODE" == dry-run ]]; then
    preflight_status=0
    devrecipe_run_preflight false || preflight_status=$?
    if [[ "$preflight_status" -ne 0 ]]; then
        exit "$preflight_status"
    fi
fi
case "$MODE" in
    list)
        show_list
        exit 0
        ;;
    dry-run)
        show_dry_run_plan
        exit 0
        ;;
    status)
        show_status
        exit 0
        ;;
    uninstall)
        build_remove_plan
        show_remove_plan
        [[ "$CONFIRM_UNINSTALL" == true ]] && run_remove_plan
        devrecipe_review_finish
        exit 0
        ;;
esac

build_install_groups
    show_dry_run_plan '--- FINAL INSTALLATION PLAN AFTER PREFLIGHT ---'
printf 'Selected profiles: %s\n' "${REQUESTED_PROFILES[*]}"
case "$PLATFORM" in
    macos) run_macos_install ;;
    linux) run_linux_install ;;
esac
show_summary
devrecipe_review_finish