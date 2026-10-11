-- star-wars-terminal: Jedi prompt for Command Prompt (needs Clink, https://chrisant996.github.io/clink/).
-- Copied into your Clink profile folder by the installer.

local swt_home = os.getenv("SWT_HOME") or (os.getenv("USERPROFILE") .. "\\.config\\star-wars-terminal")
local saber_rgb = { blue = "137;180;250", green = "166;227;161", purple = "203;166;247", yellow = "249;226;175", white = "239;241;245" }

-- Saved saber color (shared with the other shells)
local f = io.open(swt_home .. "\\saber.txt", "r")
if f then
  local saved = (f:read("*l") or ""):gsub("%s+", "")
  f:close()
  if saber_rgb[saved] then os.setenv("JEDI_SABER", saved) end
end

-- saber command; a batch file runs in this cmd session, so the color changes right away
os.setalias("saber", '"' .. swt_home .. '\\shell\\saber.cmd" $*')

-- Prompt
local init = io.popen('oh-my-posh init cmd --config "' .. swt_home .. '\\jedi.omp.json" 2>nul')
if init then
  local code = init:read("*a")
  init:close()
  if code and code ~= "" then load(code)() end
end

-- A line from the Jedi Archives for each new session
local quotes = {}
local qf = io.open(swt_home .. "\\shell\\quotes.txt", "r")
if qf then
  for line in qf:lines() do
    local text, by = line:match("^(.-)|(.*)$")
    if text then table.insert(quotes, { text, by }) end
  end
  qf:close()
end
if #quotes > 0 then
  math.randomseed(os.time())
  local q = quotes[math.random(#quotes)]
  local function ink(rgb) return "\x1b[38;2;" .. rgb .. "m" end
  local crest = "\238\183\152" -- U+EDD8, the Jedi Order crest
  print(ink(saber_rgb[os.getenv("JEDI_SABER") or "blue"] or saber_rgb.blue) .. crest .. "\x1b[0m " ..
    ink("166;173;200") .. q[1] .. "\x1b[0m " .. ink("108;112;134") .. "- " .. q[2] .. "\x1b[0m")
end
