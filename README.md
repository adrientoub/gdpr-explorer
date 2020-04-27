# GDPR Explorer

## Description

Since May 25th 2018 all EU citizen have the legal right to get their personal data from the services they use. Most websites now have an automated way to download all your data in a computer readable format (or human readable format). But that data package is often very big and can be a lot to take in.

This repository contains a collection of scripts to parse and explore your GDPR exported data from popular websites.

Currently supports:
- Instagram likes
- Instagram messages
- Facebook Messenger messages
- Twitter Direct Messages

## How to get your data

### Facebook

Follow this [guide](https://www.facebook.com/help/1701730696756992?helpref=hc_global_nav) and request the data as JSON. It usually takes a day or two to get the archive.

**Warning**: if you decide to get the high quality pictures the archive might be really heavy.

### Instagram

Follow this [guide](https://help.instagram.com/181231772500920). It usually takes a few hours to get the archive.

### Twitter

Follow this [guide](https://help.twitter.com/en/managing-your-account/accessing-your-twitter-data). It usually takes a few hours to get the archive.

### Snapchat

Follow this [guide](https://support.snapchat.com/en-US/a/download-my-data).
It usually takes a few minutes to get the archive.

### Apple

Go to [guide](https://privacy.apple.com/). Connect with your Apple Account and answer your security questions. You will then have the ability to request an archive of your data. It usually takes a few days to get the archive.

### YouTube

Go to [Google Takeout](https://takeout.google.com/settings/takeout). Select YouTube and YouTube Music, click on "Multiple formats" and pick JSON in the format selector. It usually takes a few minutes to get the archive.

## Requirements

* Ruby 2.5 or more recent

## Usage

1. Clone this repository locally.
2. Launch the script you want.

```
Usage: ruby launch_facebook_messenger.rb [path_to_inbox] [output_directory]
  'path_to_inbox' is the path to the Facebook Archive folder named 'messages/inbox'
  'output_directory' is the directory where you want the script to output its work
```

```
Usage: ruby launch_instagram_messages.rb [path_to_messages] [output_directory]
  'path_to_messages' is the path to the Instagram file named 'messages.json'
  'output_directory' is the directory where you want the script to output its work```
```

```
Usage: ruby launch_twitter_dm.rb [path_to_dms] [output_directory]
  'path_to_dms' is the path to the Twitter file named 'direct-messages.js'
  'output_directory' is the directory where you want the script to output its work
```

```
Usage: ruby launch_youtube.rb [path_to_history] [output_directory]
  'path_to_history' is the path to the YouTube file named 'watch-history.json'
  'output_directory' is the directory where you want the script to output its work
```
