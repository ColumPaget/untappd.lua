require("stream")
require("strutil")
require("xml")
require("time")
require("terminal")
require("process")



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


function ParseCheckin(venue, Xml)
local item, str
local checkin={}

checkin.date=""
item=Xml:next()
while item ~= nil
do
if item.type=="a" and string.find(item.data, 'class="user"') ~= nil
then
	checkin.user=XMLGetText(Xml)
	str=XMLGetText(Xml) 
	if string.sub(str, 1, 12) ~= "is drinking " then print("ERROR: no 'is drinking a': ["..str.."]") end
	checkin.beer=XMLGetText(Xml)
	if XMLGetText(Xml) ~= "by " then print("ERROR: no 'by'") end
	checkin.brewer=XMLGetText(Xml)
	table.insert(venue.checkins, checkin)
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


function GetVenueDetails(url)
local venue={}
local S, doc, Xml, item, str

venue.url=url
venue.checkins={}

S=stream.STREAM(url)
doc=S:readdoc()
S:close()

io.stderr:write(doc.."\n")

Xml=xml.XML(doc)
item=Xml:next()
while item ~= nil
do

if item.type ~= nil 
then
	if item.type=="div" and item.data=='class="venue-name"' 
	then 
	while item.type ~= "h1" do item=Xml:next() end
	venue.name=XMLGetText(Xml) 
	end
	if item.type=="div" and item.data=='class="checkin"' then ParseCheckin(venue, Xml) end
	if item.type=="p" and item.data=='class="address"' 
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


function DisplayTimeColorKey()
Out:puts("Key:  ~e~wToday~0  ~e~y2 days~0  ~y3 days~0  ~e~r4 days~0 ~r5 days~0 \n")
end

function TimeColor(now, checkin)
local diff

diff=now - checkin.secs
if diff < (24 * 3600) then color="~e~w"
elseif diff < (48 * 3600) then color="~e~y"
elseif diff < (72 * 3600) then color="~y"
elseif diff < (96 * 3600) then color="~e~r"
elseif diff < (120 * 3600) then color="~r"
else color=nil
end

return color
end


function SortBeers(i1, i2)
return i1.age < i2.age
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

if strutil.strlen(venue.name) > 0
then
Out:puts("~e~b"..venue.name..":~0 ")
for str,checkin in pairs(sorted)
do
str=TimeColor(now, checkin)
if str ~= nil then Out:puts(TimeColor(now, checkin) .. checkin.key.."~0, ") end
end
Out:puts("\n")
end

end




function VenuesInit()
local venues={}

venues.items={}
venues.save_required=false



venues.add=function(self, url)
local venue

venue=GetVenueDetails(url)
venue.deleted=false
table.insert(self.items, venue)

self.save_required=true
end


venues.delete_url=function(self, url)
local i, venue

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

S=stream.STREAM(process.homeDir().."/.config/untapped.venues", "r")
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
end

end


venues.save=function(self)
local S, i, item

S=stream.STREAM(process.homeDir().."/.config/untapped.venues", "w")
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
print("untappd.lua  version 1.1")
print("usage:")
print("   untappd.lua add <url>     - add untappd page to monitored pages/venues")
print("   untappd.lua del <url>     - delete untappd page from monitored pages/venues by it's untapped page url")
print("   untappd.lua del <i>       - delete untappd page from monitored pages/venues by it's index number")
print("   untappd.lua show <url>    - display recent beer reports for a venue specified by untappd page url")
print("   untappd.lua show          - display recent beer reports for all venues in the monitor list")
print("   untappd.lua list          - list all venues in the monitor list")
end


function ParseCommandLine()
local i, item

mode=arg[1]

if mode == nil or mode == "-?" or mode == "-help" or mode == "--help"
then
	PrintHelp()
elseif mode == "list"
then
	venues:list()
else
	for i,item in ipairs(arg)
	do
	     if i > 1 
	     then
		if mode == "add" then venues:add(arg[i]) 
		elseif mode == "del" or mode == "delete" then venues:delete(arg[i]) 
		else venues:show(arg[i]) 
		end
 	    end
	end

if mode == "show" and #arg == 1 then venues:show_all() end
end

end




Out=terminal.TERM()

venues=VenuesInit()
ParseCommandLine()
if venues.save_required == true then venues:save() end

