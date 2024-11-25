Next_Ary_Ref_Idx=0

new_ary () {
	Reply=a$#

	for _arg; do
		if [ "${_arg#a}" = "$_arg" ]; then
			Reply=$Reply$ARY_SEP$_arg
		else
			# readonly
			eval "A$Next_Ary_Ref_Idx=\$_arg"
			Reply=$Reply${ARY_SEP}A$Next_Ary_Ref_Idx
			Next_Ary_Ref_Idx=$((Next_Ary_Ref_Idx + 1))
		fi
	done
}

alias explode-array-at-arg1='
IFS=$ARY_SEP && set -o noglob
set -- $1 && set +o noglob && unset IFS
'

ary_join () {
	# We have to have `result` be local because `to_str` will clobber `Reply`.
	local sep=$1 result=
	shift

	explode-array-at-arg1
	shift # delete `aLEN` prefix

	for _arg; do
		to_str "$_arg"
		result=$result${result:+$sep}$Reply
	done

	Reply=$result
}
