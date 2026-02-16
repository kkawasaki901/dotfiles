local platform = require('utils.platform')

local options = {
   -- ref: https://wezfurlong.org/wezterm/config/lua/SshDomain.html
   ssh_domains = {},

   -- ref: https://wezfurlong.org/wezterm/multiplexing.html#unix-domains
   unix_domains = {
      {
         name = 'unix',
      },
   },

   -- ref: https://wezfurlong.org/wezterm/config/lua/WslDomain.html
   wsl_domains = {},
}

if platform.is_win then
   options.wsl_domains = {
      {
         name = 'WSL:Ubuntu-24.04',
         distribution = 'Ubuntu-24.04',
         default_cwd = '/home/kawasaki',
      },
   }
end

return options
