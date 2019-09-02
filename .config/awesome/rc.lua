-- If you want to use this configuration,
-- change the startup scripts at the bottom of this file


local interfaces = {
    "wlp112s0", "enp109s0",
    "es3",                      -- qemu
}

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
awful.rules = require("awful.rules")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")

local vicious = require("vicious")


function run_once(prg, args)
  if not prg then
    do return nil end
  end
  if not args then
    args=""
  end
  awful.spawn.with_shell('pgrep -f -u $USER -x ' .. prg .. ' || (' .. prg .. ' ' .. args ..')')
end


-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, and wallpapers
beautiful.init("/home/fabian/.config/awesome/theme.lua")

-- This is used later as the default terminal and editor to run.
terminal = "xterm"

editor = os.getenv("EDITOR") or "nano"
editor_cmd = terminal .. " -e " .. editor

menubar.utils.terminal = terminal -- Set the terminal for applications that require it


mymainmenu = awful.menu({
    items = {
        { "open terminal", terminal },
        --{ "hotkeys", function() return false, hotkeys_popup.show_help end},
        { "manual", terminal .. " -e man awesome" },
        { "dmesg", terminal .. " -e 'dmesg | tee /home/fabian/dmesg | tac | vim -'" },
        { "edit config", editor_cmd .. " " .. awesome.conffile },
        { "restart", awesome.restart },
        { "quit", function() awesome.quit() end}
    }
})

mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })


-- modkey: alt
modkey = "Mod1"

-- Table of layouts to cover with awful.layout.inc, order matters.
layouts =
{
    awful.layout.suit.floating,
    --awful.layout.suit.tile,
    --awful.layout.suit.tile.left, -- left is nice, but order of windows on screen is different than in the task list, so we prefer right
    awful.layout.suit.tile.right,
    awful.layout.suit.tile.bottom,
    --awful.layout.suit.tile.top,
    --awful.layout.suit.fair,
    --awful.layout.suit.fair.horizontal,
    --awful.layout.suit.spiral,
    --awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    --awful.layout.suit.max.fullscreen,
    --awful.layout.suit.magnifier
    --awful.layout.suit.corner.nw,
}
-- }}}

-- {{{ Tags
-- Define a tag table which hold all screen tags.
tags = {}
names = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, "a", "b", "c", "d", "e", "f",  "g", "h", "i", "j", "k" }
start_layouts = {
    awful.layout.suit.max,
    awful.layout.suit.max,
    awful.layout.suit.max,
    awful.layout.suit.max,
    awful.layout.suit.max,

    awful.layout.suit.max,
    awful.layout.suit.max,
    awful.layout.suit.max,
    awful.layout.suit.max,
    awful.layout.suit.max,

    awful.layout.suit.max,
    awful.layout.suit.max,
    awful.layout.suit.max,
    awful.layout.suit.max,
    awful.layout.suit.max,
    awful.layout.suit.max,

    awful.layout.suit.max,
    awful.layout.suit.max,
    awful.layout.suit.max,
    awful.layout.suit.max,
    awful.layout.suit.max,
}



for s = 1, screen.count() do
    tags[s] = awful.tag(names, s, start_layouts)
end
-- }}}

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}


