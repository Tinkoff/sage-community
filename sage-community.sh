#!/bin/bash -e

usage () {
    cat << EOF
usage: $0 <cmd>

Available commands:
- check:     check you system's conformance to minimal requirements

- install:   install Sage Community
    -c CONFIG, --config CONFIG          Specify Sage config
    -h HOSTNAME, --hostname HOSTNAME    Bind to HOSTNAME instead of default <ip>.nip.io.
                                        Note that HOSTNAME cannot be IP address, since
                                        it is used to generate certificates.

- group-add: add new group to Sage Community

- wipe:      delete Sage Community and remove created data

To install Sage Community, run commands:
\$ $0 install

To uninstall Sage Community, run command:
\$ $0 wipe

To add groups to Sage Community, run commands:
\$ $0 group-add <groups.yml>
EOF
}

case "$1" in
    check | install | group-add | wipe )
        SUBCOMMAND="$1"
        shift
    ;;
    *)
        usage >&2
        exit 1
    ;;
esac

TEMP=$(getopt -o 'c:h:' --long 'config:,hostname:' -n "$0" -- "$@")

if [ $? -ne 0 ]; then
        echo 'Terminating...' >&2
        exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
    case "$1" in
        '-h'|'--hostname')
            hostname="$2"
            shift 2
            continue
        ;;
        '-c'|'--config')
            config="$2"
            if [ ! -e "$config" ]; then
                echo "File '$config' does not exist" >&2
                exit 1
            fi
            shift 2
            continue
        ;;
        '--')
            shift
            break
        ;;
        *)
            echo 'Internal error!' >&2
            exit 1
        ;;
    esac
done


# Making variables visible in inner bash sessions
make_vars_pre () {
    export vault_pass='demo'
    export vault_file="$(pwd)/sage_vault_pass.txt"
    export ssh_dir="${HOME}/.ssh/sage"
    export ansible_user="$(id -un)"
    export ansible_host="$(hostnamectl --static)"
    export ssh_port='2222'
    export ssh_bind='127.0.0.1'
    if [ -n "${hostname}" ]; then
        export ansible_host="$hostname"
        export docker_args=("${docker_args[@]}" -e EXTERNAL_HOSTNAME=${ansible_host})
    fi
}

version_at_least () {
    dpkg --compare-versions "$1" 'ge' "$2"
}

check () {
    if ! (groups | grep -q -e sudo -e root); then
        user=$(id -un)
        echo "Use are running as user ${user}, which does not belong to group sudo."
        echo "Please, add user ${user} to sudo group or run as a different user."
        fail=1
    fi

    if ! command -v sshd >/dev/null; then
        echo "Your system does not have sshd installed."
        echo "Please, try running 'apt update && apt install openssh-server'."
        fail=1
    fi

    if ! command -v docker >/dev/null; then
        echo "Your system does not have docker installed."
        echo "Please, follow instructions on 'https://docs.docker.com/engine/install/ubuntu/'" \
             "and install docker."
        fail=1
    fi

    local docker_ver_req="20.10"
    local docker_ver="$(docker -v | grep -o '[0-9]\+\.[0-9]\+' | head -1)"
    if ! version_at_least "${docker_ver}" "${docker_ver_req}"; then
        echo "You have docker version ${docker_ver} installed, but minimum ${docker_ver_req} required."
        echo "Please, follow instructions on 'https://docs.docker.com/engine/install/ubuntu/'" \
             "and install latest version of docker."
        fail=1
    fi

    if ! (docker system info 2>/dev/null | grep -q compose); then
        echo "You do not have docker Compose plugin installed."
        echo "Please, follow instructions on 'https://docs.docker.com/compose/install/linux/'" \
             "and install latest version of plugin."
        fail=1
    fi

    if ! command -v python3 >/dev/null; then
        echo "Your system does not have python3 installed."
        echo "Please, install python3."
        fail=1
    fi

    local python_ver_req="3.8"
    local python_ver="$(python3 -V | grep -o '[0-9]\+\.[0-9]\+' | head -1)"
    if ! version_at_least "${python_ver}" "${python_ver_req}"; then
        echo "You have python version ${python_ver} installed, but minimum ${python_ver_req} required."
        echo "Please, try running 'apt update && apt install python3.10'."
        fail=1
    fi

    if [ "$(df -l --output=avail . | tail -1)" -lt '30000000' ]; then
        echo "You are running Sage Community on a disk with only $(df -lh . --output=avail | tail -1)" \
             "space available (30GB required)."
        echo "Please, try expanding the disk or move $0 to a different disk."
        fail=1
    fi

    if ! (compgen -b | grep -iq chrom); then
        echo "Warning: could not locate Chrome browser."
        echo "This is not a problem; though other browsers are not supported explicitly."
    fi

    if [ -n "${fail}" ]; then
        exit 1
    fi

    echo 'OK'
}

