#!/bin/sh
# cron job

freshdeskapikey='<redacted>'

dstnumber='+15555555555'
twilioaccountsid='<redacted>'
twilionumber='+15555555555'
twilioauthtoken='<redacted>'

ticketdir=/var/tickets # Create beforehand
newtickets="$ticketdir"/new
oldtickets="$ticketdir"/old
count="$ticketdir"/count
smslog="$ticketdir"/sms.log
curllog="$ticketdir"/curl.log

writelog() {
	printf "%s\n" "$(date): $1"
}

sendsms() {
	curl -s -X POST \
		"https://api.twilio.com/2010-04-01/Accounts/$twilioaccountsid/Messages.json" \
		--data-urlencode "Body=$message" \
		--data-urlencode "From=$twilionumber" \
		--data-urlencode "To=$dstnumber" \
		-u "$twilioaccountsid:$twilioauthtoken" >> "$curllog"
	[ "$?" -eq 0 ] && writelog "$message" >> "$smslog"
	printf "\n" >> "$curllog"
	exit 0
}

true > "$newtickets"
true > "$count"

# If the ticketing system ever hits 100k tickets, change {5} -> {6}
curl -s -u "$freshdeskapikey":X -X GET \
	https://<redacted>.freshdesk.com/api/v2/tickets | tr "," "\n" | \
	grep -E '"id":[0-9]{5}' | cut -d ":" -f 2 >> "$newtickets"

while read line; do
	if ! grep "$line" "$oldtickets" >/dev/null 2>&1; then
		printf "%s\n" "$line" | tee -a "$count" >> "$oldtickets"
	fi
done < "$newtickets"

if [ "$(wc -l < "$count")" -eq 0 ]; then
	writelog "Nothing to send" >> "$smslog"
	exit 0
elif [ "$(wc -l < "$count")" -eq 1 ]; then
	message="Ticket #$(cat "$count") has been created."
	sendsms
else
	while read line; do
		printf "%s" "#$line, "
	done < "$count" | rev | cut -d "," -f 2- | rev > trimmed
	message="Tickets $(cat trimmed) have been created."
	sendsms
fi

exit 1
