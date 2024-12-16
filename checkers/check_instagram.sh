#!/bin/bash
shopt -s expand_aliases

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


function MediaUnlockTest_Instagram.Music() {
	local videos=("C2YEAdOh9AB" "Cx_DE0ZI1xc" "CyERUKpIS7Q" "C0Y6l7qrfi-" "CrfV3RxgKYl" "C2u22AltQEu")
	
	for INST_VIDEO in "${videos[@]}"
	do
	local result=$(curl $useNIC $usePROXY $xForward -${1} ${ssll} -s --max-time 10 'https://www.instagram.com/api/graphql' \
		--header 'Accept: */*' \
		--header 'Accept-Language: ru-RU,zh;q=0.9' \
		--header 'Connection: keep-alive' \
		--header 'Content-Type: application/x-www-form-urlencoded' \
		--header 'Cookie: csrftoken=mmCtHhtfZRG-K3WgoYMemg; dpr=1.75; _js_ig_did=809EA442-22F7-4844-9470-ABC2AC4DE7AE; _js_datr=rb21ZbL7KR_5DN8m_43oEtgn; mid=ZbW9rgALAAECR590Ukv8bAlT8YQX; ig_did=809EA442-22F7-4844-9470-ABC2AC4DE7AE; ig_nrcb=1; datr=rb21ZbL7KR_5DN8m_43oEtgn; ig_did=809EA442-22F7-4844-9470-ABC2AC4DE7AE; csrftoken=OfOpK-7wFiuOiMPkuVwKzf; datr=rb21ZbL7KR_5DN8m_43oEtgn; ig_did=809EA442-22F7-4844-9470-ABC2AC4DE7AE' \
		--header 'Origin: https://www.instagram.com' \
		--header 'Referer: https://www.instagram.com/p/${INST_VIDEO}/' \
		--header 'Sec-Fetch-Dest: empty' \
		--header 'Sec-Fetch-Mode: cors' \
		--header 'Sec-Fetch-Site: same-origin' \
		--header 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36' \
		--header 'X-ASBD-ID: 129477' \
		--header 'X-CSRFToken: mmCtHhtfZRG-K3WgoYMemg' \
		--header 'X-FB-Friendly-Name: PolarisPostActionLoadPostQueryQuery' \
		--header 'X-FB-LSD: AVrkL73GMdk' \
		--header 'X-IG-App-ID: 936619743392459' \
		--header 'dpr: 1.75' \
		--header 'sec-ch-prefers-color-scheme: light' \
		--header 'sec-ch-ua: "Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"' \
		--header 'sec-ch-ua-full-version-list: "Not_A Brand";v="8.0.0.0", "Chromium";v="120.0.6099.225", "Google Chrome";v="120.0.6099.225"' \
		--header 'sec-ch-ua-mobile: ?0' \
		--header 'sec-ch-ua-model: ""' \
		--header 'sec-ch-ua-platform: "Windows"' \
		--header 'sec-ch-ua-platform-version: "10.0.0"' \
		--header 'viewport-width: 1640' \
		--data-urlencode 'av=0' \
		--data-urlencode '__d=www' \
		--data-urlencode '__user=0' \
		--data-urlencode '__a=1' \
		--data-urlencode '__req=3' \
		--data-urlencode '__hs=19750.HYP:instagram_web_pkg.2.1..0.0' \
		--data-urlencode 'dpr=1' \
		--data-urlencode '__ccg=UNKNOWN' \
		--data-urlencode '__rev=1011068636' \
		--data-urlencode '__s=drshru:gu4p3s:0d8tzk' \
		--data-urlencode '__hsi=7328972521009111950' \
		--data-urlencode '__dyn=7xeUjG1mxu1syUbFp60DU98nwgU29zEdEc8co2qwJw5ux609vCwjE1xoswIwuo2awlU-cw5Mx62G3i1ywOwv89k2C1Fwc60AEC7U2czXwae4UaEW2G1NwwwNwKwHw8Xxm16wUwtEvw4JwJCwLyES1Twoob82ZwrUdUbGwmk1xwmo6O1FwlE6PhA6bxy4UjK5V8' \
		--data-urlencode '__csr=gtneJ9lGF4HlRX-VHjmipBDGAhGuWV4uEyXyp22u6pU-mcx3BCGjHS-yabGq4rhoWBAAAKamtnBy8PJeUgUymlVF48AGGWxCiUC4E9HG78og01bZqx106Ag0clE0kVwdy0Nx4w2TU0iGDgChwmUrw2wVFQ9Bg3fw4uxfo2ow0asW' \
		--data-urlencode '__comet_req=7' \
		--data-urlencode 'lsd=AVrkL73GMdk' \
		--data-urlencode 'jazoest=2909' \
		--data-urlencode '__spin_r=1011068636' \
		--data-urlencode '__spin_b=trunk' \
		--data-urlencode '__spin_t=1706409389' \
		--data-urlencode 'fb_api_caller_class=RelayModern' \
		--data-urlencode 'fb_api_req_friendly_name=PolarisPostActionLoadPostQueryQuery' \
		--data-urlencode 'variables={"shortcode":"'"$INST_VIDEO"'","fetch_comment_count":40,"fetch_related_profile_media_count":3,"parent_comment_count":24,"child_comment_count":3,"fetch_like_count":10,"fetch_tagged_user_count":null,"fetch_preview_comment_count":2,"has_threaded_comments":true,"hoisted_comment_id":null,"hoisted_reply_id":null}' \
		--data-urlencode 'server_timestamps=true' \
		--data-urlencode 'doc_id=10015901848480474')
		
		
		local should_mute_audio=$(echo "$result" | grep -oP '"should_mute_audio":\K(false|true)')
		local mute_reason=$(echo "$result" | grep -o -P '(?<="should_mute_audio_reason":")[^"]*')
		
		echo -n -e " Instagram Licensed Audio:\t\t->\c"
		if [[ "$should_mute_audio" == "false" ]]; then
			echo -n -e "\r Instagram Licensed Audio (${INST_VIDEO}):\t${Font_Green}Yes${Font_Suffix}\n"
		elif [[ "$should_mute_audio" == "true" ]]; then
			if [[ -n "$mute_reason" ]]; then
				echo -n -e "\r Instagram Licensed Audio (${INST_VIDEO}):\t${Font_Red}No (${mute_reason})${Font_Suffix}\n"
			else
				echo -n -e "\r Instagram Licensed Audio (${INST_VIDEO}):\t${Font_Red}No${Font_Suffix}\n"
			fi
		else
			echo -n -e "\r Instagram Licensed Audio (${INST_VIDEO}):\t${Font_Red}Failed${Font_Suffix}\n"
		fi
		
	done
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
	echo "============[ INSTAGRAM ТЕСТ ]============"
	local result=$(MediaUnlockTest_Instagram.Music ${1})
	wait
	local array=("Instagram Licensed Audio:")
	echo_Result <<< "$result" "${array[@]}"
	echo "======================================="
}

function CheckV4() {
	if [[ "$NetworkType" == "6" ]]; then
		isv4=0
	else
		echo -e " ${Font_Yellow}** Результаты проверки для IPv4${Font_Suffix} "
		check4=$(ping 1.1.1.1 -c 1 2>&1)
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
	else
		check6_1=$(curl $useNIC -fsL --write-out %{http_code} --output /dev/null --max-time 10 ipv6.google.com)
		check6_2=$(curl $useNIC -fsL --write-out %{http_code} --output /dev/null --max-time 10 ipv6.ip.sb)
		if [[ "$check6_1" -ne "000" ]] || [[ "$check6_2" -ne "000" ]]; then
			echo ""
			echo ""
			echo -e " ${Font_Yellow}** Результаты проверки для IPv6${Font_Suffix} "
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
	echo ""
	echo -e "${Font_Yellow}Тест завершен! ${Font_Suffix}"
}

clear

function ScriptTitle() {
	echo -e " ${Font_Purple}[Тест для проверки Instagram]${Font_Suffix} "
	echo ""
}

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
