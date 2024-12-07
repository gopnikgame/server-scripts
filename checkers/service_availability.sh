#!/bin/bash
shopt -s expand_aliases
Font_Black="\033[30m"
Font_Red="\033[1;31m"
Font_Green="\033[1;32m"
Font_Yellow="\033[1;33m"
Font_Blue="\e[1;34m"
Font_Purple="\033[1;35m"
Font_SkyBlue="\e[1;34m"
Font_White="\e[1;37m"
Font_Suffix="\033[0m"

while getopts ":I:M:EX:P:" optname; do
	case "$optname" in
	"I")
		iface="$OPTARG"
		useNIC="--interface $iface"
		;;
	"M")
		if [[ "$OPTARG" == "4" ]]; then
			NetworkType=4
		elif [[ "$OPTARG" == "6" ]]; then
			NetworkType=6
		fi
		;;
	"E")
		language="e"
		;;
	"X")
		XIP="$OPTARG"
		xForward="--header X-Forwarded-For:$XIP"
		;;
	"P")
		proxy="$OPTARG"
		usePROXY="-x $proxy"
		;;
	":")
		echo "Unknown error while processing options"
		exit 1
		;;
	esac

done

if [ -z "$iface" ]; then
	useNIC=""
fi

if [ -z "$XIP" ]; then
	xForward=""
fi

if [ -z "$proxy" ]; then
	usePROXY=""
elif [ -n "$proxy" ]; then
	NetworkType=4
fi

if ! mktemp -u --suffix=RRC &>/dev/null; then
	is_busybox=1
fi

UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"
UA_Dalvik="Dalvik/2.1.0 (Linux; U; Android 9; ALP-AL00 Build/HUAWEIALP-AL00)"
Media_Cookie=$(curl -s --retry 3 --max-time 10 "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/cookies")
IATACode=$(curl -s --retry 3 --max-time 10 "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/reference/IATACode.txt")
IATACode2=$(curl -s --retry 3 --max-time 10 "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/reference/IATACode2.txt" 2>&1)
TVer_Cookie="Accept: application/json;pk=BCpkADawqM0_rzsjsYbC1k1wlJLU4HiAtfzjxdUmfvvLUQB-Ax6VA-p-9wOEZbCEm3u95qq2Y1CQQW1K9tPaMma9iAqUqhpISCmyXrgnlpx9soEmoVNuQpiyGsTpePGumWxSs1YoKziYB6Wz"


checkOS() {
	ifTermux=$(echo $PWD | grep termux)
	ifMacOS=$(uname -a | grep Darwin)
	if [ -n "$ifTermux" ]; then
		os_version=Termux
		is_termux=1
	elif [ -n "$ifMacOS" ]; then
		os_version=MacOS
		is_macos=1
	else
		os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
	fi

	if [[ "$os_version" == "2004" ]] || [[ "$os_version" == "10" ]] || [[ "$os_version" == "11" ]]; then
		is_windows=1
		ssll="-k --ciphers DEFAULT@SECLEVEL=1"
	fi

	if [ "$(which apt 2>/dev/null)" ]; then
		InstallMethod="apt"
		is_debian=1
	elif [ "$(which dnf 2>/dev/null)" ] || [ "$(which yum 2>/dev/null)" ]; then
		InstallMethod="yum"
		is_redhat=1
	elif [[ "$os_version" == "Termux" ]]; then
		InstallMethod="pkg"
	elif [[ "$os_version" == "MacOS" ]]; then
		InstallMethod="brew"
	fi
}
checkOS

checkCPU() {
	CPUArch=$(uname -m)
	if [[ "$CPUArch" == "aarch64" ]]; then
		arch=_arm64
	elif [[ "$CPUArch" == "i686" ]]; then
		arch=_i686
	elif [[ "$CPUArch" == "arm" ]]; then
		arch=_arm
	elif [[ "$CPUArch" == "x86_64" ]] && [ -n "$ifMacOS" ]; then
		arch=_darwin
	fi
}
checkCPU