config () {
    echo "${vault_pass}" > "${vault_file}"
    # if [ ! -e '.external_hostname' ] && ! grep -q ${ansible_host:-placeholder} /etc/hosts ; then
    #     echo '--> Create hosts record'
    #     echo "127.0.0.1 ${ansible_host}" | sudo tee -a /etc/hosts
    # fi

    echo '--> Login to Tinkoff container registry'
    cat <<EOF | sudo docker login --username json_key --password-stdin cr.yandex
{
  "created_at": "2023-04-18T15:28:49.752643522Z",
  "id": "ajej1bpt8jrps5cctvm9",
  "key_algorithm": "RSA_2048",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDR4gBffVVzUOLJ\nNqYcU5jD6BAHuBfJhV8sPMgVcuos3NTT9gFdMmguuVB6sb7k8Hzc8Xmyg+MLZZeo\nUrtDAFWMVAb+Uuh9P0SsJJdnXCKbCt3a5wCI5PDB7HcvSlYfyrHI5Q9YxjIkCPZH\nisQchlAy0Lyshc8/R2Q5pKaYd2wcapBBBKUNhqTJhsdwh1HenGIl851rBqSHrDq1\nvs83KTspXj1kDyuSzyaLIjY5JYUFKhQRBgoqiGekHTKSxdSK7f5zHsrYWbH2AUnf\nKCCD+9f8MSAgIRV65aTrnfo35I3F5lqdGUdvqA4BTHiIDZ9edlqgbsoCqR/8SyWT\nFDkPI2iFAgMBAAECggEAZGyc/RO9VUX4nYp2hMtDJ0nckbT2PMiCN2qF2i13+ytW\n8mydTniV/PVSmsJ9spGXTSiFsHMGqidcH4AmdfKs/E4gYoRNFdC2DSAdCam+LS1P\n5jPtv5K72C5LAOeyudeEpblkVHfQ+gkHvkeZeoSRzx6tiGcmOQLx49ryk7Vgl19P\naiWNv+bMvivvUI7ViI/hoCT7MAz7jU0wMavuFzmrVxsY7FnH8IGAtzqCBYznadN+\n6c1HSVl2ymq6mvV8yg4m3FQa5O7pnyzQFKXBLDS+FSY+wRvtuhu36nxwph83XrfH\n1RK6rsKB0zkIYWEfjMOjNxyP4GPD/hNOx1LDOb3C6QKBgQDXj5AXX3+6UR0H2y4m\n1asG+FkzN/Q3qLXalzXPRtJQbuLpADffJQsB47sD90l+ZSddX5xys1nRwae5kCt9\nyICNiJ7hhbg6Kohhpr5MMoabNBlirIX+/hvIQfgAYQR7aD5YKzywR/EHkTJEfbkq\nJer8c+/pyLV8Ac9WppTFS2caHwKBgQD5QcAeR/3VH07YQBWi8xW/sMHzCE8FJ+hv\nkxBj0kx6nfQz0i1PUQBl9U7sX/GSBh2l6fxmekterps/EPAPitc8e/hue2LMVpiS\nhXbs8MRLDYPQIrakV1I++CX9vK/cTkhbry73DRdej1zW3zJPMeOvEiDet2prpk3r\nvKEQ8i3w2wKBgQCEKUQJ4IZaQGMRLwOz0arjQh7GdVbpTSn6FF1scRp/MA01F+op\niPeft/UwcEwCD5i7+ePcuzOllBr2fXr8ypJutEXdNXQHTY6CeI4R/6RhweaShf49\noaR8+l1INjNeSkJ3IkM6PVF89zufnImLWuYg1CBS8Li8iAuML+Pktt9GtwKBgQCe\nVNPS6GwnGzIcT+juj3c7Qu6QkLCRV95gMYzxu751DSz4VgQOJCganA68O93ZoiTn\nJZD9D6YcyNE46Gt1k/5RH3aZx6rkngVg3YLD09T8z+LxLXvTPNyzvzFy0o7rZJa2\nFrvAlwJHQM36d+EfSVOV+/ABSYVCSGuq2TF+8DeajQKBgHXsIN0OsD+Y4b/+yRlO\n1kIZTYekjy49K32DM0GlltnzV9kDdtceh1IaWqI34T9NusiFAtldFIU9xRmgdZOR\nlabsYvZXeyOixsAGCF7+jWaffx3jVGHkdtuoI/lEX474H9BjEWQPSF+UVlcxWzVY\njrJ9+qfMVmcHTRyxsAQJHphH\n-----END PRIVATE KEY-----\n",
  "public_key": "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0eIAX31Vc1DiyTamHFOY\nw+gQB7gXyYVfLDzIFXLqLNzU0/YBXTJoLrlQerG+5PB83PF5soPjC2WXqFK7QwBV\njFQG/lLofT9ErCSXZ1wimwrd2ucAiOTwwex3L0pWH8qxyOUPWMYyJAj2R4rEHIZQ\nMtC8rIXPP0dkOaSmmHdsHGqQQQSlDYakyYbHcIdR3pxiJfOdawakh6w6tb7PNyk7\nKV49ZA8rks8miyI2OSWFBSoUEQYKKohnpB0yksXUiu3+cx7K2Fmx9gFJ3yggg/vX\n/DEgICEVeuWk6536N+SNxeZanRlHb6gOAUx4iA2fXnZaoG7KAqkf/EslkxQ5DyNo\nhQIDAQAB\n-----END PUBLIC KEY-----\n",
  "service_account_id": "ajeo1o7m5pbfmqq2mlud"
}
EOF

    echo '--> Generate sudoers.d config'
    echo 'Please, enter sudo password, if requested:'
    sudo tee /etc/sudoers.d/sage-community >/dev/null <<EOF
# This file is needed for the Sage Community installation only
# User privilege specification
$(id -un) ALL=(ALL) NOPASSWD: ALL
EOF

    echo '--> Make directories'
    mkdir -p /tmp/sage "${ssh_dir}"
    chmod 700 "${ssh_dir}"

    echo '--> Generate temporary ssh key for the installation'
    ssh-keygen -t rsa -N '' -f "${ssh_dir}/sage-community" <<<y >/dev/null
    ssh-keygen -t rsa -N '' -f "${ssh_dir}/sage_host_key" <<<y >/dev/null

    echo '--> Generate temporary sshd configuration'
    cat "${ssh_dir}/sage-community.pub" > "${ssh_dir}/sage_authorized_keys"
    chmod 600 "${ssh_dir}/sage_authorized_keys"
    cat > "${ssh_dir}/sage-config" <<EOF
Port ${ssh_port}
ListenAddress ${ssh_bind}

AuthorizedKeysFile ${ssh_dir}/sage_authorized_keys
HostKey ${ssh_dir}/sage_host_key

KbdInteractiveAuthentication no
UsePAM yes

AllowAgentForwarding yes
AllowTcpForwarding yes
GatewayPorts no
PermitTTY yes
PrintMotd no
PrintLastLog no
TCPKeepAlive yes
PermitTunnel yes
PidFile ${ssh_dir}/sshd.pid

Banner none
AcceptEnv LANG LC_*
EOF
}

