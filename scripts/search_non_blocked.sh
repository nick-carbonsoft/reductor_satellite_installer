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

search_skip(){
	# Ищем пропуски, если файл не пустой, то обрабатываем содержимое
	local https="$MAINDIR/var/https/1"
	echo "Выполняем поиск пропусков"
	if [ -s "$https" ]; then
			IS_SKIPPED=1
			render "$https"
	else
			return 0
	fi
}

get_domains(){
	# url->domain
	local file="$1"
	grep -oE "https[^ ]*|www[^ ]*" "$file" | cut -d '/' -f3
}

render(){
	local path="$1"
	echo "Обнаружены пропуски по https"
	get_domains "$path" > "$TMPDIR/our.domain_resolver_blacklist"
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
	ssh root@$REDUCTOR_SNI chroot /app/reductor /usr/local/Reductor/bin/append_workaround.sh
}

main
