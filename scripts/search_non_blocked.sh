#!/usr/bin/env bash

# Программа для отправки пропущеных ресурсов http и https на редуктор
# Что делает:
# 1) После выполнения процесса проверки, смотрит есть ли содержимое в /opt/reductor_satellite/var/{http,https}/1
# 2) Если есть, то для http и https создает список доменов
# 3) Отправляем это все на редуктор в provider-lists

set -eu

. /opt/reductor_satellite/etc/const

RESOLVER_HOST="192.168.100.15"


search_skip(){
	# Ищем пропуски, если файл не пустой, то обрабатываем содержимое
	local http="$MAINDIR/var/http/1"
	local https="$MAINDIR/var/https/1"
	for content in http https; do
		if [ -s "${!content}" ]; then
			render "$content" "${!content}"
		fi
	done
}

get_domains(){
	# url->domain
	local file="$1"
	grep -oE "http[^ ]*|www[^ ]*" "$file" | cut -d '/' -f3
}

render(){
	local type="$1"
	local path="$2"
	if [ "$type" == 'http' ]; then
		get_domains "$path" > "$TMPDIR/our.domain_autoblacklist"
	else
		get_domains "$path" > "$TMPDIR/our.domain_tcp_fragmented"
	fi
}

transfer_to_resolver(){
	find "$TMPDIR" -name "our*" -exec scp {} root@$RESOLVER_HOST:/app/reductor/var/lib/reductor/lists/provider/ \;
}

flush_lists(){
	ssh root@$RESOLVER_HOST rm -rf /app/reductor/var/lib/reducot/lists/provider/ || return 0
}

main(){
	search_skip
	flush_lists
	transfer_to_resolver
	ssh root@$RESOLVER_HOST /app/reductor/usr/local/Reductor/bin/append_workaround.sh
}

main