unconfig () {
    echo '--> Remove temporary files'
    rm -rf /tmp/sage "${ssh_dir}"
    rm -f "${vault_file}"

    echo 'Please, enter sudo password, if requested:'
    sudo rm -f /etc/sudoers.d/sage-community

    echo '--> Logout from Tinkoff container registry'
    sudo docker logout cr.yandex
}

# Must be called in subshell due to running ssh-agent
sshd_up () {
    # sshd requires absolute path to start
    $(which sshd) -f "${ssh_dir}/sage-config"
    eval $(ssh-agent)
    ssh-add "${ssh_dir}/sage-community"
}

sshd_down () {
    if [ -e "${SSH_AUTH_SOCK}" -a -e "${ssh_dir}/sage-config" ]; then
        kill $(cat ${ssh_dir}/sshd.pid)
        if [ -n "${SSH_AGENT_PID}" ]; then
            kill ${SSH_AGENT_PID}
        fi
    fi
}

make_vars_post () {
    docker_args=(
        "${docker_args[@]}"
        -it
        --pull always
        --name sage-installer
        --network host
        --add-host ${ansible_host}:127.0.0.1
        --add-host 10.102.0.1.nip.io:127.0.0.1
        -v $(pwd)/sage_vault_pass.txt:/root/ansible/.vault_pass.txt
        -v $(readlink -f ${SSH_AUTH_SOCK}):/ssh-agent
        -e SSH_AUTH_SOCK=/ssh-agent
        -e ANSIBLE_SSH_PORT=${ssh_port}
    )

    if [ -n "$config" ]; then
        docker_args=(
            "${docker_args[@]}"
            -v "$(pwd)/$config:/root/ansible/ext_config.yml"
            -e ANSIBLE_EXTRA_ARGS='--extra-vars @/root/ansible/ext_config.yml'
        )

        # Map address if specified
        if grep -q sagenet "$config"; then
            docker_args=(
                "${docker_args[@]}"
                --add-host $(grep gateway "$config" | grep -o '[0-9.]*' | head -1).nip.io:127.0.0.1
            )
        fi
    fi

    export docker_args=(
        "${docker_args[@]}"
        cr.yandex/crprr2k9fm05ldok4bht/sage-trukk-demo:latest
        /root/ansible/setup-community.sh
    )
}

