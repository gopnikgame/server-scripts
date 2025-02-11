
```markdown
# Server Scripts

Коллекция bash-скриптов для проверки различных аспектов работы сервера и сети.

---

## Содержание

### Проверка сервисов

#### check_instagram.sh
Проверяет доступность Instagram API и возвращает статус ответа.

[Посмотреть скрипт](https://raw.githubusercontent.com/gopnikgame/server-scripts/master/checkers/check_instagram.sh)  
```bash
bash <(curl -s https://raw.githubusercontent.com/gopnikgame/server-scripts/master/checkers/check_instagram.sh)
```

#### ip_quality.sh
Проверяет качество IP-адреса через сервис ipqualityscore.com. Требует API-ключ.

[Посмотреть скрипт](https://raw.githubusercontent.com/gopnikgame/server-scripts/master/checkers/ip_quality.sh)  
```bash
API_KEY=your_api_key_here bash <(curl -s https://raw.githubusercontent.com/gopnikgame/server-scripts/master/checkers/ip_quality.sh)
```

#### service_availability.sh
Проверяет доступность нескольких ключевых интернет-сервисов (Google, Facebook, Twitter).

[Посмотреть скрипт](https://raw.githubusercontent.com/gopnikgame/server-scripts/master/checkers/service_availability.sh)  
```bash
bash <(curl -s https://raw.githubusercontent.com/gopnikgame/server-scripts/master/checkers/service_availability.sh)
```

#### tiktok_region.sh
Определяет регион TikTok на основе текущего IP-адреса.

[Посмотреть скрипт](https://raw.githubusercontent.com/gopnikgame/server-scripts/master/checkers/tiktok_region.sh)  
```bash
bash <(curl -s https://raw.githubusercontent.com/gopnikgame/server-scripts/master/checkers/tiktok_region.sh)
```

---

### Тест скорости интернета

#### speedtest_ru.sh
Выполняет тест скорости интернета для России и выводит результаты.

[Посмотреть скрипт](https://raw.githubusercontent.com/gopnikgame/server-scripts/master/speedtest/countries/speedtest_ru.sh)  
```bash
bash <(curl -s https://raw.githubusercontent.com/gopnikgame/server-scripts/master/speedtest/countries/speedtest_ru.sh)
```

---

## Инструкция по использованию

1. Убедитесь, что у вас установлен `curl`:
   ```bash
   sudo apt install curl
   ```

2. Выберите нужный скрипт и запустите его либо скачав локально, либо используя прямую ссылку для выполнения без сохранения.

3. Некоторые скрипты могут требовать дополнительных параметров или API-ключей. Убедитесь, что вы предоставили все необходимые данные перед запуском.

---

## Пример использования скрипта без сохранения

```bash
# Запуск скрипта проверки качества IP
API_KEY=your_api_key_here bash <(curl -s https://raw.githubusercontent.com/gopnikgame/server-scripts/master/checkers/ip_quality.sh)

# Запуск теста скорости интернета для России
bash <(curl -s https://raw.githubusercontent.com/gopnikgame/server-scripts/master/speedtest/countries/speedtest_ru.sh)
```

---

## Важные замечания

- Перед использованием скриптов убедитесь, что у вас есть все необходимые права доступа.
- Некоторые скрипты могут требовать установки дополнительных зависимостей.
- Рекомендуется проверять работу скриптов в тестовой среде перед использованием в production.

---

## Поддержка

Если вы обнаружили ошибки или хотите предложить улучшения, пожалуйста, создайте issue или pull request.

---

## Лицензия

Этот проект распространяется под лицензией MIT. Подробности см. в файле [LICENSE](LICENSE).
```

