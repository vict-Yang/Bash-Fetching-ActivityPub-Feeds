#!/bin/bash

# input part
handle=$1
maxArticle=10
shift 1
while getopts "n:" option; do
	case $option in
	n)
		# echo "received -n with $OPTARG"
		maxArticle=$OPTARG
		;;
	*)
		echo "invalid option $OPTARG"
		;;
	esac
done

# handle example @hntooter@mastodon.social
username=$(cut -d '@' -f 2 <<<$handle)
domain=$(cut -d '@' -f 3 <<<$handle)
wf_url="https://$domain/.well-known/webfinger"
response=$(curl -X GET \
	-H 'Accept: application/jrd+json' \
	"$wf_url?resource=acct:$username@$domain" 2>/dev/null)

neededjson=$(jq '.links' <<<$response |
	jq '.[] | select(.type | contains("application/activity+json"))?')
user_url=$(jq -r '.href' <<<$neededjson)
user_json=$(curl -X GET -H \
	'Accept: application/ld+json; profile="https://www.w3.org/ns/activitystreams"' \
	$user_url 2>/dev/null)
feed_url=$(jq -r '.outbox' <<<$user_json)
# echo $feed_url
start_fetch() {
	cnt=0
	url=$1
	while true; do
		feed=$(
			curl -X GET -H \
				'Accept: application/ld+json; profile="https://www.w3.org/ns/activitystreams"' \
				$url 2>/dev/null
		)
		# echo $feed | jq
		canIterate=$(jq 'has("orderedItems")' <<<$feed)
		if [[ $canIterate == "true" ]]; then
			articles=$(jq -cr '.orderedItems[] | select(.type == "Create")' <<<$feed)
			while IFS= read -r line; do
				pbtime=$(jq -cr '.published' <<<$line) # published time
				html=$(jq -cr '.object.content' <<<$line)
				echo  "==="
                date -d "$pbtime" -R
                w3m -dump -T text/html <<< $html
				cnt=$(($cnt + 1))
				if [[ $cnt == $maxArticle ]]; then
					return
				fi
			done <<< $articles
		fi

		nexturl=""
		if [[ $(jq 'has("first")' <<<$feed) == "true" ]]; then
			nexturl=$(jq -cr '.first' <<<$feed)
		elif [[ $(jq 'has("next")' <<<$feed) == "true" ]]; then
			nexturl=$(jq -cr '.next' <<<$feed)
		fi

		if [[ -n $nexturl ]]; then
			url=$nexturl
		else
			return
		fi
	done
}
start_fetch $feed_url
