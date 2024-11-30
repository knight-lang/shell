## Sets `$Reply` To the amount of arguments the Knight function in `$1` expects. 
arity () case $1 in
	[PR])                    Reply=0 ;;
	[][\$OEBCQ\!LD,AV\~])    Reply=1 ;;
	[-+\*/%^\?\<\>\&\|\;=W]) Reply=2 ;;
	[GI])                    Reply=3 ;;
	S)                       Reply=4 ;;
	*) die 'unknown function: %s' "$1" ;;
esac

## Line is a global variable used by `next_expr` to keep track of the current
# line we're on. We need this because `read` goes line-by-line.
Line=

## Returns the next expression from stdin, putting the response in `$Reply`. The
# remainder of the input line is stored in `$Line`, which will be read the next
# time this function is called.
next_expr () {
	# Strip leading whitespace and comments
	while
		# This will almost always be faster than spinning up a pipe to
		# sed, as it's rare we'll have loads of whitespace chars at the
		# front.
		while [ "${Line#[[:space:]:()]}" != "$Line" ]; do
			Line=${Line#?}
		done

		[ -z "$Line" ] || [ "${Line#'#'}" != "$Line" ] # Delete comments
	do
		IFS= read -r Line || return
	done

	## Parse the token we just read.
	case $Line in
	# Integers
	[0-9]*)
		Reply=${Line%%[!0-9]*}
		Line=${Line#"$Reply"}

		# Strip leading 0s.
		while [ "${Reply#0}" != "$Reply" ]; do
			Reply=${Reply#0}
		done

		Reply=i${Reply:-0} ;; # `:-0` in case it's just 0.

	# Variables
	[a-z_]*)
		Reply=v${Line%%[!a-z_0-9]*}
		Line=${Line#"${Reply#?}"} ;;

	# Strings
	[\'\"]*)
		quote=$(printf %c "$Line")
		Line=${Line#?}
		while [ "${Line%$quote*}" = "$Line" ]; do
			IFS= read -r tmp || die 'missing ending %s quote' $quote
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
		[A-Z]) Line=${Line#"${Line%%[!A-Z_]*}"};;
		*)     Line=${Line#?}
		esac

		# Parse non-function-literals; fn literals are already parsed.
		[ -n "${Reply#[TFN]}" ] && parse_fn "$Reply"
		echo $Reply ;;

	# Everything else is undefined.
	*)
		die "unknown token start: '%c'" "$Line"
	esac
}


Next_Fn_Ref_Idx=0
parse_fn () {
	arity "$1"
	set -- "f$1" $Reply

	while [ $2 -gt 0 ]; do
		next_expr || return

		# Expression wasn't an ast, just assign it 
		if [ "${Reply#f}" = "$Reply" ]; then
			set -- "$1$FN_SEP$Reply" $(($2 - 1))
		else
			# Expression was a function, we have to get a ref to it
			eval "F$((Next_Fn_Ref_Idx += 1))=\$Reply"
			set -- "$1${FN_SEP}F$Next_Fn_Ref_Idx" $(($2 - 1))
		fi
	done

	Reply=$1
}