-- {{{ Wibox
-- Create a textclock widget
mytextclock = wibox.widget.textclock(" %a %b %d, %H:%M:%S ", 1)

-- Initialize widgets
memwidget = wibox.widget.textbox()
vicious.register(memwidget, vicious.widgets.mem, function (widget, args) return string.format(" M%02d%%", args[1]) end, 13)
cpuwidget = wibox.widget.textbox()
vicious.register(cpuwidget, vicious.widgets.cpu, function (widget, args) return string.format(" %02d%% ", args[1]) end, 15)

netwidget = wibox.widget.textbox()
vicious.register(netwidget, vicious.widgets.net, function (widget, args)
    local widget_text = ""
    for i, name in ipairs(interfaces) do
        local up = tonumber(args["{" .. name .. " up_kb}"])
        local down = tonumber(args["{" .. name .. " down_kb}"])
        local carrier = args["{" .. name .. " carrier}"]
        if down ~= 0 and up ~= 0 and down ~= nil or carrier ~= 0 and carrier ~= nil then
            widget_text = string.format("↓%4s ↑%4s", down, up)
            break
        end
    end
    netwidget:set_text(widget_text)
end, 3)

batterywidget = wibox.widget.textbox()
batterywidget:set_text("")
batterywidgettimer = gears.timer({ timeout = 60 })
batterywidgettimer:connect_signal("timeout",
  function()
    fh = assert(io.popen("acpi | cut -d, -f 2,3 - |sed 's/, discharging at zero rate - will never fully discharge.//' | sed 's/ 100%//' " ..
                         " | sed 's/..:..:.. until charged/charging/' | sed 's/\\s*$//' ", "r"))
    local text = fh:read("*l")
    if text then
        batterywidget:set_text(" " .. text)
    else
        batterywidget:set_text("")
    end
    fh:close()
  end
)
batterywidgettimer:start()
batterywidgettimer:emit_signal("timeout")

temperaturewidget = wibox.widget.textbox()
temperaturewidget:set_text("")
temperaturewidgetimer = gears.timer({ timeout = 5 })
temperaturewidgetimer:connect_signal("timeout",
  function()
    fh = assert(io.popen("sensors coretemp-isa-0000 |cut -d' ' -f5-6 - |sed 's/+//' | sed 's/\\.0//' |grep C |head -n1", "r"))
    local text = fh:read("*l")
    if text then
        temperaturewidget:set_text(" " .. text)
    else
        temperaturewidget:set_text()
    end
    fh:close()
  end
)
temperaturewidgetimer:start()
temperaturewidgetimer:emit_signal("timeout")


temperaturewidget2 = wibox.widget.textbox()
temperaturewidget2:set_text("")
temperaturewidgetimer2 = gears.timer({ timeout = 5 })
temperaturewidgetimer2:connect_signal("timeout",
  function()
    fh = assert(io.popen("nvidia-smi -q |grep 'GPU Current Temp' | sed 's/\\s*GPU Current Temp\\s*: //' | sed 's/ /°/'", "r"))
    local text = fh:read("*l")
    if text then
        temperaturewidget2:set_text(" " .. text)
    else
        temperaturewidget2:set_text()
    end
    fh:close()
  end
)
temperaturewidgetimer2:start()
temperaturewidgetimer2:emit_signal("timeout")

-- Create a wibox for each screen and add it
local taglist_buttons = gears.table.join(
                    awful.button({ }, 1, function(t) t:view_only() end),
                    --awful.button({ modkey }, 1, function(t,c) c:move_to_tag(t) end),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, awful.client.toggletag),

                    awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
                    )
local tasklist_buttons = gears.table.join(
    awful.button({ }, 1, function (c)
        if c == client.focus then
            c.minimized = true
        else
            if not c:isvisible() then
                awful.tag.viewonly(c:tags()[1])
            end
            -- This will also un-minimize
            -- the client, if needed
            client.focus = c
            c:raise()
        end
    end),
    awful.button({ }, 3, function (c)
        -- right mouse button closes
        if not c.no_kill then c:kill() end
    end),
    awful.button({ }, 4, function (c)
        -- mouse wheel set/removes focus
        c.minimized = true

    end),
    awful.button({ }, 5, function (c)
        c.minimized = false
        client.focus = c
        c:raise()
end))

awful.screen.connect_for_each_screen(function(s)
    -- Create a promptbox for each screen
    --mypromptbox[s] = awful.widget.prompt()
    s.mypromptbox = awful.widget.prompt()
    -- Create an imagebox widget which will contains an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
                           awful.button({ }, 1, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(layouts, -1) end),
                           awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)))
    -- Create a taglist widget
    s.mytaglist = awful.widget.taglist(s, awful.widget.taglist.filter.all, taglist_buttons)

    -- Create a tasklist widget
    s.mytasklist = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, tasklist_buttons)

    -- Create the wibox
    s.mywibox = awful.wibar({ position = "top", screen = s })

    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        {
            layout = wibox.layout.fixed.horizontal,
            mylauncher,
            s.mytaglist,
            s.mypromptbox,
        },
        s.mytasklist,
        {
            layout = wibox.layout.fixed.horizontal,
            wibox.widget.systray(),
            batterywidget,
            temperaturewidget,
            temperaturewidget2,
            netwidget,
            cpuwidget,
            memwidget,
            mytextclock,
            s.mylayoutbox,
        },
    }
