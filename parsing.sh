arity () case $1 in
	[PR]) Reply=0 ;;
	[][\$OEBCQ\!LD,AV\~]) Reply=1 ;;
	[-+\*/%\^\?\<\>\&\|\;\=W]) Reply=2 ;;
	[GI]) Reply=3 ;;
	S) Reply=4 ;;
	*) die 'unknown function: %s' "$1" ;;
esac

Next_Fn_Ref_Idx=0
parse_fn () {
	local arity result="f$1"

	arity "$1"
	arity=$Reply

	while [ $arity -ne 0 ]; do
		next_expr || return
		# Expression wasn't an ast, just assign it 
		if [ "${Reply#f}" = "$Reply" ]; then
			result="$result$FN_SEP$Reply"
		else
			# Expression was a function, we have to get a refernece to it
			eval "F$Next_Fn_Ref_Idx=\$Reply"
			result=$result${FN_SEP}F$Next_Fn_Ref_Idx
			Next_Fn_Ref_Idx=$((Next_Fn_Ref_Idx + 1))
		fi

		arity=$(( arity - 1 ))
	done
	Reply=$result
}

Line=
next_expr () {
	# Strip leading whitespace and comments
	while
		Line=$(printf %s "$Line" | sed 's/^[[:blank:]:(){}]*//; /^#/d')
		[ -z "$Line" ]
	do
		IFS= read -r Line
	done

	# Parse out the token
	case $Line in
		# Integers; cant use `0-9` cause it's locale-dependent technically
		[0123456789]*)
			Reply=i${Line%%[!0123456789]*}
			Line=${Line#"${Reply#?}"} ;;

		# Variables
		[abcdefghijklmnopqrstuvwxyz_]*)
			Reply=v${Line%%[!abcdefghijklmnopqrstuvwxyz_0123456789]*}
			Line=${Line#"${Reply#?}"} ;;

		# Strings; this have to be handled specially cause of multilined stuff
		[\'\"]*)
			_quote=$(printf %c "$Line")
			Line=${Line#?}
			while [ "${Line%$_quote*}" = "$Line" ]; do
				IFS= read -r _tmp || die "missing ending $_quote quote."
				Line=${Line}${NEWLINE}${_tmp}
			done
			Reply=s${Line%%"$_quote"*}
			Line=${Line#"${Reply#s}$_quote"} ;;

		# Array literal
		@*)
			Reply=a0
			Line=${Line#?} ;;

		# Functions
		[][TFNPRBCQDOLAWVIGSE\$\+\*\/\%\^\<\>\?\&\|\;\~\!\=\,-]*)
			Reply=$(printf %c "$Line")

			case $Reply in
				[TFNPRBCQDOLAVWIGSE])
					_tmp=${Line%%[!ABCDEFGHIJKLMNOPQRSTUVWXYZ_]*}
					Line=${Line#"$_tmp"} ;;
				*)
					Line=${Line#?}
			esac

			case $Reply in
				@) Reply=a0 ;;
				[TFN]) ;;
				*) parse_fn "$Reply"
			esac ;;
		*) die "unknown token start: '%c'" "$Line"
	esac
}
