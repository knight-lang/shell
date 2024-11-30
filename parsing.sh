## Sets `$Reply` To the amount of arguments the Knight function in `$1` expects. 
arity () case $1 in
	[PR]) Reply=0 ;;
	[][\$OEBCQ\!LD,AV\~]) Reply=1 ;;
	[-+\*/%^\?\<\>\&\|\;=W]) Reply=2 ;;
	[GI]) Reply=3 ;;
	S) Reply=4 ;;
	*) die 'unknown function: %s' "$1" ;;
esac

Line=
next_expr () {
	# Strip leading whitespace and comments
	while
		Line=$(printf %s "$Line" | sed 's/^[[:space:]:()]*//; /^#/d')
		[ -z "$Line" ]
	do
		IFS= read -r Line || return
	done

	# Parse out the token. Note that
	case $Line in
		# Integers.
		[0-9]*)
			Reply=${Line%%[!0-9]*}
			while [ ${Reply#0} != $Reply ]; do
				Reply=${Reply#0}
			done
			Reply=i$Reply
			Line=${Line#"${Reply#?}"} ;;

		# Variables
		[a-z_]*)
			Reply=v${Line%%[!a-z_0-9]*}
			Line=${Line#"${Reply#?}"} ;;

		# Strings.
		[\'\"]*)
			quote=$(printf %c "$Line")
			Line=${Line#?}
			while [ "${Line%$quote*}" = "$Line" ]
			do
				IFS= read -r tmp || \
					die 'missing ending %s quote' $quote
				Line=$Line$NEWLINE$tmp
			done
			Reply=s${Line%%$quote*}
			Line=${Line#"${Reply#s}"$quote} ;;

		# Array literal
		@*)
			Reply=a0
			Line=${Line#?} ;;

		# Functions
		[][TFNPRBCQDOLAWVIGSE\$+\*/%^\<\>\?\&\|\;\~\!=,-]*)
			Reply=$(printf %c "$Line")

			# Strip out the function name
			case $Reply in
				[A-Z])
					Line=${Line#"${Line%%[!A-Z_]*}"};;
				*)
					Line=${Line#?}
			esac

			# Handle function literals specially.
			case $Reply in
				@) Reply=a0 ;;
				[TFN]) ;;
				*) parse_fn "$Reply"
			esac ;;
		*) die "unknown token start: '%c'" "$Line"
	esac
}


Next_Fn_Ref_Idx=0
parse_fn () {
	arity "$1"
	set -- "f$1" "$Reply"

	while [ $2 -gt 0 ]; do
		next_expr || return

		# Expression wasn't an ast, just assign it 
		if [ "${Reply#f}" = "$Reply" ]; then
			set -- "$1$FN_SEP$Reply" $(( $2 - 1 ))
		else
			# Expression was a function, we have to get a ref to it
			eval "F$((Next_Fn_Ref_Idx += 1))=\$Reply"
			set -- "$1${FN_SEP}F$Next_Fn_Ref_Idx" "$(( $2 - 1 ))"
		fi
	done

	Reply=$1
}
