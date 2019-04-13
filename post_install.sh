#!/bin/sh
set -eu

gitea_work_dir=/var/db/gitea
/usr/local/bin/pluginset gitea_work_dir "$gitea_work_dir"

gitea_user=git
/usr/local/bin/pluginset gitea_user "$gitea_user"

gitea_user_home="$(getent passwd "$gitea_user" | cut -d : -f 6)"
/usr/local/bin/pluginset gitea_user_home "$gitea_user_home"

gitea_internal_token="$(gitea generate secret INTERNAL_TOKEN)"
/usr/local/bin/pluginset gitea_internal_token "$gitea_internal_token"

gitea_secret_key="$(gitea generate secret SECRET_KEY)"
/usr/local/bin/pluginset gitea_secret_key "$gitea_secret_key"

gitea_lfs_jwt_secret="$(gitea generate secret LFS_JWT_SECRET)"
/usr/local/bin/pluginset gitea_lfs_jwt_secret "$gitea_lfs_jwt_secret"

/usr/local/bin/pluginset gitea_app_name 'Gitea: Git with a cup of tea'
/usr/local/bin/pluginset gitea_domain localhost
/usr/local/bin/pluginset gitea_http_addr 127.0.0.1
/usr/local/bin/pluginset gitea_protocol http

mkdir -p "$gitea_work_dir/custom/conf" "$gitea_work_dir/data" "$gitea_work_dir/log"
chown -R "$gitea_user" "$gitea_work_dir"
chmod -R 0750 "$gitea_work_dir"
echo "Created initial state and data directories under $gitea_work_dir"

rm -rf /usr/local/etc/gitea
ln -s "$gitea_work_dir/custom" /usr/local/etc/gitea
echo "Added /usr/local/etc/gitea symlink"

rm -rf /var/log/gitea
ln -s "$gitea_work_dir/log" /var/log/gitea
echo "Added /var/log symlink"

if ! grep -q '^start_precmd=' /usr/local/etc/rc.d/gitea >/dev/null; then
  ex /usr/local/etc/rc.d/gitea <<EOEX
/^start_cmd=
-1
i

start_precmd="\${name}_prestart"

gitea_prestart() {
	/usr/local/bin/renderconfig \\
		/usr/local/share/gitea/conf/app.ini.in \\
		$gitea_work_dir/custom/conf/app.ini
	chmod 0640 $gitea_work_dir/custom/conf/app.ini
}
.
wq!
EOEX
  echo "Modified gitea rc.d script with a start_precmd"
fi

if ! grep -q 'renderconfig' /usr/local/etc/rc.d/nginx >/dev/null; then
  ex /usr/local/etc/rc.d/nginx <<EOEX
/^nginx_checkconfig()
+3
i


	if [ "\$(/usr/local/bin/pluginget gitea_protocol)" = "https" ]; then
		/usr/local/bin/renderconfig \\
			/usr/local/share/gitea/nginx/nginx.conf.https.in \\
			/usr/local/etc/nginx/nginx.conf
	else
		/usr/local/bin/renderconfig \\
			/usr/local/share/gitea/nginx/nginx.conf.http.in \\
			/usr/local/etc/nginx/nginx.conf
	fi
.
wq!
EOEX
  echo "Modified nginx rc.d script to render config"
fi

# Enable the services
sysrc -f /etc/rc.conf sshd_enable=YES
echo "Enabled sshd service"

sysrc -f /etc/rc.conf nginx_enable=YES
echo "Enabled nginx service"

sysrc -f /etc/rc.conf gitea_enable=YES
sysrc -f /etc/rc.conf "gitea_shared=$gitea_work_dir"
echo "Enabled gitea service"

# Start the services
service sshd start
echo "Started sshd service"

service nginx start
echo "Started nginx service"

service gitea start
echo "Started gitea service"