checkDependencies() {

	# os_detail=$(cat /etc/os-release 2> /dev/null)

	if ! command -v python &>/dev/null; then
		if command -v python3 &>/dev/null; then
			alias python="python3"
		else
			if [ "$is_debian" == 1 ]; then
				echo -e "${Font_Green}Installing python${Font_Suffix}"
				$InstallMethod update >/dev/null 2>&1
				$InstallMethod install python -y >/dev/null 2>&1
			elif [ "$is_redhat" == 1 ]; then
				echo -e "${Font_Green}Installing python${Font_Suffix}"
				if [[ "$os_version" -gt 7 ]]; then
					$InstallMethod makecache >/dev/null 2>&1
					$InstallMethod install python3 -y >/dev/null 2>&1
					alias python="python3"
				else
					$InstallMethod makecache >/dev/null 2>&1
					$InstallMethod install python -y >/dev/null 2>&1
				fi

			elif [ "$is_termux" == 1 ]; then
				echo -e "${Font_Green}Installing python${Font_Suffix}"
				$InstallMethod update -y >/dev/null 2>&1
				$InstallMethod install python -y >/dev/null 2>&1

			elif [ "$is_macos" == 1 ]; then
				echo -e "${Font_Green}Installing python${Font_Suffix}"
				$InstallMethod install python
			fi
		fi
	fi

	if ! command -v dig &>/dev/null; then
		if [ "$is_debian" == 1 ]; then
			echo -e "${Font_Green}Installing dnsutils${Font_Suffix}"
			$InstallMethod update >/dev/null 2>&1
			$InstallMethod install dnsutils -y >/dev/null 2>&1
		elif [ "$is_redhat" == 1 ]; then
			echo -e "${Font_Green}Installing bind-utils${Font_Suffix}"
			$InstallMethod makecache >/dev/null 2>&1
			$InstallMethod install bind-utils -y >/dev/null 2>&1
		elif [ "$is_termux" == 1 ]; then
			echo -e "${Font_Green}Installing dnsutils${Font_Suffix}"
			$InstallMethod update -y >/dev/null 2>&1
			$InstallMethod install dnsutils -y >/dev/null 2>&1
		elif [ "$is_macos" == 1 ]; then
			echo -e "${Font_Green}Installing bind${Font_Suffix}"
			$InstallMethod install bind
		fi
	fi

	if [ "$is_macos" == 1 ]; then
		if ! command -v md5sum &>/dev/null; then
			echo -e "${Font_Green}Installing md5sha1sum${Font_Suffix}"
			$InstallMethod install md5sha1sum
		fi
	fi

}
checkDependencies

local_ipv4=$(curl $useNIC $usePROXY -4 -s --max-time 10 api64.ipify.org)
local_ipv4_asterisk=$(awk -F"." '{print $1"."$2".*.*"}' <<<"${local_ipv4}")
local_ipv6=$(curl $useNIC -6 -s --max-time 20 api64.ipify.org)
local_ipv6_asterisk=$(awk -F":" '{print $1":"$2":"$3":*:*"}' <<<"${local_ipv6}")
local_isp4=$(curl $useNIC -s -4 --max-time 10 --user-agent "${UA_Browser}" "https://api.ip.sb/geoip/${local_ipv4}" | grep organization | cut -f4 -d '"')
local_isp6=$(curl $useNIC -s -6 --max-time 10 --user-agent "${UA_Browser}" "https://api.ip.sb/geoip/${local_ipv6}" | grep organization | cut -f4 -d '"')

ShowRegion() {
	echo -e "${Font_Yellow} ---${1}---${Font_Suffix}"
}


