#!/bin/bash

#================================================
# Author: Milo
# System Required: CentOS/Debian/Ubuntu
# Description: auto install and config ohmyzsh
# Version: 1.1.0
# github: https://github.com/imdm/scripts
#================================================

Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Font_color_suffix="\033[0m"

return_or_exit() {
    local exit_code="${1:-1}"
    if [ "${BASH_SOURCE[0]}" != "$0" ]; then
        return "${exit_code}"
    fi

    exit "${exit_code}"
}

log_info() {
    echo -e "${Green_font_prefix}$1${Font_color_suffix}"
}

log_warn() {
    echo -e "${Red_font_prefix}$1${Font_color_suffix}"
}

abort_install() {
    log_warn "$1"
    return_or_exit 1
}

detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        package_manager="apt-get"
    elif command -v dnf >/dev/null 2>&1; then
        package_manager="dnf"
    elif command -v yum >/dev/null 2>&1; then
        package_manager="yum"
    else
        abort_install "不支持当前操作系统"
    fi
}

detect_privileged_command_prefix() {
    if [ "$(id -u)" -eq 0 ]; then
        privileged_command=()
        return 0
    fi

    if command -v sudo >/dev/null 2>&1; then
        privileged_command=(sudo)
        return 0
    fi

    abort_install "请使用 root 运行脚本，或先安装 sudo"
}

refresh_apt_package_index() {
    if [ "${package_manager}" != "apt-get" ] || [ "${apt_package_index_refreshed:-0}" = "1" ]; then
        return 0
    fi

    log_info "刷新 apt 软件包索引.."
    if ! "${privileged_command[@]}" env DEBIAN_FRONTEND=noninteractive apt-get update; then
        abort_install "apt 软件包索引刷新失败"
    fi

    apt_package_index_refreshed=1
}

install_required_package() {
    local package_name="$1"
    local binary_name="${2:-$1}"

    if command -v "${binary_name}" >/dev/null 2>&1; then
        log_info "${binary_name} 已安装，跳过"
        return 0
    fi

    if [ "${package_manager}" = "apt-get" ]; then
        refresh_apt_package_index
        log_info "安装 ${package_name}.."
        if ! "${privileged_command[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y "${package_name}"; then
            abort_install "安装 ${package_name} 失败"
        fi
    else
        log_info "安装 ${package_name}.."
        if ! "${privileged_command[@]}" "${package_manager}" install -y "${package_name}"; then
            abort_install "安装 ${package_name} 失败"
        fi
    fi

    if ! command -v "${binary_name}" >/dev/null 2>&1; then
        abort_install "安装 ${package_name} 后仍未找到 ${binary_name}"
    fi
}

install_oh_my_zsh_framework() {
    local oh_my_zsh_dir="${HOME}/.oh-my-zsh"
    local installer_script

    if [ -d "${oh_my_zsh_dir}" ]; then
        log_info "oh-my-zsh 已存在，跳过安装"
        return 0
    fi

    log_info "安装 oh-my-zsh.."
    installer_script="$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || abort_install "下载 oh-my-zsh 安装脚本失败"
    if ! ZSH="${oh_my_zsh_dir}" RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "${installer_script}"; then
        abort_install "安装 oh-my-zsh 失败"
    fi

    if [ ! -d "${oh_my_zsh_dir}" ]; then
        abort_install "oh-my-zsh 安装后目录不存在"
    fi
}

install_oh_my_zsh_plugin_repo() {
    local plugin_repo_url="$1"
    local plugin_name="$2"
    local plugin_dir="${HOME}/.oh-my-zsh/custom/plugins"
    local plugin_path="${plugin_dir}/${plugin_name}"

    mkdir -p "${plugin_dir}"

    if [ -d "${plugin_path}" ]; then
        log_info "插件 ${plugin_name} 已存在，跳过"
        return 0
    fi

    log_info "下载插件 ${plugin_name}.."
    if ! git clone --depth=1 "${plugin_repo_url}" "${plugin_path}"; then
        abort_install "下载插件 ${plugin_name} 失败"
    fi
}

ensure_zshrc_file_exists() {
    local oh_my_zsh_dir="${HOME}/.oh-my-zsh"
    local zsh_template="${oh_my_zsh_dir}/templates/zshrc.zsh-template"

    if [ -f "${HOME}/.zshrc" ]; then
        return 0
    fi

    if [ ! -f "${zsh_template}" ]; then
        abort_install "未找到 zsh 配置模板 ${zsh_template}"
    fi

    cp "${zsh_template}" "${HOME}/.zshrc" || abort_install "创建 ~/.zshrc 失败"
}

ensure_shell_profile_file_exists() {
    local profile_path="$1"

    if [ -f "${profile_path}" ]; then
        return 0
    fi

    : > "${profile_path}" || abort_install "创建 ${profile_path} 失败"
}

