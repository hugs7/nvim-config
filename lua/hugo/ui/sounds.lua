local M = {}
local uv = vim.uv or vim.loop

local state = { active = false, aug = nil }

-- Generate short sine wave tones using ffmpeg, cached to /tmp
local sound_cache = {}
local function ensure_tone(name, freq, duration)
  if sound_cache[name] then return sound_cache[name] end
  local path = "/tmp/jarvis_" .. name .. ".wav"
  -- Check if already generated
  local stat = uv.fs_stat(path)
  if stat then
    sound_cache[name] = path
    return path
  end
  -- Generate with ffmpeg (async)
  vim.fn.jobstart({
    "ffmpeg", "-y", "-f", "lavfi", "-i",
    string.format("sine=frequency=%d:duration=%s", freq, duration),
    "-af", string.format("volume=0.3,afade=t=out:st=%s:d=0.05", duration - 0.05),
    path,
  }, {
    on_exit = function(_, code)
      if code == 0 then
        sound_cache[name] = path
      end
    end,
  })
  sound_cache[name] = path
  return path
end

local function play(name)
  if not state.active then return end
  local path = sound_cache[name]
  if not path then return end
  -- Non-blocking play
  vim.fn.jobstart({ "paplay", path }, { detach = true })
end

-- Pre-generate tones on setup
local function generate_tones()
  ensure_tone("save", 880, 0.08)      -- high short beep
  ensure_tone("error", 220, 0.15)     -- low warning tone
  ensure_tone("lsp_ready", 660, 0.1)  -- medium confirm
  ensure_tone("boot", 440, 0.12)      -- startup chime
end

function M.open()
  if state.active then return end
  state.active = true
  generate_tones()

  -- Small delay for tones to generate
  vim.defer_fn(function()
    play("boot")
  end, 500)

  state.aug = vim.api.nvim_create_augroup("JarvisSounds", { clear = true })

  -- Beep on save
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = state.aug,
    callback = function() play("save") end,
  })

  -- Low tone on diagnostic error
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = state.aug,
    callback = function()
      local errs = #vim.diagnostic.get(nil, { severity = 1 })
      if errs > 0 then
        play("error")
      end
    end,
  })

  -- Chime when LSP attaches
  vim.api.nvim_create_autocmd("LspAttach", {
    group = state.aug,
    callback = function()
      vim.defer_fn(function() play("lsp_ready") end, 200)
    end,
  })
end

function M.close()
  state.active = false
  if state.aug then
    pcall(vim.api.nvim_del_augroup_by_id, state.aug)
    state.aug = nil
  end
end

function M.toggle()
  if state.active then M.close() else M.open() end
end

return M
