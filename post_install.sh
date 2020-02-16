#!/bin/sh
set -eu

log() {
  echo "$1" >>/root/PLUGIN_INFO
}

plugin services set sshd nginx gitea

gitea_work_dir=/var/db/gitea
plugin config set gitea_work_dir "$gitea_work_dir"

gitea_user=git
plugin config set gitea_user "$gitea_user"

gitea_user_home="$(getent passwd "$gitea_user" | cut -d : -f 6)"
plugin config set gitea_user_home "$gitea_user_home"

gitea_internal_token="$(gitea generate secret INTERNAL_TOKEN)"
plugin config set gitea_internal_token "$gitea_internal_token"

gitea_secret_key="$(gitea generate secret SECRET_KEY)"
plugin config set gitea_secret_key "$gitea_secret_key"

gitea_lfs_jwt_secret="$(gitea generate secret LFS_JWT_SECRET)"
plugin config set gitea_lfs_jwt_secret "$gitea_lfs_jwt_secret"

plugin config set gitea_app_name 'Gitea: Git with a cup of tea'
plugin config set gitea_domain localhost
plugin config set gitea_http_addr 127.0.0.1
plugin config set gitea_nginx_mode http

mkdir -p "$gitea_work_dir/custom/conf" "$gitea_work_dir/data" \
  "$gitea_work_dir/log"
chown -R "$gitea_user" "$gitea_work_dir"
chmod -R 0750 "$gitea_work_dir"
log "Created initial state and data directories under $gitea_work_dir"

rm -rf /usr/local/etc/gitea
ln -s "$gitea_work_dir/custom" /usr/local/etc/gitea
log "Added /usr/local/etc/gitea symlink"

rm -rf /var/log/gitea
ln -s "$gitea_work_dir/log" /var/log/gitea
log "Added /var/log symlink"

if ! grep -q '^start_precmd=' /usr/local/etc/rc.d/gitea >/dev/null; then
  ex /usr/local/etc/rc.d/gitea <<EOEX
/^start_cmd=
-1
i

start_precmd="\${name}_prestart"

gitea_prestart() {
	/usr/local/bin/plugin template render \\
		/usr/local/share/gitea/conf/app.ini.in \\
		$gitea_work_dir/custom/conf/app.ini || return 1
	chmod 0640 $gitea_work_dir/custom/conf/app.ini
}
.
wq!
EOEX
  log "Modified gitea rc.d script with a start_precmd"
fi

if ! grep -q 'template render' /usr/local/etc/rc.d/nginx >/dev/null; then
  ex /usr/local/etc/rc.d/nginx <<EOEX
/^nginx_checkconfig()
+3
i


	nginx_mode="\$(/usr/local/bin/plugin config get gitea_nginx_mode || echo '')"
	case "\$nginx_mode" in
		https|http)
			/usr/local/bin/plugin template render \\
				"/usr/local/share/gitea/nginx/nginx.conf.\${nginx_mode}.in" \\
				/usr/local/etc/nginx/nginx.conf || return 1
			;;
		*)
			echo "nginx_mode could not be determined; gitea_nginx_mode=\$nginx_mode" >&2
			return 1
			;;
	esac
.
wq!
EOEX
  log "Modified nginx rc.d script to render config"
fi

# Enable the services
sysrc -f /etc/rc.conf sshd_enable=YES
log "Enabled sshd service"

sysrc -f /etc/rc.conf nginx_enable=YES
log "Enabled nginx service"

sysrc -f /etc/rc.conf gitea_enable=YES
sysrc -f /etc/rc.conf "gitea_shared=$gitea_work_dir"
log "Enabled gitea service"

# Start the services
service sshd start
log "Started sshd service"

service nginx start
log "Started nginx service"

service gitea start
log "Started gitea service"
