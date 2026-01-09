require("stream")
require("strutil")
require("xml")
require("time")
require("terminal")
require("process")
require("dataparser")

VERSION="2.0"
config_path=process.homeDir().."/.config/untappd.lua/default.venues" .. ":" .. process.homeDir().."/.config/untapped.venues"

today_name=time.format("%A")


function ConfigOpenRead()
local toks, tok

toks=strutil.TOKENIZER(config_path, ":")
tok=toks:next()
while tok ~= nil
do
S=stream.STREAM(tok, "r")
if S ~= nil then return S end
tok=toks:next()
end

return nil
end


function ConfigOpenWrite(path)

if strutil.strlen(path) > 0
then
filesys.makeDirPath(path)
S=stream.STREAM(path, "w")
if S ~= nil then return S end
end

return nil
end


function ConfigOpenWriteFind()
local toks, path, first

toks=strutil.TOKENIZER(config_path, ":")

path=toks:next()
first=path
while path ~= nil
do
if filesys.exists(path)==true then return ConfigOpenWrite(path) end
path=toks:next()
end

return ConfigOpenWrite(first)

end



function XMLGetText(Xml)
local item

item=Xml:next()
while item ~= nil
do
if item.type==nil then return item.data end
item=Xml:next()
end

return nil
end



function CheckinBeer(name, brewer, user, venue)
local checkin={}
local str

str=string.gsub(name, "\n", " ")
str=string.gsub(str, " +", " ")
checkin.beer=strutil.trim(str)

str=string.gsub(brewer, " +", " ")
checkin.brewer=strutil.trim(str)

str=string.gsub(user, " +", " ")
checkin.user=strutil.trim(str)

if checkin.beer ~= "{{this.beer.beer_name}}" then table.insert(venue.checkins, checkin) end

return checkin
end



function ParseCheckin(venue, Xml)
local item, str, user, beer, brewer
local checkin

venue.has_checkins=true

item=Xml:next()
while item ~= nil
do
if item.type=="a" and string.find(item.data, 'class="user"') ~= nil
then
	user=XMLGetText(Xml)
	str=XMLGetText(Xml) 
	if string.sub(str, 1, 12) ~= "is drinking " then print("ERROR: no 'is drinking a': ["..str.."]") end
	beer=XMLGetText(Xml)
	if XMLGetText(Xml) ~= "by " then print("ERROR: no 'by'") end
	brewer=XMLGetText(Xml)

	checkin=CheckinBeer(beer, brewer, user, venue)
end

if item.type=="a" and string.find(item.data, 'feed/viewcheckindate') ~= nil 
then 
checkin.date=XMLGetText(Xml) 
checkin.secs=time.tosecs("%a,  %d %b %Y %H:%M:%S", checkin.date)
return
end


item=Xml:next()
end

end

function ParseBeerDetails(venue, Xml)
local checkin

item=Xml:next()
while item ~= nil and item.type ~= "a" do item=Xml:next() end

checkin=CheckinBeer(XMLGetText(Xml), "", "venue menu", venue)
checkin.secs=time.secs()

item=Xml:next()
while item ~= nil 
do 
if item.type == "a" and string.find(item.data , 'href=":brewery"') ~= nil then checkin.brewer=strutil.trim(XMLGetText(Xml)) end

--technically this is the start of the next beer, but we use it here to catch the end of the one we are parsing
if item.type == "div" and item.data == 'class="beer-details"' then break end

item=Xml:next() 
end

end



--{"count":7,"items":[{"day_name":"Monday","is_24":0,"is_open":0,"hours":[]},{"day_name":"Tuesday","is_24":0,"is_open":1,"hours":[{"start_time":"16:00:00","end_time":"21:00:00"}]},{"day_name":"Wednesday","is_24":0,"is_open":1,"hours":[{"start_time":"16:00:00","end_time":"22:00:00"}]},{"day_name":"Thursday","is_24":0,"is_open":1,"hours":[{"start_time":"16:00:00","end_time":"23:00:00"}]},{"day_name":"Friday","is_24":0,"is_open":1,"hours":[{"start_time":"14:00:00","end_time":"23:00:00"}]},{"day_name":"Saturday","is_24":0,"is_open":1,"hours":[{"start_time":"12:00:00","end_time":"22:00:00"}]},{"day_name":"Sunday","is_24":0,"is_open":1,"hours":[{"start_time":"12:00:00","end_time":"20:00:00"}]}]}

function ExtractVenueTimes(Xml)
local hours, item, open_time, close_time

if Xml:value("is_open") == "0" then return nil, nil end

hours=Xml:open("hours")
if hours ~= nil
then
item=hours:next()
if item== nil then return "closed","closed" end

open_time=item:value("start_time")
close_time=item:value("end_time")
end