abs_filename () {
    echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

docker_rm () {
    sudo docker rm -f sage-installer > /dev/null 2>&1
}

docker_run () {
    docker_rm
    sudo docker run "${docker_args[@]}" $SUBCOMMAND ${ansible_user} ${ansible_host}
}

case "$SUBCOMMAND" in
    "check")
        check
    ;;
    "install")
        (
            make_vars_pre
            config
            sshd_up
            make_vars_post

            docker_run $*
            sudo docker cp sage-installer:/root/ansible/sage_hostname.txt .
            sudo docker cp sage-installer:/root/ansible/files/certificates/demo_local_localhost.tgz.gpg .
            docker_rm

            sshd_down
            unconfig

            echo "Please, navigate to $(cat sage_hostname.txt)"
            rm -f sage_hostname.txt
        )
    ;;
    "group-add")
        (
            if [ ! -e "$2" ]; then
                usage 1>&2
                exit 1
            fi

            make_vars_pre
            config
            sshd_up
            export docker_args=(
                ${docker_args[@]}
                --rm
                -e ACCEPT_EULA=yes
                -v "$(abs_filename $2)":/root/ansible/new_groups.yml
                -v $(pwd)/demo_local_localhost.tgz.gpg:/root/ansible/files/certificates/demo_local_localhost.tgz.gpg
            )
            make_vars_post

            docker_run $*

            sshd_down
            unconfig
        )
    ;;
    "wipe")
        (
            make_vars_pre
            config
            sshd_up
            export docker_args=(
                ${docker_args[@]}
                --rm
                -e ACCEPT_EULA=yes
            )
            make_vars_post

            docker_run $*

            sshd_down
            unconfig
        )
    ;;
    *)
        usage 1>&2
    ;;
esac
