#!/usr/bin/env bash

# Программа для отправки пропущеных ресурсов http и https на редуктор
# Что делает:
# 1) После выполнения процесса проверки, смотрит есть ли содержимое в /opt/reductor_satellite/var/{http,https}/1
# 2) Если есть, то для http и https создает список доменов
# 3) Отправляем это все на редуктор в provider-lists

set -eu

. /opt/reductor_satellite/etc/const

REDUCTOR_SNI="10.50.100.122"
IS_SKIPPED=0

get_lists(){
	find $MAINDIR/var/{http,https} -type f -name 1
}

search_skip(){
	# Ищем пропуски, если файл не пустой, то обрабатываем содержимое
	local lists
	lists="$(get_lists)"
	echo "Выполняем поиск пропусков"
	for list in $lists; do
		if [ -s "$list" ]; then
			IS_SKIPPED=1
			render "$list"
		fi
	done
}

get_domains() {
	# url->domain
	local file="$1"
	grep -oE "http[^ ]*|www[^ ]*" "$file" | cut -d '/' -f3
}

render(){
	local path="$1"
	local proto
	proto="${path#*var/}"
	proto=${proto%/1}
	if [ "$proto" == "http" ]; then
		echo "Обнаружены пропуски в http"
		get_domains "$path" > "$TMPDIR/our.domain_workaround_http"
	else
		echo "Обнаружены пропуски в https"
		get_domains "$path" > "$TMPDIR/our.domain_resolver_blacklist"
	fi
}

transfer_to_resolver(){
	find "$TMPDIR" -name "our*" -exec scp {} root@$REDUCTOR_SNI:/app/reductor/var/lib/reductor/lists/provider/ \;
}

flush_lists(){
	ssh root@$REDUCTOR_SNI rm -f /app/reductor/var/lib/reductor/lists/{provider,resolver}/* || return 0
}

main(){
	search_skip
	if [ "$IS_SKIPPED" -ne '1' ]; then
		echo "Пропусков не обнаружено"
		return 0
	fi
	flush_lists
	transfer_to_resolver
	ssh root@$REDUCTOR_SNI chroot /app/reductor /usr/local/Reductor/bin/append_blacklist.sh
}

main
