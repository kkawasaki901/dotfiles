local wezterm = require('wezterm')
local platform = require('utils.platform')

local options = {
   default_prog = { 'cd ~' },
   launch_menu = {},
   default_cwd = wezterm.home_dir,
}

if platform.is_win then
   options.default_prog = { 'C:/WINDOWS/system32/wsl.exe' }
   options.launch_menu = {
      { label = 'PowerShell 7', args = { 'pwsh', '-NoLogo' } },
      { label = 'PowerShell 5', args = { 'powershell' } },
      { label = 'Command Prompt', args = { 'cmd' } },
      { label = 'Nushell', args = { 'nu' } },
      {
         label = 'Ubuntu',
         args = {
            'C:/WINDOWS/system32/wsl.exe --distribution-id {5140d930-6f89-4017-a295-6e5f661b1422}',
            -- idはなくても起動する
            -- 規定値を正しく設定できていればwsl.exeだけで通じる
            -- wsl --set-default
         },
      },
   }
elseif platform.is_mac then
   options.default_prog = { '/opt/homebrew/bin/fish', '-l' }
   options.launch_menu = {
      { label = 'Bash', args = { 'bash', '-l' } },
      { label = 'Fish', args = { '/opt/homebrew/bin/fish', '-l' } },
      { label = 'Nushell', args = { '/opt/homebrew/bin/nu', '-l' } },
      { label = 'Zsh', args = { 'zsh', '-l' } },
   }
elseif platform.is_linux then
   options.default_prog = { 'fish', '-l' }
   options.launch_menu = {
      { label = 'Bash', args = { 'bash', '-l' } },
      { label = 'Fish', args = { 'fish', '-l' } },
      { label = 'Zsh', args = { 'zsh', '-l' } },
   }
end

return options