function MediaUnlockTest_Netflix() {
	local tmpresult1=$(curl $useNIC $usePROXY $xForward -${1} --user-agent "${UA_Browser}" -fsL  --max-time 10 "https://www.netflix.com/title/81280792" 2>&1)
	local tmpresult2=$(curl $useNIC $usePROXY $xForward -${1} --user-agent "${UA_Browser}" -fsL  --max-time 10 "https://www.netflix.com/title/70143836" 2>&1)
	local result1=$(echo $tmpresult1 | grep -oP '"isPlayable":\K(true|false)')
	local result2=$(echo $tmpresult2 | grep -oP '"isPlayable":\K(true|false)')
	
	if [[ "$result1" == "false" ]] && [[ "$result2" == "false" ]]; then
		echo -n -e "\r Netflix:\t\t\t\t${Font_Yellow}Originals Only${Font_Suffix}\n"
		return
	elif [ -z "$result1" ] && [ -z "$result2" ]; then
		echo -n -e "\r Netflix:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
		return
	elif [[ "$result1" == "true" ]] || [[ "$result2" == "true" ]]; then
		local region=$(echo $tmpresult1 | grep -oP '"requestCountry":{"id":"\K\w\w' | head -n 1)
		echo -n -e "\r Netflix:\t\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
		return
	else
		echo -n -e "\r Netflix:\t\t\t\t${Font_Red}Failed${Font_Suffix}\n"
		return
	fi
}

function MediaUnlockTest_YouTube_Premium() {
	local tmpresult=$(curl $useNIC $usePROXY $xForward -${1} --max-time 10 -sSL -H "Accept-Language: en" -b "YSC=BiCUU3-5Gdk; CONSENT=YES+cb.20220301-11-p0.en+FX+700; GPS=1; VISITOR_INFO1_LIVE=4VwPMkB7W5A; PREF=tz=Asia.Shanghai; _gcl_au=1.1.1809531354.1646633279" "https://www.youtube.com/premium" 2>&1)

	if [[ "$tmpresult" == "curl"* ]]; then
		echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
		return
	fi

	local isCN=$(echo $tmpresult | grep 'www.google.cn')
	if [ -n "$isCN" ]; then
		echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}No${Font_Suffix} ${Font_Green} (Region: CN)${Font_Suffix} \n"
		return
	fi
	local isNotAvailable=$(echo $tmpresult | grep 'Premium is not available in your country')
	local region=$(echo $tmpresult | grep "countryCode" | sed 's/.*"countryCode"//' | cut -f2 -d'"')
	local isAvailable=$(echo $tmpresult | grep 'ad-free')

	if [ -n "$isNotAvailable" ]; then
		echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}No${Font_Suffix} \n"
		return
	elif [ -n "$isAvailable" ] && [ -n "$region" ]; then
		echo -n -e "\r YouTube Premium:\t\t\t${Font_Green}Yes (Region: $region)${Font_Suffix}\n"
		return
	elif [ -z "$region" ] && [ -n "$isAvailable" ]; then
		echo -n -e "\r YouTube Premium:\t\t\t${Font_Green}Yes${Font_Suffix}\n"
		return
	else
		echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}Failed${Font_Suffix}\n"
	fi

}


function MediaUnlockTest_YouTube_CDN() {
	local tmpresult=$(curl $useNIC $usePROXY $xForward -${1} ${ssll} -sS --max-time 10 "https://redirector.googlevideo.com/report_mapping" 2>&1)

	if [[ "$tmpresult" == "curl"* ]]; then
		echo -n -e "\r YouTube Region:\t\t\t${Font_Red}Check Failed (Network Connection)${Font_Suffix}\n"
		return
	fi

	local iata=$(echo $tmpresult | grep '=>'| awk "NR==1" | awk '{print $3}' | cut -f2 -d'-' | cut -c 1-3 | tr [:lower:] [:upper:])

	local isIataFound1=$(echo "$IATACode" | grep $iata)
	local isIataFound2=$(echo "$IATACode2" | grep $iata)
	if [ -n "$isIataFound1" ]; then
		local lineNo=$(echo "$IATACode" | cut -f3 -d"|" | sed -n "/${iata}/=")
		local location=$(echo "$IATACode" | awk "NR==${lineNo}" | cut -f1 -d"|" | sed -e 's/^[[:space:]]*//')
	elif [ -z "$isIataFound1" ] && [ -n "$isIataFound2" ]; then
		local lineNo=$(echo "$IATACode2" | awk '{print $1}' | sed -n "/${iata}/=")
		local location=$(echo "$IATACode2" | awk "NR==${lineNo}" | cut -f2 -d"," | sed -e 's/^[[:space:]]*//' | tr [:upper:] [:lower:] | sed 's/\b[a-z]/\U&/g')
	fi
	
	local isIDC=$(echo $tmpresult | grep "router")
	if [ -n "$iata" ] && [ -z "$isIDC" ]; then
		local CDN_ISP=$(echo $tmpresult | awk "NR==1" | awk '{print $3}' | cut -f1 -d"-" | tr [:lower:] [:upper:])
		echo -n -e "\r YouTube CDN:\t\t\t\t${Font_Yellow}$CDN_ISP in $location${Font_Suffix}\n"
		return
	elif [ -n "$iata" ] && [ -n "$isIDC" ]; then
		echo -n -e "\r YouTube CDN:\t\t\t\t${Font_Green}$location${Font_Suffix}\n"
		return
	else
		echo -n -e "\r YouTube CDN:\t\t\t\t${Font_Red}Undetectable${Font_Suffix}\n"
		return
	fi

}


