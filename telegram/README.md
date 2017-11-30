 PRE-REQUISITES :
 ----------------

   - Get telegram-notify.sh & telegram-notify.conf from Nicolas Bernaerts :
      wget https://raw.githubusercontent.com/NicolasBernaerts/debian-scripts/master/telegram/telegram-notify-install.sh
      wget https://raw.githubusercontent.com/NicolasBernaerts/debian-scripts/master/telegram/telegram-notify.conf
   - Create a telegram bot :
      Follow steps 1 to 13 here : https://github.com/topkecleon/telegram-bot-bash
      /!\ Note down the API key given by @BotFather
   - Get user ID :
      + Send a message to your Bot from your Telegram client
      + Call the following URL from any web browser. XXXXX = your API key.
          https://api.telegram.org/botXXXXX/getUpdates
          In the page displayed, you'll get some information. search for "from":"id":YYYYY, ". YYYYY is your user ID.
   - Update telegram-notify.conf with your telegram API key and user ID.
