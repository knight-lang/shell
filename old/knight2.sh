#!/bin/sh

die () {
	echo "$@" >&2
	exit 1
}
alias eecho='>&2 echo'

next_token () {
	# Strip out comments and leading whitespace
	old_len=0
	until [ $old_len -eq ${#input} ] ; do
		old_len=${#input}
		input="${input##[[:blank:]]}"
		input="${input#\#*$'\n'}"
	done

	case "${input%"${input#?}"}" in
		[[:digit:]])
			number="${input%%[^[:digit:]]*}"
			input="${input#"$number"}"
			;;
		*)
			echo "something else! "${input%"${input#?}"}""
			;;
	esac
}


input=$' # oops\n#there\nOUTPUT - + 1 2 4'
input='123aFALSE 44'
next_token


return

doit () {
	IFS= read -r line || return 0
	echo "read: ${line}"
	doit
}

doit2 () { doit; } <$input
input=$0
doit2

exit

f () { read -r line; echo "<$line>" } <$0

next_token () {
	read -r line
	# while [ -n "$line" ]; do
	line="${line##\#*$'\n'}"
	echo $line
	# done
	# # IFS=$'\0' read -r line
	# # echo $line
	# # if we haven't already been reading a line,
	# # then read the next one in.
	# while true; do
	# 	line=$(printf %s "$line" | sed 's/[][{}()[:blank:]:]*//')
	# 	line=${line##\#*}
	# 	[ -n "$line" ] && break
	# 	read -r line || die "nope"
	# done
} <$input

next_token <$input
echo $line
