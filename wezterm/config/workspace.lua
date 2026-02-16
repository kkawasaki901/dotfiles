local wezterm = require('wezterm')
local mux = wezterm.mux
local M = {}

function M.setup()
   wezterm.on('gui-startup', function()
      -- default
      do
         local tab, pane, window = mux.spawn_window({
            workspace = 'ws1-single',
         })
      end
      -- 2分割
      do
         local tab, pane, window = mux.spawn_window({
            workspace = 'ws1-2pane',
         })
         pane:split({ direction = 'Right', size = 0.5 })
      end

      -- IDE風3分割
      do
         local tab, pane, window = mux.spawn_window({
            workspace = 'ws2-ide',
         })
         local right = pane:split({ direction = 'Right', size = 0.3 })
         pane:split({ direction = 'Bottom', size = 0.3 })
      end

      -- 4分割
      do
         local tab, pane, window = mux.spawn_window({
            workspace = 'ws3-dashboard',
         })
         local right = pane:split({ direction = 'Right', size = 0.5 })
         pane:split({ direction = 'Bottom', size = 0.5 })
         right:split({ direction = 'Bottom', size = 0.5 })
      end

      mux.set_active_workspace('ws1-single')
   end)
end

return M