function MediaUnlockTest_NetflixCDN() {
	local tmpresult=$(curl $useNIC $usePROXY $xForward -${1} ${ssll} -s --max-time 10 "https://api.fast.com/netflix/speedtest/v2?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm&urlCount=1" 2>&1)
	if [ -z "$tmpresult" ]; then
		echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Red}Failed${Font_Suffix}\n"
		return
	elif [ -n "$(echo $tmpresult | grep '>403<')" ]; then
		echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Red}Failed (IP Banned By Netflix)${Font_Suffix}\n"
		return
	fi

	local CDNAddr=$(echo $tmpresult | sed 's/.*"url":"//' | cut -f3 -d"/")
	if [[ "$1" == "6" ]]; then
		nslookup -q=AAAA $CDNAddr >~/v6_addr.txt
		ifAAAA=$(cat ~/v6_addr.txt | grep 'AAAA address' | awk '{print $NF}')
		if [ -z "$ifAAAA" ]; then
			CDNIP=$(cat ~/v6_addr.txt | grep Address | sed -n '$p' | awk '{print $NF}')
		else
			CDNIP=${ifAAAA}
		fi
	else
		CDNIP=$(nslookup $CDNAddr | sed '/^\s*$/d' | awk 'END {print}' | awk '{print $2}')
	fi

	if [ -z "$CDNIP" ]; then
		echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Red}Failed (CDN IP Not Found)${Font_Suffix}\n"
		rm -rf ~/v6_addr.txt
		return
	fi

	local CDN_ISP=$(curl $useNIC $xForward --user-agent "${UA_Browser}" -s --max-time 20 "https://api.ip.sb/geoip/$CDNIP" 2>&1 | python -m json.tool 2>/dev/null | grep 'isp' | cut -f4 -d'"')
	local iata=$(echo $CDNAddr | cut -f3 -d"-" | sed 's/.\{3\}$//' | tr [:lower:] [:upper:])

	#local IATACode2=$(curl -s --retry 3 --max-time 10 "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/reference/IATACode2.txt" 2>&1)

	local isIataFound1=$(echo "$IATACode" | grep $iata)
	local isIataFound2=$(echo "$IATACode2" | grep $iata)

	if [ -n "$isIataFound1" ]; then
		local lineNo=$(echo "$IATACode" | cut -f3 -d"|" | sed -n "/${iata}/=")
		local location=$(echo "$IATACode" | awk "NR==${lineNo}" | cut -f1 -d"|" | sed -e 's/^[[:space:]]*//')
	elif [ -z "$isIataFound1" ] && [ -n "$isIataFound2" ]; then
		local lineNo=$(echo "$IATACode2" | awk '{print $1}' | sed -n "/${iata}/=")
		local location=$(echo "$IATACode2" | awk "NR==${lineNo}" | cut -f2 -d"," | sed -e 's/^[[:space:]]*//' | tr [:upper:] [:lower:] | sed 's/\b[a-z]/\U&/g')
	fi

	if [ -n "$location" ] && [[ "$CDN_ISP" == "Netflix Streaming Services" ]]; then
		echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Green}$location ${Font_Suffix}\n"
		rm -rf ~/v6_addr.txt
		return
	elif [ -n "$location" ] && [[ "$CDN_ISP" != "Netflix Streaming Services" ]]; then
		echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Yellow}Associated with [$CDN_ISP] in [$location]${Font_Suffix}\n"
		rm -rf ~/v6_addr.txt
		return
	elif [ -n "$location" ] && [ -z "$CDN_ISP" ]; then
		echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Red}No ISP Info Founded${Font_Suffix}\n"
		rm -rf ~/v6_addr.txt
		return
	fi
}


