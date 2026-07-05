FROM juewuy/shellcrash:latest

ENV CRASHDIR=/etc/ShellCrash \
    SHELLCRASH_DATADIR=/data \
    SHELLCRASH_DEFAULTS_DIR=/usr/local/share/shellcrash/defaults \
    TZ=Asia/Shanghai

USER root

COPY init.sh menu.sh start.sh /etc/ShellCrash/
COPY cn_ip.txt cn_ipv6.txt version README.md /etc/ShellCrash/
COPY fake_ip_filter.list fallback_filter.list servers.list singbox_providers.list clash_providers.list /usr/local/share/shellcrash/defaults/configs/
COPY task.list task_en.list /usr/local/share/shellcrash/defaults/task/
COPY cn_ip.txt cn_ipv6.txt /usr/local/share/shellcrash/defaults/data/
COPY libs /etc/ShellCrash/libs
COPY menus /etc/ShellCrash/menus
COPY starts /etc/ShellCrash/starts
COPY docker/entrypoint.sh /usr/local/bin/shellcrash-entrypoint

RUN set -eux; \
    mkdir -p /data /tmp/ShellCrash; \
    for dir in configs yamls jsons ruleset ui task tools; do \
        rm -rf "/etc/ShellCrash/${dir}"; \
        ln -s "/data/${dir}" "/etc/ShellCrash/${dir}"; \
    done; \
    find /etc/ShellCrash /usr/local/bin/shellcrash-entrypoint -type f -exec sed -i 's/\r$//' {} +; \
    sed -i '/ShellCrash\/menu.sh/d; /export CRASHDIR=/d; /alias .*crash=/d' /etc/profile 2>/dev/null || true; \
    find /etc/ShellCrash -name '*.sh' -exec chmod 755 {} +; \
    chmod 755 /etc/ShellCrash/init.sh /etc/ShellCrash/menu.sh /etc/ShellCrash/start.sh /usr/local/bin/shellcrash-entrypoint; \
    printf '%s\n' '#!/bin/sh' 'CRASHDIR=${CRASHDIR:-/etc/ShellCrash}' 'export CRASHDIR' 'exec "$CRASHDIR/menu.sh" "$@"' >/usr/local/bin/crash; \
    chmod 755 /usr/local/bin/crash; \
    chown -R 1000:1000 /etc/ShellCrash /data /tmp/ShellCrash /usr/local/bin/shellcrash-entrypoint /usr/local/share/shellcrash

USER 1000:1000
WORKDIR /etc/ShellCrash

ENTRYPOINT ["/usr/local/bin/shellcrash-entrypoint"]
CMD ["start"]
