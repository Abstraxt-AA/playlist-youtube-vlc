--[[
 Youtube playlist importer for VLC media player 1.1 and 2.0
 Copyright 2012 Guillaume Le Maout
 Authors:  Guillaume Le Maout
 Contact: http://addons.videolan.org/messages/?action=newmessage&username=exebetche
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
--]]

--[[
 MODified by Kai Gillmann, 19.01.2013, kaigillmann@googlemail.com:
 VLC HAS already a youtube importer, but not for playlists. IMO this mentioned one is
 better than this one, because it opens the video in the best possible video resolution.
 So i decided to remove all parts of the code which is not responsible for list handling.
 Now this lua script parses the list, as wanted, but for each video opened, the vlc default
 Youtube script is used, so the videos will be displayed properly.
--]]

--[[
 Patched by Aaron Hill (https://github.com/seraku24), 2018-05-16:
 The original script was failing in VLC 3.x due to an overzealous probe function.
 This patch makes the probe function more restrictive to avoid false positives.
--]]

--[[
 Patched by Matteo Federico Zazzetta (https://github.com/p3g4asus), 2020-02-17:
 The original script was not working anymore because youtube removed the list_ajax interface.
 Unfortunately the new interface requires at least http GET method with proper headers and 
 they are not supported by vlc. So this version makes use of an external program (youtube-dl).
 Disclaimer: this version works only under Windows. It can be easily ported but I have no way to test
 it on other OS at the moment.
 Installation (under Windows): place this file in the lua playlist vlc folder together with JSON.lua 
 (http://regex.info/code/JSON.lua) and youtube-dl.exe (https://youtube-dl.org/latest)
--]]

--[[
 Modified by Ahmed Yehia (https://github.com/Abstraxt-AA), 2021-09-25:
 The script now relies on cURL being installed on the system instead of youtube-dl, and uses an API
 key to make the calls to Google's Youtube API in order to load playlist information. As such, part
 of the installation process is to replace the placeholder value in the api_key variable with a valid
 Google API key. More info can be found at https://cloud.google.com/docs/authentication/api-keys
 --]]

local api_key = 'INSERT_YOUR_API_KEY_HERE'

function probe()
  if vlc.access ~= "http" and vlc.access ~= "https" then
    return false
  end

  return string.match(vlc.path:match("([^/]+)"), "%w+.youtube.com") and
    (not string.match(vlc.path, "list_ajax") and 
    string.match(vlc.path, "[?&]list="))
end


local function get_url_param(url, name)
  local _, _, res = string.find(url, "[&?]" .. name .. "=([^&]*)")
  return res
end

local function extract_json_value(line, name, init_value)
  local value = init_value
  if (string.match(line, '"' .. name .. '": "')) then
    local _, start = string.find(line, '"' .. name .. '": "')
    local finish = string.find(string.sub(line, start + 1), '"[^"]*$')
    value = string.sub(line, start + 1, start + finish - 1)
  end
  return value
end

function parse()
  local playlist = {}
  local playlist_id = get_url_param(vlc.path, "list")
  local page_token = ''
  local title

  while page_token ~= nil do
    local curl = 'curl "https://content-youtube.googleapis.com/youtube/v3/playlistItems?part=snippet' ..
      '&playlist_id=' .. playlist_id ..
      '&key=' .. api_key ..
      '&maxResults=50&fields=pageInfo%2CnextPageToken%2CprevPageToken%2Citems%28'..
      'snippet%2FresourceId%2FvideoId%2Csnippet%2Ftitle%29' ..
      '&pageToken=' .. page_token .. '"'
    
    page_token = nil
    
    local handle = assert(io.popen(curl, 'r'))
    for line in handle:lines() do
      page_token = extract_json_value(line, "nextPageToken", page_token)
      title = extract_json_value(line, "title", title)
      if (string.match(line, '"videoId": "')) then
        local item = {}
        _, start = string.find(line, '"videoId": "')
        finish = string.find(string.sub(line, start + 1), '"[^"]*$')
        item.path = 'https://www.youtube.com/watch?v=' .. string.sub(line, start + 1, start + finish - 1)
        item.title = title;
        table.insert(playlist, item)
      end
    end
    handle:close()
  end
  
  return playlist
end