function MediaUnlockTest_Spotify() {
	local tmpresult=$(curl $useNIC $usePROXY $xForward -${1} ${ssll} --user-agent "${UA_Browser}" -s --max-time 10 -X POST "https://spclient.wg.spotify.com/signup/public/v1/account" -d "birth_day=11&birth_month=11&birth_year=2000&collect_personal_info=undefined&creation_flow=&creation_point=https%3A%2F%2Fwww.spotify.com%2Fhk-en%2F&displayname=Gay%20Lord&gender=male&iagree=1&key=a1e486e2729f46d6bb368d6b2bcda326&platform=www&referrer=&send-email=0&thirdpartyemail=0&identifier_token=AgE6YTvEzkReHNfJpO114514" -H "Accept-Language: en" 2>&1)
	local region=$(echo $tmpresult | python -m json.tool 2>/dev/null | grep '"country":' | cut -f4 -d'"')
	local isLaunched=$(echo $tmpresult | python -m json.tool 2>/dev/null | grep is_country_launched | cut -f1 -d',' | awk '{print $2}')
	local StatusCode=$(echo $tmpresult | python -m json.tool 2>/dev/null | grep status | cut -f1 -d',' | awk '{print $2}')

	if [ "$tmpresult" = "000" ]; then
		echo -n -e "\r Spotify Registration:\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
		return
	elif [ "$StatusCode" = "320" ] || [ "$StatusCode" = "120" ]; then
		echo -n -e "\r Spotify Registration:\t\t\t${Font_Red}No${Font_Suffix}\n"
		return
	elif [ "$StatusCode" = "311" ] && [ "$isLaunched" = "true" ]; then
		echo -n -e "\r Spotify Registration:\t\t\t${Font_Green}Yes (Region: $region)${Font_Suffix}\n"
		return
	fi
}


