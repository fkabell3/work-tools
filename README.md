# Work Tools
These are notification tools I use for work. The goal is to convert help desk app notifications into loud, obnoxious, hard-to-miss ringtones so I am notified when a ticket comes in. They have varying levels of reliability due to the technologies they depend on.

# freshdeskapi.sh
Queries FreshDesk (help desk) API for the 30 most recent ticket IDs and stores them in a file. Does the same thing a minute later (cron job), and compares the difference. If there is a new ticket ID, there must be a new ticket so send an SMS. Most reliable.

# freshdeskemail.sh
Does the same thing but parses emails instead of using API (I didn't know FreshDesk had an API at the time). Has more complexity so is less reliable. Sometimes the messages come out malformed.

# notify-send
Forward any iOS notification as an SMS. notify-send is usually a binary package installed on your computer for displaying notifications. The iOS jailbreak tweak ForwardNotifier (com.greg0109.forwardnotifier) makes use of this by calling notify-send on the remote computer via SSH. This tweak is a drop-in replacement for the package on the remote computer. You trick the tweak by changing the remote SSH server to localhost and placing this script at /bin/notify-send. Then whenever the tweak is triggered, this script is called on the iDevice and thus an SMS is sent. The tweak crashes SpringBoard often (at least on iOS 14) so don't rely on it for anything important.
