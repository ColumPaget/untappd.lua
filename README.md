SYNOPSIS
========

untappd.lua is a script that monitors recent "checkins" at a list of pubs by screen-scraping their "untappd.com" pages. It then prints out a list of recently reported beers to give some idea of what beers are guesting at the various venues.

Venues are added using the 'add' command and passing the url of the venue's page on "untappd.com". The 'show' command can then be used to print out recent beer reports from the venues in the monitor list.

untappd.lua requires libUseful (https://github.com/ColumPaget/libUseful) and libUseful-lua (https://github.com/ColumPaget/libUseful-lua) to be installed.

USAGE
=====

```
   untappd.lua add <url>     - add untappd page to monitored pages/venues
   untappd.lua del <url>     - delete untappd page from monitored pages/venues by it's untapped page url
   untappd.lua del <i>       - delete untappd page from monitored pages/venues by it's index number
   untappd.lua show <url>    - display recent beer reports for a venue specified by untappd page url
   untappd.lua show          - display recent beer reports for all venues in the monitor list
   untappd.lua list          - list all venues in the monitor list
```