function MediaUnlockTest_Instagram.Music() {
	local result=$(curl $useNIC $usePROXY $xForward -${1} ${ssll} -s --max-time 10 'https://www.instagram.com/api/graphql'   -H 'Accept: */*'   -H 'Accept-Language: zh-CN,zh;q=0.9'   -H 'Connection: keep-alive'   -H 'Content-Type: application/x-www-form-urlencoded'   -H 'Cookie: csrftoken=mmCtHhtfZRG-K3WgoYMemg; dpr=1.75; _js_ig_did=809EA442-22F7-4844-9470-ABC2AC4DE7AE; _js_datr=rb21ZbL7KR_5DN8m_43oEtgn; mid=ZbW9rgALAAECR590Ukv8bAlT8YQX; ig_did=809EA442-22F7-4844-9470-ABC2AC4DE7AE; ig_nrcb=1'   -H 'Origin: https://www.instagram.com'   -H 'Referer: https://www.instagram.com/p/C2YEAdOh9AB/'   -H 'Sec-Fetch-Dest: empty'   -H 'Sec-Fetch-Mode: cors'   -H 'Sec-Fetch-Site: same-origin'   -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'   -H 'X-ASBD-ID: 129477'   -H 'X-CSRFToken: mmCtHhtfZRG-K3WgoYMemg'   -H 'X-FB-Friendly-Name: PolarisPostActionLoadPostQueryQuery'   -H 'X-FB-LSD: AVrkL73GMdk'   -H 'X-IG-App-ID: 936619743392459'   -H 'dpr: 1.75'   -H 'sec-ch-prefers-color-scheme: light'   -H 'sec-ch-ua: "Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"'   -H 'sec-ch-ua-full-version-list: "Not_A Brand";v="8.0.0.0", "Chromium";v="120.0.6099.225", "Google Chrome";v="120.0.6099.225"'   -H 'sec-ch-ua-mobile: ?0'   -H 'sec-ch-ua-model: ""'   -H 'sec-ch-ua-platform: "Windows"'   -H 'sec-ch-ua-platform-version: "10.0.0"'   -H 'viewport-width: 1640'   --data-raw 'av=0&__d=www&__user=0&__a=1&__req=3&__hs=19750.HYP%3Ainstagram_web_pkg.2.1..0.0&dpr=1&__ccg=UNKNOWN&__rev=1011068636&__s=drshru%3Agu4p3s%3A0d8tzk&__hsi=7328972521009111950&__dyn=7xeUjG1mxu1syUbFp60DU98nwgU29zEdEc8co2qwJw5ux609vCwjE1xoswIwuo2awlU-cw5Mx62G3i1ywOwv89k2C1Fwc60AEC7U2czXwae4UaEW2G1NwwwNwKwHw8Xxm16wUwtEvw4JwJCwLyES1Twoob82ZwrUdUbGwmk1xwmo6O1FwlE6PhA6bxy4UjK5V8&__csr=gtneJ9lGF4HlRX-VHjmipBDGAhGuWV4uEyXyp22u6pU-mcx3BCGjHS-yabGq4rhoWBAAAKamtnBy8PJeUgUymlVF48AGGWxCiUC4E9HG78og01bZqx106Ag0clE0kVwdy0Nx4w2TU0iGDgChwmUrw2wVFQ9Bg3fw4uxfo2ow0asW&__comet_req=7&lsd=AVrkL73GMdk&jazoest=2909&__spin_r=1011068636&__spin_b=trunk&__spin_t=1706409389&fb_api_caller_class=RelayModern&fb_api_req_friendly_name=PolarisPostActionLoadPostQueryQuery&variables=%7B%22shortcode%22%3A%22C2YEAdOh9AB%22%2C%22fetch_comment_count%22%3A40%2C%22fetch_related_profile_media_count%22%3A3%2C%22parent_comment_count%22%3A24%2C%22child_comment_count%22%3A3%2C%22fetch_like_count%22%3A10%2C%22fetch_tagged_user_count%22%3Anull%2C%22fetch_preview_comment_count%22%3A2%2C%22has_threaded_comments%22%3Atrue%2C%22hoisted_comment_id%22%3Anull%2C%22hoisted_reply_id%22%3Anull%7D&server_timestamps=true&doc_id=10015901848480474' | grep -oP '"should_mute_audio":\K(false|true)')
	echo -n -e " Instagram Licensed Audio:\t\t->\c"
	if [[ "$result" == "false" ]]; then
		echo -n -e "\r Instagram Licensed Audio:\t\t${Font_Green}Yes${Font_Suffix}\n"
	elif [[ "$result" == "true" ]]; then
		echo -n -e "\r Instagram Licensed Audio:\t\t${Font_Red}No${Font_Suffix}\n"
	else
		echo -n -e "\r Instagram Licensed Audio:\t\t${Font_Red}Failed${Font_Suffix}\n"
	fi
	
}


function OpenAITest() {
	local location=$(curl -sS "https://chat.openai.com/cdn-cgi/trace" | grep -oP '(?<=loc=)[A-Z]{2}')
	local SUPPORT_COUNTRY=("AL" "DZ" "AD" "AO" "AG" "AR" "AM" "AU" "AT" "AZ" "BS" "BD" "BB" "BE" "BZ" "BJ" "BT" "BO" "BA" "BW" "BR" "BN" "BG" "BF" "CV" "CA" "CL" "CO" "KM" "CG" "CR" "CI" "HR" "CY" "CZ" "DK" "DJ" "DM" "DO" "EC" "SV" "EE" "FJ" "FI" "FR" "GA" "GM" "GE" "DE" "GH" "GR" "GD" "GT" "GN" "GW" "GY" "HT" "VA" "HN" "HU" "IS" "IN" "ID" "IQ" "IE" "IL" "IT" "JM" "JP" "JO" "KZ" "KE" "KI" "KW" "KG" "LV" "LB" "LS" "LR" "LI" "LT" "LU" "MG" "MW" "MY" "MV" "ML" "MT" "MH" "MR" "MU" "MX" "FM" "MD" "MC" "MN" "ME" "MA" "MZ" "MM" "NA" "NR" "NP" "NL" "NZ" "NI" "NE" "NG" "MK" "NO" "OM" "PK" "PW" "PS" "PA" "PG" "PY" "PE" "PH" "PL" "PT" "QA" "RO" "RW" "KN" "LC" "VC" "WS" "SM" "ST" "SN" "RS" "SC" "SL" "SG" "SK" "SI" "SB" "ZA" "KR" "ES" "LK" "SR" "SE" "CH" "TW" "TZ" "TH" "TL" "TG" "TO" "TT" "TN" "TR" "TV" "UG" "UA" "AE" "GB" "US" "UY" "VU" "ZM")

	if [[ " ${SUPPORT_COUNTRY[@]} " =~ " ${location} " ]]; then
		echo -n -e "\r ChatGPT:\t\t\t\t${Font_Green}Yes (Region: ${location})${Font_Suffix}\n"
		return
	else
		echo -n -e "\r ChatGPT:\t\t\t\t${Font_Red}No (Region: ${location})${Font_Suffix}\n"
		return
	fi
}



function Bing_Region(){
	local tmpresult=$(curl $useNIC $usePROXY $xForward -${1} ${ssll} -s --max-time 10 "https://www.bing.com/search?q=curl")
	local isCN=$(echo $tmpresult | grep 'cn.bing.com')
	local Region=$(echo $tmpresult | sed -n 's/.*Region:"\([^"]*\)".*/\1/p')
	if [ -n "$isCN" ]; then
		echo -n -e "\r Bing Region:\t\t\t\t${Font_Yellow}CN${Font_Suffix}\n"
		return
	else
		echo -n -e "\r Bing Region:\t\t\t\t${Font_Yellow}${Region}${Font_Suffix}\n"
		return
	fi
}


function echo_Result() {
	for((i=0;i<${#array[@]};i++)) 
	do
		echo "$result" | grep "${array[i]}"
		sleep 0.03
	done;
}


function Global_UnlockTest() {
	echo ""
	echo -e "${Font_Yellow}============[ Глобальный тест ]============${Font_Suffix}"
	echo ""
	local result=$(
	MediaUnlockTest_Netflix ${1} &
	MediaUnlockTest_YouTube_Premium ${1} &
	MediaUnlockTest_YouTube_CDN ${1} &
	MediaUnlockTest_NetflixCDN ${1} &
	MediaUnlockTest_Spotify ${1} &
	OpenAITest ${1} &
	Bing_Region ${1} &
	MediaUnlockTest_Instagram.Music ${1} &
	)
	wait
	local array=("Netflix:" "YouTube Premium:" "YouTube CDN:" "Netflix Preferred CDN:" "Spotify Registration:" "ChatGPT:" "Bing Region:" "Instagram Licensed Audio:")
	echo_Result ${result} ${array}
	echo "======================================="
}


function CheckPROXY() {
	if [ -n "$usePROXY" ]; then
		local proxy=$(echo $usePROXY | tr A-Z a-z)
		if [[ "$proxy" == *"socks:"* ]] ; then
			proxyType=Socks
		elif [[ "$proxy" == *"socks4:"* ]]; then
			proxyType=Socks4
		elif [[ "$proxy" == *"socks5:"* ]]; then
			proxyType=Socks5
		elif [[ "$proxy" == *"http"* ]]; then
			proxyType=http
		else
			proxyType=""
		fi
		local result1=$(curl $useNIC $usePROXY -sS --user-agent "${UA_Browser}" ip.sb 2>&1)
		local result2=$(curl $useNIC $usePROXY -sS --user-agent "${UA_Browser}" https://1.0.0.1/cdn-cgi/trace 2>&1)
		if [[ "$result1" == "curl"* ]] && [[ "$result2" == "curl"* ]] || [ -z "$proxyType" ]; then
			isproxy=0
		else
			isproxy=1
		fi
	else
		isproxy=0
	fi
}



function CheckV4() {
	CheckPROXY
	if [[ "$NetworkType" == "6" ]]; then
		isv4=0
		echo -e "${Font_SkyBlue}User Choose to Test Only IPv6 Results, Skipping IPv4 Testing...${Font_Suffix}"
	else
		if [ -n "$usePROXY" ] && [[ "$isproxy" -eq 1 ]]; then
			echo -e " ${Font_SkyBlue}** Checking Results Under Proxy${Font_Suffix} "
			isv6=0
		elif [ -n "$usePROXY" ] && [[ "$isproxy" -eq 0 ]]; then
			echo -e " ${Font_SkyBlue}** Unable to connect to this proxy${Font_Suffix} "
			isv6=0
			return
		else
			echo -e " ${Font_Yellow}** Проверяем результаты для IPv4${Font_Suffix} "
			check4=$(ping 1.1.1.1 -c 1 2>&1)
		fi
		echo "--------------------------------"
		echo -e " ${Font_Yellow}** Ваш хостинг-провайдер: ${local_isp4} (${local_ipv4_asterisk})${Font_Suffix} "
		ip_info=$(curl -sS "https://ipinfo.io/json")
		country=$(echo "$ip_info" | awk -F'"' '/country/ {print $4}')
		city=$(echo "$ip_info" | awk -F'"' '/city/ {print $4}')
		asn=$(echo "$ip_info" | awk -F'"' '/org/ {print $4}')
		echo -e " ${Font_Yellow}"Страна: $country"${Font_Suffix}"
		echo -e " ${Font_Yellow}"Город: $city"${Font_Suffix}"
		echo -e " ${Font_Yellow}"ASN: $asn"${Font_Suffix}"
		
		if [[ "$check4" != *"unreachable"* ]] && [[ "$check4" != *"Unreachable"* ]]; then
			isv4=1
		else
			echo ""
			echo -e "${Font_Yellow}IPv4 не обнаружен, отмена IPv4 проверки...${Font_Suffix}"
			isv4=0
		fi

		echo ""
	fi
}


function CheckV6() {
	if [[ "$NetworkType" == "4" ]]; then
		isv6=0
		if [ -z "$usePROXY" ]; then
			echo -e "${Font_SkyBlue}User Choose to Test Only IPv4 Results, Skipping IPv6 Testing...${Font_Suffix}"
		fi
	else
		check6_1=$(curl $useNIC -fsL --write-out %{http_code} --output /dev/null --max-time 10 ipv6.google.com)
		check6_2=$(curl $useNIC -fsL --write-out %{http_code} --output /dev/null --max-time 10 ipv6.ip.sb)
		if [[ "$check6_1" -ne "000" ]] || [[ "$check6_2" -ne "000" ]]; then
			echo ""
			echo ""
			echo -e " ${Font_yellow}** Проверяем результаты для IPv6${Font_Suffix} "
			echo "--------------------------------"
			echo -e " ${Font_Yellow}** Ваш хостинг-провайдер: ${local_isp6} (${local_ipv6_asterisk})${Font_Suffix} "
			isv6=1
		else
			echo ""
			echo -e "${Font_Yellow}IPv6 не обнаружен, отмена IPv6 проверки...${Font_Suffix}"
			isv6=0
		fi
		echo -e ""
	fi
}


function Goodbye() {
	echo -e "${Font_Yellow}Тест завершен! ${Font_Suffix}"
}

clear


function ScriptTitle() {
	echo -e " ${Font_Purple}[Тест для проверки доступности сервисов на сервере]${Font_Suffix} "
	echo ""
}
ScriptTitle


function RunScript() {
	clear
	ScriptTitle
	CheckV4
	if [[ "$isv4" -eq 1 ]]; then
		Global_UnlockTest 4
	fi
	CheckV6
	if [[ "$isv6" -eq 1 ]]; then
		Global_UnlockTest 6
	fi
	Goodbye
}

RunScript