end)
-- }}}

-- {{{ Mouse bindings
root.buttons(gears.table.join(
    --awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = gears.table.join(

   awful.key({}, "F8" , function() awful.spawn( ".local/bin/setvolume.sh decrease" ) end),
   awful.key({}, "F9" , function() awful.spawn( ".local/bin/setvolume.sh increase" ) end),
   awful.key({}, "F10", function() awful.spawn( ".local/bin/setvolume.sh mute" ) end),
   awful.key({}, "F11", function()
       awful.spawn.with_shell( "cmus-remote -u; notify-send $(cmus-remote -Q |grep status)" )
       awful.spawn.with_shell( "notify-send $(vlc-toggle)" )
       awful.spawn.with_shell( "echo 'cycle pause' | socat - /tmp/mpasocket" )
   end),

    awful.key({ modkey,           }, "Left",   awful.tag.viewprev       ),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext       ),


    -- added: go to left/right tag and take focused client with you
    awful.key({ modkey, "Shift" }, "Right",
        function()
          if client.focus then
             local screen = client.focus.screen
             local tag = client.focus:tags()[1]
             local c = client.focus

             awful.tag.viewnext()
             c:move_to_tag(screen.selected_tag)
             client.focus = c
             c:raise()
         else
             awful.tag.viewnext()
         end
        end),
    awful.key({ modkey, "Shift" }, "Left",
        function()
          if client.focus then
             local screen = client.focus.screen
             local c = client.focus
             awful.tag.viewprev()
             c:move_to_tag(screen.selected_tag)
             client.focus = c
             c:raise()
          else
             awful.tag.viewprev()
         end
        end),
    awful.key({ modkey, "Shift" }, "k",
        function()
          if client.focus then
             local screen = client.focus.screen
             local tag = client.focus:tags()[1]
             local c = client.focus

             awful.tag.viewnext()
             c:move_to_tag(screen.selected_tag)
             client.focus = c
             c:raise()
         else
             awful.tag.viewnext()
         end
        end),
    awful.key({ modkey, "Shift" }, "j",
        function()
          if client.focus then
             local screen = client.focus.screen
             local c = client.focus
             awful.tag.viewprev()
             c:move_to_tag(screen.selected_tag)
             client.focus = c
             c:raise()
          else
             awful.tag.viewprev()
         end
        end),

    awful.key({ modkey,           }, "h",
        function ()
            awful.client.focus.byidx(-1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "l",
        function ()
            awful.client.focus.byidx( 1)
            if client.focus then client.focus:raise() end
        end),

    -- Layout manipulation
    awful.key({ modkey, "Shift", "Ctrl"   }, "j", function () awful.client.swap.byidx(  1)    end),
    awful.key({ modkey, "Shift", "Ctrl"   }, "k", function () awful.client.swap.byidx( -1)    end),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.byidx( 1)
            if client.focus then
                client.focus:raise()
            end
        end),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.spawn(terminal) end),
    awful.key({ modkey, "Control" }, "r", awesome.restart),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit),

    awful.key({ modkey,           }, "j",     function () awful.tag.viewprev()    end),
    awful.key({ modkey,           }, "k",     function () awful.tag.viewnext()    end),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1)      end),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1)      end),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1)         end),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1)         end),
    awful.key({ modkey,           }, "space", function () awful.layout.inc(layouts,  1) end),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),

    awful.key({ modkey, "Control" }, "n", awful.client.restore),

    -- Prompt
    awful.key({ modkey },            "r",
              function ()
                  awful.screen.focused().mypromptbox:run()
              end),

    -- multimedia keys
    awful.key({ }, "XF86AudioNext",function () awful.spawn( "cmus-remote -n" ) end),
    awful.key({ }, "XF86Tools",function () awful.spawn( "cmus-remote -n" ) end), -- the button looks like a next key anyways
    awful.key({ }, "XF86AudioPrev",function () awful.spawn( "cmus-remote -r" ) end),
    awful.key({ }, "XF86AudioPlay",function () awful.spawn( "cmus-remote -u" ) end),
    --awful.key({ }, "XF86AudioStop",function () awful.spawn( "mpc pause" ) end),

    awful.key({ }, "XF86AudioRaiseVolume",function () awful.spawn( ".local/bin/setvolume.sh increase" ) end),
    awful.key({ }, "XF86AudioLowerVolume",function () awful.spawn( ".local/bin/setvolume.sh decrease" ) end),
    awful.key({ }, "XF86AudioMute",function () awful.spawn( ".local/bin/setvolume.sh mute" ) end),


   --awful.key(
   --    { modkey },
   --    "F1",
   --    function()
   --        awful.spawn(".local/bin/change_headphones_speakers.py", false)
   --    end
   --),

   awful.key(
       { modkey },
       "F2",
       function()
           awful.spawn("pavucontrol", false)
       end
   ),

   awful.key(
       { modkey },
       "F3",
       function()
           awful.spawn(".local/bin/notify-ip.sh", false)
       end
   ),


    --awful.key({ modkey }, "p", function() menubar.show() end),

   awful.key(
       { modkey },
       "F11",
       function()
           awful.spawn.easy_async_with_shell("wa weather | stripcolorcodes", function(stdout, stderr, reason, exit_code)
               naughty.notify { text = stdout, timeout = 30 }
           end)
       end
   ),

   awful.key(
       { modkey },
       "F12",
       function()
           local info = " " -- TODO: Insert something useful here
           awful.spawn("xlock -mode blank -echokeys -echokey '*' +description -info '" .. info .. "' -username ' ' -password ' ' -validate ' ' +showdate", false)
       end
   ),

   awful.key(
        { modkey },
        "w",
        function()
            naughty.destroy_all_notifications()
        end
   ),

   -- bind PrintScrn to capture a screen
   awful.key(
       {},
       "Print",
       function()
           awful.spawn("xfce4-screenshooter -f -s /tmp/",false)
       end
   ),

   awful.key(
       { modkey },
       "Print",
       function()
           awful.spawn("xfce4-screenshooter -r -s /tmp/",false)
       end
   )


)

