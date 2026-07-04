FROM juewuy/shellcrash:latest

ENV CRASHDIR=/etc/ShellCrash \
    SHELLCRASH_DATADIR=/data \
    TZ=Asia/Shanghai

USER root

COPY init.sh menu.sh start.sh /etc/ShellCrash/
COPY clash_providers.list cn_ip.txt cn_ipv6.txt fake_ip_filter.list fallback_filter.list servers.list singbox_providers.list task.list task_en.list version README.md /etc/ShellCrash/
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
    find /etc/ShellCrash -name '*.sh' -exec chmod 755 {} +; \
    chmod 755 /etc/ShellCrash/init.sh /etc/ShellCrash/menu.sh /etc/ShellCrash/start.sh /usr/local/bin/shellcrash-entrypoint; \
    ln -sf /etc/ShellCrash/menu.sh /usr/local/bin/crash; \
    chown -R 1000:1000 /etc/ShellCrash /data /tmp/ShellCrash /usr/local/bin/shellcrash-entrypoint

USER 1000:1000
WORKDIR /etc/ShellCrash

ENTRYPOINT ["/usr/local/bin/shellcrash-entrypoint"]
CMD ["start"]
