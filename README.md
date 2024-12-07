# server-scripts

Speedtest for Russian regions:
```
wget -qO- https://raw.githubusercontent.com/jomertix/server-scripts/refs/heads/master/speedtest/countries/speedtest_ru.sh | bash
```

IP quality:
```
bash <(curl -sL https://raw.githubusercontent.com/jomertix/server-scripts/refs/heads/master/checkers/ip_quality.sh)
```
Check the availability of services:
```
bash <(curl -sL https://raw.githubusercontent.com/jomertix/server-scripts/refs/heads/master/checkers/service_availability.sh)
```
Check Instagram availability
```
bash <(curl -sL https://raw.githubusercontent.com/jomertix/server-scripts/refs/heads/master/checkers/check_instagram.sh)
```

