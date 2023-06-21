#!/bin/sh
# cron job

mail=/var/mail/sms
smslog=/var/log/sms.log
curllog=/var/log/curl.log

dst_number='+15555555555'
twilio_account_sid='<redacted>'
twilio_number='+15555555555'
twilio_auth_token='<redacted>'

parsesubjectline() {
	case "$1" in
		groupassign) string="Assigned to Group -"
			action="assigned to your group";;
		reply) string="New Reply Received -"
			if parsemailaddress | grep \@ >/dev/null 2>&1; then
				action="commented by $(parsemailaddress)"
			elif parsemailaddress base64 | grep \@ >/dev/null \
				2>&1; then
				action="commented by $(parsemailaddress base64)"
			else
				action="has a new comment"
			fi;;
		reopen) string="Ticket re-opened -"
			action="reopened";;
	esac
	subjectline=$(grep "^Subject: F[Ww]: $string" "$mail")
	status="$?"
	ticketname="$(printf "%s" "$subjectline" | cut -d - -f 2- | \
		awk '{$1=$1};1')"
	return "$status"
}

parseticketnum() {
	if [ "$1" = base64 ]; then
		basename "$(sed 1,/base64/d $mail | base64 --decode \
			2>/dev/null | grep \
			'^https://<redacted>.freshdesk.com/helpdesk/tickets/')"
	else
		basename "$(grep \
			'^https://<redacted>.freshdesk.com/helpdesk/tickets/' \
			$mail)"
	fi | tr -d '\r'
}

parsemailaddress() {
	if [ "$1" = base64 ]; then
		sed 1,/base64/d $mail | base64 --decode 2>/dev/null | \
			grep -A 2 \
			'^The customer has responded to the ticket.'
	else
		grep -A 2 '^The customer has responded to the ticket.' \
			"$mail"
	fi | tail -n 1 | sed s/\<// | sed s/\>// | \
		sed 's/&lt;//' | sed 's/&gt;br//' | \
		sed 's/.com/.c_m/' | sed 's/.cc/_cc/'
	# Obfuscate email addresses so SMS won't get silently dropped
}

if [ -s "$mail" ]; then
	# If the ticketing system ever hits 100k tickets,
	# change {5} -> {6}
	if parseticketnum | grep -E '^[0-9]{5}$' >/dev/null 2>&1; then
		ticketnum="#$(parseticketnum)"
	elif parseticketnum base64 | grep -E '^[0-9]{5}$' >/dev/null \
		2>&1; then
		ticketnum="#$(parseticketnum base64)"
	else
		ticketnum=
	fi
	# Works on GNU & BusyBox but not on OpenBSD for some reason
	#if grep 'support@<redacted>.com\|www.<redacted>.com' "$mail" \
	if grep 'support@<redacted>.com' "$mail" >/dev/null 2>&1 || \
		grep 'www.<redacted>.com' "$mail" >/dev/null 2>&1; then
		message="<redacted> has sent a notification."
	elif [ "$ticketname" = \
		"<redacted> Weather Alert" ]; then
		message="<redacted> has sent a <redacted> weather alert."
	else
		for subject in groupassign reply reopen; do
			parsesubjectline "$subject" && break
		done
		message="Ticket $ticketnum \`$ticketname' $action"
	fi
	if [ -n "$message" ]; then
		curl -X POST \
			"https://api.twilio.com/2010-04-01/Accounts/$twilio_account_sid/Messages.json" \
			--data-urlencode "Body=$message" \
			--data-urlencode "From=$twilio_number" \
			--data-urlencode "To=$dst_number" \
			-u "$twilio_account_sid:$twilio_auth_token" >> "$curllog"
		[ "$?" -eq 0 ] && printf "%s\n" "$(date): $message" >> "$smslog"
		printf "\n" >> "$curllog"
		cat "$mail" >> /var/mail/sms.bak
		true > "$mail"
		message=
	fi
else
	printf "%s\n" "Nothing to send!"
fi
