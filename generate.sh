#!/usr/bin/env bash
set -e

# 統合優先順位。ユーザ指定の順序に関わらず、この順で処理・追記される
TEMPLATES_ORDER="git markdown python c"
TEMPLATE_URLS_git="https://github.com/in0ho1no/Git_Template"
TEMPLATE_URLS_markdown="https://github.com/in0ho1no/Markdown_Template"
TEMPLATE_URLS_python="https://github.com/in0ho1no/Python_Template"
TEMPLATE_URLS_c="https://github.com/in0ho1no/C_template"
OUTPUT_DIR="integlated"
WORK_DIR=""

get_template_url() {
    case "$1" in
        git)      echo "$TEMPLATE_URLS_git" ;;
        markdown) echo "$TEMPLATE_URLS_markdown" ;;
        python)   echo "$TEMPLATE_URLS_python" ;;
        c)        echo "$TEMPLATE_URLS_c" ;;
        *)        echo "" ;;
    esac
}

# 異常終了・シグナル受信時にも一時ディレクトリを残さないため
cleanup() {
    [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"
}
trap cleanup EXIT

is_valid_template() {
    case "$1" in
        git|markdown|python|c) return 0 ;;
        *) return 1 ;;
    esac
}

contains_word() {
    local needle="$1"
    shift
    local word
    for word in "$@"; do
        [ "$word" = "$needle" ] && return 0
    done
    return 1
}

select_and_sort_templates() {
    local raw_selected=""

    if [ $# -eq 0 ]; then
        for tmpl in $TEMPLATES_ORDER; do
            printf "Use %s template? (y/n): " "$tmpl"
            read -r answer
            case "$answer" in
                y|Y) raw_selected="$raw_selected $tmpl" ;;
            esac
        done
    else
        for arg in "$@"; do
            if ! is_valid_template "$arg"; then
                echo "Error: Unknown template '$arg'" >&2
                exit 1
            fi
            # shellcheck disable=SC2086
            if ! contains_word "$arg" $raw_selected; then
                raw_selected="$raw_selected $arg"
            fi
        done
    fi

    # ユーザ指定順を捨て、定義済み優先順位に従って並べ直す
    local sorted=""
    for tmpl in $TEMPLATES_ORDER; do
        # shellcheck disable=SC2086
        if contains_word "$tmpl" $raw_selected; then
            sorted="$sorted $tmpl"
        fi
    done

    echo "${sorted# }"
}

# 複数テンプレートの設定を蓄積する目的で追記対象とするファイルを識別する
is_mechanical_merge() {
    case "$(basename "$1")" in
        .gitignore|.editorconfig|.gitattributes) return 0 ;;
        *) return 1 ;;
    esac
}

# ツール設定ファイルは内容の無言上書きを防ぐため、常に衝突として扱う
is_instruction_file() {
    local norm_rel
    norm_rel=$(printf '%s' "$1" | tr '\\' '/')
    case "$norm_rel" in
        ".claude/CLAUDE.md"|".github/copilot-instructions.md") return 0 ;;
        *) return 1 ;;
    esac
}

# 追記後もファイルが改行で終わることを保証する（連続追記時の行境界を守るため）
ensure_trailing_newline() {
    if [ -n "$(tail -c1 "$1")" ]; then
        printf '\n' >> "$1"
    fi
}

process_file() {
    local src="$1"
    local rel="$2"
    local tmpl="$3"
    local dest="$OUTPUT_DIR/$rel"

    mkdir -p "$(dirname "$dest")"

    if is_instruction_file "$rel"; then
        if [ -f "$dest" ]; then
            cp "$src" "${dest}.merge.${tmpl}"
            echo "[CONFLICT] ${rel}.merge.${tmpl}"
        else
            cp "$src" "$dest"
            echo "[ADD] $rel"
        fi
        return
    fi

    if is_mechanical_merge "$rel"; then
        if [ -f "$dest" ]; then
            printf '\n' >> "$dest"
            cat "$src" >> "$dest"
        else
            cp "$src" "$dest"
        fi
        ensure_trailing_newline "$dest"
        echo "[ADD] $rel"
        return
    fi

    if [ ! -f "$dest" ]; then
        cp "$src" "$dest"
        echo "[ADD] $rel"
    elif cmp -s "$src" "$dest"; then
        echo "[SKIP] $rel"
    else
        cp "$src" "${dest}.merge.${tmpl}"
        echo "[CONFLICT] ${rel}.merge.${tmpl}"
    fi
}

apply_template() {
    local tmpl_dir="$1"
    local tmpl_name="$2"

    while IFS= read -r file; do
        local rel="${file#${tmpl_dir}/}"
        process_file "$file" "$rel" "$tmpl_name"
    done < <(find "$tmpl_dir" -type f -not -path '*/.git/*' | sort)
}

main() {
    local sorted
    sorted=$(select_and_sort_templates "$@")

    if [ -z "$sorted" ]; then
        echo "No templates selected. Exiting."
        exit 0
    fi

    echo "Selected templates (in order): $sorted"

    if [ -d "$OUTPUT_DIR" ]; then
        local other
        other=$(find "$OUTPUT_DIR" -type f -not -name ".gitignore" 2>/dev/null | head -1)
        if [ -n "$other" ]; then
            echo "Error: '$OUTPUT_DIR' already exists and contains files other than .gitignore. Aborting."
            exit 1
        fi
    fi

    mkdir -p "$OUTPUT_DIR"
    WORK_DIR=$(mktemp -d)

    for tmpl in $sorted; do
        local url
        url=$(get_template_url "$tmpl")
        local clone_dir="$WORK_DIR/$tmpl"
        echo "Cloning $tmpl from $url ..."
        git clone --depth 1 "$url" "$clone_dir"
        echo "Applying $tmpl ..."
        apply_template "$clone_dir" "$tmpl"
    done

    echo "Done."
}

main "$@"