return open_time,close_time
end




function ParseVenueHours(venue, Xml)
local P, item, open_time, close_time

item=Xml:next()

P=dataparser.PARSER("json", item.data)
if P ~= nil then P=P:open("items") end

if P ~= nil
then
item=P:next()
while item ~= nil
do
  
  if item:value("day_name") == today_name
  then
	open_time, close_time=ExtractVenueTimes(item)
	if open_time ~= nil then venue.open_time = open_time end
	if close_time ~= nil then venue.close_time = close_time end
  end
  item=P:next()
end
end

return nil, nil
end




function NewVenue(url)
local venue={}

venue.url=url
venue.checkins={}
venue.has_checkins=false -- does the venue have real checkins, rather than a menu?
venue.deleted=false

return venue
end




function VenueLoadDetails(venue, url)
local S, doc, Xml, item, str

S=stream.STREAM(url)

if S == nil
then
  Out:puts("~rERROR~0: can't connect to '"..url.."' to get venue details\n")
end

doc=S:readdoc()
S:close()

Xml=xml.XML(doc)
item=Xml:next()
while item ~= nil
do

if item.type ~= nil 
then
	if item.type=="div" and item.data=='class="venue-name"' and strutil.strlen(venue.name)==0
	then 
	   while item ~= nil and item.type ~= "h1" do item=Xml:next() end
	   venue.name=XMLGetText(Xml) 
	   if venue.name==nil then venue.name="fail" end
	elseif item.type=="div" and item.data=='class="checkin"' then ParseCheckin(venue, Xml)
	elseif item.type=="div" and item.data=='class="beer-details"' then ParseBeerDetails(venue, Xml)
	elseif item.type=="div" and item.data=='class="hours-area" style="display: none;"' then ParseVenueHours(venue, Xml) 
	elseif item.type=="p" and item.data=='class="address"' 
	then 
   	  str=XMLGetText(Xml)
	  pos=string.find(str, "%(")
	  if pos > 0 then str=string.sub(str, 1, pos-1) end
	  venue.address=str
	end
end


item=Xml:next()
end

return venue
end




function GetVenueDetails(url)
local venue

venue=NewVenue(url)
VenueLoadDetails(venue, url)
if venue.has_checkins ~= true then VenueLoadDetails(venue, url.."/activity") end

return venue
end





function DisplayTimeColorKey()
Out:puts("Key:  ~e~cMenu~0  ~e~wToday~0  ~e~y2 days~0  ~y3 days~0  ~e~r4 days~0 ~r5 days~0 \n")
end


function TimeColor(now, checkin)
local diff

if checkin.user == "venue menu" then color="~e~c"
else
  diff=now - checkin.secs
  if diff < (24 * 3600) then color="~e~w"
  elseif diff < (48 * 3600) then color="~e~y"
  elseif diff < (72 * 3600) then color="~y"
  elseif diff < (96 * 3600) then color="~e~r"
  elseif diff < (120 * 3600) then color="~r"
  else color=nil
  end
end

return color
end


function SortBeers(i1, i2)
return i1.age < i2.age
end



function VenueOutputInfo(venue, now, checkins)
local str, checkin

if strutil.strlen(venue.name) > 0
then
  Out:puts("~e~b"..venue.name..":~0 ")

  if venue.open_time ~= nil 
  then 
    if venue.open_time=="closed" then Out:puts(" ~rclosed today~0" .." ") 
    else Out:puts(" ~gopen today~0:"..venue.open_time.."-"..venue.close_time.." ") 
    end
  end
  
  for str,checkin in pairs(checkins)
  do
    str=TimeColor(now, checkin)
    if str ~= nil then Out:puts(TimeColor(now, checkin) .. checkin.key.."~0, ") end
  end
  Out:puts("\n")
end
end



function DisplayVenue(venue)
local beers={}
local sorted={}
local i, str, checkin, now, diff

now=time.secs()

for i,checkin in ipairs(venue.checkins)
do
	checkin.key=checkin.beer.." ("..checkin.brewer..")"
	checkin.age=(now - checkin.secs) / 3600
	if beers[checkin.key] == nil then beers[checkin.key]=checkin end
end


-- lua won't sort a table where entries are stored under keynames
for str,checkin in pairs(beers)
do
  table.insert(sorted, checkin)
end
table.sort(sorted, SortBeers)

-- actually output venue info
VenueOutputInfo(venue, now, sorted)

end




function VenuesInit()
local venues={}

venues.items={}
venues.save_required=false



venues.add=function(self, url)
local venue

if strutil.strlen(url)==0 then return end
venue=GetVenueDetails(url)
table.insert(self.items, venue)

self.save_required=true
end


venues.delete_url=function(self, url)
local i, venue

if strutil.strlen(url)==0 then return end