clientkeys = gears.table.join(
    awful.key({ modkey,           }, "f",      function (c) c.fullscreen = not c.fullscreen  end),
    awful.key({ modkey,           }, "q",      function (c) if not c.no_kill then c:kill() end  end),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
    awful.key({ modkey,           }, "o",
        function (c)
            -- fix bug with screens which do not have the same size
            local old_maximized = c.maximized_horizontal
            c.maximized_horizontal = false
            c.maximized_vertical   = false
            c:move_to_screen()
            c.maximized_horizontal = old_maximized
            c.maximized_vertical   = old_maximized
        end),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized = not c.maximized
            c.maximized_horizontal = c.maximized
            c.maximized_vertical   = c.maximized
        end),
    awful.key({ modkey,           }, "v",
        function (c)
            awful.tag.history.restore(awful.screen.focused())
        end)
)

-- Compute the maximum number of digit we need, limited to 9
keynumber = 0
for s = 1, screen.count() do
   keynumber = math.min(9, math.max(#tags[s], keynumber));
end

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, keynumber do
    globalkeys = gears.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end),
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end),
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                              tag:view_only()
                          end
                     end
                  end)
          )
end

globalkeys = gears.table.join(globalkeys,
awful.key({ modkey }, "#" .. 19,
function ()
    local screen = awful.screen.focused()
    local tag = screen.tags[#screen.tags]
    if tag then
        tag:view_only()
    end
end),
awful.key({ modkey, "Control" }, "#" .. 19,
function ()
    local screen = awful.screen.focused()
    local tag = screen.tags[#screen.tags]
    if tag then
        awful.tag.viewtoggle(tag)
    end
end),
awful.key({ modkey, "Shift" }, "#" .. 19,
function ()
    if client.focus then
        local tag = client.focus.screen.tags[#client.focus.screen.tags]
        if tag then
            client.focus:move_to_tag(tag)
            tag:view_only()
        end
    end
end)
)

clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, function(c) if not c.no_mouse then awful.mouse.client.move(c) end end),
    awful.button({ modkey }, 3, function(c) if not c.no_mouse then awful.mouse.client.resize(c) end end))

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      --properties = { border_width = 2, --beautiful.border_width,
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = true,
                     keys = clientkeys,
                     buttons = clientbuttons } },
    { rule = { class = "MPlayer" },
      properties = { border_width = 0 } },
    { rule = { class = "Vlc" },
      properties = { border_width = 0 } },
    { rule = { class = "Orage" },
      properties = { floating = true } },

    { rule = { class = "thunderbird" },
      properties = { floating = true } },
    { rule = { class = "Thunderbird" },
      properties = { floating = true } },

    { rule = { class = "feh" },
      properties = { floating = true } },

    { rule = { class = "VirtualBox" },
      properties = { border_width = 0 } },
    { rule = { class = "rdesktop" },
      properties = { border_width = 0 } },

    { rule = { class = "Qemu-system-x86_64" },
      --properties = { border_width = 0 },
      callback = function(c)
          c.no_kill = true
      end
    },

    { rule = { class = "Wine" },
      --properties = { border_width = 0 },
      callback = function(c)
          c.no_kill = true
          c.no_mouse = true
      end
    },

    -- wine doesn't like borders
    { rule = { class = "Wine" },
      properties = { border_width = 0 } },


     --{ rule = { class = "Firefox" },
      -- properties = { tag = tags[1][2] } },
      --properties = { floating = false, border_width = 5, maximized_vertical = true } },

    --{ rule = { class = "Terminal" },
    --  --properties = { border_width = 0 },
    --  callback = function(c)
    --      awful.layout.set(awful.layout.suit.spiral, c.tags(c)[0])
    --  end
    --},

}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c, startup)
    -- Add a titlebar
    -- awful.titlebar.add(c, { modkey = modkey })

    -- Enable sloppy focus
    c:connect_signal("mouse::enter", function(c)
        local count = 0
        --for _ in pairs(awful.client.tiled(c.screen)) do
        for _ in pairs(awful.client.visible(c.screen)) do
            count = count + 1
        end

       if (awful.layout.get(c.screen) ~= awful.layout.suit.magnifier or count < 2)
            and awful.client.focus.filter(c) then
            client.focus = c
        end
    end)

    if not startup then
        -- Set the windows at the slave,
        -- i.e. put it at the end of others instead of setting it master.
        -- awful.client.setslave(c)

        -- Put windows in a smart way, only if they does not set an initial position.
        if not c.size_hints.user_position and not c.size_hints.program_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}

-- run xflux/redshift
-- oh noes, you know where I live
awful.spawn.with_shell("pidof redshift || redshift -l 47.5:19.0")