update_zshrc_theme_and_plugins() {
    local plugin_line='plugins=(git last-working-dir vi-mode zsh-autosuggestions zsh-syntax-highlighting)'

    ensure_zshrc_file_exists

    log_info "写入 ~/.zshrc 配置.."
    if grep -q '^ZSH_THEME=' "${HOME}/.zshrc"; then
        sed -i.bak 's/^ZSH_THEME=.*/ZSH_THEME="ys"/' "${HOME}/.zshrc" || abort_install "更新 ~/.zshrc 主题失败"
    else
        printf '\nZSH_THEME="ys"\n' >> "${HOME}/.zshrc"
    fi

    if grep -q '^plugins=' "${HOME}/.zshrc"; then
        sed -i.bak "s/^plugins=.*/${plugin_line}/" "${HOME}/.zshrc" || abort_install "更新 ~/.zshrc 插件失败"
    else
        printf '\n%s\n' "${plugin_line}" >> "${HOME}/.zshrc"
    fi

    rm -f "${HOME}/.zshrc.bak"
}

ensure_interactive_bash_hands_off_to_zsh() {
    local zsh_path
    local bash_profile_path="${HOME}/.bash_profile"
    local bashrc_path="${HOME}/.bashrc"
    local handoff_block

    zsh_path="$(command -v zsh 2>/dev/null)"
    if [ -z "${zsh_path}" ]; then
        abort_install "未找到 zsh 可执行文件，无法写入 bash 到 zsh 的兜底切换"
    fi

    handoff_block="$(cat <<EOF
# >>> ohmyzsh auto handoff >>>
if [ -n "\${BASH_VERSION:-}" ] && [ -z "\${ZSH_VERSION:-}" ]; then
    case "\$-" in
        *i*)
            export SHELL="${zsh_path}"
            exec "${zsh_path}" -l
            ;;
    esac
fi
# <<< ohmyzsh auto handoff <<<
EOF
)"

    ensure_shell_profile_file_exists "${bash_profile_path}"
    ensure_shell_profile_file_exists "${bashrc_path}"

    if ! grep -q 'ohmyzsh auto handoff' "${bash_profile_path}"; then
        printf '\n%s\n' "${handoff_block}" >> "${bash_profile_path}" || abort_install "写入 ${bash_profile_path} 失败"
    fi

    if ! grep -q 'ohmyzsh auto handoff' "${bashrc_path}"; then
        printf '\n%s\n' "${handoff_block}" >> "${bashrc_path}" || abort_install "写入 ${bashrc_path} 失败"
    fi
}

read_configured_login_shell_for_user() {
    local user_name="$1"
    local configured_login_shell

    if command -v getent >/dev/null 2>&1; then
        configured_login_shell="$(getent passwd "${user_name}" | awk -F: '{print $7}')"
    else
        configured_login_shell="$(awk -F: -v target_user="${user_name}" '$1 == target_user { print $7 }' /etc/passwd)"
    fi

    printf '%s\n' "${configured_login_shell}"
}

update_default_login_shell_to_zsh() {
    local zsh_path
    local user_name
    local configured_login_shell

    zsh_path="$(command -v zsh 2>/dev/null)"
    user_name="$(id -un)"

    if [ -z "${zsh_path}" ]; then
        abort_install "未找到 zsh 可执行文件，无法切换默认 SHELL"
    fi

    configured_login_shell="$(read_configured_login_shell_for_user "${user_name}")"
    if [ "${configured_login_shell}" = "${zsh_path}" ]; then
        log_info "当前默认登录 SHELL 已是 ${zsh_path}"
        return 0
    fi

    log_info "切换默认登录 SHELL 到 ${zsh_path}.."
    if [ -r /etc/shells ] && ! grep -qx "${zsh_path}" /etc/shells; then
        log_warn "${zsh_path} 不在 /etc/shells 中，请手动确认后再执行 chsh"
        return 0
    fi

    if command -v chsh >/dev/null 2>&1; then
        "${privileged_command[@]}" chsh -s "${zsh_path}" "${user_name}" >/dev/null 2>&1 || true
    fi

    configured_login_shell="$(read_configured_login_shell_for_user "${user_name}")"
    if [ "${configured_login_shell}" = "${zsh_path}" ]; then
        log_info "默认登录 SHELL 已切换为 ${zsh_path}"
        return 0
    fi

    if command -v usermod >/dev/null 2>&1; then
        "${privileged_command[@]}" usermod -s "${zsh_path}" "${user_name}" >/dev/null 2>&1 || true
    fi

    configured_login_shell="$(read_configured_login_shell_for_user "${user_name}")"
    if [ "${configured_login_shell}" = "${zsh_path}" ]; then
        log_info "默认登录 SHELL 已切换为 ${zsh_path}"
        return 0
    fi

    log_warn "自动切换默认登录 SHELL 失败，请手动执行: chsh -s ${zsh_path} ${user_name}"
}

install_and_configure_oh_my_zsh() {
    echo -e "当前SHELL是:${SHELL}"
    detect_package_manager
    detect_privileged_command_prefix

    install_required_package "curl" "curl"
    install_required_package "zsh" "zsh"
    install_required_package "git" "git"
    install_oh_my_zsh_framework
    install_oh_my_zsh_plugin_repo "https://github.com/zsh-users/zsh-syntax-highlighting.git" "zsh-syntax-highlighting"
    install_oh_my_zsh_plugin_repo "https://github.com/zsh-users/zsh-autosuggestions.git" "zsh-autosuggestions"
    update_zshrc_theme_and_plugins
    ensure_interactive_bash_hands_off_to_zsh
    update_default_login_shell_to_zsh

    log_info "安装成功，请重新登录终端或执行 exec zsh 生效"
}

install_and_configure_oh_my_zsh "$@"