for i,venue in ipairs(self.items)
do
  if venue ~= nil and venue.url == url
  then
    venue.deleted=true
    self.save_required=true
  end
end
end

venues.delete_index=function(self, item)
local venue

  venue=self.items[tonumber(item)]
  if venue ~= nil then venue.deleted=true end
  self.save_required=true
end


venues.delete=function(self, item)
if strutil.strlen(item)==0 then return end

if string.sub(item, 1, 6) == "https:" then self:delete_url(item)
elseif tonumber(item) > 0 then self:delete_index(item)
end
end


venues.load_venue=function(self, details)
local toks, str
local venue={}

 venue.name=""
 venue.address=""
 venue.deleted=false

 toks=strutil.TOKENIZER(details, " ", "Q")
 venue.url=toks:next()

 str=toks:next()
 while str ~= nil
 do
   if string.sub(str, 1, 5) == "name=" then venue.name=strutil.stripQuotes(string.sub(str, 6)) end
   if string.sub(str, 1, 8) == "address=" then venue.address=strutil.stripQuotes(string.sub(str, 9)) end
   str=toks:next()
 end

 table.insert(self.items, venue)

return venue
end

venues.load=function(self)
local str, S

S=ConfigOpenRead()
if S ~= nil
then
	str=S:readln()
	while  str ~= nil
	do
	str=strutil.trim(str)
	if strutil.strlen(str) > 0 then self:load_venue(str) end
	str=S:readln()
	end
	S:close()
else
  Out:puts("~rERROR~0: can't open venues config file.\n")
end

end


venues.save=function(self)
local S, i, item

S=ConfigOpenWriteFind()
if S ~= nil
then
	for i,item in ipairs(self.items)
	do
	if item.deleted == false and item.url ~= nil
	then 
		str=item.url
		if strutil.strlen(item.name) > 0 then str=str.." name=\"".. item.name.."\"" end
		if strutil.strlen(item.address) > 0 then str=str.." address=\""..item.address.."\"" end
		S:writeln(str.."\n") 
	end
	end
	S:close()
else
  Out:puts("~rERROR~0: can't open venues config file for writing, cannot save venues list.\n")
end

end


venues.list=function(self)
local i, item

for i, item in ipairs(self.items)
do
print(string.format("%4d %-60s    %s, %s", i, item.url, item.name, item.address))
end

end



venues.show=function(self, url)
local venue, toks

if strutil.strlen(url) > 0
then
venue=GetVenueDetails(url)
DisplayVenue(venue)
end

end


venues.show_all=function(self)
local i, item

if #self.items == 0
then
print("NO ITEMS IN MONITOR LIST. Add some with the 'add' command")
else
 DisplayTimeColorKey()
 for i, item in ipairs(self.items)
 do
  Out:puts(string.format("%4d ", i))
  self:show(item.url)
  time.sleep(1)
 end
end

end

venues:load()
return venues
end


function PrintHelp()
print("untappd.lua  version "..VERSION)
print("usage:")
print("   untappd.lua add <url>     - add untappd page to monitored pages/venues")
print("   untappd.lua del <url>     - delete untappd page from monitored pages/venues by it's untapped page url")
print("   untappd.lua del <i>       - delete untappd page from monitored pages/venues by it's index number")
print("   untappd.lua show <url>    - display recent beer reports for a venue specified by untappd page url")
print("   untappd.lua show          - display recent beer reports for all venues in the monitor list")
print("   untappd.lua list          - list all venues in the monitor list")
print("   untappd.lua help          - show this help")
print("   untappd.lua -help         - show this help")
print("   untappd.lua -help         - show this help")
print("   untappd.lua --help        - show this help")
print("   untappd.lua -?            - show this help")
print("options:")
print("   -f <path>       Path to alternative config file")
end


function ParseCommandLine()
local i, item


for i,item in ipairs(arg)
do
  if item == "-f" 
  then
  config_path=arg[i+1]
  arg[i]=nil
  arg[i+1]=nil
  elseif  item == "-?" or item == "-help" or item == "--help" then return "help"
  end
end
	
mode=arg[1]
if mode == nil then return "help" end

return mode
end




function DoStuff(mode, arg, venues)
local i, item

if mode=="help" then PrintHelp()
elseif mode == "list" then venues:list()
else
	for i,item in ipairs(arg)
	do
	     if i > 1 
	     then
		if mode == "add" then venues:add(item) 
		elseif mode == "del" or mode == "delete" then venues:delete(item) 
		else venues:show(item) 
		end
 	    end
	end
    if mode == "show" and #arg == 1 then venues:show_all() end
end


end



Out=terminal.TERM()

mode=ParseCommandLine()
venues=VenuesInit()

DoStuff(mode, arg, venues)

if venues.save_required == true then venues:save() end

